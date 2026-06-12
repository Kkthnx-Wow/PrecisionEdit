-- WoW runs on a modified Lua 5.1.
std = "lua51"

max_line_length = 200

-- 212 unused argument (event handlers must declare self/event), 432/431 shadow,
-- 542 empty if branch, 631 line length on data.
ignore = {
	"212",
	"431",
	"432",
	"542",
}

-- Globals PrecisionEdit defines (its handle, saved variables, named frames and
-- the slash registrations).
globals = {
	"PrecisionEdit",
	"PrecisionEditDB",
	"PrecisionEditEventFrame",
	"PrecisionEditAnchorGuide",
	"PrecisionEditPanel",
	"SlashCmdList",
	"SLASH_PRECISIONEDIT1",
	"SLASH_PRECISIONEDIT2",
}

-- WoW API surface PrecisionEdit reads.
read_globals = {
	"C_AddOns",
	"CreateFrame",
	"DEFAULT_CHAT_FRAME",
	"EditModeManagerFrame",
	"EventRegistry",
	"GameTooltip",
	"InCombatLockdown",
	"IsLoggedIn",
	"IsShiftKeyDown",
	"SquareButton_SetIcon",
	"UIParent",
	"UNKNOWN",
	"hooksecurefunc",
	"issecretvalue",
}
