-- Double fire: partial first pass, full second pass, both before the frame ends.
print("\n== Double fire (partial then full)")
GearRaterDB.tooltip = true
local full = {
    {"Ring", "gold"}, {"Finger"}, {"+30 Stamina"}, {"+20 Intellect"},
    {"+12 Spirit", "green"}, {"+15 Spell Power", "green"}, {"Equip: Improves haste rating by 25.", "green"},
}
local partial = { full[1], full[2], full[3], full[4] }
TEST.SetLines(GameTooltip, partial, "item:1:0:0:0:0:0:0:0")
GameTooltip.hook(GameTooltip)
local addedFirst = #GameTooltip.added
assert(addedFirst >= 3, "first pass appends our lines, got " .. addedFirst)
-- second pass: client appended the rest of the lines; our lines from pass one are still present
local lines2 = {}
for i = 1, 4 do lines2[#lines2+1] = full[i] end
for i = 1, addedFirst do lines2[#lines2+1] = GameTooltip.lines[4 + i] end
for i = 5, 7 do lines2[#lines2+1] = full[i] end
TEST.SetLines(GameTooltip, lines2, "item:1:0:0:0:0:0:0:0")
GameTooltip.hook(GameTooltip)
assert(#GameTooltip.added == 0, "second pass must not append new GR lines, got " .. #GameTooltip.added)
local hdr
for i = 1, GameTooltip:NumLines() do
    local t = _G["GameTooltipTextLeft" .. i]:GetText() or ""
    if t:find("stats") then hdr = t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") end
end
print("  refreshed header: " .. tostring(hdr))
assert(hdr and hdr:find("5 stats"), "header should be refreshed in place to 5 stats")
print("  -- chat after pump (expect ONE dump with 5 stats):")
TEST.Pump()
print("  -- second pump (expect nothing):")
TEST.Pump()
GearRaterDB.tooltip = false
print("\nDOUBLE FIRE PASSED")
