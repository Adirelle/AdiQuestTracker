--[[
AdiQuestTracker - a collection of quest tracker enhancement modules.
(c) 2009 Adirelle (adirelle@tagada-team.net)
All rights reserverd.
--]]

local addonName, addon = ...

local L = setmetatable({}, {
	__index = function(self, key)
		if not key then return end
		key = tostring(key)
		rawset(self, key, key)
		addon:Debug("Missing localization for:", key)
		return key
	end,
	__newindex = function(self, key, value)
		if not key or not value then return end
		key = tostring(key)
		if value == true then value = key end
		rawset(self, key, tostring(value))
	end,
})
addon.L = L


