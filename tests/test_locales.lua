local fw = require("framework")

local function loadLocales()
	wipe = function(t) for k in pairs(t) do t[k] = nil end end
	local addon = {}
	local localeFn, err = loadfile("src/Locales/Locale.lua")
	if not localeFn then error(err) end
	localeFn("MiniCC", addon)

	local registered = {}
	local defaults = {}
	local registerLocale = addon.L.RegisterLocale
	local setDefaults = addon.L.SetDefaultStrings
	function addon.L:RegisterLocale(key, strings)
		registered[key] = strings
		return registerLocale(self, key, strings)
	end
	function addon.L:SetDefaultStrings(strings)
		for key, value in pairs(strings) do defaults[key] = value end
		return setDefaults(self, strings)
	end

	for _, locale in ipairs({
		"enUS", "deDE", "esES", "esMX", "frFR", "itIT",
		"ptBR", "ruRU", "koKR", "zhCN", "zhTW",
	}) do
		local fn, loadErr = loadfile("src/Locales/" .. locale .. ".lua")
		if not fn then error(loadErr) end
		fn("MiniCC", addon)
	end
	return addon.L, registered, defaults
end

fw.describe("Localization registry", function()
	fw.it("lists one English choice while retaining the enGB alias", function()
		local L, registered = loadLocales()
		fw.not_nil(registered.enGB, "enGB alias")
		local available = L:GetAvailableLocales()
		fw.eq(#available, 11, "dropdown locale count")
		for _, entry in ipairs(available) do
			fw.neq(entry.Key, "enGB", "duplicate English dropdown entry")
		end
	end)

	fw.it("keeps re-keyed descriptions aligned across every translated locale", function()
		local _, registered = loadLocales()
		local keys = {
			"Shows CC and defensive auras as one set of icons on party/raid frames.",
			"Shows CC, defensives, and other important spells on the player/target/focus portraits.",
			"Shows enemy arena opponent defensive cooldowns after their buffs expire.",
		}
		for _, locale in ipairs({ "deDE", "esES", "esMX", "frFR", "itIT", "ptBR", "ruRU", "koKR", "zhCN", "zhTW" }) do
			for _, key in ipairs(keys) do
				fw.not_nil(registered[locale][key], locale .. ": " .. key)
			end
		end
	end)

end)
