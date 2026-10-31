-- Character sheet summary.
local function near(a, b, eps) return math.abs(a - b) <= (eps or 0.05) end
TEST.class, TEST.talents = "WARRIOR", { 51, 0, 20 }
TEST.talentList = {}; TEST.ratingBonus = {}; TEST.expertise = 0; TEST.defense = { 0, 0 }
GearRater.InvalidateTalents()
for slot = 1, 19 do TEST.equipped[slot] = nil end

print("\n== Character: three equipped items, rest empty")
TEST.equipLoc["c_head"], TEST.equipLoc["c_chest"], TEST.equipLoc["c_2h"] = "INVTYPE_HEAD", "INVTYPE_CHEST", "INVTYPE_2HWEAPON"
TEST.itemInfo["c_head"], TEST.itemInfo["c_chest"], TEST.itemInfo["c_2h"] = { 2, 20 }, { 3, 30 }, { 2, 25 }
TEST.equipped[1] = { link = "c_head", lines = { {"Helm"}, {"Head", "white", "Plate"}, {"+10 Strength"}, {"+5 Strength", "green"} } }
TEST.equipped[5] = { link = "c_chest", lines = { {"Chest"}, {"Chest", "white", "Plate"}, {"+20 Strength"} } }
TEST.equipped[16] = { link = "c_2h", lines = { {"Big"}, {"Two-Hand", "white", "Mace"}, {"10 - 20 Damage", "white", "Speed 2.00"}, {"(7.5 damage per second)"} } }
GearRater.InvalidateEquipped()
local s = GearRater.CharacterSummary()
-- helm 15*2.3 = 34.5, chest 46, 2H 7.5*4.6 = 34.5
print(string.format("  total %.1f (expect 115.0), %d items, avg ilvl %.1f, avg eff %.1f", s.total, s.count, s.avgIlvl, s.avgEff))
assert(near(s.total, 115.0), "total")
assert(s.count == 3 and near(s.avgIlvl, 25), "three items averaging ilvl 25")
assert(s.avgEff > s.avgIlvl, "helm enchant lifts the effective average")
assert(#s.slots == 17, "17 slot rows")
local filled = 0
for _, row in ipairs(s.slots) do if row.item then filled = filled + 1 end end
assert(filled == 3, "three rows filled")
assert(s.slots[1].name == HEADSLOT and s.slots[1].item == "name" and near(s.slots[1].score, 34.5), "head row")

print("\n== Character: cache follows gear changes")
TEST.equipped[1] = nil
GearRater.InvalidateEquipped()
s = GearRater.CharacterSummary()
assert(near(s.total, 80.5) and s.count == 2, "helm removed")

print("\nCHARACTER PASSED")
