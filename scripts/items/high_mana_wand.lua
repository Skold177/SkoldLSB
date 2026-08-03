-----------------------------------
-- ID: 18403
-- Item: High Mana Wand
-- Item Effect: MPHEAL +4
-- Duration: 30 Minutes
-----------------------------------
---@type TItem
local itemObject = {}

itemObject.onItemCheck = function(target, item, caster)
    if target:getStatusEffectBySource(xi.effect.ENCHANTMENT, xi.effectSourceType.EQUIPPED_ITEM, xi.item.HIGH_MANA_WAND) then
        target:delStatusEffect(xi.effect.ENCHANTMENT, nil, xi.effectSourceType.EQUIPPED_ITEM, xi.item.HIGH_MANA_WAND)
    end

    return 0
end

itemObject.onItemUnequip = function(target, item)
    target:delStatusEffect(xi.effect.ENCHANTMENT, nil, xi.effectSourceType.EQUIPPED_ITEM, xi.item.HIGH_MANA_WAND)
end

itemObject.onItemUse = function(target, user)
    if target:hasEquipped(xi.item.HIGH_MANA_WAND) then
        target:addStatusEffect(xi.effect.ENCHANTMENT, { duration = 1800, origin = user, flag = xi.effectFlag.ON_ZONE, sourceType = xi.effectSourceType.EQUIPPED_ITEM, sourceTypeParam = xi.item.HIGH_MANA_WAND })
    end
end

itemObject.onEffectGain = function(target, effect)
    effect:addMod(xi.mod.MPHEAL, 4)
end

itemObject.onEffectLose = function(target, effect)
end

return itemObject
