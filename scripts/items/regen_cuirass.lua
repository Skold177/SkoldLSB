-----------------------------------
-- ID: 15170
-- Item: Regen Cuirass
-- Item Effect: Regen (5 HP per tick)
-- Duration: 75 Seconds
-----------------------------------
---@type TItem
local itemObject = {}

itemObject.onItemCheck = function(target, item, caster)
    return 0
end

itemObject.onItemUnequip = function(target, item)
    target:delStatusEffect(xi.effect.REGEN, nil, xi.effectSourceType.EQUIPPED_ITEM, xi.item.REGEN_CUIRASS)
end

itemObject.onItemUse = function(target, user)
    if target:hasEquipped(xi.item.REGEN_CUIRASS) then
        if target:hasStatusEffect(xi.effect.REGEN) then
            target:messageBasic(xi.msg.basic.NO_EFFECT)
        else
            target:addStatusEffect(xi.effect.REGEN, { duration = 75, origin = user, flag = xi.effectFlag.ON_ZONE, sourceType = xi.effectSourceType.EQUIPPED_ITEM, sourceTypeParam = xi.item.REGEN_CUIRASS })
        end
    end
end

itemObject.onEffectGain = function(target, effect)
    effect:addMod(xi.mod.REGEN, 5)
end

itemObject.onEffectLose = function(target, effect)
end

return itemObject
