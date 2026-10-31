-- Step 2: profile selection and scoring.
local function near(a, b, eps) return math.abs(a - b) <= (eps or 0.05) end
local function strip(s) return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

print("\n== Scoring: Warrior with Arms talents, Anvilmar Sledge (2H)")
TEST.class, TEST.talents = "WARRIOR", { 51, 0, 20 }
TEST.equipLoc["|cffffffff|Hitem:5761:249:0:0:0:0:0:0:3|h[Anvilmar Sledge]|h|r"] = "INVTYPE_2HWEAPON"
TEST.SetLines(GameTooltip, {
    {"Anvilmar Sledge", "white"}, {"Soulbound"}, {"Two-Hand", "white", "Mace"},
    {"6 - 10 Damage", "white", "Speed 3.10"}, {"(2.6 damage per second)"},
    {"+2 Beastslaying", "green"}, {"+20 Armor", "green"}, {"+4 Spell Power", "green"},
    {"|cffffffff+10 Ranged Attack Power|r", "odd"}, {"|cffffffff+5 Intellect|r", "odd"},
    {"Durability 35 / 35"}, {"Item Level 5"},
}, "|cffffffff|Hitem:5761:249:0:0:0:0:0:0:3|h[Anvilmar Sledge]|h|r")
GameTooltip.hook(GameTooltip); TEST.Pump()
local profile, how = GearRater.GetActiveProfile()
assert(profile.name == "Warrior: Arms" and how == "talents", "arms via talents, got " .. profile.name .. "/" .. how)
local r = GearRater.ScanTooltip(GameTooltip)
local total, parts = GearRater.Score(r, "|cffffffff|Hitem:5761:249:0:0:0:0:0:0:3|h[Anvilmar Sledge]|h|r")
-- 2.6 dps*4.6 + 20 armor*0.02 + 10 rap*0.02 + 2 beast slaying*0.1; spell power and intellect are zero for a warrior
print(string.format("  total %.2f (expect 12.76)", total))
assert(near(total, 12.76), "arms score")
assert(#parts == 4 and parts[1].key == "DPS", "dps, armor, rap, slayer count; sp/int do not")
local scoreLine
for _, a in ipairs(GameTooltip.added) do if a:find("Score:") then scoreLine = strip(a) end end
print("  tooltip: " .. tostring(scoreLine))
assert(scoreLine and scoreLine:find("12.8") and scoreLine:find("Warrior: Arms"), "score line on tooltip")

print("\n== Scoring: manual override must match class")
GearRaterCharDB.profile = "Druid: Feral (Bear)"
profile, how = GearRater.GetActiveProfile()
assert(profile.name == "Warrior: Arms" and how == "talents", "foreign-class override ignored")
GearRaterCharDB.profile = "Warrior: Protection"
profile, how = GearRater.GetActiveProfile()
assert(profile.name == "Warrior: Protection" and how == "manual", "same-class override honoured")
GearRaterCharDB.profile = nil

print("\n== Scoring: Hunter with no talents -> class default, Pellet Rifle (ranged)")
TEST.class, TEST.talents = "HUNTER", { 0, 0, 0 }
local link = "|cffffffff|Hitem:8182:94:0:0:0:0:0:0:11|h[Pellet Rifle]|h|r"
TEST.equipLoc[link] = "INVTYPE_RANGEDRIGHT"
TEST.SetLines(GameTooltip, {
    {"Pellet Rifle"}, {"Ranged", "white", "Gun"}, {"4 - 9 Damage", "white", "Speed 2.60"}, {"(2.5 damage per second)"},
    {"+4 Intellect", "green"}, {"+8 Attack Power", "green"}, {"+4 All Resistances", "green"},
    {"|cffffffff+4 Damage|r", "gold"}, {"|cffffffff+6 Elemental Slayer|r", "gold"},
    {"Durability 30 / 30"}, {"Requires Level 2"}, {"Item Level 7"},
}, link)
GameTooltip.hook(GameTooltip); TEST.Pump()
profile, how = GearRater.GetActiveProfile()
assert(profile.name == "Hunter: Beast Mastery" and how == "default", "BM default, got " .. profile.name .. "/" .. how)
r = GearRater.ScanTooltip(GameTooltip)
total, parts = GearRater.Score(r, link)
-- 2.5 dps*5 + 4 int*0.9 + 8 ap*1 + 1 allres*0.1 (enchant 28 really grants +1) + 4 flat dmg/2.6 speed*5 + 6 elemental slayer*0.1
-- = 12.5+3.6+8+0.1+7.692+0.6
print(string.format("  total %.2f (expect 32.49)", total))
assert(near(total, 32.49), "bm score")

print("\n== Scoring: melee weapon DPS ignored for hunter; ranged DPS ignored for warrior")
TEST.equipLoc["sword"] = "INVTYPE_WEAPON"
TEST.SetLines(GameTooltip, { {"Sword"}, {"One-Hand", "white", "Sword"}, {"10 - 20 Damage", "white", "Speed 2.00"},
    {"(7.5 damage per second)"}, {"+5 Agility"} }, "sword")
r = GearRater.ScanTooltip(GameTooltip)
total = GearRater.Score(r, "sword")
assert(near(total, 5 * 2.2 + 7.5 * 0.05), "hunter: agility plus a token melee dps weight, got " .. total)
TEST.class, TEST.talents = "WARRIOR", { 51, 0, 20 }
total = GearRater.Score(r, "sword")
assert(near(total, 7.5 * 4.6 + 5 * 0.7), "warrior arms: dps + agility, got " .. total)

print("\n== Scoring: custom weight override")
GearRaterDB.weights = { ["Warrior: Arms"] = { AGILITY = 0 } }
total = GearRater.Score(r, "sword")
assert(near(total, 7.5 * 4.6), "custom agility weight 0 applied, got " .. total)
GearRaterDB.weights = nil

print("\n== Scoring: caster school damage and rating aliases")
TEST.class, TEST.talents = "MAGE", { 0, 60, 11 }
TEST.SetLines(GameTooltip, { {"Wand"}, {"Ranged", "white", "Wand"}, {"+10 Fire Spell Damage", "green"},
    {"+10 Frost Spell Damage", "green"}, {"Equip: Improves spell hit rating by 10.", "green"},
    {"Equip: Improves melee hit rating by 10.", "green"} }, "wand")
TEST.equipLoc["wand"] = "INVTYPE_RANGEDRIGHT"
r = GearRater.ScanTooltip(GameTooltip)
total = GearRater.Score(r, "wand")
-- fire mage: fire 10*1*1 + frost 10*1*0.1 + spell hit 10*1.4 + melee hit 0
print(string.format("  total %.2f (expect 25.0)", total))
assert(near(total, 25.0), "fire mage score")

print("\nSCORING PASSED")

print("\n== Hunter: spell power and school damage do nothing on this server")
TEST.class, TEST.talents = "HUNTER", { 0, 0, 51 }
TEST.SetLines(GameTooltip, { {"Quiver"}, {"Trinket"}, {"+10 Spell Power", "green"}, {"+10 Nature Spell Damage", "green"},
    {"+10 Arcane Spell Damage", "green"}, {"+10 Frost Spell Damage", "green"} }, "trinket")
TEST.equipLoc["trinket"] = "INVTYPE_TRINKET"
local hr = GearRater.ScanTooltip(GameTooltip)
local ht, hp = GearRater.Score(hr, "trinket")
assert(ht == 0 and #hp == 0, "hunter: all spell power zero, got " .. ht)
print("HUNTER SPELL POWER PASSED")
