--[[
AdiQuestTracker - a collection of quest tracker enhancement modules.
(c) 2009 Adirelle (adirelle@tagada-team.net)
All rights reserverd.
--]]

local _, core = ...
local mod = core:NewModule('PersistentTracking', 'AceEvent-3.0')

local DEFAULTS = {}

function mod:OnInitialize()
	mod.db = core.db:RegisterNamespace("PersistentTracking", DEFAULTS)
end

function mod:OnEnable()
	self:RegisterEvent('PLAYER_LOGOUT', 'SaveTrackerStatus)	
	if IsLoggedIn() then
		self:RestoreTrackerStatus("OnEnable")
	else
		self:RegisterEvent('PLAYER_LOGIN', 'RestoreTrackerStatus')
	end
end

function mod:OnDisable()
	self:SaveTrackerStatus("OnDisable")
end

function mod:RestoreTrackerStatus(event)
	self.core:ExpandQuestLog()
	self:Debug("RestoreTrackerStatus", event)
	for index = 1, GetNumQuestLogEntries() do
		local	title, _, _, _, isHeader, _, _, _, questID = GetQuestLogTitle(questIndex)
		if not self.db.char[questID] then
			self:Debug("Tracking:", title)
			AddQuestWatch(index)
		end
	end
	self.core:RestoreQuestLog()
	wipe(self.db.char)	
end

function mod:SaveTrackerStatus(event)
	self:Debug("SaveTrackerStatus", event)
	self.core:ExpandQuestLog()
	for index = 1, GetNumQuestLogEntries() do
		local	_, _, _, _, isHeader, _, _, _, questID = GetQuestLogTitle(questIndex)
		if not isHeader then
			self.db.char[questID] = true
		end
	end
	self.core:RestoreQuestLog()
end
