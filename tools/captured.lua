print("\n== Captured: Anvilmar Sledge (5 module enchants, 2 with inline colour codes)")
TEST.SetLines(GameTooltip, {
    {"Anvilmar Sledge", "white"}, {"Soulbound"}, {"Two-Hand", "white", "Mace"},
    {"6 - 10 Damage", "white", "Speed 3.10"}, {"(2.6 damage per second)"},
    {"+2 Beastslaying", "green"}, {"+20 Armor", "green"}, {"+4 Spell Power", "green"},
    {"|cffffffff+10 Ranged Attack Power|r", "odd"}, {"|cffffffff+5 Intellect|r", "odd"},
    {"Durability 35 / 35"}, {"Item Level 5"}, {" "},
}, "|cffffffff|Hitem:5761:249:0:0:0:0:0:0:3|h[Anvilmar Sledge]|h|r")
GameTooltip.hook(GameTooltip)
TEST.Pump()
local r = GearRater.ScanTooltip(GameTooltip)
assert(r.stats.ARMOR and r.stats.ARMOR.total == 20 and r.stats.ARMOR.ench == 20, "+20 Armor")
assert(r.stats.SPELL_POWER.total == 4, "sp")
assert(r.stats.RANGED_ATTACK_POWER and r.stats.RANGED_ATTACK_POWER.total == 10, "inline-coloured RAP")
assert(r.stats.INTELLECT and r.stats.INTELLECT.total == 5 and r.stats.INTELLECT.ench == 5, "inline-coloured Int")
assert(r.stats.DPS.total == 2.6 and r.stats.SPEED.total == 3.1, "weapon")
assert(r.stats.SLAYER_BEAST and r.stats.SLAYER_BEAST.total == 2 and #r.unparsed == 0, "beastslaying parsed")

print("\n== Captured: Boar Handler Gloves")
TEST.SetLines(GameTooltip, {
    {"Boar Handler Gloves", "white"}, {"Soulbound"}, {"Hands", "white", "Mail"}, {"42 Armor"},
    {"+5 Spirit", "green"}, {"+5 Agility", "green"}, {"+14 Ranged Attack Power", "green"},
    {"|cffffffff+4 All Resistances|r", "odd"}, {"|cffffffff+5 Mana|r", "odd"},
    {"Durability 18 / 18"}, {"Item Level 5"}, {" "},
}, "|cffffffff|Hitem:2547:99:0:0:0:0:0:0:3|h[Boar Handler Gloves]|h|r")
GameTooltip.hook(GameTooltip)
TEST.Pump()
r = GearRater.ScanTooltip(GameTooltip)
assert(r.stats.ARMOR.total == 42 and r.stats.ARMOR.ench == 0, "base armor")
-- text says +4, but enchant 28 casts spell 7438 "Minor Resistance" which grants +1; DBC effect wins
assert(r.stats.ALL_RESISTANCES and r.stats.ALL_RESISTANCES.total == 1, "all res")
assert(r.stats.MANA and r.stats.MANA.total == 5, "mana")
assert(#r.order == 6, "6 stats, got " .. #r.order)
assert(#r.unparsed == 0, "nothing unparsed")
print("\nCAPTURED CASES PASSED")
