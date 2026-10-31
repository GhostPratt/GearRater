-- GearRater stat weights per class and spec (WoW 3.3.5a).
--
-- Principle: every stat that does anything for the character gets a weight, however small.
-- Only stats that literally do nothing for that class are zero (Intellect on a warrior,
-- parry rating on a druid, nature spell damage on a paladin, feral attack power on a mage).
--
-- Weights are relative within a profile. Conventions:
--   physical DPS    1 Attack Power = 1.0
--   casters/healers 1 Spell Power = 1.0
--   tanks           1 Stamina = 1.0
-- Main values follow the WotLK-era community consensus (Elitist Jerks / Wowhead / Pawn
-- default scales); the small "still useful" values are judgement calls. Edit in game with
-- /gr weight STAT value (saved per profile); this file is only the default.
--
-- Special keys handled by the scorer:
--   DPS_MELEE / DPS_RANGED  weapon DPS, applied by the item's equip slot
--   SOCKETS                 value of one empty socket (roughly a rare gem of the main stat)
--   RESISTANCE / SLAYER     single-school resistance / "+N Beast Slaying" style enchants
--   schools = { FIRE = 1, ... }  fraction of SPELL_POWER weight given to school-only spell damage;
--                                schools not listed are worth nothing to that spec
-- Rating variants (HIT_MELEE_RATING, HIT_SPELL_RATING, ...) fall back to the generic rating when
-- the profile's attack type matches ("melee", "ranged" or "spell").

GearRater = GearRater or {}

local explicit = {}   -- weights table -> the keys a profile set itself (class rules never override those)

local function merge(base, extra)
    local t = {}
    for k, v in pairs(base) do t[k] = v end
    for k, v in pairs(extra) do t[k] = v end
    explicit[t] = extra
    return t
end

-- Role templates ---------------------------------------------------------------------------

local COMMON = {   -- things everyone can use
    STAMINA = 0.1, HEALTH = 0.01, HEALTH_REGEN = 0.05,
    ALL_RESISTANCES = 0.1, RESISTANCE = 0.03, RESILIENCE_RATING = 0.2,
    DEFENSE_SKILL_RATING = 0.1, DODGE_RATING = 0.1, PARRY_RATING = 0.1,
    BLOCK_RATING = 0.05, BLOCK_VALUE = 0.02,
    SPIRIT = 0.02, INTELLECT = 0.02, MANA = 0.01, MANA_REGENERATION = 0.05,
}

local MELEE = merge(COMMON, {
    ATTACK_POWER = 1, ARMOR = 0.02, RANGED_ATTACK_POWER = 0.02, DPS_RANGED = 0.05,
    SLAYER = 0.1, SPELL_PENETRATION = 0.02,
})
local RANGED = merge(COMMON, {
    ATTACK_POWER = 1, RANGED_ATTACK_POWER = 1, ARMOR = 0.02, DPS_MELEE = 0.05,
    SPIRIT = 0.1, MANA = 0.02, MANA_REGENERATION = 0.2, EXPERTISE_RATING = 0.02, SLAYER = 0.1,
})
local CASTER = merge(COMMON, {
    SPELL_POWER = 1, SPELL_DAMAGE_DONE = 1, SPELL_HEALING_DONE = 0.2, SPELL_PENETRATION = 0.1,
    MANA = 0.02, MANA_REGENERATION = 0.3, ARMOR = 0.015, PARRY_RATING = 0.05,
    ATTACK_POWER = 0.05, DPS_MELEE = 0.1, EXPERTISE_RATING = 0.02, ARMOR_PENETRATION_RATING = 0.02, SLAYER = 0.02,
})
local HEALER = merge(COMMON, {
    SPELL_POWER = 1, SPELL_HEALING_DONE = 1, SPELL_DAMAGE_DONE = 0.2, SPELL_PENETRATION = 0.02,
    STAMINA = 0.15, MANA = 0.03, MANA_REGENERATION = 0.5, ARMOR = 0.015, ALL_RESISTANCES = 0.15, RESISTANCE = 0.05,
    PARRY_RATING = 0.05, ATTACK_POWER = 0.05, DPS_MELEE = 0.1, EXPERTISE_RATING = 0.02,
    ARMOR_PENETRATION_RATING = 0.02, SLAYER = 0.02,
})
local TANK = merge(COMMON, {
    STAMINA = 1, HEALTH = 0.1, HEALTH_REGEN = 0.1, ARMOR = 0.05, ALL_RESISTANCES = 0.3, RESISTANCE = 0.1,
    RESILIENCE_RATING = 0.3, DPS_RANGED = 0.02, CRIT_RATING = 0.1, HASTE_RATING = 0.05,
    ARMOR_PENETRATION_RATING = 0.05, SLAYER = 0.05,
})

local P = {}
GearRater.Profiles = P

-- WARRIOR -------------------------------------------------------------------------------
P["Warrior: Arms"] = { class = "WARRIOR", tab = 1, attack = "melee", weights = merge(MELEE, {
    STRENGTH = 2.3, AGILITY = 0.7, HIT_RATING = 1.9, CRIT_RATING = 1.4, EXPERTISE_RATING = 1.8,
    ARMOR_PENETRATION_RATING = 1.5, HASTE_RATING = 0.7, DPS_MELEE = 4.6, SOCKETS = 37 }) }
P["Warrior: Fury"] = { class = "WARRIOR", tab = 2, attack = "melee", weights = merge(MELEE, {
    STRENGTH = 2.3, AGILITY = 0.8, HIT_RATING = 1.8, CRIT_RATING = 1.6, EXPERTISE_RATING = 1.5,
    ARMOR_PENETRATION_RATING = 1.4, HASTE_RATING = 1.0, DPS_MELEE = 3.8, SOCKETS = 37 }) }
P["Warrior: Protection"] = { class = "WARRIOR", tab = 3, attack = "melee", weights = merge(TANK, {
    STRENGTH = 0.5, AGILITY = 0.6, DEFENSE_SKILL_RATING = 0.9, DODGE_RATING = 0.8, PARRY_RATING = 0.7,
    BLOCK_RATING = 0.2, BLOCK_VALUE = 0.3, HIT_RATING = 0.3, EXPERTISE_RATING = 0.5, ATTACK_POWER = 0.05,
    DPS_MELEE = 0.4, SOCKETS = 24 }) }

-- PALADIN -------------------------------------------------------------------------------
P["Paladin: Holy"] = { class = "PALADIN", tab = 1, attack = "spell", schools = { HOLY = 1 }, weights = merge(HEALER, {
    INTELLECT = 1.3, CRIT_RATING = 0.7, HASTE_RATING = 0.6, MANA_REGENERATION = 1.0, SPIRIT = 0.1,
    STRENGTH = 0.03, SOCKETS = 19 }) }
P["Paladin: Protection"] = { class = "PALADIN", tab = 2, attack = "melee", schools = { HOLY = 1 }, weights = merge(TANK, {
    STRENGTH = 0.6, AGILITY = 0.5, DEFENSE_SKILL_RATING = 0.9, DODGE_RATING = 0.8, PARRY_RATING = 0.7,
    BLOCK_RATING = 0.3, BLOCK_VALUE = 0.4, HIT_RATING = 0.4, EXPERTISE_RATING = 0.6, SPELL_POWER = 0.1,
    INTELLECT = 0.1, ATTACK_POWER = 0.05, DPS_MELEE = 0.4, SOCKETS = 24 }) }
P["Paladin: Retribution"] = { class = "PALADIN", tab = 3, attack = "melee", schools = { HOLY = 1 }, weights = merge(MELEE, {
    STRENGTH = 2.4, AGILITY = 0.5, HIT_RATING = 1.9, CRIT_RATING = 1.5, EXPERTISE_RATING = 1.3, HASTE_RATING = 1.0,
    ARMOR_PENETRATION_RATING = 0.6, SPELL_POWER = 0.3, INTELLECT = 0.1, MANA_REGENERATION = 0.1,
    DPS_MELEE = 5.0, SOCKETS = 38 }) }

-- HUNTER --------------------------------------------------------------------------------
-- Hunter shots and stings are arcane/nature/fire school spells but scale from ranged attack power
-- only: AzerothCore's spell_bonus_data gives every hunter ability a spell power coefficient of 0, and
-- mod-individual-progression does not change that. Spell power and school damage are therefore zero.
P["Hunter: Beast Mastery"] = { class = "HUNTER", tab = 1, attack = "ranged", weights = merge(RANGED, {
    AGILITY = 2.2, INTELLECT = 0.9, HIT_RATING = 2.0, CRIT_RATING = 1.5, ARMOR_PENETRATION_RATING = 0.9,
    HASTE_RATING = 0.9, STRENGTH = 0.05, DPS_RANGED = 5.0, SOCKETS = 35 }) }
P["Hunter: Marksmanship"] = { class = "HUNTER", tab = 2, attack = "ranged", weights = merge(RANGED, {
    AGILITY = 2.0, INTELLECT = 0.7, HIT_RATING = 2.0, CRIT_RATING = 1.6, ARMOR_PENETRATION_RATING = 1.4,
    HASTE_RATING = 1.0, STRENGTH = 0.05, DPS_RANGED = 5.0, SOCKETS = 32 }) }
P["Hunter: Survival"] = { class = "HUNTER", tab = 3, attack = "ranged", weights = merge(RANGED, {
    AGILITY = 2.4, INTELLECT = 0.7, HIT_RATING = 2.0, CRIT_RATING = 1.6, ARMOR_PENETRATION_RATING = 0.8,
    HASTE_RATING = 1.0, STRENGTH = 0.05, DPS_RANGED = 5.0, SOCKETS = 38 }) }

-- ROGUE ---------------------------------------------------------------------------------
P["Rogue: Assassination"] = { class = "ROGUE", tab = 1, attack = "melee", weights = merge(MELEE, {
    AGILITY = 2.3, STRENGTH = 1.1, HIT_RATING = 1.9, CRIT_RATING = 1.6, EXPERTISE_RATING = 1.3, HASTE_RATING = 1.2,
    ARMOR_PENETRATION_RATING = 0.9, STEALTH = 0.3, DPS_MELEE = 3.5, SOCKETS = 37 }) }
P["Rogue: Combat"] = { class = "ROGUE", tab = 2, attack = "melee", weights = merge(MELEE, {
    AGILITY = 2.1, STRENGTH = 1.1, HIT_RATING = 1.9, CRIT_RATING = 1.4, EXPERTISE_RATING = 1.7, HASTE_RATING = 1.4,
    ARMOR_PENETRATION_RATING = 1.6, STEALTH = 0.3, DPS_MELEE = 4.0, SOCKETS = 34 }) }
P["Rogue: Subtlety"] = { class = "ROGUE", tab = 3, attack = "melee", weights = merge(MELEE, {
    AGILITY = 2.3, STRENGTH = 1.1, HIT_RATING = 1.9, CRIT_RATING = 1.5, EXPERTISE_RATING = 1.3, HASTE_RATING = 1.3,
    ARMOR_PENETRATION_RATING = 1.0, STEALTH = 0.5, DPS_MELEE = 3.5, SOCKETS = 37 }) }

-- PRIEST --------------------------------------------------------------------------------
P["Priest: Discipline"] = { class = "PRIEST", tab = 1, attack = "spell", schools = { HOLY = 1, SHADOW = 0.3 }, weights = merge(HEALER, {
    INTELLECT = 1.1, SPIRIT = 0.5, CRIT_RATING = 0.8, HASTE_RATING = 0.8, MANA_REGENERATION = 0.9, HIT_RATING = 0.1, SOCKETS = 18 }) }
P["Priest: Holy"] = { class = "PRIEST", tab = 2, attack = "spell", schools = { HOLY = 1, SHADOW = 0.3 }, weights = merge(HEALER, {
    INTELLECT = 1.0, SPIRIT = 0.9, CRIT_RATING = 0.6, HASTE_RATING = 0.9, MANA_REGENERATION = 1.0, HIT_RATING = 0.1, SOCKETS = 18 }) }
P["Priest: Shadow"] = { class = "PRIEST", tab = 3, attack = "spell", schools = { SHADOW = 1, HOLY = 0.1 }, weights = merge(CASTER, {
    HIT_RATING = 1.4, CRIT_RATING = 0.7, HASTE_RATING = 0.9, SPIRIT = 0.4, INTELLECT = 0.3, SOCKETS = 19 }) }

-- DEATH KNIGHT --------------------------------------------------------------------------
P["Death Knight: Blood"] = { class = "DEATHKNIGHT", tab = 1, attack = "melee", weights = merge(MELEE, {
    STRENGTH = 2.5, AGILITY = 0.4, HIT_RATING = 1.7, CRIT_RATING = 1.3, EXPERTISE_RATING = 1.3, HASTE_RATING = 1.0,
    ARMOR_PENETRATION_RATING = 1.5, DPS_MELEE = 5.0, SOCKETS = 40 }) }
P["Death Knight: Frost"] = { class = "DEATHKNIGHT", tab = 2, attack = "melee", weights = merge(MELEE, {
    STRENGTH = 2.4, AGILITY = 0.4, HIT_RATING = 1.7, CRIT_RATING = 1.4, EXPERTISE_RATING = 1.3, HASTE_RATING = 1.3,
    ARMOR_PENETRATION_RATING = 1.0, DPS_MELEE = 4.5, SOCKETS = 38 }) }
P["Death Knight: Unholy"] = { class = "DEATHKNIGHT", tab = 3, attack = "melee", weights = merge(MELEE, {
    STRENGTH = 2.4, AGILITY = 0.4, HIT_RATING = 1.7, CRIT_RATING = 1.2, EXPERTISE_RATING = 1.3, HASTE_RATING = 1.4,
    ARMOR_PENETRATION_RATING = 0.8, DPS_MELEE = 4.5, SOCKETS = 38 }) }
P["Death Knight: Tank"] = { class = "DEATHKNIGHT", manual = true, attack = "melee", weights = merge(TANK, {
    STRENGTH = 0.5, AGILITY = 0.6, DEFENSE_SKILL_RATING = 0.9, DODGE_RATING = 0.8, PARRY_RATING = 0.8,
    HIT_RATING = 0.3, EXPERTISE_RATING = 0.5, ATTACK_POWER = 0.05, DPS_MELEE = 0.6, SOCKETS = 24 }) }

-- SHAMAN --------------------------------------------------------------------------------
P["Shaman: Elemental"] = { class = "SHAMAN", tab = 1, attack = "spell", schools = { NATURE = 1, FIRE = 0.7, FROST = 0.2 }, weights = merge(CASTER, {
    HIT_RATING = 1.3, CRIT_RATING = 0.8, HASTE_RATING = 1.0, INTELLECT = 0.4, MANA_REGENERATION = 0.2, SOCKETS = 19 }) }
P["Shaman: Enhancement"] = { class = "SHAMAN", tab = 2, attack = "melee", schools = { NATURE = 1, FIRE = 1, FROST = 0.5 }, weights = merge(MELEE, {
    AGILITY = 1.7, STRENGTH = 1.0, INTELLECT = 1.0, HIT_RATING = 1.9, CRIT_RATING = 1.3, EXPERTISE_RATING = 1.5,
    HASTE_RATING = 1.3, ARMOR_PENETRATION_RATING = 0.6, SPELL_POWER = 0.5, MANA_REGENERATION = 0.1,
    DPS_MELEE = 3.5, SOCKETS = 28 }) }
P["Shaman: Restoration"] = { class = "SHAMAN", tab = 3, attack = "spell", schools = { NATURE = 1, FIRE = 0.1, FROST = 0.1 }, weights = merge(HEALER, {
    INTELLECT = 1.0, MANA_REGENERATION = 1.2, CRIT_RATING = 0.7, HASTE_RATING = 0.8, SPIRIT = 0.1, HIT_RATING = 0.1, SOCKETS = 18 }) }

-- MAGE ----------------------------------------------------------------------------------
P["Mage: Arcane"] = { class = "MAGE", tab = 1, attack = "spell", schools = { ARCANE = 1, FIRE = 0.3, FROST = 0.3 }, weights = merge(CASTER, {
    HIT_RATING = 1.4, CRIT_RATING = 0.6, HASTE_RATING = 1.1, INTELLECT = 0.5, SPIRIT = 0.3, SOCKETS = 19 }) }
P["Mage: Fire"] = { class = "MAGE", tab = 2, attack = "spell", schools = { FIRE = 1, ARCANE = 0.1, FROST = 0.1 }, weights = merge(CASTER, {
    HIT_RATING = 1.4, CRIT_RATING = 1.0, HASTE_RATING = 1.0, INTELLECT = 0.4, SPIRIT = 0.2, SOCKETS = 19 }) }
P["Mage: Frost"] = { class = "MAGE", tab = 3, attack = "spell", schools = { FROST = 1, FIRE = 0.1, ARCANE = 0.1 }, weights = merge(CASTER, {
    HIT_RATING = 1.4, CRIT_RATING = 0.8, HASTE_RATING = 0.9, INTELLECT = 0.4, SOCKETS = 19 }) }

-- WARLOCK -------------------------------------------------------------------------------
P["Warlock: Affliction"] = { class = "WARLOCK", tab = 1, attack = "spell", schools = { SHADOW = 1, FIRE = 0.2 }, weights = merge(CASTER, {
    HIT_RATING = 1.5, HASTE_RATING = 1.0, CRIT_RATING = 0.5, SPIRIT = 0.4, INTELLECT = 0.2, SOCKETS = 19 }) }
P["Warlock: Demonology"] = { class = "WARLOCK", tab = 2, attack = "spell", schools = { SHADOW = 1, FIRE = 0.5 }, weights = merge(CASTER, {
    HIT_RATING = 1.5, HASTE_RATING = 0.9, CRIT_RATING = 0.7, SPIRIT = 0.4, INTELLECT = 0.2, SOCKETS = 19 }) }
P["Warlock: Destruction"] = { class = "WARLOCK", tab = 3, attack = "spell", schools = { FIRE = 1, SHADOW = 0.5 }, weights = merge(CASTER, {
    HIT_RATING = 1.5, HASTE_RATING = 1.0, CRIT_RATING = 0.9, SPIRIT = 0.3, INTELLECT = 0.2, SOCKETS = 19 }) }

-- DRUID ---------------------------------------------------------------------------------
P["Druid: Balance"] = { class = "DRUID", tab = 1, attack = "spell", schools = { ARCANE = 1, NATURE = 1 }, weights = merge(CASTER, {
    HIT_RATING = 1.4, CRIT_RATING = 0.9, HASTE_RATING = 1.0, INTELLECT = 0.4, SPIRIT = 0.3, FERAL_ATTACK_POWER = 0.02, SOCKETS = 19 }) }
P["Druid: Feral (Cat)"] = { class = "DRUID", tab = 2, attack = "melee", schools = { NATURE = 1, ARCANE = 1 }, weights = merge(MELEE, {
    AGILITY = 2.2, STRENGTH = 1.9, FERAL_ATTACK_POWER = 1, HIT_RATING = 1.6, CRIT_RATING = 1.4, EXPERTISE_RATING = 1.2,
    HASTE_RATING = 0.9, ARMOR_PENETRATION_RATING = 1.2, SPELL_POWER = 0.05, INTELLECT = 0.05, MANA_REGENERATION = 0.05,
    STEALTH = 0.3, SOCKETS = 35 }) }
P["Druid: Feral (Bear)"] = { class = "DRUID", manual = true, attack = "melee", schools = { NATURE = 1, ARCANE = 1 }, weights = merge(TANK, {
    AGILITY = 0.8, STRENGTH = 0.3, ATTACK_POWER = 0.15, FERAL_ATTACK_POWER = 0.15, DODGE_RATING = 0.7,
    DEFENSE_SKILL_RATING = 0.5, ARMOR = 0.12, HIT_RATING = 0.2, EXPERTISE_RATING = 0.4, CRIT_RATING = 0.2,
    SPELL_POWER = 0.05, STEALTH = 0.3, SOCKETS = 24 }) }
P["Druid: Restoration"] = { class = "DRUID", tab = 3, attack = "spell", schools = { NATURE = 1, ARCANE = 0.1 }, weights = merge(HEALER, {
    INTELLECT = 0.9, SPIRIT = 1.0, HASTE_RATING = 0.9, CRIT_RATING = 0.4, MANA_REGENERATION = 0.9, HIT_RATING = 0.1,
    FERAL_ATTACK_POWER = 0.02, SOCKETS = 18 }) }

-- Profile used when the character has no talent points yet (leveling defaults).
GearRater.ClassDefault = {
    WARRIOR = "Warrior: Arms",          PALADIN = "Paladin: Retribution", HUNTER = "Hunter: Beast Mastery",
    ROGUE = "Rogue: Combat",            PRIEST = "Priest: Shadow",        DEATHKNIGHT = "Death Knight: Blood",
    SHAMAN = "Shaman: Enhancement",     MAGE = "Mage: Frost",             WARLOCK = "Warlock: Affliction",
    DRUID = "Druid: Feral (Cat)",
}

-- Class capabilities: stats that do nothing at all for a class are forced to zero, unless the
-- profile set them explicitly. Wand classes still get a little for wand DPS (Shoot).
local ZERO = 0
local classRules = {
    WARRIOR     = { INTELLECT = ZERO, MANA = ZERO, MANA_REGENERATION = ZERO, FERAL_ATTACK_POWER = ZERO, SPELL_POWER = ZERO, SPELL_PENETRATION = ZERO },
    ROGUE       = { INTELLECT = ZERO, MANA = ZERO, MANA_REGENERATION = ZERO, FERAL_ATTACK_POWER = ZERO, SPELL_POWER = ZERO, SPELL_PENETRATION = ZERO,
                    BLOCK_RATING = ZERO, BLOCK_VALUE = ZERO },
    DEATHKNIGHT = { INTELLECT = ZERO, MANA = ZERO, MANA_REGENERATION = ZERO, FERAL_ATTACK_POWER = ZERO, SPELL_POWER = ZERO,
                    BLOCK_RATING = ZERO, BLOCK_VALUE = ZERO, RANGED_ATTACK_POWER = ZERO, DPS_RANGED = ZERO },
    PALADIN     = { FERAL_ATTACK_POWER = ZERO, RANGED_ATTACK_POWER = ZERO, DPS_RANGED = ZERO },
    SHAMAN      = { FERAL_ATTACK_POWER = ZERO, RANGED_ATTACK_POWER = ZERO, DPS_RANGED = ZERO, PARRY_RATING = ZERO },
    DRUID       = { RANGED_ATTACK_POWER = ZERO, DPS_RANGED = ZERO, PARRY_RATING = ZERO, BLOCK_RATING = ZERO, BLOCK_VALUE = ZERO },
    HUNTER      = { FERAL_ATTACK_POWER = ZERO, BLOCK_RATING = ZERO, BLOCK_VALUE = ZERO, SPELL_POWER = ZERO, SPELL_PENETRATION = ZERO },
    MAGE        = { FERAL_ATTACK_POWER = ZERO, RANGED_ATTACK_POWER = ZERO, DPS_RANGED = 0.15, PARRY_RATING = ZERO, BLOCK_RATING = ZERO, BLOCK_VALUE = ZERO },
    PRIEST      = { FERAL_ATTACK_POWER = ZERO, RANGED_ATTACK_POWER = ZERO, DPS_RANGED = 0.15, PARRY_RATING = ZERO, BLOCK_RATING = ZERO, BLOCK_VALUE = ZERO },
    WARLOCK     = { FERAL_ATTACK_POWER = ZERO, RANGED_ATTACK_POWER = ZERO, DPS_RANGED = 0.15, PARRY_RATING = ZERO, BLOCK_RATING = ZERO, BLOCK_VALUE = ZERO },
}

-- class -> talent tab index -> profile name
GearRater.SpecProfile = {}
for name, prof in pairs(P) do
    prof.name = name
    local rules, own = classRules[prof.class], explicit[prof.weights] or {}
    if rules then
        for key, value in pairs(rules) do
            if own[key] == nil then prof.weights[key] = value end
        end
    end
    if prof.tab then
        GearRater.SpecProfile[prof.class] = GearRater.SpecProfile[prof.class] or {}
        GearRater.SpecProfile[prof.class][prof.tab] = name
    end
end
