-----------------------------------
-- ID: 15861
-- Item: Deductive Brocade Obi
-- Item Effect: MND+10
-- Duration: 3 Minutes
-----------------------------------
---@type TItem
local itemObject = {}

itemObject.onItemCheck = function(target, item, caster)
    if target:getStatusEffectBySource(xi.effect.MND_BOOST, xi.effectSourceType.EQUIPPED_ITEM, xi.item.DEDUCTIVE_BROCADE_OBI) then
        target:delStatusEffect(xi.effect.MND_BOOST, nil, xi.effectSourceType.EQUIPPED_ITEM, xi.item.DEDUCTIVE_BROCADE_OBI)
    end

    return 0
end

itemObject.onItemUnequip = function(target, item)
    target:delStatusEffect(xi.effect.MND_BOOST, nil, xi.effectSourceType.EQUIPPED_ITEM, xi.item.DEDUCTIVE_BROCADE_OBI)
end

itemObject.onItemUse = function(target, user)
    if target:hasEquipped(xi.item.DEDUCTIVE_BROCADE_OBI) then
        target:addStatusEffect(xi.effect.MND_BOOST, { duration = 180, origin = user, sourceType = xi.effectSourceType.EQUIPPED_ITEM, sourceTypeParam = xi.item.DEDUCTIVE_BROCADE_OBI })
    end
end

itemObject.onEffectGain = function(target, effect)
    effect:addMod(xi.mod.MND, 10)
end

itemObject.onEffectLose = function(target, effect)
end

return itemObject
