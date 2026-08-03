-----------------------------------
-- ID: 18029
-- Item: piercing_dagger
-- Item Effect: Attack +3
-- Duration: 30 Minutes
-----------------------------------
---@type TItem
local itemObject = {}

itemObject.onItemCheck = function(target, item, caster)
    if target:getStatusEffectBySource(xi.effect.ATTACK_BOOST, xi.effectSourceType.EQUIPPED_ITEM, xi.item.PIERCING_DAGGER) then
        target:delStatusEffect(xi.effect.ATTACK_BOOST, nil, xi.effectSourceType.EQUIPPED_ITEM, xi.item.PIERCING_DAGGER)
    end

    return 0
end

itemObject.onItemUse = function(target, user)
    if target:hasEquipped(xi.item.PIERCING_DAGGER) then
        target:addStatusEffect(xi.effect.ATTACK_BOOST, { duration = 1800, origin = user, sourceType = xi.effectSourceType.EQUIPPED_ITEM, sourceTypeParam = xi.item.PIERCING_DAGGER })
    end
end

itemObject.onEffectGain = function(target, effect)
    effect:addMod(xi.mod.ATT, 3)
end

itemObject.onEffectLose = function(target, effect)
end

return itemObject
