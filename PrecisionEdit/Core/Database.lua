--[[
	PrecisionEdit - Database
	-------------------------------------------------------------------------
	A deliberately tiny saved-variable layer. PrecisionEdit is a positioning
	tool, not a UI suite, so there are no per-character profiles - Blizzard's
	own Edit Mode layouts already own that concern. We keep one account-wide
	settings table (`PrecisionEditDB`) for our panel's behaviour and position.

	Modules register defaults at file-run time via `ns:RegisterDefaults`, then
	read/write through `ns.db` once it is built on ADDON_LOADED.
--]]

local _, ns = ...
local F = ns.F

ns.defaults = { db = {} }

--- Merge a table of defaults into the master default tree (before the DB is
--- built), e.g. ns:RegisterDefaults({ panel = { locked = false } }).
function ns:RegisterDefaults(defaults)
	F.CopyDefaults(defaults, ns.defaults.db)
end

-- ---------------------------------------------------------------------------
-- Setup (called by the engine on ADDON_LOADED, before module OnInitialize).
-- ---------------------------------------------------------------------------
function ns:SetupDatabase()
	-- nil on a fresh install; create the skeleton then fill defaults.
	local root = _G.PrecisionEditDB or {}
	_G.PrecisionEditDB = root
	ns.db = F.CopyDefaults(ns.defaults.db, root)
end
