-----------------------------------
-- ID: 14494
-- Item: Healing Mail
-- Item Effect: Restores 100-120 of the wyvern's HP
-----------------------------------
---@type TItem
local itemObject = {}

itemObject.onItemCheck = function(target, item, caster)
    local pet = caster:getPet()
    if not pet or pet:getPetID() ~= xi.petId.WYVERN then
        return xi.msg.basic.ITEM_NO_TARGET
    end

    return 0
end

itemObject.onItemUse = function(target, user, item, action)
    local pet = user:getPet()

    if pet and pet:getPetID() == xi.petId.WYVERN then
        action:ID(user:getID(), pet:getID())

        local healAmount = math.randomInt(100, 120)
        pet:addHP(healAmount)
        action:messageID(pet:getID(), xi.msg.basic.RECOVERS_HP)

        return healAmount
    end

    action:messageID(target:getID(), xi.msg.basic.ITEM_NO_EFFECT)

    return 0
end

return itemObject
