/************************************************************************
 * Auction House Pagination
 *
 * This allows players to list and view more than the client-restricted 7
 * entries. This works by using multiple pages of 6 entries and pages
 * through them every time the player opens their AH listing page.
 ************************************************************************/

#include "map/utils/moduleutils.h"

#include "common/database.h"
#include "common/logging.h"
#include "common/macros.h"
#include "common/settings.h"
#include "common/timer.h"
#include "common/tracy.h"

#include "map/entities/char_entity.h"
#include "map/enums/chat_message_type.h"
#include "map/packets/basic.h"
#include "map/packets/s2c/0x017_chat_std.h"
#include "packets/c2s/0x04e_auc.h"
#include "packets/s2c/0x04c_auc.h"

#include <algorithm>

class AHPaginationModule : public CPPModule
{
    void OnInit() override
    {
        TracyZoneScoped;

        // Auction house limit is defined as uint8 in core.
        const auto originalAHListLimit = settings::get<uint8>("map.AH_LIST_LIMIT");
        if (originalAHListLimit != 0 && originalAHListLimit <= clientSellSlots_)
        {
            ShowWarningFmt("[AH PAGES] AH_LIST_LIMIT is already set to {}. AH_LIST_LIMIT <= 7 is handled by the client. This module isn't required.", originalAHListLimit);
            return;
        }

        enabled_ = true;
        ShowInfoFmt("[AH PAGES] AH_LIST_LIMIT is set to {}. Enabling pagination with {} items per page.", originalAHListLimit, itemsPerPage_);
    }

    auto OnIncomingPacket(MapSession* session, CCharEntity* PChar, CBasicPacket& packet) -> bool override
    {
        if (!enabled_ || packet.getType() != static_cast<uint16_t>(PacketC2S::GP_CLI_COMMAND_AUC))
        {
            return false;
        }

        // Zone check is enforced here.
        const auto typedPacket = packet.as<GP_CLI_COMMAND_AUC>();

        // Only intercept for action 0x05: Open List Of Sales / Wait
        if (typedPacket->Command != GP_CLI_COMMAND_AUC_COMMAND::Info)
        {
            return false;
        }

        // Rate limit opening the AH Sales Info to once every 1.5 seconds
        const timer::time_point curTick = timer::now();
        if (curTick < PChar->m_AHHistoryTimestamp + 1500ms)
        {
            PChar->pushPacket<GP_SERV_COMMAND_AUC>(typedPacket->Command, 246, 0, 0, 0, 0); // Please try again in a little while message
            return true;
        }

        // Get the current page the player is on.
        auto currentAHPage = PChar->GetLocalVar("AH_PAGE");

        // Get the number of items player currently has for sale.
        const auto ahListings = [&]() -> uint32
        {
            const auto rset = db::preparedStmt("SELECT COUNT(*) "
                                               "FROM auction_house "
                                               "WHERE seller = ? AND sale = 0",
                                               PChar->id);
            FOR_DB_SINGLE_RESULT(rset)
            {
                return rset->get<uint32>(0);
            }

            return 0;
        }();

        // Shown when player opens the auction house for the first time, or when they cycle back to page 1.
        if (currentAHPage == 0) // Page "1"
        {
            PChar->pushPacket<GP_SERV_COMMAND_CHAT_STD>(PChar, MESSAGE_SYSTEM_3, fmt::format("You have {} item{} listed for sale.", ahListings, ahListings == 1 ? "" : "s"));
        }

        const auto totalPages = std::max<uint32>(1, (ahListings + itemsPerPage_ - 1) / itemsPerPage_);

        PChar->SetLocalVar("AH_PAGE", (currentAHPage + 1) % totalPages);

        PChar->m_ah_history.clear();
        PChar->m_AHHistoryTimestamp = curTick;
        PChar->pushPacket<GP_SERV_COMMAND_AUC>(typedPacket->Command);

        auto rset = db::preparedStmt("SELECT itemid, price, stack "
                                     "FROM auction_house "
                                     "WHERE seller = ? AND sale = 0 "
                                     "ORDER BY id ASC "
                                     "LIMIT ? OFFSET ?",
                                     PChar->id,
                                     itemsPerPage_,
                                     currentAHPage * itemsPerPage_);

        if ((!rset || rset->rowsCount() == 0) && currentAHPage != 0)
        {
            PChar->pushPacket<GP_SERV_COMMAND_CHAT_STD>(PChar, MESSAGE_SYSTEM_3, "Your listings changed. Returning to page 1.");

            // Reset to Page 1
            rset = db::preparedStmt("SELECT itemid, price, stack "
                                    "FROM auction_house "
                                    "WHERE seller = ? AND sale = 0 "
                                    "ORDER BY id ASC "
                                    "LIMIT ? OFFSET 0",
                                    PChar->id,
                                    itemsPerPage_);

            // Show Page 1 this time
            currentAHPage = 0;

            // Prepare Page 2 for next load
            PChar->SetLocalVar("AH_PAGE", (currentAHPage + 1) % totalPages);
        }

        const auto rowCount = rset ? rset->rowsCount() : 0;
        PChar->pushPacket<GP_SERV_COMMAND_CHAT_STD>(PChar, MESSAGE_SYSTEM_3, fmt::format("Current page: {} of {}. Showing {} item{}.", currentAHPage + 1, totalPages, rowCount, rowCount == 1 ? "" : "s"));

        if (rset)
        {
            FOR_DB_MULTIPLE_RESULTS(rset)
            {
                PChar->m_ah_history.emplace_back(AuctionHistory_t{
                    .itemid = rset->get<uint16>("itemid"),
                    .stack  = rset->get<uint8>("stack"),
                    .price  = rset->get<uint32>("price"),
                    .status = 0,
                });
            }
        }

        for (uint8 slot = 0; slot < clientSellSlots_; slot++)
        {
            PChar->pushPacket<GP_SERV_COMMAND_AUC>(GP_CLI_COMMAND_AUC_COMMAND::LotCancel, slot, PChar);
        }

        return true;
    }

    // The client's Sales Status window only has 7 sell slots.
    static constexpr uint8 clientSellSlots_{ 7 };

    // If this is set to 7, the client won't let you put up more than 7 items. So, 6.
    static constexpr uint32 itemsPerPage_{ 6 };

    bool enabled_{ false };
};

REGISTER_CPP_MODULE(AHPaginationModule);
