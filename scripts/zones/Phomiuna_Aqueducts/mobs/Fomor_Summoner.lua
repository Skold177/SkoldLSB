-----------------------------------
-- Area: Phomiuna_Aqueducts
--  Mob: Fomor Summoner
-----------------------------------
mixins =
{
    require('scripts/mixins/follow'),
    require('scripts/mixins/fomor_hate'),
    require('scripts/mixins/fomor_party'),
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
    xi.mix.fomorParty.onPartySpawn(mob)
    xi.pet.setMobPet(mob, 1, 'Fomors_Elemental')
end

entity.onMobSpawn = function(mob)
    mob:setLocalVar('petSummonTime', GetSystemTime() + math.randomInt(15, 30))
end

entity.onMobRoam = function(mob)
    xi.mix.fomorParty.onPartyRoam(mob)
    tryResummonPet(mob)
end

entity.onMobFight = function(mob, target)
    tryResummonPet(mob)
end

entity.onMobDeath = function(mob, player, optParams)
    if optParams.isKiller or optParams.noKiller then
        xi.mix.fomorParty.onPartyDeath(mob)
    end
end

return entity
