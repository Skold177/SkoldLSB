-----------------------------------
-- Global file for spell interruption.
-----------------------------------
xi = xi or {}
xi.combat = xi.combat or {}
xi.combat.magicInterrupt = xi.combat.magicInterrupt or {}
-----------------------------------

---Return whether a spell being cast should be interrupted.
---@param attacker CBaseEntity
---@param caster CBaseEntity
---@param spell CSpell
---@return boolean
xi.combat.magicInterrupt.shouldInterruptSpell = function(attacker, caster, spell)
    -- Early return: Songs can't be interrupted.
    local skillType = spell:getSkillType()
    if skillType == xi.skill.SINGING then
        return false
    end

    -- Early return: Manafont prevents interruptions.
    if caster:hasStatusEffect(xi.effect.MANAFONT) then
        return false
    end

    -- Early return: Chainspell prevents interruptions.
    if caster:hasStatusEffect(xi.effect.CHAINSPELL) then
        return false
    end

    -- Level factor.
    local baseInterruptionRate = caster:isMob() and 5 or 50
    local levelRatio           = math.max((baseInterruptionRate + attacker:getMainLvl() - caster:getMainLvl()) / 100, 0.01)

    -- Skill factor.
    local skillRatio = 1

    if caster:isPC() then
        local skillCap   = caster:getMaxSkillLevel(caster:getMainLvl(), caster:getMainJob(), skillType)
        local skillLevel = caster:getSkillLevel(skillType)

        -- If skill cap is 0, player may be using a spell from their subjob.
        if skillCap == 0 then
            skillCap = caster:getMaxSkillLevel(caster:getMainLvl(), caster:getSubJob(), skillType)
        end

        -- If skill level is 0, set ratio to 10.
        if skillLevel <= 0 then
            skillRatio = 10
        else
            skillRatio = skillCap / skillLevel
        end
    end

    -- SIRD reduces the interrupt after all the calculations are done -- as evidenced by the infamous "102% SIRD" builds.
    -- Anything less than 102% interrupt results in the ability to be interrupted.
    -- Note: the 102% is probably an x/256 x/1024 nonsense -- sometimes 101% works.
    local sirdRatio = (100 - caster:getMerit(xi.merit.SPELL_INTERRUPTION_RATE) - caster:getMod(xi.mod.SPELLINTERRUPT)) / 100

    -- levelRatio : 0.01 to infinity.
    -- skillRatio : 1 to infinity.
    -- sirdRatio  : No limits. Can be negative. A negative value will guarantee NOT being interrupted.
    local finalRatio = levelRatio * skillRatio * sirdRatio -- TL;DR Higher = Worse = More chances to get interrupted.

    -- Early return: Caster doesn't get interrupted.
    if math.randomFloat(0, 1) >= finalRatio then
        return false
    end

    -- Early return: Caster can't prevent interruption via Aquaveil.
    if not caster:hasStatusEffect(xi.effect.AQUAVEIL) then
        return true
    end

    -- Handle Aquaveil. Consumes a charge but still prevents the interruption.
    local aquaveilEffect = caster:getStatusEffect(xi.effect.AQUAVEIL)
    local aquaveilPower  = aquaveilEffect:getPower() - 1

    if aquaveilPower == 0 then
        caster:delStatusEffect(xi.effect.AQUAVEIL)
    else
        aquaveilEffect:setPower(aquaveilPower)
    end

    return false
end
