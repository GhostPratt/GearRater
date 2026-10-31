# Gear Rater

WoW 3.3.5a addon that rates gear by the stats actually on it, not its item level.
Built for AzerothCore servers running a random-enchant module, where item level
badly understates an item's real strength.

## Status: step 5 (score, equipped comparison, effective item level, bag overlays, Pawn import)

Hover any item. The addon reads the tooltip lines, extracts every stat (base stats, random
suffix stats, enchants and the random-enchant module's bonuses alike) and appends:

    GR Score: 245.3  [Warrior: Arms]
    GR Equipped: +31.2 (+15%)  vs Primal Boots
    GR Item Level: 23  (base 5, +18 from enchants)

The score is the weighted sum of the item's stats using the active profile's weights. The
equipped line is the difference to what you wear in that slot, scored the same way. The
item level line is class-neutral: it says how many item levels the item's extra stats are
worth, so a level 5 white mace carrying five random enchants reads like a level 23 item.

### Equipped comparison

The equipped item is read through a hidden tooltip, so its random enchants count exactly as
the client shows them. Rings and trinkets compare against the weaker of the two you wear. A
two-hander compares against main hand plus off hand together; a one-hander ignores a shield
or held item in the off hand. Hovering something you already wear says "equipped" (or, for a
ring, compares against your other ring). Equipped scores are cached and refreshed when gear,
talents, the profile or a weight changes.

### Effective item level

Blizzard budgets an item's stats linearly in item level for its quality and slot, combining
stats as `(sum (value x cost)^1.7095)^(1/1.7095)`. The constants are community reverse
engineering from TBC (see `GearRater_Budget.lua`) and only approximately right for WotLK, so
the addon never uses them in absolute terms. It measures the difference between the item's
budget points with and without its enchant stats and converts that difference to item levels
with the slope for the item's quality and the divisor for its slot. Quality intercepts cancel,
and items whose base stats the server rewrote (Individual Progression restores vanilla values)
are compared against themselves. Base armor, shield block, weapon DPS and sockets are not part
of the stat budget and are left out. `/gr why` shows the budget points behind the number.

### Profiles

The profile is picked from your class and the talent tree with the most points spent
(active dual-spec group). With no talents a leveling default for the class is used and
the tooltip says "(no talents)". A few profiles can only be chosen by hand because talents
cannot tell them apart: Druid Feral (Bear) and Death Knight Tank.

Weights live in `GearRater_Weights.lua` (WotLK-era community values, meant to be tuned).
Conventions: physical DPS 1 Attack Power = 1, casters and healers 1 Spell Power = 1,
tanks 1 Stamina = 1. Scores are therefore comparable within a profile, not across profiles.

Every stat that does anything for the character has a weight, however small: a caster still
gets a little for armor, dodge, attack power and weapon DPS because they get hit and
sometimes swing. Only stats that literally do nothing for the class are zero, enforced by
per-class rules (Intellect and spell power on warriors, parry on druids, feral attack power
on anyone but a druid, spell damage of a school the spec never casts). `/gr why` lists the
zero-weight stats of an item as "ignored".

Weapon DPS is weighted by the weapon type the profile attacks with: full for melee or
ranged as appropriate, a token amount for the other, and wand DPS for casters. The weights
describe the spec, not the exact talents chosen; individual talents (Kings, Precision, hit
caps) are not modelled yet.

### Bag overlays

Every equippable item in your bags and bank shows its effective item level in the top-left
corner of its slot: green when it beats what you have equipped, red when it is worse, grey
when it is the equipped item itself, white when there is nothing to compare. `/gr bags`
toggles the overlays.

### Pawn scales

`/gr import` opens a paste window for a Pawn v1 scale string such as
`( Pawn: v1: "EJ Arms": Strength=2.3, Ap=1, HitRating=1.9, TwoHandDps=4.6 )`. The scale
becomes a manual profile for your class named "Import: EJ Arms", saved across sessions and
selectable with `/gr spec`. Pawn's dps variants fold into the melee or ranged weapon DPS
weight, socket colours average into the socket weight, single resistances average into the
resistance weight, and school damage becomes a fraction of the spell power weight. `/gr export`
shows the active profile as a Pawn string ready to copy.

### Commands

| Command | Effect |
| --- | --- |
| `/gr why` | per-stat breakdown of the last hovered item's score (value x weight) |
| `/gr spec` | show the active profile and the profiles for your class |
| `/gr spec <number or name>` | override the profile for this character; `/gr spec auto` follows talents again |
| `/gr weight` | list the active profile's weights |
| `/gr weight STAT value` | change one weight (saved); `/gr weight reset` restores the defaults |
| `/gr score` | toggle the score line |
| `/gr ilvl` | toggle the effective item level line |
| `/gr compare` | toggle the equipped comparison line |
| `/gr bags` | toggle the bag and bank overlays |
| `/gr import [string]` | import a Pawn scale (opens a paste window when no string is given) |
| `/gr export` | show the active profile as a Pawn scale string |
| `/gr tip` | toggle the parsed-stat lines in the tooltip (diagnostics) |
| `/gr chat` | toggle the chat dump on hover (diagnostics) |
| `/gr dump` | reprint the parsed stats of the last hovered item |
| `/gr raw` | print the raw tooltip lines of the last hovered item with their colour class |
| `/gr patterns` | list the Lua patterns built from the client's global strings |

### Server enchant pool

The server runs [mod-random-enchants-enhanced](https://github.com/GhostPratt/mod-random-enchants-enhanced),
which adds up to five enchants per item in enchantment slots 0, 1, 5, 7 and 8, drawn from a
700-entry pool by item quality. `GearRater_Enchants.lua` is generated from that pool joined
with the client's SpellItemEnchantment.dbc and Spell.dbc, so every possible enchant text maps
to its exact stat breakdown (including multi-stat ones like "Block Level 42" = +12 Block Rating,
+12 Strength, and non-stat procs like "Crusader"). Tooltip lines are looked up there first and
only fall back to pattern parsing when the text is unknown.

Chat links carry only slot 0, so an item linked by another player shows at most one of its
random enchants.

Regenerate after the module's SQL changes:

    python tools/generate_enchant_data.py <module>/data/sql/db-world/base/item_enchantment_random_tiers.sql
    python tools/check_pool.py        # coverage report (needs tools/dump_enchants.py output)

### How parsing works

Patterns are generated at load from the client's own `ITEM_MOD_*` global strings
(`"%c%d Stamina"`, `"Equip: Improves hit rating by %d."` and so on), so the
scanner is locale safe and needs no hand-written stat list. Longer formats are
tried first so "attack power ... in Cat, Bear ... forms" wins over plain attack
power. Enchant text such as `+20 Spell Power` falls back to a lookup against the
`ITEM_MOD_*_SHORT` names. Grey (inactive) and red (unmet requirement) lines are
skipped. Anything starting with Equip:, Use: or Chance on hit: that does not
match a stat is reported as unparsed so gaps are visible.

## Ideas not yet built

- Talent-aware weight adjustments (Kings-style multipliers, hit caps).
- Manual values for proc enchants (Crusader, Mongoose) that currently score zero.
- A character-sheet summary of total gear score.
