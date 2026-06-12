--[[
	PrecisionEdit - Engine
	-------------------------------------------------------------------------
	Owns the addon namespace, a tiny module system, one shared event
	dispatcher, an internal signal bus and the load lifecycle. Every other
	file receives the namespace from WoW via `local addonName, ns = ...`.

	Design goals (mirrors NexEnhance / the peterodox-patterns rule):
	  * One global only (`_G.PrecisionEdit`); everything else lives on `ns`.
	  * One event frame for the whole addon - modules subscribe through it
	    rather than each creating their own frame.
	  * Mid-dispatch safe event + signal lists (tombstoned slots) so a
	    callback may unregister itself or others while firing.
	  * Clear lifecycle: OnInitialize (DB ready) -> OnEnable (world ready).
--]]

local addonName, ns = ...

_G.PrecisionEdit = ns

local CreateFrame = CreateFrame
local IsLoggedIn = IsLoggedIn
local tinsert = table.insert
local C_AddOns = C_AddOns

-- ---------------------------------------------------------------------------
-- Metadata + sub-namespaces (declared up front so load order never nils out).
-- ---------------------------------------------------------------------------
ns.name = addonName
ns.title = C_AddOns.GetAddOnMetadata(addonName, "Title") or addonName
ns.version = C_AddOns.GetAddOnMetadata(addonName, "Version") or "0.0.0"

ns.C = ns.C or {} -- Constants
ns.F = ns.F or {} -- Functions / helpers
ns.L = ns.L or setmetatable({}, {
	__index = function(_, key)
		return key
	end,
}) -- Locale (falls back to the key itself)

-- ---------------------------------------------------------------------------
-- Module registry
-- ---------------------------------------------------------------------------
local modules = {}
local moduleByName = {}
ns.modules = modules

local moduleMeta = {}
moduleMeta.__index = moduleMeta

--- Register a game event against this module. `handler` is a function or the
--- name of a method on the module; when omitted a method named after the event
--- is used (the common WoW convention). `self` is bound once at registration.
function moduleMeta:RegisterEvent(event, handler)
	handler = handler or self[event]
	if type(handler) == "string" then
		handler = self[handler]
	end
	assert(type(handler) == "function", ("PrecisionEdit: no handler for event '%s' on module '%s'"):format(event, self.name))

	ns:RegisterEvent(event, function(_, ...)
		handler(self, ...)
	end)
end

--- Whether this module is enabled. Modules that opt into the toggle convention
--- store `enable` under `ns.db[dbKey]`; absent a key they default to enabled.
function moduleMeta:IsEnabled()
	if self.dbKey and ns.db and ns.db[self.dbKey] and ns.db[self.dbKey].enable ~= nil then
		return ns.db[self.dbKey].enable
	end
	return true
end

--- Create (or fetch) a module. `dbKey` ties it to a settings table in the DB.
function ns:NewModule(name, dbKey)
	assert(not moduleByName[name], ("PrecisionEdit: module '%s' already exists"):format(name))
	local module = setmetatable({ name = name, dbKey = dbKey }, moduleMeta)
	moduleByName[name] = module
	tinsert(modules, module)
	return module
end

function ns:GetModule(name)
	return moduleByName[name]
end

-- ---------------------------------------------------------------------------
-- Central event dispatcher (one frame, registration-ordered callbacks).
-- ---------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame", "PrecisionEditEventFrame")
local eventCallbacks = {} -- event -> { callback | false, ... }

eventFrame:SetScript("OnEvent", function(_, event, ...)
	local callbacks = eventCallbacks[event]
	if not callbacks then
		return
	end
	-- Tombstoned slots (false) are skipped so a callback may unregister itself
	-- or others mid-dispatch without shifting indices.
	for i = 1, #callbacks do
		local callback = callbacks[i]
		if callback then
			callback(event, ...)
		end
	end
end)

function ns:RegisterEvent(event, callback)
	local callbacks = eventCallbacks[event]
	if not callbacks then
		callbacks = {}
		eventCallbacks[event] = callbacks
		eventFrame:RegisterEvent(event)
	end
	for i = 1, #callbacks do
		if not callbacks[i] then
			callbacks[i] = callback
			return callback
		end
	end
	callbacks[#callbacks + 1] = callback
	return callback
end

function ns:UnregisterEvent(event, callback)
	local callbacks = eventCallbacks[event]
	if not callbacks then
		return
	end
	local anyLive = false
	for i = 1, #callbacks do
		if callbacks[i] == callback then
			callbacks[i] = false
		elseif callbacks[i] then
			anyLive = true
		end
	end
	if not anyLive then
		eventCallbacks[event] = nil
		eventFrame:UnregisterEvent(event)
	end
end

-- ---------------------------------------------------------------------------
-- Internal signal bus (pub/sub) - for addon-internal signals, not game events.
--   ns:RegisterCallback("Selection.Changed", "OnSelection", self)
--   ns:TriggerCallback("Selection.Changed", frame)
-- ---------------------------------------------------------------------------
local signalCallbacks = {} -- signal -> { { callback, owner, isMethod } | false, ... }

function ns:RegisterCallback(signal, callback, owner)
	local list = signalCallbacks[signal]
	if not list then
		list = {}
		signalCallbacks[signal] = list
	end
	list[#list + 1] = { callback, owner, type(callback) == "string" }
	return callback
end

function ns:TriggerCallback(signal, ...)
	local list = signalCallbacks[signal]
	if not list then
		return
	end
	for i = 1, #list do
		local cb = list[i]
		if cb then
			if cb[3] then
				cb[2][cb[1]](cb[2], ...) -- owner:method(...)
			elseif cb[2] then
				cb[1](cb[2], ...) -- func(owner, ...)
			else
				cb[1](...) -- func(...)
			end
		end
	end
end

function ns:UnregisterCallback(signal, callback, owner)
	local list = signalCallbacks[signal]
	if not list then
		return
	end
	local anyLive = false
	for i = 1, #list do
		local cb = list[i]
		if cb and cb[1] == callback and cb[2] == owner then
			list[i] = false
		elseif cb then
			anyLive = true
		end
	end
	if not anyLive then
		signalCallbacks[signal] = nil
	end
end

-- ---------------------------------------------------------------------------
-- Lifecycle: ADDON_LOADED -> Initialize (DB ready) -> PLAYER_LOGIN -> Enable.
--   Flags keep both idempotent and handle a late load where PLAYER_LOGIN
--   already fired.
-- ---------------------------------------------------------------------------
local initialized, enabled = false, false

local function RunCallback(module, method)
	local fn = module[method]
	if type(fn) ~= "function" then
		return
	end
	-- Isolate faults so one broken module can't abort the rest.
	local ok, err = pcall(fn, module)
	if not ok then
		ns.F.Print("|cffff5555Error in", module.name, "(" .. method .. "):|r", err)
	end
end

local function Enable()
	if enabled or not initialized then
		return
	end
	enabled = true
	for i = 1, #modules do
		local module = modules[i]
		if module:IsEnabled() then
			RunCallback(module, "OnEnable")
		end
	end
end

local function Initialize()
	if initialized then
		return
	end
	initialized = true

	if ns.SetupDatabase then
		ns:SetupDatabase()
	end

	for i = 1, #modules do
		RunCallback(modules[i], "OnInitialize")
	end

	if IsLoggedIn() then
		Enable()
	end
end

local onAddonLoaded
onAddonLoaded = function(_, loadedAddon)
	if loadedAddon ~= addonName then
		return
	end
	ns:UnregisterEvent("ADDON_LOADED", onAddonLoaded)
	Initialize()
end

ns:RegisterEvent("ADDON_LOADED", onAddonLoaded)
ns:RegisterEvent("PLAYER_LOGIN", Enable)
