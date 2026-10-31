-- GearRater scoring: pick the player's profile from class and talents, then weight parsed stats.

GearRater = GearRater or {}
local GR = GearRater

GearRaterCharDB = GearRaterCharDB or {}   -- per character: { profile = "Druid: Feral (Bear)" }

-- Rating variants fall back to the generic rating when the attack type matches the profile.
local aliases = {
    HIT_MELEE_RATING   = { "HIT_RATING", "melee" },  HIT_RANGED_RATING   = { "HIT_RATING", "ranged" },  HIT_SPELL_RATING   = { "HIT_RATING", "spell" },
    CRIT_MELEE_RATING  = { "CRIT_RATING", "melee" }, CRIT_RANGED_RATING  = { "CRIT_RATING", "ranged" }, CRIT_SPELL_RATING  = { "CRIT_RATING", "spell" },
    HASTE_MELEE_RATING = { "HASTE_RATING", "melee" }, HASTE_RANGED_RATING = { "HASTE_RATING", "ranged" }, HASTE_SPELL_RATING = { "HASTE_RATING", "spell" },
    HIT_TAKEN_MELEE_RATING = { "RESILIENCE_RATING" }, HIT_TAKEN_RANGED_RATING = { "RESILIENCE_RATING" }, HIT_TAKEN_SPELL_RATING = { "RESILIENCE_RATING" },
    CRIT_TAKEN_MELEE_RATING = { "RESILIENCE_RATING" }, CRIT_TAKEN_RANGED_RATING = { "RESILIENCE_RATING" }, CRIT_TAKEN_SPELL_RATING = { "RESILIENCE_RATING" },
    HIT_TAKEN_RATING = { "RESILIENCE_RATING" }, CRIT_TAKEN_RATING = { "RESILIENCE_RATING" },
    POWER_REGEN0 = { "MANA_REGENERATION" }, HEALTH_REGENERATION = { "HEALTH_REGEN" },
}

local RANGED_LOC = { INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true, INVTYPE_THROWN = true }
local IGNORED = { DAMAGE_MIN = true, DAMAGE_MAX = true, SPEED = true }

-------------------------------------------------------------------------------
-- Profile selection
-------------------------------------------------------------------------------

local function PlayerClass()
    local _, class = UnitClass("player")
    return class
end

-- Returns the talent tab with the most points and the total points spent.
local function DetectSpec()
    local group = GetActiveTalentGroup and GetActiveTalentGroup() or 1
    local best, bestPts, total = nil, 0, 0
    for i = 1, (GetNumTalentTabs and GetNumTalentTabs() or 3) do
        local _, _, pts = GetTalentTabInfo(i, false, false, group)
        pts = pts or 0
        total = total + pts
        if pts > bestPts then best, bestPts = i, pts end
    end
    return best, total
end

-- Returns the active profile and how it was chosen ("manual", "talents" or "default").
function GR.GetActiveProfile()
    local class = PlayerClass()
    local override = GearRaterCharDB.profile
    if override and GR.Profiles[override] and GR.Profiles[override].class == class then
        return GR.Profiles[override], "manual"
    end
    local tab, total = DetectSpec()
    if total > 0 and tab and GR.SpecProfile[class] and GR.SpecProfile[class][tab] then
        return GR.Profiles[GR.SpecProfile[class][tab]], "talents"
    end
    local name = GR.ClassDefault[class]
    return name and GR.Profiles[name] or nil, "default"
end

-- Profiles usable by the player's class, in a stable order.
function GR.ProfilesForClass()
    local class, list = PlayerClass(), {}
    for name, prof in pairs(GR.Profiles) do
        if prof.class == class then list[#list + 1] = name end
    end
    table.sort(list)
    return list
end

-- Effective weights: SavedVariables overrides (GearRaterDB.weights[profile][STAT]) on top of the defaults.
function GR.GetWeights(profile)
    local custom = GearRaterDB and GearRaterDB.weights and GearRaterDB.weights[profile.name]
    if not custom then return profile.weights end
    local w = {}
    for k, v in pairs(profile.weights) do w[k] = v end
    for k, v in pairs(custom) do w[k] = v end
    return w
end

-------------------------------------------------------------------------------
-- Scoring
-------------------------------------------------------------------------------

local function WeightFor(profile, w, key, equipLoc, stats)
    if IGNORED[key] then return 0, key end
    if key == "DPS" then
        return (RANGED_LOC[equipLoc] and (w.DPS_RANGED or 0) or (w.DPS_MELEE or 0)), key
    end
    if key == "WEAPON_DAMAGE" then
        -- flat weapon damage ~ damage / speed extra DPS
        local speed = stats.SPEED and stats.SPEED.total or 2.5
        local dps = RANGED_LOC[equipLoc] and (w.DPS_RANGED or 0) or (w.DPS_MELEE or 0)
        return dps / speed, "DPS"
    end
    local school = key:match("^SPELL_DAMAGE_(%a+)$")
    if school and key ~= "SPELL_DAMAGE_DONE" then
        return (w.SPELL_POWER or 0) * ((profile.schools or {})[school] or 0), key
    end
    if key:match("^RESISTANCE_") then return w.RESISTANCE or 0, key end
    if key:match("^SLAYER_") then return w.SLAYER or 0, key end
    local weight = w[key]
    if weight == nil then
        local a = aliases[key]
        if a and (not a[2] or a[2] == profile.attack) then weight = w[a[1]] end
    end
    return weight or 0, key
end

-- Score a scan result. Returns total, breakdown list { {key, value, weight, contribution} }, profile, how.
function GR.Score(result, link)
    local profile, how = GR.GetActiveProfile()
    if not profile then return nil end
    local w = GR.GetWeights(profile)
    local equipLoc = link and select(9, GetItemInfo(link)) or nil
    local total, parts = 0, {}
    for _, key in ipairs(result.order) do
        local value = result.stats[key].total
        local weight = WeightFor(profile, w, key, equipLoc, result.stats)
        if weight ~= 0 and value ~= 0 then
            local c = value * weight
            total = total + c
            parts[#parts + 1] = { key = key, value = value, weight = weight, contribution = c }
        end
    end
    table.sort(parts, function(a, b) return a.contribution > b.contribution end)
    return total, parts, profile, how, equipLoc
end
