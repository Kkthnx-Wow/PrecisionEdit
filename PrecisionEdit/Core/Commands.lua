--[[
	PrecisionEdit - Slash command
	-------------------------------------------------------------------------
	`/pe` (alias `/precisionedit`): help, reset the panel position, and toggle
	the panel lock. The panel itself appears automatically in Edit Mode.
--]]

local _, ns = ...
local F, L = ns.F, ns.L

local handlers = {}

handlers.help = function()
	F.Print(F.Colorize(L["Commands:"], "brand"))
	F.Print("  /pe        -", L["Show this help"])
	F.Print("  /pe reset  -", L["Reset the panel's position"])
	F.Print("  /pe lock   -", L["Lock or unlock the panel"])
	F.Print(L["Enter Edit Mode, then select a frame to position it precisely."])
end

handlers.reset = function()
	local mod = ns.EditMode
	if mod and mod.ResetPanelPosition then
		mod:ResetPanelPosition()
		F.Print(L["Panel position reset."])
	end
end

handlers.lock = function()
	local mod = ns.EditMode
	if not (mod and mod.SetPanelLocked) then
		return
	end
	local locked = not (ns.db.panel and ns.db.panel.locked)
	mod:SetPanelLocked(locked)
	F.Print(locked and L["Panel locked."] or L["Panel unlocked."])
end

local function HandleSlash(input)
	local command = (input or ""):match("^%s*(%S*)"):lower()
	local handler = handlers[command] or handlers.help
	handler()
end

_G.SLASH_PRECISIONEDIT1 = "/pe"
_G.SLASH_PRECISIONEDIT2 = "/precisionedit"
_G.SlashCmdList["PRECISIONEDIT"] = HandleSlash
