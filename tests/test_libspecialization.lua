local fw = require("framework")

local function loadWith(existingMinor, registrationResult)
	local prefixCalls = 0
	local newLibraryCalls = 0

	WOW_PROJECT_ID = 1
	C_ChatInfo = {
		RegisterAddonMessagePrefix = function()
			prefixCalls = prefixCalls + 1
			return registrationResult
		end,
	}
	LibStub = {
		GetLibrary = function()
			if existingMinor then return {}, existingMinor end
			return nil, nil
		end,
		NewLibrary = function()
			newLibraryCalls = newLibraryCalls + 1
			return {}, nil
		end,
	}

	local fn, err = loadfile("src/Libs/LibSpecialization/LibSpecialization.lua")
	if not fn then error(err) end
	local ok, loadErr = pcall(fn)
	return ok, loadErr, prefixCalls, newLibraryCalls
end

fw.describe("LibSpecialization registration guard", function()
	fw.it("does not touch the prefix when a newer library is already loaded", function()
		local ok, err, prefixCalls, newLibraryCalls = loadWith(27, 3)
		fw.truthy(ok, err)
		fw.eq(prefixCalls, 0, "prefix calls")
		fw.eq(newLibraryCalls, 0, "NewLibrary calls")
	end)

	fw.it("treats the retail API's false result as registration failure", function()
		local ok, _, prefixCalls, newLibraryCalls = loadWith(nil, false)
		fw.falsy(ok, "load should fail")
		fw.eq(prefixCalls, 1, "prefix calls")
		fw.eq(newLibraryCalls, 0, "no half-registered library")
	end)
end)
