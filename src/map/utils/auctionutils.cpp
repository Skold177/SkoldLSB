/*
===========================================================================

  Copyright (c) 2025 LandSandBoat Dev Teams

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

#include "auctionutils.h"

#include "common/logging.h"
#include "common/settings.h"
#include "common/timer.h"
#include "common/tracy.h"

#include "entities/char_entity.h"

#include "packets/c2s/0x04e_auc.h"
#include "packets/s2c/0x01d_item_same.h"
#include "packets/s2c/0x01e_item_num.h"
#include "packets/s2c/0x020_item_attr.h"
#include "packets/s2c/0x04c_auc.h"

#include "items/transactions/item_claim.h"
#include "lua/luautils.h"
#include "utils/charutils.h"
#include "utils/itemutils.h"

namespace
{

const auto isPartiallyUsed = [](CItem* PItem) -> bool
{
    if (PItem->isSubType(ITEM_CHARGED))
    {
        const auto PChargedItem = static_cast<CItemUsable*>(PItem);
        return PChargedItem->getCurrentCharges() < PChargedItem->getMaxCharges();
    }

    return false;
};

} // namespace

void auctionutils::SellingItems(CCharEntity* PChar, GP_AUC_PARAM_ASKCOMMIT param)
{
    TracyZoneScoped;

    DebugAuctionsFmt("AH: SellingItems: player: {}, Commission: {}, ItemWorkIndex: {}, ItemNo: {}, ItemStacks: {}",
                     PChar->getName(),
                     param.Commission,
                     param.ItemWorkIndex,
                     param.ItemNo,
                     param.ItemStacks);

    CItem* PItem = PChar->getStorage(LOC_INVENTORY)->GetItem(param.ItemWorkIndex);
    if (!PItem)
    {
        return;
    }

    if (PItem->getID() == param.ItemNo && !PItem->isBusy() && !PItem->hasFlag(ItemFlag::NoAuction))
    {
        if (isPartiallyUsed(PItem))
        {
            PChar->pushPacket<GP_SERV_COMMAND_AUC>(GP_CLI_COMMAND_AUC_COMMAND::AskCommit, 197, 0, 0, 0, 0);
            return;
        }

        PChar->pushPacket<GP_SERV_COMMAND_AUC>(GP_CLI_COMMAND_AUC_COMMAND::AskCommit, PItem, param.ItemStacks, param.Commission);
    }
}

void auctionutils::OpenListOfSales(CCharEntity* PChar)
{
    TracyZoneScoped;

    DebugAuctionsFmt("AH: OpenListOfSales: player: {}", PChar->getName());

    if (const auto curTick = timer::now(); curTick > PChar->m_AHHistoryTimestamp + 5s)
    {
        PChar->m_ah_history.clear();
        PChar->m_AHHistoryTimestamp = curTick;
        PChar->pushPacket<GP_SERV_COMMAND_AUC>(GP_CLI_COMMAND_AUC_COMMAND::Info);

        // A single SQL query for the player's AH history which is stored in a Char Entity struct + vector.
        const auto rset = db::preparedStmt("SELECT itemid, price, stack FROM auction_house WHERE seller = ? AND sale=0 ORDER BY id ASC LIMIT 7", PChar->id);
        if (rset && rset->rowsCount())
        {
            while (rset->next())
            {
                PChar->m_ah_history.emplace_back(AuctionHistory_t{
                    .itemid = rset->get<uint16>("itemid"),
                    .stack  = rset->get<uint8>("stack"),
                    .price  = rset->get<uint32>("price"),
                    .status = 0,
                });
            }
        }

        DebugAuctionsFmt("AH: {} has {} items up on the AH", PChar->getName(), PChar->m_ah_history.size());
    }
    else
    {
        PChar->pushPacket<GP_SERV_COMMAND_AUC>(GP_CLI_COMMAND_AUC_COMMAND::Info, 246, 0, 0, 0, 0); // try again in a little while msg
    }
}

void auctionutils::RetrieveListOfItemsSoldByPlayer(CCharEntity* PChar)
{
    TracyZoneScoped;

    DebugAuctionsFmt("AH: RetrieveListOfItemsSoldByPlayer: player: {}", PChar->getName());

    const auto totalItemsOnAh = PChar->m_ah_history.size();

    for (size_t auctionSlot = 0; auctionSlot < totalItemsOnAh; auctionSlot++)
    {
        PChar->pushPacket<GP_SERV_COMMAND_AUC>(static_cast<GP_CLI_COMMAND_AUC_COMMAND>(0x0C), static_cast<uint8>(auctionSlot), PChar);
    }
}

void auctionutils::ProofOfPurchase(CCharEntity* PChar, GP_AUC_PARAM_LOT param)
{
    TracyZoneScoped;

    DebugAuctionsFmt("AH: ProofOfPurchase: player: {}, LimitPrice: {}, ItemWorkIndex: {}, ItemStacks: {}",
                     PChar->getName(),
                     param.LimitPrice,
                     param.ItemWorkIndex,
                     param.ItemStacks);

    if (PChar->status == xi::Status::Shutdown || param.ItemWorkIndex == 0 ||
        param.ItemWorkIndex > PChar->getStorage(LOC_INVENTORY)->GetSize() || param.ItemStacks > 1)
    {
        return;
    }

    // Only claim the item here. ItemClaimTransaction's pay/take perform separate
    // writes and compensating undos, which must not be mixed with SQL rollback.
    auto transaction = ItemClaimTransaction::start(PChar);
    if (!transaction)
    {
        return;
    }

    CItem* PItem = transaction->claimSlot(LOC_INVENTORY, param.ItemWorkIndex);

    if (PItem && !PItem->isType(ITEM_CURRENCY) && !PItem->hasFlag(ItemFlag::NoAuction) && PItem->getQuantity() > 0)
    {
        if (isPartiallyUsed(PItem))
        {
            PChar->pushPacket<GP_SERV_COMMAND_AUC>(GP_CLI_COMMAND_AUC_COMMAND::LotIn, 197, 0, 0, 0, 0);
            return;
        }

        uint32 auctionFee = 0;
        if (param.ItemStacks == 0) // Selling a stack
        {
            if (PItem->getStackSize() == 1 || PItem->getStackSize() != PItem->getQuantity())
            {
                ShowErrorFmt("AH: Incorrect quantity of item {}", PItem->getName());
                PChar->pushPacket<GP_SERV_COMMAND_AUC>(GP_CLI_COMMAND_AUC_COMMAND::LotIn, 197, 0, 0, 0, 0); // Failed to place up
                return;
            }
            auctionFee = static_cast<uint32>(settings::get<uint32>("map.AH_BASE_FEE_STACKS") + (param.LimitPrice * settings::get<float>("map.AH_TAX_RATE_STACKS") / 100));
        }
        else // Selling a single item
        {
            auctionFee = static_cast<uint32>(settings::get<uint32>("map.AH_BASE_FEE_SINGLE") + (param.LimitPrice * settings::get<float>("map.AH_TAX_RATE_SINGLE") / 100));
        }

        auctionFee = std::clamp<uint32>(auctionFee, 0, settings::get<uint32>("map.AH_MAX_FEE"));

        CItem* PGil = PChar->getStorage(LOC_INVENTORY)->GetItem(0);
        if (!PGil || PGil->getQuantity() < auctionFee)
        {
            PChar->pushPacket<GP_SERV_COMMAND_AUC>(GP_CLI_COMMAND_AUC_COMMAND::LotIn, 197, 0, 0, 0, 0); // Not enough gil to pay fee
            return;
        }

        const auto listedQuantity = static_cast<uint32>(param.ItemStacks != 0 ? 1 : PItem->getStackSize());
        const auto listedItemId   = PItem->getID();
        const auto oldQuantity    = PItem->getQuantity();
        const auto newQuantity    = oldQuantity - listedQuantity;
        const auto oldGil         = PGil->getQuantity();
        const auto ahListLimit    = settings::get<uint32>("map.AH_LIST_LIMIT");
        bool       listed         = false;

        // Inventory quantities and client packets change only after COMMIT.
        // A dropped SQL connection cannot retry INSERT inside this transaction.
        const auto success = db::transaction(
            [&]()
            {
                // Serialize listings for this seller, including when the fee is zero.
                const auto gil = db::preparedStmt("SELECT itemId, quantity FROM char_inventory WHERE charid = ? AND location = ? AND slot = 0 FOR UPDATE",
                                                  PChar->id,
                                                  LOC_INVENTORY);
                if (!gil || !gil->next() || gil->get<uint16>("itemId") != PGil->getID() || gil->get<uint32>("quantity") != oldGil)
                {
                    throw std::runtime_error(fmt::format("AH: gil does not match inventory for {} ({})", PChar->getName(), PChar->id));
                }

                const auto count = db::preparedStmt("SELECT COUNT(*) FROM auction_house WHERE seller = ? AND sale = 0", PChar->id);
                if (!count || !count->next())
                {
                    throw std::runtime_error(fmt::format("AH: could not count listings for {} ({})", PChar->getName(), PChar->id));
                }

                if (ahListLimit && count->get<uint32>(0) >= ahListLimit)
                {
                    DebugAuctionsFmt("AH: Player {} has reached the AH listing limit of {}", PChar->getName(), ahListLimit);
                    return;
                }

                const auto removed = newQuantity == 0
                                         ? db::preparedStmt("DELETE FROM char_inventory WHERE charid = ? AND location = ? AND slot = ? AND itemId = ? AND quantity = ? AND bazaar = 0",
                                                            PChar->id,
                                                            LOC_INVENTORY,
                                                            param.ItemWorkIndex,
                                                            listedItemId,
                                                            oldQuantity)
                                         : db::preparedStmt("UPDATE char_inventory SET quantity = ? WHERE charid = ? AND location = ? AND slot = ? AND itemId = ? AND quantity = ? AND bazaar = 0",
                                                            newQuantity,
                                                            PChar->id,
                                                            LOC_INVENTORY,
                                                            param.ItemWorkIndex,
                                                            listedItemId,
                                                            oldQuantity);
                if (!removed || removed->rowsAffected() != 1)
                {
                    throw std::runtime_error(fmt::format("AH: item {} in slot {} does not match inventory for {} ({})",
                                                         listedItemId,
                                                         param.ItemWorkIndex,
                                                         PChar->getName(),
                                                         PChar->id));
                }

                if (auctionFee != 0)
                {
                    const auto paid = db::preparedStmt("UPDATE char_inventory SET quantity = ? WHERE charid = ? AND location = ? AND slot = 0 AND itemId = ? AND quantity = ?",
                                                       oldGil - auctionFee,
                                                       PChar->id,
                                                       LOC_INVENTORY,
                                                       PGil->getID(),
                                                       oldGil);
                    if (!paid || paid->rowsAffected() != 1)
                    {
                        throw std::runtime_error(fmt::format("AH: could not charge listing fee for {} ({})", PChar->getName(), PChar->id));
                    }
                }

                const auto inserted = db::preparedStmt("INSERT INTO auction_house(itemid, stack, seller, seller_name, date, price) VALUES(?, ?, ?, ?, ?, ?)",
                                                       listedItemId,
                                                       param.ItemStacks == 0,
                                                       PChar->id,
                                                       PChar->getName(),
                                                       earth_time::timestamp(),
                                                       param.LimitPrice);
                if (!inserted || inserted->rowsAffected() != 1)
                {
                    throw std::runtime_error(fmt::format("AH: could not list item {} for {} ({})", listedItemId, PChar->getName(), PChar->id));
                }

                listed = true;
            });

        if (!success)
        {
            // COMMIT may have reached the database even if its reply was lost.
            // Reload on login instead of refunding or using an uncertain inventory.
            ShowErrorFmt("AH: listing failed for {} ({}), disconnecting to reload inventory", PChar->getName(), PChar->id);
            charutils::ForceLogout(PChar);
            return;
        }

        if (!listed)
        {
            PChar->pushPacket<GP_SERV_COMMAND_AUC>(GP_CLI_COMMAND_AUC_COMMAND::LotIn, 197, 0, 0, 0, 0);
            return;
        }

        PGil->setQuantity(oldGil - auctionFee);
        PChar->pushPacket<GP_SERV_COMMAND_ITEM_NUM>(LOC_INVENTORY, 0, PGil->getQuantity());

        std::unique_ptr<CItem> removed;
        if (newQuantity != 0)
        {
            PItem->setQuantity(newQuantity);
            PChar->pushPacket<GP_SERV_COMMAND_ITEM_NUM>(LOC_INVENTORY, param.ItemWorkIndex, newQuantity);
        }
        else
        {
            removed = PChar->getStorage(LOC_INVENTORY)->RemoveItem(param.ItemWorkIndex);
            PChar->pushPacket<GP_SERV_COMMAND_ITEM_ATTR>(nullptr, LOC_INVENTORY, param.ItemWorkIndex);
        }

        if (!transaction->commit())
        {
            charutils::ForceLogout(PChar);
            return;
        }

        if (removed)
        {
            luautils::OnItemDrop(PChar, removed.get());
            if (PChar->inventorySyncState().hasEquipChange(removed.get()))
            {
                PChar->inventorySyncState().clearEquipChanges();
                PChar->resyncEquipment();
            }
        }

        PChar->pushPacket<GP_SERV_COMMAND_ITEM_SAME>(PChar);
        PChar->pushPacket<GP_SERV_COMMAND_AUC>(GP_CLI_COMMAND_AUC_COMMAND::LotIn, 1, 0, 0, 0, 0); // Merchandise put up on auction msg

        // The client indexes the displayed page, not the seller's total listings.
        if (PChar->m_ah_history.size() < 7)
        {
            const auto slot = static_cast<uint8>(PChar->m_ah_history.size());
            PChar->m_ah_history.emplace_back(AuctionHistory_t{
                .itemid = listedItemId,
                .stack  = static_cast<uint8>(param.ItemStacks == 0),
                .price  = param.LimitPrice,
                .status = 0,
            });
            PChar->pushPacket<GP_SERV_COMMAND_AUC>(static_cast<GP_CLI_COMMAND_AUC_COMMAND>(0x0C), slot, PChar);
        }
    }
}

auto auctionutils::PurchasingItems(CCharEntity* PChar, GP_AUC_PARAM_BID param) -> bool
{
    TracyZoneScoped;

    DebugAuctionsFmt("AH: PurchasingItems: player: {}, BidPrice: {}, ItemNo: {}, ItemStacks: {}",
                     PChar->getName(),
                     param.BidPrice,
                     param.ItemNo,
                     param.ItemStacks);

    if (PChar->getStorage(LOC_INVENTORY)->GetFreeSlotsCount() == 0)
    {
        PChar->pushPacket<GP_SERV_COMMAND_AUC>(GP_CLI_COMMAND_AUC_COMMAND::Bid, 0xE5, 0, 0, 0, 0);
    }
    else
    {
        const CItem* PItem = xi::items::lookup(param.ItemNo);

        if (PItem != nullptr)
        {
            if (PItem->hasFlag(ItemFlag::Rare))
            {
                for (uint8 LocID = 0; LocID < CONTAINER_ID::MAX_CONTAINER_ID; ++LocID)
                {
                    if (PChar->getStorage(LocID)->SearchItem(param.ItemNo) != ERROR_SLOTID)
                    {
                        PChar->pushPacket<GP_SERV_COMMAND_AUC>(GP_CLI_COMMAND_AUC_COMMAND::Bid, 0xE5, 0, 0, 0, 0);
                        return false;
                    }
                }
            }

            const CItem* PGil = PChar->getStorage(LOC_INVENTORY)->GetItem(0);
            if (!PGil || PGil->getQuantity() < param.BidPrice)
            {
                PChar->pushPacket<GP_SERV_COMMAND_AUC>(GP_CLI_COMMAND_AUC_COMMAND::Bid, 0xC5, param.ItemNo, param.BidPrice, param.ItemStacks, PItem->getStackSize());
                return false;
            }

            auto transaction = ItemClaimTransaction::start(PChar);
            if (!transaction)
            {
                return false;
            }

            const auto boughtQuantity = static_cast<uint32>(param.ItemStacks == 0 ? PItem->getStackSize() : 1);

            bool listingFound = false;

            // pay() refuses a balance that is short, and the auction_house_buy trigger pays the seller when the row is marked sold, so the two unwind together
            const auto success = db::transaction(
                [&]()
                {
                    const auto rset = db::preparedStmt("UPDATE auction_house SET buyer = ?, buyer_name = ?, sale = ?, sell_date = ? WHERE itemid = ? AND buyer_name IS NULL "
                                                       "AND stack = ? AND price <= ? ORDER BY price ASC, id ASC LIMIT 1",
                                                       PChar->id,
                                                       PChar->getName(),
                                                       param.BidPrice,
                                                       earth_time::timestamp(),
                                                       param.ItemNo,
                                                       param.ItemStacks == 0,
                                                       param.BidPrice);
                    if (!rset)
                    {
                        throw std::runtime_error(fmt::format("AH: could not mark item {} sold to {} ({})", param.ItemNo, PChar->getName(), PChar->id));
                    }

                    if (!rset->rowsAffected())
                    {
                        DebugAuctionsFmt("AH: no listing of item {} at or below {} gil for {}", param.ItemNo, param.BidPrice, PChar->getName());
                        return;
                    }

                    listingFound = true;

                    if (!transaction->pay(param.BidPrice))
                    {
                        throw std::runtime_error(fmt::format("AH: {} ({}) bought item {} for {} gil but cannot pay for it", PChar->getName(), PChar->id, param.ItemNo, param.BidPrice));
                    }

                    if (!transaction->give(LOC_INVENTORY, param.ItemNo, boughtQuantity))
                    {
                        throw std::runtime_error(fmt::format("AH: {} ({}) bought item {} x{} but it could not be added to their inventory", PChar->getName(), PChar->id, param.ItemNo, boughtQuantity));
                    }
                });

            if (success && listingFound && transaction->commit())
            {
                PChar->pushPacket<GP_SERV_COMMAND_AUC>(GP_CLI_COMMAND_AUC_COMMAND::Bid, 0x01, param.ItemNo, param.BidPrice, param.ItemStacks, PItem->getStackSize());
                PChar->pushPacket<GP_SERV_COMMAND_ITEM_SAME>(PChar);

                return true;
            }
        }

        // You were unable to buy the {qty} {item}
        if (PItem)
        {
            PChar->pushPacket<GP_SERV_COMMAND_AUC>(GP_CLI_COMMAND_AUC_COMMAND::Bid, 0xC5, param.ItemNo, param.BidPrice, param.ItemStacks, PItem->getStackSize());
        }
        else
        {
            PChar->pushPacket<GP_SERV_COMMAND_AUC>(GP_CLI_COMMAND_AUC_COMMAND::Bid, 0xC5, param.ItemNo, param.BidPrice, param.ItemStacks, 0);
        }
    }

    return false;
}

void auctionutils::CancelSale(CCharEntity* PChar, int8_t AucWorkIndex)
{
    TracyZoneScoped;

    DebugAuctionsFmt("AH: CancelSale: player: {}, AucWorkIndex: {}", PChar->getName(), AucWorkIndex);

    // AucWorkIndex can technically be -1 but this is checked at the packet handler level.
    if (AucWorkIndex < PChar->m_ah_history.size())
    {
        AuctionHistory_t canceledItem = PChar->m_ah_history[AucWorkIndex];

        const CItem* PListedItem = xi::items::lookup(canceledItem.itemid);
        const bool   isRareHeld  = PListedItem && PListedItem->hasFlag(ItemFlag::Rare) && charutils::HasItem(PChar, canceledItem.itemid);
        if (PChar->getStorage(LOC_INVENTORY)->GetFreeSlotsCount() == 0 || isRareHeld)
        {
            PChar->pushPacket<GP_SERV_COMMAND_AUC>(GP_CLI_COMMAND_AUC_COMMAND::LotCancel, 0xE5, PChar, static_cast<uint8_t>(AucWorkIndex), true);
            return;
        }

        auto transaction = ItemClaimTransaction::start(PChar);
        if (!transaction)
        {
            return;
        }

        bool listingFound = false;

        const auto success = db::transaction(
            [&]()
            {
                const auto rset = db::preparedStmt("DELETE FROM auction_house WHERE seller = ? AND itemid = ? AND stack = ? AND price = ? AND sale = 0 LIMIT 1",
                                                   PChar->id,
                                                   canceledItem.itemid,
                                                   canceledItem.stack,
                                                   canceledItem.price);
                if (!rset)
                {
                    throw std::runtime_error(fmt::format("AH: could not remove listing of item {} for {} ({})", canceledItem.itemid, PChar->getName(), PChar->id));
                }

                if (!rset->rowsAffected())
                {
                    DebugAuctionsFmt("AH: no open listing of item {} at {} gil to cancel for {}", canceledItem.itemid, canceledItem.price, PChar->getName());
                    return;
                }

                listingFound = true;

                const CItem* PDelItem = xi::items::lookup(canceledItem.itemid);
                if (!PDelItem)
                {
                    throw std::runtime_error(fmt::format("AH: {} ({}) cancelled a listing of unknown item id {}", PChar->getName(), PChar->id, canceledItem.itemid));
                }

                const auto returnedQuantity = canceledItem.stack != 0 ? PDelItem->getStackSize() : 1;
                if (!transaction->give(LOC_INVENTORY, canceledItem.itemid, returnedQuantity, Silence::Yes))
                {
                    throw std::runtime_error(fmt::format("AH: {} ({}) cancelled item {} x{} but it could not be returned to their inventory", PChar->getName(), PChar->id, canceledItem.itemid, returnedQuantity));
                }
            });

        if (success && listingFound)
        {
            if (transaction->commit())
            {
                PChar->pushPacket<GP_SERV_COMMAND_AUC>(GP_CLI_COMMAND_AUC_COMMAND::LotCancel, 0, PChar, static_cast<uint8_t>(AucWorkIndex), false);
                PChar->pushPacket<GP_SERV_COMMAND_ITEM_SAME>(PChar);
            }

            return;
        }
    }

    // Let client know something went wrong
    PChar->pushPacket<GP_SERV_COMMAND_AUC>(GP_CLI_COMMAND_AUC_COMMAND::LotCancel, 0xE5, PChar, static_cast<uint8_t>(AucWorkIndex), true); // Inventory full, unable to remove msg
}

void auctionutils::UpdateSaleListByPlayer(CCharEntity* PChar, int8_t AucWorkIndex)
{
    TracyZoneScoped;

    // AucWorkIndex can technically be -1 but this is checked at the packet handler level.
    DebugAuctionsFmt("AH: UpdateSaleListByPlayer: player: {}, AucWorkIndex: {}", PChar->getName(), AucWorkIndex);
    PChar->pushPacket<GP_SERV_COMMAND_AUC>(GP_CLI_COMMAND_AUC_COMMAND::LotCheck, AucWorkIndex, PChar);
}
