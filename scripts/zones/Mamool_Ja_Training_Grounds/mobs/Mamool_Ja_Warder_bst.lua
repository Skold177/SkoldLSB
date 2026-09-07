-----------------------------------
-- Area: Mamool Ja Training Grounds
--  Mob: Mamool Ja Warder (BST)
-- Involved in Assault: Imperial Agent Rescue
-----------------------------------
mixins = { require('scripts/mixins/weapon_break') }
-----------------------------------
---@type TMobEntity
local entity = {}

entity.onMobInitialize = function(mob)
    mob:setMod(xi.mod.HPP, 50)
    mob:setPet(GetMobByID(mob:getID() + 1, mob:getInstance()))
    mob:addListener('WEAPONSKILL_STATE_EXIT', 'WARDER_HIDE_GATES', function(mobArg, skillId, wasExecuted)
        xi.assault.contents[xi.assault.mission.IMPERIAL_AGENT_RESCUE].hideGates(mobArg)
    end)
end

entity.onMobSpawn = function(mob)
    xi.assault.adjustMobLevel(mob)
    mob:setMobMod(xi.mobMod.SPECIAL_SKILL, 0)
    mob:setLocalVar('petResummonTicks', 17)

    mob:setMod(xi.mod.STORETP, 10)
end

entity.onMobRoam = function(mob)
    local pet = mob:getPet()

    -- If the pet is alive, nothing to do here.
    if
        pet and
        pet:isAlive()
    then
        return
    end

    -- Time to resummon pet only accumulates while idle. Return.
    if mob:isFollowingPath() then
        return
    end

    -- Resummons pet after 60 seconds idle time. onMobRoam fires every 3 seconds.
    mob:setLocalVar('petResummonTicks', mob:getLocalVar('petResummonTicks') + 1)

    if mob:getLocalVar('petResummonTicks') >= 20 then
        mob:setLocalVar('petResummonTicks', 0)
        mob:stun(3000)
        mob:entityAnimationPacket(xi.animationString.CAST_SUMMONER_START)

        mob:timer(3000, function(mobArg)
            local position = mobArg:getPos()
            local instance = mobArg:getInstance()
            local petArg   = GetMobByID(mobArg:getID() + 1, instance)

            mobArg:entityAnimationPacket(xi.animationString.CAST_SUMMONER_STOP)

            if not petArg then
                return
            end

            petArg:setSpawn(position.x + math.randomInt(-2, 2), position.y, position.z + math.randomInt(-2, 2), position.rot)
            SpawnMob(petArg:getID(), instance)
            mobArg:setPet(petArg)
        end)
    end
end

-- Skill selection, Firespit & Axe Throw have higher weight when near a Dilapidated Gate.
entity.onMobMobskillChoose = function(mob, target, skillId)
    local gate      = xi.assault.contents[xi.assault.mission.IMPERIAL_AGENT_RESCUE].findGate(mob)
    local skillList =
    {
        [1] = { xi.mobSkill.SOMERSAULT_KICK_1,       20 },
        [2] = { xi.mobSkill.WARM_UP_1,               20 },
        [3] = { xi.mobSkill.FIRESPIT, gate and 85 or 20 },
    }

    if mob:getAnimationSub() == 0 then
        table.insert(skillList, { xi.mobSkill.AXE_THROW, gate and 60 or 20 })
        table.insert(skillList, { xi.mobSkill.RUSHING_SLASH_2,          20 })
    else
        table.insert(skillList, { xi.mobSkill.FORCEFUL_BLOW,            20 })
    end

    local weightSum = 0
    for i = 1, #skillList do
        weightSum = weightSum + skillList[i][2]
    end

    local randomRoll = math.randomInt(1, weightSum)
    weightSum = 0
    for i = 1, #skillList do
        weightSum = weightSum + skillList[i][2]
        if randomRoll <= weightSum then
            return skillList[i][1]
        end
    end
end

-- If Firespit or Axe Throw are chosen, unhide gate and redirect target to it - the exit state listener will rehide it.
entity.onMobSkillTarget = function(target, mob, skill)
    local skill = skill:getID()
    local gate  = xi.assault.contents[xi.assault.mission.IMPERIAL_AGENT_RESCUE].findGate(mob)

    if not gate then
        return target
    end

    if
        skill == xi.mobSkill.AXE_THROW or
        skill == xi.mobSkill.FIRESPIT
    then
        gate:setUntargetable(false)
        return gate
    end

    return target
end

entity.onMobDeath = function(mob, player, optParams)
    if optParams.isKiller or optParams.noKiller then
        xi.assault.contents[xi.assault.mission.IMPERIAL_AGENT_RESCUE].hideGates(mob)
    end
end

return entity
