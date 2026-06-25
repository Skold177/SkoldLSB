/*
===========================================================================

  Copyright (c) 2010-2015 Darkstar Dev Teams

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see http://www.gnu.org/licenses/

===========================================================================
*/

#include "automaton_controller.h"

#include "ai/ai_container.h"
#include "ai/states/ability_state.h"
#include "ai/states/magic_state.h"
#include "ai/states/weaponskill_state.h"
#include "common/database.h"
#include "common/utils.h"
#include "enmity_container.h"
#include "entities/trust_entity.h"
#include "enums/automaton.h"
#include "lua/luautils.h"
#include "mobskill.h"
#include "recast_container.h"
#include "status_effect_container.h"
#include "utils/battleutils.h"
#include "utils/itemutils.h"
#include "utils/petutils.h"
#include "utils/puppetutils.h"

namespace
{
    auto extractResonanceProperties(CStatusEffect* PSCEffect) -> std::list<SKILLCHAIN_ELEMENT>
    {
        std::list<SKILLCHAIN_ELEMENT> resonanceProperties;
        if (uint16 power = PSCEffect->GetPower())
        {
            if (power & 0xF)        resonanceProperties.emplace_back(static_cast<SKILLCHAIN_ELEMENT>(power & 0xF));
            if ((power >> 4) & 0xF) resonanceProperties.emplace_back(static_cast<SKILLCHAIN_ELEMENT>((power >> 4) & 0xF));
            if (power >> 8)         resonanceProperties.emplace_back(static_cast<SKILLCHAIN_ELEMENT>(power >> 8));
        }
        return resonanceProperties;
    }
} // namespace

CAutomatonController::CAutomatonController(CAutomatonEntity* PPet)
: CPetController(PPet)
, PAutomaton(PPet)
{
    setCooldowns();
    if (shouldStandBack())
    {
        PAutomaton->m_Behavior |= BEHAVIOR_STANDBACK;
    }
}

void CAutomatonController::setCooldowns()
{
    switch (PAutomaton->frame())
    {
        case AutomatonFrame::Sharpshot:
        {
            switch (PAutomaton->head())
            {
                case AutomatonHead::Sharpshot:
                    m_rangedCooldown = 20s;
                    break;
                case AutomatonHead::Harlequin:
                    m_rangedCooldown = 25s;
                    break;
                default:
                    m_rangedCooldown = 36s;
            }
        }
        break;
        case AutomatonFrame::Harlequin:
        {
            setMagicCooldowns();
        }
        break;
        case AutomatonFrame::Stormwaker:
        {
            setMagicCooldowns();
        }
        break;
        case AutomatonFrame::Valoredge:
        {
            m_shieldbashCooldown = 3min;
        }
    }
}

// New retail Automaton magic AI (Needs more information to accurately recreate)
void CAutomatonController::setMagicCooldowns()
{
    const auto headKey      = static_cast<uint8>(PAutomaton->head());
    const auto maybeHeadRow = lua["xi"]["automaton_spellcasting"]["cooldowns"][headKey].get<sol::optional<sol::table>>();
    if (!maybeHeadRow)
    {
        ShowErrorFmt("CAutomatonController::setMagicCooldowns() - Missing xi.automaton_spellcasting.cooldowns for head {:d}", headKey);
        return;
    }

    const auto& row = *maybeHeadRow;

    auto getSeconds = [&](const char* key) -> timer::duration
    {
        const auto val = row[key].get<sol::optional<uint32>>();
        return val ? std::chrono::seconds(*val) : 0s;
    };

    m_magicCooldown     = getSeconds("overall");
    m_healCooldown      = getSeconds("healing");
    m_enfeebleCooldown  = getSeconds("enfeebling");
    m_elementalCooldown = getSeconds("elemental");
    m_statusCooldown    = getSeconds("statusRemoval");
    m_enhanceCooldown   = getSeconds("enhancing");
    m_darkCooldown      = getSeconds("dark");
}

// Determines standback behavior for the Automaton.
// Type 2 animators override all behavior, Valor Edge frame will always enter melee, followed
// by ranged head types defaulting to ranged behavior.
auto CAutomatonController::shouldStandBack() const -> bool
{
    const CBattleEntity* PMaster = PAutomaton->PMaster;

    if (PMaster)
    {
        CItemWeapon* animator = dynamic_cast<CItemWeapon*>(PMaster->m_Weapons[SLOT_AMMO]);

        if (animator && animator->getSubSkillType() == SUBSKILLTYPE::SUBSKILL_ANIMATOR_II)
        {
            return true;
        }
        else if (PAutomaton->frame() == AutomatonFrame::Valoredge)
        {
            return false;
        }
        else if (PAutomaton->head() >= AutomatonHead::Sharpshot)
        {
            return true;
        }
    }

    return false;
}

auto CAutomatonController::GetCurrentManeuvers() const -> CurrentManeuvers
{
    const auto& statuses = PAutomaton->PMaster->StatusEffectContainer;
    return {
        statuses->GetEffectsCount(xi::StatusEffect::FireManeuver),
        statuses->GetEffectsCount(xi::StatusEffect::IceManeuver),
        statuses->GetEffectsCount(xi::StatusEffect::WindManeuver),
        statuses->GetEffectsCount(xi::StatusEffect::EarthManeuver),
        statuses->GetEffectsCount(xi::StatusEffect::ThunderManeuver),
        statuses->GetEffectsCount(xi::StatusEffect::WaterManeuver),
        statuses->GetEffectsCount(xi::StatusEffect::LightManeuver),
        statuses->GetEffectsCount(xi::StatusEffect::DarkManeuver),
    };
}

auto CAutomatonController::DoCombatTick(timer::time_point tick) -> Task<void>
{
    if (PAutomaton->PMaster == nullptr || PAutomaton->PMaster->isDead())
    {
        if (PAutomaton->isAlive())
        {
            PAutomaton->Die();
        }
        co_return;
    }

    PTarget = static_cast<CBattleEntity*>(PAutomaton->GetEntity(PAutomaton->GetBattleTargetID()));

    if (TryDeaggro())
    {
        Disengage();
        co_return;
    }

    // Automatons only attempt actions in 3 second intervals (Reduced by the Tactical Processor)
    if (TryAction())
    {
        if (TryShieldBash())
        {
            m_LastShieldBashTime = m_Tick;
            co_return;
        }
        else if (TryMagicBurst())
        {
            m_LastMagicTime     = m_Tick;
            m_LastElementalTime = m_Tick;
            co_return;
        }
        else if (TrySpellcast())
        {
            m_LastMagicTime = m_Tick;
            co_return;
        }
        else if (TryTPMove())
        {
            co_return;
        }
        else if (TryRangedAttack())
        {
            m_LastRangedTime = m_Tick;
            co_return;
        }
        else if (TryAttachment())
        {
            co_return;
        }
    }

    Move();
}

void CAutomatonController::Move()
{
    if ((PTarget && shouldStandBack() && !isWithinDistance(PAutomaton->loc.p, PTarget->loc.p, 15.0f)) ||
        (PAutomaton->health.mp < 8 && PAutomaton->health.maxmp > 8))
    {
        PAutomaton->m_Behavior &= ~BEHAVIOR_STANDBACK;
    }

    CPetController::Move();
}

auto CAutomatonController::TryAction() -> bool
{
    if (m_Tick > m_LastActionTime + (m_actionCooldown - std::chrono::milliseconds(PAutomaton->getMod(Mod::AUTO_DECISION_DELAY) * 10)))
    {
        m_LastActionTime = m_Tick;
        PAutomaton->PAI->EventHandler.triggerListener("AUTOMATON_AI_TICK", PAutomaton, PTarget);

        return true;
    }

    return false;
}

auto CAutomatonController::TryShieldBash() -> bool
{
    if (!PTarget)
    {
        return false;
    }

    CState* PState = PTarget->PAI->GetCurrentState();

    if (m_shieldbashCooldown > 0s && PState && PState->CanInterrupt() &&
        m_Tick > m_LastShieldBashTime + (m_shieldbashCooldown - std::chrono::seconds(PAutomaton->getMod(Mod::AUTO_SHIELD_BASH_DELAY))))
    {
        return MobSkill(PTarget->targid, m_ShieldBashAbility, std::nullopt);
    }

    return false;
}

auto CAutomatonController::TrySpellcast() -> bool
{
    if (!PAutomaton->PMaster || m_magicCooldown == 0s ||
        m_Tick <= m_LastMagicTime + (m_magicCooldown + std::chrono::seconds(PAutomaton->getMod(Mod::AUTO_MAGIC_COOLDOWN))) || !CanCastSpells(IgnoreRecastsAndCosts::Yes))
    {
        return false;
    }

    const auto maneuvers = GetCurrentManeuvers();

    switch (PAutomaton->head())
    {
        case AutomatonHead::Valoredge:
        {
            if (TryHeal())
            {
                m_LastHealTime = m_Tick;
                return true;
            }
        }
        break;
        case AutomatonHead::Sharpshot:
        {
            if (TryHeal())
            {
                m_LastHealTime = m_Tick;
                return true;
            }
            else if (TryEnfeeble())
            {
                m_LastEnfeebleTime = m_Tick;
                return true;
            }
        }
        break;
        case AutomatonHead::Harlequin:
        {
            if (TryHeal())
            {
                m_LastHealTime = m_Tick;
                return true;
            }
            else if (TryEnfeeble())
            {
                m_LastEnfeebleTime = m_Tick;
                return true;
            }
        }
        break;
        case AutomatonHead::Stormwaker:
        {
            bool lowHP = PTarget && PTarget->GetHPP() <= 30 && PTarget->health.hp <= 300;
            if (lowHP && TryElemental())
            {
                m_LastElementalTime = m_Tick;
                return true;
            }

            if (TryHeal())
            {
                m_LastHealTime = m_Tick;
                return true;
            }
            else if (TryEnhance())
            {
                m_LastEnhanceTime = m_Tick;
                return true;
            }
            else if (TryEnfeeble())
            {
                m_LastEnfeebleTime = m_Tick;
                return true;
            }
            else if (TryElemental())
            {
                m_LastElementalTime = m_Tick;
                return true;
            }
        }
        break;
        case AutomatonHead::Soulsoother:
        {
            if (TryHeal())
            {
                m_LastHealTime = m_Tick;
                return true;
            }
            else if (TryStatusRemoval())
            {
                m_LastStatusTime = m_Tick;
                return true;
            }
            else if (TryEnhance())
            {
                m_LastEnhanceTime = m_Tick;
                return true;
            }
            else if (TryEnfeeble())
            {
                m_LastEnfeebleTime = m_Tick;
                return true;
            }
        }
        break;
        case AutomatonHead::Spiritreaver:
        {
            const int  maxOtherManeuver = std::max({ maneuvers.fire, maneuvers.ice, maneuvers.wind, maneuvers.earth, maneuvers.thunder, maneuvers.water, maneuvers.light });
            const bool darkDominant     = maneuvers.dark > maxOtherManeuver;

            if (darkDominant && TryEnfeeble())
            {
                m_LastEnfeebleTime = m_Tick;
                return true;
            }
            else if (darkDominant && TryEnhance())
            {
                m_LastEnhanceTime = m_Tick;
                return true;
            }
            else if (TryElemental())
            {
                m_LastElementalTime = m_Tick;
                return true;
            }
            else if (TryDark())
            {
                m_LastDarkTime = m_Tick;
                return true;
            }
        }
    }
    return false;
}

// Spell selection entry points return { spellId, targetTargId }, or an empty table.
auto CAutomatonController::CastAutomatonSpell(const sol::table& result) -> bool
{
    const auto selectedSpell = result.get_or(1, uint16(0));
    if (selectedSpell == 0)
    {
        return false;
    }

    const auto   spellId      = static_cast<SpellID>(selectedSpell);
    const uint16 targetTargId = result.get_or(2, uint16(0));
    auto*        PSpellTarget = static_cast<CBattleEntity*>(PAutomaton->GetEntity(targetTargId));

    if (!PSpellTarget || PAutomaton->PRecastContainer->HasRecast(RECAST_MAGIC, static_cast<Recast>(spellId), 0s))
    {
        return false;
    }

    return Cast(PSpellTarget->targid, spellId);
}

auto CAutomatonController::TryHeal() -> bool
{
    if (!PAutomaton->PMaster || m_healCooldown == 0s ||
        m_Tick <= m_LastHealTime + (m_healCooldown - std::chrono::seconds(PAutomaton->getMod(Mod::AUTO_HEALING_DELAY))))
    {
        return false;
    }

    return CastAutomatonSpell(luautils::callGlobal<sol::table>("xi.automaton_spellcasting.doHealingSpell", PAutomaton, PTarget));
}

auto CAutomatonController::TryMagicBurst() -> bool
{
    if (!PAutomaton->PMaster || !PTarget || PAutomaton->getMod(Mod::MAGIC_BURST_BONUS_UNCAPPED) == 0)
    {
        return false;
    }

    // Burst bypasses the normal magic cooldown — only blocked if the automaton is actively casting
    if (!CanCastSpells(IgnoreRecastsAndCosts::Yes))
    {
        return false;
    }

    // Resonance validity and element matching are decided by the script.
    CStatusEffect* PSCEffect = PTarget->StatusEffectContainer->GetStatusEffect(xi::StatusEffect::Skillchain, 0);
    if (!PSCEffect || timer::now() >= PSCEffect->GetStartTime() + 3s)
    {
        return false;
    }

    return CastAutomatonSpell(luautils::callGlobal<sol::table>("xi.automaton_spellcasting.doMagicBurst", PAutomaton, PTarget));
}

auto CAutomatonController::TryEnfeeble() -> bool
{
    if (!PAutomaton->PMaster || m_enfeebleCooldown == 0s || m_Tick <= m_LastEnfeebleTime + m_enfeebleCooldown)
    {
        return false;
    }

    return CastAutomatonSpell(luautils::callGlobal<sol::table>("xi.automaton_spellcasting.doEnfeeblingSpell", PAutomaton, PTarget));
}

auto CAutomatonController::TryStatusRemoval() -> bool
{
    if (!PAutomaton->PMaster || m_statusCooldown == 0s || m_Tick <= m_LastStatusTime + m_statusCooldown)
    {
        return false;
    }

    return CastAutomatonSpell(luautils::callGlobal<sol::table>("xi.automaton_spellcasting.doStatusRemovalSpell", PAutomaton));
}

auto CAutomatonController::TryEnhance() -> bool
{
    if (!PAutomaton->PMaster || m_enhanceCooldown == 0s || m_Tick <= m_LastEnhanceTime + m_enhanceCooldown)
    {
        return false;
    }

    return CastAutomatonSpell(luautils::callGlobal<sol::table>("xi.automaton_spellcasting.doEnhancingSpell", PAutomaton));
}

auto CAutomatonController::TryElemental() -> bool
{
    if (!PAutomaton->PMaster || m_elementalCooldown == 0s || m_Tick <= m_LastElementalTime + m_elementalCooldown)
    {
        return false;
    }

    return CastAutomatonSpell(luautils::callGlobal<sol::table>("xi.automaton_spellcasting.doElementalSpell", PAutomaton, PTarget));
}

auto CAutomatonController::TryDark() -> bool
{
    if (!PAutomaton->PMaster || m_darkCooldown == 0s || m_Tick <= m_LastDarkTime + m_darkCooldown)
    {
        return false;
    }

    return CastAutomatonSpell(luautils::callGlobal<sol::table>("xi.automaton_spellcasting.doDarkSpell", PAutomaton, PTarget));
}

auto CAutomatonController::TryTPMove() -> bool
{
    if (!PTarget)
    {
        return false;
    }

    if (PAutomaton->health.tp >= 1000)
    {
        const auto& FrameSkills = battleutils::GetMobSkillList(PAutomaton->m_MobSkillList);

        std::vector<CMobSkill*> validSkills;

        // load the skills that the automaton has access to with it's skill
        SKILLTYPE skilltype = SKILL_AUTOMATON_MELEE;

        if (PAutomaton->frame() == AutomatonFrame::Sharpshot)
        {
            skilltype = SKILL_AUTOMATON_RANGED;
        }

        for (auto skillid : FrameSkills)
        {
            auto* PSkill = battleutils::GetMobSkill(skillid);
            if (PSkill && PAutomaton->GetSkill(skilltype) > PSkill->getParam() && PSkill->getParam() != -1 &&
                distance(PAutomaton->loc.p, PTarget->loc.p) < PSkill->getRadius())
            {
                validSkills.emplace_back(PSkill);
            }
        }

        int16      currentSkill     = -1;
        CMobSkill* PWSkill          = nullptr;
        int8       currentManeuvers = -1;

        bool attemptChain = (PAutomaton->getMod(Mod::AUTO_TP_EFFICIENCY) != 0);

        if (attemptChain)
        {
            CStatusEffect* PSCEffect = PTarget->StatusEffectContainer->GetStatusEffect(xi::StatusEffect::Skillchain, 0);
            auto           now       = timer::now();
            if (PSCEffect && now > PSCEffect->GetStartTime() + 1s && now < PSCEffect->GetStartTime() + 3s)
            {
                const auto resonanceProperties = extractResonanceProperties(PSCEffect);

                for (auto* PSkill : validSkills)
                {
                    if (PSkill->getParam() > currentSkill)
                    {
                        std::list<SKILLCHAIN_ELEMENT> skillProperties;
                        skillProperties.emplace_back((SKILLCHAIN_ELEMENT)PSkill->getPrimarySkillchain());
                        skillProperties.emplace_back((SKILLCHAIN_ELEMENT)PSkill->getSecondarySkillchain());
                        skillProperties.emplace_back((SKILLCHAIN_ELEMENT)PSkill->getTertiarySkillchain());
                        if (battleutils::FormSkillchain(resonanceProperties, skillProperties) != SC_NONE)
                        {
                            currentManeuvers = 1;
                            currentSkill     = PSkill->getParam();
                            PWSkill          = PSkill;
                        }
                    }
                }
            }
        }

        if (!attemptChain || (currentManeuvers == -1 && PAutomaton->PMaster && PAutomaton->PMaster->health.tp < PAutomaton->getMod(Mod::AUTO_TP_EFFICIENCY)))
        {
            for (auto* PSkill : validSkills)
            {
                int8 maneuvers = luautils::OnAutomatonAbilityCheck(PTarget, PAutomaton, PSkill);
                if (maneuvers > -1 && (maneuvers > currentManeuvers || (maneuvers == currentManeuvers && PSkill->getParam() > currentSkill)))
                {
                    currentManeuvers = maneuvers;
                    currentSkill     = PSkill->getParam();
                    PWSkill          = PSkill;
                }
            }
        }

        // No WS was chosen (waiting on master's TP to skillchain probably)
        if (currentManeuvers == -1)
        {
            return false;
        }

        if (PWSkill)
        {
            return MobSkill(PTarget->targid, PWSkill->getID(), std::nullopt);
        }
    }
    return false;
}

auto CAutomatonController::TryRangedAttack() -> bool // TODO: Find the animation for its ranged attack
{
    if (!PTarget)
    {
        return false;
    }

    if (PAutomaton->frame() == AutomatonFrame::Sharpshot)
    {
        timer::duration minDelay   = PAutomaton->head() == AutomatonHead::Sharpshot ? 5s : 10s;
        timer::duration attackTime = m_rangedCooldown - std::chrono::seconds(PAutomaton->getMod(Mod::AUTO_RANGED_DELAY));

        if (m_rangedCooldown > 0s && m_Tick > m_LastRangedTime + std::max(attackTime, minDelay))
        {
            return MobSkill(PTarget->targid, m_RangedAbility, std::nullopt);
        }
    }

    return false;
}

auto CAutomatonController::TryAttachment() -> bool
{
    if (!PAutomaton->PAI->CanChangeState())
    {
        return false;
    }

    PAutomaton->PAI->EventHandler.triggerListener("AUTOMATON_ATTACHMENT_CHECK", PAutomaton, PTarget);

    return false;
}

auto CAutomatonController::CanCastSpells(IgnoreRecastsAndCosts) -> bool
{
    if (PAutomaton->StatusEffectContainer->HasStatusEffect({ xi::StatusEffect::Silence, xi::StatusEffect::Mute }))
    {
        return false;
    }

    return PAutomaton->PAI->CanChangeState();
}

auto CAutomatonController::Cast(uint16 targid, SpellID spellid) -> bool
{
    if (PAutomaton->PRecastContainer->HasRecast(RECAST_MAGIC, static_cast<Recast>(spellid), 0s))
    {
        return false;
    }

    return CPetController::Cast(targid, spellid);
}

auto CAutomatonController::MobSkill(uint16 targid, uint16 wsid, Maybe<timer::duration> castTimeOverride) -> bool
{
    if (PAutomaton->PRecastContainer->HasRecast(RECAST_ABILITY, static_cast<Recast>(wsid), 0s))
    {
        return false;
    }
    return CPetController::MobSkill(targid, wsid, castTimeOverride);
}

auto CAutomatonController::Disengage() -> bool
{
    PTarget = nullptr;
    if (shouldStandBack())
    {
        PAutomaton->m_Behavior |= BEHAVIOR_STANDBACK;
    }
    return CMobController::Disengage();
}

namespace automaton
{

std::unordered_map<uint16, AutomatonAbility> autoAbilityList;

void LoadAutomatonAbilities()
{
    const auto rset = db::preparedStmt("SELECT abilityid, abilityname, reqframe, skilllevel FROM automaton_abilities");

    if (rset && rset->rowsCount())
    {
        while (rset->next())
        {
            uint16 id = rset->get<uint16>("abilityid");

            AutomatonAbility PAbility{
                .requiredFrame = rset->get<uint8>("reqframe"),
                .skillLevel    = rset->get<uint16>("skilllevel"),
            };

            autoAbilityList[id] = PAbility;

            const auto abilityName = rset->get<std::string>("abilityname");

            const auto filename = fmt::format("./scripts/actions/abilities/pets/automaton/{}.lua", abilityName);
            luautils::LoadLuaObjectFromFile(filename);
        }
    }
}

} // namespace automaton
