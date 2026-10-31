"""Run GearRater's parser over every enchant description the server module can roll.

Usage: python check_pool.py [enchant_pool.json]
Prints every description the parser cannot handle, grouped by effect type, and a
coverage summary. Needs enchant_pool.json from dump_enchants.py.
"""
import json, os, sys
import lupa.lua51 as lupa

HERE = os.path.dirname(os.path.abspath(__file__))
POOL = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "enchant_pool.json")
GLOBALSTRINGS = os.path.join(HERE, "GlobalStrings.lua")
ADDON = os.path.join(HERE, "..", "GearRater.lua")

L = lupa.LuaRuntime(unpack_returned_tuples=True)
L.execute(open(GLOBALSTRINGS, encoding="utf-8", errors="replace").read())
L.execute(r"""
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
SlashCmdList = {}
local frames = {}
function CreateFrame() local f = { events = {} }
    f.RegisterEvent = function(self, e) self.events[e] = true end; f.UnregisterEvent = function() end
    f.SetScript = function(self, which, fn) if which == "OnEvent" then self.onEvent = fn end end
    f.Show = function() end; f.Hide = function() end
    frames[#frames+1] = f; return f end
local function tip(name) return { GetName = function() return name end, HookScript = function() end } end
GameTooltip, ItemRefTooltip, ShoppingTooltip1, ShoppingTooltip2 = tip("GameTooltip"), tip("ItemRefTooltip"), tip("ShoppingTooltip1"), tip("ShoppingTooltip2")
FRAMES = frames
""")
L.execute(open(os.path.join(HERE, "..", "GearRater_Enchants.lua"), encoding="utf-8").read())
L.execute(open(ADDON, encoding="utf-8").read())
L.execute('for _, f in ipairs(FRAMES) do if f.events.ADDON_LOADED then f.onEvent(f, "ADDON_LOADED", "GearRater") end end')
parse = L.eval("GearRater.ParseLine")

pool = json.load(open(POOL, encoding="utf-8"))
TYPE_NAMES = {1: "proc", 2: "weapon damage", 3: "equip spell", 4: "resistance", 5: "stat", 6: "totem", 7: "use spell", 8: "socket"}

ok, bad = [], {}
for e in pool:
    desc = e["desc"]
    res = parse(desc) if desc else None
    stats, known = (res[0], res[1]) if isinstance(res, tuple) else (None, False)
    kinds = sorted({TYPE_NAMES.get(f["type"], str(f["type"])) for f in e["effects"]}) or ["none"]
    if known:
        pairs = [(stats[i][1], stats[i][2]) for i in range(1, len(stats) + 1)] if stats else []
        ok.append((e, pairs))
    else:
        bad.setdefault("/".join(kinds), []).append(e)

print(f"parsed {len(ok)} / {len(pool)} pool enchants\n")
for kind, items in sorted(bad.items()):
    print(f"== unparsed, effect {kind}: {len(items)}")
    seen = set()
    for e in items:
        if e["desc"] in seen:
            continue
        seen.add(e["desc"])
        eff = "; ".join(f"t{f['type']} {f['min']}-{f['max']} arg{f['arg']}" + (f" ({f['stat']})" if f.get('stat') else "") for f in e["effects"])
        print(f"  [{e['id']} tier{e['tier']} {e['class']}] {e['desc']!r}   {eff}")
    print()

# Sanity: for single-stat enchants, does the resolved value match the DBC amount?
mismatch, nostat = 0, []
for e, pairs in ok:
    stats = [f for f in e["effects"] if f["type"] == 5]
    if len(stats) == 1 and len(pairs) == 1 and stats[0]["min"] != pairs[0][1]:
        mismatch += 1
        print(f"value mismatch [{e['id']}] {e['desc']!r}: parsed {pairs}, dbc {stats[0]['min']}")
    if not pairs:
        nostat.append(f"[{e['id']}] {e['desc']}")
print()
print(f"{mismatch} value mismatches among single-stat enchants")
print(f"{len(nostat)} known enchants carry no stat value:")
for line in nostat:
    print("  " + line)
