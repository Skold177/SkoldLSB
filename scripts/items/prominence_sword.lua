-----------------------------------
-- ID:18381
-- Item: Prominence Sword
-- Enchantment: Enfire
-- Duration: 3 minutes
-----------------------------------
---@type TItem
local itemObject = {}

itemObject.onItemCheck = function(target, user)
    if target:getStatusEffectBySource(xi.effect.ENFIRE, xi.effectSourceType.EQUIPPED_ITEM, xi.item.PROMINENCE_SWORD) then
        target:delStatusEffect(xi.effect.ENFIRE, nil, xi.effectSourceType.EQUIPPED_ITEM, xi.item.PROMINENCE_SWORD)
    end

    return 0
end

itemObject.onItemUse = function(target, user)
    if target:hasEquipped(xi.item.PROMINENCE_SWORD) then
        local effect = xi.effect.ENFIRE
        local magicskill = target:getSkillLevel(xi.skill.ENHANCING_MAGIC)
        local potency = 0

        if magicskill <= 200 then
            potency = 3 + math.floor(6 * magicskill / 100)
        elseif magicskill > 200 then
            potency = 5 + math.floor(5 * magicskill / 100)
        end

        potency = utils.clamp(potency, 3, 25)

        target:addStatusEffect(effect, { power = potency, duration = 180, origin = user, sourceType = xi.effectSourceType.EQUIPPED_ITEM, sourceTypeParam = xi.item.PROMINENCE_SWORD })
    end
end

itemObject.onEffectGain = function(target, effect)
    effect:addMod(xi.mod.ENSPELL, xi.element.FIRE)
    effect:addMod(xi.mod.ENSPELL_DMG, effect:getPower())
end

itemObject.onEffectLose = function(target, effect)
end

return itemObject
