-----------------------------------
-- Area: Xarcabard
--  Mob: Demon Warlock
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
    xi.pet.setMobPet(mob, 1, 'Demons_Elemental')
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
    xi.regime.checkRegime(player, mob, 55, 1, xi.regime.type.FIELDS)
end

return entity
