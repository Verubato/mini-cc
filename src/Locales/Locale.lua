---@type string, Addon
local _, addon = ...

---@class Localization
local L = {}
addon.L = L

local strings = {}

-- Default locale (English)
local defaultStrings = {}

-- Registry of all locale strings keyed by locale code
local registry = {}

local localeDisplayNames = {
	["enUS"] = "English",
	["enGB"] = "English",
	["deDE"] = "Deutsch",
	["esES"] = "Español",
	["esMX"] = "Español (México)",
	["frFR"] = "Français",
	["itIT"] = "Italiano",
	["ptBR"] = "Português",
	["koKR"] = "한국어",
	["ruRU"] = "Русский",
	["zhCN"] = "简体中文",
	["zhTW"] = "繁體中文",
}

-- Register a locale's strings for later activation
function L:RegisterLocale(localeKey, stringTable)
	registry[localeKey] = stringTable
end

-- Apply a registered locale as the active strings
function L:ApplyLocale(localeKey)
	wipe(strings)

	local registered = registry[localeKey]
	if registered then
		for key, value in pairs(registered) do
			strings[key] = value
		end
	end
end

-- Return all registered locale codes with display names
function L:GetAvailableLocales()
	local result = {}
	for key in pairs(registry) do
		-- enGB is an alias of enUS (identical strings and display name); listing
		-- both would put two indistinguishable "English" entries in the dropdown.
		if key ~= "enGB" then
			table.insert(result, { Key = key, Name = localeDisplayNames[key] or key })
		end
	end
	table.sort(result, function(a, b)
		return a.Name < b.Name
	end)
	return result
end

-- Set default strings (English)
function L:SetDefaultStrings(stringTable)
	for key, value in pairs(stringTable) do
		defaultStrings[key] = value
	end
end

-- Convenience metatable: L["key"] returns the localized string, falling back to
-- English and then to the key itself.
setmetatable(L, {
	__index = function(t, key)
		if type(key) == "string" then
			return strings[key] or defaultStrings[key] or key
		end
		return rawget(t, key)
	end,
})

function L:GetDisplayName(localeKey)
	return localeDisplayNames[localeKey] or localeKey
end
