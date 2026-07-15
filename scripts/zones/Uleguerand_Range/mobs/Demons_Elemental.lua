-----------------------------------
-- Area: Uleguerand Range
--  Mob: Demon Elemental
-----------------------------------
require('scripts/globals/pets/summon')
-----------------------------------
---@type TMobEntity
local entity = {}

local possibleElementals =
{
    xi.pets.summon.type.ICE_SPIRIT,
    xi.pets.summon.type.THUNDER_SPIRIT,
    xi.pets.summon.type.DARK_SPIRIT,
}

entity.onMobSpawn = function(mob)
    xi.pets.summon.setupSummon(mob, possibleElementals)
end

entity.onMobDeath = function(mob, player, optParams)
    if optParams.isKiller or optParams.noKiller then
        local master = mob:getMaster()

        if not master then
            return
        end

        master:setLocalVar('petSummonTime', GetSystemTime() + math.randomInt(35, 70))
    end
end

return entity
