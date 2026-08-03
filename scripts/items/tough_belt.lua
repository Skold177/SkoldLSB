-----------------------------------
-- ID: 15864
-- Item: tough_belt
-- Item Effect: VIT +3
-- Duration: 60 seconds
-----------------------------------
---@type TItem
local itemObject = {}

itemObject.onItemCheck = function(target, item, caster)
    if target:getStatusEffectBySource(xi.effect.VIT_BOOST, xi.effectSourceType.EQUIPPED_ITEM, xi.item.TOUGH_BELT) then
        target:delStatusEffect(xi.effect.VIT_BOOST, nil, xi.effectSourceType.EQUIPPED_ITEM, xi.item.TOUGH_BELT)
    end

    return 0
end

itemObject.onItemUnequip = function(target, item)
    target:delStatusEffect(xi.effect.VIT_BOOST, nil, xi.effectSourceType.EQUIPPED_ITEM, xi.item.TOUGH_BELT)
end

itemObject.onItemUse = function(target, user)
    if target:hasEquipped(xi.item.TOUGH_BELT) then
        target:addStatusEffect(xi.effect.VIT_BOOST, { duration = 60, origin = user, sourceType = xi.effectSourceType.EQUIPPED_ITEM, sourceTypeParam = xi.item.TOUGH_BELT })
    end
end

itemObject.onEffectGain = function(target, effect)
    effect:addMod(xi.mod.VIT, 3)
end

itemObject.onEffectLose = function(target, effect)
end

return itemObject
