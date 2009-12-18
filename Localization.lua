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

-- English
L["Add level and tags to quest titles"] = true
L["Automatically hide the watcher"] = true
L["DailyTag"] = true
L['General'] = true
L['Hiding conditions'] = true
L['In arena'] = true
L['In battleground'] = true
L['In combat'] = true
L['In raid group'] = true
L['Modules'] = true
L["The tracker is hidden when at least one condition is true."] = true
L["Update watched quests on zoning"] = true
L['When empty'] = true
L["Dungeon"] = true
L["Elite"] = true
L["Group"] = true
L["Heroic"] = true
L["PVP"] = true
L["Raid"] = true

-- Tags
L["DungeonTag"] = "D"
L["EliteTag"] = "+"
L["GroupTag"] = "G"
L["HeroicTag"] = "H"
L["PVPTag"] = "P"
L["RaidTag"] = "R"
L["DailyTag"] = "Y"

if GetLocale() == "frFR" then
-- frFR
L["Dungeon"] = "Donjon"
L["Elite"] = "Elite"
L["Group"] = "Groupe"
L["Heroic"] = "Héroïque"
L["PVP"] = "JcJ"
L["Raid"] = "Raid"
L["DailyTag"] = "J"
end
