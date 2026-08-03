-----------------------------------
-- ID: 15862
-- Item: enthralling_brocade_obi
-- Item Effect: CHR+10
-- Duration: 3 Minutes
-----------------------------------
---@type TItem
local itemObject = {}

itemObject.onItemCheck = function(target, item, caster)
    if target:getStatusEffectBySource(xi.effect.CHR_BOOST, xi.effectSourceType.EQUIPPED_ITEM, xi.item.ENTHRALLING_BROCADE_OBI) then
        target:delStatusEffect(xi.effect.CHR_BOOST, nil, xi.effectSourceType.EQUIPPED_ITEM, xi.item.ENTHRALLING_BROCADE_OBI)
    end

    return 0
end

itemObject.onItemUnequip = function(target, item)
    target:delStatusEffect(xi.effect.CHR_BOOST, nil, xi.effectSourceType.EQUIPPED_ITEM, xi.item.ENTHRALLING_BROCADE_OBI)
end

itemObject.onItemUse = function(target, user)
    if target:hasEquipped(xi.item.ENTHRALLING_BROCADE_OBI) then
        target:addStatusEffect(xi.effect.CHR_BOOST, { duration = 180, origin = user, sourceType = xi.effectSourceType.EQUIPPED_ITEM, sourceTypeParam = xi.item.ENTHRALLING_BROCADE_OBI })
    end
end

itemObject.onEffectGain = function(target, effect)
    effect:addMod(xi.mod.CHR, 10)
end

itemObject.onEffectLose = function(target, effect)
end

return itemObject
