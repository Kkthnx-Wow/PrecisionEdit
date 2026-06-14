--[[
	PrecisionEdit - EditMode / Panel
	-------------------------------------------------------------------------
	The movable precision panel, attached to the EditMode module. It appears
	when a frame is selected in Edit Mode and disappears on deselect/exit
	(driven entirely by Core.lua's hooks - no polling). It shows the system
	name and live anchor, lets you type exact X/Y, nudge with a d-pad or the
	arrow keys, snap to screen edges, centre on screen and reset to default.
--]]

local _, ns = ...
local C, F, L = ns.C, ns.F, ns.L
local Mod = ns.EditMode

local CreateFrame = CreateFrame
local tonumber, tostring = tonumber, tostring
local IsShiftKeyDown = IsShiftKeyDown
local pcall = pcall

-- ---------------------------------------------------------------------------
-- Small widget helpers
-- ---------------------------------------------------------------------------
local function AddTooltip(button, text)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(text, 1, 1, 1, 1, true)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
end

local function CreateButton(parent, text, width, height, tooltip)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(width, height)
	button:SetText(text)
	if tooltip then
		AddTooltip(button, tooltip)
	end
	return button
end

-- Nudge by direction in stored units (Shift = big step). Shared by the d-pad
-- and the edit boxes' arrow keys. Forces an input refresh so the boxes track
-- the move even while focused.
local function NudgeDir(key)
	local step = IsShiftKeyDown() and Mod:GetBigStep() or 1
	if key == "UP" then
		Mod:Nudge(0, step)
	elseif key == "DOWN" then
		Mod:Nudge(0, -step)
	elseif key == "LEFT" then
		Mod:Nudge(-step, 0)
	elseif key == "RIGHT" then
		Mod:Nudge(step, 0)
	end
	Mod:RefreshPanel(true)
end

-- A directional nudge button using Blizzard's stock square-arrow art. Anchored
-- by its CENTER to the panel's TOPLEFT so the d-pad forms a tidy plus.
local function CreateArrow(parent, direction, cx, cy, tooltip)
	local button = CreateFrame("Button", nil, parent, "UIPanelSquareButton")
	button:SetSize(26, 26)
	button:SetPoint("CENTER", parent, "TOPLEFT", cx, cy)
	if SquareButton_SetIcon then
		SquareButton_SetIcon(button, direction)
	end
	if tooltip then
		AddTooltip(button, tooltip)
	end
	button:SetScript("OnClick", function()
		NudgeDir(direction)
	end)
	return button
end

local function CreateCoordRow(parent, label, y)
	local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, y)
	fs:SetText(label)
	fs:SetWidth(14)

	local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
	box:SetSize(80, 20)
	box:SetPoint("LEFT", fs, "RIGHT", 8, 0)
	box:SetAutoFocus(false)
	box:SetNumeric(false) -- allow a leading minus sign
	return box
end

-- Rich help, shown by the gold "i" button, styled like Blizzard's helptips.
-- Anchored just outside the panel (right side, flipping left near the screen
-- edge) so it never covers the controls it is describing.
local function ShowHelp(self)
	local panel = Mod.panel
	GameTooltip:SetOwner(self, "ANCHOR_NONE")
	GameTooltip:ClearAllPoints()
	if panel then
		local right = panel:GetRight() or 0
		local screenW = UIParent:GetRight() or right
		if right + 280 > screenW then
			GameTooltip:SetPoint("TOPRIGHT", panel, "TOPLEFT", -6, 0)
		else
			GameTooltip:SetPoint("TOPLEFT", panel, "TOPRIGHT", 6, 0)
		end
	else
		GameTooltip:SetPoint("TOPLEFT", self, "BOTTOMRIGHT", 0, 0)
	end
	GameTooltip:SetText(C.Title, C.Colors.brand[1], C.Colors.brand[2], C.Colors.brand[3])
	GameTooltip:AddLine(L["HELP_INTRO"], 1, 1, 1, true)
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine(L["HELP_TYPE"], 0.82, 0.82, 0.82, true)
	GameTooltip:AddLine(L["HELP_NUDGE"], 0.82, 0.82, 0.82, true)
	GameTooltip:AddLine(L["HELP_SNAP"], 0.82, 0.82, 0.82, true)
	GameTooltip:AddLine(L["HELP_RESET"], 0.82, 0.82, 0.82, true)
	GameTooltip:Show()
end

-- ---------------------------------------------------------------------------
-- Panel construction (lazy: built on first selection)
-- ---------------------------------------------------------------------------
function Mod:EnsurePanel()
	if self.panel then
		return
	end

	local panelDB = ns.db.panel
	local f = CreateFrame("Frame", "PrecisionEditPanel", UIParent)
	f:SetSize(300, 286)
	f:SetPoint(panelDB.point, UIParent, panelDB.point, panelDB.x, panelDB.y)
	f:SetFrameStrata("FULLSCREEN_DIALOG")
	f:SetClampedToScreen(true)
	f:Hide()

	-- Native Edit Mode dialog chrome: a dark fill behind Blizzard's translucent
	-- dialog border, exactly like the per-frame settings dialog.
	local bg = f:CreateTexture(nil, "BACKGROUND")
	bg:SetPoint("TOPLEFT", 6, -6)
	bg:SetPoint("BOTTOMRIGHT", -6, 6)
	bg:SetColorTexture(0.04, 0.04, 0.05, 0.92)

	local border = CreateFrame("Frame", nil, f, "DialogBorderTranslucentTemplate")
	border:SetAllPoints(f)

	-- Controls live on a content frame layered above the border so the
	-- nine-slice never draws over the title, labels or buttons.
	local body = CreateFrame("Frame", nil, f)
	body:SetAllPoints(f)
	body:SetFrameLevel(border:GetFrameLevel() + 5)

	-- Drag to move (respecting the lock toggle), persisting the position.
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function(self)
		if not ns.db.panel.locked then
			self:StartMoving()
		end
	end)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local point, _, _, x, y = self:GetPoint(1)
		ns.db.panel.point, ns.db.panel.x, ns.db.panel.y = point, x, y
	end)

	-- Close button (native red X), top-right like Blizzard's dialogs.
	local close = CreateFrame("Button", nil, body, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
	close:SetScript("OnClick", function()
		Mod.userHidden = true
		Mod:HidePanel()
	end)

	-- Gold "i" help button, top-left. Reproduces Blizzard's MainHelpPlateButton
	-- art (gold ring + "i" glyph) from raw textures at half scale, so we don't
	-- depend on the load-on-demand Blizzard_HelpPlate template.
	local help = CreateFrame("Button", nil, body)
	help:SetSize(42, 42)
	help:SetPoint("TOPLEFT", f, "TOPLEFT", -10, 10)

	local ring = help:CreateTexture(nil, "ARTWORK")
	ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	ring:SetSize(42, 42)
	ring:SetPoint("CENTER", 8, -8)

	local glyph = help:CreateTexture(nil, "BORDER")
	glyph:SetTexture("Interface\\common\\help-i")
	glyph:SetSize(38, 38)
	glyph:SetPoint("CENTER")

	local hl = help:CreateTexture(nil, "HIGHLIGHT")
	hl:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	hl:SetBlendMode("ADD")
	hl:SetSize(34, 34)
	hl:SetPoint("CENTER")

	help:SetScript("OnEnter", ShowHelp)
	help:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	-- Centred title = selected system name, matching the Edit Mode dialog.
	f.systemName = body:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	f.systemName:SetPoint("TOP", 0, -15)
	f.systemName:SetWidth(210)
	f.systemName:SetWordWrap(false)

	f.anchor = body:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	f.anchor:SetPoint("TOP", 0, -40)
	f.anchor:SetWidth(260)
	f.anchor:SetWordWrap(false)

	-- Coordinate inputs (left column).
	f.inputX = CreateCoordRow(body, "X", -84)
	f.inputY = CreateCoordRow(body, "Y", -114)

	local function HookCoord(box, axis)
		box:SetScript("OnEnterPressed", function(self)
			local v = tonumber(self:GetText())
			if v then
				Mod:SetOffsetAxis(axis, v)
			end
			self:ClearFocus()
			Mod:RefreshPanel(true)
		end)
		box:SetScript("OnEscapePressed", function(self)
			self:ClearFocus()
			Mod:RefreshPanel(true)
		end)
		box:SetScript("OnArrowPressed", function(_, key)
			NudgeDir(key)
		end)
	end
	HookCoord(f.inputX, "X")
	HookCoord(f.inputY, "Y")

	local stepLabel = body:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	stepLabel:SetPoint("TOPLEFT", body, "TOPLEFT", 20, -146)
	stepLabel:SetText(L["Step"])

	f.stepInput = CreateFrame("EditBox", nil, body, "InputBoxTemplate")
	f.stepInput:SetSize(42, 20)
	f.stepInput:SetPoint("LEFT", stepLabel, "RIGHT", 8, 0)
	f.stepInput:SetAutoFocus(false)
	f.stepInput:SetNumeric(true)
	f.stepInput:SetText(self:GetBigStep())
	f.stepInput:SetScript("OnEnterPressed", function(self)
		Mod:SetBigStep(self:GetNumber())
		self:ClearFocus()
	end)
	f.stepInput:SetScript("OnEscapePressed", function(self)
		self:SetText(Mod:GetBigStep())
		self:ClearFocus()
	end)
	AddTooltip(f.stepInput, L["Shift-nudge distance"])

	local guideCheck = CreateFrame("CheckButton", nil, body, "UICheckButtonTemplate")
	guideCheck:SetPoint("LEFT", f.stepInput, "RIGHT", 20, 0)
	guideCheck:SetChecked(ns.db.panel.showAnchorGuide)
	guideCheck:SetScript("OnClick", function(self)
		ns.db.panel.showAnchorGuide = self:GetChecked()
		Mod:UpdateAnchorGuide()
	end)
	AddTooltip(guideCheck, L["Show anchor guide"])

	local guideLabel = body:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	guideLabel:SetPoint("LEFT", guideCheck, "RIGHT", -2, 1)
	guideLabel:SetText(L["Guide"])

	-- Directional d-pad (right column), a tidy plus centred beside the inputs.
	CreateArrow(body, "UP", 228, -85, L["Nudge up"])
	CreateArrow(body, "DOWN", 228, -133, L["Nudge down"])
	CreateArrow(body, "LEFT", 202, -109, L["Nudge left"])
	CreateArrow(body, "RIGHT", 254, -109, L["Nudge right"])

	-- Footer hint above the action row.
	f.hint = body:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	f.hint:SetPoint("BOTTOM", 0, 104)
	f.hint:SetText(L["Arrow keys nudge - hold Shift for %d"]:format(self:GetBigStep()))

	-- Snap row: the fastest way to make a selected frame kiss a screen edge.
	local snapLabel = body:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	snapLabel:SetPoint("BOTTOMLEFT", 18, 78)
	snapLabel:SetText(L["Snap"])

	local snapLeft = CreateButton(body, L["Left"], 46, 22, L["Snap to left edge"])
	snapLeft:SetPoint("BOTTOMLEFT", 62, 74)
	snapLeft:SetScript("OnClick", function()
		Mod:SnapToEdge("LEFT")
	end)

	local snapRight = CreateButton(body, L["Right"], 48, 22, L["Snap to right edge"])
	snapRight:SetPoint("LEFT", snapLeft, "RIGHT", 4, 0)
	snapRight:SetScript("OnClick", function()
		Mod:SnapToEdge("RIGHT")
	end)

	local snapTop = CreateButton(body, L["Top"], 42, 22, L["Snap to top edge"])
	snapTop:SetPoint("LEFT", snapRight, "RIGHT", 4, 0)
	snapTop:SetScript("OnClick", function()
		Mod:SnapToEdge("TOP")
	end)

	local snapBottom = CreateButton(body, L["Bottom"], 58, 22, L["Snap to bottom edge"])
	snapBottom:SetPoint("LEFT", snapTop, "RIGHT", 4, 0)
	snapBottom:SetScript("OnClick", function()
		Mod:SnapToEdge("BOTTOM")
	end)

	-- Centre + reset (bottom).
	local centerX = CreateButton(body, L["Center X"], 84, 22, L["Center horizontally on screen"])
	centerX:SetPoint("BOTTOMLEFT", 16, 44)
	centerX:SetScript("OnClick", function()
		Mod:CenterAxis("X")
	end)

	local centerY = CreateButton(body, L["Center Y"], 84, 22, L["Center vertically on screen"])
	centerY:SetPoint("BOTTOM", 0, 44)
	centerY:SetScript("OnClick", function()
		Mod:CenterAxis("Y")
	end)

	local centerBoth = CreateButton(body, L["Center"], 84, 22, L["Center on both axes"])
	centerBoth:SetPoint("BOTTOMRIGHT", -16, 44)
	centerBoth:SetScript("OnClick", function()
		Mod:CenterAxis("BOTH")
	end)

	local reset = CreateButton(body, L["Reset to default position"], 268, 22, L["Reset to default position"])
	reset:SetPoint("BOTTOM", 0, 14)
	reset:SetScript("OnClick", function()
		Mod:ResetSelectedPosition()
	end)

	self.panel = f
end

-- ---------------------------------------------------------------------------
-- Show / hide / refresh
-- ---------------------------------------------------------------------------
function Mod:ShowPanel()
	-- Respect a manual close (via the X) until the next selection re-opens it.
	if self.userHidden then
		return
	end
	if self.panel then
		self.panel:Show()
	end
end

function Mod:HidePanel()
	if self.panel then
		self.panel:Hide()
	end
end

--- Whether either coordinate box currently has keyboard focus.
function Mod:IsEditing()
	local f = self.panel
	return f ~= nil and (f.inputX:HasFocus() or f.inputY:HasFocus() or f.stepInput:HasFocus())
end

--- Repaint the panel from the selected frame. Input boxes are only rewritten
--- when not being typed in, unless `force` is set (after a nudge/apply).
function Mod:RefreshPanel(force)
	local f = self.panel
	if not f or not self.selected then
		return
	end

	f.systemName:SetText(self:GetTargetName())

	local point, relPoint, relName, storedX, storedY = self:GetAnchorInfo()
	if not point then
		f.anchor:SetText("|cff999999--|r")
		if force or not self:IsEditing() then
			f.inputX:SetText("")
			f.inputY:SetText("")
		end
		return
	end

	f.anchor:SetText(L["Anchor: %s to %s of %s"]:format(point, relPoint, relName))
	if force or not self:IsEditing() then
		f.inputX:SetText(tostring(F.Round(storedX)))
		f.inputY:SetText(tostring(F.Round(storedY)))
		f.stepInput:SetText(tostring(self:GetBigStep()))
	end
end

-- ---------------------------------------------------------------------------
-- Anchor guide
-- ---------------------------------------------------------------------------
function Mod:EnsureAnchorGuide()
	if self.anchorGuide then
		return self.anchorGuide
	end

	local guide = CreateFrame("Frame", "PrecisionEditAnchorGuide", UIParent)
	guide:SetSize(26, 26)
	guide:SetFrameStrata("FULLSCREEN_DIALOG")
	guide:Hide()

	local h = guide:CreateTexture(nil, "OVERLAY")
	h:SetColorTexture(C.Colors.brand[1], C.Colors.brand[2], C.Colors.brand[3], 0.9)
	h:SetHeight(2)
	h:SetPoint("LEFT", 2, 0)
	h:SetPoint("RIGHT", -2, 0)

	local v = guide:CreateTexture(nil, "OVERLAY")
	v:SetColorTexture(C.Colors.brand[1], C.Colors.brand[2], C.Colors.brand[3], 0.9)
	v:SetWidth(2)
	v:SetPoint("TOP", 0, -2)
	v:SetPoint("BOTTOM", 0, 2)

	local dot = guide:CreateTexture(nil, "OVERLAY")
	dot:SetColorTexture(1, 0.9, 0.2, 1)
	dot:SetSize(6, 6)
	dot:SetPoint("CENTER")

	guide.label = guide:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	guide.label:SetPoint("TOP", guide, "BOTTOM", 0, -2)

	self.anchorGuide = guide
	return guide
end

function Mod:HideAnchorGuide()
	if self.anchorGuide then
		self.anchorGuide:Hide()
	end
end

function Mod:UpdateAnchorGuide()
	if not (ns.db.panel.showAnchorGuide and self.selected) then
		self:HideAnchorGuide()
		return
	end

	local point = self:GetAnchorInfo()
	if not point then
		self:HideAnchorGuide()
		return
	end

	local guide = self:EnsureAnchorGuide()
	guide:ClearAllPoints()
	guide.label:SetText(point)
	local ok = pcall(guide.SetPoint, guide, "CENTER", self.selected, point, 0, 0)
	guide:SetShown(ok)
end

-- ---------------------------------------------------------------------------
-- Used by the slash command
-- ---------------------------------------------------------------------------
function Mod:ResetPanelPosition()
	local db = ns.db.panel
	db.point, db.x, db.y = "CENTER", 0, -200
	if self.panel then
		self.panel:ClearAllPoints()
		self.panel:SetPoint(db.point, UIParent, db.point, db.x, db.y)
	end
end

function Mod:SetPanelLocked(locked)
	ns.db.panel.locked = locked
end
