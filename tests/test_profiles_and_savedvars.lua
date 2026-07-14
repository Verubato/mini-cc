local fw = require("framework")
local profileLoader = require("profile_loader")

local CURRENT_VERSION = 55

fw.describe("SavedVariables and stored profiles", function()
	fw.it("repairs scalar profile machinery before ProfileManager initializes", function()
		local env = profileLoader.new({
			Version = CURRENT_VERSION,
			Profiles = "corrupt",
			AutoSwitch = 42,
			ActiveProfile = {},
		})
		local db = env.migrator:GetAndUpgradeDb()
		local ok, err = pcall(function() env.profileManager:Init() end)
		fw.truthy(ok, err)
		fw.eq(type(db.Profiles), "table", "Profiles repaired")
		fw.eq(type(db.AutoSwitch), "table", "AutoSwitch repaired")
		fw.eq(db.ActiveProfile, "Default", "active profile repaired")
		fw.not_nil(db.Profiles.Default, "default profile created")
	end)

	fw.it("repairs non-finite top-level schema versions", function()
		local nan = 0 / 0
		local env = profileLoader.new({ Version = nan, FontScale = 1.25 })
		local db = env.migrator:GetAndUpgradeDb()
		fw.eq(db.Version, CURRENT_VERSION, "schema version")
		fw.not_nil(db.MigrationBackup, "corrupt data backup")
		fw.eq(db.MigrationBackup.FontScale, 1.25, "backup retains settings")
	end)

	fw.it("sanitizes stored payload values before applying a profile", function()
		local nan = 0 / 0
		local env = profileLoader.new({
			Version = CURRENT_VERSION,
			Profiles = {
				Default = { Version = CURRENT_VERSION, FontScale = 1 },
				Broken = {
					Version = nan,
					FontScale = "not-a-number",
					GlowType = {},
					Modules = "not-a-table",
					UnknownInternalKey = "must not survive",
				},
			},
			ActiveProfile = "Default",
			AutoSwitch = {},
		})
		local db = env.migrator:GetAndUpgradeDb()
		env.profileManager:Init()
		env.profileManager:SwitchProfile("Broken")
		fw.eq(db.ActiveProfile, "Broken", "switched profile")
		fw.eq(type(db.FontScale), "number", "FontScale repaired")
		fw.eq(type(db.GlowType), "string", "GlowType repaired")
		fw.eq(type(db.Modules), "table", "Modules repaired")
		fw.no_key(db.Profiles.Broken, "UnknownInternalKey", "unknown payload key")
		fw.eq(db.Profiles.Broken.Version, CURRENT_VERSION, "payload stamp")
	end)

	fw.it("handles malformed auto-switch entries through the public methods", function()
		local env = profileLoader.new({
			Version = CURRENT_VERSION,
			Profiles = { Default = { Version = CURRENT_VERSION } },
			ActiveProfile = "Default",
			AutoSwitch = { ["Tester-ExampleRealm"] = "corrupt" },
		})
		env.migrator:GetAndUpgradeDb()
		env.profileManager:Init()
		local ok, err = pcall(function()
			env.profileManager:SetAutoSwitchRule(71, "Default")
		end)
		fw.truthy(ok, err)
		fw.eq(env.profileManager:GetAutoSwitchRule(71), "Default", "stored rule")
	end)

	fw.it("terminates when an imported payload contains a cycle", function()
		local env = profileLoader.new({ Version = CURRENT_VERSION })
		local cyclic = { Version = CURRENT_VERSION }
		cyclic.Modules = cyclic
		local ok, sanitized = pcall(function()
			return env.migrator:SanitizeProfilePayload(cyclic)
		end)
		fw.truthy(ok, sanitized)
		fw.eq(type(sanitized), "table", "sanitized payload")
	end)
end)
