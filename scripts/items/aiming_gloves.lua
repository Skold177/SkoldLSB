-----------------------------------
-- ID: 14957
-- Item: Aiming Gloves
-- Item Effect: RACC +3
-- Duration: 30 Minutes
-----------------------------------
---@type TItem
local itemObject = {}

itemObject.onItemCheck = function(target, item, caster)
    if target:getStatusEffectBySource(xi.effect.ENCHANTMENT, xi.effectSourceType.EQUIPPED_ITEM, xi.item.AIMING_GLOVES) then
        target:delStatusEffect(xi.effect.ENCHANTMENT, nil, xi.effectSourceType.EQUIPPED_ITEM, xi.item.AIMING_GLOVES)
    end

    return 0
end

itemObject.onItemUnequip = function(target, item)
    target:delStatusEffect(xi.effect.ENCHANTMENT, nil, xi.effectSourceType.EQUIPPED_ITEM, xi.item.AIMING_GLOVES)
end

itemObject.onItemUse = function(target, user)
    if target:hasEquipped(xi.item.AIMING_GLOVES) then
        target:addStatusEffect(xi.effect.ENCHANTMENT, { duration = 1800, origin = user, flag = xi.effectFlag.ON_ZONE, sourceType = xi.effectSourceType.EQUIPPED_ITEM, sourceTypeParam = xi.item.AIMING_GLOVES })
    end
end

itemObject.onEffectGain = function(target, effect)
    effect:addMod(xi.mod.RACC, 3)
end

itemObject.onEffectLose = function(target, effect)
end

return itemObject
