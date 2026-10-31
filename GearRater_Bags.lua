-- GearRater bag overlays: paint the effective item level on equippable bag and bank items,
-- green when the item beats what is equipped, red when it is worse, white otherwise.

GearRater = GearRater or {}
local GR = GearRater

local bagCache = {}   -- bag -> slot -> { link, data }

function GR.InvalidateBags(bag)
    if bag then bagCache[bag] = nil else bagCache = {} end
end

-- Score one bag slot through the hidden tooltip. Returns nil for empty or non-equippable slots,
-- else { link, score, lvl, cmp }.
function GR.ScoreBagItem(bag, slot)
    local link = GetContainerItemLink(bag, slot)
    if not link then return nil end
    local equipLoc = select(9, GetItemInfo(link))
    if not equipLoc or equipLoc == "" then return nil end

    local c = bagCache[bag] and bagCache[bag][slot]
    if c and c.link == link then return c.data end

    local tip = GR.ScanTip()
    tip:SetOwner(UIParent, "ANCHOR_NONE")
    tip:ClearLines()
    tip:SetBagItem(bag, slot)
    local result = GR.ScanTooltip(tip)
    local total = GR.Score(result, link)
    local data = {
        link  = link,
        score = total,
        lvl   = GR.EffectiveLevel(result, link),
        cmp   = total and GR.Compare(result, link, total) or nil,
    }
    bagCache[bag] = bagCache[bag] or {}
    bagCache[bag][slot] = { link = link, data = data }
    return data
end

-------------------------------------------------------------------------------
-- Overlay drawing
-------------------------------------------------------------------------------

local function OverlayText(button)
    if not button.grText then
        local fs = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        fs:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
        fs:SetJustifyH("LEFT")
        button.grText = fs
    end
    return button.grText
end

local function UpdateButton(button, bag, slot)
    if not GearRaterDB or not GearRaterDB.bags then
        if button.grText then button.grText:Hide() end
        return
    end
    local data = GR.ScoreBagItem(bag, slot)
    if not data or not data.lvl then
        if button.grText then button.grText:Hide() end
        return
    end
    local fs = OverlayText(button)
    local r, g, b = 1, 1, 1
    local cmp = data.cmp
    if cmp and not cmp.isEquipped then
        if cmp.delta > 0.05 then r, g, b = 0.3, 1, 0.3
        elseif cmp.delta < -0.05 then r, g, b = 1, 0.35, 0.35 end
    elseif cmp and cmp.isEquipped then
        r, g, b = 0.7, 0.7, 0.7
    end
    fs:SetText(string.format("%.0f", data.lvl.effective))
    fs:SetTextColor(r, g, b)
    fs:Show()
end

local function UpdateContainer(frame)
    local bag, name = frame:GetID(), frame:GetName()
    for i = 1, (frame.size or 0) do
        local button = _G[name .. "Item" .. i]
        if button then UpdateButton(button, bag, button:GetID()) end
    end
end

function GR.RefreshBags()
    for i = 1, (NUM_CONTAINER_FRAMES or 13) do
        local frame = _G["ContainerFrame" .. i]
        if frame and frame:IsShown() then UpdateContainer(frame) end
    end
    if BankFrame and BankFrame:IsShown() and BankFrameItemButton_Update then
        for i = 1, (NUM_BANKGENERIC_SLOTS or 28) do
            local button = _G["BankFrameItem" .. i]
            if button then UpdateButton(button, BANK_CONTAINER or -1, button:GetID()) end
        end
    end
end

if hooksecurefunc then
    if ContainerFrame_Update then
        hooksecurefunc("ContainerFrame_Update", UpdateContainer)
    end
    if BankFrameItemButton_Update then
        hooksecurefunc("BankFrameItemButton_Update", function(button)
            if button.isBag then return end
            UpdateButton(button, BANK_CONTAINER or -1, button:GetID())
        end)
    end
end

-- Anything that changes the equipped baseline also changes every overlay colour.
local origInvalidate = GR.InvalidateEquipped
GR.InvalidateEquipped = function()
    if origInvalidate then origInvalidate() end
    GR.InvalidateBags()
    GR.RefreshBags()
end

local f = CreateFrame("Frame")
f:RegisterEvent("BAG_UPDATE")
f:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
f:SetScript("OnEvent", function(_, event, bag)
    if event == "BAG_UPDATE" then GR.InvalidateBags(bag) else GR.InvalidateBags(BANK_CONTAINER or -1) end
end)
