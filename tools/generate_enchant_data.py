"""Generate GearRater_Enchants.lua: the server module's random-enchant pool with the real
stat breakdown of every enchant, resolved from the client's own DBC files.

Usage:
    python generate_enchant_data.py <path to item_enchantment_random_tiers.sql>

Sources (read from the 3.3.5a client MPQs next to this AddOns folder):
  SpellItemEnchantment.dbc  description text + up to 3 effects per enchant
  Spell.dbc                 auras behind "equip spell" effects (+2 All Stats, Beast Slaying...)

Output entry shape (GearRater.Enchants[enchantId]):
  { "description", tier, {STAT_KEY, value}, {STAT_KEY, value}, ... }
An entry with no stat pairs is a known non-stat enchant (proc, absorb, stealth...).
"""
import os, sys
from dump_enchants import read_dbc, parse_dbc, parse_pool, ITEM_MOD, IDX_EFFECT, IDX_MIN, IDX_MAX, IDX_ARG, IDX_DESC_ENUS

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "GearRater_Enchants.lua")

# Spell.dbc 3.3.5a columns
S_EFFECT, S_DIESIDES, S_BASEPOINTS, S_AURA, S_MISC, S_MISCB = 71, 74, 80, 95, 110, 113

SCHOOL = {0: "PHYSICAL", 1: "HOLY", 2: "FIRE", 3: "NATURE", 4: "FROST", 5: "SHADOW", 6: "ARCANE"}
SCHOOL_MASK = {1 << k: v for k, v in SCHOOL.items()}
ALL_MAGIC = 0x7E
STAT_IDX = {0: "STRENGTH", 1: "AGILITY", 2: "STAMINA", 3: "INTELLECT", 4: "SPIRIT"}
CREATURE = {1: "BEAST", 2: "DRAGONKIN", 3: "DEMON", 4: "ELEMENTAL", 5: "GIANT", 6: "UNDEAD", 7: "HUMANOID", 8: "CRITTER", 9: "MECHANICAL"}
SKILL = {186: "MINING", 182: "HERBALISM", 393: "SKINNING", 356: "FISHING"}
# CombatRating index -> stat key (SPELL_AURA_MOD_RATING misc is a bit mask of these)
CR = {0: "WEAPON_SKILL", 1: "DEFENSE_SKILL_RATING", 2: "DODGE_RATING", 3: "PARRY_RATING", 4: "BLOCK_RATING",
      5: "HIT_MELEE_RATING", 6: "HIT_RANGED_RATING", 7: "HIT_SPELL_RATING",
      8: "CRIT_MELEE_RATING", 9: "CRIT_RANGED_RATING", 10: "CRIT_SPELL_RATING",
      11: "HIT_TAKEN_MELEE_RATING", 12: "HIT_TAKEN_RANGED_RATING", 13: "HIT_TAKEN_SPELL_RATING",
      14: "CRIT_TAKEN_MELEE_RATING", 15: "CRIT_TAKEN_RANGED_RATING", 16: "CRIT_TAKEN_SPELL_RATING",
      17: "HASTE_MELEE_RATING", 18: "HASTE_RANGED_RATING", 19: "HASTE_SPELL_RATING",
      20: "WEAPON_SKILL", 21: "WEAPON_SKILL", 22: "WEAPON_SKILL", 23: "EXPERTISE_RATING", 24: "ARMOR_PENETRATION_RATING"}
CR_GROUPS = [((1 << 5) | (1 << 6) | (1 << 7), "HIT_RATING"), ((1 << 8) | (1 << 9) | (1 << 10), "CRIT_RATING"),
             ((1 << 17) | (1 << 18) | (1 << 19), "HASTE_RATING"), ((1 << 14) | (1 << 15) | (1 << 16), "RESILIENCE_RATING")]

PROC_AURAS = {4, 42, 69, 15, 23, 27, 56, 57, 72, 109, 193, 226}  # dummy, proc trigger, absorb, ... -> no static stat

unknown_auras = {}


def school_stats(mask, points, prefix_single, key_all, armor_key=None):
    """Expand a school mask into stat pairs."""
    out = []
    if mask & 1 and armor_key:
        out.append((armor_key, points))
        mask &= ~1
    if mask & ALL_MAGIC == ALL_MAGIC:
        out.append((key_all, points))
        return out
    for bit, name in SCHOOL_MASK.items():
        if mask & bit and bit != 1:
            out.append((prefix_single + name, points))
    return out


def aura_stats(aura, points, misc, miscb, spell_id):
    if aura == 29:   # MOD_STAT
        if misc < 0:
            return [(k, points) for k in STAT_IDX.values()]
        return [(STAT_IDX[misc], points)] if misc in STAT_IDX else []
    if aura == 13:   # MOD_DAMAGE_DONE
        return school_stats(misc, points, "SPELL_DAMAGE_", "SPELL_DAMAGE_DONE")
    if aura == 135:  # MOD_HEALING_DONE
        return [("SPELL_HEALING_DONE", points)]
    if aura == 22:   # MOD_RESISTANCE
        return school_stats(misc, points, "RESISTANCE_", "ALL_RESISTANCES", armor_key="ARMOR")
    if aura == 189:  # MOD_RATING
        out, mask = [], misc
        for gmask, key in CR_GROUPS:
            if mask & gmask == gmask:
                out.append((key, points)); mask &= ~gmask
        for idx, key in CR.items():
            if mask & (1 << idx):
                out.append((key, points))
        return out
    if aura == 99:   return [("ATTACK_POWER", points)]
    if aura == 124:  return [("RANGED_ATTACK_POWER", points)]
    if aura == 85:   return [("MANA_REGENERATION", points)] if misc == 0 else []
    if aura in (84, 161): return [("HEALTH_REGEN", points)]
    if aura in (34, 230): return [("HEALTH", points)]
    if aura == 35:   return [("MANA", points)] if misc == 0 else []
    if aura == 158:  return [("BLOCK_VALUE", points)]
    if aura == 59:   # MOD_DAMAGE_DONE_CREATURE
        return [("SLAYER_" + name, points) for t, name in CREATURE.items() if misc & (1 << (t - 1))]
    if aura == 30:   # MOD_SKILL
        return [(SKILL[misc], points)] if misc in SKILL else [("WEAPON_SKILL", points)]
    if aura == 154:  return [("STEALTH", points)]
    if aura in PROC_AURAS:
        return []
    unknown_auras.setdefault(aura, []).append(spell_id)
    return []


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    ench_rows, nfld, ench_s = parse_dbc(read_dbc("SpellItemEnchantment.dbc"))
    assert nfld == 38, nfld
    ench_by_id = {r[0]: r for r in ench_rows}
    spell_rows, snfld, _ = parse_dbc(read_dbc("Spell.dbc"))
    assert snfld == 234, snfld
    spell_by_id = {r[0]: r for r in spell_rows}

    pool = parse_pool(sys.argv[1])
    entries, missing_spells = [], []
    for e in pool:
        r = ench_by_id[e["id"]]
        desc = ench_s(r[IDX_DESC_ENUS])
        stats = []
        for i in range(3):
            t, mn, mx, arg = r[IDX_EFFECT + i], r[IDX_MIN + i], r[IDX_MAX + i], r[IDX_ARG + i]
            if t == 2:      # weapon damage
                stats.append(("WEAPON_DAMAGE", mn))
            elif t == 4:    # resistance
                stats.append(("ARMOR" if arg == 0 else "RESISTANCE_" + SCHOOL[arg], mn))
            elif t == 5:    # stat
                if arg in ITEM_MOD:
                    stats.append((ITEM_MOD[arg], mn))
            elif t == 3:    # equip spell
                sp = spell_by_id.get(arg)
                if not sp:
                    missing_spells.append((e["id"], arg)); continue
                for j in range(3):
                    if sp[S_EFFECT + j] == 6:   # SPELL_EFFECT_APPLY_AURA
                        # Core: value = basePoints + roll(1..dieSides); dieSides 1 is the usual "+1".
                        ds = sp[S_DIESIDES + j]
                        points = sp[S_BASEPOINTS + j] + (0 if ds == 0 else 1 if ds == 1 else (1 + ds) / 2)
                        if ds > 1:
                            print(f"note: spell {arg} rolls {sp[S_BASEPOINTS + j] + 1}-{sp[S_BASEPOINTS + j] + ds}, using average")
                        stats += aura_stats(sp[S_AURA + j], points, sp[S_MISC + j], sp[S_MISCB + j], arg)
        # merge duplicate keys
        merged = {}
        for k, v in stats:
            merged[k] = merged.get(k, 0) + v
        entries.append((e["id"], desc, e["tier"], list(merged.items())))

    lines = ["-- GearRater enchant data. GENERATED by tools/generate_enchant_data.py from the server's",
             "-- item_enchantment_random_tiers.sql joined with the 3.3.5a client's SpellItemEnchantment.dbc",
             "-- and Spell.dbc. Do not edit by hand.",
             "--",
             "-- [enchantId] = { description, tier, {STAT_KEY, value}, ... }",
             "-- No stat pairs = known enchant with no static stat (proc, absorb, stealth, ...).",
             "",
             "GearRater = GearRater or {}",
             "GearRater.Enchants = {"]
    for eid, desc, tier, stats in sorted(entries):
        pairs = "".join(f', {{"{k}", {v}}}' for k, v in stats)
        lines.append(f"    [{eid}] = {{ {lua_str(desc)}, {tier}{pairs} }},")
    lines.append("}")
    open(OUT, "w", encoding="utf-8", newline="\n").write("\n".join(lines) + "\n")

    with_stats = sum(1 for e in entries if e[3])
    print(f"wrote {OUT}: {len(entries)} enchants, {with_stats} with stats, {len(entries) - with_stats} non-stat")
    if missing_spells:
        print("missing spells:", missing_spells)
    for aura, ids in sorted(unknown_auras.items()):
        print(f"UNHANDLED aura {aura} in spells {sorted(set(ids))[:8]}{'...' if len(set(ids)) > 8 else ''}")
    keys = sorted({k for e in entries for k, _ in e[3]})
    print("stat keys used:", ", ".join(keys))


if __name__ == "__main__":
    main()
