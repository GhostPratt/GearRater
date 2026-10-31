-- Step 3: effective item level from the stat budget difference.
local function near(a, b, eps) return math.abs(a - b) <= (eps or 0.05) end
local function strip(s) return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local B = GearRater.Budget

print("\n== Budget: Anvilmar Sledge, white ilvl 5 two-hander with 5 module enchants")
local link = "|cffffffff|Hitem:5761:249:0:0:0:0:0:0:3|h[Anvilmar Sledge]|h|r"
TEST.equipLoc[link] = "INVTYPE_2HWEAPON"
TEST.itemInfo[link] = { 1, 5 }
TEST.SetLines(GameTooltip, {
    {"Anvilmar Sledge", "white"}, {"Soulbound"}, {"Two-Hand", "white", "Mace"},
    {"6 - 10 Damage", "white", "Speed 3.10"}, {"(2.6 damage per second)"},
    {"+2 Beastslaying", "green"}, {"+20 Armor", "green"}, {"+4 Spell Power", "green"},
    {"|cffffffff+10 Ranged Attack Power|r", "odd"}, {"|cffffffff+5 Intellect|r", "odd"},
    {"Durability 35 / 35"}, {"Item Level 5"},
}, link)
GameTooltip.hook(GameTooltip); TEST.Pump()
local r = GearRater.ScanTooltip(GameTooltip)
local lvl = GearRater.EffectiveLevel(r, link)
assert(lvl, "level computed")
-- base has no budgeted stats; total = ((20/14)^p + (4*0.857)^p + (10*0.4)^p + 5^p + (2*0.3)^p)^(1/p)
local p = B.exponent
local expect = ((20 / 14) ^ p + (4 * 0.857) ^ p + (10 * 0.4) ^ p + 5 ^ p + (2 * 0.3) ^ p) ^ (1 / p)
print(string.format("  base %.2f total %.2f (expect %.2f)  delta %.1f  effective %.1f", lvl.base, lvl.total, expect, lvl.delta, lvl.effective))
assert(near(lvl.base, 0) and near(lvl.total, expect, 0.01), "item values")
assert(near(lvl.delta, 2.2 * 1.0 * expect, 0.01), "white 2H: slope 2.2, divisor 1")
local tipLine
for _, a in ipairs(GameTooltip.added) do if a:find("Item Level") then tipLine = strip(a) end end
print("  tooltip: " .. tostring(tipLine))
assert(tipLine and tipLine:find("base 5") and tipLine:find("from enchants"), "item level line on tooltip")

print("\n== Budget: Terrorcloth Mantle, green ilvl 99 shoulders, no enchants -> no change")
link = "|cff1eff00|Hitem:25925:0:0:0:0:0:0:0:11|h[Terrorcloth Mantle]|h|r"
TEST.equipLoc[link] = "INVTYPE_SHOULDER"
TEST.itemInfo[link] = { 2, 99 }
TEST.SetLines(GameTooltip, {
    {"Terrorcloth Mantle", "green"}, {"Soulbound"}, {"Shoulder", "white", "Cloth"}, {"92 Armor"},
    {"+22 Stamina"}, {"+9 Intellect"}, {"+15 Spirit"}, {"Red Socket", "grey"}, {"Yellow Socket", "grey"},
    {"Socket Bonus: +3 Critical Strike Rating", "grey"}, {"Durability 45 / 45"}, {"Item Level 99"},
    {"Equip: Increases spell power by 11.", "green"},
}, link)
GameTooltip.hook(GameTooltip); TEST.Pump()
r = GearRater.ScanTooltip(GameTooltip)
lvl = GearRater.EffectiveLevel(r, link)
print(string.format("  base %.2f total %.2f delta %.2f", lvl.base, lvl.total, lvl.delta))
assert(lvl.base > 0 and near(lvl.delta, 0), "all stats are base; base armor excluded")
tipLine = nil
for _, a in ipairs(GameTooltip.added) do if a:find("Item Level") then tipLine = strip(a) end end
assert(tipLine and tipLine:find("no enchant value"), "no-change wording")

print("\n== Budget: same shoulders with a +10 Intellect enchant -> delta scales by 2.0 * 1.29")
TEST.SetLines(GameTooltip, {
    {"Terrorcloth Mantle", "green"}, {"Shoulder", "white", "Cloth"}, {"92 Armor"},
    {"+22 Stamina"}, {"+9 Intellect"}, {"+15 Spirit"}, {"Item Level 99"},
    {"Equip: Increases spell power by 11.", "green"}, {"+10 Intellect", "green"},
}, link)
r = GearRater.ScanTooltip(GameTooltip)
lvl = GearRater.EffectiveLevel(r, link)
local base = ((22 * 2 / 3) ^ p + 9 ^ p + 15 ^ p + (11 * 0.857) ^ p) ^ (1 / p)
local total = ((22 * 2 / 3) ^ p + 19 ^ p + 15 ^ p + (11 * 0.857) ^ p) ^ (1 / p)
print(string.format("  base %.2f (expect %.2f) total %.2f (expect %.2f) delta %.2f", lvl.base, base, lvl.total, total, lvl.delta))
assert(near(lvl.base, base, 0.01) and near(lvl.total, total, 0.01), "item values with enchant")
assert(near(lvl.delta, 2.0 * 1.29 * (total - base), 0.01), "green shoulder scaling")

print("\n== Budget: non-equippable item has no level line")
TEST.equipLoc["bread"] = ""
TEST.SetLines(GameTooltip, { {"Tough Hunk of Bread"}, {"Use: Restores 61 health over 18 sec.", "green"} }, "bread")
r = GearRater.ScanTooltip(GameTooltip)
assert(GearRater.EffectiveLevel(r, "bread") == nil, "no level for consumables")

print("\nBUDGET PASSED")
