--[[
	PrecisionEdit - EditMode / LibEditMode bridge
	-------------------------------------------------------------------------
	Many addons add their own frames to Edit Mode through LibEditMode
	(p3lim's library, embedded widely). Those frames are *not* Blizzard system
	frames: clicking one runs EditModeManagerFrame:ClearSelectedSystem() and
	shows the library's own dialog, so Core.lua's SelectSystem hook never sees
	them. This bridge teaches the panel about them.

	How it works (all post-hooks, no polling, no taint):
	  * We find the library through LibStub (the standard embed registers there).
	  * The library funnels every selection through `internal.dialog:Update`
	    and every deselection through that dialog hiding - we hook both.
	  * A lib frame is a plain frame anchored by a single point to its parent,
	    so reads (GetAnchorInfo) and the in-place translate in Position.lua work
	    unchanged. Only *persistence* differs: instead of Blizzard's
	    OnSystemPositionChange we fire the frame's registered callback (via
	    internal:TriggerCallback) so the move saves into the owning addon's
	    layout. We keep the anchor point fixed rather than re-normalising it (as
	    the library's own drag would), so typed coordinates stay exact.

	Positioning math (Nudge / Center / Snap) all funnels through
	Mod:ApplyLiveOffsetDelta in Position.lua, which calls Mod:PersistLibMove
	below for "lib" targets; only persistence and Reset differ between families.
--]]

local _, ns = ...
local F = ns.F
local Mod = ns.EditMode

local hooksecurefunc = hooksecurefunc

local CENTER = { point = "CENTER", x = 0, y = 0 }

-- ---------------------------------------------------------------------------
-- Library discovery
-- ---------------------------------------------------------------------------
local function FindLib()
	local LibStub = rawget(_G, "LibStub")
	if not (LibStub and LibStub.GetLibrary) then
		return nil
	end
	-- Silent lookup: returns nil instead of erroring when nobody embeds it.
	local lib = LibStub:GetLibrary("LibEditMode", true)
	if lib and lib.internal then
		return lib
	end
	return nil
end

-- ---------------------------------------------------------------------------
-- Selection routing (called from the dialog hooks)
-- ---------------------------------------------------------------------------
--- A LibEditMode frame became the active selection (or its dialog refreshed).
function Mod:SetLibSelected(selection)
	local frame = selection and selection.parent
	if not frame then
		return
	end

	local isNew = self.selected ~= frame or self.targetKind ~= "lib"
	self.targetKind = "lib"
	self.libSelection = selection
	self.selected = frame

	self:ActivatePanel(isNew)
	ns:TriggerCallback("Selection.Changed", frame)
end

--- The library dialog updated. Same frame -> just repaint; new frame -> select.
function Mod:OnLibDialogUpdate(selection)
	if not (selection and selection.parent) then
		return
	end

	if self.targetKind == "lib" and self.selected == selection.parent then
		self.libSelection = selection
		self:RefreshPanel()
		self:UpdateAnchorGuide()
	else
		self:SetLibSelected(selection)
	end
end

--- The library dialog hid (close, deselect, edit-mode enter/exit, or a Blizzard
--- system being selected). Tear our panel down only if a lib frame owned it.
function Mod:OnLibDialogHide()
	if self.targetKind ~= "lib" then
		return
	end

	self.targetKind = nil
	self.libSelection = nil
	self.selected = nil
	self:DeactivatePanel()
	ns:TriggerCallback("Selection.Changed", nil)
end

-- ---------------------------------------------------------------------------
-- Persistence adapters (called from Position.lua for "lib" targets)
-- ---------------------------------------------------------------------------
--- Save a lib frame's *current* position (already moved in place by
--- ApplyLiveOffsetDelta) through the owning addon's registered callback, so it
--- persists in that addon's layout. We deliberately pass the frame's current
--- anchor point rather than re-normalising it (which `internal:MoveParent`
--- would), so typed coordinates and nudges stay exact and predictable - the
--- same stable-anchor contract PrecisionEdit honours for Blizzard frames.
function Mod:PersistLibMove(frame)
	local internal = self.libInternal
	if not (internal and internal.TriggerCallback) then
		return
	end

	local point, _, _, x, y = frame:GetPoint(1)
	if not F.CanAccessValues(x, y) then
		return
	end

	internal:TriggerCallback(frame, point, x, y)

	-- Repaint our own readout directly. We deliberately do NOT force the library
	-- dialog to rebuild here: this runs on every nudge (a held arrow key fires it
	-- repeatedly) and its Update() releases and re-acquires every setting widget.
	-- The lib dialog's reset button can lag a touch; it self-corrects on the next
	-- reselect, which is a fair trade for not thrashing pools on each keypress.
	self:RefreshPanel()
	self:UpdateAnchorGuide()
end

--- Reset a lib frame to the default position registered with it (or CENTER),
--- mirroring the library dialog's own reset button.
function Mod:ResetLibPosition(frame)
	local lib = self.lib
	local internal = self.libInternal
	if not (lib and internal) then
		return false
	end

	local default = lib.GetFrameDefaultPosition and lib:GetFrameDefaultPosition(frame) or nil
	default = default or CENTER

	frame:ClearAllPoints()
	frame:SetPoint(default.point, default.x, default.y)

	if internal.TriggerCallback then
		internal:TriggerCallback(frame, default.point, default.x, default.y)
	end

	-- Refresh the lib dialog (updates its reset button) which, in turn, repaints
	-- our panel through the Update hook; fall back to a direct repaint otherwise.
	if internal.dialog and internal.dialog.selection == self.libSelection and internal.dialog.Update then
		internal.dialog:Update(self.libSelection)
	else
		self:RefreshPanel()
		self:UpdateAnchorGuide()
	end
	return true
end

-- ---------------------------------------------------------------------------
-- Install (called from Core.lua OnEnable)
-- ---------------------------------------------------------------------------
--- Hook the library's dialog once it exists. The dialog is created lazily on the
--- first AddFrame, so this is called both at install time and after every
--- AddFrame until the hook lands.
function Mod:HookLibDialog()
	local internal = self.libInternal
	local dialog = internal and internal.dialog
	if not dialog or dialog.__precisionEditHooked then
		return
	end
	dialog.__precisionEditHooked = true

	hooksecurefunc(dialog, "Update", function(_, selection)
		Mod:OnLibDialogUpdate(selection)
	end)
	dialog:HookScript("OnHide", function()
		Mod:OnLibDialogHide()
	end)
end

function Mod:InstallLibEditMode()
	if self.libInstalled then
		return true
	end

	local lib = FindLib()
	if not lib then
		return false
	end

	self.lib = lib
	self.libInternal = lib.internal
	self.libInstalled = true

	-- Dialog may already exist if an addon registered frames before us; if not,
	-- it is created on the first AddFrame, so re-check after each one.
	self:HookLibDialog()
	if lib.AddFrame then
		hooksecurefunc(lib, "AddFrame", function()
			Mod:HookLibDialog()
		end)
	end
	return true
end
