--[[
AdiQuestTracker - a collection of quest tracker enhancement modules.
(c) 2009 Adirelle (adirelle@tagada-team.net)
All rights reserverd.
--]]

local _, core = ...
local mod = core:NewModule('ZoneTracking', 'AceEvent-3.0')

function mod:OnEnable()
	self.currentZone = nil
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "CheckZoneChange")
	self:RegisterEvent("ZONE_CHANGED", "CheckZoneChange")
	self:RegisterEvent("ZONE_CHANGED_INDOORS", "CheckZoneChange")
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "CheckZoneChange")
end

function mod:CheckZoneChange()
	local newZone = GetRealZoneText()
	if newZone ~= self.currentZone then
		self:ZoneChanged(self.currentZone, newZone)
		self.currentZone = newZone
	end
end

local wasCollapsed = {}
function mod:ZoneChanged(oldZone, newZone)
	self:Debug("ZoneChanged", oldZone, newZone)
	
	-- Expand zone headers
	local expandedNew, expandedOld
	for index = 1, GetNumQuestLogEntries() do
		local title, _, _, _, isHeader, isCollapsed = GetQuestLogTitle(index)
		if isHeader and isCollapsed then
			if title == newZone or title == oldZone then
				wasCollapsed[title] = true
				ExpandQuestHeader(index)
			end
		end
	end

	-- Change tracked quests
	local currentHeader = nil
	for index = 1, GetNumQuestLogEntries() do
		local title, _, _, _, isHeader = GetQuestLogTitle(index)
		if isHeader then
			if title == oldZone or title == newZone then
				currentHeader = title
			else
				currentHeader = nil
			end
		elseif currentHeader then
			if currentHeader == oldZone and IsQuestWatched(index) then
				RemoveQuestWatch(index)
			elseif currentHeader == newZone and not IsQuestWatched(index) then
				AddQuestWatch(index)
			end
		end
	end
		
	-- Restore header status
	for index = 1, GetNumQuestLogEntries() do
		local title, _, _, _, isHeader = GetQuestLogTitle(index)
		if isHeader and wasCollapsed[title] then
			CollapseQuestHeader(index)
			toCollapse[title] = nil
		end
	end
	
end
