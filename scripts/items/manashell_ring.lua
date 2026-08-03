-----------------------------------
-- ID: 15782
-- Item: Manashell Ring
-- Item Effect: MP +9
-- Duration: 30 Minutes
-----------------------------------
---@type TItem
local itemObject = {}

itemObject.onItemCheck = function(target, user)
    if target:getStatusEffectBySource(xi.effect.MAX_MP_BOOST, xi.effectSourceType.EQUIPPED_ITEM, xi.item.MANASHELL_RING) then
        target:delStatusEffect(xi.effect.MAX_MP_BOOST, nil, xi.effectSourceType.EQUIPPED_ITEM, xi.item.MANASHELL_RING)
    end

    return 0
end

itemObject.onItemUnequip = function(target, item)
    target:delStatusEffect(xi.effect.MAX_MP_BOOST, nil, xi.effectSourceType.EQUIPPED_ITEM, xi.item.MANASHELL_RING)
end

itemObject.onItemUse = function(target, user)
    if target:hasEquipped(xi.item.MANASHELL_RING) then
        target:addStatusEffect(xi.effect.MAX_MP_BOOST, { duration = 1800, origin = user, flag = xi.effectFlag.ON_ZONE, sourceType = xi.effectSourceType.EQUIPPED_ITEM, sourceTypeParam = xi.item.MANASHELL_RING })
    end
end

itemObject.onEffectGain = function(target, effect)
    effect:addMod(xi.mod.MP, 9)
end

itemObject.onEffectLose = function(target, effect)
end

return itemObject
