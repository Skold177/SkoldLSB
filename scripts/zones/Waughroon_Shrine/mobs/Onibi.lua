-----------------------------------
-- Area: Waughroon Shrine
--  Mob: Gaki
-- a Thief in Norg BCNM Fight
-----------------------------------
mixins = { require('scripts/mixins/job_special') }
-----------------------------------
---@type TMobEntity
local entity = {}

entity.onMobSpawn = function(mob)
    mob:setMagicCastingEnabled(false)
end

entity.onMobEngage = function(mob)
    mob:setMagicCastingEnabled(true) -- This will prevent Gaki from using blaze spikes before the fight starts
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
