-----------------------------------
-- Area: Al Zahbi
--  Mob: Lamias Elemental
--  Besieged
-----------------------------------
require('scripts/globals/pets/summon')
-----------------------------------
---@type TMobEntity
local entity = {}

local possibleElementals =
{
    xi.pets.summon.type.ICE_SPIRIT,
    xi.pets.summon.type.WATER_SPIRIT,
    xi.pets.summon.type.DARK_SPIRIT,
}

entity.onMobInitialize = function(mob)
    xi.besieged.onMobInitialize(mob)
end

entity.onMobSpawn = function(mob)
    xi.besieged.onMobSpawn(mob)
    xi.pets.summon.setupSummon(mob, possibleElementals)
end

entity.onMobDeath = function(mob, player, optParams)
    xi.besieged.onMobDeath(mob, player, optParams)

    if optParams.isKiller or optParams.noKiller then
        local master = mob:getMaster()

        if not master then
            return
        end

        master:setLocalVar('petSummonTime', GetSystemTime() + math.randomInt(35, 70))
    end
end

entity.onMobDespawn = function(mob)
    xi.besieged.onMobDespawn(mob)
end

return entity
