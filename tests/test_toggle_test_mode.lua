local fw = require("framework")

local function loadAddon(rememberedRaid)
	local startedWith
	local refreshes = 0
	local testModeManager = {
		IsActive = function() return false end,
		StartTesting = function(_, value) startedWith = value end,
		StopTesting = function() end,
	}
	local addon = {
		L = setmetatable({}, { __index = function(_, key) return key end }),
		Core = {
			Framework = {
				WaitForAddonLoad = function() end,
			},
		},
		Utils = {},
		Modules = {
			TestModeManager = testModeManager,
			Cooldowns = {},
		},
		Config = {},
	}
	local fn, err = loadfile("src/MiniCC.lua")
	if not fn then error(err) end
	fn("MiniCC", addon)
	addon.CurrentTestIsRaid = rememberedRaid
	function addon:Refresh() refreshes = refreshes + 1 end
	return addon, function() return startedWith end, function() return refreshes end
end

fw.describe("Test mode selection", function()
	fw.it("honors an explicit false even when the remembered mode is raid", function()
		local addon, startedWith, refreshes = loadAddon(true)
		addon:ToggleTest(false)
		fw.eq(startedWith(), false, "requested mode")
		fw.eq(refreshes(), 1, "refresh")
	end)

	fw.it("uses the remembered mode only when no argument is supplied", function()
		local addon, startedWith = loadAddon(true)
		addon:ToggleTest(nil)
		fw.eq(startedWith(), true, "remembered mode")
	end)
end)
