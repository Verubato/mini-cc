local fw = require("framework")
local profileLoader = require("profile_loader")

fw.describe("Targeted schema migrations", function()
	fw.it("v18 retains the correctly-cased CC modules and healer battleground setting", function()
		local env = profileLoader.new({ Version = 55 })
		local vars = {
			Version = 17,
			WhatsNew = {},
			NotifiedChanges = true,
			Default = {
				Enabled = true,
				SimpleMode = { Grow = "RIGHT", Offset = { X = 1, Y = 2 } },
			},
			Raid = {
				Enabled = false,
				SimpleMode = { Grow = "LEFT", Offset = { X = 3, Y = 4 } },
			},
			Healer = {
				Enabled = true,
				Filters = { Arena = false, BattleGrounds = true },
			},
		}
		fw.truthy(env.migrator:UpgradeToVersion18(vars), "migration result")
		fw.not_nil(vars.Modules.CCModule, "CCModule")
		fw.not_nil(vars.Modules.HealerCCModule, "HealerCCModule")
		fw.eq(vars.Modules.HealerCCModule.Enabled.Raids, true, "healer battleground flag")
		fw.eq(vars.Version, 18, "version")
	end)

	fw.it("v23 preserves keys required by later migrations", function()
		local env = profileLoader.new({ Version = 55 })
		local vars = {
			Version = 22,
			WhatsNew = {},
			NotifiedChanges = true,
			Modules = {
				AlertsModule = {},
				CCModule = { Enabled = { Always = true, Raids = false } },
				NameplatesModule = {
					Enemy = { CC = { Enabled = true }, Combined = { Enabled = false } },
				},
			},
		}
		fw.truthy(env.migrator:UpgradeToVersion23(vars), "migration result")
		fw.eq(vars.Modules.CCModule.Enabled.Always, true, "Always retained")
		fw.not_nil(vars.Modules.NameplatesModule.Enemy.CC, "CC section retained")
		fw.not_nil(vars.Modules.NameplatesModule.Enemy.Combined, "Combined section retained")
	end)

	fw.it("v26 keeps deferred scale work through the full migration chain", function()
		local env = profileLoader.new({
			Version = 25,
			WhatsNew = {},
			NotifiedChanges = true,
			Modules = {
				CCModule = {
					Enabled = { Always = true, Arena = true, Raids = false, Dungeons = true },
					Default = { Icons = { Size = 20 } },
					Raid = { Icons = { Size = 10 } },
				},
				PetCCModule = {
					Enabled = { Always = false, Arena = false, Raids = false, Dungeons = false },
					Icons = { Size = 8 },
				},
			},
		})
		local db = env.migrator:GetAndUpgradeDb()
		fw.eq(db.PendingScaleMigration26, true, "deferred flag")
		UIParent = { GetScale = function() return 1.5 end }
		fw.truthy(env.migrator:RunDeferredMigrations(db), "deferred migration ran")
		fw.eq(db.Modules.CCModule.Default.Icons.Size, 30, "default icon size")
		fw.eq(db.Modules.CCModule.Raid.Icons.Size, 15, "raid icon size")
		fw.eq(db.Modules.PetCCModule.Icons.Size, 12, "pet icon size")
		fw.is_nil(db.PendingScaleMigration26, "flag cleared")
	end)

	fw.it("v49 carries false ColorByDispelType preferences into generic bars", function()
		local env = profileLoader.new({ Version = 55 })
		local vars = {
			Version = 48,
			Modules = {
				NameplatesModule = {
					Enemy = {
						CC = { Icons = { ColorByDispelType = false } },
						Combined = { Icons = { ColorByDispelType = false } },
					},
				},
			},
		}
		fw.truthy(env.migrator:UpgradeToVersion49(vars), "migration result")
		fw.eq(vars.Modules.NameplatesModule.Enemy.Bar1.Icons.ColorByCategory, false, "bar 1")
		fw.eq(vars.Modules.NameplatesModule.Enemy.Bar2.Icons.ColorByCategory, false, "bar 2")
		fw.is_nil(vars.Modules.NameplatesModule.Enemy.CC, "old CC removed")
		fw.is_nil(vars.Modules.NameplatesModule.Enemy.Combined, "old Combined removed")
	end)
end)
