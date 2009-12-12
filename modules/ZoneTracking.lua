--[[
AdiQuestTracker - a collection of quest tracker enhancement modules.
(c) 2009 Adirelle (adirelle@tagada-team.net)
All rights reserverd.
--]]

local _, core = ...
local mod = core:NewModule('ZoneTracking', 'AceEvent-3.0')
local L = core.L

function mod:OnEnable()
	self.currentZone = nil
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "CheckZoneChange")
	self:RegisterEvent("ZONE_CHANGED", "CheckZoneChange")
	self:RegisterEvent("ZONE_CHANGED_INDOORS", "CheckZoneChange")
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "CheckZoneChange")
	if IsLoggedIn() then
		self:CheckZoneChange("OnEnable")
	end
end

function mod:CheckZoneChange(event)
	local newZone = GetCurrentMapAreaID() - 1
	self:Debug("CheckZoneChange, event=", event, "old=", self.currentZone, "new=", newZone)
	if newZone ~= self.currentZone then
		self:ZoneChanged(self.currentZone, newZone)
		self.currentZone = newZone
	end
end

function mod:ZoneChanged(oldZone, newZone)
	self:Debug("ZoneChanged", oldZone, newZone)

	self.core:ExpandQuestLog()

	for index = 1, GetNumQuestLogEntries() do
		local	title, _, _, _, isHeader, _, _, _, questID = GetQuestLogTitle(index)
		if not isHeader and questID then
			local mapID = GetQuestWorldMapAreaID(questID)
			self:Debug("quest=", title, "id=", questID, "mapID=", mapID, "isWatched=", IsQuestWatched(index))
			if mapID == oldZone and IsQuestWatched(index) then
				RemoveQuestWatch(index)
			elseif mapID == newZone and not IsQuestWatched(index) then
				AddQuestWatch(index)
			end
		end
	end

	self.core:RestoreQuestLog()

end
