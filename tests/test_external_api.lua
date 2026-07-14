local fw = require("framework")

local function loadApi()
	MiniCCApi = nil
	local forwarded = {}
	local addon = {
		Modules = {
			FriendlyCooldowns = {
				Module = {
					RegisterPredictedCallback = function(_, fn) forwarded.predicted = fn end,
					RegisterMatchedCallback = function(_, fn) forwarded.matched = fn end,
				},
			},
		},
		Core = {
			Frames = {
				RegisterProvider = function(_, provider) forwarded.provider = provider end,
			},
		},
	}
	local fn, err = loadfile("src/Api/v1.lua")
	if not fn then error(err) end
	fn("MiniCC", addon)
	return MiniCCApi.v1, forwarded
end

fw.describe("MiniCC external API v1", function()
	fw.it("rejects non-function callback registrations at the API boundary", function()
		local api, forwarded = loadApi()
		local okPredicted = pcall(function() api:RegisterPredictedCallback("bad") end)
		local okMatched = pcall(function() api:RegisterMatchedCallback({}) end)
		fw.falsy(okPredicted, "predicted callback")
		fw.falsy(okMatched, "matched callback")
		fw.is_nil(forwarded.predicted, "invalid predicted not forwarded")
		fw.is_nil(forwarded.matched, "invalid matched not forwarded")
	end)

	fw.it("forwards valid callbacks and frame providers unchanged", function()
		local api, forwarded = loadApi()
		local predicted = function() end
		local matched = function() end
		local provider = { Name = "Test", GetFrames = function() return {} end }
		api:RegisterPredictedCallback(predicted)
		api:RegisterMatchedCallback(matched)
		api:RegisterFrameProvider(provider)
		fw.eq(forwarded.predicted, predicted, "predicted")
		fw.eq(forwarded.matched, matched, "matched")
		fw.eq(forwarded.provider, provider, "provider")
	end)
end)
