/*
===========================================================================

  Copyright (c) 2026 LandSandBoat Dev Teams

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see http://www.gnu.org/licenses/

===========================================================================
*/

#include "common/database/database.h"
#include "common/database/libmariadb/libmariadb_result_set.h"
#include "common/settings.h"
#include "map/entities/char_entity.h"
#include "map/item_container.h"
#include "map/items/item_currency.h"
#include "map/items/item_general.h"
#include "map/packet_system.h"
#include "map/packets/c2s/0x03a_item_stack.h"
#include "map/packets/c2s/0x04e_auc.h"
#include "map/utils/auctionutils.h"

#include <catch2/catch_test_macros.hpp>
#include <catch2/generators/catch_generators.hpp>

#include <functional>
#include <memory>
#include <optional>
#include <stdexcept>
#include <string>
#include <type_traits>
#include <utility>
#include <vector>

namespace
{

constexpr uint32 SellerId      = 12345;
constexpr uint16 ListingItemId = 4096;
constexpr uint32 Balance       = 1000;
constexpr uint32 Fee           = 10;

struct InventoryRow
{
    uint32 charId{ SellerId };
    uint32 location{ LOC_INVENTORY };
    uint32 slot{ 1 };
    uint32 itemId{ ListingItemId };
    uint32 quantity{ 1 };
    uint32 bazaar{};

    auto operator==(const InventoryRow&) const -> bool = default;
};

struct ListingRow
{
    uint32 itemId{ ListingItemId };
    bool   stack{};
    uint32 seller{ SellerId };
    uint32 price{ 100 };

    auto operator==(const ListingRow&) const -> bool = default;
};

struct StoredAuctionState
{
    std::optional<InventoryRow> item{ InventoryRow{} };
    std::optional<InventoryRow> gil{ InventoryRow{ SellerId, LOC_INVENTORY, 0, 65535, Balance, 0 } };
    std::vector<ListingRow>     listings;

    auto operator==(const StoredAuctionState&) const -> bool = default;
};

enum class Failure
{
    None,
    Begin,
    Count,
    Inventory,
    Fee,
    Insert,
    Commit,
    CommitReplyLost,
};

auto number(const db::BoundValue& value) -> uint32
{
    return std::visit(
        [](const auto& item) -> uint32
        {
            if constexpr (std::is_arithmetic_v<std::decay_t<decltype(item)>>)
            {
                return static_cast<uint32>(item);
            }
            else
            {
                throw std::runtime_error("Expected a numeric SQL parameter");
            }
        },
        value);
}

auto selected(const std::string& query, std::vector<std::string> names, std::vector<db::LibMariaDBResultSet::Row> rows) -> std::unique_ptr<db::ResultSet>
{
    auto schema = std::make_shared<db::ColumnSchema>();
    for (size_t index = 0; index < names.size(); ++index)
    {
        schema->index.emplace(names[index], index);
    }
    schema->names = std::move(names);
    return std::make_unique<db::LibMariaDBResultSet>(query, std::move(schema), std::move(rows));
}

// Models transaction durability and failures; SQL syntax/isolation still need a MariaDB integration test.
class ListingDatabase final : public db::Database
{
public:
    StoredAuctionState    stored;
    Failure               failure{ Failure::None };
    std::function<void()> beforeCommit;
    uint32                transactionCount{};
    uint32                gilLocks{};
    bool                  reconnectSuppressed{};

    auto execute(const std::string& query, const std::vector<db::BoundValue>& params) -> std::unique_ptr<db::ResultSet> override
    {
        const auto updated = [&](const size_t count = 0) -> std::unique_ptr<db::ResultSet>
        {
            return std::make_unique<db::LibMariaDBResultSet>(count, query);
        };

        if (query == "START TRANSACTION")
        {
            ++transactionCount;
            CHECK_FALSE(pending_.has_value());
            if (failure == Failure::Begin)
            {
                return nullptr;
            }
            pending_ = stored;
            return updated();
        }
        if (query == "COMMIT")
        {
            REQUIRE(pending_.has_value());
            CHECK(reconnectSuppressed);
            if (beforeCommit)
            {
                beforeCommit();
            }
            if (failure == Failure::Commit)
            {
                return nullptr;
            }
            stored = *pending_;
            pending_.reset();
            return failure == Failure::CommitReplyLost ? nullptr : updated();
        }
        if (query == "ROLLBACK")
        {
            CHECK(reconnectSuppressed);
            pending_.reset();
            return updated();
        }
        // ForceLogout saves position; CCharEntity's destructor saves history.
        if (query.starts_with("UPDATE chars SET pos_rot") || query.starts_with("INSERT INTO char_history SET"))
        {
            return updated(1);
        }

        auto& state = pending_ ? *pending_ : stored;
        // Retain the old statements so the stale-slot regression reaches the
        // duplicate on the original handler, instead of failing on unknown SQL.
        if (query == "UPDATE char_inventory SET quantity = ? WHERE charid = ? AND location = ? AND slot = ?")
        {
            auto& row = number(params.at(3)) == 0 ? state.gil : state.item;
            if (!row || row->charId != number(params.at(1)) || row->location != number(params.at(2)) || row->slot != number(params.at(3)))
            {
                return updated();
            }
            row->quantity = number(params.at(0));
            return updated(1);
        }
        if (query == "DELETE FROM char_inventory WHERE charid = ? AND location = ? AND slot = ?")
        {
            if (!state.item || state.item->charId != number(params.at(0)) || state.item->location != number(params.at(1)) || state.item->slot != number(params.at(2)))
            {
                return updated();
            }
            state.item.reset();
            return updated(1);
        }
        if (query == "SELECT itemId, quantity FROM char_inventory WHERE charid = ? AND location = ? AND slot = 0 FOR UPDATE")
        {
            REQUIRE(pending_.has_value());
            CHECK(reconnectSuppressed);
            ++gilLocks;
            std::vector<db::LibMariaDBResultSet::Row> rows;
            if (state.gil && state.gil->charId == number(params.at(0)) && state.gil->location == number(params.at(1)) && state.gil->slot == 0)
            {
                rows.push_back({ uint64(state.gil->itemId), uint64(state.gil->quantity) });
            }
            return selected(query, { "itemId", "quantity" }, std::move(rows));
        }
        if (query == "SELECT COUNT(*) FROM auction_house WHERE seller = ? AND sale = 0")
        {
            if (failure == Failure::Count)
            {
                return nullptr;
            }
            CHECK(number(params.at(0)) == SellerId);
            return selected(query, { "COUNT(*)" }, { { uint64(state.listings.size()) } });
        }
        const bool deleting = query == "DELETE FROM char_inventory WHERE charid = ? AND location = ? AND slot = ? AND itemId = ? AND quantity = ? AND bazaar = 0";
        if (deleting || query == "UPDATE char_inventory SET quantity = ? WHERE charid = ? AND location = ? AND slot = ? AND itemId = ? AND quantity = ? AND bazaar = 0")
        {
            if (failure == Failure::Inventory)
            {
                return nullptr;
            }
            const size_t first = deleting ? 0 : 1;
            const auto&  item  = state.item;
            if (!item || item->charId != number(params.at(first)) || item->location != number(params.at(first + 1)) ||
                item->slot != number(params.at(first + 2)) || item->itemId != number(params.at(first + 3)) ||
                item->quantity != number(params.at(first + 4)) || item->bazaar != 0)
            {
                return updated();
            }
            if (deleting)
            {
                state.item.reset();
            }
            else
            {
                state.item->quantity = number(params.at(0));
            }
            return updated(1);
        }
        if (query == "UPDATE char_inventory SET quantity = ? WHERE charid = ? AND location = ? AND slot = 0 AND itemId = ? AND quantity = ?")
        {
            if (failure == Failure::Fee)
            {
                return nullptr;
            }
            auto& gil = state.gil;
            if (!gil || gil->charId != number(params.at(1)) || gil->location != number(params.at(2)) || gil->slot != 0 ||
                gil->itemId != number(params.at(3)) || gil->quantity != number(params.at(4)))
            {
                return updated();
            }
            gil->quantity = number(params.at(0));
            return updated(1);
        }
        if (query == "INSERT INTO auction_house(itemid, stack, seller, seller_name, date, price) VALUES(?, ?, ?, ?, ?, ?)")
        {
            if (failure == Failure::Insert)
            {
                return nullptr;
            }
            state.listings.push_back({ number(params.at(0)), number(params.at(1)) != 0, number(params.at(2)), number(params.at(5)) });
            return updated(1);
        }

        FAIL_CHECK("Unexpected auction SQL: " << query);
        return nullptr;
    }

    auto executeBulk(const std::string&, const std::vector<db::BoundValue>&) -> std::unique_ptr<db::ResultSet> override
    {
        FAIL_CHECK("Unexpected bulk statement");
        return nullptr;
    }

    auto getSchema() -> std::string override
    {
        return "auction_listing_test";
    }

    auto getVersion() -> std::string override
    {
        return "test";
    }

    auto getDriverVersion() -> std::string override
    {
        return "test";
    }

    void setInTransaction(const bool active) override
    {
        reconnectSuppressed = active;
    }

private:
    std::optional<StoredAuctionState> pending_;
};

class ListingFixture
{
public:
    ListingDatabase              database;
    std::unique_ptr<CCharEntity> player;

    ListingFixture()
    : previousDatabase_(&db::getDatabase())
    , previousSettings_(settings::settingsMap)
    {
        db::setDatabase(&database);
        settings::set("map.AH_BASE_FEE_SINGLE", double(Fee));
        settings::set("map.AH_BASE_FEE_STACKS", double(Fee));
        settings::set("map.AH_TAX_RATE_SINGLE", 0.0);
        settings::set("map.AH_TAX_RATE_STACKS", 0.0);
        settings::set("map.AH_MAX_FEE", 1000.0);
        settings::set("map.AH_LIST_LIMIT", 0.0);
        resetPlayer(1, 1);
    }

    ~ListingFixture()
    {
        player.reset();
        db::setDatabase(previousDatabase_);
        settings::settingsMap = std::move(previousSettings_);
        settings::detail::generation.fetch_add(1, std::memory_order_release);
    }

    void resetPlayer(const uint32 quantity, const uint32 stackSize, const uint32 gil = Balance)
    {
        // Fresh characters also let a stale session be tested without registering a test zone.
        player            = std::make_unique<CCharEntity>();
        player->id        = SellerId;
        player->status    = xi::Status::Normal;
        player->health.hp = 1;
        player->SetName("Auctiontest");
        auto* inventory = player->getStorage(LOC_INVENTORY);
        inventory->SetSize(10);
        auto item = std::make_unique<CItemGeneral>(ListingItemId);
        item->setName("auction_listing_test_item");
        item->setStackSize(stackSize);
        item->setQuantity(quantity);
        inventory->InsertItem(std::move(item), 1);
        auto money = std::make_unique<CItemCurrency>(65535);
        money->setQuantity(gil);
        inventory->InsertItem(std::move(money), 0);
    }

    void list(const bool stack = false)
    {
        const auto* inventory = player->getStorage(LOC_INVENTORY);
        const auto* item      = inventory->GetItem(1);
        const auto  quantity  = item ? item->getQuantity() : 0;
        const auto  gil       = inventory->GetItem(0)->getQuantity();
        database.beforeCommit = [&, quantity, gil]()
        {
            const auto* current = player->getStorage(LOC_INVENTORY)->GetItem(1);
            CHECK((current ? current->getQuantity() : 0) == quantity);
            CHECK(player->getStorage(LOC_INVENTORY)->GetItem(0)->getQuantity() == gil);
            CHECK(player->isPacketListEmpty());
        };
        auctionutils::ProofOfPurchase(player.get(), GP_AUC_PARAM_LOT{ .LimitPrice = 100, .ItemWorkIndex = 1, .ItemStacks = stack ? 0U : 1U });
    }

private:
    db::Database*         previousDatabase_;
    settings::SettingsMap previousSettings_;
};

} // namespace

TEST_CASE("Auction listing transfers inventory and fee only after SQL commit", "[auction][inventory]")
{
    ListingFixture fixture;
    uint32         originalQuantity = 1;
    uint32         remaining        = 0;
    bool           stack            = false;

    SECTION("single item")
    {
    }
    SECTION("whole stack")
    {
        originalQuantity = 12;
        stack            = true;
    }
    SECTION("single item from a partial stack")
    {
        originalQuantity = 6;
        remaining        = 5;
    }

    fixture.resetPlayer(originalQuantity, originalQuantity == 1 ? 1 : 12);
    fixture.database.stored.item->quantity = originalQuantity;
    fixture.list(stack);

    REQUIRE(fixture.database.stored.listings.size() == 1);
    CHECK(fixture.database.stored.listings.front() == ListingRow{ ListingItemId, stack, SellerId, 100 });
    CHECK(fixture.database.transactionCount == 1);
    CHECK(fixture.database.stored.gil->quantity == Balance - Fee);
    CHECK(fixture.player->getStorage(LOC_INVENTORY)->GetItem(0)->getQuantity() == Balance - Fee);
    CHECK(fixture.player->status == xi::Status::Normal);
    CHECK_FALSE(fixture.database.reconnectSuppressed);
    const auto* item = fixture.player->getStorage(LOC_INVENTORY)->GetItem(1);
    if (remaining)
    {
        REQUIRE(fixture.database.stored.item.has_value());
        REQUIRE(item != nullptr);
        CHECK(fixture.database.stored.item->quantity == remaining);
        CHECK(item->getQuantity() == remaining);
    }
    else
    {
        CHECK_FALSE(fixture.database.stored.item.has_value());
        CHECK(item == nullptr);
    }
}

TEST_CASE("Auction listing SQL failures preserve inventory and fee", "[auction][inventory]")
{
    ListingFixture fixture;
    const auto     quantity = GENERATE(1U, 6U);
    fixture.resetPlayer(quantity, 12);
    fixture.database.stored.item->quantity = quantity;

    SECTION("transaction start fails")
    {
        fixture.database.failure = Failure::Begin;
    }
    SECTION("listing count fails")
    {
        fixture.database.failure = Failure::Count;
    }
    SECTION("inventory removal fails")
    {
        fixture.database.failure = Failure::Inventory;
    }
    SECTION("fee debit fails")
    {
        fixture.database.failure = Failure::Fee;
    }
    SECTION("listing insert fails")
    {
        fixture.database.failure = Failure::Insert;
    }
    SECTION("commit fails without applying")
    {
        fixture.database.failure = Failure::Commit;
    }

    const auto before = fixture.database.stored;
    fixture.list();

    CHECK(fixture.database.stored == before);
    REQUIRE(fixture.player->getStorage(LOC_INVENTORY)->GetItem(1) != nullptr);
    CHECK(fixture.player->getStorage(LOC_INVENTORY)->GetItem(1)->getQuantity() == quantity);
    CHECK(fixture.player->getStorage(LOC_INVENTORY)->GetItem(0)->getQuantity() == Balance);
    CHECK(fixture.player->status == xi::Status::Shutdown);
    CHECK_FALSE(fixture.database.reconnectSuppressed);
}

TEST_CASE("Auction listing refuses stale persisted inventory", "[auction][inventory]")
{
    ListingFixture fixture;

    SECTION("item missing")
    {
        fixture.database.stored.item.reset();
    }
    SECTION("item identity changed")
    {
        ++fixture.database.stored.item->itemId;
    }
    SECTION("item quantity changed")
    {
        ++fixture.database.stored.item->quantity;
    }
    SECTION("item belongs to another player")
    {
        ++fixture.database.stored.item->charId;
    }
    SECTION("item moved to another container")
    {
        ++fixture.database.stored.item->location;
    }
    SECTION("item moved to another slot")
    {
        ++fixture.database.stored.item->slot;
    }
    SECTION("item is in a bazaar")
    {
        fixture.database.stored.item->bazaar = 10;
    }
    SECTION("gil missing")
    {
        fixture.database.stored.gil.reset();
    }
    SECTION("gil identity changed")
    {
        ++fixture.database.stored.gil->itemId;
    }
    SECTION("gil balance changed")
    {
        --fixture.database.stored.gil->quantity;
    }

    const auto before = fixture.database.stored;
    fixture.list();

    CHECK(fixture.database.stored == before);
    CHECK(fixture.player->status == xi::Status::Shutdown);
    CHECK(fixture.player->getStorage(LOC_INVENTORY)->GetItem(1)->getQuantity() == 1);
    CHECK(fixture.player->getStorage(LOC_INVENTORY)->GetItem(0)->getQuantity() == Balance);
}

TEST_CASE("Auction listing does not refund a commit whose reply was lost", "[auction][inventory]")
{
    ListingFixture fixture;
    fixture.database.failure = Failure::CommitReplyLost;
    fixture.list();

    REQUIRE(fixture.database.stored.listings.size() == 1);
    CHECK_FALSE(fixture.database.stored.item.has_value());
    CHECK(fixture.database.stored.gil->quantity == Balance - Fee);
    CHECK(fixture.player->status == xi::Status::Shutdown);
    CHECK(fixture.player->getStorage(LOC_INVENTORY)->GetItem(1)->getQuantity() == 1);
    CHECK(fixture.player->getStorage(LOC_INVENTORY)->GetItem(0)->getQuantity() == Balance);

    const auto committed = fixture.database.stored;
    fixture.list();
    CHECK(fixture.database.transactionCount == 1);
    CHECK(fixture.database.stored == committed);
}

TEST_CASE("Auction listing cannot duplicate an item whose saved slot changed", "[auction][inventory]")
{
    ListingFixture fixture;
    fixture.database.stored.item->slot = 2;
    fixture.list();

    // The old DELETE returned a valid result with zero affected rows, then
    // inserted the listing anyway. Reconnecting loaded the surviving item.
    REQUIRE(fixture.database.stored.item.has_value());
    CHECK(fixture.database.stored.item->slot == 2);
    CHECK(fixture.database.stored.item->quantity == 1);
    CHECK(fixture.database.stored.listings.empty());
    CHECK(fixture.database.stored.gil->quantity == Balance);
    CHECK(fixture.player->status == xi::Status::Shutdown);
}

TEST_CASE("Auction listing rejects an inventory index before narrowing it", "[auction][inventory]")
{
    ListingFixture fixture;
    const auto     before = fixture.database.stored;
    auctionutils::ProofOfPurchase(fixture.player.get(), GP_AUC_PARAM_LOT{ .LimitPrice = 100, .ItemWorkIndex = 257, .ItemStacks = 1 });

    CHECK(fixture.database.transactionCount == 0);
    CHECK(fixture.database.stored == before);
    CHECK(fixture.player->status == xi::Status::Normal);
    CHECK_FALSE(fixture.player->getStorage(LOC_INVENTORY)->GetItem(1)->isBusy());
}

TEST_CASE("An uncertain auction commit blocks subsequent inventory packets", "[auction][inventory][packets]")
{
    ListingFixture fixture;
    fixture.database.failure = Failure::CommitReplyLost;
    fixture.list();
    REQUIRE(fixture.player->status == xi::Status::Shutdown);

    PacketSystem packets;
    CBasicPacket sort;
    sort.setType(0x03A);
    sort.setSize(sizeof(GP_CLI_COMMAND_ITEM_STACK));
    sort.as<GP_CLI_COMMAND_ITEM_STACK>()->Category = LOC_INVENTORY;

    const auto lastSort              = fixture.player->getStorage(LOC_INVENTORY)->LastSortingTime;
    const auto packetCount           = fixture.player->getPacketList().size();
    fixture.player->m_LastPacketType = 0;
    packets.dispatch(0x03A, nullptr, fixture.player.get(), sort);

    CHECK(fixture.player->m_LastPacketType == 0);
    CHECK(fixture.player->getStorage(LOC_INVENTORY)->LastSortingTime == lastSort);
    CHECK(fixture.player->getPacketList().size() == packetCount);

    // Control: this same valid packet reaches the sorting handler for a live character.
    fixture.resetPlayer(1, 1);
    packets.dispatch(0x03A, nullptr, fixture.player.get(), sort);
    CHECK(fixture.player->m_LastPacketType == 0x03A);
    CHECK(fixture.player->getStorage(LOC_INVENTORY)->LastSortingTime != lastSort);
    CHECK_FALSE(fixture.player->isPacketListEmpty());
}

TEST_CASE("Auction listing cannot repeat a completed transfer", "[auction][inventory]")
{
    ListingFixture fixture;
    fixture.list();
    const auto committed = fixture.database.stored;

    SECTION("same request after success")
    {
        fixture.list();
        CHECK(fixture.database.transactionCount == 1);
    }
    SECTION("stale inventory in a second session")
    {
        fixture.resetPlayer(1, 1, Balance - Fee);
        fixture.list();
        CHECK(fixture.player->status == xi::Status::Shutdown);
    }

    CHECK(fixture.database.stored == committed);
}

TEST_CASE("Auction listing supports free listings and pagination limits", "[auction][inventory]")
{
    ListingFixture fixture;
    settings::set("map.AH_LIST_LIMIT", 300.0);

    SECTION("zero fee still locks the seller")
    {
        settings::set("map.AH_BASE_FEE_SINGLE", 0.0);
        fixture.list();
        CHECK(fixture.database.gilLocks == 1);
        CHECK(fixture.database.stored.gil->quantity == Balance);
        CHECK(fixture.database.stored.listings.size() == 1);
    }
    SECTION("limit above 255 does not truncate")
    {
        fixture.database.stored.listings.resize(100);
        fixture.list();
        CHECK(fixture.database.stored.listings.size() == 101);
        REQUIRE(fixture.player->m_ah_history.size() == 1);
        CHECK(fixture.player->m_ah_history.front().itemid == ListingItemId);
    }
    SECTION("full listing limit leaves inventory and fee unchanged")
    {
        fixture.database.stored.listings.resize(300);
        const auto before = fixture.database.stored;
        fixture.list();
        CHECK(fixture.database.stored == before);
        CHECK(fixture.player->status == xi::Status::Normal);
        CHECK(fixture.player->getStorage(LOC_INVENTORY)->GetItem(1)->getQuantity() == 1);
        CHECK(fixture.player->getStorage(LOC_INVENTORY)->GetItem(0)->getQuantity() == Balance);
    }
}
