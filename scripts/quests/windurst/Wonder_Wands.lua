-----------------------------------
-- Wonder Wands
-----------------------------------
-- Log ID: 2, Quest ID: 48
-- Hakkuru-Rinkuru : !pos -111 -4 101 240
-- Kuroido-Moido   : !pos -112.5 -4.2 102.9 240
-----------------------------------

local quest = Quest:new(xi.questLog.WINDURST, xi.quest.id.windurst.WONDER_WANDS)

local wandItems = { xi.item.ROSE_WAND, xi.item.OAK_STAFF, xi.item.MYTHRIL_ROD }

quest.reward =
{
    fame     = 50,
    fameArea = xi.fameArea.WINDURST,
    gil      = 4800,
    item     = xi.item.NEW_MOON_ARMLETS,
    title    = xi.title.DOCTOR_SHANTOTTOS_GUINEA_PIG,
}

quest.sections =
{
    {
        check = function(player, status, vars)
            return status == xi.questStatus.QUEST_AVAILABLE and
                player:getQuestStatus(xi.questLog.WINDURST, xi.quest.id.windurst.MAKING_AMENS) == xi.questStatus.QUEST_COMPLETED and
                player:getFameLevel(xi.fameArea.WINDURST) >= 5 and
                not xi.quest.getMustZone(player, xi.questLog.WINDURST, xi.quest.id.windurst.MAKING_AMENS)
        end,

        [xi.zone.PORT_WINDURST] =
        {
            ['Hakkuru-Rinkuru'] = quest:progressEvent(259, 0, xi.item.ROSE_WAND, xi.item.OAK_STAFF, xi.item.MYTHRIL_ROD),

            onEventFinish =
            {
                [259] = function(player, csid, option, npc)
                    if option == 1 then
                        quest:begin(player)
                    end
                end,
            },
        },
    },

    {
        check = function(player, status, vars)
            return status == xi.questStatus.QUEST_ACCEPTED
        end,

        [xi.zone.PORT_WINDURST] =
        {
            ['Hakkuru-Rinkuru'] =
            {
                onTrigger = function(player, npc)
                    return quest:event(260, 0, xi.item.ROSE_WAND, xi.item.OAK_STAFF, xi.item.MYTHRIL_ROD)
                end,

                onTrade = function(player, npc, trade)
                    if npcUtil.tradeMatches(trade, { { xi.item.ROSE_WAND, 1 }, { xi.item.OAK_STAFF, 1 }, { xi.item.MYTHRIL_ROD, 1 } }) then
                        -- Shantotto destroys one of the three wands at random during the cutscene
                        local brokenWand = wandItems[math.randomInt(1, 3)]
                        player:setCharVar('[WonderWands]BrokenWand', brokenWand)
                        return quest:progressEvent(265, 4800, xi.item.ROSE_WAND, xi.item.OAK_STAFF, xi.item.MYTHRIL_ROD, brokenWand)
                    else
                        return quest:event(260, 0, xi.item.ROSE_WAND, xi.item.OAK_STAFF, xi.item.MYTHRIL_ROD)
                    end
                end,
            },

            ['Goltata']        = quest:event(257, 0, 0, xi.item.OAK_STAFF, xi.item.MYTHRIL_ROD),
            ['Kunchichi']      = quest:event(262),
            ['Kuroido-Moido']  = quest:event(261),
            ['Maabu-Sonbu']    = quest:event(264),
            ['Mojo-Pojo']      = quest:event(263),
            ['Ohruru']         = quest:event(258, 0, xi.item.ROSE_WAND, 5, xi.item.MYTHRIL_ROD),
            ['Yaman-Hachuman'] = quest:event(256, 0, 0, 5, xi.item.MYTHRIL_ROD),

            onEventFinish =
            {
                [265] = function(player, csid, option, npc)
                    if quest:complete(player) then
                        local brokenWand = player:getCharVar('[WonderWands]BrokenWand')
                        player:tradeComplete()

                        -- Only the broken wand is kept: the other two are returned without messages
                        for _, wandId in ipairs(wandItems) do
                            if wandId ~= brokenWand then
                                player:addItem(wandId)
                            end
                        end

                        player:setCharVar('SecondRewardVar', 0)
                    end
                end,
            },
        },
    },

    {
        check = function(player, status, vars)
            return status == xi.questStatus.QUEST_COMPLETED
        end,

        [xi.zone.PORT_WINDURST] =
        {
            ['Hakkuru-Rinkuru'] =
            {
                onTrigger = function(player, npc)
                    local brokenWand = player:getCharVar('[WonderWands]BrokenWand')
                    if brokenWand == 0 then
                        brokenWand = xi.item.MYTHRIL_ROD
                    end

                    return quest:event(267, 0, xi.item.ROSE_WAND, xi.item.OAK_STAFF, xi.item.MYTHRIL_ROD, brokenWand)
                end,
            },

            ['Goltata']        = quest:event(269),
            ['Kunchichi']      = quest:event(271),
            ['Kuroido-Moido']  = quest:event(266),
            ['Maabu-Sonbu']    = quest:event(273),
            ['Mojo-Pojo']      = quest:event(272),
            ['Ohruru']         = quest:event(270),
            ['Yaman-Hachuman'] = quest:event(268),

            onEventFinish =
            {
                [267] = function(player, csid, option, npc)
                    -- Players who completed the quest when the wand return was handled
                    -- here instead of in event 265 are still owed their two wands
                    if
                        player:getCharVar('SecondRewardVar') == 1 and
                        npcUtil.giveItem(player, { xi.item.ROSE_WAND, xi.item.OAK_STAFF })
                    then
                        player:setCharVar('SecondRewardVar', 0)
                    end
                end,
            },
        },
    },
}

return quest
