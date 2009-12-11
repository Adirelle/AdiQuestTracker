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

function mod:ZoneChanged(oldZone, newZone)
	self:Debug("ZoneChanged", oldZone, newZone)
	
	-- Expand zone headers
	local expandedNew, expandedOld
	for index = 1, GetNumQuestLogEntries() do
		local title, _, _, _, isHeader, isCollapsed = GetQuestLogTitle(index)
		if isHeader and isCollapsed then
			if newZone and title == newZone then
				expandedNew = true
				ExpandQuestHeader(index)
			elseif oldZone and title == oldZone then
				expandedOld = true
				ExpandQuestHeader(index)
			end
		end
	end

	-- Change tracked quests
	local currentHeader = nil
	for index = 1, GetNumQuestLogEntries() do
		local title, _, _, _, isHeader = GetQuestLogTitle(index)
		if isHeader then
			currentHeader = title
		elseif oldZone and currentHeader == oldZone and IsQuestWatched(index) then
			RemoveQuestWatch(index)
		elseif newZone and currentHeader == newZone and not IsQuestWatched(index) then
			AddQuestWatch(index)
		end
	end
		
	-- Restore header status
	for index = 1, GetNumQuestLogEntries() do
		local title, _, _, _, isHeader = GetQuestLogTitle(index)
		if isHeader and ((expandedNew and title == newZone) or (expandedOld and title == oldZone)) then
			CollapseQuestHeader(index)
		end
	end
	
end
