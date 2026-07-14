local fw = require("framework")

local function loadTalents(db)
	time = function() return 100000 end
	LibStub = nil
	GetPvpTalentInfoByID = function(id) return id == 101 and {} or nil end
	CreateFrame = function()
		return { SetScript = function() end, RegisterEvent = function() end }
	end

	local addon = {
		Core = {
			Framework = { GetSavedVars = function() return db end },
			InspectorFacade = { GetUnitSpecId = function() return nil end },
		},
		Modules = {
			Cooldowns = {
				PvPTalentSync = { RegisterCallback = function() end },
			},
		},
	}
	local fn, err = loadfile("src/Modules/Cooldowns/Talents.lua")
	if not fn then error(err) end
	fn("MiniCC", addon)
	return addon.Modules.Cooldowns.Talents
end

fw.describe("Persisted talent cache validation", function()
	fw.it("drops non-finite timestamps and invalid PvP talent ids without aborting init", function()
		local nan = 0 / 0
		local db = {
			TalentCache = {
				BadTime = { Time = nan, SpecId = 71, TalentString = "anything" },
			},
			PvPTalentCache = {
				BadNaN = { Time = 100000, Ids = { nan } },
				BadUnknown = { Time = 100000, Ids = { 999 } },
				Good = { Time = 100000, Ids = { 101 } },
			},
		}
		local talents = loadTalents(db)
		local ok, err = pcall(function() talents:Init() end)
		fw.truthy(ok, err)
		fw.is_nil(db.TalentCache.BadTime, "NaN time")
		fw.is_nil(db.PvPTalentCache.BadNaN, "NaN id")
		fw.is_nil(db.PvPTalentCache.BadUnknown, "unknown id")
		fw.not_nil(db.PvPTalentCache.Good, "known id")
	end)
end)
