-----------------------------------
-- ID: 15610
-- Item: sturdy_trousers
-- Item Effect: HP +10
-- Duration: 30 Minutes
-----------------------------------
---@type TItem
local itemObject = {}

itemObject.onItemCheck = function(target, item, caster)
    if target:getStatusEffectBySource(xi.effect.MAX_HP_BOOST, xi.effectSourceType.EQUIPPED_ITEM, xi.item.STURDY_TROUSERS) then
        target:delStatusEffect(xi.effect.MAX_HP_BOOST, nil, xi.effectSourceType.EQUIPPED_ITEM, xi.item.STURDY_TROUSERS)
    end

    return 0
end

itemObject.onItemUse = function(target, user)
    if target:hasEquipped(xi.item.STURDY_TROUSERS) then
        target:addStatusEffect(xi.effect.MAX_HP_BOOST, { duration = 1800, origin = user, sourceType = xi.effectSourceType.EQUIPPED_ITEM, sourceTypeParam = xi.item.STURDY_TROUSERS })
    end
end

itemObject.onEffectGain = function(target, effect)
    effect:addMod(xi.mod.HP, 10)
end

itemObject.onEffectLose = function(target, effect)
end

return itemObject
