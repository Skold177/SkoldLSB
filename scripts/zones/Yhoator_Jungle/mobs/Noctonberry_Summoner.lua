-----------------------------------
-- Area: Yhoator Jungle
--  Mob: Noctonberry Summoner
-----------------------------------
mixins =
{
    require('scripts/mixins/families/tonberry'),
    require('scripts/mixins/job_special')
}
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
    xi.pet.setMobPet(mob, 1, 'Tonberrys_Elemental')
    mob:setMobMod(xi.mobMod.ASTRAL_PET_OFFSET, 2)
    mob:setMobMod(xi.mobMod.NO_DESPAWN, 1)
    mob:setMobMod(xi.mobMod.IDLE_DESPAWN, 180)
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
    if optParams.isKiller or optParams.noKiller then
        xi.expeditionaryForce.onMobDeath(mob, player)
    end
end

entity.onMobDespawn = function(mob)
    xi.expeditionaryForce.onMobDespawn(mob)
end

return entity
