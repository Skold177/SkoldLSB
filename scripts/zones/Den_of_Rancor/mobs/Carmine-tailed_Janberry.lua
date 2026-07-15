-----------------------------------
-- Area: Den of Rancor
--   NM: Carmine-tailed Janberry
-----------------------------------
mixins =
{
    require('scripts/mixins/families/tonberry'),
    require('scripts/mixins/job_special')
}
-----------------------------------
local ID = zones[xi.zone.DEN_OF_RANCOR]
-----------------------------------
---@type TMobEntity
local entity = {}

entity.spawnPoints =
{
    { x =  0.500, y =  36.000, z = -87.000 }
}

entity.phList =
{
    [ID.mob.CARMINE_TAILED_JANBERRY + 2] = ID.mob.CARMINE_TAILED_JANBERRY,
    [ID.mob.CARMINE_TAILED_JANBERRY + 3] = ID.mob.CARMINE_TAILED_JANBERRY,
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
    mob:addImmunity(xi.immunity.DARK_SLEEP)
    mob:addImmunity(xi.immunity.LIGHT_SLEEP)
    mob:addImmunity(xi.immunity.PETRIFY)
    mob:addImmunity(xi.immunity.SILENCE)
    mob:addImmunity(xi.immunity.TERROR)

    xi.pet.setMobPet(mob, 1, 'Tonberrys_Elemental')

    mob:setMobMod(xi.mobMod.GIL_MIN, 18000)
    mob:setMobMod(xi.mobMod.GIL_MAX, 18000)
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

return entity
