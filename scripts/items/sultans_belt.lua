-----------------------------------
-- ID: 15867
-- Item: sultans_belt
-- Item Effect: STR +10
-- Duration: 60 seconds
-----------------------------------
---@type TItem
local itemObject = {}

itemObject.onItemCheck = function(target, item, caster)
    if target:getStatusEffectBySource(xi.effect.STR_BOOST, xi.effectSourceType.EQUIPPED_ITEM, xi.item.SULTANS_BELT) then
        target:delStatusEffect(xi.effect.STR_BOOST, nil, xi.effectSourceType.EQUIPPED_ITEM, xi.item.SULTANS_BELT)
    end

    return 0
end

itemObject.onItemUnequip = function(target, item)
    target:delStatusEffect(xi.effect.STR_BOOST, nil, xi.effectSourceType.EQUIPPED_ITEM, xi.item.SULTANS_BELT)
end

itemObject.onItemUse = function(target, user)
    if target:hasEquipped(xi.item.SULTANS_BELT) then
        target:addStatusEffect(xi.effect.STR_BOOST, { duration = 60, origin = user, sourceType = xi.effectSourceType.EQUIPPED_ITEM, sourceTypeParam = xi.item.SULTANS_BELT })
    end
end

itemObject.onEffectGain = function(target, effect)
    effect:addMod(xi.mod.STR, 10)
end

itemObject.onEffectLose = function(target, effect)
end

return itemObject
