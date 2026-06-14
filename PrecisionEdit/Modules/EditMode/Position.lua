--[[
	PrecisionEdit - EditMode / Position
	-------------------------------------------------------------------------
	The positioning math, attached to the EditMode module. We mirror Blizzard's
	own model exactly (see Blizzard_EditModeSystemTemplates / -Manager):

	  * A system's saved offset is normalised to 1.0 scale:
	        storedOffset = livePointOffset * frame:GetScale()
	    (ApplySystemAnchor divides by GetScale, UpdateSystemAnchorInfo multiplies
	    by it.) We work in these "stored" units so our numbers match what Edit
	    Mode persists and what layout import/export strings contain. At a
	    pixel-perfect UI scale, one stored unit equals one physical screen pixel.

	  * To persist a move we set the frame's point(s) then call
	        EditModeManagerFrame:OnSystemPositionChange(frame)
	    which is the exact path a normal drag uses - it rewrites anchorInfo and
	    flags the layout as having active (savable) changes.

	All mutators are gated on combat (Edit Mode is unavailable in combat anyway)
	and on the geometry being readable (never do math on a secret value).
--]]

local _, ns = ...
local F, L = ns.F, ns.L
local Mod = ns.EditMode

local InCombatLockdown = InCombatLockdown
local UIParent = UIParent

local function Manager()
	return _G.EditModeManagerFrame
end

--- Guard: a real, selected, movable system frame that we can mutate now.
local function Movable()
	local frame = Mod.selected
	if not frame then
		return nil
	end
	if InCombatLockdown() then
		F.Print(L["Cannot move a frame during combat."])
		return nil
	end
	if frame.CanBeMoved and not frame:CanBeMoved() then
		return nil
	end
	if frame:GetNumPoints() == 0 then
		return nil
	end
	return frame
end

-- ---------------------------------------------------------------------------
-- Reads
-- ---------------------------------------------------------------------------
--- Returns point, relativePoint, relativeToName, storedX, storedY for the
--- selected frame's primary anchor, or nil when unreadable (no selection /
--- secret geometry). storedX/Y are normalised to 1.0 scale.
function Mod:GetAnchorInfo()
	local frame = self.selected
	if not frame or frame.GetNumPoints == nil or frame:GetNumPoints() == 0 then
		return nil
	end

	local point, relativeTo, relativePoint, offsetX, offsetY = frame:GetPoint(1)
	if not F.CanAccessValues(offsetX, offsetY) then
		return nil
	end

	local scale = frame:GetScale()
	if not scale or scale < 0.01 then
		scale = 1
	end

	local relName = "UIParent"
	if relativeTo and relativeTo.GetName then
		relName = relativeTo:GetName() or relName
	end

	return point or "CENTER", relativePoint or point or "CENTER", relName, offsetX * scale, offsetY * scale
end

-- ---------------------------------------------------------------------------
-- Core mutation: translate every anchor point by (dxLocal, dyLocal) local
-- units, keeping multi-point frames (e.g. action bars) rigid, then persist via
-- Blizzard's own position-change path.
-- ---------------------------------------------------------------------------
function Mod:ApplyLiveOffsetDelta(dxLocal, dyLocal)
	local frame = Movable()
	if not frame then
		return false
	end

	local isLib = self.targetKind == "lib"

	-- Match Blizzard's drag-start path for managed/default-position frames and
	-- snapped frames; otherwise precise moves can be pulled back by the frame
	-- manager or leave stale snap links behind. LibEditMode frames are plain
	-- frames with none of this machinery, so we skip it for them.
	if not isLib then
		if frame.isManagedFrame and frame.IsInDefaultPosition and frame:IsInDefaultPosition() and frame.BreakFromFrameManager then
			frame:BreakFromFrameManager()
		end
		if frame.ClearFrameSnap then
			frame:ClearFrameSnap()
		end
	end

	local numPoints = frame:GetNumPoints()
	local points = {}
	for i = 1, numPoints do
		local point, relativeTo, relativePoint, ox, oy = frame:GetPoint(i)
		if not F.CanAccessValues(ox, oy) then
			return false
		end
		points[i] = { point, relativeTo, relativePoint, ox + dxLocal, oy + dyLocal }
	end

	frame:ClearAllPoints()
	for i = 1, numPoints do
		local p = points[i]
		frame:SetPoint(p[1], p[2], p[3], p[4], p[5])
	end

	-- Persist through the owning system's save path. We keep the anchor point
	-- fixed (above) for both families, so coordinates stay exact and stable.
	if isLib then
		self:PersistLibMove(frame)
	else
		local manager = Manager()
		if manager and manager.OnSystemPositionChange then
			manager:OnSystemPositionChange(frame)
		end
	end
	return true
end

-- ---------------------------------------------------------------------------
-- Public operations (the panel and keyboard handler call these)
-- ---------------------------------------------------------------------------
--- Nudge by a delta expressed in stored (1.0-scale) units. The displayed
--- coordinate changes by exactly (dStoredX, dStoredY).
function Mod:Nudge(dStoredX, dStoredY)
	local frame = self.selected
	if not frame then
		return false
	end
	local scale = frame:GetScale()
	if not scale or scale < 0.01 then
		scale = 1
	end
	return self:ApplyLiveOffsetDelta(dStoredX / scale, dStoredY / scale)
end

--- Set the stored offset on one axis ("X" or "Y") to an absolute target.
function Mod:SetOffsetAxis(axis, target)
	local _, _, _, storedX, storedY = self:GetAnchorInfo()
	if not storedX then
		return false
	end
	if axis == "X" then
		return self:Nudge(target - storedX, 0)
	else
		return self:Nudge(0, target - storedY)
	end
end

--- Centre the frame on the screen along "X", "Y" or "BOTH". Works in physical
--- pixels (region center * effective scale) then converts to a local-offset
--- delta, so it is correct regardless of the frame's own scale.
function Mod:CenterAxis(axis)
	local frame = Movable()
	if not frame then
		return false
	end

	local sysCX, sysCY = frame:GetCenter()
	local uipCX, uipCY = UIParent:GetCenter()
	local frameEff = frame:GetEffectiveScale()
	local uipEff = UIParent:GetEffectiveScale()
	if not F.CanAccessValues(sysCX, sysCY, uipCX, uipCY) or not frameEff or frameEff < 0.01 then
		return false
	end

	local dxLocal, dyLocal = 0, 0
	if axis == "X" or axis == "BOTH" then
		dxLocal = (uipCX * uipEff - sysCX * frameEff) / frameEff
	end
	if axis == "Y" or axis == "BOTH" then
		dyLocal = (uipCY * uipEff - sysCY * frameEff) / frameEff
	end

	return self:ApplyLiveOffsetDelta(dxLocal, dyLocal)
end

--- Snap one edge of the selected frame to the matching UIParent screen edge.
--- Edge geometry is converted through effective scale so the alignment remains
--- correct when a system frame is scaled differently from UIParent.
function Mod:SnapToEdge(edge)
	local frame = Movable()
	if not frame then
		return false
	end

	local frameEff = frame:GetEffectiveScale()
	local uipEff = UIParent:GetEffectiveScale()
	if not frameEff or frameEff < 0.01 or not uipEff or uipEff < 0.01 then
		return false
	end

	local dxLocal, dyLocal = 0, 0
	if edge == "LEFT" then
		local frameLeft, parentLeft = frame:GetLeft(), UIParent:GetLeft()
		if not F.CanAccessValues(frameLeft, parentLeft) then
			return false
		end
		dxLocal = (parentLeft * uipEff - frameLeft * frameEff) / frameEff
	elseif edge == "RIGHT" then
		local frameRight, parentRight = frame:GetRight(), UIParent:GetRight()
		if not F.CanAccessValues(frameRight, parentRight) then
			return false
		end
		dxLocal = (parentRight * uipEff - frameRight * frameEff) / frameEff
	elseif edge == "TOP" then
		local frameTop, parentTop = frame:GetTop(), UIParent:GetTop()
		if not F.CanAccessValues(frameTop, parentTop) then
			return false
		end
		dyLocal = (parentTop * uipEff - frameTop * frameEff) / frameEff
	elseif edge == "BOTTOM" then
		local frameBottom, parentBottom = frame:GetBottom(), UIParent:GetBottom()
		if not F.CanAccessValues(frameBottom, parentBottom) then
			return false
		end
		dyLocal = (parentBottom * uipEff - frameBottom * frameEff) / frameEff
	else
		return false
	end

	return self:ApplyLiveOffsetDelta(dxLocal, dyLocal)
end

--- Reset the selected system to its layout default position.
function Mod:ResetSelectedPosition()
	local frame = Movable()
	if not frame then
		return false
	end

	if self.targetKind == "lib" then
		return self:ResetLibPosition(frame)
	end

	if not frame.ResetToDefaultPosition then
		return false
	end
	frame:ResetToDefaultPosition()
	self:RefreshPanel()
	self:UpdateAnchorGuide()
	return true
end
