local fw = require("framework")

local function loadScheduler()
	local eventHandler
	local errors = {}
	local inCombat = true

	InCombatLockdown = function() return inCombat end
	geterrorhandler = function()
		return function(err) errors[#errors + 1] = tostring(err) end
	end
	CreateFrame = function()
		local frame = {}
		function frame:SetScript(_, fn) eventHandler = fn end
		function frame:RegisterEvent() end
		return frame
	end

	local addon = { Utils = {} }
	local fn, err = loadfile("src/Utils/Scheduler.lua")
	if not fn then error(err) end
	fn("MiniCC", addon)
	addon.Utils.Scheduler:Init()

	return {
		scheduler = addon.Utils.Scheduler,
		fireCombatEnd = function() eventHandler(nil, "PLAYER_REGEN_ENABLED") end,
		setCombat = function(value) inCombat = value end,
		errors = errors,
	}
end

fw.describe("Scheduler combat-end queue", function()
	fw.it("isolates a failing callback and never replays the drained queue", function()
		local env = loadScheduler()
		local calls = 0
		env.scheduler:RunWhenCombatEnds(function() error("expected test failure") end)
		env.scheduler:RunWhenCombatEnds(function() calls = calls + 1 end)

		local ok, err = pcall(env.fireCombatEnd)
		fw.truthy(ok, err)
		fw.eq(calls, 1, "later callback ran")
		fw.eq(#env.errors, 1, "error reported")

		env.fireCombatEnd()
		fw.eq(calls, 1, "queue did not replay")
		fw.eq(#env.errors, 1, "failure did not replay")
	end)

	fw.it("defers work queued by a draining callback until the next event", function()
		local env = loadScheduler()
		local calls = {}
		env.scheduler:RunWhenCombatEnds(function()
			calls[#calls + 1] = "first"
			env.scheduler:RunWhenCombatEnds(function()
				calls[#calls + 1] = "second"
			end)
		end)

		env.fireCombatEnd()
		fw.eq(#calls, 1, "first drain")
		env.fireCombatEnd()
		fw.eq(#calls, 2, "second drain")
		fw.eq(calls[2], "second", "deferred callback")
	end)
end)
