---@type string, Addon
local _, addon = ...
local eventsFrame
---@class SchedulerUtil
local M = {}
addon.Utils.Scheduler = M

local combatEndCallbacks = {}
local combatEndKeyedCallbacks = {}

local function OnCombatEnded()
	-- Swap the queues into locals and reset the module tables before iterating:
	-- an error mid-loop must not leave already-run callbacks queued for replay on
	-- the next combat end, and callbacks that re-schedule work need a fresh queue.
	local callbacks = combatEndCallbacks
	local keyedCallbacks = combatEndKeyedCallbacks
	combatEndCallbacks = {}
	combatEndKeyedCallbacks = {}

	for _, callback in ipairs(callbacks) do
		xpcall(callback, geterrorhandler())
	end

	for _, callback in pairs(keyedCallbacks) do
		xpcall(callback, geterrorhandler())
	end
end

local function OnEvent(_, event)
	if event == "PLAYER_REGEN_ENABLED" then
		OnCombatEnded()
	end
end

---Invokes the callback once combat ends.
---@param key string? an optional key which will ensure only the latest callback provided with the same key will be executed.
---@param callback fun()
function M:RunWhenCombatEnds(callback, key)
	if not callback then
		return
	end

	if not InCombatLockdown() then
		callback()
		return
	end

	if key then
		combatEndKeyedCallbacks[key] = callback
	else
		combatEndCallbacks[#combatEndCallbacks + 1] = callback
	end
end

function M:Init()
	eventsFrame = CreateFrame("Frame")
	eventsFrame:SetScript("OnEvent", OnEvent)
	eventsFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
	eventsFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
end
