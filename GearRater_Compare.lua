-- GearRater comparison: score the item(s) currently equipped in the hovered item's slot and
-- report the difference. Equipped items are read through a hidden tooltip so their random
-- enchants are seen exactly as the client shows them.

GearRater = GearRater or {}
local GR = GearRater

-- equip location -> inventory slot ids. pair = the item occupies both slots (two-hander).
local SLOTS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_BODY = { 4 },
    INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 },
    INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 },
    INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 },
    INVTYPE_WEAPON = { 16, 17 }, INVTYPE_WEAPONMAINHAND = { 16 },
    INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_HOLDABLE = { 17 }, INVTYPE_SHIELD = { 17 },
    INVTYPE_2HWEAPON = { 16, 17, pair = true },
    INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 },
    INVTYPE_TABARD = { 19 },
}
local WEAPON_LOC = { INVTYPE_WEAPON = true, INVTYPE_WEAPONMAINHAND = true, INVTYPE_WEAPONOFFHAND = true, INVTYPE_2HWEAPON = true }

local scanTip
function GR.ScanTip()
    if not scanTip then
        scanTip = CreateFrame("GameTooltip", "GearRaterScanTip", UIParent, "GameTooltipTemplate")
        scanTip:SetOwner(UIParent, "ANCHOR_NONE")
    end
    return scanTip
end
local ScanTip = GR.ScanTip

-- Cache of equipped scores, keyed by slot. Cleared whenever gear, talents or weights change.
local cache, cacheVersion = {}, 0
function GR.InvalidateEquipped()
    cache = {}
    cacheVersion = cacheVersion + 1
end

-- Returns { score, name, link, equipLoc } for an inventory slot, or { empty = true }.
function GR.EquippedScore(slot)
    local link = GetInventoryItemLink("player", slot)
    if not link then return { empty = true, slot = slot } end
    local hit = cache[slot]
    if hit and hit.link == link then return hit end

    local tip = ScanTip()
    tip:SetOwner(UIParent, "ANCHOR_NONE")
    tip:ClearLines()
    tip:SetInventoryItem("player", slot)
    local result = GR.ScanTooltip(tip)
    local total = GR.Score(result, link)
    local name = GetItemInfo(link)
    local equipLoc = select(9, GetItemInfo(link))
    hit = { score = total or 0, name = name or "?", link = link, equipLoc = equipLoc, slot = slot }
    cache[slot] = hit
    return hit
end

-- Compare a scored item against what is equipped for its slot.
-- Returns nil when nothing sensible can be compared, else:
--   { delta, pct, equippedScore, against (text), empty (bool), isEquipped (bool), slots = {..} }
function GR.Compare(result, link, score)
    if not link or not score then return nil end
    local equipLoc = select(9, GetItemInfo(link))
    local slots = equipLoc and SLOTS[equipLoc]
    if not slots then return nil end

    local candidates = {}
    for _, slot in ipairs(slots) do candidates[#candidates + 1] = GR.EquippedScore(slot) end

    -- A one-hander only competes with the off hand when a weapon is actually held there.
    if equipLoc == "INVTYPE_WEAPON" and candidates[2] and (candidates[2].empty or not WEAPON_LOC[candidates[2].equipLoc]) then
        candidates[2] = nil
    end

    -- Hovering an item that is itself equipped: compare against the other slot, if any.
    local isEquipped = false
    local remaining = {}
    for _, c in ipairs(candidates) do
        if not c.empty and c.link == link and not isEquipped then isEquipped = true
        else remaining[#remaining + 1] = c end
    end
    if isEquipped and (#remaining == 0 or slots.pair) then
        return { isEquipped = true, delta = 0, pct = 0, equippedScore = score, against = "equipped" }
    end
    candidates = remaining

    local equippedScore, against, empty
    if slots.pair then
        -- two-hander replaces main hand and off hand together
        equippedScore, empty = 0, true
        local names = {}
        for _, c in ipairs(candidates) do
            if not c.empty then
                equippedScore = equippedScore + c.score
                names[#names + 1] = c.name
                empty = false
            end
        end
        against = #names > 0 and table.concat(names, " + ") or "empty slot"
    else
        -- replace the weakest candidate (an empty slot is weakest of all)
        local weakest
        for _, c in ipairs(candidates) do
            local s = c.empty and -1 or c.score
            if not weakest or s < (weakest.empty and -1 or weakest.score) then weakest = c end
        end
        if not weakest then return nil end
        equippedScore = weakest.empty and 0 or weakest.score
        against = weakest.empty and "empty slot" or weakest.name
        empty = weakest.empty or false
    end

    local delta = score - equippedScore
    local pct = equippedScore > 0 and (delta / equippedScore * 100) or nil
    return { delta = delta, pct = pct, equippedScore = equippedScore, against = against, empty = empty,
             isEquipped = false, slots = slots }
end

-- Invalidate on anything that changes the equipped baseline.
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
f:RegisterEvent("UNIT_INVENTORY_CHANGED")
f:RegisterEvent("PLAYER_TALENT_UPDATE")
f:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(_, event, unit)
    if event == "UNIT_INVENTORY_CHANGED" and unit ~= "player" then return end
    GR.InvalidateEquipped()
end)
