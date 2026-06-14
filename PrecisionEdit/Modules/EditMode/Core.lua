--[[
	PrecisionEdit - EditMode / Core
	-------------------------------------------------------------------------
	Tracks the selected Edit Mode system and drives the precision panel. This
	is fully event-driven (no OnUpdate polling):

	  * hooksecurefunc(EditModeManagerFrame, "SelectSystem")         -> selection
	  * hooksecurefunc(EditModeManagerFrame, "ClearSelectedSystem")  -> deselect
	  * hooksecurefunc(EditModeManagerFrame, "OnSystemPositionChange")-> live readout
	  * EventRegistry "EditMode.Enter" / "EditMode.Exit"             -> lifecycle

	Blizzard_EditMode is load-on-demand, so we install the hooks the moment it
	loads (or immediately if it is already present).

	Position math lives in Position.lua and the UI in Panel.lua; both attach
	their methods to this same module table.
--]]

local _, ns = ...

local hooksecurefunc = hooksecurefunc
local IsShiftKeyDown = IsShiftKeyDown
local CreateFrame = CreateFrame
local EventRegistry = EventRegistry
local rawget = rawget
local pcall = pcall
local tonumber = tonumber
local floor, max, min = math.floor, math.max, math.min
local UNKNOWN = rawget(_G, "UNKNOWN") or "Unknown"

ns:RegisterDefaults({
	panel = {
		point = "CENTER",
		x = 0,
		y = -200,
		locked = false,
		bigStep = 10,
		showAnchorGuide = true,
	},
})

local Mod = ns:NewModule("EditMode", "editMode")
ns.EditMode = Mod

-- Currently selected frame (a Blizzard EditModeSystemMixin frame, or a
-- LibEditMode-registered frame), or nil. `targetKind` records which family the
-- selection belongs to so the positioning code knows how to persist a move:
--   "blizzard" -> Blizzard's OnSystemPositionChange path
--   "lib"      -> LibEditMode's own move/callback path (see LibEditMode.lua)
Mod.selected = nil
Mod.targetKind = nil
Mod.libSelection = nil -- the LibEditMode selection overlay for a "lib" target
Mod.active = false

--- The Shift-modifier step size, clamped to something sane.
function Mod:GetBigStep()
	local step = ns.db and ns.db.panel and ns.db.panel.bigStep or 10
	return math.max(2, math.min(100, step))
end

function Mod:SetBigStep(step)
	step = tonumber(step)
	if not step then
		return false
	end
	ns.db.panel.bigStep = max(2, min(100, floor(step + 0.5)))
	if self.panel and self.panel.stepInput then
		self.panel.stepInput:SetText(ns.db.panel.bigStep)
	end
	if self.panel and self.panel.hint then
		self.panel.hint:SetText(ns.L["Arrow keys nudge - hold Shift for %d"]:format(ns.db.panel.bigStep))
	end
	return true
end

-- ---------------------------------------------------------------------------
-- Selection
-- ---------------------------------------------------------------------------
--- Bring the panel up for the current selection. `isNew` re-opens a panel the
--- user manually closed (a fresh selection), but a mere refresh of the same
--- target leaves a user-closed panel closed.
function Mod:ActivatePanel(isNew)
	if isNew then
		self.userHidden = false
	end
	self:EnsurePanel()
	self:ShowPanel()
	self:RefreshPanel()
	self:UpdateAnchorGuide()
	self:SetKeyboardEnabled(true)
end

--- Tear the panel down (no selection).
function Mod:DeactivatePanel()
	self:SetKeyboardEnabled(false)
	self:HideAnchorGuide()
	self:HidePanel()
end

--- The display name of the current target. LibEditMode keeps the system name on
--- the selection overlay rather than the frame itself, so check there first.
function Mod:GetTargetName()
	if self.targetKind == "lib" and self.libSelection then
		local system = self.libSelection.system
		if system and system.GetSystemName then
			local ok, name = pcall(system.GetSystemName, system)
			if ok and name then
				return name
			end
		end
	end

	local frame = self.selected
	if frame and frame.GetSystemName then
		local ok, name = pcall(frame.GetSystemName, frame)
		if ok and name then
			return name
		end
	end
	return UNKNOWN
end

--- Select (or clear) a Blizzard Edit Mode system frame.
function Mod:SetSelected(frame)
	-- Edit Mode passes frames through secureexecuterange; only accept a real
	-- movable system frame so the panel never targets a stale/odd object.
	if frame and not (frame.IsObjectType and frame:IsObjectType("Frame") and frame.GetSystemName) then
		frame = nil
	end

	self.targetKind = frame and "blizzard" or nil
	self.libSelection = nil
	self.selected = frame

	if frame then
		self:ActivatePanel(true)
	else
		self:DeactivatePanel()
	end

	ns:TriggerCallback("Selection.Changed", frame)
end

-- ---------------------------------------------------------------------------
-- Global arrow-key nudging while a frame is selected.
--   A keyboard-listening frame, enabled only during an active selection. It
--   propagates every key by default and only *consumes* the four arrow keys,
--   so chat and other bindings keep working. While the user is typing in the
--   panel's edit boxes we let arrows move the text cursor instead.
-- ---------------------------------------------------------------------------
local function OnKeyDown(self, key)
	self:SetPropagateKeyboardInput(true)

	if not Mod.selected or (Mod.IsEditing and Mod:IsEditing()) then
		return
	end

	local step = IsShiftKeyDown() and Mod:GetBigStep() or 1
	local dx, dy = 0, 0
	if key == "UP" then
		dy = step
	elseif key == "DOWN" then
		dy = -step
	elseif key == "LEFT" then
		dx = -step
	elseif key == "RIGHT" then
		dx = step
	else
		return
	end

	-- We handled an arrow key: stop it propagating to movement/camera bindings.
	self:SetPropagateKeyboardInput(false)
	Mod:Nudge(dx, dy)
end

function Mod:SetKeyboardEnabled(enabled)
	if not self.keyCatcher then
		if not enabled then
			return
		end
		local catcher = CreateFrame("Frame", nil, UIParent)
		catcher:Hide()
		catcher:SetScript("OnKeyDown", OnKeyDown)
		self.keyCatcher = catcher
	end

	self.keyCatcher:EnableKeyboard(enabled)
	self.keyCatcher:SetShown(enabled)
end

-- ---------------------------------------------------------------------------
-- Hook installation (load-on-demand aware)
-- ---------------------------------------------------------------------------
function Mod:TryInstall()
	if self.installed then
		return true
	end

	local manager = rawget(_G, "EditModeManagerFrame")
	if not manager then
		return false
	end
	self.installed = true

	hooksecurefunc(manager, "SelectSystem", function(_, systemFrame)
		Mod:SetSelected(systemFrame)
	end)

	if manager.ClearSelectedSystem then
		hooksecurefunc(manager, "ClearSelectedSystem", function()
			-- LibEditMode clears the Blizzard selection (taint avoidance) right
			-- before it selects one of its own frames; ignoring that case keeps
			-- the panel from flickering during a Blizzard -> lib hand-off. A lib
			-- target is torn down via the lib dialog's OnHide instead.
			if Mod.targetKind ~= "lib" then
				Mod:SetSelected(nil)
			end
		end)
	end

	-- Fires for our nudges *and* normal Blizzard drags, so the readout stays
	-- live without any polling.
	hooksecurefunc(manager, "OnSystemPositionChange", function(_, systemFrame)
		if systemFrame == Mod.selected then
			Mod:RefreshPanel()
			Mod:UpdateAnchorGuide()
		end
	end)

	if EventRegistry then
		EventRegistry:RegisterCallback("EditMode.Enter", function()
			Mod.active = true
		end, Mod)
		EventRegistry:RegisterCallback("EditMode.Exit", function()
			Mod.active = false
			Mod:SetSelected(nil)
		end, Mod)
	end

	return true
end

function Mod:OnEnable()
	-- Pick up frames registered through LibEditMode (if any addon embeds it), so
	-- the panel works for third-party Edit Mode frames too. Safe to call when the
	-- library is absent.
	if self.InstallLibEditMode then
		self:InstallLibEditMode()
	end

	if self:TryInstall() then
		return
	end
	-- Blizzard_EditMode hasn't loaded yet; install as soon as it does.
	ns:RegisterEvent("ADDON_LOADED", function(_, loadedAddon)
		if loadedAddon == "Blizzard_EditMode" then
			Mod:TryInstall()
		end
	end)
end
