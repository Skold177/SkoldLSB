-----------------------------------
-- ID: 15268
-- Item: Eldritch Bone Hairpin
-- Item Effect: INT+2 MND+2
-- Duration: 30 Minutes
-----------------------------------
---@type TItem
local itemObject = {}

itemObject.onItemCheck = function(target, item, caster)
    if target:getStatusEffectBySource(xi.effect.ENCHANTMENT, xi.effectSourceType.EQUIPPED_ITEM, xi.item.ELDRITCH_BONE_HAIRPIN) then
        target:delStatusEffect(xi.effect.ENCHANTMENT, nil, xi.effectSourceType.EQUIPPED_ITEM, xi.item.ELDRITCH_BONE_HAIRPIN)
    end

    return 0
end

itemObject.onItemUnequip = function(target, item)
    target:delStatusEffect(xi.effect.ENCHANTMENT, nil, xi.effectSourceType.EQUIPPED_ITEM, xi.item.ELDRITCH_BONE_HAIRPIN)
end

itemObject.onItemUse = function(target, user)
    if target:hasEquipped(xi.item.ELDRITCH_BONE_HAIRPIN) then
        target:addStatusEffect(xi.effect.ENCHANTMENT, { duration = 1800, origin = user, flag = xi.effectFlag.ON_ZONE, sourceType = xi.effectSourceType.EQUIPPED_ITEM, sourceTypeParam = xi.item.ELDRITCH_BONE_HAIRPIN })
    end
end

itemObject.onEffectGain = function(target, effect)
    effect:addMod(xi.mod.INT, 2)
    effect:addMod(xi.mod.MND, 2)
end

itemObject.onEffectLose = function(target, effect)
end

return itemObject
