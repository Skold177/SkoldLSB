-----------------------------------
-- ID: 15269
-- Item: Eldritch Horn Hairpin
-- Item Effect: INT+3 MND+3
-- Duration: 30 Minutes
-----------------------------------
---@type TItem
local itemObject = {}

itemObject.onItemCheck = function(target, item, caster)
    if target:getStatusEffectBySource(xi.effect.ENCHANTMENT, xi.effectSourceType.EQUIPPED_ITEM, xi.item.ELDRITCH_HORN_HAIRPIN) then
        target:delStatusEffect(xi.effect.ENCHANTMENT, nil, xi.effectSourceType.EQUIPPED_ITEM, xi.item.ELDRITCH_HORN_HAIRPIN)
    end

    return 0
end

itemObject.onItemUnequip = function(target, item)
    target:delStatusEffect(xi.effect.ENCHANTMENT, nil, xi.effectSourceType.EQUIPPED_ITEM, xi.item.ELDRITCH_HORN_HAIRPIN)
end

itemObject.onItemUse = function(target, user)
    if target:hasEquipped(xi.item.ELDRITCH_HORN_HAIRPIN) then
        target:addStatusEffect(xi.effect.ENCHANTMENT, { duration = 1800, origin = user, flag = xi.effectFlag.ON_ZONE, sourceType = xi.effectSourceType.EQUIPPED_ITEM, sourceTypeParam = xi.item.ELDRITCH_HORN_HAIRPIN })
    end
end

itemObject.onEffectGain = function(target, effect)
    effect:addMod(xi.mod.INT, 3)
    effect:addMod(xi.mod.MND, 3)
end

itemObject.onEffectLose = function(target, effect)
end

return itemObject
