-----------------------------------
-- ID: 13144
-- Item: Wing Gorget
-- Item Effect: Regain (500 TP over 30 seconds)
-----------------------------------
---@type TItem
local itemObject = {}

itemObject.onItemCheck = function(target, item, caster)
    return 0
end

itemObject.onItemUnequip = function(target, item)
    target:delStatusEffect(xi.effect.REGAIN, nil, xi.effectSourceType.EQUIPPED_ITEM, xi.item.WING_GORGET)
end

itemObject.onItemUse = function(target, user)
    if target:hasEquipped(xi.item.WING_GORGET) then
        if target:hasStatusEffect(xi.effect.REGAIN) then
            target:messageBasic(xi.msg.basic.NO_EFFECT)
        else
            target:addStatusEffect(xi.effect.REGAIN, { duration = 30, origin = user, flag = xi.effectFlag.ON_ZONE, sourceType = xi.effectSourceType.EQUIPPED_ITEM, sourceTypeParam = xi.item.WING_GORGET })
        end
    end
end

itemObject.onEffectGain = function(target, effect)
    effect:addMod(xi.mod.REGAIN, 50)
end

itemObject.onEffectLose = function(target, effect)
end

return itemObject
