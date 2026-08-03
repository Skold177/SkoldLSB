-----------------------------------
-- ID: 18747
-- Item: Smash Cesti
-- Item Effect: Attack +3
-- Duration: 30 Minutes
-----------------------------------
---@type TItem
local itemObject = {}

itemObject.onItemCheck = function(target, item, caster)
    if target:getStatusEffectBySource(xi.effect.ENCHANTMENT, xi.effectSourceType.EQUIPPED_ITEM, xi.item.SMASH_CESTI) then
        target:delStatusEffect(xi.effect.ENCHANTMENT, nil, xi.effectSourceType.EQUIPPED_ITEM, xi.item.SMASH_CESTI)
    end

    return 0
end

itemObject.onItemUnequip = function(target, item)
    target:delStatusEffect(xi.effect.ENCHANTMENT, nil, xi.effectSourceType.EQUIPPED_ITEM, xi.item.SMASH_CESTI)
end

itemObject.onItemUse = function(target, user)
    if target:hasEquipped(xi.item.SMASH_CESTI) then
        target:addStatusEffect(xi.effect.ENCHANTMENT, { duration = 1800, origin = user, flag = xi.effectFlag.ON_ZONE, sourceType = xi.effectSourceType.EQUIPPED_ITEM, sourceTypeParam = xi.item.SMASH_CESTI })
    end
end

itemObject.onEffectGain = function(target, effect)
    effect:addMod(xi.mod.ATT, 3)
end

itemObject.onEffectLose = function(target, effect)
end

return itemObject
