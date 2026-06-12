--[[
	PrecisionEdit - Constants
	-------------------------------------------------------------------------
	Shared, read-mostly values: branding, colours and the stock backdrop used
	by our frames. Populates the `ns.C` table created by the engine (never
	replaces it, so load order is irrelevant).
--]]

local _, ns = ...
local C = ns.C

C.Title = "PrecisionEdit"

-- Brand colour (a warm gold, echoing Blizzard's Edit Mode accents) used for
-- titles, the message prefix and the anchor guide.
C.BrandHex = "fff2b134"
C.Colors = {
	brand = { 0.949, 0.694, 0.204 },
	header = { 0.9, 0.9, 0.9 },
	label = { 0.7, 0.7, 0.7 },
	white = { 1, 1, 1 },
	green = { 0.4, 0.85, 0.4 },
	red = { 0.9, 0.4, 0.4 },
}

-- Chat message prefix, e.g. "PrecisionEdit: ...".
C.MsgPrefix = "|c" .. C.BrandHex .. C.Title .. ":|r "

-- Stock tooltip border backdrop (matches Blizzard's own edit dialogs and is
-- always available - no shipped art required).
C.Backdrop = {
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true,
	tileSize = 16,
	edgeSize = 16,
	insets = { left = 4, right = 4, top = 4, bottom = 4 },
}
