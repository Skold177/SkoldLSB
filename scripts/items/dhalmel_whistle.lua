-----------------------------------
-- ID: 15505
-- Item: Dhalmel Whistle
-- Item Effect: AGI +6
-- Duration: 3 minutes
-----------------------------------
---@type TItem
local itemObject = {}

itemObject.onItemCheck = function(target, item, caster)
    if target:getStatusEffectBySource(xi.effect.ENCHANTMENT, xi.effectSourceType.EQUIPPED_ITEM, xi.item.DHALMEL_WHISTLE) then
        target:delStatusEffect(xi.effect.ENCHANTMENT, nil, xi.effectSourceType.EQUIPPED_ITEM, xi.item.DHALMEL_WHISTLE)
    end

    return 0
end

itemObject.onItemUnequip = function(target, item)
    target:delStatusEffect(xi.effect.ENCHANTMENT, nil, xi.effectSourceType.EQUIPPED_ITEM, xi.item.DHALMEL_WHISTLE)
end

itemObject.onItemUse = function(target, user)
    if target:hasEquipped(xi.item.DHALMEL_WHISTLE) then
        target:addStatusEffect(xi.effect.ENCHANTMENT, { duration = 180, origin = user, flag = xi.effectFlag.ON_ZONE, sourceType = xi.effectSourceType.EQUIPPED_ITEM, sourceTypeParam = xi.item.DHALMEL_WHISTLE })
    end
end

itemObject.onEffectGain = function(target, effect)
    effect:addMod(xi.mod.AGI, 6)
end

itemObject.onEffectLose = function(target, effect)
end

return itemObject
