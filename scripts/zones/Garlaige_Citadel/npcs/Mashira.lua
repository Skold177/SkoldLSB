-----------------------------------
-- Area: Garlaige Citadel
--  NPC: Mashira
-- Involved in Quests: Rubbish Day, Making Amens!
-- !pos 141 -6 138 200
-----------------------------------
---@type TNpcEntity
local entity = {}

entity.onTrigger = function(player, npc)
    player:startEvent(11, -1, xi.item.BLOCK_OF_ANIMAL_GLUE, 140011, -1, 67381, -1, 669256, 0)
end

entity.onEventFinish = function(player, csid, option, npc)
    if
        csid == 11 and
        option == 1 and
        player:getQuestStatus(xi.questLog.JEUNO, xi.quest.id.jeuno.RUBBISH_DAY) == xi.questStatus.QUEST_ACCEPTED
    then
        player:delKeyItem(xi.ki.MAGIC_TRASH)
        player:setCharVar('RubbishDayVar', 1)
    end
end

return entity
