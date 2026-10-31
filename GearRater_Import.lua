-- GearRater Pawn scale import/export.
--   ( Pawn: v1: "Scale Name": Strength=2.3, Agility=0.7, HitRating=1.9, ... )
-- Imported scales become manual profiles for the current class ("Import: Scale Name"),
-- saved in GearRaterDB.imported and selectable with /gr spec.

GearRater = GearRater or {}
local GR = GearRater

-- Pawn v1 stat names (lower case) -> GearRater keys. Several Pawn names fold into one key.
local PAWN = {
    strength = "STRENGTH", agility = "AGILITY", stamina = "STAMINA", intellect = "INTELLECT", spirit = "SPIRIT",
    armor = "ARMOR", health = "HEALTH", mana = "MANA",
    ap = "ATTACK_POWER", rap = "RANGED_ATTACK_POWER", feralap = "FERAL_ATTACK_POWER",
    spellpower = "SPELL_POWER", spelldamage = "SPELL_DAMAGE_DONE", healing = "SPELL_HEALING_DONE",
    hitrating = "HIT_RATING", critrating = "CRIT_RATING", hasterating = "HASTE_RATING",
    expertiserating = "EXPERTISE_RATING", armorpenetration = "ARMOR_PENETRATION_RATING",
    defenserating = "DEFENSE_SKILL_RATING", dodgerating = "DODGE_RATING", parryrating = "PARRY_RATING",
    blockrating = "BLOCK_RATING", blockvalue = "BLOCK_VALUE", resiliencerating = "RESILIENCE_RATING",
    spellpenetration = "SPELL_PENETRATION", mp5 = "MANA_REGENERATION", hp5 = "HEALTH_REGEN",
    allresist = "ALL_RESISTANCES",
    dps = "DPS_MELEE", meleedps = "DPS_MELEE", mainhanddps = "DPS_MELEE", offhanddps = "DPS_MELEE",
    onehanddps = "DPS_MELEE", twohanddps = "DPS_MELEE", rangeddps = "DPS_RANGED",
    redsocket = "SOCKETS", yellowsocket = "SOCKETS", bluesocket = "SOCKETS", prismaticsocket = "SOCKETS",
}
local PAWN_RESIST = { fireresist = true, frostresist = true, shadowresist = true, natureresist = true, arcaneresist = true }
local PAWN_SCHOOL = { firespelldamage = "FIRE", frostspelldamage = "FROST", arcanespelldamage = "ARCANE",
                      shadowspelldamage = "SHADOW", naturespelldamage = "NATURE", holyspelldamage = "HOLY" }
-- reverse map for export (first Pawn name wins)
local KEY_TO_PAWN = {}
for pawnName, key in pairs(PAWN) do
    if not KEY_TO_PAWN[key] or #pawnName < #KEY_TO_PAWN[key] then KEY_TO_PAWN[key] = pawnName end
end
KEY_TO_PAWN.DPS_MELEE, KEY_TO_PAWN.DPS_RANGED, KEY_TO_PAWN.SOCKETS = "MeleeDps", "RangedDps", "RedSocket"
local PAWN_CASE = { strength = "Strength", agility = "Agility", stamina = "Stamina", intellect = "Intellect", spirit = "Spirit",
    armor = "Armor", health = "Health", mana = "Mana", ap = "Ap", rap = "Rap", feralap = "FeralAp", spellpower = "SpellPower",
    spelldamage = "SpellDamage", healing = "Healing", hitrating = "HitRating", critrating = "CritRating", hasterating = "HasteRating",
    expertiserating = "ExpertiseRating", armorpenetration = "ArmorPenetration", defenserating = "DefenseRating",
    dodgerating = "DodgeRating", parryrating = "ParryRating", blockrating = "BlockRating", blockvalue = "BlockValue",
    resiliencerating = "ResilienceRating", spellpenetration = "SpellPenetration", mp5 = "Mp5", hp5 = "Hp5", allresist = "AllResist" }

-- Parse a Pawn string. Returns name, { pawnName(lower) = number }, or nil + error.
function GR.ParsePawnScale(str)
    if type(str) ~= "string" then return nil, "no text" end
    local name, body = str:match('%(%s*[Pp]awn%s*:%s*v1%s*:%s*"([^"]*)"%s*:%s*(.-)%s*%)%s*$')
    if not name then return nil, "not a Pawn v1 scale string" end
    local values, count = {}, 0
    for pair in body:gmatch("[^,]+") do
        local k, v = pair:match("^%s*([%w_]+)%s*=%s*(%-?[%d%.]+)%s*$")
        if k and tonumber(v) then
            values[k:lower()] = tonumber(v)
            count = count + 1
        elseif pair:match("%S") then
            return nil, "cannot read '" .. pair:gsub("^%s+", ""):gsub("%s+$", "") .. "'"
        end
    end
    if count == 0 then return nil, "scale has no stats" end
    return name, values
end

-- Build a profile table from parsed Pawn values. Returns profile, unknown-name list.
function GR.ProfileFromPawn(name, values, class)
    local weights, schools, unknown = {}, {}, {}
    local resistSum, resistN, socketSum, socketN = 0, 0, 0, 0
    for pawnName, v in pairs(values) do
        local key = PAWN[pawnName]
        if key == "SOCKETS" then
            socketSum, socketN = socketSum + v, socketN + 1
        elseif key then
            if key == "DPS_MELEE" or key == "DPS_RANGED" then
                weights[key] = math.max(weights[key] or 0, v)
            else
                weights[key] = v
            end
        elseif PAWN_RESIST[pawnName] then
            resistSum, resistN = resistSum + v, resistN + 1
        elseif PAWN_SCHOOL[pawnName] then
            schools[PAWN_SCHOOL[pawnName]] = v
        elseif pawnName ~= "metasocket" and not pawnName:match("^is") then
            unknown[#unknown + 1] = pawnName
        end
    end
    if resistN > 0 then weights.RESISTANCE = resistSum / resistN end
    if socketN > 0 then weights.SOCKETS = socketSum / socketN end

    -- school damage is a fraction of the spell power weight
    local sp = weights.SPELL_POWER or weights.SPELL_DAMAGE_DONE or 0
    local hasSchools = false
    for school, v in pairs(schools) do
        schools[school] = sp > 0 and (v / sp) or 1
        hasSchools = true
    end
    if sp > 0 and not weights.SPELL_POWER then weights.SPELL_POWER = sp end

    local ap = (weights.ATTACK_POWER or 0) + (weights.DPS_MELEE or 0)
    local rap = (weights.RANGED_ATTACK_POWER or 0) + (weights.DPS_RANGED or 0)
    local attack = (sp > ap and sp > rap) and "spell" or (rap > ap and "ranged" or "melee")

    local profile = { name = "Import: " .. name, class = class, attack = attack, manual = true, imported = true,
                      weights = weights, schools = hasSchools and schools or nil }
    table.sort(unknown)
    return profile, unknown
end

-- Pawn string for a profile (its effective weights).
function GR.ExportPawn(profile)
    local w = GR.GetWeights(profile)
    local parts, keys = {}, {}
    for k in pairs(w) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do
        local v = w[k]
        if v and v ~= 0 then
            local pawnName = KEY_TO_PAWN[k]
            if pawnName then
                parts[#parts + 1] = (PAWN_CASE[pawnName] or pawnName) .. "=" .. (math.floor(v * 1000 + 0.5) / 1000)
            end
        end
    end
    if profile.schools and w.SPELL_POWER then
        for school, frac in pairs(profile.schools) do
            local pawnName = school:sub(1, 1) .. school:sub(2):lower() .. "SpellDamage"
            parts[#parts + 1] = pawnName .. "=" .. (math.floor(w.SPELL_POWER * frac * 1000 + 0.5) / 1000)
        end
    end
    local name = profile.name:gsub("^Import: ", "")
    return '( Pawn: v1: "' .. name .. '": ' .. table.concat(parts, ", ") .. " )"
end

-- Register saved imports as profiles (called at load and after an import).
function GR.RegisterImported()
    GearRaterDB.imported = GearRaterDB.imported or {}
    for name, p in pairs(GearRaterDB.imported) do
        p.name = name
        GR.Profiles[name] = p
    end
end

-- Import a string for the player's class. Returns profile or nil + error.
function GR.ImportPawn(str)
    local name, values = GR.ParsePawnScale(str)
    if not name then return nil, values end
    local _, class = UnitClass("player")
    local profile, unknown = GR.ProfileFromPawn(name, values, class)
    GearRaterDB.imported = GearRaterDB.imported or {}
    GearRaterDB.imported[profile.name] = profile
    GR.RegisterImported()
    if GR.InvalidateEquipped then GR.InvalidateEquipped() end
    return profile, unknown
end

-------------------------------------------------------------------------------
-- Paste window (chat input is limited to 255 characters; Pawn strings are longer)
-------------------------------------------------------------------------------

local frame
local function BuildFrame()
    if frame then return frame end
    frame = CreateFrame("Frame", "GearRaterImportFrame", UIParent)
    frame:SetWidth(480); frame:SetHeight(230)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                        tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 } })
    frame:EnableMouse(true); frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    tinsert(UISpecialFrames, "GearRaterImportFrame")

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.title:SetPoint("TOP", 0, -16)

    local scroll = CreateFrame("ScrollFrame", "GearRaterImportScroll", frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 20, -40); scroll:SetPoint("BOTTOMRIGHT", -40, 50)
    local edit = CreateFrame("EditBox", "GearRaterImportEdit", scroll)
    edit:SetMultiLine(true); edit:SetAutoFocus(false); edit:SetMaxLetters(8000)
    edit:SetFontObject(ChatFontNormal)
    edit:SetWidth(400); edit:SetHeight(120)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    scroll:SetScrollChild(edit)
    frame.edit = edit

    frame.status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.status:SetPoint("BOTTOMLEFT", 20, 22); frame.status:SetPoint("BOTTOMRIGHT", -140, 22)
    frame.status:SetJustifyH("LEFT")

    local close = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    close:SetWidth(60); close:SetHeight(22); close:SetPoint("BOTTOMRIGHT", -16, 16); close:SetText("Close")
    close:SetScript("OnClick", function() frame:Hide() end)

    local action = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    action:SetWidth(70); action:SetHeight(22); action:SetPoint("RIGHT", close, "LEFT", -6, 0); action:SetText("Import")
    action:SetScript("OnClick", function()
        local profile, info = GR.ImportPawn(edit:GetText())
        if profile then
            frame.status:SetText("Imported '" .. profile.name .. "' (" .. profile.attack .. ")"
                .. (#info > 0 and ("; unknown: " .. table.concat(info, ", ")) or "") .. ". Use /gr spec to select it.")
        else
            frame.status:SetText("|cffff4040" .. tostring(info) .. "|r")
        end
    end)
    frame.action = action
    return frame
end

function GR.ShowImportFrame(text, title)
    local f = BuildFrame()
    f.title:SetText(title or "GearRater: paste a Pawn scale string and press Import")
    f.status:SetText("")
    f.edit:SetText(text or "")
    f:Show()
    f.edit:SetFocus()
    if text and text ~= "" then f.edit:HighlightText() end
end
