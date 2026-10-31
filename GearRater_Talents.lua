-- GearRater talent awareness: adjust a profile's weights for the talents the character has
-- actually taken, and zero ratings the character has already capped.
--
-- Rule shapes (all values are per rank unless `ranks` gives the value for each rank):
--   mult    = { STAT = fraction }          "+3% Strength per rank": weight(STAT) *= 1 + rank*fraction
--   ranks   = { r1, r2, r3 }               uneven multipliers, e.g. Demonic Embrace 4/7/10% Stamina
--   apMult  = fraction                     "+2% attack power per rank": scales AP and the stats that feed it
--   convert = { { from = "INT", to = "RANGED_ATTACK_POWER", frac = 1/3 } }
--                                          "33% of Intellect as ranged AP per rank": weight(from) += rank*frac*weight(to)
--   hit     = percent                      hit chance from talents (for the hit cap)
--   expertise = points                     expertise from talents (reported; GetExpertise already includes it)
--   only    = { "Profile name" }           rule applies to these profiles only (Heart of the Wild cat/bear)
-- Talent names are the enUS client names (3.3.5a).

GearRater = GearRater or {}
local GR = GearRater

local AP_FEEDERS = {   -- stats whose weight is mostly attack power for these classes
    WARRIOR = { "STRENGTH" }, PALADIN = { "STRENGTH" }, DEATHKNIGHT = { "STRENGTH" },
    ROGUE = { "AGILITY" }, HUNTER = { "AGILITY" }, DRUID = { "AGILITY", "STRENGTH", "FERAL_ATTACK_POWER" },
    SHAMAN = { "AGILITY", "STRENGTH" },
}

GR.TalentRules = {
    WARRIOR = {
        ["Strength of Arms"]        = { mult = { STRENGTH = 0.02, STAMINA = 0.02 }, expertise = 2 },
        ["Vitality"]                = { mult = { STRENGTH = 0.02, STAMINA = 0.03 }, expertise = 2 },
        ["Armored to the Teeth"]    = { convert = { { from = "ARMOR", to = "ATTACK_POWER", frac = 1 / 108 } } },
        ["Improved Berserker Stance"] = { apMult = 0.02, only = { "Warrior: Fury" } },
        ["Precision"]               = { hit = 1 },
    },
    PALADIN = {
        ["Divine Strength"]         = { mult = { STRENGTH = 0.03 } },
        ["Divine Intellect"]        = { mult = { INTELLECT = 0.02 } },
        ["Sacred Duty"]             = { mult = { STAMINA = 0.04 } },
        ["Combat Expertise"]        = { mult = { STAMINA = 0.02 }, expertise = 2 },
        ["Touched by the Light"]    = { convert = { { from = "STRENGTH", to = "SPELL_POWER", frac = 0.2 } } },
        ["Sheath of Light"]         = { convert = { { from = "ATTACK_POWER", to = "SPELL_POWER", frac = 0.1 } } },
        ["Holy Guidance"]           = { convert = { { from = "INTELLECT", to = "SPELL_POWER", frac = 0.04 } } },
        ["Enlightened Judgements"]  = { hit = 1 },
    },
    HUNTER = {
        ["Combat Experience"]       = { mult = { AGILITY = 0.01, INTELLECT = 0.01 } },
        ["Careful Aim"]             = { convert = { { from = "INTELLECT", to = "RANGED_ATTACK_POWER", frac = 1 / 3 } } },
        ["Lightning Reflexes"]      = { mult = { AGILITY = 0.03 } },
        ["Hunting Party"]           = { mult = { AGILITY = 0.01 } },
        ["Hunter vs. Wild"]         = { convert = { { from = "STAMINA", to = "RANGED_ATTACK_POWER", frac = 0.1 } } },
        ["Focused Aim"]             = { hit = 1 },
    },
    ROGUE = {
        ["Sinister Calling"]        = { mult = { AGILITY = 0.03 } },
        ["Deadliness"]              = { apMult = 0.02 },
        ["Savage Combat"]           = { apMult = 0.02 },
        ["Vitality"]                = { mult = { STAMINA = 0.02, AGILITY = 0.01 } },
        ["Precision"]               = { hit = 1 },
        ["Weapon Expertise"]        = { expertise = 5 },
    },
    PRIEST = {
        ["Mental Strength"]         = { mult = { INTELLECT = 0.03 } },
        ["Enlightenment"]           = { mult = { SPIRIT = 0.02 } },
        ["Improved Power Word: Fortitude"] = { mult = { STAMINA = 0.02 } },
        ["Spiritual Guidance"]      = { convert = { { from = "SPIRIT", to = "SPELL_POWER", frac = 0.05 } } },
        ["Twisted Faith"]           = { convert = { { from = "SPIRIT", to = "SPELL_POWER", frac = 0.04 } } },
        ["Shadow Focus"]            = { hit = 1 },
    },
    DEATHKNIGHT = {
        ["Veteran of the Third War"] = { mult = { STRENGTH = 0.02, STAMINA = 0.01 }, expertise = 2 },
        ["Abomination's Might"]     = { apMult = 0.01 },
        ["Bladed Armor"]            = { convert = { { from = "ARMOR", to = "ATTACK_POWER", frac = 1 / 180 } } },
        ["Ravenous Dead"]           = { mult = { STRENGTH = 0.01 } },
        ["Endless Winter"]          = { mult = { STRENGTH = 0.02 } },
        ["Toughness"]               = { mult = { ARMOR = 0.02 } },
        ["Nerves of Cold Steel"]    = { hit = 1 },
    },
    SHAMAN = {
        ["Ancestral Knowledge"]     = { mult = { INTELLECT = 0.02 } },
        ["Toughness"]               = { mult = { STAMINA = 0.02 } },
        ["Mental Quickness"]        = { convert = { { from = "ATTACK_POWER", to = "SPELL_POWER", frac = 0.1 } } },
        ["Mental Dexterity"]        = { convert = { { from = "INTELLECT", to = "ATTACK_POWER", frac = 1 / 3 } } },
        ["Unrelenting Storm"]       = { convert = { { from = "INTELLECT", to = "MANA_REGENERATION", frac = 0.04 } } },
        ["Nature's Blessing"]       = { convert = { { from = "INTELLECT", to = "SPELL_POWER", frac = 0.05 } } },
        ["Elemental Precision"]     = { hit = 1 },
        ["Dual Wield Specialization"] = { hit = 2 },
    },
    MAGE = {
        ["Arcane Mind"]             = { mult = { INTELLECT = 0.03 } },
        ["Mind Mastery"]            = { convert = { { from = "INTELLECT", to = "SPELL_POWER", frac = 0.03 } } },
        ["Student of the Mind"]     = { ranks = { SPIRIT = { 0.04, 0.07, 0.10 } } },
        ["Arcane Fortitude"]        = { convert = { { from = "INTELLECT", to = "ARMOR", frac = 0.5 } } },
        ["Arcane Focus"]            = { hit = 1 },
        ["Precision"]               = { hit = 1 },
    },
    WARLOCK = {
        ["Demonic Embrace"]         = { ranks = { STAMINA = { 0.04, 0.07, 0.10 } } },
        ["Fel Vitality"]            = { mult = { INTELLECT = 0.01, STAMINA = 0.01 } },
        ["Suppression"]             = { hit = 1 },
    },
    DRUID = {
        ["Heart of the Wild"]       = { mult = { INTELLECT = 0.02 } },
        ["Heart of the Wild (cat)"] = { talent = "Heart of the Wild", apMult = 0.02, only = { "Druid: Feral (Cat)" } },
        ["Heart of the Wild (bear)"] = { talent = "Heart of the Wild", mult = { STAMINA = 0.02 }, only = { "Druid: Feral (Bear)" } },
        ["Survival of the Fittest"] = { mult = { STRENGTH = 0.02, AGILITY = 0.02, STAMINA = 0.02, INTELLECT = 0.02, SPIRIT = 0.02 } },
        ["Improved Mark of the Wild"] = { mult = { STRENGTH = 0.01, AGILITY = 0.01, STAMINA = 0.01, INTELLECT = 0.01, SPIRIT = 0.01 } },
        ["Living Spirit"]           = { mult = { SPIRIT = 0.05 } },
        ["Furor"]                   = { mult = { INTELLECT = 0.02 } },
        ["Lunar Guidance"]          = { convert = { { from = "INTELLECT", to = "SPELL_POWER", frac = 0.04 } } },
        ["Dreamstate"]              = { ranks = {}, convertRanks = { from = "INTELLECT", to = "MANA_REGENERATION", fracs = { 0.04, 0.07, 0.10 } } },
        ["Balance of Power"]        = { hit = 2 },
    },
}

-- Caps against a boss-level target (3.3.5a).
GR.Caps = {
    hit = { melee = 8, ranged = 8, spell = 17 },   -- percent
    expertise = 26,                                -- dodge removed
    defense = 540,                                 -- crit immune
}

-------------------------------------------------------------------------------
-- Reading talents
-------------------------------------------------------------------------------

local talentRanks   -- name -> rank, for the active talent group

function GR.InvalidateTalents()
    talentRanks = nil
end

local function ReadTalents()
    if talentRanks then return talentRanks end
    talentRanks = {}
    local group = GetActiveTalentGroup and GetActiveTalentGroup() or 1
    for tab = 1, (GetNumTalentTabs and GetNumTalentTabs() or 3) do
        for i = 1, (GetNumTalents and GetNumTalents(tab) or 0) do
            local name, _, _, _, rank = GetTalentInfo(tab, i, false, false, group)
            if name and rank and rank > 0 then talentRanks[name] = rank end
        end
    end
    return talentRanks
end

local function AppliesTo(rule, profile)
    if not rule.only then return true end
    for _, n in ipairs(rule.only) do if n == profile.name then return true end end
    return false
end

-------------------------------------------------------------------------------
-- Applying rules
-------------------------------------------------------------------------------

-- Returns adjusted weights and a list of human readable notes.
function GR.ApplyTalents(profile, w)
    local rules = GR.TalentRules[profile.class]
    local ranks = ReadTalents()
    local notes = {}
    local out = {}
    for k, v in pairs(w) do out[k] = v end
    if not rules then return out, notes, 0 end

    local mult, apMult, talentHit, talentExp = {}, 1, 0, 0
    local conversions = {}

    for label, rule in pairs(rules) do
        local rank = ranks[rule.talent or label] or 0
        if rank > 0 and AppliesTo(rule, profile) then
            if rule.mult then
                for stat, frac in pairs(rule.mult) do
                    mult[stat] = (mult[stat] or 1) * (1 + rank * frac)
                end
                notes[#notes + 1] = string.format("%s %d/%d: stat multipliers", label, rank, rank)
            end
            if rule.ranks then
                for stat, perRank in pairs(rule.ranks) do
                    local frac = perRank[math.min(rank, #perRank)] or 0
                    mult[stat] = (mult[stat] or 1) * (1 + frac)
                end
                if next(rule.ranks) then notes[#notes + 1] = string.format("%s rank %d: stat multiplier", label, rank) end
            end
            if rule.apMult then
                apMult = apMult * (1 + rank * rule.apMult)
                notes[#notes + 1] = string.format("%s rank %d: +%d%% attack power", label, rank, rank * rule.apMult * 100)
            end
            if rule.convert then
                for _, c in ipairs(rule.convert) do
                    conversions[#conversions + 1] = { from = c.from, to = c.to, frac = c.frac * rank, label = label }
                end
            end
            if rule.convertRanks then
                local c = rule.convertRanks
                conversions[#conversions + 1] = { from = c.from, to = c.to, frac = c.fracs[math.min(rank, #c.fracs)], label = label }
            end
            if rule.hit then talentHit = talentHit + rank * rule.hit end
            if rule.expertise then talentExp = talentExp + rank * rule.expertise end
        end
    end

    -- attack power multiplier: AP itself and the stats that mostly feed it
    if apMult ~= 1 then
        for _, k in ipairs({ "ATTACK_POWER", "RANGED_ATTACK_POWER", "FERAL_ATTACK_POWER" }) do
            mult[k] = (mult[k] or 1) * apMult
        end
        for _, k in ipairs(AP_FEEDERS[profile.class] or {}) do
            mult[k] = (mult[k] or 1) * apMult
        end
    end

    -- multipliers first
    for stat, m in pairs(mult) do
        if out[stat] then out[stat] = out[stat] * m end
    end
    -- then conversions, valued at the (already multiplied) target weight
    for _, c in ipairs(conversions) do
        local target = out[c.to] or 0
        if target > 0 then
            local gain = c.frac * target * (mult[c.from] or 1)
            out[c.from] = (out[c.from] or 0) + gain
            notes[#notes + 1] = string.format("%s: %s worth +%.2f via %s", c.label, c.from, gain, c.to)
        end
    end

    return out, notes, talentHit, talentExp
end

-------------------------------------------------------------------------------
-- Caps
-------------------------------------------------------------------------------

local CR = { melee = CR_HIT_MELEE or 6, ranged = CR_HIT_RANGED or 7, spell = CR_HIT_SPELL or 8 }

-- Zero the ratings the character has already capped. Returns weights and notes.
function GR.ApplyCaps(profile, w, talentHit)
    local notes = {}
    if not GetCombatRatingBonus then return w, notes end
    local attack = profile.attack or "melee"
    local hitPct = (GetCombatRatingBonus(CR[attack]) or 0) + (talentHit or 0)
    local cap = GR.Caps.hit[attack]
    if w.HIT_RATING and w.HIT_RATING > 0 and cap and hitPct >= cap then
        w.HIT_RATING = 0
        notes[#notes + 1] = string.format("hit capped (%.1f%% of %d%%): hit rating worth 0", hitPct, cap)
    end
    if attack == "melee" and w.EXPERTISE_RATING and w.EXPERTISE_RATING > 0 and GetExpertise then
        local exp = GetExpertise() or 0
        if exp >= GR.Caps.expertise then
            w.EXPERTISE_RATING = 0
            notes[#notes + 1] = string.format("expertise capped (%d of %d): expertise rating worth 0", exp, GR.Caps.expertise)
        end
    end
    if w.DEFENSE_SKILL_RATING and w.DEFENSE_SKILL_RATING >= 0.5 and UnitDefense then
        local base, mod = UnitDefense("player")
        local def = (base or 0) + (mod or 0)
        if def >= GR.Caps.defense then
            w.DEFENSE_SKILL_RATING = 0
            notes[#notes + 1] = string.format("defense capped (%d of %d): defense rating worth 0", def, GR.Caps.defense)
        end
    end
    return w, notes
end

-- Full adjustment used by the scorer. Returns weights, notes.
function GR.AdjustWeights(profile, w)
    if GearRaterDB and GearRaterDB.talents == false then return w, {} end
    local adjusted, notes, talentHit = GR.ApplyTalents(profile, w)
    if GearRaterDB and GearRaterDB.caps ~= false then
        local capNotes
        adjusted, capNotes = GR.ApplyCaps(profile, adjusted, talentHit)
        for _, n in ipairs(capNotes) do notes[#notes + 1] = n end
    end
    return adjusted, notes
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_TALENT_UPDATE")
f:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
f:RegisterEvent("CHARACTER_POINTS_CHANGED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function() GR.InvalidateTalents() end)
