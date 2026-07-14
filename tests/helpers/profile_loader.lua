-- Loads ProfileManager and Migrator with a small SavedVariables-compatible
-- framework. The goal is to exercise the real profile/migration code without a
-- running WoW client.

local M = {}

local function deepCopy(value, seen)
	if type(value) ~= "table" then return value end
	seen = seen or {}
	if seen[value] then return seen[value] end
	local copy = {}
	seen[value] = copy
	for k, v in pairs(value) do
		copy[k] = deepCopy(v, seen)
	end
	return copy
end

local function copyDefaults(src, dst, seen)
	if type(dst) ~= "table" then dst = {} end
	seen = seen or {}
	if seen[src] then return seen[src] end
	seen[src] = dst
	for k, v in pairs(src) do
		if type(v) == "table" then
			dst[k] = copyDefaults(v, dst[k], seen)
		elseif dst[k] == nil then
			dst[k] = v
		end
	end
	return dst
end

local function cleanTable(target, template, cleanValues, recurse, seen)
	if type(target) ~= "table" or type(template) ~= "table" then return end
	seen = seen or {}
	if seen[target] then return end
	seen[target] = true
	for key, value in pairs(target) do
		local templateValue = template[key]
		if cleanValues and templateValue == nil then
			target[key] = nil
		elseif cleanValues and type(value) == "table" and type(templateValue) ~= "table" then
			target[key] = templateValue
		elseif recurse and type(value) == "table" and type(templateValue) == "table" then
			cleanTable(value, templateValue, cleanValues, recurse, seen)
		end
	end
end

local function loadAddonFile(path, addon)
	local fn, err = loadfile(path)
	if not fn then error(err) end
	return fn("MiniCC", addon)
end

function M.new(savedVars)
	MiniCCDB = savedVars

	local notifications = {}
	local eventFrames = {}
	local refreshCount = 0

	UnitName = function() return "Tester" end
	GetRealmName = function() return "ExampleRealm" end
	GetSpecialization = function() return 1 end
	GetSpecializationInfo = function() return 71 end
	InCombatLockdown = function() return false end
	CreateFrame = function()
		local frame = { scripts = {}, events = {} }
		function frame:SetScript(name, fn) self.scripts[name] = fn end
		function frame:RegisterEvent(name) self.events[name] = true end
		eventFrames[#eventFrames + 1] = frame
		return frame
	end

	local framework = {}
	function framework:GetSavedVars(defaults)
		MiniCCDB = MiniCCDB or {}
		if defaults then return copyDefaults(defaults, MiniCCDB) end
		return MiniCCDB
	end
	function framework:CopyTable(src, dst)
		return copyDefaults(src, dst)
	end
	function framework:CopyValueOrTable(value)
		return deepCopy(value)
	end
	function framework:CleanTable(target, template, cleanValues, recurse)
		cleanTable(target, template, cleanValues, recurse)
	end
	function framework:Notify(message, ...)
		notifications[#notifications + 1] = string.format(message, ...)
	end

	local addon = {
		Core = { Framework = framework },
		Utils = {
			Scheduler = {
				RunWhenCombatEnds = function(_, fn) fn() end,
			},
		},
		Config = {},
		L = setmetatable({}, { __index = function(_, key) return key end }),
	}
	function addon:Refresh() refreshCount = refreshCount + 1 end

	loadAddonFile("src/Core/ProfileManager.lua", addon)
	loadAddonFile("src/Config/Migrator.lua", addon)

	return {
		addon = addon,
		framework = framework,
		profileManager = addon.Core.ProfileManager,
		migrator = addon.Config.Migrator,
		notifications = notifications,
		eventFrames = eventFrames,
		getDb = function() return MiniCCDB end,
		getRefreshCount = function() return refreshCount end,
	}
end

return M
