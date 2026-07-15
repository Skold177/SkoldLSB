-----------------------------------
-- Area: Altar Room
-----------------------------------
local ID = zones[xi.zone.ALTAR_ROOM]
mixins = { require('scripts/mixins/job_special') }
-----------------------------------
---@type TMobEntity
local entity = {}

local function tryResummonPet(mob)
    local pet = mob:getPet()

    if not pet then
        return
    end

    if pet:isAlive() then
        return
    end

    if GetSystemTime() >= mob:getLocalVar('petSummonTime') then
        xi.mob.callPets(mob, nil, { callPetJob = xi.job.SMN, inactiveTime = 3000, superLink = true, dieWithOwner = true, maxSpawns = 1 })
    end
end

entity.onMobInitialize = function(mob)
    xi.pet.setMobPet(mob, 1, 'Yagudos_Elemental')
end

entity.onMobSpawn = function(mob)
    mob:setLocalVar('petSummonTime', GetSystemTime() + math.randomInt(15, 30))
end

entity.onMobRoam = function(mob)
    tryResummonPet(mob)
end

entity.onMobFight = function(mob, target)
    tryResummonPet(mob)
end

entity.onMobDeath = function(mob, player, optParams)
    if
        player:getQuestStatus(xi.questLog.OTHER_AREAS, xi.quest.id.otherAreas.A_MORAL_MANIFEST) == xi.questStatus.QUEST_ACCEPTED and
        player:getCharVar('moral') == 5
    then
        player:setCharVar('moral', 6)
        player:delKeyItem(xi.ki.VAULT_QUIPUS)
    end

    for i = ID.mob.YAGUDO_AVATAR + 1, ID.mob.YAGUDO_AVATAR + 8 do
        DespawnMob(i)
    end
end

entity.onMobDespawn = function(mob)
    for i = ID.mob.YAGUDO_AVATAR + 1, ID.mob.YAGUDO_AVATAR + 8 do
        DespawnMob(i)
    end
end

return entity
