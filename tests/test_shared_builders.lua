local fw = require("framework")

local function makeFrame(kind, frames)
	local frame = { kind = kind, shown = true, scripts = {} }
	frames[#frames + 1] = frame
	function frame:SetPoint() end
	function frame:SetWidth(value) self.width = value end
	function frame:SetHeight(value) self.height = value end
	function frame:SetSize(w, h) self.width, self.height = w, h end
	function frame:Hide() self.shown = false end
	function frame:Show() self.shown = true end
	function frame:SetShown(value) self.shown = value end
	function frame:SetBackdrop() end
	function frame:SetBackdropColor() end
	function frame:SetScript(name, fn) self.scripts[name] = fn end
	function frame:SetAllPoints() end
	function frame:SetColorTexture() end
	function frame:SetText(value) self.text = value end
	function frame:SetTextColor() end
	function frame:SetTexture() end
	function frame:SetTexCoord() end
	function frame:CreateTexture()
		return makeFrame("Texture", frames)
	end
	function frame:CreateFontString()
		return makeFrame("FontString", frames)
	end
	return frame
end

local function loadBuilder()
	local frames = {}
	local checkboxes = {}

	LocalizedClassList = function()
		return { DEATHKNIGHT = "Death Knight", MAGE = "Mage" }
	end
	RAID_CLASS_COLORS = {
		DEATHKNIGHT = { r = 1, g = 0, b = 0 },
		MAGE = { r = 0, g = 0.5, b = 1 },
	}
	C_Spell = {
		GetSpellName = function(id)
			return ({ [101] = "Shared", [102] = "Unique", [103] = "Shared" })[id]
		end,
		GetSpellTexture = function(id) return id + 1000 end,
	}
	GameTooltip = { SetOwner = function() end, SetSpellByID = function() end, Show = function() end, Hide = function() end }
	CreateFrame = function(kind) return makeFrame(kind, frames) end

	local mini = {}
	function mini:Checkbox(options)
		local checkbox = makeFrame("Checkbox", frames)
		checkbox.options = options
		checkboxes[#checkboxes + 1] = checkbox
		return checkbox
	end
	local addon = { Core = { Framework = mini }, Config = {} }
	local fn, err = loadfile("src/Config/SharedBuilders.lua")
	if not fn then error(err) end
	fn("MiniCC", addon)
	return addon.Config.SharedBuilders, frames, checkboxes
end

fw.describe("Shared config builders", function()
	fw.it("keeps spell handlers bound to the correct spell and disambiguates names", function()
		local builder, _, checkboxes = loadBuilder()
		local disabled = {}
		local changed = 0
		local parent = makeFrame("Parent", {})
		local height = builder.BuildClassSpellList(parent, disabled, function()
			return { DEATHKNIGHT = { 101, 102 }, MAGE = { 103 } }
		end, function() changed = changed + 1 end)

		fw.eq(#checkboxes, 3, "checkbox count")
		fw.eq(checkboxes[1].options.LabelText, "Shared (101)", "first duplicate label")
		fw.eq(checkboxes[2].options.LabelText, "Unique", "unique label")
		fw.eq(checkboxes[3].options.LabelText, "Shared (103)", "second duplicate label")
		checkboxes[1].options.SetValue(false)
		checkboxes[3].options.SetValue(false)
		fw.eq(disabled[101], true, "first spell")
		fw.eq(disabled[103], true, "third spell")
		fw.eq(changed, 2, "change callbacks")
		fw.eq(height, 52, "content height")
	end)
end)
