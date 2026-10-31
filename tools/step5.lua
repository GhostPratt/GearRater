-- Step 5: Pawn import/export and bag scoring.
local function near(a, b, eps) return math.abs(a - b) <= (eps or 0.01) end

print("\n== Pawn: parse")
local name, values = GearRater.ParsePawnScale('( Pawn: v1: "EJ Arms 3.3": Strength=2.3, Agility=0.7, Ap=1, HitRating=1.9, CritRating=1.4, ExpertiseRating=1.8, ArmorPenetration=1.5, HasteRating=0.7, TwoHandDps=4.6, OneHandDps=3.1, RedSocket=40, YellowSocket=34, FireResist=0.02, FrostResist=0.04, Stamina=0.1 )')
assert(name == "EJ Arms 3.3" and values.strength == 2.3 and values.twohanddps == 4.6, "parsed")
local bad, err = GearRater.ParsePawnScale("hello")
assert(bad == nil and err:find("not a Pawn"), "reject junk: " .. tostring(err))
bad, err = GearRater.ParsePawnScale('( Pawn: v1: "x": Strength=abc )')
assert(bad == nil and err:find("cannot read"), "reject bad pair: " .. tostring(err))

print("\n== Pawn: profile mapping")
local prof, unknown = GearRater.ProfileFromPawn(name, values, "WARRIOR")
assert(prof.name == "Import: EJ Arms 3.3" and prof.class == "WARRIOR" and prof.attack == "melee", "profile basics")
assert(prof.weights.STRENGTH == 2.3 and prof.weights.ARMOR_PENETRATION_RATING == 1.5, "stat keys")
assert(prof.weights.DPS_MELEE == 4.6, "melee dps takes the max of the dps variants, got " .. tostring(prof.weights.DPS_MELEE))
assert(near(prof.weights.SOCKETS, 37), "sockets averaged")
assert(near(prof.weights.RESISTANCE, 0.03), "resists averaged")
assert(#unknown == 0, "nothing unknown")

local cname, cvalues = GearRater.ParsePawnScale('( Pawn: v1: "Fire Mage": SpellPower=1, FireSpellDamage=1, FrostSpellDamage=0.1, HitRating=1.4, CritRating=1, HasteRating=1, Intellect=0.4, Stamina=0.1, Mp5=0.3, MetaSocket=20, IsCloth=1, Wibble=3 )')
local cprof, cunknown = GearRater.ProfileFromPawn(cname, cvalues, "MAGE")
assert(cprof.attack == "spell", "caster inferred")
assert(cprof.schools and near(cprof.schools.FIRE, 1) and near(cprof.schools.FROST, 0.1), "schools as fraction of spell power")
assert(cprof.weights.MANA_REGENERATION == 0.3, "mp5 mapped")
assert(#cunknown == 1 and cunknown[1] == "wibble", "unknown reported, meta/is* ignored: " .. table.concat(cunknown, ","))

print("\n== Pawn: import registers a selectable profile for the player's class")
TEST.class, TEST.talents = "WARRIOR", { 51, 0, 20 }
local imported, info = GearRater.ImportPawn('( Pawn: v1: "EJ Arms 3.3": Strength=2.3, Ap=1, TwoHandDps=4.6 )')
assert(imported and GearRater.Profiles["Import: EJ Arms 3.3"] and GearRaterDB.imported["Import: EJ Arms 3.3"], "registered")
local found = false
for _, n in ipairs(GearRater.ProfilesForClass()) do if n == "Import: EJ Arms 3.3" then found = true end end
assert(found, "listed for class")
GearRaterCharDB.profile = "Import: EJ Arms 3.3"
local active, how = GearRater.GetActiveProfile()
assert(active.name == "Import: EJ Arms 3.3" and how == "manual", "selectable")
-- score with it: 2H with 7.5 dps and +10 str
TEST.equipLoc["imp2h"] = "INVTYPE_2HWEAPON"
TEST.SetLines(GameTooltip, { {"Big"}, {"Two-Hand", "white", "Mace"}, {"10 - 20 Damage", "white", "Speed 2.00"}, {"(7.5 damage per second)"}, {"+10 Strength"} }, "imp2h")
local r = GearRater.ScanTooltip(GameTooltip)
local total = GearRater.Score(r, "imp2h")
assert(near(total, 7.5 * 4.6 + 10 * 2.3), "imported weights used, got " .. total)
GearRaterCharDB.profile = nil

print("\n== Pawn: export round-trips")
local exported = GearRater.ExportPawn(GearRater.Profiles["Mage: Fire"])
print("  " .. exported:sub(1, 120) .. "...")
local ename, evalues = GearRater.ParsePawnScale(exported)
assert(ename == "Mage: Fire" and evalues.spellpower == 1 and near(evalues.firespelldamage, 1) and near(evalues.frostspelldamage, 0.1), "export parses back")
assert(evalues.hitrating == 1.4 and evalues.rangeddps == 0.15, "ratings and wand dps exported")

print("\n== Bags: scoring a bag slot through the hidden tooltip")
TEST.equipLoc["bagring"] = "INVTYPE_FINGER"
TEST.itemInfo["bagring"] = { 2, 20 }
TEST.bags[0] = { [3] = { link = "bagring", lines = { {"Bag Ring"}, {"Finger"}, {"+12 Strength"}, {"+5 Stamina", "green"} } },
                 [4] = { link = "bread", lines = { {"Tough Hunk of Bread"}, {"Use: Restores 61 health.", "green"} } } }
TEST.equipLoc["bread"] = ""
GearRater.InvalidateBags()
local data = GearRater.ScoreBagItem(0, 3)
assert(data and near(data.score, 12 * 2.3 + 5 * 0.1) and data.lvl and data.lvl.delta > 0 and data.cmp, "bag ring scored with level and comparison")
print(string.format("  bag ring score %.1f, effective ilvl %.1f, vs %s delta %.1f", data.score, data.lvl.effective, data.cmp.against, data.cmp.delta))
assert(GearRater.ScoreBagItem(0, 4) == nil, "consumable has no overlay data")
assert(GearRater.ScoreBagItem(0, 9) == nil, "empty slot")
assert(GearRater.ScoreBagItem(0, 3) == data, "cached")
GearRater.InvalidateBags(0)
assert(GearRater.ScoreBagItem(0, 3) ~= data, "cache cleared for bag")

print("\nSTEP5 PASSED")
