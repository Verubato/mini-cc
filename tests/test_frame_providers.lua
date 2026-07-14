local fw = require("framework")

local function loadFrames()
	local notifications = {}
	local timers = {}
	local refreshCount = 0

	MAX_PARTY_MEMBERS = 4
	MAX_RAID_MEMBERS = 40
	C_Timer = {
		After = function(_, fn) timers[#timers + 1] = fn end,
	}

	local addon = {
		Core = {
			Framework = {
				Notify = function(_, message, ...)
					notifications[#notifications + 1] = string.format(message, ...)
				end,
			},
		},
		Utils = { Array = {}, Units = {}, WoWEx = {} },
	}
	function addon:Refresh() refreshCount = refreshCount + 1 end

	local fn, err = loadfile("src/Core/Frames.lua")
	if not fn then error(err) end
	fn("MiniCC", addon)

	return {
		frames = addon.Core.Frames,
		notifications = notifications,
		timers = timers,
		getRefreshCount = function() return refreshCount end,
	}
end

fw.describe("External frame providers", function()
	fw.it("surfaces invalid and duplicate registrations", function()
		local env = loadFrames()
		env.frames:RegisterProvider(nil)
		env.frames:RegisterProvider({ Name = "" })
		env.frames:RegisterProvider({ Name = "MissingGetter" })
		local provider = { Name = "Valid", GetFrames = function() return {} end }
		env.frames:RegisterProvider(provider)
		env.frames:RegisterProvider(provider)
		fw.eq(#env.notifications, 4, "rejection notifications")
	end)

	fw.it("coalesces a burst of provider refresh requests into one refresh", function()
		local env = loadFrames()
		local requestRefresh
		env.frames:RegisterProvider({
			Name = "Chatty",
			GetFrames = function() return {} end,
			RegisterRefreshFrames = function(cb) requestRefresh = cb end,
		})
		requestRefresh()
		requestRefresh()
		requestRefresh()
		fw.eq(#env.timers, 1, "scheduled timers")
		fw.eq(env.getRefreshCount(), 0, "refresh deferred")
		env.timers[1]()
		fw.eq(env.getRefreshCount(), 1, "coalesced refresh")
	end)

	fw.it("isolates provider getter failures and filters forbidden frames", function()
		local env = loadFrames()
		env.frames:RegisterProvider({ Name = "Broken", GetFrames = function() error("boom") end })
		env.frames:RegisterProvider({
			Name = "Mixed",
			GetFrames = function()
				return {
					{ IsForbidden = function() return false end, IsVisible = function() return true end },
					{ IsForbidden = function() return true end, IsVisible = function() return true end },
					{ IsForbidden = function() return false end, IsVisible = function() return false end },
				}
			end,
		})
		local frames = env.frames:ExternalFrames(true)
		fw.eq(#frames, 1, "eligible frames")
	end)
end)
