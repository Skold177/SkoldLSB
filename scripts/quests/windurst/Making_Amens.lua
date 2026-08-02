-----------------------------------
-- Making Amens!
-----------------------------------
-- Log ID: 2, Quest ID: 8
-- Kuroido-Moido   : !pos -112.5 -4.2 102.9 240
-- Hakkuru-Rinkuru : !pos -111 -4 101 240
-- Mashira         : !pos 141 -6 138 200
-----------------------------------

local quest = Quest:new(xi.questLog.WINDURST, xi.quest.id.windurst.MAKING_AMENS)

quest.reward =
{
    fame     = 40,
    fameArea = xi.fameArea.WINDURST,
    gil      = 6000,
    title    = xi.title.HAKKURU_RINKURUS_BENEFACTOR,
}

quest.sections =
{
    {
        check = function(player, status, vars)
            return status == xi.questStatus.QUEST_AVAILABLE and
                player:getQuestStatus(xi.questLog.WINDURST, xi.quest.id.windurst.MAKING_AMENDS) == xi.questStatus.QUEST_COMPLETED and
                player:getFameLevel(xi.fameArea.WINDURST) >= 4 and
                not xi.quest.getMustZone(player, xi.questLog.WINDURST, xi.quest.id.windurst.MAKING_AMENDS)
        end,

        [xi.zone.PORT_WINDURST] =
        {
            ['Kuroido-Moido'] = quest:progressEvent(280),

            onEventFinish =
            {
                [280] = function(player, csid, option, npc)
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
            ['Hakkuru-Rinkuru'] = quest:event(282),

            ['Kuroido-Moido'] =
            {
                onTrigger = function(player, npc)
                    if player:hasKeyItem(xi.ki.BROKEN_WAND) then
                        return quest:progressEvent(284)
                    else
                        return quest:event(283)
                    end
                end,
            },

            onEventFinish =
            {
                [284] = function(player, csid, option, npc)
                    if quest:complete(player) then
                        player:delKeyItem(xi.ki.BROKEN_WAND)
                        quest:setMustZone(player)
                    end
                end,
            },
        },

        [xi.zone.GARLAIGE_CITADEL] =
        {
            ['Mashira'] =
            {
                onTrigger = function(player, npc)
                    if not player:hasKeyItem(xi.ki.BROKEN_WAND) then
                        return quest:progressEvent(11, -1, xi.item.BLOCK_OF_ANIMAL_GLUE, 140011, -1, 67381, -1, 669256, 0)
                    end
                end,
            },

            onEventFinish =
            {
                [11] = function(player, csid, option, npc)
                    if
                        option == 0 and
                        not player:hasKeyItem(xi.ki.BROKEN_WAND)
                    then
                        npcUtil.giveKeyItem(player, xi.ki.BROKEN_WAND)
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
            ['Kuroido-Moido'] =
            {
                onTrigger = function(player, npc)
                    if player:getQuestStatus(xi.questLog.WINDURST, xi.quest.id.windurst.WONDER_WANDS) == xi.questStatus.QUEST_AVAILABLE then
                        return quest:event(286, 0, xi.item.BLOCK_OF_ANIMAL_GLUE):replaceDefault()
                    end
                end,
            },
        },
    },
}

return quest
