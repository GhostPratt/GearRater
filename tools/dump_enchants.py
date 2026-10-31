"""Dump the random-enchant module's enchant pool with client-side text and effects.

Reads SpellItemEnchantment.dbc from the 3.3.5a client's enUS MPQ chain (next to this
AddOns folder) and joins it with the module's item_enchantment_random_tiers.sql.

Usage:
    python dump_enchants.py <path to item_enchantment_random_tiers.sql> [out.json]

Output JSON: list of {id, tier, class, subclass, desc, effects:[{type,min,max,arg}]}.
Effect types (SpellItemEnchantment): 0 none, 1 combat spell (proc), 2 weapon damage,
3 equip spell (aura), 4 resistance, 5 stat (arg = ITEM_MOD_*), 6 totem, 7 use spell,
8 prismatic socket.
"""
import json, os, re, struct, sys
import mpyq

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.normpath(os.path.join(HERE, "..", "..", "..", "..", "Data"))
FIELDS_335 = 38
IDX_EFFECT, IDX_MIN, IDX_MAX, IDX_ARG, IDX_DESC_ENUS = 2, 5, 8, 11, 14

ITEM_MOD = {0: "MANA", 1: "HEALTH", 3: "AGILITY", 4: "STRENGTH", 5: "INTELLECT", 6: "SPIRIT", 7: "STAMINA",
            12: "DEFENSE_SKILL_RATING", 13: "DODGE_RATING", 14: "PARRY_RATING", 15: "BLOCK_RATING",
            16: "HIT_MELEE_RATING", 17: "HIT_RANGED_RATING", 18: "HIT_SPELL_RATING",
            19: "CRIT_MELEE_RATING", 20: "CRIT_RANGED_RATING", 21: "CRIT_SPELL_RATING",
            22: "HIT_TAKEN_MELEE_RATING", 23: "HIT_TAKEN_RANGED_RATING", 24: "HIT_TAKEN_SPELL_RATING",
            25: "CRIT_TAKEN_MELEE_RATING", 26: "CRIT_TAKEN_RANGED_RATING", 27: "CRIT_TAKEN_SPELL_RATING",
            28: "HASTE_MELEE_RATING", 29: "HASTE_RANGED_RATING", 30: "HASTE_SPELL_RATING",
            31: "HIT_RATING", 32: "CRIT_RATING", 33: "HIT_TAKEN_RATING", 34: "CRIT_TAKEN_RATING",
            35: "RESILIENCE_RATING", 36: "HASTE_RATING", 37: "EXPERTISE_RATING", 38: "ATTACK_POWER",
            39: "RANGED_ATTACK_POWER", 40: "FERAL_ATTACK_POWER", 41: "SPELL_HEALING_DONE",
            42: "SPELL_DAMAGE_DONE", 43: "MANA_REGENERATION", 44: "ARMOR_PENETRATION_RATING",
            45: "SPELL_POWER", 46: "HEALTH_REGEN", 47: "SPELL_PENETRATION", 48: "BLOCK_VALUE"}


def read_dbc(name):
    chain = [os.path.join(DATA, "enUS", n) for n in
             ["patch-enUS-3.MPQ", "patch-enUS-2.MPQ", "patch-enUS.MPQ", "lichking-locale-enUS.MPQ",
              "expansion-locale-enUS.MPQ", "locale-enUS.MPQ"]]
    for p in chain:
        if not os.path.exists(p):
            continue
        data = mpyq.MPQArchive(p, listfile=False).read_file("DBFilesClient\\" + name)
        if data:
            return data
    raise SystemExit("could not find " + name)


def parse_dbc(blob):
    magic, nrec, nfld, rsize, _ = struct.unpack_from("<4sIIII", blob, 0)
    assert magic == b"WDBC"
    records = blob[20:20 + nrec * rsize]
    strings = blob[20 + nrec * rsize:]
    fmt = "<" + "i" * nfld
    rows = [struct.unpack_from(fmt, records, i * rsize) for i in range(nrec)]

    def s(off):
        end = strings.find(b"\0", off)
        return strings[off:end].decode("utf-8", "replace")
    return rows, nfld, s


def parse_pool(sql_path):
    text = open(sql_path, encoding="utf-8").read()
    pool = []
    for m in re.finditer(r"\((\d+),\s*(\d+),\s*'(\w+)',\s*(NULL|-?\d+)\)", text):
        pool.append({"id": int(m.group(1)), "tier": int(m.group(2)), "class": m.group(3),
                     "subclass": None if m.group(4) == "NULL" else int(m.group(4))})
    return pool


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    out_path = sys.argv[2] if len(sys.argv) > 2 else os.path.join(HERE, "enchant_pool.json")
    rows, nfld, s = parse_dbc(read_dbc("SpellItemEnchantment.dbc"))
    if nfld != FIELDS_335:
        raise SystemExit(f"SpellItemEnchantment.dbc has {nfld} fields, expected {FIELDS_335}")
    by_id = {r[0]: r for r in rows}

    pool = parse_pool(sys.argv[1])
    out, missing = [], []
    for e in pool:
        r = by_id.get(e["id"])
        if not r:
            missing.append(e["id"]); continue
        effects = []
        for i in range(3):
            t = r[IDX_EFFECT + i]
            if t:
                effects.append({"type": t, "min": r[IDX_MIN + i], "max": r[IDX_MAX + i], "arg": r[IDX_ARG + i],
                                "stat": ITEM_MOD.get(r[IDX_ARG + i]) if t == 5 else None})
        e["desc"] = s(r[IDX_DESC_ENUS])
        e["effects"] = effects
        out.append(e)
    json.dump(out, open(out_path, "w", encoding="utf-8"), indent=1, ensure_ascii=False)

    types = {}
    for e in out:
        for f in e["effects"]:
            types[f["type"]] = types.get(f["type"], 0) + 1
    print(f"{len(out)} pool enchants written to {out_path}; {len(missing)} ids missing from DBC: {missing}")
    print("effect type counts:", dict(sorted(types.items())))
    print("distinct descriptions:", len({e['desc'] for e in out}))


if __name__ == "__main__":
    main()
