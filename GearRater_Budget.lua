-- GearRater effective item level: how many item levels the item's extra stats are worth.
--
-- Blizzard gives every item a stat budget that grows linearly with item level for a given
-- quality and slot. Stats are combined as ItemValue = (sum (value * statMod) ^ p) ^ (1/p).
-- The budget constants were reverse engineered by the community (Hyzenthlei, Kanath,
-- Thorgred and others on the WoWWiki "Item level" talk page) for TBC and are only
-- approximately right for WotLK, so this module never trusts them in absolute terms.
-- Instead it measures the difference: the item level gain that the enchant stats (anything
-- not part of the base item) would represent for an item of this quality in this slot:
--
--   effective ilvl = ilvl + slope(quality) * slotDivisor(slot) * (ItemValue(all) - ItemValue(base))
--
-- Quality intercepts cancel out, and items whose base stats were rewritten by the server
-- (mod-individual-progression restores vanilla values) are measured against themselves.

GearRater = GearRater or {}
local GR = GearRater

GR.Budget = {
    exponent = 1.7095,     -- log(2)/log(1.5), the fit most analyses settled on; Blizzard's slide said 1.5

    -- item levels per ItemSlotValue point, by quality (GetItemInfo quality index)
    slope = { [0] = 2.3, [1] = 2.2, [2] = 2.0, [3] = 1.8, [4] = 1.6, [5] = 1.5, [7] = 1.6 },

    -- Kanath's slot divisors: a 1H weapon gets 1/2.38 of the budget a chest gets
    slotDivisor = {
        INVTYPE_HEAD = 1.0, INVTYPE_CHEST = 1.0, INVTYPE_ROBE = 1.0, INVTYPE_LEGS = 1.0, INVTYPE_2HWEAPON = 1.0,
        INVTYPE_SHOULDER = 1.29, INVTYPE_HAND = 1.29, INVTYPE_WAIST = 1.29, INVTYPE_FEET = 1.29,
        INVTYPE_TRINKET = 1.43,
        INVTYPE_WRIST = 1.82, INVTYPE_NECK = 1.82, INVTYPE_CLOAK = 1.82, INVTYPE_FINGER = 1.82,
        INVTYPE_HOLDABLE = 1.82, INVTYPE_SHIELD = 1.82, INVTYPE_WEAPONOFFHAND = 1.82,
        INVTYPE_WEAPON = 2.38, INVTYPE_WEAPONMAINHAND = 2.38,
        INVTYPE_RANGED = 3.33, INVTYPE_RANGEDRIGHT = 3.33, INVTYPE_THROWN = 3.33, INVTYPE_RELIC = 3.33,
    },

    -- budget cost per point of stat (primary stats and ratings = 1)
    statMod = {
        STRENGTH = 1, AGILITY = 1, INTELLECT = 1, SPIRIT = 1, STAMINA = 2 / 3,
        ATTACK_POWER = 0.5, RANGED_ATTACK_POWER = 0.4, FERAL_ATTACK_POWER = 0.5,
        SPELL_POWER = 0.857, SPELL_DAMAGE_DONE = 0.857, SPELL_HEALING_DONE = 0.45,
        SPELL_PENETRATION = 0.8, MANA_REGENERATION = 2.0, POWER_REGEN0 = 2.0, HEALTH_REGEN = 2.0,
        HEALTH = 0.15, MANA = 0.15, BLOCK_VALUE = 0.65, ARMOR = 1 / 14,
        ALL_RESISTANCES = 2.5, WEAPON_DAMAGE = 1.0, STEALTH = 0, WEAPON_SKILL = 0,
        FISHING = 0, MINING = 0, HERBALISM = 0, SKINNING = 0,
    },
    schoolDamageMod = 0.7,   -- "+N Fire Spell Damage" style
    resistanceMod   = 1.0,   -- single-school resistance
    slayerMod       = 0.3,
    ratingMod       = 1.0,   -- every *_RATING key not listed above
}

-- Stats that are not part of the stat budget at all (weapon DPS and damage range come from a
-- separate table; sockets and speed are structural).
local EXCLUDED = { DPS = true, DAMAGE_MIN = true, DAMAGE_MAX = true, SPEED = true, SOCKETS = true }
-- Stats whose base portion is not budgeted (base armor and shield block come from the armor
-- table), so only the enchant portion counts.
local ENCH_ONLY = { ARMOR = true, BLOCK_VALUE = true }

local function StatMod(key)
    local B = GR.Budget
    if B.statMod[key] ~= nil then return B.statMod[key] end
    if key:match("^SPELL_DAMAGE_%a+$") then return B.schoolDamageMod end
    if key:match("^RESISTANCE_%a+$") then return B.resistanceMod end
    if key:match("^SLAYER_%a+$") then return B.slayerMod end
    if key:match("_RATING$") then return B.ratingMod end
    return 0
end

-- ItemValue of a scan result. which = "base" or "total".
function GR.ItemValue(result, which)
    local p, sum = GR.Budget.exponent, 0
    for _, key in ipairs(result.order) do
        if not EXCLUDED[key] then
            local s = result.stats[key]
            local value
            if ENCH_ONLY[key] then
                value = which == "base" and 0 or s.ench
            else
                value = which == "base" and s.base or s.total
            end
            local mod = StatMod(key)
            if value > 0 and mod > 0 then
                sum = sum + (value * mod) ^ p
            end
        end
    end
    return sum ^ (1 / p)
end

-- Returns a table { ilvl, effective, delta, base, total, quality, equipLoc } or nil when the
-- item is not equippable or its info is not cached yet.
function GR.EffectiveLevel(result, link)
    if not link then return nil end
    local _, _, quality, ilvl, _, _, _, _, equipLoc = GetItemInfo(link)
    if not ilvl or not equipLoc or equipLoc == "" then return nil end
    local B = GR.Budget
    local slope = B.slope[quality or 1] or 2.0
    local div = B.slotDivisor[equipLoc] or 1.0
    local base, total = GR.ItemValue(result, "base"), GR.ItemValue(result, "total")
    local delta = slope * div * (total - base)
    return { ilvl = ilvl, effective = ilvl + delta, delta = delta, base = base, total = total,
             quality = quality, equipLoc = equipLoc }
end
