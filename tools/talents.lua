-- Talent-aware weights and caps.
local function near(a, b, eps) return math.abs(a - b) <= (eps or 0.005) end
local function W(profileName) local w, notes = GearRater.GetWeights(GearRater.Profiles[profileName]); return w, notes end
local function reset() TEST.talentList = {}; TEST.ratingBonus = {}; TEST.expertise = 0; TEST.defense = { 0, 0 }; GearRater.InvalidateTalents() end

print("\n== Talents: multiplier and conversion (Prot paladin)")
reset()
TEST.class = "PALADIN"
TEST.talentList = { { "Divine Strength", 5 }, { "Touched by the Light", 3 } }
local w, notes = W("Paladin: Protection")
-- base STR 0.6 * 1.15 = 0.69, plus 60% of SP weight (0.1) * 1.15 = 0.069
print(string.format("  STRENGTH %.3f (expect 0.759); notes: %d", w.STRENGTH, #notes))
assert(near(w.STRENGTH, 0.759), "prot paladin strength")
assert(#notes == 2, "two notes")

print("\n== Talents: Careful Aim gives Intellect ranged attack power value (MM hunter)")
reset()
TEST.class = "HUNTER"
TEST.talentList = { { "Careful Aim", 3 }, { "Combat Experience", 2 } }
w = W("Hunter: Marksmanship")
-- AGI 2.0*1.02 ; INT (0.7 + 1.0 * RAP 1.0) * 1.02
print(string.format("  AGILITY %.3f INTELLECT %.3f (expect 2.040, 1.734)", w.AGILITY, w.INTELLECT))
assert(near(w.AGILITY, 2.04) and near(w.INTELLECT, 1.734), "mm hunter")

print("\n== Talents: attack power multiplier scales AP and feeders (Combat rogue)")
reset()
TEST.class = "ROGUE"
TEST.talentList = { { "Savage Combat", 2 } }
w = W("Rogue: Combat")
assert(near(w.ATTACK_POWER, 1.04) and near(w.AGILITY, 2.1 * 1.04) and near(w.STRENGTH, 1.1), "savage combat: AP and agility scaled, strength not an AP feeder for rogues")

print("\n== Talents: Heart of the Wild differs for cat and bear")
reset()
TEST.class = "DRUID"
TEST.talentList = { { "Heart of the Wild", 5 } }
local cat, bear = W("Druid: Feral (Cat)"), W("Druid: Feral (Bear)")
assert(near(cat.INTELLECT, 0.05 * 1.1) and near(cat.ATTACK_POWER, 1.1) and near(cat.STAMINA, 0.1), "cat: int and ap up, stamina unchanged")
assert(near(bear.STAMINA, 1.1) and near(bear.ATTACK_POWER, 0.15), "bear: stamina up, ap unchanged")

print("\n== Talents: uneven ranks (Demonic Embrace)")
reset()
TEST.class = "WARLOCK"
TEST.talentList = { { "Demonic Embrace", 2 } }
w = W("Warlock: Demonology")
assert(near(w.STAMINA, 0.1 * 1.07), "rank 2 = 7%")

print("\n== Caps: hit from gear plus talents")
reset()
TEST.class = "WARRIOR"
TEST.ratingBonus[6] = 7.5
w = W("Warrior: Fury")
assert(w.HIT_RATING == 1.8, "below cap: hit keeps its weight")
TEST.talentList = { { "Precision", 1 } }
GearRater.InvalidateTalents()
w, notes = W("Warrior: Fury")
assert(w.HIT_RATING == 0, "7.5% gear + 1% talent >= 8%: hit worth 0")
print("  " .. notes[#notes])
TEST.class = "MAGE"; reset(); TEST.ratingBonus[8] = 17
w = W("Mage: Fire")
assert(w.HIT_RATING == 0, "spell hit cap 17%")
TEST.ratingBonus[8] = 14
GearRater.InvalidateTalents()
assert(W("Mage: Fire").HIT_RATING == 1.4, "below spell cap")

print("\n== Caps: expertise and defense")
reset()
TEST.class = "WARRIOR"
TEST.expertise = 26
w = W("Warrior: Arms")
assert(w.EXPERTISE_RATING == 0, "expertise capped")
TEST.expertise = 10; TEST.defense = { 400, 140 }
GearRater.InvalidateTalents()
w = W("Warrior: Protection")
assert(w.DEFENSE_SKILL_RATING == 0 and w.EXPERTISE_RATING == 0.5, "defense capped at 540, expertise not")
TEST.defense = { 400, 100 }
assert(W("Warrior: Protection").DEFENSE_SKILL_RATING == 0.9, "below defense cap")

print("\n== Toggles: talents off restores base; caps off keeps multipliers")
reset()
TEST.class = "PALADIN"
TEST.talentList = { { "Divine Strength", 5 } }
TEST.ratingBonus[6] = 9
GearRaterDB.talents = false
w = W("Paladin: Retribution")
assert(w.STRENGTH == 2.4 and w.HIT_RATING == 1.9, "talents off: base weights")
GearRaterDB.talents = true; GearRaterDB.caps = false
w = W("Paladin: Retribution")
assert(near(w.STRENGTH, 2.4 * 1.15) and w.HIT_RATING == 1.9, "caps off: multiplier applied, hit kept")
GearRaterDB.caps = true
w = W("Paladin: Retribution")
assert(w.HIT_RATING == 0, "caps on: hit zeroed")
reset()
TEST.class, TEST.talents = "WARRIOR", { 0, 0, 0 }

print("\nTALENTS PASSED")
