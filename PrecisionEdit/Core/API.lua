--[[
	PrecisionEdit - API helpers
	-------------------------------------------------------------------------
	Small, reusable helpers on `ns.F`: printing, math, Midnight secret guards,
	the shared backdrop and a movable-frame helper that persists position.
	File-scope locals cache the hot globals we touch.
--]]

local _, ns = ...
local C, F = ns.C, ns.F

local select, type = select, type
local tostring = tostring
local floor = math.floor
local min, max = math.min, math.max
local issecretvalue = issecretvalue
local DEFAULT_CHAT_FRAME = DEFAULT_CHAT_FRAME

-- ---------------------------------------------------------------------------
-- Output
-- ---------------------------------------------------------------------------
--- Print a space-joined message to chat with the addon prefix.
function F.Print(...)
	local msg = ""
	for i = 1, select("#", ...) do
		msg = msg .. (i > 1 and " " or "") .. tostring((select(i, ...)))
	end
	DEFAULT_CHAT_FRAME:AddMessage(C.MsgPrefix .. msg)
end

--- Wrap `text` in the addon's brand colour (or a named C.Colors entry).
function F.Colorize(text, colorName)
	local c = C.Colors[colorName or "brand"]
	if not c then
		return text
	end
	return ("|cff%02x%02x%02x%s|r"):format(c[1] * 255, c[2] * 255, c[3] * 255, text)
end

-- ---------------------------------------------------------------------------
-- Math
-- ---------------------------------------------------------------------------
--- Round to `decimals` places (default 0). Symmetric for negative values.
function F.Round(value, decimals)
	if not value then
		return 0
	end
	local mult = 10 ^ (decimals or 0)
	if value >= 0 then
		return floor(value * mult + 0.5) / mult
	end
	return -floor(-value * mult + 0.5) / mult
end

function F.Clamp(value, lower, upper)
	return max(lower, min(upper, value))
end

-- ---------------------------------------------------------------------------
-- Midnight secret-value guards (12.0)
--   Frame geometry (GetPoint/GetCenter) can become secret once secret anchors
--   propagate. Edit Mode is unavailable in combat so this is mostly defensive,
--   but we guard reads before any arithmetic/format per the secret-value rules.
-- ---------------------------------------------------------------------------
function F.IsSecret(value)
	return issecretvalue and issecretvalue(value) or false
end

function F.NotSecret(value)
	return not (issecretvalue and issecretvalue(value))
end

--- True only when every argument is a readable (non-secret, non-nil) value.
function F.CanAccessValues(...)
	for i = 1, select("#", ...) do
		local v = select(i, ...)
		if v == nil or (issecretvalue and issecretvalue(v)) then
			return false
		end
	end
	return true
end

--- Merge `defaults` into `target`: fill missing keys and repair any saved
--- value whose type drifted from the default (recursing into sub-tables).
--- Keys absent from `defaults` are preserved. Returns `target`.
function F.CopyDefaults(defaults, target)
	if type(target) ~= "table" then
		target = {}
	end
	for k, v in pairs(defaults) do
		if type(v) == "table" then
			target[k] = F.CopyDefaults(v, target[k])
		elseif type(target[k]) ~= type(v) then
			target[k] = v
		end
	end
	return target
end

-- ---------------------------------------------------------------------------
-- Frames
-- ---------------------------------------------------------------------------
--- Apply the stock tooltip backdrop to a BackdropTemplate frame, with an
--- optional border tint (defaults to a subtle dark border).
function F.CreateBackdrop(frame, borderColor)
	if not frame.SetBackdrop then
		return
	end
	frame:SetBackdrop(C.Backdrop)
	frame:SetBackdropColor(0.06, 0.06, 0.08, 0.94)
	local b = borderColor or { 0.3, 0.3, 0.32, 1 }
	frame:SetBackdropBorderColor(b[1], b[2], b[3], b[4] or 1)
end

--- Make `frame` drag-movable by the left mouse button. When movement stops,
--- `onMoved(point, x, y)` is called so the caller can persist the position.
function F.MakeMovable(frame, onMoved)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetClampedToScreen(true)
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		if onMoved then
			local point, _, _, x, y = self:GetPoint(1)
			onMoved(point, x, y)
		end
	end)
end
