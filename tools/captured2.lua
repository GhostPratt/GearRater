print("\n== Captured: Terrorcloth Mantle (grey sockets, green base Equip line)")
TEST.SetLines(GameTooltip, {
    {"Terrorcloth Mantle", "green"}, {"Soulbound"}, {"Shoulder", "white", "Cloth"}, {"92 Armor"},
    {"+22 Stamina"}, {"+9 Intellect"}, {"+15 Spirit"},
    {"Red Socket", "grey"}, {"Yellow Socket", "grey"}, {"Socket Bonus: +3 Critical Strike Rating", "grey"},
    {"Durability 45 / 45"}, {"Item Level 99"},
    {"Equip: Increases spell power by 11.", "green"}, {"<Shift Right Click to Socket>", "green"},
}, "|cff1eff00|Hitem:25925:0:0:0:0:0:0:0:11|h[Terrorcloth Mantle]|h|r")
GameTooltip.hook(GameTooltip); TEST.Pump()
local r = GearRater.ScanTooltip(GameTooltip)
assert(r.stats.SOCKETS and r.stats.SOCKETS.total == 2, "grey sockets counted")
assert(r.stats.SPELL_POWER and r.stats.SPELL_POWER.total == 11 and r.stats.SPELL_POWER.base == 11, "Equip: spell power is base")
assert(r.stats.CRIT_RATING == nil, "inactive socket bonus skipped")
assert(#r.unparsed == 0, "nothing unparsed, got " .. #r.unparsed)

print("\n== Captured: Seasoned Fighter's Cloak (+4 Damage, +16 Armor enchant)")
TEST.SetLines(GameTooltip, {
    {"Seasoned Fighter's Cloak"}, {"Soulbound"}, {"Back"}, {"8 Armor"},
    {"+8 Attack Power", "green"}, {"+4 All Resistances", "green"}, {"+16 Armor", "green"},
    {"|cffffffff+4 Damage|r", "gold"}, {"|cffffffff+4 Agility|r", "gold"}, {"Item Level 9"},
}, "|cffffffff|Hitem:4933:1585:0:0:0:0:0:0:11|h[Seasoned Fighter's Cloak]|h|r")
GameTooltip.hook(GameTooltip); TEST.Pump()
r = GearRater.ScanTooltip(GameTooltip)
assert(r.stats.ARMOR.total == 24 and r.stats.ARMOR.base == 8 and r.stats.ARMOR.ench == 16, "armor base+ench")
assert(r.stats.WEAPON_DAMAGE and r.stats.WEAPON_DAMAGE.total == 4, "+4 Damage")
assert(r.stats.ALL_RESISTANCES.total == 1 and r.stats.AGILITY.total == 4 and r.stats.ATTACK_POWER.total == 8, "rest")  -- enchant 28 grants +1 (see captured.lua)
assert(#r.unparsed == 0, "nothing unparsed")

print("\n== Captured: Grom'tor's Charge (real DAMAGE_TEMPLATE, green Equip defense)")
TEST.SetLines(GameTooltip, {
    {"Grom'tor's Charge", "odd"}, {"Soulbound"}, {"One-Hand", "white", "Axe"},
    {"75 - 140 Damage", "white", "Speed 1.60"}, {"(67.2 damage per second)"},
    {"+7 Agility"}, {"+30 Stamina"}, {"Durability 90 / 90"}, {"Item Level 109"},
    {"Equip: Increases defense rating by 11.", "green"},
    {"\"We spill blood for just cause...\" -Oronok Torn-heart", "gold"},
}, "|cff0070dd|Hitem:31071:0:0:0:0:0:0:0:11|h[Grom'tor's Charge]|h|r")
GameTooltip.hook(GameTooltip); TEST.Pump()
r = GearRater.ScanTooltip(GameTooltip)
assert(r.stats.DAMAGE_MIN.total == 75 and r.stats.DAMAGE_MAX.total == 140 and r.stats.SPEED.total == 1.6, "damage/speed")
assert(math.abs(r.stats.DPS.total - 67.2) < 0.01, "dps")
assert(r.stats.DEFENSE_SKILL_RATING.total == 11 and r.stats.DEFENSE_SKILL_RATING.base == 11, "defense base")
assert(#r.unparsed == 0, "nothing unparsed")

print("\n== Captured: Battleworn Chain Leggings (+10 Arcane Spell Damage)")
TEST.SetLines(GameTooltip, {
    {"Battleworn Chain Leggings"}, {"Soulbound"}, {"Legs", "white", "Mail"}, {"58 Armor"},
    {"+10 Arcane Spell Damage", "green"}, {"+5 Stamina", "green"}, {"+14 Spell Power", "green"},
    {"|cffffffff+6 Strength|r", "gold"}, {"Durability 40 / 40"}, {"Item Level 5"},
}, "|cffffffff|Hitem:4917:2085:0:0:0:0:0:0:11|h[Battleworn Chain Leggings]|h|r")
GameTooltip.hook(GameTooltip); TEST.Pump()
r = GearRater.ScanTooltip(GameTooltip)
assert(r.stats.SPELL_DAMAGE_ARCANE and r.stats.SPELL_DAMAGE_ARCANE.total == 10, "arcane spell damage")
assert(r.stats.SPELL_POWER.total == 14 and r.stats.STRENGTH.total == 6, "rest")
assert(#r.unparsed == 0, "nothing unparsed")

print("\nCAPTURED2 CASES PASSED")
