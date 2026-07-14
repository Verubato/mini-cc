local fw = require("framework")

local function loadSync(registerResult)
	local printed = {}
	local registeredEvents = {}
	local eventHandler
	local originalPrint = print

	print = function(message) printed[#printed + 1] = message end
	UnitNameUnmodified = function() return "Tester" end
	IsInGroup = function() return false end
	Ambiguate = function(name) return name end
	issecretvalue = function() return false end
	securecallfunction = function(fn, ...) return fn(...) end
	C_SpecializationInfo = { GetAllSelectedPvpTalentIDs = function() return {} end }
	C_ChatInfo = {
		RegisterAddonMessagePrefix = function() return registerResult end,
		SendAddonMessage = function() return 0 end,
	}
	C_Timer = { NewTimer = function(_, fn) return { fn = fn } end }
	CreateFrame = function()
		local frame = {}
		function frame:SetScript(_, fn) eventHandler = fn end
		function frame:RegisterEvent(event) registeredEvents[event] = true end
		return frame
	end

	local addon = { Modules = { Cooldowns = {} }, Utils = {} }
	local fn, err = loadfile("src/Modules/Cooldowns/PvPTalentSync.lua")
	if not fn then error(err) end
	fn("MiniCC", addon)
	print = originalPrint
	return addon.Modules.Cooldowns.PvPTalentSync, printed, registeredEvents, eventHandler
end

fw.describe("PvP talent sync prefix registration", function()
	fw.it("accepts the retail API's true result without a false disabled warning", function()
		local _, printed, events = loadSync(true)
		fw.eq(#printed, 0, "warnings")
		fw.eq(events.CHAT_MSG_ADDON, true, "chat event registered")
	end)

	fw.it("disables remote chat handling when registration returns false", function()
		local sync, printed, events = loadSync(false)
		local calls = 0
		sync:RegisterCallback(function() calls = calls + 1 end)
		sync:RequestSync()
		fw.eq(#printed, 1, "warning")
		fw.is_nil(events.CHAT_MSG_ADDON, "chat event")
		fw.eq(calls, 1, "local callback remains available")
	end)
end)
