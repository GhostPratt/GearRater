-- GearRater: step 1 - tooltip stat scanner.
-- WoW 3.3.5a (Interface 30300).
--
-- Reads every item tooltip line, pulls each stat out using the client's own
-- ITEM_MOD_* global strings (so it is locale safe and catches base stats, random
-- suffix stats, enchant text and "Equip:" ratings alike), and reports what it found
-- in the tooltip and/or chat. Later steps will weight the stats per class/spec.

local ADDON_NAME = "GearRater"
local PARSER_VERSION = 4        -- bump when parsing changes; saved diagnostics are reset
local TAG        = "|cff66ccffGR|r"           -- marks our own tooltip lines
local CHAT_TAG   = "|cff66ccffGearRater:|r "

local GREEN, GREY, GOLD, WHITE, RED = "|cff33ff33", "|cff9d9d9d", "|cffffd100", "|cffffffff", "|cffff4040"

local defaults = { chat = false, tooltip = false, score = true, ilvl = true, compare = true, bags = true, talents = true, caps = true }
GearRaterDB = GearRaterDB or {}

local function Print(msg) DEFAULT_CHAT_FRAME:AddMessage(CHAT_TAG .. msg) end

-------------------------------------------------------------------------------
-- Pattern building from global strings
-------------------------------------------------------------------------------

local MAGIC = "([%(%)%.%%%+%-%*%?%[%]%^%$])"

-- Turn a format string such as "%c%d Stamina" or "Equip: Improves hit rating by %d."
-- into a Lua pattern. Returns pattern and the index of the number capture.
local function ToPattern(fmt, anchorEnd)
    fmt = fmt:gsub("%%%%", "\4")                         -- literal percent sign
    fmt = fmt:gsub("%%c%%d", "\1")                       -- signed integer
    fmt = fmt:gsub("%%%d*%$?%d*%.?%d*([dsf])", function(t) -- %d %s %.1f %2$s ...
        if t == "d" then return "\2" elseif t == "f" then return "\5" else return "\3" end
    end)
    fmt = fmt:gsub("%.$", "")                            -- drop trailing full stop; be lenient
    fmt = fmt:gsub(MAGIC, "%%%1")

    local numIndex, n = nil, 0
    local out = fmt:gsub("[\1\2\3\5]", function(c)
        n = n + 1
        if c == "\1" then numIndex = numIndex or n; return "([%+%-]%d+)" end
        if c == "\2" then numIndex = numIndex or n; return "(%d+)" end
        if c == "\5" then numIndex = numIndex or n; return "([%d%.]+)" end
        return "(.-)"
    end)
    out = out:gsub("\4", "%%%%")
    if not numIndex then return nil end
    return "^" .. out .. (anchorEnd and "$" or ""), numIndex
end

local statPatterns = {}   -- { pat=, key=, numIndex=, len= }  sorted longest format first
local shortNames   = {}   -- lower(short name) -> key
local prettyName   = {}   -- key -> display name

local function AddPattern(fmt, key, anchorEnd)
    local pat, numIndex = ToPattern(fmt, anchorEnd)
    if pat then
        statPatterns[#statPatterns + 1] = { pat = pat, key = key, numIndex = numIndex, len = #fmt }
    end
end

local function TitleCase(s)
    return (s:lower():gsub("_", " "):gsub("(%a)(%w*)", function(a, b) return a:upper() .. b end))
end

local function Prettify(key)
    local short = _G["ITEM_MOD_" .. key .. "_SHORT"]
    if short then return short end
    local school = key:match("^RESISTANCE_(%a+)$")
    if school then return TitleCase(school) .. " Resistance" end
    school = key:match("^SPELL_DAMAGE_(%a+)$")
    if school and key ~= "SPELL_DAMAGE_DONE" then return TitleCase(school) .. " Spell Damage" end
    local family = key:match("^SLAYER_(%a+)$")
    if family then return TitleCase(family) .. " Slayer" end
    return TitleCase(key)
end

local function BuildPatterns()
    for name, value in pairs(_G) do
        if type(name) == "string" and type(value) == "string" then
            local key = name:match("^ITEM_MOD_(.+)$")
            if key then
                if key:sub(-6) == "_SHORT" then
                    shortNames[value:lower()] = key:sub(1, -7)
                elseif value:find("%%c%%d") or value:find("%%d") then
                    AddPattern(value, key, false)
                end
            end
        end
    end
    -- Non ITEM_MOD templates worth capturing.
    if ARMOR_TEMPLATE        then AddPattern(ARMOR_TEMPLATE,        "ARMOR",       true) end
    if SHIELD_BLOCK_TEMPLATE then AddPattern(SHIELD_BLOCK_TEMPLATE, "BLOCK_VALUE", true) end
    if DPS_TEMPLATE          then AddPattern((DPS_TEMPLATE:gsub("%%s", "%%.1f")), "DPS", true) end
    if ITEM_RESIST_SINGLE    then AddPattern(ITEM_RESIST_SINGLE,    "RESISTANCE",  true) end
    if ITEM_RESIST_ALL       then AddPattern(ITEM_RESIST_ALL,       "ALL_RESISTANCES", true) end

    -- Enchantment descriptions (SpellItemEnchantment) use phrases that have no ITEM_MOD
    -- global. These only apply when no _SHORT name matched. enUS wording.
    local extra = {
        [(ARMOR or "Armor"):lower()] = "ARMOR",       -- "+20 Armor" (base line is "%d Armor", unsigned)
        ["all resistances"]          = "ALL_RESISTANCES",
        ["damage"]                   = "WEAPON_DAMAGE",
        ["weapon damage"]            = "WEAPON_DAMAGE",
        ["spell damage and healing"] = "SPELL_POWER",
        ["healing and spell damage"] = "SPELL_POWER",
        ["spell damage"]             = "SPELL_POWER",
        ["healing spells"]           = "SPELL_HEALING_DONE",
        ["healing"]                  = "SPELL_HEALING_DONE",
        ["defense"]                  = "DEFENSE_SKILL_RATING",
        ["dodge"]                    = "DODGE_RATING",
        ["parry"]                    = "PARRY_RATING",
        ["block"]                    = "BLOCK_RATING",
        ["block value"]              = "BLOCK_VALUE",
        ["mana every 5 seconds"]     = "POWER_REGEN0",
        ["mana per 5 sec."]          = "POWER_REGEN0",
        ["mana per 5 sec"]           = "POWER_REGEN0",
        ["health every 5 seconds"]   = "HEALTH_REGEN",
        ["fishing"]                  = "FISHING",
        ["mining"]                   = "MINING",
        ["herbalism"]                = "HERBALISM",
        ["skinning"]                 = "SKINNING",
    }
    for phrase, key in pairs(extra) do
        if not shortNames[phrase] then shortNames[phrase] = key end
    end

    table.sort(statPatterns, function(a, b) return a.len > b.len end)
    for _, p in ipairs(statPatterns) do prettyName[p.key] = prettyName[p.key] or Prettify(p.key) end
    prettyName.ARMOR       = ARMOR or "Armor"
    prettyName.BLOCK_VALUE = prettyName.BLOCK_VALUE or "Block Value"
    prettyName.DPS         = "DPS"
    prettyName.RESISTANCE  = "Resistance"
    prettyName.ALL_RESISTANCES = "All Resistances"
    prettyName.WEAPON_DAMAGE   = "Weapon Damage"
    prettyName.FISHING, prettyName.MINING, prettyName.HERBALISM, prettyName.SKINNING = "Fishing", "Mining", "Herbalism", "Skinning"
    for _, key in pairs(shortNames) do prettyName[key] = prettyName[key] or Prettify(key) end
    prettyName.DAMAGE_MIN  = "Min Damage"
    prettyName.DAMAGE_MAX  = "Max Damage"
    prettyName.SPEED       = "Speed"
    prettyName.SOCKETS     = "Sockets"
end

local function TemplateToPattern(tpl, capture)
    return "^" .. tpl:gsub(MAGIC, "%%%1"):gsub("%%%%s", capture) .. "$"
end

-- Weapon damage line: "123 - 456 Damage" (DAMAGE_TEMPLATE = "%d - %d Damage"); both numbers captured in order.
local damagePattern      = DAMAGE_TEMPLATE and (ToPattern(DAMAGE_TEMPLATE, true))
local socketBonusPattern = ITEM_SOCKET_BONUS and TemplateToPattern(ITEM_SOCKET_BONUS, "(.+)")
local genericPattern     = "^([%+%-]%d+) (.+)$"   -- "+15 Spell Power" style (enchant text, socket bonuses)
local schoolDamagePattern = "^([%+%-]%d+) (%a+) Spell Damage$"   -- "+10 Arcane Spell Damage" (enUS enchant text)
local slayerPatterns = { "^([%+%-]%d+) (%a+) [Ss]layer$", "^([%+%-]%d+) (%a+) ?[Ss]laying$" }  -- "+6 Elemental Slayer", "+2 Beast Slaying"

-- Exact-text lookup of the server module's enchant pool (GearRater_Enchants.lua), keyed by
-- description. Resolved from the client DBCs, so multi-stat and proc enchants are exact.
local enchantByText = {}
local function BuildEnchantIndex()
    for id, e in pairs(GearRater and GearRater.Enchants or {}) do
        local desc = e[1]
        if desc and desc ~= "" then
            local stats = {}
            for i = 3, #e do stats[#stats + 1] = e[i] end
            local prev = enchantByText[desc]
            -- Same text can belong to several ids; keep the one with stats, prefer first otherwise.
            if not prev or (#prev.stats == 0 and #stats > 0) then
                enchantByText[desc] = { id = id, stats = stats }
            end
        end
    end
end


local socketNames = {}
for _, g in ipairs({ "EMPTY_SOCKET_RED", "EMPTY_SOCKET_BLUE", "EMPTY_SOCKET_YELLOW", "EMPTY_SOCKET_META", "EMPTY_SOCKET_PRISMATIC" }) do
    if _G[g] then socketNames[_G[g]] = true end
end
local onUsePrefix   = ITEM_SPELL_TRIGGER_ONUSE
local onProcPrefix  = ITEM_SPELL_TRIGGER_ONPROC
local onEquipPrefix = ITEM_SPELL_TRIGGER_ONEQUIP

-------------------------------------------------------------------------------
-- Line classification and parsing
-------------------------------------------------------------------------------

local function LineColor(fs)
    local r, g, b = fs:GetTextColor()
    if r > 0.9 and g > 0.9 and b > 0.9 then return "white" end
    if g > 0.9 and r < 0.3 and b < 0.3 then return "green" end
    if math.abs(r - g) < 0.05 and math.abs(g - b) < 0.05 and r > 0.4 and r < 0.7 then return "grey" end
    if r > 0.9 and g < 0.3 and b < 0.3 then return "red" end
    return string.format("other(%.2f,%.2f,%.2f)", r, g, b)
end

-- Strip inline colour codes ("|cffffffff+10 Intellect|r"), which the client uses for
-- enchantment text beyond the first few slots.
local function CleanText(text)
    return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function StartsWith(text, prefix)
    return prefix and prefix ~= "" and text:sub(1, #prefix) == prefix
end

-- Try to parse one stat sentence. Returns key, value or nil.
local function ParseStat(text)
    -- ITEM_MOD sentences have no "Equip:" in the global string; the tooltip adds it.
    if StartsWith(text, onEquipPrefix) then
        text = text:sub(#onEquipPrefix + 1):gsub("^%s+", "")
    end
    for _, p in ipairs(statPatterns) do
        local caps = { text:match(p.pat) }
        if caps[1] then
            local v = tonumber(caps[p.numIndex])
            if v then
                if p.key == "RESISTANCE" then
                    -- "%c%d %s Resistance": key by school so it matches the enchant data file
                    for i, c in ipairs(caps) do
                        if i ~= p.numIndex then return "RESISTANCE_" .. c:upper(), v end
                    end
                end
                return p.key, v
            end
        end
    end
    local sign, name = text:match(genericPattern)
    if sign then
        local key = shortNames[name:lower()]
        if key then return key, tonumber(sign) end
        local _, school = text:match(schoolDamagePattern)
        if school then
            key = "SPELL_DAMAGE_" .. school:upper()
            prettyName[key] = prettyName[key] or (school .. " Spell Damage")
            return key, tonumber(sign)
        end
        for _, pat in ipairs(slayerPatterns) do
            local _, family = text:match(pat)
            if family then
                key = "SLAYER_" .. family:upper()
                prettyName[key] = prettyName[key] or (family .. " Slayer")
                return key, tonumber(sign)
            end
        end
    end
    return nil
end

-- Parse one cleaned tooltip line into a list of {key, value} pairs.
-- Returns stats (possibly empty for a known non-stat enchant) and whether the line was recognised.
local function ParseLine(text)
    local e = enchantByText[text]
    if e then return e.stats, true, e.id end
    local key, value = ParseStat(text)
    if key then return { { key, value } }, true end
    return nil, false
end

local function Add(result, key, value, isEnch)
    local s = result.stats[key]
    if not s then
        s = { total = 0, base = 0, ench = 0 }
        result.stats[key] = s
        result.order[#result.order + 1] = key
    end
    s.total = s.total + value
    if isEnch then s.ench = s.ench + value else s.base = s.base + value end
end

-- Scan a tooltip frame. Returns a result table.
local function ScanTooltip(tip)
    local name = tip:GetName()
    local result = { stats = {}, order = {}, raw = {}, unparsed = {}, effects = {}, sockets = 0, ownLines = {} }
    for i = 1, tip:NumLines() do
        local left  = _G[name .. "TextLeft" .. i]
        local right = _G[name .. "TextRight" .. i]
        local rawText = left and left:GetText()
        if rawText and rawText:find(TAG, 1, true) then
            result.ownLines[#result.ownLines + 1] = i   -- lines we added on an earlier pass
        elseif rawText and not rawText:match("^%s*$") then
            local text  = CleanText(rawText)
            local color = LineColor(left)
            local rtext = right and right:IsShown() and right:GetText() or nil
            result.raw[#result.raw + 1] = { text = rawText, color = color, right = rtext }

            -- Base "Equip:" stat sentences are green on 3.3.5a; everything else that is
            -- not plain white is enchant-like: green "+N Stat" lines and the oddly
            -- coloured lines the client uses for extra enchantment slots.
            local isEnch = color ~= "white" and not StartsWith(text, onEquipPrefix)
            if socketNames[text] then
                result.sockets = result.sockets + 1          -- empty sockets render grey
            elseif color ~= "grey" and color ~= "red" then
                local stats, known = ParseLine(text)
                if known then
                    for _, pair in ipairs(stats) do Add(result, pair[1], pair[2], isEnch) end
                    if #stats == 0 then result.effects[#result.effects + 1] = text end
                elseif damagePattern and text:match(damagePattern) then
                    local lo, hi = text:match(damagePattern)
                    Add(result, "DAMAGE_MIN", tonumber(lo), isEnch)
                    Add(result, "DAMAGE_MAX", tonumber(hi), isEnch)
                    local speed = rtext and rtext:match("([%d%.]+)")
                    if speed then Add(result, "SPEED", tonumber(speed), isEnch) end
                elseif socketBonusPattern and text:match(socketBonusPattern) then
                    local inner = text:match(socketBonusPattern)
                    local s2, known2 = ParseLine(inner)
                    if known2 then
                        for _, pair in ipairs(s2) do Add(result, pair[1], pair[2], true) end
                    else
                        result.unparsed[#result.unparsed + 1] = text
                    end
                elseif StartsWith(text, onEquipPrefix) or StartsWith(text, onUsePrefix)
                    or StartsWith(text, onProcPrefix) or (isEnch and text:match(genericPattern)) then
                    result.unparsed[#result.unparsed + 1] = text
                end
            end
        end
    end
    if result.sockets > 0 then Add(result, "SOCKETS", result.sockets, false) end
    return result
end

-------------------------------------------------------------------------------
-- Output
-------------------------------------------------------------------------------

local function FormatValue(v)
    if v == math.floor(v) then return tostring(v) end
    return string.format("%.1f", v)
end

local function StatLine(key, s)
    local str = GOLD .. (prettyName[key] or key) .. "|r " .. WHITE .. FormatValue(s.total) .. "|r"
    if s.ench ~= 0 and s.base ~= 0 then
        str = str .. GREY .. " (" .. FormatValue(s.base) .. " base " .. GREEN .. "+" .. FormatValue(s.ench) .. " ench" .. GREY .. ")|r"
    elseif s.ench ~= 0 then
        str = str .. GREEN .. " (ench)|r"
    end
    return str
end

local function LinkIds(link)
    if not link then return "no link" end
    local id, ench, g1, g2, g3, g4, suffix, unique = link:match("item:(%d+):(%-?%d+):(%-?%d+):(%-?%d+):(%-?%d+):(%-?%d+):(%-?%d+):(%-?%d+)")
    if not id then return "unrecognised link" end
    return string.format("id %s, enchant %s, gems %s/%s/%s/%s, suffix %s, unique %s", id, ench, g1, g2, g3, g4, suffix, unique)
end

local lastLink, lastResult, lastName, lastSignature

-- Stable text summary of a scan, used to avoid re-dumping identical results.
local function Signature(link, result)
    local parts = { link or "" }
    for _, key in ipairs(result.order) do parts[#parts + 1] = key .. "=" .. result.stats[key].total end
    return table.concat(parts, ";") .. "#" .. #result.unparsed
end

local function ScoreText(score)
    if not score or not score[1] then return nil end
    local total, _, profile, how = score[1], score[2], score[3], score[4]
    local howTag = how == "manual" and " (manual)" or how == "default" and " (no talents)" or ""
    return WHITE .. string.format("%.1f", total) .. "|r  " .. GREY .. "[" .. profile.name .. howTag .. "]|r"
end

local function DumpToChat(itemName, link, result, score, lvl, cmp)
    Print(GOLD .. (itemName or "?") .. "|r  " .. GREY .. LinkIds(link) .. "|r")
    local st = ScoreText(score)
    if st then Print("  Score: " .. st) end
    if cmp then Print("  Equipped: " .. CompareText(cmp)) end
    if lvl then Print("  Item Level: " .. LevelText(lvl)) end
    for _, key in ipairs(result.order) do
        Print("  " .. StatLine(key, result.stats[key]))
    end
    if #result.order == 0 then Print("  " .. GREY .. "no stats parsed|r") end
    for _, text in ipairs(result.effects) do
        Print("  " .. GREY .. "effect (no stat value): " .. text .. "|r")
    end
    for _, text in ipairs(result.unparsed) do
        Print("  " .. RED .. "unparsed:|r " .. text)
    end
end

local function DumpRaw(result)
    if not result then Print("nothing scanned yet"); return end
    Print(GOLD .. (lastName or "?") .. "|r raw tooltip lines:")
    for i, line in ipairs(result.raw) do
        local c = line.color == "green" and GREEN or line.color == "grey" and GREY or line.color == "white" and WHITE or GOLD
        Print(string.format("  %2d %s[%s]|r %s%s", i, c, line.color, CleanText(line.text),
            line.right and (GREY .. "  |  " .. line.right .. "|r") or ""))
    end
end

-- OnTooltipSetItem can fire more than once while a tooltip is being built, and the
-- first pass may not yet contain every line. The chat dump is therefore deferred to
-- the next frame so only the final, complete scan is printed.
local pending
local pump = CreateFrame("Frame")
pump:Hide()
pump:SetScript("OnUpdate", function(self)
    self:Hide()
    if not pending then return end
    local p = pending
    pending = nil
    local sig = Signature(p.link, p.result)
    if sig ~= lastSignature then
        lastSignature = sig
        DumpToChat(p.name, p.link, p.result, p.score, p.lvl, p.cmp)
    end
end)

local function LevelText(lvl)
    if not lvl then return nil end
    if math.abs(lvl.delta) < 0.5 then
        return WHITE .. lvl.ilvl .. "|r" .. GREY .. " (no enchant value)|r"
    end
    local sign = lvl.delta > 0 and "+" or ""
    return WHITE .. string.format("%.0f", lvl.effective) .. "|r" .. GREY .. string.format("  (base %d, %s%.0f from enchants)|r", lvl.ilvl, sign, lvl.delta)
end

local function CompareText(cmp)
    if not cmp then return nil end
    if cmp.isEquipped then return GREY .. "equipped|r" end
    local color = cmp.delta > 0.05 and GREEN or cmp.delta < -0.05 and RED or GREY
    local sign = cmp.delta > 0 and "+" or ""
    local pct = cmp.pct and string.format(" (%s%.0f%%)", cmp.pct > 0 and "+" or "", cmp.pct) or ""
    return color .. sign .. string.format("%.1f", cmp.delta) .. pct .. "|r" .. GREY .. "  vs " .. cmp.against .. "|r"
end

-- The lines we append to a tooltip: { text, r, g, b, wrap }.
local function BuildTooltipLines(result, score, lvl, cmp)
    local lines = {}
    local st = ScoreText(score)
    if GearRaterDB.score and st then
        lines[#lines + 1] = { TAG .. " Score: " .. st, 0.4, 0.8, 1 }
    end
    local ct = CompareText(cmp)
    if GearRaterDB.compare and ct then
        lines[#lines + 1] = { TAG .. " Equipped: " .. ct, 0.4, 0.8, 1 }
    end
    local lt = LevelText(lvl)
    if GearRaterDB.ilvl and lt then
        lines[#lines + 1] = { TAG .. " Item Level: " .. lt, 0.4, 0.8, 1 }
    end
    if GearRaterDB.tooltip then
        local header = TAG .. " " .. #result.order .. " stats"
            .. (#result.unparsed > 0 and (", " .. RED .. #result.unparsed .. " unparsed|r") or "")
        local parts = {}
        for _, key in ipairs(result.order) do
            local s = result.stats[key]
            parts[#parts + 1] = (prettyName[key] or key) .. " " .. FormatValue(s.total) .. (s.ench ~= 0 and GREEN .. "*|r" or "")
        end
        lines[#lines + 1] = { header, 0.4, 0.8, 1 }
        lines[#lines + 1] = { TAG .. " " .. (#parts > 0 and table.concat(parts, ", ") or GREY .. "no stats|r"), 0.8, 0.8, 0.8, true }
    end
    return lines
end

local function WriteTooltipLines(tip, result, score, lvl, cmp)
    local lines = BuildTooltipLines(result, score, lvl, cmp)
    if #lines == 0 then return end
    local own = result.ownLines
    if #own > 0 then
        -- Lines from an earlier pass are still on the tooltip; refresh them in place.
        local name = tip:GetName()
        for i, l in ipairs(lines) do
            local fs = own[i] and _G[name .. "TextLeft" .. own[i]]
            if fs then fs:SetText(l[1]) end
        end
    else
        tip:AddLine(" ")
        for _, l in ipairs(lines) do tip:AddLine(l[1], l[2], l[3], l[4], l[5]) end
    end
    tip:Show()
end

-- Record what the parser could not handle into SavedVariables so the raw text can be
-- inspected outside the game (WTF/Account/<acct>/SavedVariables/GearRater.lua).
local MAX_SAMPLES = 40
local function RecordUnparsed(itemName, link, result, force)
    GearRaterDB.unparsed = GearRaterDB.unparsed or {}
    GearRaterDB.samples  = GearRaterDB.samples  or {}
    for _, text in ipairs(result.unparsed) do
        GearRaterDB.unparsed[text] = (GearRaterDB.unparsed[text] or 0) + 1
    end
    if #result.unparsed > 0 or force then
        local count = 0
        for _ in pairs(GearRaterDB.samples) do count = count + 1 end
        if count < MAX_SAMPLES or GearRaterDB.samples[itemName] then
            local lines = {}
            for _, l in ipairs(result.raw) do
                lines[#lines + 1] = "[" .. l.color .. "] " .. l.text .. (l.right and ("  ||  " .. l.right) or "")
            end
            GearRaterDB.samples[itemName] = { link = link, lines = lines }
        end
    end
end

local lastScore, lastLevel, lastCompare

local function OnTooltipSetItem(tip)
    local itemName, link = tip:GetItem()
    if not itemName then return end
    local result = ScanTooltip(tip)

    -- Consumables and other non-equippable items legitimately have Use: lines; don't report them.
    local equipLoc = link and select(9, GetItemInfo(link))
    if equipLoc == "" then result.unparsed = {} end
    RecordUnparsed(itemName, link, result, false)

    local score = GearRater.Score and { GearRater.Score(result, link) } or nil
    if score and not score[1] then score = nil end
    local lvl = GearRater.EffectiveLevel and GearRater.EffectiveLevel(result, link) or nil
    local cmp = (score and GearRater.Compare) and GearRater.Compare(result, link, score[1]) or nil

    WriteTooltipLines(tip, result, score, lvl, cmp)

    lastName, lastLink, lastResult, lastScore, lastLevel, lastCompare = itemName, link, result, score, lvl, cmp
    if GearRaterDB.chat and tip == GameTooltip then
        pending = { name = itemName, link = link, result = result, score = score, lvl = lvl, cmp = cmp }
        pump:Show()
    end
end

local function PrintBreakdown()
    if not lastResult then Print("nothing scanned yet"); return end
    if not lastScore then Print("no score for " .. GOLD .. (lastName or "?") .. "|r (no profile)"); return end
    local total, parts, profile, how, equipLoc = lastScore[1], lastScore[2], lastScore[3], lastScore[4], lastScore[5]
    Print(GOLD .. (lastName or "?") .. "|r  " .. GREY .. (equipLoc or "?") .. "|r  profile " .. WHITE .. profile.name .. "|r (" .. how .. ")")
    for _, p in ipairs(parts) do
        Print(string.format("  %s%-28s|r %7s x %-5s = %s%.1f|r", GOLD, prettyName[p.key] or p.key, FormatValue(p.value),
            FormatValue(p.weight), WHITE, p.contribution))
    end
    local zero = {}
    for _, key in ipairs(lastResult.order) do
        local counted = false
        for _, p in ipairs(parts) do if p.key == key then counted = true end end
        if not counted then zero[#zero + 1] = prettyName[key] or key end
    end
    if #zero > 0 then Print("  " .. GREY .. "ignored (weight 0): " .. table.concat(zero, ", ") .. "|r") end
    local _, notes = GearRater.GetWeights(profile)
    for _, n in ipairs(notes or {}) do Print("  " .. GREY .. "talents: " .. n .. "|r") end
    Print("  Score: " .. ScoreText(lastScore))
    if lastCompare then
        Print("  Equipped: " .. CompareText(lastCompare)
            .. (lastCompare.isEquipped and "" or string.format("  %s(equipped score %.1f)|r", GREY, lastCompare.equippedScore)))
    end
    if lastLevel then
        local l = lastLevel
        Print(string.format("  Item Level: %s  %sbudget points base %.1f, total %.1f, quality %s, slot %s, x%.2f per point|r",
            LevelText(l), GREY, l.base, l.total, tostring(l.quality), tostring(l.equipLoc),
            (GearRater.Budget.slope[l.quality or 1] or 2) * (GearRater.Budget.slotDivisor[l.equipLoc] or 1)))
    end
end

local function HandleSpec(arg)
    if not GearRater.GetActiveProfile then Print("scoring not loaded"); return end
    local list = GearRater.ProfilesForClass()
    if GearRater.InvalidateEquipped then GearRater.InvalidateEquipped() end
    if arg == "auto" then
        GearRaterCharDB.profile = nil
    elseif arg then
        local chosen
        for i, name in ipairs(list) do
            if tostring(i) == arg or name:lower():find(arg, 1, true) then chosen = name; break end
        end
        if not chosen then Print("no profile matches '" .. arg .. "'"); return end
        GearRaterCharDB.profile = chosen
    end
    local profile, how = GearRater.GetActiveProfile()
    Print("active profile: " .. WHITE .. (profile and profile.name or "none") .. "|r (" .. how .. ")")
    for i, name in ipairs(list) do
        local p = GearRater.Profiles[name]
        Print(string.format("  %d. %s%s", i, name, p.imported and GREY .. "  (imported)|r" or p.manual and GREY .. "  (manual only)|r" or ""))
    end
    Print(GREY .. "/gr spec <number|name>  to override,  /gr spec auto  to follow talents|r")
end

local function HandleWeight(arg)
    if not GearRater.GetActiveProfile then Print("scoring not loaded"); return end
    local profile = GearRater.GetActiveProfile()
    if not profile then Print("no profile"); return end
    GearRaterDB.weights = GearRaterDB.weights or {}
    if GearRater.InvalidateEquipped then GearRater.InvalidateEquipped() end
    if arg == "reset" then
        GearRaterDB.weights[profile.name] = nil
        Print("custom weights for " .. profile.name .. " cleared")
        return
    end
    local stat, value = arg and arg:match("^(%S+)%s+(%-?[%d%.]+)$")
    if stat then
        stat = stat:upper()
        GearRaterDB.weights[profile.name] = GearRaterDB.weights[profile.name] or {}
        GearRaterDB.weights[profile.name][stat] = tonumber(value)
        Print(profile.name .. ": " .. stat .. " = " .. value)
        return
    end
    local base = GearRater.GetBaseWeights(profile)
    local w, notes = GearRater.GetWeights(profile)
    local custom = GearRaterDB.weights[profile.name] or {}
    local keys = {}
    for k in pairs(w) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return (w[a] or 0) > (w[b] or 0) end)
    Print("weights for " .. WHITE .. profile.name .. "|r" .. (next(custom) and GREY .. " (* = customised, ~ = talent adjusted)|r" or GREY .. " (~ = talent adjusted)|r"))
    for _, k in ipairs(keys) do
        local adj = base[k] ~= w[k] and string.format("  %s~ base %s|r", GREY, FormatValue(base[k] or 0)) or ""
        Print(string.format("  %-28s %s%s%s", k, FormatValue(w[k] or 0), custom[k] ~= nil and " *" or "", adj))
    end
    for _, n in ipairs(notes or {}) do Print("  " .. GREY .. "talents: " .. n .. "|r") end
    Print(GREY .. "/gr weight STAT value  to change,  /gr weight reset  to restore defaults|r")
end

local function HandleTalents(arg)
    if not GearRater.AdjustWeights then Print("talent module not loaded"); return end
    if arg == "off" or arg == "on" then
        GearRaterDB.talents = (arg == "on")
    elseif arg == "caps" then
        GearRaterDB.caps = not GearRaterDB.caps
    end
    if GearRater.InvalidateTalents then GearRater.InvalidateTalents() end
    if GearRater.InvalidateEquipped then GearRater.InvalidateEquipped() end
    local profile = GearRater.GetActiveProfile()
    Print("talent adjustments " .. (GearRaterDB.talents and "on" or "off") .. ", caps " .. (GearRaterDB.caps and "on" or "off")
        .. (profile and ("  profile " .. WHITE .. profile.name .. "|r") or ""))
    if profile then
        local _, notes = GearRater.GetWeights(profile)
        if #notes == 0 then Print("  " .. GREY .. "no talent or cap adjustments apply|r") end
        for _, n in ipairs(notes) do Print("  " .. n) end
    end
    Print(GREY .. "/gr talents on|off  toggle adjustments,  /gr talents caps  toggle hit/expertise/defense caps|r")
end

-------------------------------------------------------------------------------
-- Setup
-------------------------------------------------------------------------------

local function HookTooltip(tip)
    if tip and tip.HookScript then tip:HookScript("OnTooltipSetItem", OnTooltipSetItem) end
end

SLASH_GEARRATER1 = "/gr"
SLASH_GEARRATER2 = "/gearrater"
SlashCmdList.GEARRATER = function(msg)
    local raw = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    msg = raw:lower()
    if msg == "import" or msg:match("^import%s") then
        if not GearRater.ImportPawn then Print("import not loaded"); return end
        local text = raw:match("^%S+%s+(.+)$")
        if text then
            local profile, info = GearRater.ImportPawn(text)
            if profile then
                Print("imported " .. WHITE .. profile.name .. "|r (" .. profile.attack .. ")"
                    .. (#info > 0 and (GREY .. "; unknown stats: " .. table.concat(info, ", ") .. "|r") or "") .. ". /gr spec to select it.")
            else
                Print(RED .. tostring(info) .. "|r")
            end
        else
            GearRater.ShowImportFrame()
        end
    elseif msg == "export" then
        if not GearRater.ExportPawn then Print("export not loaded"); return end
        local profile = GearRater.GetActiveProfile()
        if not profile then Print("no profile"); return end
        GearRater.ShowImportFrame(GearRater.ExportPawn(profile), "GearRater: Pawn string for " .. profile.name .. " (Ctrl+C to copy)")
    elseif msg == "bags" then
        GearRaterDB.bags = not GearRaterDB.bags
        Print("bag overlays " .. (GearRaterDB.bags and "on" or "off"))
        if GearRater.RefreshBags then GearRater.RefreshBags() end
    elseif msg == "chat" then
        GearRaterDB.chat = not GearRaterDB.chat
        Print("chat dump " .. (GearRaterDB.chat and "on" or "off"))
    elseif msg == "tip" or msg == "tooltip" then
        GearRaterDB.tooltip = not GearRaterDB.tooltip
        Print("tooltip lines " .. (GearRaterDB.tooltip and "on" or "off"))
    elseif msg == "score" then
        GearRaterDB.score = not GearRaterDB.score
        Print("score line " .. (GearRaterDB.score and "on" or "off"))
    elseif msg == "ilvl" then
        GearRaterDB.ilvl = not GearRaterDB.ilvl
        Print("item level line " .. (GearRaterDB.ilvl and "on" or "off"))
    elseif msg == "compare" then
        GearRaterDB.compare = not GearRaterDB.compare
        Print("equipped comparison line " .. (GearRaterDB.compare and "on" or "off"))
    elseif msg == "why" then
        PrintBreakdown()
    elseif msg == "spec" or msg:match("^spec%s") then
        HandleSpec(msg:match("^spec%s+(.+)$"))
    elseif msg == "weight" or msg == "weights" or msg:match("^weights?%s") then
        HandleWeight(msg:match("^weights?%s+(.+)$"))
    elseif msg == "talents" or msg:match("^talents%s") then
        HandleTalents(msg:match("^talents%s+(.+)$"))
    elseif msg == "dump" then
        if lastResult then DumpToChat(lastName, lastLink, lastResult, lastScore, lastLevel, lastCompare) else Print("nothing scanned yet") end
    elseif msg == "raw" then
        DumpRaw(lastResult)
    elseif msg == "save" then
        if lastResult then
            RecordUnparsed(lastName, lastLink, lastResult, true)
            Print("saved raw lines of " .. GOLD .. (lastName or "?") .. "|r (written to SavedVariables on /reload or logout)")
        else
            Print("nothing scanned yet")
        end
    elseif msg == "clear" then
        GearRaterDB.unparsed, GearRaterDB.samples = {}, {}
        Print("cleared saved samples")
    elseif msg == "patterns" then
        Print(#statPatterns .. " stat patterns built from global strings")
        for _, p in ipairs(statPatterns) do Print("  " .. p.key .. "  " .. GREY .. p.pat .. "|r") end
    else
        Print("commands: /gr why | spec | weight | talents | import | export | bags | score | compare | ilvl | tip | chat | dump | raw | save | clear | patterns")
    end
end

-- Shared namespace for later files (weights, scoring) and for offline tests.
GearRater = GearRater or {}
GearRater.ScanTooltip   = ScanTooltip
GearRater.ParseStat     = ParseStat
GearRater.ParseLine     = ParseLine
GearRater.BuildPatterns = BuildPatterns
GearRater.statPatterns  = statPatterns
GearRater.prettyName    = prettyName

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, name)
    if name ~= ADDON_NAME then return end
    for k, v in pairs(defaults) do if GearRaterDB[k] == nil then GearRaterDB[k] = v end end
    if GearRaterDB.parserVersion ~= PARSER_VERSION then
        -- Stale diagnostics from an older parser would only confuse; start clean.
        GearRaterDB.unparsed, GearRaterDB.samples = {}, {}
        if (GearRaterDB.parserVersion or 0) < 4 then
            -- Step 1 diagnostics were on by default; scoring is the normal mode now.
            GearRaterDB.chat, GearRaterDB.tooltip = false, false
        end
        GearRaterDB.parserVersion = PARSER_VERSION
    end
    BuildPatterns()
    BuildEnchantIndex()
    if GearRater.RegisterImported then GearRater.RegisterImported() end
    HookTooltip(GameTooltip)
    HookTooltip(ItemRefTooltip)
    HookTooltip(ShoppingTooltip1)
    HookTooltip(ShoppingTooltip2)
    local profile, how
    if GearRater.GetActiveProfile then profile, how = GearRater.GetActiveProfile() end
    Print("loaded, " .. #statPatterns .. " stat patterns. Profile: " .. WHITE .. (profile and profile.name or "none") .. "|r ("
        .. (how or "?") .. "). /gr for options.")
    self:UnregisterEvent("ADDON_LOADED")
end)
