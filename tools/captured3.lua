print("\n== Captured: Pellet Rifle (+6 Elemental Slayer)")
TEST.SetLines(GameTooltip, {
    {"Pellet Rifle"}, {"Ranged", "white", "Gun"}, {"4 - 9 Damage", "white", "Speed 2.60"}, {"(2.5 damage per second)"},
    {"+4 Intellect", "green"}, {"+8 Attack Power", "green"}, {"+4 All Resistances", "green"},
    {"|cffffffff+4 Damage|r", "gold"}, {"|cffffffff+6 Elemental Slayer|r", "gold"},
    {"Durability 30 / 30"}, {"Requires Level 2"}, {"Item Level 7"},
}, "|cffffffff|Hitem:8182:94:0:0:0:0:0:0:11|h[Pellet Rifle]|h|r")
GameTooltip.hook(GameTooltip); TEST.Pump()
local r = GearRater.ScanTooltip(GameTooltip)
assert(r.stats.SLAYER_ELEMENTAL and r.stats.SLAYER_ELEMENTAL.total == 6, "elemental slayer")
assert(r.stats.WEAPON_DAMAGE.total == 4 and r.stats.DPS.total == 2.5, "rest")
assert(#r.unparsed == 0, "nothing unparsed")
print("\nCAPTURED3 CASES PASSED")
