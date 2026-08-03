-----------------------------------
-- ID: 14541
-- Item: taikyoku_kenpogi
-- Item Effect: Eva +3
-- Duration: 30 Minutes
-----------------------------------
---@type TItem
local itemObject = {}

itemObject.onItemCheck = function(target, item, caster)
    if target:getStatusEffectBySource(xi.effect.EVASION_BOOST, xi.effectSourceType.EQUIPPED_ITEM, xi.item.TAIKYOKU_KENPOGI) then
        target:delStatusEffect(xi.effect.EVASION_BOOST, nil, xi.effectSourceType.EQUIPPED_ITEM, xi.item.TAIKYOKU_KENPOGI)
    end

    return 0
end

itemObject.onItemUse = function(target, user)
    if target:hasEquipped(xi.item.TAIKYOKU_KENPOGI) then
        target:addStatusEffect(xi.effect.EVASION_BOOST, { duration = 1800, origin = user, sourceType = xi.effectSourceType.EQUIPPED_ITEM, sourceTypeParam = xi.item.TAIKYOKU_KENPOGI })
    end
end

itemObject.onEffectGain = function(target, effect)
    effect:addMod(xi.mod.EVA, 3)
end

itemObject.onEffectLose = function(target, effect)
end

return itemObject
