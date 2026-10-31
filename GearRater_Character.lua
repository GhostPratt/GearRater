-- GearRater character summary: total score of everything equipped, with average base and
-- effective item level, shown on the character sheet and via /gr char.

GearRater = GearRater or {}
local GR = GearRater

-- Inventory slots that count (shirt and tabard excluded), with their display names.
local SLOTS = {
    { 1, HEADSLOT }, { 2, NECKSLOT }, { 3, SHOULDERSLOT }, { 15, BACKSLOT }, { 5, CHESTSLOT },
    { 9, WRISTSLOT }, { 10, HANDSSLOT }, { 6, WAISTSLOT }, { 7, LEGSSLOT }, { 8, FEETSLOT },
    { 11, FINGER0SLOT }, { 12, FINGER1SLOT }, { 13, TRINKET0SLOT }, { 14, TRINKET1SLOT },
    { 16, MAINHANDSLOT }, { 17, SECONDARYHANDSLOT }, { 18, RANGEDSLOT },
}

-- Returns { total, count, avgIlvl, avgEff, profile, how, slots = { {slot, name, item, score, ilvl, eff} } }
function GR.CharacterSummary()
    local profile, how = GR.GetActiveProfile()
    local s = { total = 0, count = 0, avgIlvl = 0, avgEff = 0, profile = profile, how = how, slots = {} }
    if not profile then return s end
    local ilvlSum, effSum = 0, 0
    for _, def in ipairs(SLOTS) do
        local slot, name = def[1], def[2] or tostring(def[1])
        local e = GR.EquippedScore(slot)
        local row = { slot = slot, name = name }
        if not e.empty then
            row.item, row.score = e.name, e.score
            s.total = s.total + e.score
            if e.lvl then
                row.ilvl, row.eff = e.lvl.ilvl, e.lvl.effective
                s.count = s.count + 1
                ilvlSum, effSum = ilvlSum + e.lvl.ilvl, effSum + e.lvl.effective
            end
        end
        s.slots[#s.slots + 1] = row
    end
    if s.count > 0 then s.avgIlvl, s.avgEff = ilvlSum / s.count, effSum / s.count end
    return s
end

-------------------------------------------------------------------------------
-- Character sheet display
-------------------------------------------------------------------------------

local GREY, WHITE, GOLD, GREEN = "|cff9d9d9d", "|cffffffff", "|cffffd100", "|cff33ff33"
local panel

local function SummaryLines(s)
    local l1 = string.format("%sGear score|r %s%.0f|r", GOLD, WHITE, s.total)
    local l2
    if s.count > 0 then
        local gain = s.avgEff - s.avgIlvl
        l2 = string.format("%sItem level|r %s%.0f|r", GOLD, WHITE, s.avgIlvl)
        if math.abs(gain) >= 0.5 then
            l2 = l2 .. string.format(" %s(%.0f)|r", GREEN, s.avgEff)
        end
    else
        l2 = GREY .. "nothing equipped|r"
    end
    return l1, l2
end

local function ShowBreakdown(self)
    local s = GR.CharacterSummary()
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("GearRater: equipped gear", 0.4, 0.8, 1)
    GameTooltip:AddLine(string.format("Profile %s (%s)", s.profile and s.profile.name or "?", s.how or "?"), 0.6, 0.6, 0.6)
    for _, row in ipairs(s.slots) do
        if row.item then
            GameTooltip:AddDoubleLine(row.name .. ": " .. row.item,
                string.format("%.1f   ilvl %s", row.score, row.eff and string.format("%.0f", row.eff) or "?"), 1, 1, 1, 0.9, 0.9, 0.9)
        else
            GameTooltip:AddDoubleLine(row.name, "empty", 0.5, 0.5, 0.5, 0.5, 0.5, 0.5)
        end
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Total", string.format("%.1f", s.total), 1, 0.82, 0, 1, 1, 1)
    GameTooltip:Show()
end

local function BuildPanel()
    if panel or not PaperDollFrame or not CharacterModelFrame then return panel end
    panel = CreateFrame("Frame", "GearRaterCharacterPanel", PaperDollFrame)
    panel:SetWidth(140); panel:SetHeight(30)
    -- Free space on the model frame: the bottom is behind the stat panes, the top-left holds
    -- the rotate buttons and the right edge holds the resistance icons. Sit just below the
    -- rotate buttons on the left and draw above the paper doll artwork.
    local anchor = CharacterModelFrameRotateLeftButton or CharacterModelFrame
    if anchor == CharacterModelFrame then
        panel:SetPoint("TOPLEFT", CharacterModelFrame, "TOPLEFT", 8, -44)
    else
        panel:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 2, -4)
    end
    panel:SetFrameLevel((CharacterModelFrame:GetFrameLevel() or PaperDollFrame:GetFrameLevel() or 1) + 10)
    panel:EnableMouse(true)
    panel.line1 = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    panel.line1:SetPoint("TOPLEFT"); panel.line1:SetJustifyH("LEFT")
    panel.line2 = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    panel.line2:SetPoint("TOPLEFT", panel.line1, "BOTTOMLEFT", 0, -1); panel.line2:SetJustifyH("LEFT")
    panel:SetScript("OnEnter", ShowBreakdown)
    panel:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return panel
end

function GR.RefreshCharacter()
    if not GearRaterDB or GearRaterDB.sheet == false then
        if panel then panel:Hide() end
        return
    end
    if not PaperDollFrame or not PaperDollFrame:IsShown() then return end
    local p = BuildPanel()
    if not p then return end
    local l1, l2 = SummaryLines(GR.CharacterSummary())
    p.line1:SetText(l1); p.line2:SetText(l2)
    p:Show()
end

if PaperDollFrame and PaperDollFrame.HookScript then
    PaperDollFrame:HookScript("OnShow", GR.RefreshCharacter)
end

-- Any change to the equipped baseline changes the total.
local origInvalidate = GR.InvalidateEquipped
GR.InvalidateEquipped = function()
    if origInvalidate then origInvalidate() end
    GR.RefreshCharacter()
end
