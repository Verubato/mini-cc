---@type string, Addon
local _, addon = ...
local mini = addon.Core.Framework
local config = addon.Config

---@class ConfigSharedBuilders
local M = {}
config.SharedBuilders = M

local classDisplayNames = LocalizedClassList()

local classOrder = {
	"DEATHKNIGHT", "DEMONHUNTER", "DRUID", "EVOKER", "HUNTER",
	"MAGE", "MONK", "PALADIN", "PRIEST", "ROGUE",
	"SHAMAN", "WARLOCK", "WARRIOR",
}

---Builds a Spells tab: a vertical class tab sidebar on the left, with the
---selected class's spell checkboxes on the right. Shared by the enemy and
---friendly cooldown tracker panels, which differ only in how spells are
---collected and what refreshes after a toggle.
---@param parent table  the spells sub-frame (already sized)
---@param disabledSpells table<number, boolean>  module DisabledSpells hash, modified in place
---@param collectSpells fun(): table<string, number[]>  classToken -> ordered spell IDs
---@param onChanged fun()  called after a checkbox toggles a spell
---@return number  total content height in pixels
function M.BuildClassSpellList(parent, disabledSpells, collectSpells, onChanged)
	local sidebarW    = 120
	local sidebarSep  = 8
	local classTabH   = 24
	local classTabGap = 1
	local rowH   = 26
	local iconSz = 18

	local classSpells = collectSpells()

	-- Disambiguation: spell names shared across any class get the spell ID appended.
	local nameCounts = {}
	for _, classToken in ipairs(classOrder) do
		local spells = classSpells[classToken]
		if spells then
			for _, spellId in ipairs(spells) do
				local name = C_Spell.GetSpellName(spellId)
				if name then nameCounts[name] = (nameCounts[name] or 0) + 1 end
			end
		end
	end

	-- Sidebar
	local sidebar = CreateFrame("Frame", nil, parent)
	sidebar:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
	sidebar:SetWidth(sidebarW)

	-- Build per-class spell panels (all parented to parent, shown/hidden on tab select)
	local classPanels = {}
	local maxContentH = 0
	local contentOffsetX = sidebarW + sidebarSep

	for _, classToken in ipairs(classOrder) do
		local spells = classSpells[classToken]
		if spells and #spells > 0 then
			local classPanel = CreateFrame("Frame", nil, parent)
			classPanel:SetPoint("TOPLEFT",  parent, "TOPLEFT",  contentOffsetX, 0)
			classPanel:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
			classPanel:Hide()
			classPanels[classToken] = classPanel

			local y = 0
			for _, spellId in ipairs(spells) do
				local spellName = C_Spell.GetSpellName(spellId) or ("Spell #" .. spellId)
				if nameCounts[spellName] and nameCounts[spellName] > 1 then
					spellName = spellName .. " (" .. spellId .. ")"
				end
				local texture = C_Spell.GetSpellTexture(spellId)

				local chk = mini:Checkbox({
					Parent    = classPanel,
					LabelText = spellName,
					GetValue  = function() return not disabledSpells[spellId] end,
					SetValue  = function(value)
						if value then
							disabledSpells[spellId] = nil
						else
							disabledSpells[spellId] = true
						end
						onChanged()
					end,
				})
				chk:SetPoint("TOPLEFT", classPanel, "TOPLEFT", 26, y)

				if texture then
					local iconBtn = CreateFrame("Button", nil, classPanel)
					iconBtn:SetSize(iconSz, iconSz)
					iconBtn:SetPoint("RIGHT", chk, "LEFT", -2, 0)
					iconBtn:SetScript("OnEnter", function(self)
						GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
						GameTooltip:SetSpellByID(spellId)
						GameTooltip:Show()
					end)
					iconBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
					local icon = iconBtn:CreateTexture(nil, "ARTWORK")
					icon:SetAllPoints()
					icon:SetTexture(texture)
					icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
				end

				y = y - rowH
			end

			local h = -y
			classPanel:SetHeight(h)
			maxContentH = math.max(maxContentH, h)
		end
	end

	-- Build vertical class tab buttons
	local classTabBtns = {}

	local function SetClassTabSelected(entry, selected)
		if selected then
			entry.btn:SetBackdropColor(0.15, 0.15, 0.15, 0.9)
			entry.accent:SetColorTexture(entry.r, entry.g, entry.b, 1)
		else
			entry.btn:SetBackdropColor(0, 0, 0, 0)
			entry.accent:SetColorTexture(entry.r, entry.g, entry.b, 0)
		end
	end

	local function SelectClass(classToken)
		for _, entry in ipairs(classTabBtns) do
			local isSelected = entry.classToken == classToken
			SetClassTabSelected(entry, isSelected)
			if classPanels[entry.classToken] then
				classPanels[entry.classToken]:SetShown(isSelected)
			end
		end
	end

	local tabY = 0
	local firstClass = nil
	for _, classToken in ipairs(classOrder) do
		local spells = classSpells[classToken]
		if spells and #spells > 0 then
			if not firstClass then firstClass = classToken end

			local cc = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
			local r = cc and cc.r or 1
			local g = cc and cc.g or 1
			local b = cc and cc.b or 0.8

			local btn = CreateFrame("Button", nil, sidebar, "BackdropTemplate")
			btn:SetHeight(classTabH)
			btn:SetPoint("TOPLEFT",  sidebar, "TOPLEFT",  0, tabY)
			btn:SetPoint("TOPRIGHT", sidebar, "TOPRIGHT", 0, tabY)
			btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
			btn:SetBackdropColor(0, 0, 0, 0)

			local accent = btn:CreateTexture(nil, "OVERLAY")
			accent:SetWidth(2)
			accent:SetPoint("TOPLEFT",    btn, "TOPLEFT",    0, 0)
			accent:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
			accent:SetColorTexture(r, g, b, 0)

			local hl = btn:CreateTexture(nil, "HIGHLIGHT")
			hl:SetAllPoints()
			hl:SetColorTexture(1, 1, 1, 0.05)

			local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			fs:SetPoint("LEFT", btn, "LEFT", 8, 0)
			fs:SetText(classDisplayNames[classToken] or classToken)
			fs:SetTextColor(r, g, b, 1)

			local token = classToken
			btn:SetScript("OnClick", function() SelectClass(token) end)

			table.insert(classTabBtns, { btn = btn, accent = accent, classToken = classToken, r = r, g = g, b = b })
			tabY = tabY - classTabH - classTabGap
		end
	end

	local sidebarH = -tabY
	sidebar:SetHeight(sidebarH)

	if firstClass then SelectClass(firstClass) end

	parent.MiniRefresh = function()
		for _, cp in pairs(classPanels) do
			if cp.MiniRefresh then cp:MiniRefresh() end
		end
	end

	return math.max(sidebarH, maxContentH)
end
