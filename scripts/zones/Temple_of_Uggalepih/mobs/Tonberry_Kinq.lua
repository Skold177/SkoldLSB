-----------------------------------
-- Area: Temple of Uggalepih
--   NM: Tonberry Kinq
-----------------------------------
mixins =
{
    require('scripts/mixins/families/tonberry'),
    require('scripts/mixins/job_special')
}
-----------------------------------
local ID = zones[xi.zone.TEMPLE_OF_UGGALEPIH]
-----------------------------------
---@type TMobEntity
local entity = {}

entity.spawnPoints =
{
    { x = -219.962, y = -1.736, z =  28.388 }
}

entity.phList =
{
    [ID.mob.TONBERRY_KINQ - 2] = ID.mob.TONBERRY_KINQ, -- Confirmed on retail
}

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
    mob:setMobMod(xi.mobMod.NO_MOVE, 1)

    xi.pet.setMobPet(mob, 1, 'Tonberrys_Elemental')

    mob:setMobMod(xi.mobMod.GIL_MIN, 18000)
    mob:setMobMod(xi.mobMod.GIL_MAX, 18000)
end

entity.onMobSpawn = function(mob)
    mob:setMobMod(xi.mobMod.BASE_DAMAGE_MULTIPLIER, 150)
    mob:setLocalVar('petSummonTime', GetSystemTime() + math.randomInt(15, 30))
end

entity.onMobRoam = function(mob)
    tryResummonPet(mob)
end

entity.onMobFight = function(mob, target)
    tryResummonPet(mob)
end

entity.onMobEngage = function(mob, target)
    mob:setMobMod(xi.mobMod.NO_MOVE, 0)
end

return entity
