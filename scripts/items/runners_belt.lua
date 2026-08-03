-----------------------------------
-- ID: 15865
-- Item: runners_belt
-- Item Effect: DEX +3
-- Duration: 60 seconds
-----------------------------------
---@type TItem
local itemObject = {}

itemObject.onItemCheck = function(target, item, caster)
    if target:getStatusEffectBySource(xi.effect.DEX_BOOST, xi.effectSourceType.EQUIPPED_ITEM, xi.item.RUNNERS_BELT) then
        target:delStatusEffect(xi.effect.DEX_BOOST, nil, xi.effectSourceType.EQUIPPED_ITEM, xi.item.RUNNERS_BELT)
    end

    return 0
end

itemObject.onItemUnequip = function(target, item)
    target:delStatusEffect(xi.effect.DEX_BOOST, nil, xi.effectSourceType.EQUIPPED_ITEM, xi.item.RUNNERS_BELT)
end

itemObject.onItemUse = function(target, user)
    if target:hasEquipped(xi.item.RUNNERS_BELT) then
        target:addStatusEffect(xi.effect.DEX_BOOST, { duration = 60, origin = user, sourceType = xi.effectSourceType.EQUIPPED_ITEM, sourceTypeParam = xi.item.RUNNERS_BELT })
    end
end

itemObject.onEffectGain = function(target, effect)
    effect:addMod(xi.mod.DEX, 3)
end

itemObject.onEffectLose = function(target, effect)
end

return itemObject
