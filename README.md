# Gear Rater

A World of Warcraft 3.3.5a addon that rates gear by the stats actually on it, weighted for your
class, spec and talents, instead of trusting item level.

Built for AzerothCore servers running a random-enchant module
([mod-random-enchants-enhanced](https://github.com/GhostPratt/mod-random-enchants-enhanced)),
where a level 5 white mace can carry five extra enchants and item level says nothing about how
strong a piece really is.

## What you get

Hover any item and three lines are added to its tooltip:

    GR Score: 245.3  [Warrior: Arms]
    GR Equipped: +31.2 (+15%)  vs Primal Boots
    GR Item Level: 23  (base 5, +18 from enchants)

- **Score** is the weighted sum of every stat on the item, using the weights of your active
  profile adjusted for your talents.
- **Equipped** is the difference to the item you wear in that slot, scored the same way.
- **Item Level** is class-neutral: how many item levels the item's extra stats are worth.

Beyond the tooltip:

- **Bag and bank overlays** paint each equippable item's effective item level on its slot,
  green when it beats what you wear and red when it is worse.
- **Character sheet summary** on the paper doll: total equipped gear score and average base
  and effective item level, with a per-slot breakdown on hover.
- **Pawn scale import and export**, so community weight strings can be pasted in.
- **Tuning commands** to change any weight, pick a profile by hand and see exactly how a score
  was built.

## Installation

Copy the `GearRater` folder into `Interface\AddOns` and reload the UI. Everything is on by
default; the `/gr` commands below turn individual pieces off.

## Commands

All commands start with `/gr` (or `/gearrater`). Typing `/gr` alone lists them.

### Everyday use

| Command | Effect |
| --- | --- |
| `/gr why` | Per-stat breakdown of the last hovered item: each stat, its weight and its contribution, the stats ignored as weight zero, the talent and cap adjustments in force, and the budget points behind the item level line. |
| `/gr char` | Print the equipped gear summary to chat: total score, average item levels and one line per slot. |
| `/gr spec` | Show the active profile, how it was chosen (talents, manual or class default) and the profiles available to your class. |
| `/gr spec <number or name>` | Pin a profile for this character, by its number in the list or part of its name (`/gr spec bear`). |
| `/gr spec auto` | Follow talents again. |
| `/gr talents` | Show the talent multipliers, conversions and caps currently applied to your weights. |
| `/gr talents on` / `/gr talents off` | Enable or disable talent adjustments. |
| `/gr talents caps` | Toggle the hit, expertise and defense caps. |

### Weights

| Command | Effect |
| --- | --- |
| `/gr weight` | List the active profile's weights, highest first. `*` marks a value you customised, `~` marks a talent-adjusted value and shows the base. |
| `/gr weight <STAT> <value>` | Change one weight for the active profile, for example `/gr weight hit_rating 1.5`. Saved across sessions. |
| `/gr weight reset` | Remove your customisations for the active profile. |
| `/gr import` | Open a paste window for a Pawn v1 scale string and import it as a profile for your class. |
| `/gr import <string>` | Import a Pawn string directly, when it fits in the chat box. |
| `/gr export` | Show the active profile as a Pawn v1 string, pre-selected for Ctrl+C. |

### Display toggles

| Command | Effect |
| --- | --- |
| `/gr score` | Tooltip score line. |
| `/gr compare` | Tooltip equipped comparison line. |
| `/gr ilvl` | Tooltip effective item level line. |
| `/gr bags` | Bag and bank slot overlays. |
| `/gr sheet` | Character sheet summary. |

### Diagnostics

| Command | Effect |
| --- | --- |
| `/gr tip` | Add the parsed stat list to tooltips (off by default). |
| `/gr chat` | Dump the parsed stats of each newly hovered item to chat (off by default). |
| `/gr dump` | Reprint the parsed stats, score and comparison of the last hovered item. |
| `/gr raw` | Print the raw tooltip lines of the last hovered item with their colour class, which shows how the client rendered each line. |
| `/gr save` | Store the last hovered item's raw tooltip in SavedVariables for inspection outside the game. Items with unparsed lines are stored automatically. |
| `/gr clear` | Clear the stored samples and the unparsed-line tally. |
| `/gr patterns` | List the Lua patterns generated from the client's global strings. |

## How it works

### Profiles

The profile is picked from your class and the talent tree with the most points spent, in the
active dual-spec group. With no talents a leveling default for the class is used and the
tooltip says "(no talents)". Two profiles can only be chosen by hand because talents cannot
tell them apart: Druid Feral (Bear) and Death Knight Tank.

Weights live in `GearRater_Weights.lua` (WotLK-era community values, meant to be tuned).
Conventions: physical DPS 1 Attack Power = 1, casters and healers 1 Spell Power = 1, tanks
1 Stamina = 1. Scores are therefore comparable within a profile, not across profiles.

Every stat that does anything for the character has a weight, however small: a caster still
gets a little for armor, dodge, attack power and weapon DPS because they get hit and
sometimes swing. Only stats that literally do nothing for the class are zero, enforced by
per-class rules (Intellect and spell power on warriors, parry on druids, feral attack power on
anyone but a druid, spell damage of a school the spec never casts). Weapon DPS is weighted by
the weapon type the profile attacks with: full for melee or ranged as appropriate, a token
amount for the other, and wand DPS for casters.

### Talent adjustments and caps

`GearRater_Talents.lua` adjusts the spec weights for the talents actually taken (enUS talent
names, 3.3.5a values):

- Stat multipliers such as Divine Strength, Arcane Mind or Survival of the Fittest scale that
  stat's weight.
- Stat conversions such as Careful Aim (Intellect to ranged attack power), Touched by the
  Light (Strength to spell power) or Mental Quickness (attack power to spell power) add the
  converted stat's value to the source stat.
- Attack power multipliers (Deadliness, Savage Combat, Improved Berserker Stance) scale attack
  power and the stats that mostly feed it.
- Caps: hit rating is worth nothing once gear plus talents reach the boss cap for the profile's
  attack type (8% melee and ranged, 17% spell), expertise rating once expertise reaches 26,
  defense rating once defense reaches 540. Caps read your current gear, so they switch on and
  off as you change equipment. Dual-wield white-hit caps are not modelled; turn caps off with
  `/gr talents caps` if that matters for your spec.

### Equipped comparison

The equipped item is read through a hidden tooltip, so its random enchants count exactly as
the client shows them. Rings and trinkets compare against the weaker of the two you wear. A
two-hander compares against main hand plus off hand together; a one-hander ignores a shield or
held item in the off hand. Hovering something you already wear says "equipped" (or, for a
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
are compared against themselves. Base armor, shield block, weapon DPS and sockets come from
separate item level tables rather than the stat budget and are left out; enchanted armor and
flat weapon damage do count.

### Character sheet

The paper doll shows the total score of everything equipped (shirt and tabard excluded) and
the average base item level, with the average effective item level when enchants add to it.
Hovering the text lists every slot with its item, score and effective item level. The panel
refreshes whenever gear, talents, the profile or a weight changes.

### Bag overlays

Every equippable item in your bags and bank shows its effective item level in the top-left
corner of its slot: green when it beats what you have equipped, red when it is worse, grey when
it is the equipped item itself, white when there is nothing to compare.

### Pawn scales

A Pawn v1 scale string such as `( Pawn: v1: "EJ Arms": Strength=2.3, Ap=1, HitRating=1.9,
TwoHandDps=4.6 )` becomes a manual profile for your class named "Import: EJ Arms", saved
across sessions and selectable with `/gr spec`. Pawn's dps variants fold into the melee or
ranged weapon DPS weight, socket colours average into the socket weight, single resistances
average into the resistance weight, and school damage becomes a fraction of the spell power
weight. The paste window exists because WoW's chat box stops at 255 characters.

### Server enchant pool

The server's random-enchant module adds up to five enchants per item in enchantment slots 0,
1, 5, 7 and 8, drawn from a 700-entry pool by item quality. `GearRater_Enchants.lua` is
generated from that pool joined with the client's SpellItemEnchantment.dbc and Spell.dbc, so
every possible enchant text maps to its exact stat breakdown, including multi-stat ones like
"Block Level 42" (+12 Block Rating, +12 Strength) and non-stat procs like "Crusader". Tooltip
lines are looked up there first and only fall back to pattern parsing when the text is unknown.

Chat links carry only slot 0, so an item linked by another player shows at most one of its
random enchants.

### Parsing

Patterns are generated at load from the client's own `ITEM_MOD_*` global strings, so the
scanner is locale safe and needs no hand-written stat list. Longer formats are tried first so
"attack power ... in Cat, Bear ... forms" wins over plain attack power. Enchant text such as
`+20 Spell Power` falls back to a lookup against the `ITEM_MOD_*_SHORT` names. Grey (inactive)
and red (unmet requirement) lines are skipped. Anything starting with Equip:, Use: or Chance on
hit: that does not match a stat is reported as unparsed so gaps stay visible.

## Development

The `tools` folder holds an offline test harness and the data generators. They need Python
with `lupa` (Lua 5.1 binding) and `mpyq`, and a 3.3.5a client two folders up from the addon:

    python tools/test_gearrater.py          # runs every test group under Lua 5.1 with stubbed WoW APIs
    python tools/generate_enchant_data.py <module>/data/sql/db-world/base/item_enchantment_random_tiers.sql
    python tools/check_pool.py              # parser coverage of the whole enchant pool

The harness extracts GlobalStrings.lua from the client's MPQ on first run and replays real
captured tooltips, so parser changes are checked against what the client actually renders.

## Ideas not yet built

- Manual values for proc enchants (Crusader, Mongoose) that currently score zero.
- Scoring inspected players.
