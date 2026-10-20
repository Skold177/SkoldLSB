-----------------------------------
-- Bait and Switch
-- https://wiki.ffo.jp/html/1357.html
-- https://wiki.ffo.jp/html/12578.html
-----------------------------------
-- Log ID: 1, Quest ID: 83
-- Salim          : !pos -59.290 -10.000 21.780 237
-- ???            : !pos -22.235 6.847 0.060 237
-- Small Switch   : !pos -57.584 1.740 21.920 237
-- Medium Switch  : !pos -31.176 -1.000 0.043 237
-- Large Switch   : !pos -93.831 0.953 0.072 237
-- Folzen         : !pos -92.114 2.000 8.530 237
-- Darha          : !pos -77.922 2.000 21.201 237
-- Helmut         : !pos -70.334 1.999 -5.143 237
-- Hungry Wolf    : !pos -25.861 -10.000 -30.172 237
-- Striking Snake : !pos -15.700 -9.244 19.658 237
-- Ferghus        : !pos -23.092 -10.000 -27.157 237
-- Grohm          : !pos -18.084 -10.000 -27.576 237
-- Dark Clouds    : !pos -85.442 2.000 -3.592 237
-----------------------------------
local metalID = zones[xi.zone.METALWORKS]
-----------------------------------

local quest = Quest:new(xi.questLog.BASTOK, xi.quest.id.bastok.BAIT_AND_SWITCH)

quest.reward = {}

-- Order of the tools in the event 900 menu. Also sent to every event as param 2.
local tool =
{
    SCOPE        = 1,
    BARDS_HARP   = 2,
    GUARDSMAN_ID = 3,
    SNARES       = 4,
    LUCKY_CHARM  = 5,
    POCKET_WATCH = 6,
    COSTUME_KIT  = 7,
}

local toolReward =
{
    [tool.SCOPE]        = xi.item.POT_OF_SILENT_OIL,
    [tool.BARDS_HARP]   = xi.item.PINCH_OF_PRISM_POWDER,
    [tool.GUARDSMAN_ID] = xi.item.HI_POTION,
    [tool.SNARES]       = xi.item.HI_ETHER,
    [tool.LUCKY_CHARM]  = xi.item.KEY_RING_BELT,
    [tool.POCKET_WATCH] = xi.item.HERMES_QUENCHER,
    [tool.COSTUME_KIT]  = xi.item.ICARUS_WING,
}

local progress =
{
    NONE      = 0,
    REQUESTED = 1, -- Salim asked for the friar to be chased off.
    SWITCHES  = 2, -- The letter is out. The trap switches are live.
    FAILED    = 3, -- Left the Metalworks, ran out of time or was caught a third time.
    TRAP_OFF  = 4, -- Every switch is pressed.
    REWARD    = 5, -- The reward did not fit. The ??? holds it until the player zones.
}

local thief =
{
    LUTO   = 1,
    MILEDO = 2,
}

local rescue =
{
    ASK_FERGHUS = 0,
    ASK_FOLZEN  = 1,
    ASK_HELMUT  = 2, -- Costume kit only. Helmut names the key holder.
    GET_KEY     = 3, -- Costume kit only. The key holder lends the key.
}

-- Event 915 returns the key holder.
local keyHolder =
{
    HUNGRY_WOLF    = 1,
    DARHA          = 2,
    STRIKING_SNAKE = 3,
}

-- Each NPC only gives their hint once per attempt.
local hintBit =
{
    ['Folzen']         = 0,
    ['Darha']          = 1,
    ['Helmut']         = 2,
    ['Hungry_Wolf']    = 3,
    ['Striking_Snake'] = 4,
    ['Ferghus']        = 5,
}

-- location is what the switch events compare against param 7: 1 the kiln, 2 the Cermet Refinery
-- and 3 the Metalworks replica. snareBit is the bit event 900 sets when a snare is laid there.
local switchInfo =
{
    ['Small_Switch']  = { letter = 'S', event = 908, location = 2, snareBit = 11 },
    ['Medium_Switch'] = { letter = 'M', event = 909, location = 3, snareBit = 12 },
    ['Large_Switch']  = { letter = 'L', event = 910, location = 1, snareBit = 9 },
}

-- Darha is sent the first switch and Striking Snake the last.
local hintSwitch = { S = 1, M = 2, L = 3 }

-- Switch orders, S M L being the Small, Medium and Large Switch. hungryWolf and helmut are the
-- hint each of them is sent for that order.
local eightPressOrders =
{
    { order = 'SMLMSLMM', hungryWolf = 1, helmut = 1 },
    { order = 'LMSSSMLM', hungryWolf = 2, helmut = 2 },
    { order = 'SLMMMSLL', hungryWolf = 3, helmut = 3 },
    { order = 'MSLSMLSL', hungryWolf = 4, helmut = 4 },
    { order = 'MLSLLSMS', hungryWolf = 5, helmut = 5 },
    { order = 'LSMSLMSS', hungryWolf = 1, helmut = 6 },
}

local switchOrders =
{
    [tool.SCOPE] =
    {
        { order = 'SML', hungryWolf = 2 },
        { order = 'SLM', hungryWolf = 3 },
        { order = 'MSL', hungryWolf = 1 },
        { order = 'MLS', hungryWolf = 3 },
        { order = 'LSM', hungryWolf = 1 },
        { order = 'LMS', hungryWolf = 2 },
    },

    -- Unverified. Retail orders for the harp are not published. These are presses three to six of
    -- the lead guardsman's ID orders, which contain the one captured harp order (SLSM).
    [tool.BARDS_HARP] =
    {
        { order = 'LSLM', hungryWolf = 1, helmut = 3 },
        { order = 'SLSM', hungryWolf = 2, helmut = 1 },
        { order = 'SSML', hungryWolf = 3, helmut = 1 },
        { order = 'MMSL', hungryWolf = 4, helmut = 2 },
        { order = 'MLMS', hungryWolf = 5, helmut = 2 },
        { order = 'LMLS', hungryWolf = 6, helmut = 3 },
    },

    -- The eight press orders without the fourth and eighth press.
    [tool.GUARDSMAN_ID] =
    {
        { order = 'LMSSML', hungryWolf = 1, helmut = 1 },
        { order = 'SLMMSL', hungryWolf = 2, helmut = 2 },
        { order = 'MLSLSM', hungryWolf = 3, helmut = 3 },
        { order = 'LSMLMS', hungryWolf = 4, helmut = 4 },
        { order = 'SMLSLM', hungryWolf = 5, helmut = 5 },
        { order = 'MSLMLS', hungryWolf = 5, helmut = 6 },
    },

    [tool.SNARES]       = eightPressOrders,
    [tool.LUCKY_CHARM]  = eightPressOrders,
    [tool.POCKET_WATCH] = eightPressOrders,

    -- Unverified. Retail orders for the costume kit are not published. These follow the hints, with
    -- each order opening on a different set of three switches like the published orders.
    -- LSMSLSMLMS is a reported retail order.
    [tool.COSTUME_KIT] =
    {
        { order = 'SMLMSMLSLM', hungryWolf = 1, helmut = 1 },
        { order = 'MLSLMLSLSM', hungryWolf = 2, helmut = 2 },
        { order = 'LMSSLMSSML', hungryWolf = 3, helmut = 3 },
        { order = 'LSMSLSMLMS', hungryWolf = 4, helmut = 4 },
        { order = 'SLMMSLMMSL', hungryWolf = 5, helmut = 5 },
        { order = 'MSLSMSLMLS', hungryWolf = 1, helmut = 1 },
    },
}

local function hasFinishedTool(player, toolId)
    return utils.mask.getBit(quest:getVar(player, 'Tools'), toolId)
end

-- Luto greets the player by name once she knows them from the fellow quests or an earlier job.
local function knowsLuto(player)
    return player:hasCompletedQuest(quest.areaId, quest.questId) or
        player:getQuestStatus(xi.questLog.JEUNO, xi.quest.id.jeuno.UNLISTED_QUALITIES) ~= xi.questStatus.QUEST_AVAILABLE
end

-- The guest NPC for a tool only appears until the quest has been finished with that tool.
local function isGuestActive(player)
    return not hasFinishedTool(player, quest:getVar(player, 'Tool'))
end

-- The seventh tool needs the other six finished and the costume kit from Chameleon Capers.
local function isCostumeKitAvailable(player)
    for toolId = tool.SCOPE, tool.POCKET_WATCH do
        if not hasFinishedTool(player, toolId) then
            return false
        end
    end

    return player:hasKeyItem(xi.keyItem.COSTUME_KIT)
end

local function isTimeUp(vars)
    return vars.Tool == tool.POCKET_WATCH and GetSystemTime() >= vars.Timer
end

local function getSwitchOrder(player)
    return switchOrders[quest:getVar(player, 'Tool')][quest:getVar(player, 'Order')]
end

local function getHint(player, npcName)
    local entry = getSwitchOrder(player)

    if npcName == 'Darha' then
        return hintSwitch[entry.order:sub(1, 1)]
    elseif npcName == 'Striking_Snake' then
        return hintSwitch[entry.order:sub(-1)]
    elseif npcName == 'Hungry_Wolf' then
        return entry.hungryWolf
    elseif npcName == 'Helmut' then
        return entry.helmut
    end

    return 0
end

local function isNextSwitch(player, letter)
    local step = quest:getVar(player, 'Step') + 1

    return getSwitchOrder(player).order:sub(step, step) == letter
end

-- Clears the current attempt. Finished tools and the conquest wait carry over.
local function resetAttempt(player)
    local tools = quest:getVar(player, 'Tools')
    local wait  = quest:getVar(player, 'Wait')

    quest:cleanup(player)
    quest:setVar(player, 'Tools', tools)
    quest:setVar(player, 'Wait', wait)
end

local function acceptRequest(player)
    resetAttempt(player)
    quest:begin(player)
    quest:setVar(player, 'Prog', progress.REQUESTED)
end

-- Giving up at the ??? takes the quest off the log. A quest finished before stays finished.
local function giveUp(player)
    resetAttempt(player)
    player:delCurrentQuest(quest.areaId, quest.questId)
end

-- Event 900 returns the tool. The lucky charm returns 4 to 6 for where the lead guardsman starts.
-- The snares return a mask of where they were laid, which is 0 if none were.
local function startAttempt(player, option)
    local chosenTool = tool.SNARES

    if option >= tool.SCOPE and option <= tool.GUARDSMAN_ID then
        chosenTool = option
    elseif option >= 4 and option <= 6 then
        chosenTool = tool.LUCKY_CHARM
        quest:setVar(player, 'Beast', option - 3)
    elseif option == 7 then
        chosenTool = tool.POCKET_WATCH
        quest:setVar(player, 'Timer', GetSystemTime() + 3600)
    elseif option == 8 then
        if not isCostumeKitAvailable(player) then
            return
        end

        chosenTool = tool.COSTUME_KIT
    else
        quest:setVar(player, 'Snares', option)
    end

    quest:setVar(player, 'Tool', chosenTool)
    quest:setVar(player, 'Order', math.random(1, #switchOrders[chosenTool]))
    quest:setVar(player, 'Story', isGuestActive(player) and 1 or 0)
    quest:setVar(player, 'Prog', progress.SWITCHES)
end

-- The third capture calls the job off.
local function captureThief(player, captured)
    local caught = quest:getVar(player, 'Caught')

    if caught >= 2 then
        quest:setVar(player, 'Prog', progress.FAILED)
        return
    end

    quest:setVar(player, 'Caught', caught + 1)
    quest:setVar(player, 'Jailed', captured)
end

local function releaseThief(player)
    quest:setVar(player, 'Jailed', 0)
    quest:setVar(player, 'Rescue', rescue.ASK_FERGHUS)
    quest:setVar(player, 'Holder', 0)
end

local function isAtRescueStep(player, step)
    return quest:getVar(player, 'Prog') == progress.SWITCHES and
        quest:getVar(player, 'Jailed') ~= 0 and
        quest:getVar(player, 'Rescue') == step
end

-- A wrong switch silently undoes every switch pressed so far. The order stays the same.
local function pressSwitch(player, npc, letter)
    if not isNextSwitch(player, letter) then
        quest:setVar(player, 'Step', 0)
        return
    end

    local step = quest:getVar(player, 'Step') + 1

    if step == #getSwitchOrder(player).order then
        quest:setVar(player, 'Prog', progress.TRAP_OFF)
        player:messageText(npc, metalID.text.NOISE_FROM_TEMPLE, false, 6)
    else
        quest:setVar(player, 'Step', step)
        player:messageText(npc, metalID.text.FIRST_SWITCH_DEACTIVATED + step - 1, false, 6)
    end
end

-- Param 7 of a switch event is the switch location when a laid snare or the lead guardsman is
-- there, or 4 when one is there but fails.
local function getSwitchState(player, info)
    local currentTool = quest:getVar(player, 'Tool')

    if currentTool == tool.SNARES then
        local snares = quest:getVar(player, 'Snares')

        if not utils.mask.getBit(snares, info.snareBit) then
            return 0
        end

        -- Laying four or more snares gets them noticed.
        return utils.mask.countBits(snares) >= 4 and 4 or info.location
    end

    if
        currentTool == tool.LUCKY_CHARM and
        quest:getVar(player, 'Beast') == info.location
    then
        -- The lucky charm only moves the lead guardsman away from the next correct switch.
        return isNextSwitch(player, info.letter) and info.location or 4
    end

    return 0
end

local function getRequestEvent(player)
    -- After the first job, Miledo-Shiraddo poses as a bard instead of a friar.
    return quest:progressEvent(899, { [6] = player:hasCompletedQuest(quest.areaId, quest.questId) and 2 or 0 })
end

local function getHintEvent(player, npcName, eventId)
    if
        quest:getVar(player, 'Prog') ~= progress.SWITCHES or
        quest:getVar(player, 'Jailed') ~= 0 or
        quest:isVarBitsSet(player, 'Heard', hintBit[npcName])
    then
        return
    end

    local currentTool = quest:getVar(player, 'Tool')

    return quest:progressEvent(eventId, {
        [0] = currentTool == tool.SCOPE and isGuestActive(player) and 1 or 0, -- Bumimi
        [2] = currentTool,
        [3] = getHint(player, npcName),
    })
end

-- With the costume kit, the hint only counts once the right disguise was used.
local function onHintFinish(player, option, npcName)
    if
        quest:getVar(player, 'Tool') == tool.COSTUME_KIT and
        option ~= 1
    then
        return
    end

    quest:setVarBit(player, 'Heard', hintBit[npcName])
end

local function getKeyHolderEvent(player, holder, eventId)
    if
        not isAtRescueStep(player, rescue.GET_KEY) or
        quest:getVar(player, 'Holder') ~= holder
    then
        return
    end

    return quest:progressEvent(eventId, { [1] = quest:getVar(player, 'Jailed') == thief.MILEDO and 1 or 2 })
end

local function onKeyHolderFinish(player, csid, option, npc)
    if option == 1 then
        releaseThief(player)
    end
end

-- Grohm and Dark Clouds are guardsmen in disguise. The scope warns the player off them.
local function getDisguisedGuardEvent(player, eventId)
    if
        quest:getVar(player, 'Prog') ~= progress.SWITCHES or
        quest:getVar(player, 'Jailed') ~= 0 or
        quest:getVar(player, 'Tool') ~= tool.SCOPE
    then
        return
    end

    return quest:progressEvent(eventId, { [0] = quest:getVar(player, 'Caught') >= 2 and 1 or 0 })
end

local function onSwitchTrigger(player, npc)
    if
        quest:getVar(player, 'Prog') ~= progress.SWITCHES or
        quest:getVar(player, 'Jailed') ~= 0
    then
        return
    end

    local info = switchInfo[npc:getName()]

    return quest:progressEvent(info.event, {
        [1] = quest:getVar(player, 'Caught') >= 2 and 1 or 0,
        [2] = quest:getVar(player, 'Tool'),
        [5] = quest:getVar(player, 'Story'),
        [6] = knowsLuto(player) and 1 or 0,
        [7] = getSwitchState(player, info),
    })
end

-- Result bits: 1 switch pressed, 2 Miledo-Shiraddo caught, 3 Luto caught, 4 to 6 where the lead
-- guardsman goes next, 7 to 9 which guest scene played, 10 the guard paid 10 gil for a song.
local function onSwitchFinish(player, csid, option, npc)
    if
        utils.mask.getBit(option, 10) and
        quest:getVar(player, 'Tool') == tool.BARDS_HARP and
        quest:getVar(player, 'Story') > 0
    then
        player:addGil(10)
    end

    for scene = 1, 3 do
        if utils.mask.getBit(option, scene + 6) then
            quest:setVar(player, 'Story', scene < 3 and scene + 1 or 0)
        end
    end

    for location = 1, 3 do
        if utils.mask.getBit(option, location + 3) then
            quest:setVar(player, 'Beast', location)
        end
    end

    if utils.mask.getBit(option, 2) then
        captureThief(player, thief.MILEDO)
    elseif utils.mask.getBit(option, 3) then
        captureThief(player, thief.LUTO)
    elseif utils.mask.getBit(option, 1) then
        pressSwitch(player, npc, switchInfo[npc:getName()].letter)
    end
end

-- Param 6 of event 900: 2 after the first job, 1 when Luto knows the player.
local function getFamiliarity(player)
    if player:hasCompletedQuest(quest.areaId, quest.questId) then
        return 2
    end

    return knowsLuto(player) and 1 or 0
end

-- Param 6 of event 920: 2 when the player signed the letter, which they do once the costume kit
-- job is done, 1 when Luto knows the player.
local function getLetterSigners(player)
    if hasFinishedTool(player, tool.COSTUME_KIT) then
        return 2
    end

    return knowsLuto(player) and 1 or 0
end

-- If the reward does not fit, the ??? keeps it until the player makes room. Zoning forfeits it.
local function giveReward(player)
    local currentTool = quest:getVar(player, 'Tool')

    if not npcUtil.giveItem(player, toolReward[currentTool]) then
        quest:setVar(player, 'Prog', progress.REWARD)
        return
    end

    local tools = utils.mask.setBit(quest:getVar(player, 'Tools'), currentTool, true)

    quest:complete(player)
    player:delCurrentQuest(quest.areaId, quest.questId)
    quest:setVar(player, 'Tools', tools)
    quest:setVar(player, 'Wait', NextConquestTally())

    -- The costume kit is used up. Getting it again from Chameleon Capers reopens the seventh tool.
    if currentTool == tool.COSTUME_KIT then
        player:delKeyItem(xi.keyItem.COSTUME_KIT)
    end
end

-- Leaving the Metalworks once the letter is out ends the attempt. Logging out does not.
local function onLeaveMetalworks(player)
    if player:getStatus() ~= xi.status.SHUTDOWN then
        quest:setVar(player, 'Prog', progress.FAILED)
    end
end

quest.sections =
{
    -- Section: Salim's request. Repeatable once per conquest tally.
    {
        check = function(player, status, vars)
            return vars.Prog == progress.NONE and
                vars.Wait < NextConquestTally() and
                player:getFameLevel(xi.fameArea.BASTOK) >= 3
        end,

        [xi.zone.METALWORKS] =
        {
            ['Salim'] =
            {
                onTrigger = function(player, npc)
                    return getRequestEvent(player)
                end,
            },

            onEventFinish =
            {
                [899] = function(player, csid, option, npc)
                    acceptRequest(player)
                end,
            },
        },
    },

    -- Section: Meet the thieves at the Temple of the Goddess and pick a tool.
    {
        check = function(player, status, vars)
            return vars.Prog == progress.REQUESTED
        end,

        [xi.zone.METALWORKS] =
        {
            ['Salim'] =
            {
                onTrigger = function(player, npc)
                    return getRequestEvent(player)
                end,
            },

            ['qm4'] =
            {
                onTrigger = function(player, npc)
                    return quest:progressEvent(900, {
                        [1] = hasFinishedTool(player, tool.COSTUME_KIT) and 2 or 0, -- Player leaves the letter.
                        [5] = isCostumeKitAvailable(player) and 1 or 0,
                        [6] = getFamiliarity(player),
                    })
                end,
            },

            onEventFinish =
            {
                [899] = function(player, csid, option, npc)
                    acceptRequest(player)
                end,

                [900] = function(player, csid, option, npc)
                    if option == utils.EVENT_CANCELLED_OPTION then
                        return
                    end

                    startAttempt(player, option)
                end,
            },
        },
    },

    -- Section: Gather hints, get past the guards and press the switches.
    {
        check = function(player, status, vars)
            return (vars.Prog == progress.SWITCHES or vars.Prog == progress.TRAP_OFF) and
                not isTimeUp(vars)
        end,

        [xi.zone.METALWORKS] =
        {
            ['Salim'] =
            {
                onTrigger = function(player, npc)
                    return quest:event(901, { [2] = quest:getVar(player, 'Tool') })
                end,
            },

            ['qm4'] =
            {
                onTrigger = function(player, npc)
                    if quest:getVar(player, 'Prog') ~= progress.TRAP_OFF then
                        return quest:progressEvent(907)
                    end

                    return quest:progressEvent(920, {
                        [2] = isGuestActive(player) and quest:getVar(player, 'Tool') or 0,
                        [6] = getLetterSigners(player),
                    })
                end,
            },

            ['Small_Switch'] =
            {
                onTrigger = onSwitchTrigger,
            },

            ['Medium_Switch'] =
            {
                onTrigger = onSwitchTrigger,
            },

            ['Large_Switch'] =
            {
                onTrigger = onSwitchTrigger,
            },

            ['Folzen'] =
            {
                onTrigger = function(player, npc)
                    if not isAtRescueStep(player, rescue.ASK_FOLZEN) then
                        return getHintEvent(player, 'Folzen', 902)
                    end

                    -- With the costume kit, Folzen only saw the key handed to someone.
                    if quest:getVar(player, 'Tool') == tool.COSTUME_KIT then
                        return quest:progressEvent(914)
                    end

                    return quest:progressEvent(916, {
                        [2] = quest:getVar(player, 'Tool'),
                        [6] = quest:getVar(player, 'Jailed') == thief.LUTO and 2 or 3,
                    })
                end,
            },

            ['Darha'] =
            {
                onTrigger = function(player, npc)
                    return getKeyHolderEvent(player, keyHolder.DARHA, 918) or
                        getHintEvent(player, 'Darha', 906)
                end,
            },

            ['Helmut'] =
            {
                onTrigger = function(player, npc)
                    if isAtRescueStep(player, rescue.ASK_HELMUT) then
                        return quest:progressEvent(915)
                    end

                    -- Helmut has no hint for the scope.
                    if quest:getVar(player, 'Tool') == tool.SCOPE then
                        return
                    end

                    return getHintEvent(player, 'Helmut', 904)
                end,
            },

            ['Hungry_Wolf'] =
            {
                onTrigger = function(player, npc)
                    return getKeyHolderEvent(player, keyHolder.HUNGRY_WOLF, 917) or
                        getHintEvent(player, 'Hungry_Wolf', 905)
                end,
            },

            ['Striking_Snake'] =
            {
                onTrigger = function(player, npc)
                    return getKeyHolderEvent(player, keyHolder.STRIKING_SNAKE, 919) or
                        getHintEvent(player, 'Striking_Snake', 903)
                end,
            },

            ['Ferghus'] =
            {
                onTrigger = function(player, npc)
                    if
                        quest:getVar(player, 'Prog') == progress.SWITCHES and
                        quest:getVar(player, 'Jailed') ~= 0
                    then
                        return quest:progressEvent(923, { [2] = quest:getVar(player, 'Tool') })
                    end

                    return getHintEvent(player, 'Ferghus', 913)
                end,
            },

            ['Grohm'] =
            {
                onTrigger = function(player, npc)
                    return getDisguisedGuardEvent(player, 921)
                end,
            },

            ['Dark_Clouds'] =
            {
                onTrigger = function(player, npc)
                    return getDisguisedGuardEvent(player, 922)
                end,
            },

            onEventFinish =
            {
                [902] = function(player, csid, option, npc)
                    onHintFinish(player, option, 'Folzen')
                end,

                [903] = function(player, csid, option, npc)
                    onHintFinish(player, option, 'Striking_Snake')
                end,

                [904] = function(player, csid, option, npc)
                    onHintFinish(player, option, 'Helmut')
                end,

                [905] = function(player, csid, option, npc)
                    onHintFinish(player, option, 'Hungry_Wolf')
                end,

                [906] = function(player, csid, option, npc)
                    onHintFinish(player, option, 'Darha')
                end,

                [907] = function(player, csid, option, npc)
                    if option == 1 then
                        giveUp(player)
                    end
                end,

                [908] = onSwitchFinish,
                [909] = onSwitchFinish,
                [910] = onSwitchFinish,

                [913] = function(player, csid, option, npc)
                    onHintFinish(player, option, 'Ferghus')
                end,

                [914] = function(player, csid, option, npc)
                    if option == 1 then
                        quest:setVar(player, 'Rescue', rescue.ASK_HELMUT)
                    end
                end,

                [915] = function(player, csid, option, npc)
                    if option >= keyHolder.HUNGRY_WOLF and option <= keyHolder.STRIKING_SNAKE then
                        quest:setVar(player, 'Holder', option)
                        quest:setVar(player, 'Rescue', rescue.GET_KEY)
                    end
                end,

                [916] = function(player, csid, option, npc)
                    releaseThief(player)
                end,

                [917] = onKeyHolderFinish,
                [918] = onKeyHolderFinish,
                [919] = onKeyHolderFinish,

                [920] = function(player, csid, option, npc)
                    giveReward(player)
                end,

                [921] = function(player, csid, option, npc)
                    if option == 1 then
                        captureThief(player, thief.MILEDO)
                    end
                end,

                [922] = function(player, csid, option, npc)
                    if option == 1 then
                        captureThief(player, thief.LUTO)
                    end
                end,

                [923] = function(player, csid, option, npc)
                    if quest:getVar(player, 'Rescue') ~= rescue.ASK_FERGHUS then
                        return
                    end

                    -- With the costume kit, Ferghus only talks to Salim's wife.
                    if
                        quest:getVar(player, 'Tool') == tool.COSTUME_KIT and
                        option ~= 1
                    then
                        return
                    end

                    quest:setVar(player, 'Rescue', rescue.ASK_FOLZEN)
                end,
            },

            onZoneOut = onLeaveMetalworks,
        },
    },

    -- Section: The attempt failed. Salim starts it over from the request.
    {
        check = function(player, status, vars)
            return vars.Prog == progress.FAILED or
                ((vars.Prog == progress.SWITCHES or vars.Prog == progress.TRAP_OFF) and isTimeUp(vars))
        end,

        [xi.zone.METALWORKS] =
        {
            ['Salim'] =
            {
                onTrigger = function(player, npc)
                    return getRequestEvent(player)
                end,
            },

            ['qm4'] =
            {
                onTrigger = function(player, npc)
                    if quest:getVar(player, 'Prog') == progress.FAILED then
                        return quest:progressEvent(907)
                    end

                    -- The pocket watch hour ran out.
                    quest:setVar(player, 'Prog', progress.FAILED)
                    player:messageText(npc, metalID.text.TIME_LIMIT_EXCEEDED, false, 6)

                    return quest:noAction()
                end,
            },

            onEventFinish =
            {
                [899] = function(player, csid, option, npc)
                    acceptRequest(player)
                end,

                [907] = function(player, csid, option, npc)
                    if option == 1 then
                        giveUp(player)
                    end
                end,
            },
        },
    },

    -- Section: The reward did not fit.
    {
        check = function(player, status, vars)
            return vars.Prog == progress.REWARD
        end,

        [xi.zone.METALWORKS] =
        {
            ['qm4'] =
            {
                onTrigger = function(player, npc)
                    player:messageText(npc, metalID.text.SALIM_LEFT_SOMETHING, false, 6)
                    giveReward(player)

                    return quest:noAction()
                end,
            },

            onZoneOut = onLeaveMetalworks,
        },
    },
}

return quest
