---@type string, Addon
local _, addon = ...

---@class InspectorFacade
local M = {}
addon.Core.InspectorFacade = M

---Returns the spec ID for a unit using a best-effort fallback chain:
---  1. FrameSort (most authoritative, real-time)
---  2. Internal Inspector (tooltip + async inspect queue)
---  3. GetArenaOpponentSpec for arena1-9 units
---@param unit string
---@return number|nil
function M:GetUnitSpecId(unit)
	-- The internal Inspector fallback tolerates nil; match that here rather than
	-- erroring on unit:match below.
	if type(unit) ~= "string" then
		return nil
	end

	local fs = FrameSortApi and FrameSortApi.v3
	if fs and fs.Inspector then
		-- Third-party code (trust boundary): a broken FrameSort must not
		-- propagate errors into our callers (including KickTracker's
		-- interrupt path).
		local ok, id = pcall(fs.Inspector.GetUnitSpecId, fs.Inspector, unit)
		if ok and id then
			return id
		end
	end

	local id = addon.Core.Inspector:GetUnitSpecId(unit)
	if id then
		return id
	end

	local arenaIndex = unit:match("^arena(%d)$")
	if arenaIndex then
		local arenaId = GetArenaOpponentSpec and GetArenaOpponentSpec(tonumber(arenaIndex))
		if arenaId and arenaId > 0 then
			return arenaId
		end
	end

	return nil
end
