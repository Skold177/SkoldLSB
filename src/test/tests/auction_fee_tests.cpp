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

#include "common/settings.h"
#include "map/utils/auctionutils.h"

#include <catch2/catch_test_macros.hpp>

#include <array>
#include <atomic>
#include <utility>

namespace
{

class AuctionFeeSettings
{
public:
    AuctionFeeSettings()
    : savedSettings_(settings::settingsMap)
    {
        settings::set("map.AH_BASE_FEE_SINGLE", 7.0);
        settings::set("map.AH_BASE_FEE_STACKS", 19.0);
        settings::set("map.AH_TAX_RATE_SINGLE", 2.0);
        settings::set("map.AH_TAX_RATE_STACKS", 3.0);
        settings::set("map.AH_STARTER_CITY_BASE_FEE_SINGLE", -1.0);
        settings::set("map.AH_STARTER_CITY_BASE_FEE_STACKS", -1.0);
        settings::set("map.AH_STARTER_CITY_TAX_RATE_SINGLE", 0.5);
        settings::set("map.AH_STARTER_CITY_TAX_RATE_STACKS", 0.75);
        settings::set("map.AH_AL_ZAHBI_BASE_FEE_SINGLE", -1.0);
        settings::set("map.AH_AL_ZAHBI_BASE_FEE_STACKS", -1.0);
        settings::set("map.AH_AL_ZAHBI_TAX_RATE_SINGLE", 1.0);
        settings::set("map.AH_AL_ZAHBI_TAX_RATE_STACKS", 1.25);
        settings::set("map.AH_MAX_FEE", 10000.0);
    }

    ~AuctionFeeSettings()
    {
        settings::settingsMap = std::move(savedSettings_);
        settings::detail::generation.fetch_add(1, std::memory_order_release);
    }

private:
    settings::SettingsMap savedSettings_;
};

} // namespace

TEST_CASE_METHOD(AuctionFeeSettings, "Starter city auction houses use their single and stack tax rates", "[auction_fee]")
{
    const auto zones = std::array{
        xi::ZoneId::SouthernSanDoria,
        xi::ZoneId::PortSanDoria,
        xi::ZoneId::BastokMines,
        xi::ZoneId::BastokMarkets,
        xi::ZoneId::WindurstWalls,
        xi::ZoneId::WindurstWoods,
    };

    for (const auto zone : zones)
    {
        CAPTURE(static_cast<uint16_t>(zone));
        CHECK(auctionutils::CalculateFee(zone, 10000, false) == 57);
        CHECK(auctionutils::CalculateFee(zone, 10000, true) == 94);
    }
}

TEST_CASE_METHOD(AuctionFeeSettings, "Other zones retain global auction tax rates", "[auction_fee]")
{
    const auto zones = std::array{
        xi::ZoneId::RuludeGardens,
        xi::ZoneId::UpperJeuno,
        xi::ZoneId::LowerJeuno,
        xi::ZoneId::PortJeuno,
        xi::ZoneId::AhtUrhganWhitegate,
        xi::ZoneId::Nashmau,
        xi::ZoneId::TavnazianSafehold,
        xi::ZoneId::SouthernSanDoriaS,
        xi::ZoneId::BastokMarketsS,
        xi::ZoneId::WindurstWatersS,
        xi::ZoneId::NorthernSanDoria,
        xi::ZoneId::PortBastok,
        xi::ZoneId::WindurstWaters,
        xi::ZoneId::PortWindurst,
        xi::ZoneId::WestRonfaure,
    };

    for (const auto zone : zones)
    {
        CAPTURE(static_cast<uint16_t>(zone));
        CHECK(auctionutils::CalculateFee(zone, 10000, false) == 207);
        CHECK(auctionutils::CalculateFee(zone, 10000, true) == 319);
    }
}

TEST_CASE_METHOD(AuctionFeeSettings, "Al Zahbi tax rates are independent of Whitegate and starter cities", "[auction_fee]")
{
    CHECK(auctionutils::CalculateFee(xi::ZoneId::AlZahbi, 10000, false) == 107);
    CHECK(auctionutils::CalculateFee(xi::ZoneId::AlZahbi, 10000, true) == 144);
    CHECK(auctionutils::CalculateFee(xi::ZoneId::AhtUrhganWhitegate, 10000, false) == 207);
    CHECK(auctionutils::CalculateFee(xi::ZoneId::AhtUrhganWhitegate, 10000, true) == 319);
    CHECK(auctionutils::CalculateFee(xi::ZoneId::BastokMarkets, 10000, false) == 57);
    CHECK(auctionutils::CalculateFee(xi::ZoneId::BastokMarkets, 10000, true) == 94);
}

TEST_CASE_METHOD(AuctionFeeSettings, "Regional auction base fees use their own region and listing type", "[auction_fee]")
{
    settings::set("map.AH_STARTER_CITY_BASE_FEE_SINGLE", 11.0);
    settings::set("map.AH_STARTER_CITY_BASE_FEE_STACKS", 23.0);
    settings::set("map.AH_AL_ZAHBI_BASE_FEE_SINGLE", 31.0);
    settings::set("map.AH_AL_ZAHBI_BASE_FEE_STACKS", 47.0);

    for (const auto zone : { xi::ZoneId::SouthernSanDoria, xi::ZoneId::PortSanDoria, xi::ZoneId::BastokMines, xi::ZoneId::BastokMarkets, xi::ZoneId::WindurstWalls, xi::ZoneId::WindurstWoods })
    {
        CAPTURE(static_cast<uint16_t>(zone));
        CHECK(auctionutils::CalculateFee(zone, 10000, false) == 61);
        CHECK(auctionutils::CalculateFee(zone, 10000, true) == 98);
    }

    CHECK(auctionutils::CalculateFee(xi::ZoneId::AlZahbi, 10000, false) == 131);
    CHECK(auctionutils::CalculateFee(xi::ZoneId::AlZahbi, 10000, true) == 172);
    CHECK(auctionutils::CalculateFee(xi::ZoneId::AhtUrhganWhitegate, 10000, false) == 207);
    CHECK(auctionutils::CalculateFee(xi::ZoneId::AhtUrhganWhitegate, 10000, true) == 319);
}

TEST_CASE_METHOD(AuctionFeeSettings, "Inherited auction base fees update independently from regional tax rates", "[auction_fee]")
{
    REQUIRE(auctionutils::CalculateFee(xi::ZoneId::WindurstWoods, 10000, false) == 57);
    REQUIRE(auctionutils::CalculateFee(xi::ZoneId::WindurstWoods, 10000, true) == 94);
    REQUIRE(auctionutils::CalculateFee(xi::ZoneId::AlZahbi, 10000, false) == 107);
    REQUIRE(auctionutils::CalculateFee(xi::ZoneId::AlZahbi, 10000, true) == 144);

    settings::set("map.AH_BASE_FEE_SINGLE", 11.0);
    settings::set("map.AH_BASE_FEE_STACKS", 23.0);

    CHECK(auctionutils::CalculateFee(xi::ZoneId::WindurstWoods, 10000, false) == 61);
    CHECK(auctionutils::CalculateFee(xi::ZoneId::WindurstWoods, 10000, true) == 98);
    CHECK(auctionutils::CalculateFee(xi::ZoneId::AlZahbi, 10000, false) == 111);
    CHECK(auctionutils::CalculateFee(xi::ZoneId::AlZahbi, 10000, true) == 148);

    settings::set("map.AH_STARTER_CITY_BASE_FEE_SINGLE", 31.0);
    settings::set("map.AH_STARTER_CITY_TAX_RATE_SINGLE", -1.0);
    settings::set("map.AH_AL_ZAHBI_BASE_FEE_STACKS", 47.0);
    settings::set("map.AH_AL_ZAHBI_TAX_RATE_STACKS", -1.0);
    settings::set("map.AH_BASE_FEE_SINGLE", 13.0);
    settings::set("map.AH_BASE_FEE_STACKS", 29.0);

    CHECK(auctionutils::CalculateFee(xi::ZoneId::WindurstWoods, 10000, false) == 231);
    CHECK(auctionutils::CalculateFee(xi::ZoneId::WindurstWoods, 10000, true) == 104);
    CHECK(auctionutils::CalculateFee(xi::ZoneId::AlZahbi, 10000, false) == 113);
    CHECK(auctionutils::CalculateFee(xi::ZoneId::AlZahbi, 10000, true) == 347);
}

TEST_CASE_METHOD(AuctionFeeSettings, "Zero regional tax retains inherited base fees until they are also disabled", "[auction_fee]")
{
    settings::set("map.AH_STARTER_CITY_TAX_RATE_SINGLE", 0.0);
    settings::set("map.AH_STARTER_CITY_TAX_RATE_STACKS", 0.0);
    settings::set("map.AH_AL_ZAHBI_TAX_RATE_SINGLE", 0.0);
    settings::set("map.AH_AL_ZAHBI_TAX_RATE_STACKS", 0.0);

    for (const auto zone : { xi::ZoneId::SouthernSanDoria, xi::ZoneId::AlZahbi })
    {
        CAPTURE(static_cast<uint16_t>(zone));
        CHECK(auctionutils::CalculateFee(zone, 10000, false) == 7);
        CHECK(auctionutils::CalculateFee(zone, 10000, true) == 19);
    }

    CHECK(auctionutils::CalculateFee(xi::ZoneId::LowerJeuno, 10000, false) == 207);
    CHECK(auctionutils::CalculateFee(xi::ZoneId::LowerJeuno, 10000, true) == 319);

    settings::set("map.AH_STARTER_CITY_BASE_FEE_SINGLE", 0.0);
    settings::set("map.AH_STARTER_CITY_BASE_FEE_STACKS", 0.0);
    settings::set("map.AH_AL_ZAHBI_BASE_FEE_SINGLE", 0.0);
    settings::set("map.AH_AL_ZAHBI_BASE_FEE_STACKS", 0.0);

    for (const auto zone : { xi::ZoneId::SouthernSanDoria, xi::ZoneId::AlZahbi })
    {
        CAPTURE(static_cast<uint16_t>(zone));
        CHECK(auctionutils::CalculateFee(zone, 10000, false) == 0);
        CHECK(auctionutils::CalculateFee(zone, 10000, true) == 0);
    }

    CHECK(auctionutils::CalculateFee(xi::ZoneId::LowerJeuno, 10000, false) == 207);
    CHECK(auctionutils::CalculateFee(xi::ZoneId::LowerJeuno, 10000, true) == 319);
}

TEST_CASE_METHOD(AuctionFeeSettings, "Inherited auction tax rates follow updated global settings independently", "[auction_fee]")
{
    settings::set("map.AH_STARTER_CITY_TAX_RATE_SINGLE", -1.0);
    settings::set("map.AH_STARTER_CITY_TAX_RATE_STACKS", -1.0);
    settings::set("map.AH_AL_ZAHBI_TAX_RATE_SINGLE", -1.0);
    settings::set("map.AH_AL_ZAHBI_TAX_RATE_STACKS", -1.0);

    for (const auto zone : { xi::ZoneId::WindurstWoods, xi::ZoneId::AlZahbi })
    {
        CAPTURE(static_cast<uint16_t>(zone));
        REQUIRE(auctionutils::CalculateFee(zone, 10000, false) == 207);
        REQUIRE(auctionutils::CalculateFee(zone, 10000, true) == 319);
    }

    settings::set("map.AH_TAX_RATE_SINGLE", 4.0);
    settings::set("map.AH_TAX_RATE_STACKS", 6.0);

    for (const auto zone : { xi::ZoneId::WindurstWoods, xi::ZoneId::AlZahbi })
    {
        CAPTURE(static_cast<uint16_t>(zone));
        CHECK(auctionutils::CalculateFee(zone, 10000, false) == 407);
        CHECK(auctionutils::CalculateFee(zone, 10000, true) == 619);
    }

    settings::set("map.AH_STARTER_CITY_TAX_RATE_SINGLE", 0.5);
    settings::set("map.AH_AL_ZAHBI_TAX_RATE_STACKS", 0.0);

    CHECK(auctionutils::CalculateFee(xi::ZoneId::WindurstWoods, 10000, false) == 57);
    CHECK(auctionutils::CalculateFee(xi::ZoneId::WindurstWoods, 10000, true) == 619);
    CHECK(auctionutils::CalculateFee(xi::ZoneId::AlZahbi, 10000, false) == 407);
    CHECK(auctionutils::CalculateFee(xi::ZoneId::AlZahbi, 10000, true) == 19);
}

TEST_CASE_METHOD(AuctionFeeSettings, "Auction fees truncate fractional gil after adding the base fee", "[auction_fee]")
{
    settings::set("map.AH_TAX_RATE_SINGLE", 1.0);
    settings::set("map.AH_TAX_RATE_STACKS", 2.5);
    settings::set("map.AH_STARTER_CITY_TAX_RATE_SINGLE", 1.0);
    settings::set("map.AH_STARTER_CITY_TAX_RATE_STACKS", 2.5);
    settings::set("map.AH_AL_ZAHBI_TAX_RATE_SINGLE", 1.0);
    settings::set("map.AH_AL_ZAHBI_TAX_RATE_STACKS", 2.5);

    for (const auto zone : { xi::ZoneId::BastokMines, xi::ZoneId::AlZahbi, xi::ZoneId::LowerJeuno })
    {
        CAPTURE(static_cast<uint16_t>(zone));
        CHECK(auctionutils::CalculateFee(zone, 199, false) == 8);
        CHECK(auctionutils::CalculateFee(zone, 199, true) == 23);
        CHECK(auctionutils::CalculateFee(zone, 0, false) == 7);
        CHECK(auctionutils::CalculateFee(zone, 0, true) == 19);
    }
}

TEST_CASE_METHOD(AuctionFeeSettings, "The auction fee cap applies to every region and listing type", "[auction_fee]")
{
    SECTION("Regional base fee overrides share the same cap")
    {
        settings::set("map.AH_STARTER_CITY_BASE_FEE_SINGLE", 100.0);
        settings::set("map.AH_STARTER_CITY_BASE_FEE_STACKS", 200.0);
        settings::set("map.AH_AL_ZAHBI_BASE_FEE_SINGLE", 300.0);
        settings::set("map.AH_AL_ZAHBI_BASE_FEE_STACKS", 400.0);
        settings::set("map.AH_MAX_FEE", 50.0);

        for (const auto zone : { xi::ZoneId::PortSanDoria, xi::ZoneId::AlZahbi })
        {
            CAPTURE(static_cast<uint16_t>(zone));
            CHECK(auctionutils::CalculateFee(zone, 0, false) == 50);
            CHECK(auctionutils::CalculateFee(zone, 0, true) == 50);
            CHECK(auctionutils::CalculateFee(zone, 10000, false) == 50);
            CHECK(auctionutils::CalculateFee(zone, 10000, true) == 50);
        }
    }

    SECTION("Tax and base fees share the same cap")
    {
        settings::set("map.AH_MAX_FEE", 50.0);

        for (const auto zone : { xi::ZoneId::PortSanDoria, xi::ZoneId::AlZahbi, xi::ZoneId::LowerJeuno })
        {
            CAPTURE(static_cast<uint16_t>(zone));
            CHECK(auctionutils::CalculateFee(zone, 10000, false) == 50);
            CHECK(auctionutils::CalculateFee(zone, 10000, true) == 50);
        }
    }

    SECTION("The cap can be lower than the base fees")
    {
        settings::set("map.AH_MAX_FEE", 5.0);

        for (const auto zone : { xi::ZoneId::PortSanDoria, xi::ZoneId::AlZahbi, xi::ZoneId::LowerJeuno })
        {
            CAPTURE(static_cast<uint16_t>(zone));
            CHECK(auctionutils::CalculateFee(zone, 0, false) == 5);
            CHECK(auctionutils::CalculateFee(zone, 0, true) == 5);
        }
    }

    SECTION("A zero cap makes all listings free")
    {
        settings::set("map.AH_MAX_FEE", 0.0);

        for (const auto zone : { xi::ZoneId::PortSanDoria, xi::ZoneId::AlZahbi, xi::ZoneId::LowerJeuno })
        {
            CAPTURE(static_cast<uint16_t>(zone));
            CHECK(auctionutils::CalculateFee(zone, 10000, false) == 0);
            CHECK(auctionutils::CalculateFee(zone, 10000, true) == 0);
        }
    }
}

TEST_CASE_METHOD(AuctionFeeSettings, "Auction settings can reproduce the May 2006 Jeuno and Al Zahbi fee schedules", "[auction_fee]")
{
    settings::set("map.AH_BASE_FEE_SINGLE", 50.0);
    settings::set("map.AH_BASE_FEE_STACKS", 200.0);
    settings::set("map.AH_TAX_RATE_SINGLE", 1.0);
    settings::set("map.AH_TAX_RATE_STACKS", 0.5);
    settings::set("map.AH_AL_ZAHBI_BASE_FEE_SINGLE", 100.0);
    settings::set("map.AH_AL_ZAHBI_BASE_FEE_STACKS", 400.0);
    settings::set("map.AH_AL_ZAHBI_TAX_RATE_SINGLE", -1.0);
    settings::set("map.AH_AL_ZAHBI_TAX_RATE_STACKS", -1.0);

    for (const auto zone : { xi::ZoneId::LowerJeuno, xi::ZoneId::Nashmau, xi::ZoneId::TavnazianSafehold })
    {
        CAPTURE(static_cast<uint16_t>(zone));
        CHECK(auctionutils::CalculateFee(zone, 10000, false) == 150);
        CHECK(auctionutils::CalculateFee(zone, 10000, true) == 250);
    }

    CHECK(auctionutils::CalculateFee(xi::ZoneId::AlZahbi, 10000, false) == 200);
    CHECK(auctionutils::CalculateFee(xi::ZoneId::AlZahbi, 10000, true) == 450);
    CHECK(auctionutils::CalculateFee(xi::ZoneId::AhtUrhganWhitegate, 10000, false) == 150);
    CHECK(auctionutils::CalculateFee(xi::ZoneId::AhtUrhganWhitegate, 10000, true) == 250);
}
