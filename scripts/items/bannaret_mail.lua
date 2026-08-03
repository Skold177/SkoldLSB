-----------------------------------
-- ID: 14531
-- Item: Bannaret Mail
-- Item Effect: HP +15, Enmity +2
-- Duration: 30 Minutes
-----------------------------------
---@type TItem
local itemObject = {}

itemObject.onItemCheck = function(target, item, caster)
    if target:getStatusEffectBySource(xi.effect.ENCHANTMENT, xi.effectSourceType.EQUIPPED_ITEM, xi.item.BANNARET_MAIL) then
        target:delStatusEffect(xi.effect.ENCHANTMENT, nil, xi.effectSourceType.EQUIPPED_ITEM, xi.item.BANNARET_MAIL)
    end

    return 0
end

itemObject.onItemUnequip = function(target, item)
    target:delStatusEffect(xi.effect.ENCHANTMENT, nil, xi.effectSourceType.EQUIPPED_ITEM, xi.item.BANNARET_MAIL)
end

itemObject.onItemUse = function(target, user)
    if target:hasEquipped(xi.item.BANNARET_MAIL) then
        target:addStatusEffect(xi.effect.ENCHANTMENT, { duration = 1800, origin = user, flag = xi.effectFlag.ON_ZONE, sourceType = xi.effectSourceType.EQUIPPED_ITEM, sourceTypeParam = xi.item.BANNARET_MAIL })
    end
end

itemObject.onEffectGain = function(target, effect)
    effect:addMod(xi.mod.HP, 15)
    effect:addMod(xi.mod.ENMITY, 2)
end

itemObject.onEffectLose = function(target, effect)
end

return itemObject
