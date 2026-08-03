-----------------------------------
-- ID: 15708
-- Item: Earth Greaves
-- Item Effect: Grants Stoneskin to the wyvern (absorbs up to 200 damage)
-- Duration: 60 Seconds
-----------------------------------
---@type TItem
local itemObject = {}

itemObject.onItemCheck = function(target, item, caster)
    local pet = target:getPet()
    if not pet then
        return xi.msg.basic.REQUIRES_A_PET, 0
    end

    return 0
end

itemObject.onItemUse = function(target, user)
    local pet = target:getPet()
    if not pet then
        return
    end

    if target:hasEquipped(xi.item.EARTH_GREAVES) then
        pet:addStatusEffect(xi.effect.STONESKIN, { power = 200, duration = 60, origin = user })
    end
end

return itemObject
