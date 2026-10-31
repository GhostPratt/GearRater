"""Offline harness: run GearRater.lua under Lua 5.1 with stubbed WoW globals and fake tooltips.

Usage (from anywhere):  python GearRater/tools/test_gearrater.py
Needs: pip install lupa mpyq. GlobalStrings.lua is extracted from the client's enUS MPQ on first run.
"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
os.chdir(HERE)
ADDON = os.path.join(HERE, "..", "GearRater.lua")
GLOBALSTRINGS = os.path.join(HERE, "GlobalStrings.lua")
if not os.path.exists(GLOBALSTRINGS):
    import mpyq
    base = os.path.normpath(os.path.join(HERE, "..", "..", "..", "..", "Data", "enUS"))
    for name in ["patch-enUS-3.MPQ", "patch-enUS-2.MPQ", "patch-enUS.MPQ", "locale-enUS.MPQ"]:
        data = mpyq.MPQArchive(os.path.join(base, name), listfile=False).read_file("Interface\FrameXML\GlobalStrings.lua")
        if data:
            open(GLOBALSTRINGS, "wb").write(data); print("extracted GlobalStrings.lua from", name); break
try:
    import lupa.lua51 as lupa_mod
    print("using Lua 5.1")
except ImportError:
    import lupa as lupa_mod
    print("using default lupa Lua")

L = lupa_mod.LuaRuntime(unpack_returned_tuples=True)

STUBS = r"""
-- WoW API stubs
TEST = TEST or {}
TEST.class, TEST.talents, TEST.equipLoc = "WARRIOR", { 0, 0, 0 }, {}
function UnitClass(unit) return TEST.class:sub(1,1) .. TEST.class:sub(2):lower(), TEST.class end
function GetNumTalentTabs() return 3 end
function GetActiveTalentGroup() return 1 end
function GetTalentTabInfo(i) return "Tab" .. i, "icon", TEST.talents[i] or 0, "bg" end
TEST.itemInfo = {}   -- link -> { quality, ilvl }
function GetItemInfo(link)
    local loc = TEST.equipLoc[link or ""] or "INVTYPE_CHEST"
    local info = TEST.itemInfo[link or ""] or { 2, 10 }
    return "name", link, info[1], info[2], 1, "Armor", "Cloth", 1, loc, "", 0
end
local frames = {}
TEST.frames = frames
DEFAULT_CHAT_FRAME = { AddMessage = function(self, m) print((m:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))) end }
SlashCmdList = {}
UIParent = {}
TEST.equipped = {}   -- inventory slot -> { link = , lines = { {text, color, right}, ... } }
function GetInventoryItemLink(unit, slot) local e = TEST.equipped[slot]; return e and e.link or nil end
TEST.bags = {}       -- bag -> slot -> { link = , lines = }
function GetContainerItemLink(bag, slot) local e = TEST.bags[bag] and TEST.bags[bag][slot]; return e and e.link or nil end
TEST.hooked = {}
function hooksecurefunc(name, fn) TEST.hooked[name] = fn end
UISpecialFrames = {}
function tinsert(t, v) t[#t + 1] = v end
function CreateFrame(kind, name, parent, template)
    if kind == "GameTooltip" then
        local tip = TEST.MakeTooltip(name, {}, nil)
        tip.SetOwner = function() end
        tip.ClearLines = function(self) TEST.SetLines(self, {}, nil) end
        tip.SetBagItem = function(self, bag, slot)
            local e = TEST.bags[bag] and TEST.bags[bag][slot]
            if e then TEST.SetLines(self, e.lines, e.link); return true end
            TEST.SetLines(self, {}, nil); return false
        end
        tip.SetInventoryItem = function(self, unit, slot)
            local e = TEST.equipped[slot]
            if e then TEST.SetLines(self, e.lines, e.link); return true end
            TEST.SetLines(self, {}, nil); return false
        end
        return tip
    end
    local f = {}
    f.events = {}
    f.RegisterEvent = function(self, e) self.events[e] = true end; f.UnregisterEvent = function(self, e) self.events[e] = nil end
    f.SetScript = function(self, which, fn) if which == "OnEvent" then self.onEvent = fn else self.onUpdate = fn end end
    f.Show = function(self) self.shown = true end; f.Hide = function(self) self.shown = false end
    frames[#frames+1] = f; return f end
function TEST.Pump()   -- run one frame of OnUpdate on every shown frame
    for _, f in ipairs(frames) do if f.shown and f.onUpdate then f.onUpdate(f) end end
end

-- Fake tooltip builder
local function FS(text, color, shown)
    local rgb = ({ white={1,1,1}, green={0,1,0}, grey={0.5,0.5,0.5}, gold={1,0.82,0}, red={1,0.13,0.13}, odd={0,0.44,0.87} })[color]
    local fs = {}
    fs.GetText = function() return text end
    fs.SetText = function(self, t) text = t end
    fs.GetTextColor = function() return rgb[1], rgb[2], rgb[3] end
    fs.IsShown = function() return shown ~= false end
    return fs
end
function TEST.SetLines(tip, lines, link)
    local name = tip.name
    tip.lines, tip.link, tip.added = lines, link, {}
    tip.NumLines = function() return #tip.lines end
    tip.GetItem = function() return "Test Item", tip.link end
    for i = 1, 60 do _G[name .. "TextLeft" .. i] = nil; _G[name .. "TextRight" .. i] = nil end
    for i, l in ipairs(lines) do
        _G[name .. "TextLeft" .. i]  = FS(l[1], l[2] or "white")
        _G[name .. "TextRight" .. i] = l[3] and FS(l[3], "white") or FS(nil, "white", false)
    end
end
function TEST.MakeTooltip(name, lines, link)
    local tip = { name = name, added = {} }
    tip.GetName = function() return name end
    TEST.SetLines(tip, lines, link)
    tip.AddLine = function(self, t)
        self.added[#self.added+1] = t
        self.lines[#self.lines+1] = { t, "white" }
        _G[name .. "TextLeft" .. #self.lines] = FS(t, "white"); _G[name .. "TextRight" .. #self.lines] = FS(nil, "white", false)
    end
    tip.Show = function() end
    tip.HookScript = function(self, _, fn) self.hook = fn end
    return tip
end
GameTooltip = TEST.MakeTooltip("GameTooltip", {}, nil)
ItemRefTooltip = TEST.MakeTooltip("ItemRefTooltip", {}, nil)
"""
L.execute(open(GLOBALSTRINGS, encoding="utf-8", errors="replace").read())
L.execute(STUBS)

for f in ["GearRater_Enchants.lua", "GearRater_Weights.lua", "GearRater_Score.lua", "GearRater_Budget.lua", "GearRater_Compare.lua", "GearRater_Bags.lua", "GearRater_Import.lua"]:
    L.execute(open(os.path.join(HERE, "..", f), encoding="utf-8").read())
L.execute(open(ADDON, encoding="utf-8").read())
# fire ADDON_LOADED
L.execute("GearRaterDB = { chat = true, tooltip = true }")
L.execute('for _, f in ipairs(TEST.frames) do if f.events.ADDON_LOADED then f.onEvent(f, "ADDON_LOADED", "GearRater") end end')

CASES = r"""
local function run(title, lines, link)
    print("\n== " .. title)
    local tip = GameTooltip
    TEST.SetLines(tip, lines, link)
    tip.hook(tip)
    for _, a in ipairs(tip.added) do print("  TIP> " .. (a:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))) end
    print("  -- chat after pump:")
    TEST.Pump()
    return GearRater.ScanTooltip(tip)
end

local r1 = run("Plate legs with module enchants", {
    {"Sanctified Scourgelord Legplates", "gold"}, {"Heroic", "white"}, {"Binds when picked up"},
    {"Legs", "white", "Plate"}, {"2250 Armor"}, {"+150 Strength"}, {"+200 Stamina"},
    {"Red Socket"}, {"Yellow Socket"}, {"Socket Bonus: +8 Strength", "grey"},
    {"Durability 165 / 165"}, {"Requires Level 80"}, {"Item Level 264"},
    {"Equip: Improves hit rating by 70."}, {"Equip: Increases your armor penetration rating by 100."},
    {"+24 Stamina", "green"}, {"Equip: Increases attack power by 60.", "green"}, {"+20 Spell Power", "green"},
    {"Equip: Increases attack power by 42 in Cat, Bear, Dire Bear, and Moonkin forms only.", "green"},
    {"Equip: Your melee attacks have a chance to grant 300 strength for 10 sec.", "green"},
    {"Use: Something fun. (2 Min Cooldown)", "green"},
    {"Set: Decreases cooldown.", "grey"},
    {"GR 3 stats", "white"},   -- our own stale line should be skipped
}, "|cffa335ee|Hitem:51205:3834:3621:0:0:0:0:1234567890:80|h[Sanctified Scourgelord Legplates]|h|r")
assert(r1.stats.STRENGTH.total == 150, "str")
assert(r1.stats.STAMINA.total == 224 and r1.stats.STAMINA.ench == 24, "sta")
assert(r1.stats.HIT_RATING.total == 70, "hit")
assert(r1.stats.ARMOR_PENETRATION_RATING.total == 100, "arp")
assert(r1.stats.ATTACK_POWER.total == 60, "ap")
assert(r1.stats.FERAL_ATTACK_POWER.total == 42, "feral")
assert(r1.stats.SPELL_POWER.total == 20, "sp")
assert(r1.stats.ARMOR.total == 2250, "armor")
assert(r1.stats.SOCKETS.total == 2, "sockets")
assert(#r1.unparsed == 2, "unparsed count " .. #r1.unparsed)

local r2 = run("Two-hand weapon with active socket bonus", {
    {"Shadowmourne", "gold"}, {"Binds when picked up"}, {"Two-Hand", "white", "Axe"},
    {"793 - 1183 Damage", "white", "Speed 3.70"}, {"(267.0 damage per second)"},
    {"+223 Strength"}, {"+198 Stamina"}, {"Red Socket"}, {"Socket Bonus: +8 Strength", "white"},
    {"Equip: Improves critical strike rating by 114."}, {"Equip: Increases your expertise rating by 114."},
    {"+20 Fire Resistance"}, {"Equip: Restores 10 mana per 5 sec.", "green"},
    {"Chance on hit: Does a thing.", "white"},
})
assert(r2.stats.DAMAGE_MIN.total == 793 and r2.stats.DAMAGE_MAX.total == 1183, "dmg")
assert(r2.stats.SPEED.total == 3.7, "speed")
assert(math.abs(r2.stats.DPS.total - 267.0) < 0.01, "dps")
assert(r2.stats.STRENGTH.total == 231 and r2.stats.STRENGTH.ench == 8, "socket bonus")
assert(r2.stats.CRIT_RATING.total == 114 and r2.stats.EXPERTISE_RATING.total == 114, "ratings")
assert(r2.stats.RESISTANCE_FIRE and r2.stats.RESISTANCE_FIRE.total == 20, "resist")
assert(r2.stats.MANA_REGENERATION.total == 10, "mp5")
assert(#r2.unparsed == 1, "proc unparsed")

local r3 = run("Shield", {
    {"Bulwark", "gold"}, {"Off Hand", "white", "Shield"}, {"8000 Armor"}, {"250 Block"}, {"+50 Stamina"},
    {"Equip: Increases defense rating by 40."}, {"Equip: Increases the block value of your shield by 60."},
})
assert(r3.stats.BLOCK_VALUE.total == 310, "block value base+equip")
assert(r3.stats.DEFENSE_SKILL_RATING.total == 40, "def")

print("\nALL ASSERTIONS PASSED")
"""
L.execute(CASES)
L.execute(open("doublefire.lua", encoding="utf-8").read())
L.execute(open("captured.lua", encoding="utf-8").read())
L.execute(open("captured2.lua", encoding="utf-8").read())
L.execute(open("captured3.lua", encoding="utf-8").read())
L.execute(open("scoring.lua", encoding="utf-8").read())
L.execute(open("budget.lua", encoding="utf-8").read())
L.execute(open("compare.lua", encoding="utf-8").read())
L.execute(open("step5.lua", encoding="utf-8").read())
