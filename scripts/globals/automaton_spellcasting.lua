-----------------------------------
-- Automaton Spellcasting
-- Returns { spellId, targetTargId }, or an empty table when there is nothing to cast.
-- Spell lists are ordered by cast priority.
-----------------------------------
xi = xi or {}
xi.automaton_spellcasting = xi.automaton_spellcasting or {}

-- Cooldowns are in seconds; a missing category means the head never casts it.
xi.automaton_spellcasting.cooldowns =
{
    [xi.automaton.head.HARLEQUIN   ] =
    {
        overall       = 10,
        healing       = 12,
        enfeebling    = 12,
    },

    [xi.automaton.head.VALOREDGE   ] =
    {
        overall       = 10,
        healing       = 20,
    },

    [xi.automaton.head.SHARPSHOT   ] =
    {
        overall       = 10,
        healing       = 20,
        enfeebling    = 12,
    },

    [xi.automaton.head.STORMWAKER  ] =
    {
        overall       =  8,
        healing       = 20,
        enfeebling    = 10,
        elemental     = 25,
        enhancing     = 25,
    },

    [xi.automaton.head.SOULSOOTHER ] =
    {
        overall       =  8,
        healing       = 10,
        enfeebling    = 10,
        statusRemoval = 10,
        enhancing     = 25,
    },

    [xi.automaton.head.SPIRITREAVER] =
    {
        overall       =  8,
        enfeebling    = 10,
        elemental     = 30,
        enhancing     = 35,
        dark          = 25,
    },
}

xi.automaton_spellcasting.spellLists = {}

-----------------------------------
-- Shared helpers
-----------------------------------

local function getEquippedHead(automaton)
    local master = automaton:getMaster()

    return master, master and master:getAutomatonHead()
end

local function isHeadAllowed(spellData, headEquipped)
    for _, allowedHead in ipairs(spellData.allowedHeads) do
        if allowedHead == headEquipped then
            return true
        end
    end

    return false
end

local function getEligibleSpells(automaton, headEquipped, spellList)
    local magicSkill     = automaton:getSkillLevel(xi.skill.AUTOMATON_MAGIC)
    local currentMP      = automaton:getMP()
    local eligibleSpells = {}

    for _, spellData in ipairs(spellList) do
        if
            isHeadAllowed(spellData, headEquipped) and
            magicSkill >= spellData.skillNeeded and
            currentMP >= spellData.mpCost and
            not automaton:hasRecast(xi.recast.MAGIC, spellData.spellId)
        then
            eligibleSpells[#eligibleSpells + 1] = spellData
        end
    end

    return eligibleSpells
end

local function getActiveManeuverElements(master)
    local activeManeuvers = {}

    for _, maneuverData in pairs(xi.automaton.maneuverList) do
        if master:hasStatusEffect(maneuverData.effect) then
            activeManeuvers[maneuverData.element] = true
        end
    end

    return activeManeuvers
end

-----------------------------------
-- Healing
-----------------------------------
xi.automaton_spellcasting.spellLists.healing =
{
    {
        spellId            = xi.magic.spell.CURE_VI,
        mpCost             = 227,
        skillNeeded        = 313,
        allowedHeads       = { xi.automaton.head.SOULSOOTHER },
        missingHPThreshold = 850,
    },
    {
        spellId            = xi.magic.spell.CURE_V,
        mpCost             = 135,
        skillNeeded        = 207,
        allowedHeads       = { xi.automaton.head.SOULSOOTHER },
        missingHPThreshold = 600,
    },
    {
        spellId            = xi.magic.spell.CURE_IV,
        mpCost             =  88,
        skillNeeded        = 147,
        allowedHeads       = { xi.automaton.head.HARLEQUIN, xi.automaton.head.VALOREDGE, xi.automaton.head.SHARPSHOT, xi.automaton.head.STORMWAKER, xi.automaton.head.SOULSOOTHER },
        missingHPThreshold = 350,
    },
    {
        spellId            = xi.magic.spell.CURE_III,
        mpCost             =  46,
        skillNeeded        =  81,
        allowedHeads       = { xi.automaton.head.HARLEQUIN, xi.automaton.head.VALOREDGE, xi.automaton.head.SHARPSHOT, xi.automaton.head.STORMWAKER, xi.automaton.head.SOULSOOTHER },
        missingHPThreshold = 190,
    },
    {
        spellId            = xi.magic.spell.CURE_II,
        mpCost             =  24,
        skillNeeded        =  45,
        allowedHeads       = { xi.automaton.head.HARLEQUIN, xi.automaton.head.VALOREDGE, xi.automaton.head.SHARPSHOT, xi.automaton.head.STORMWAKER, xi.automaton.head.SOULSOOTHER },
        missingHPThreshold = 120,
    },
    {
        spellId            = xi.magic.spell.CURE,
        mpCost             =   8,
        skillNeeded        =  12,
        allowedHeads       = { xi.automaton.head.HARLEQUIN, xi.automaton.head.VALOREDGE, xi.automaton.head.SHARPSHOT, xi.automaton.head.STORMWAKER, xi.automaton.head.SOULSOOTHER },
        missingHPThreshold = 0,
    },
    {
        spellId        = xi.magic.spell.REGEN_IV,
        mpCost         =  82,
        skillNeeded    = 337,
        allowedHeads   = { xi.automaton.head.SOULSOOTHER },
        castConditions = { missingEffects = { xi.effect.REGEN }, enemyLevelDiff = 4 },
    },
    {
        spellId        = xi.magic.spell.REGEN_III,
        mpCost         =  64,
        skillNeeded    = 232,
        allowedHeads   = { xi.automaton.head.SOULSOOTHER },
        castConditions = { missingEffects = { xi.effect.REGEN }, enemyLevelDiff = 4 },
    },
    {
        spellId        = xi.magic.spell.REGEN_II,
        mpCost         =  36,
        skillNeeded    = 135,
        allowedHeads   = { xi.automaton.head.SOULSOOTHER },
        castConditions = { missingEffects = { xi.effect.REGEN }, enemyLevelDiff = 4 },
    },
    {
        spellId        = xi.magic.spell.REGEN,
        mpCost         =  15,
        skillNeeded    =  66,
        allowedHeads   = { xi.automaton.head.SOULSOOTHER },
        castConditions = { missingEffects = { xi.effect.REGEN }, enemyLevelDiff = 4 },
    },
}

xi.automaton_spellcasting.doHealingSpell = function(automaton, target)
    local master, headEquipped = getEquippedHead(automaton)

    if not headEquipped or not target then
        return {}
    end

    local lightManeuvers     = master:countEffect(xi.effect.LIGHT_MANEUVER)
    local healingThreshold   = utils.clamp(30 + math.min(lightManeuvers, 3) * 10 + automaton:getMod(xi.mod.AUTO_HEALING_THRESHOLD), 30, 90)

    local targetOfTarget     = target:getTarget()
    local haveHate           = targetOfTarget and targetOfTarget:getID() == automaton:getID()

    local autoNeedsHealing   = automaton:getHPP() <= 50
    local masterNeedsHealing = master:getHPP() <= healingThreshold and automaton:checkDistance(master) < 20

    -- The master comes first unless the automaton is holding hate.
    local castTarget
    if haveHate then
        if autoNeedsHealing then
            castTarget = automaton
        elseif masterNeedsHealing then
            castTarget = master
        end
    else
        if masterNeedsHealing then
            castTarget = master
        elseif autoNeedsHealing then
            castTarget = automaton
        end
    end

    if
        lightManeuvers > 0 and
        not castTarget and
        headEquipped == xi.automaton.head.SOULSOOTHER
    then
        for _, member in ipairs(master:getPartyWithTrusts() or {}) do
            if
                member:getID() ~= master:getID() and
                member:getHPP() <= healingThreshold and
                automaton:checkDistance(member) < 20
            then
                castTarget = member
                break
            end
        end
    end

    if not castTarget then
        return {}
    end

    local missingHP      = castTarget:getMaxHP() - castTarget:getHP()
    local eligibleSpells = getEligibleSpells(automaton, headEquipped, xi.automaton_spellcasting.spellLists.healing)

    for _, spell in ipairs(eligibleSpells) do
        if spell.missingHPThreshold ~= nil then
            if missingHP > spell.missingHPThreshold then
                return { spell.spellId, castTarget:getTargID() }
            end
        elseif spell.castConditions then
            local conditionsMet = true

            for _, effect in ipairs(spell.castConditions.missingEffects or {}) do
                if castTarget:hasStatusEffect(effect) then
                    conditionsMet = false
                    break
                end
            end

            if
                conditionsMet and
                spell.castConditions.enemyLevelDiff
            then
                conditionsMet = (target:getLevel() - master:getLevel()) >= spell.castConditions.enemyLevelDiff
            end

            if conditionsMet then
                return { spell.spellId, castTarget:getTargID() }
            end
        end
    end

    return {}
end

-----------------------------------
-- Status removal
-----------------------------------
xi.automaton_spellcasting.spellLists.statusRemoval =
{
    {
        spellId        = xi.magic.spell.POISONA,
        mpCost         =  8,
        skillNeeded    = 27,
        allowedHeads   = { xi.automaton.head.SOULSOOTHER },
        castConditions = { hasEffects = { xi.effect.POISON } },
    },
    {
        spellId        = xi.magic.spell.PARALYNA,
        mpCost         = 12,
        skillNeeded    = 36,
        allowedHeads   = { xi.automaton.head.SOULSOOTHER },
        castConditions = { hasEffects = { xi.effect.PARALYSIS } },
    },
    {
        spellId        = xi.magic.spell.BLINDNA,
        mpCost         = 16,
        skillNeeded    = 45,
        allowedHeads   = { xi.automaton.head.SOULSOOTHER },
        castConditions = { hasEffects = { xi.effect.BLINDNESS } },
    },
    {
        spellId        = xi.magic.spell.SILENA,
        mpCost         = 24,
        skillNeeded    = 60,
        allowedHeads   = { xi.automaton.head.SOULSOOTHER },
        castConditions = { hasEffects = { xi.effect.SILENCE } },
    },
    {
        spellId        = xi.magic.spell.CURSNA,
        mpCost         = 30,
        skillNeeded    = 90,
        allowedHeads   = { xi.automaton.head.SOULSOOTHER },
        castConditions = { hasEffects = { xi.effect.CURSE_I, xi.effect.CURSE_II, xi.effect.BANE } }, -- Doom is excluded.
    },
    {
        spellId        = xi.magic.spell.ERASE,
        mpCost         = 18,
        skillNeeded    = 99,
        allowedHeads   = { xi.automaton.head.SOULSOOTHER },
        castConditions = { hasErasableEffect = true },
    },
    {
        spellId        = xi.magic.spell.VIRUNA,
        mpCost         = 48,
        skillNeeded    = 105,
        allowedHeads   = { xi.automaton.head.SOULSOOTHER },
        castConditions = { hasEffects = { xi.effect.DISEASE, xi.effect.PLAGUE } },
    },
    {
        spellId        = xi.magic.spell.STONA,
        mpCost         = 40,
        skillNeeded    = 120,
        allowedHeads   = { xi.automaton.head.SOULSOOTHER },
        castConditions = { hasEffects = { xi.effect.PETRIFICATION } },
    },
}

xi.automaton_spellcasting.doStatusRemovalSpell = function(automaton)
    local master, headEquipped = getEquippedHead(automaton)

    if not headEquipped then
        return {}
    end

    local eligibleSpells = getEligibleSpells(automaton, headEquipped, xi.automaton_spellcasting.spellLists.statusRemoval)

    if #eligibleSpells == 0 then
        return {}
    end

    local checkTargets = { master, automaton }

    if
        master:countEffect(xi.effect.WATER_MANEUVER) > 0 and
        headEquipped == xi.automaton.head.SOULSOOTHER
    then
        for _, member in ipairs(master:getPartyWithTrusts() or {}) do
            if member:getID() ~= master:getID() then
                checkTargets[#checkTargets + 1] = member
            end
        end
    end

    for _, checkTarget in ipairs(checkTargets) do
        for _, spell in ipairs(eligibleSpells) do
            local conditions = spell.castConditions

            if conditions.hasErasableEffect then
                if checkTarget:hasStatusEffectByFlag(xi.effectFlag.ERASABLE) then
                    return { spell.spellId, checkTarget:getTargID() }
                end
            elseif conditions.hasEffects then
                for _, effect in ipairs(conditions.hasEffects) do
                    if checkTarget:hasStatusEffect(effect) then
                        return { spell.spellId, checkTarget:getTargID() }
                    end
                end
            end
        end
    end

    return {}
end

-----------------------------------
-- Enhancing
-----------------------------------
xi.automaton_spellcasting.spellLists.enhancing =
{
    {
        spellId       = xi.magic.spell.PROTECTRA_V,
        mpCost        = 84,
        skillNeeded   = 322,
        allowedHeads  = { xi.automaton.head.SOULSOOTHER },
        missingEffect = xi.effect.PROTECT,
    },
    {
        spellId       = xi.magic.spell.PROTECT_V,
        mpCost        = 84,
        skillNeeded   = 281,
        allowedHeads  = { xi.automaton.head.STORMWAKER, xi.automaton.head.SOULSOOTHER },
        missingEffect = xi.effect.PROTECT,
    },
    {
        spellId       = xi.magic.spell.PROTECT_IV,
        mpCost        = 65,
        skillNeeded   = 217,
        allowedHeads  = { xi.automaton.head.STORMWAKER, xi.automaton.head.SOULSOOTHER },
        missingEffect = xi.effect.PROTECT,
    },
    {
        spellId       = xi.magic.spell.PROTECT_III,
        mpCost        = 46,
        skillNeeded   = 144,
        allowedHeads  = { xi.automaton.head.STORMWAKER, xi.automaton.head.SOULSOOTHER },
        missingEffect = xi.effect.PROTECT,
    },
    {
        spellId       = xi.magic.spell.PROTECT_II,
        mpCost        = 28,
        skillNeeded   =  84,
        allowedHeads  = { xi.automaton.head.STORMWAKER, xi.automaton.head.SOULSOOTHER },
        missingEffect = xi.effect.PROTECT,
    },
    {
        spellId       = xi.magic.spell.PROTECT,
        mpCost        =  9,
        skillNeeded   = 24,
        allowedHeads  = { xi.automaton.head.STORMWAKER, xi.automaton.head.SOULSOOTHER },
        missingEffect = xi.effect.PROTECT,
    },
    {
        spellId       = xi.magic.spell.SHELLRA_V,
        mpCost        = 93,
        skillNeeded   = 337,
        allowedHeads  = { xi.automaton.head.SOULSOOTHER },
        missingEffect = xi.effect.SHELL,
    },
    {
        spellId       = xi.magic.spell.SHELL_V,
        mpCost        = 93,
        skillNeeded   = 337,
        allowedHeads  = { xi.automaton.head.STORMWAKER, xi.automaton.head.SOULSOOTHER },
        missingEffect = xi.effect.SHELL,
    },
    {
        spellId       = xi.magic.spell.SHELL_IV,
        mpCost        = 75,
        skillNeeded   = 241,
        allowedHeads  = { xi.automaton.head.STORMWAKER, xi.automaton.head.SOULSOOTHER },
        missingEffect = xi.effect.SHELL,
    },
    {
        spellId       = xi.magic.spell.SHELL_III,
        mpCost        = 56,
        skillNeeded   = 188,
        allowedHeads  = { xi.automaton.head.STORMWAKER, xi.automaton.head.SOULSOOTHER },
        missingEffect = xi.effect.SHELL,
    },
    {
        spellId       = xi.magic.spell.SHELL_II,
        mpCost        = 37,
        skillNeeded   = 114,
        allowedHeads  = { xi.automaton.head.STORMWAKER, xi.automaton.head.SOULSOOTHER },
        missingEffect = xi.effect.SHELL,
    },
    {
        spellId       = xi.magic.spell.SHELL,
        mpCost        = 18,
        skillNeeded   =  54,
        allowedHeads  = { xi.automaton.head.STORMWAKER, xi.automaton.head.SOULSOOTHER },
        missingEffect = xi.effect.SHELL,
    },
    {
        spellId       = xi.magic.spell.HASTE_II,
        mpCost        = 80,
        skillNeeded   = 393,
        allowedHeads  = { xi.automaton.head.STORMWAKER },
        missingEffect = xi.effect.HASTE,
    },
    {
        spellId       = xi.magic.spell.HASTE,
        mpCost        = 40,
        skillNeeded   = 147,
        allowedHeads  = { xi.automaton.head.STORMWAKER, xi.automaton.head.SOULSOOTHER },
        missingEffect = xi.effect.HASTE,
    },
    {
        spellId       = xi.magic.spell.STONESKIN,
        mpCost        = 29,
        skillNeeded   = 105,
        allowedHeads  = { xi.automaton.head.STORMWAKER },
        missingEffect = xi.effect.STONESKIN,
    },
    {
        spellId       = xi.magic.spell.PHALANX,
        mpCost        = 21,
        skillNeeded   =  99,
        allowedHeads  = { xi.automaton.head.STORMWAKER },
        missingEffect = xi.effect.PHALANX,
    },
    {
        spellId       = xi.magic.spell.DREAD_SPIKES,
        mpCost        = 78,
        skillNeeded   = 256,
        allowedHeads  = { xi.automaton.head.SPIRITREAVER },
        missingEffect = xi.effect.DREAD_SPIKES,
        selfOnly      = true,
    },
}

xi.automaton_spellcasting.doEnhancingSpell = function(automaton)
    local master, headEquipped = getEquippedHead(automaton)

    if not headEquipped then
        return {}
    end

    local buffTargets = { master, automaton }

    if headEquipped == xi.automaton.head.SOULSOOTHER then
        local currentTarget  = automaton:getTarget()
        local targetOfTarget = currentTarget and currentTarget:getTarget()

        if targetOfTarget then
            buffTargets[#buffTargets + 1] = targetOfTarget
        end
    end

    local eligibleSpells = getEligibleSpells(automaton, headEquipped, xi.automaton_spellcasting.spellLists.enhancing)

    -- Each target is buffed fully before moving on to the next one.
    for _, buffTarget in ipairs(buffTargets) do
        local isSelf = buffTarget:getID() == automaton:getID()

        for _, spell in ipairs(eligibleSpells) do
            if
                (not spell.selfOnly or isSelf) and
                not buffTarget:hasStatusEffect(spell.missingEffect)
            then
                return { spell.spellId, buffTarget:getTargID() }
            end
        end
    end

    return {}
end

-----------------------------------
-- Enfeebling
-----------------------------------
xi.automaton_spellcasting.spellLists.enfeebling =
{
    {
        spellId        = xi.magic.spell.FRAZZLE_II,
        mpCost         = 64,
        skillNeeded    = 371,
        allowedHeads   = { xi.automaton.head.STORMWAKER },
        maneuver       = xi.element.DARK,
        missingEffects = { xi.effect.MAGIC_EVASION_DOWN },
    },
    {
        spellId        = xi.magic.spell.FRAZZLE,
        mpCost         = 38,
        skillNeeded    = 129,
        allowedHeads   = { xi.automaton.head.STORMWAKER },
        maneuver       = xi.element.DARK,
        missingEffects = { xi.effect.MAGIC_EVASION_DOWN },
    },
    {
        spellId        = xi.magic.spell.POISON_II,
        mpCost         = 38,
        skillNeeded    = 141,
        allowedHeads   = { xi.automaton.head.HARLEQUIN, xi.automaton.head.STORMWAKER, xi.automaton.head.SOULSOOTHER, xi.automaton.head.SPIRITREAVER },
        maneuver       = xi.element.WATER,
        missingEffects = { xi.effect.POISON },
        notImmune      = xi.immunity.POISON,
    },
    {
        spellId        = xi.magic.spell.POISON,
        mpCost         =  5,
        skillNeeded    = 18,
        allowedHeads   = { xi.automaton.head.HARLEQUIN, xi.automaton.head.SHARPSHOT, xi.automaton.head.STORMWAKER, xi.automaton.head.SOULSOOTHER, xi.automaton.head.SPIRITREAVER },
        maneuver       = xi.element.WATER,
        missingEffects = { xi.effect.POISON },
        notImmune      = xi.immunity.POISON,
    },
    {
        spellId      = xi.magic.spell.DISPEL,
        mpCost       = 25,
        skillNeeded  = 105,
        allowedHeads = { xi.automaton.head.STORMWAKER },
        maneuver     = xi.element.DARK,
        dispellable  = true,
        notImmune    = xi.immunity.DISPEL,
    },
    {
        spellId      = xi.magic.spell.ABSORB_ATTRI,
        mpCost       = 33,
        skillNeeded  = 368,
        allowedHeads = { xi.automaton.head.SPIRITREAVER },
        maneuver     = xi.element.DARK,
        dispellable  = true,
        notImmune    = xi.immunity.DISPEL,
    },
    {
        spellId        = xi.magic.spell.ABSORB_INT,
        mpCost         = 33,
        skillNeeded    = 120,
        allowedHeads   = { xi.automaton.head.SPIRITREAVER },
        maneuver       = xi.element.DARK,
        missingEffects = { xi.effect.INT_DOWN },
    },
    {
        spellId        = xi.magic.spell.ADDLE,
        mpCost         = 36,
        skillNeeded    = 337,
        allowedHeads   = { xi.automaton.head.HARLEQUIN, xi.automaton.head.SHARPSHOT, xi.automaton.head.STORMWAKER, xi.automaton.head.SOULSOOTHER, xi.automaton.head.SPIRITREAVER },
        maneuver       = xi.element.FIRE,
        missingEffects = { xi.effect.ADDLE },
        notImmune      = xi.immunity.ADDLE,
        innateCaster   = true,
    },
    {
        spellId        = xi.magic.spell.DISTRACT_II,
        mpCost         = 58,
        skillNeeded    = 328,
        allowedHeads   = { xi.automaton.head.STORMWAKER },
        maneuver       = xi.element.ICE,
        missingEffects = { xi.effect.EVASION_DOWN },
    },
    {
        spellId        = xi.magic.spell.DISTRACT,
        mpCost         = 32,
        skillNeeded    = 109,
        allowedHeads   = { xi.automaton.head.STORMWAKER },
        maneuver       = xi.element.ICE,
        missingEffects = { xi.effect.EVASION_DOWN },
    },
    {
        spellId        = xi.magic.spell.SILENCE,
        mpCost         = 16,
        skillNeeded    = 57,
        allowedHeads   = { xi.automaton.head.HARLEQUIN, xi.automaton.head.SHARPSHOT, xi.automaton.head.STORMWAKER, xi.automaton.head.SOULSOOTHER, xi.automaton.head.SPIRITREAVER },
        maneuver       = xi.element.WIND,
        missingEffects = { xi.effect.SILENCE },
        notImmune      = xi.immunity.SILENCE,
        innateCaster   = true,
    },
    {
        spellId        = xi.magic.spell.SLOW,
        mpCost         = 15,
        skillNeeded    = 42,
        allowedHeads   = { xi.automaton.head.HARLEQUIN, xi.automaton.head.SHARPSHOT, xi.automaton.head.STORMWAKER, xi.automaton.head.SOULSOOTHER, xi.automaton.head.SPIRITREAVER },
        maneuver       = xi.element.EARTH,
        missingEffects = { xi.effect.SLOW },
        notImmune      = xi.immunity.SLOW,
    },
    {
        spellId        = xi.magic.spell.DIA_II,
        mpCost         = 30,
        skillNeeded    = 96,
        allowedHeads   = { xi.automaton.head.HARLEQUIN, xi.automaton.head.SHARPSHOT, xi.automaton.head.STORMWAKER, xi.automaton.head.SOULSOOTHER, xi.automaton.head.SPIRITREAVER },
        maneuver       = xi.element.LIGHT,
        missingEffects = { xi.effect.DIA, xi.effect.BIO },
    },
    {
        spellId        = xi.magic.spell.BIO_II,
        mpCost         = 36,
        skillNeeded    = 111,
        allowedHeads   = { xi.automaton.head.HARLEQUIN, xi.automaton.head.SHARPSHOT, xi.automaton.head.STORMWAKER, xi.automaton.head.SOULSOOTHER, xi.automaton.head.SPIRITREAVER },
        maneuver       = xi.element.DARK,
        missingEffects = { xi.effect.BIO, xi.effect.DIA },
    },
    {
        spellId        = xi.magic.spell.DIA,
        mpCost         =  7,
        skillNeeded    =  0,
        allowedHeads   = { xi.automaton.head.HARLEQUIN, xi.automaton.head.SHARPSHOT, xi.automaton.head.STORMWAKER, xi.automaton.head.SOULSOOTHER, xi.automaton.head.SPIRITREAVER },
        maneuver       = xi.element.LIGHT,
        missingEffects = { xi.effect.DIA, xi.effect.BIO },
    },
    {
        spellId        = xi.magic.spell.BIO,
        mpCost         = 15,
        skillNeeded    = 33,
        allowedHeads   = { xi.automaton.head.HARLEQUIN, xi.automaton.head.SHARPSHOT, xi.automaton.head.STORMWAKER, xi.automaton.head.SOULSOOTHER, xi.automaton.head.SPIRITREAVER },
        maneuver       = xi.element.DARK,
        missingEffects = { xi.effect.BIO, xi.effect.DIA },
    },
    {
        spellId        = xi.magic.spell.BLIND,
        mpCost         =  5,
        skillNeeded    = 27,
        allowedHeads   = { xi.automaton.head.HARLEQUIN, xi.automaton.head.SHARPSHOT, xi.automaton.head.STORMWAKER, xi.automaton.head.SOULSOOTHER, xi.automaton.head.SPIRITREAVER },
        maneuver       = xi.element.DARK,
        missingEffects = { xi.effect.BLINDNESS },
        notImmune      = xi.immunity.BLIND,
    },
    {
        spellId        = xi.magic.spell.PARALYZE,
        mpCost         =  6,
        skillNeeded    = 21,
        allowedHeads   = { xi.automaton.head.HARLEQUIN, xi.automaton.head.SHARPSHOT, xi.automaton.head.STORMWAKER, xi.automaton.head.SOULSOOTHER, xi.automaton.head.SPIRITREAVER },
        maneuver       = xi.element.ICE,
        missingEffects = { xi.effect.PARALYSIS },
        notImmune      = xi.immunity.PARALYZE,
    },
}

xi.automaton_spellcasting.doEnfeeblingSpell = function(automaton, target)
    local master, headEquipped = getEquippedHead(automaton)

    if not headEquipped or not target then
        return {}
    end

    local activeManeuvers   = getActiveManeuverElements(master)
    local hasActiveManeuver = next(activeManeuvers) ~= nil
    local selectedSpellId   = 0
    local eligibleSpells    = getEligibleSpells(automaton, headEquipped, xi.automaton_spellcasting.spellLists.enfeebling)

    for _, spellData in ipairs(eligibleSpells) do
        local conditionsMet = true

        if
            spellData.innateCaster and
            not xi.data.job.isInnateCaster(target)
        then
            conditionsMet = false
        end

        if
            conditionsMet and
            spellData.notImmune and
            target:hasImmunity(spellData.notImmune)
        then
            conditionsMet = false
        end

        if
            conditionsMet and
            spellData.dispellable and
            not target:hasStatusEffectByFlag(xi.effectFlag.DISPELABLE)
        then
            conditionsMet = false
        end

        if
            conditionsMet and
            spellData.missingEffects
        then
            for _, missingEffect in ipairs(spellData.missingEffects) do
                if target:hasStatusEffect(missingEffect) then
                    conditionsMet = false
                    break
                end
            end
        end

        if conditionsMet then
            if hasActiveManeuver and activeManeuvers[spellData.maneuver] then
                return { spellData.spellId, target:getTargID() }
            elseif selectedSpellId == 0 then
                selectedSpellId = spellData.spellId
            end
        end
    end

    if selectedSpellId ~= 0 then
        return { selectedSpellId, target:getTargID() }
    end

    return {}
end

-----------------------------------
-- Elemental
-----------------------------------
xi.automaton_spellcasting.spellLists.elemental =
{
    {
        spellId      = xi.magic.spell.THUNDER_V,
        mpCost       = 306,
        skillNeeded  = 389,
        allowedHeads = { xi.automaton.head.SPIRITREAVER },
        element      = xi.element.THUNDER,
        baseDamage   = 874,
    },
    {
        spellId      = xi.magic.spell.BLIZZARD_V,
        mpCost       = 267,
        skillNeeded  = 368,
        allowedHeads = { xi.automaton.head.SPIRITREAVER },
        element      = xi.element.ICE,
        baseDamage   = 829,
    },
    {
        spellId      = xi.magic.spell.FIRE_V,
        mpCost       = 228,
        skillNeeded  = 349,
        allowedHeads = { xi.automaton.head.SPIRITREAVER },
        element      = xi.element.FIRE,
        baseDamage   = 785,
    },
    {
        spellId      = xi.magic.spell.AERO_V,
        mpCost       = 198,
        skillNeeded  = 331,
        allowedHeads = { xi.automaton.head.SPIRITREAVER },
        element      = xi.element.WIND,
        baseDamage   = 738,
    },
    {
        spellId      = xi.magic.spell.WATER_V,
        mpCost       = 175,
        skillNeeded  = 313,
        allowedHeads = { xi.automaton.head.SPIRITREAVER },
        element      = xi.element.WATER,
        baseDamage   = 680,
    },
    {
        spellId      = xi.magic.spell.STONE_V,
        mpCost       = 156,
        skillNeeded  = 296,
        allowedHeads = { xi.automaton.head.SPIRITREAVER },
        element      = xi.element.EARTH,
        baseDamage   = 626,
    },
    {
        spellId      = xi.magic.spell.THUNDER_IV,
        mpCost       = 171,
        skillNeeded  = 291,
        allowedHeads = { xi.automaton.head.STORMWAKER, xi.automaton.head.SPIRITREAVER },
        element      = xi.element.THUNDER,
        baseDamage   = 541,
    },
    {
        spellId      = xi.magic.spell.BLIZZARD_IV,
        mpCost       = 164,
        skillNeeded  = 286,
        allowedHeads = { xi.automaton.head.STORMWAKER, xi.automaton.head.SPIRITREAVER },
        element      = xi.element.ICE,
        baseDamage   = 506,
    },
    {
        spellId      = xi.magic.spell.FIRE_IV,
        mpCost       = 157,
        skillNeeded  = 281,
        allowedHeads = { xi.automaton.head.STORMWAKER, xi.automaton.head.SPIRITREAVER },
        element      = xi.element.FIRE,
        baseDamage   = 472,
    },
    {
        spellId      = xi.magic.spell.AERO_IV,
        mpCost       = 150,
        skillNeeded  = 276,
        allowedHeads = { xi.automaton.head.STORMWAKER, xi.automaton.head.SPIRITREAVER },
        element      = xi.element.WIND,
        baseDamage   = 440,
    },
    {
        spellId      = xi.magic.spell.WATER_IV,
        mpCost       = 144,
        skillNeeded  = 271,
        allowedHeads = { xi.automaton.head.STORMWAKER, xi.automaton.head.SPIRITREAVER },
        element      = xi.element.WATER,
        baseDamage   = 410,
    },
    {
        spellId      = xi.magic.spell.STONE_IV,
        mpCost       = 138,
        skillNeeded  = 266,
        allowedHeads = { xi.automaton.head.STORMWAKER, xi.automaton.head.SPIRITREAVER },
        element      = xi.element.EARTH,
        baseDamage   = 381,
    },
    {
        spellId      = xi.magic.spell.THUNDER_III,
        mpCost       = 128,
        skillNeeded  = 261,
        allowedHeads = { xi.automaton.head.STORMWAKER, xi.automaton.head.SPIRITREAVER },
        element      = xi.element.THUNDER,
        baseDamage   = 345,
    },
    {
        spellId      = xi.magic.spell.BLIZZARD_III,
        mpCost       = 120,
        skillNeeded  = 256,
        allowedHeads = { xi.automaton.head.STORMWAKER, xi.automaton.head.SPIRITREAVER },
        element      = xi.element.ICE,
        baseDamage   = 320,
    },
    {
        spellId      = xi.magic.spell.FIRE_III,
        mpCost       = 113,
        skillNeeded  = 251,
        allowedHeads = { xi.automaton.head.STORMWAKER, xi.automaton.head.SPIRITREAVER },
        element      = xi.element.FIRE,
        baseDamage   = 295,
    },
    {
        spellId      = xi.magic.spell.AERO_III,
        mpCost       = 106,
        skillNeeded  = 246,
        allowedHeads = { xi.automaton.head.STORMWAKER, xi.automaton.head.SPIRITREAVER },
        element      = xi.element.WIND,
        baseDamage   = 265,
    },
    {
        spellId      = xi.magic.spell.WATER_III,
        mpCost       =  98,
        skillNeeded  = 236,
        allowedHeads = { xi.automaton.head.STORMWAKER, xi.automaton.head.SPIRITREAVER },
        element      = xi.element.WATER,
        baseDamage   = 236,
    },
    {
        spellId      = xi.magic.spell.STONE_III,
        mpCost       =  92,
        skillNeeded  = 227,
        allowedHeads = { xi.automaton.head.STORMWAKER, xi.automaton.head.SPIRITREAVER },
        element      = xi.element.EARTH,
        baseDamage   = 210,
    },
    {
        spellId      = xi.magic.spell.THUNDER_II,
        mpCost       =  86,
        skillNeeded  = 203,
        allowedHeads = { xi.automaton.head.STORMWAKER, xi.automaton.head.SPIRITREAVER },
        element      = xi.element.THUNDER,
        baseDamage   = 178,
    },
    {
        spellId      = xi.magic.spell.BLIZZARD_II,
        mpCost       =  77,
        skillNeeded  = 178,
        allowedHeads = { xi.automaton.head.STORMWAKER, xi.automaton.head.SPIRITREAVER },
        element      = xi.element.ICE,
        baseDamage   = 155,
    },
    {
        spellId      = xi.magic.spell.FIRE_II,
        mpCost       =  68,
        skillNeeded  = 153,
        allowedHeads = { xi.automaton.head.STORMWAKER, xi.automaton.head.SPIRITREAVER },
        element      = xi.element.FIRE,
        baseDamage   = 133,
    },
    {
        spellId      = xi.magic.spell.AERO_II,
        mpCost       =  59,
        skillNeeded  = 138,
        allowedHeads = { xi.automaton.head.STORMWAKER, xi.automaton.head.SPIRITREAVER },
        element      = xi.element.WIND,
        baseDamage   = 113,
    },
    {
        spellId      = xi.magic.spell.WATER_II,
        mpCost       =  51,
        skillNeeded  = 123,
        allowedHeads = { xi.automaton.head.STORMWAKER, xi.automaton.head.SPIRITREAVER },
        element      = xi.element.WATER,
        baseDamage   =  95,
    },
    {
        spellId      = xi.magic.spell.STONE_II,
        mpCost       =  43,
        skillNeeded  = 108,
        allowedHeads = { xi.automaton.head.STORMWAKER, xi.automaton.head.SPIRITREAVER },
        element      = xi.element.EARTH,
        baseDamage   =  78,
    },
    {
        spellId      = xi.magic.spell.THUNDER,
        mpCost       =  37,
        skillNeeded  =  90,
        allowedHeads = { xi.automaton.head.STORMWAKER, xi.automaton.head.SPIRITREAVER },
        element      = xi.element.THUNDER,
        baseDamage   =  60,
    },
    {
        spellId      = xi.magic.spell.BLIZZARD,
        mpCost       =  30,
        skillNeeded  =  75,
        allowedHeads = { xi.automaton.head.STORMWAKER, xi.automaton.head.SPIRITREAVER },
        element      = xi.element.ICE,
        baseDamage   =  46,
    },
    {
        spellId      = xi.magic.spell.FIRE,
        mpCost       =  24,
        skillNeeded  =  60,
        allowedHeads = { xi.automaton.head.STORMWAKER, xi.automaton.head.SPIRITREAVER },
        element      = xi.element.FIRE,
        baseDamage   =  35,
    },
    {
        spellId      = xi.magic.spell.AERO,
        mpCost       =  18,
        skillNeeded  =  45,
        allowedHeads = { xi.automaton.head.STORMWAKER, xi.automaton.head.SPIRITREAVER },
        element      = xi.element.WIND,
        baseDamage   =  25,
    },
    {
        spellId      = xi.magic.spell.WATER,
        mpCost       =  13,
        skillNeeded  =  30,
        allowedHeads = { xi.automaton.head.STORMWAKER, xi.automaton.head.SPIRITREAVER },
        element      = xi.element.WATER,
        baseDamage   =  16,
    },
    {
        spellId      = xi.magic.spell.STONE,
        mpCost       =   9,
        skillNeeded  =  15,
        allowedHeads = { xi.automaton.head.STORMWAKER, xi.automaton.head.SPIRITREAVER },
        element      = xi.element.EARTH,
        baseDamage   =  10,
    },
}

xi.automaton_spellcasting.doElementalSpell = function(automaton, target)
    local master, headEquipped = getEquippedHead(automaton)

    if not headEquipped or not target then
        return {}
    end

    local targetHP        = target:getHP()
    local activeManeuvers = getActiveManeuverElements(master)
    local eligibleSpells  = getEligibleSpells(automaton, headEquipped, xi.automaton_spellcasting.spellLists.elemental)

    local killSpell        = nil
    local bestBoostedSpell = nil
    local bestNormalSpell  = nil

    for _, spellData in ipairs(eligibleSpells) do
        -- Kill check: most MP-efficient spell that guarantees the kill
        if
            spellData.baseDamage >= targetHP and
            (killSpell == nil or spellData.mpCost < killSpell.mpCost)
        then
            killSpell = spellData
        end

        if activeManeuvers[spellData.element] then
            if not bestBoostedSpell then
                bestBoostedSpell = spellData
            end
        elseif not bestNormalSpell then
            bestNormalSpell = spellData
        end
    end

    local selectedSpell = killSpell or bestBoostedSpell or bestNormalSpell

    if selectedSpell then
        return { selectedSpell.spellId, target:getTargID() }
    end

    return {}
end

-----------------------------------
-- Magic burst
-----------------------------------
xi.automaton_spellcasting.doMagicBurst = function(automaton, target)
    local _, headEquipped = getEquippedHead(automaton)

    if not headEquipped or not target then
        return {}
    end

    -- Tier 0 is an unformed opening weaponskill and cannot be burst.
    local resonance = target:getStatusEffect(xi.effect.SKILLCHAIN)

    if
        not resonance or
        resonance:getTier() <= 0
    then
        return {}
    end

    local skillchainType = resonance:getPower()
    local eligibleSpells = getEligibleSpells(automaton, headEquipped, xi.automaton_spellcasting.spellLists.elemental)

    for _, spellData in ipairs(eligibleSpells) do
        if xi.data.element.skillchainElementTable[spellData.element][skillchainType] > 0 then
            return { spellData.spellId, target:getTargID() }
        end
    end

    return {}
end

-----------------------------------
-- Dark
-----------------------------------
xi.automaton_spellcasting.spellLists.dark =
{
    {
        spellId      = xi.magic.spell.DRAIN,
        mpCost       = 21,
        skillNeeded  =  45,
        allowedHeads = { xi.automaton.head.SPIRITREAVER },
    },
    {
        spellId      = xi.magic.spell.ASPIR_II,
        mpCost       = 15,
        skillNeeded  = 331,
        allowedHeads = { xi.automaton.head.SPIRITREAVER },
    },
    {
        spellId      = xi.magic.spell.ASPIR,
        mpCost       = 10,
        skillNeeded  =  78,
        allowedHeads = { xi.automaton.head.SPIRITREAVER },
    },
}

xi.automaton_spellcasting.doDarkSpell = function(automaton, target)
    local _, headEquipped = getEquippedHead(automaton)

    if not headEquipped or not target then
        return {}
    end

    local eligibleSpells = getEligibleSpells(automaton, headEquipped, xi.automaton_spellcasting.spellLists.dark)

    if #eligibleSpells == 0 then
        return {}
    end

    local mpp      = automaton:getMaxMP() > 0 and (automaton:getMP() / automaton:getMaxMP() * 100) or 100
    local hpp      = automaton:getHPP()
    local canDrain = not target:isUndead()
    local canAspir = not target:isUndead() and not target:hasImmunity(xi.immunity.ASPIR) and target:getMaxMP() > 0

    local function findSpell(...)
        for _, spell in ipairs(eligibleSpells) do
            for _, wantedId in ipairs({ ... }) do
                if spell.spellId == wantedId then
                    return spell.spellId
                end
            end
        end

        return 0
    end

    local selectedSpellId = 0

    -- Aspir has priority when MP is low (Aspir II preferred via list order),
    -- but Drain is prioritized when HP is also low.
    if
        mpp < 75 and
        hpp >= 75 and
        canAspir
    then
        selectedSpellId = findSpell(xi.magic.spell.ASPIR_II, xi.magic.spell.ASPIR)
    end

    -- Drain is the fallback regardless of HP level
    if
        selectedSpellId == 0 and
        canDrain
    then
        selectedSpellId = findSpell(xi.magic.spell.DRAIN)
    end

    if
        selectedSpellId == 0 and
        mpp < 75 and
        canAspir
    then
        selectedSpellId = findSpell(xi.magic.spell.ASPIR_II, xi.magic.spell.ASPIR)
    end

    if selectedSpellId ~= 0 then
        return { selectedSpellId, target:getTargID() }
    end

    return {}
end
