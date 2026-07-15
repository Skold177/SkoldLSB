-----------------------------------
-- Area: Temple of Uggalepih
--  Mob: Tonberry Harrier
-- Note: PH for Sozu Terberry
-----------------------------------
local ID = zones[xi.zone.TEMPLE_OF_UGGALEPIH]
mixins = { require('scripts/mixins/families/tonberry') }
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
    xi.regime.checkRegime(player, mob, 790, 1, xi.regime.type.GROUNDS)
    xi.regime.checkRegime(player, mob, 791, 1, xi.regime.type.GROUNDS)
    xi.regime.checkRegime(player, mob, 792, 1, xi.regime.type.GROUNDS)
    xi.regime.checkRegime(player, mob, 793, 1, xi.regime.type.GROUNDS)
    xi.regime.checkRegime(player, mob, 794, 1, xi.regime.type.GROUNDS)
    xi.regime.checkRegime(player, mob, 795, 1, xi.regime.type.GROUNDS)
end

entity.onMobDespawn = function(mob)
    xi.mob.phOnDespawn(mob, ID.mob.SOZU_TERBERRY, 10, 3600) -- 1 hour
end

return entity
