-- Step 4: comparison against equipped items.
local function near(a, b, eps) return math.abs(a - b) <= (eps or 0.05) end
local function strip(s) return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function hover(lines, link)
    TEST.SetLines(GameTooltip, lines, link)
    GameTooltip.hook(GameTooltip)
    local r = GearRater.ScanTooltip(GameTooltip)
    local total = GearRater.Score(r, link)
    return GearRater.Compare(r, link, total), total
end
local function tipline(pat)
    for _, a in ipairs(GameTooltip.added) do if a:find(pat) then return strip(a) end end
end

TEST.class, TEST.talents = "WARRIOR", { 51, 0, 20 }   -- Arms
GearRater.InvalidateEquipped()

print("\n== Compare: empty head slot")
TEST.equipLoc["helm"] = "INVTYPE_HEAD"
local cmp, total = hover({ {"Helm"}, {"Head", "white", "Plate"}, {"+10 Strength"} }, "helm")
assert(cmp and cmp.empty and cmp.against == "empty slot" and near(cmp.delta, total) and cmp.pct == nil, "empty slot compare")
print("  tooltip: " .. tostring(tipline("Equipped")))
assert(tipline("Equipped"):find("vs empty slot"), "empty slot wording")

print("\n== Compare: rings, replace the weaker one")
TEST.equipLoc["ringA"], TEST.equipLoc["ringB"], TEST.equipLoc["ringC"] = "INVTYPE_FINGER", "INVTYPE_FINGER", "INVTYPE_FINGER"
TEST.equipped[11] = { link = "ringA", lines = { {"Ring A"}, {"Finger"}, {"+20 Strength"} } }        -- 46.0
TEST.equipped[12] = { link = "ringB", lines = { {"Ring B"}, {"Finger"}, {"+10 Strength"} } }        -- 23.0
GearRater.InvalidateEquipped()
cmp, total = hover({ {"Ring C"}, {"Finger"}, {"+15 Strength"} }, "ringC")                              -- 34.5
print(string.format("  C %.1f vs weaker equipped %.1f -> delta %.1f (%.0f%%) vs %s", total, cmp.equippedScore, cmp.delta, cmp.pct, cmp.against))
assert(near(cmp.equippedScore, 23.0) and near(cmp.delta, 11.5) and near(cmp.pct, 50) and cmp.against == "name", "weaker ring chosen")
-- hovering ring A itself compares against ring B, not "equipped"
cmp = hover({ {"Ring A"}, {"Finger"}, {"+20 Strength"} }, "ringA")
assert(cmp and not cmp.isEquipped and near(cmp.equippedScore, 23.0) and near(cmp.delta, 23.0), "equipped ring compares to the other ring")

print("\n== Compare: single slot item that is itself equipped")
TEST.equipLoc["chest"] = "INVTYPE_CHEST"
TEST.equipped[5] = { link = "chest", lines = { {"Chest"}, {"Chest", "white", "Plate"}, {"+30 Strength"} } }
GearRater.InvalidateEquipped()
cmp = hover({ {"Chest"}, {"Chest", "white", "Plate"}, {"+30 Strength"} }, "chest")
assert(cmp and cmp.isEquipped, "equipped chest")
assert(tipline("Equipped"):find("equipped"), "equipped wording")

print("\n== Compare: two-hander vs main hand + off hand")
TEST.equipLoc["mh"], TEST.equipLoc["oh"], TEST.equipLoc["twoh"] = "INVTYPE_WEAPONMAINHAND", "INVTYPE_WEAPONOFFHAND", "INVTYPE_2HWEAPON"
TEST.equipped[16] = { link = "mh", lines = { {"Main"}, {"Main Hand", "white", "Sword"}, {"10 - 20 Damage", "white", "Speed 2.00"}, {"(7.5 damage per second)"} } }  -- 34.5
TEST.equipped[17] = { link = "oh", lines = { {"Off"}, {"Off Hand", "white", "Sword"}, {"6 - 10 Damage", "white", "Speed 1.60"}, {"(5.0 damage per second)"} } }      -- 23.0
GearRater.InvalidateEquipped()
cmp, total = hover({ {"Big"}, {"Two-Hand", "white", "Mace"}, {"30 - 50 Damage", "white", "Speed 3.60"}, {"(11.1 damage per second)"} }, "twoh")  -- 51.06
print(string.format("  2H %.1f vs MH+OH %.1f -> delta %.1f vs %s", total, cmp.equippedScore, cmp.delta, cmp.against))
assert(near(cmp.equippedScore, 57.5) and near(cmp.delta, total - 57.5) and cmp.against == "name + name", "pair compare")

print("\n== Compare: one-hander ignores a shield in the off hand")
TEST.equipLoc["shield"], TEST.equipLoc["sword1h"] = "INVTYPE_SHIELD", "INVTYPE_WEAPON"
TEST.equipped[17] = { link = "shield", lines = { {"Shield"}, {"Off Hand", "white", "Shield"}, {"500 Armor"}, {"+5 Stamina"} } }
GearRater.InvalidateEquipped()
cmp, total = hover({ {"Sword"}, {"One-Hand", "white", "Sword"}, {"8 - 16 Damage", "white", "Speed 2.40"}, {"(5.0 damage per second)"} }, "sword1h")
assert(near(cmp.equippedScore, 34.5), "compared to main hand only, got " .. cmp.equippedScore)

print("\n== Compare: cache invalidates when equipment changes")
TEST.equipped[5] = { link = "chest2", lines = { {"Chest 2"}, {"Chest", "white", "Plate"}, {"+5 Strength"} } }
TEST.equipLoc["chest2"] = "INVTYPE_CHEST"
GearRater.InvalidateEquipped()
cmp = hover({ {"Chest"}, {"Chest", "white", "Plate"}, {"+30 Strength"} }, "chest")
assert(cmp and not cmp.isEquipped and near(cmp.equippedScore, 11.5), "new equipped chest scored, got " .. tostring(cmp.equippedScore))

print("\nCOMPARE PASSED")
