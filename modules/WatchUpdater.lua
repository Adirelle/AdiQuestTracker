--[[
AdiQuestTracker - a collection of quest tracker enhancement modules.
(c) 2009 Adirelle (adirelle@tagada-team.net)
All rights reserverd.
--]]

local _, core = ...
local mod = core:NewModule('WatchUpdater', 'AceEvent-3.0', 'AceHook-3.0')
local L = core.L

mod.title = L["Automatically update watched quests"]

local DEFAULTS = {
	char = {
		managed = { ['*'] = true },
	}
}

function mod:OnInitialize()
	mod.db = core.db:RegisterNamespace("WatchUpdater", DEFAULTS)
end

local DISABLE_VARS = {
	{ "autoQuestWatch", "AUTO_QUEST_WATCH", "InterfaceOptionsObjectivesPanelAutoQuestTracking" },
	{ "autoQuestProgress", "AUTO_QUEST_PROGRESS", "InterfaceOptionsObjectivesPanelAutoQuestProgress" },
}

function mod:OnEnable()
	for _, data in pairs(DISABLE_VARS) do
		local cvar, uvar, control = unpack(data)
		self['save-'..cvar] = GetCVar(cvar)
		SetCVar(cvar, false)
		_G[uvar] = nil
		_G[control]:Disable()
	end
	self:RegisterEvent('PLAYER_LOGOUT', 'Disable')
	
	self.currentZone = nil
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "CheckZone")
	self:RegisterEvent("ZONE_CHANGED", "CheckZone")
	self:RegisterEvent("ZONE_CHANGED_INDOORS", "CheckZone")
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "CheckZone")
	self:RegisterEvent('QUEST_LOG_UPDATE')
	self:RegisterEvent('PARTY_MEMBERS_CHANGED', 'Update')
	self:SecureHook('AddQuestWatch', 'DoNotManage')
	self:SecureHook('RemoveQuestWatch', 'DoNotManage')
	if IsLoggedIn() then
		self:CheckZone("OnEnable")
	end
end

function mod:OnDisable()
	for _, data in pairs(DISABLE_VARS) do
		local cvar, uvar, control = unpack(data)
		local setting = self['save-'..cvar]
		SetCVar(cvar, setting)
		_G[uvar] = setting
		_G[control]:Enable()
	end
end

function mod:QUEST_LOG_UPDATE(event)
	self:UnregisterEvent('QUEST_LOG_UPDATE')
	self:RegisterEvent('UNIT_QUEST_LOG_CHANGED')
	self:Debug('QUEST_LOG_UPDATE', 'event=', event, 'unit=', unit)
	return self:UNIT_QUEST_LOG_CHANGED(event, 'player')
end

function mod:UNIT_QUEST_LOG_CHANGED(event, unit)
	if unit ~= "player" then return end
	self:Debug('UNIT_QUEST_LOG_CHANGED', 'event=', event, 'unit=', unit)
	return self:Update(event)
end

function mod:CheckZone(event)
	local newZone = GetCurrentMapAreaID() - 1
	self:Debug("CheckZone, event=", event, "old=", self.currentZone, "new=", newZone)
	if newZone ~= self.currentZone then
		self.currentZone = newZone
		self:Update(event)
	end
end

local updating = false

function mod:DoNotManage(questLogIndex)
	if updating then return end
	local questId = select(9, GetQuestLogTitle(questLogIndex or 0))
	self:Debug('DoNotManage', 'index=', questLogIndex, 'id=', questId)
	if questId then
		self.db.char.managed[questId] = false
	end
end

local function xnor(a, b) return (a and b) or (not a and not b) end

local DoUpdate
do
	local toForget = {}
	local watchState = {}
	
	function DoUpdate(self, event)
		local managed = self.db.char.managed

		-- Mark every known managed states to be forgotten
		for questId, value in pairs(managed) do
			if value then
				toForget[questId] = true
			end
		end
	
		local _, instanceType = IsInInstance()
		local inDungeon = (instanceType == 'party')
		local inRaid = GetRealNumRaidMembers() > 0
		local groupStrength = UnitLevel('player')
		for i = 1, GetRealNumPartyMembers() do
			groupStrength = groupStrength + UnitLevel('party'..i)
		end
		self:Debug('Update data', 'inDungeon=', inDungeon, 'inRaid=', inRaid, 'groupStrength=', groupStrength)
		
		-- Scan all quests to create a map of the ones we want to show
		local numToWatch, numComplete = 0, 0
		for index = 1, GetNumQuestLogEntries() do		
			local	title, level, tag, suggestedGroup, isHeader, _, isComplete, _, questId = GetQuestLogTitle(index)
			if not isHeader and questId then
				toForget[questId] = nil -- do not forget managed flag of this quest
				if managed[questId] then
					local mapId = GetQuestWorldMapAreaID(questId)
					local isDungeonQuest = (tag == L['Dungeon'])
					local isRaidQuest = (tag == L['Raid'])
					local recommendedGroupStrength = (level-3) * (tonumber(suggestedGroup) or 1)
					isComplete = tonumber(isComplete) == 1 and GetNumQuestLeaderBoards(index) > 0
					if (mapId == self.currentZone) and xnor(inDungeon, isDungeonQuest) and xnor(inRaid, isRaidQuest) and groupStrength >= recommendedGroupStrength then
						numToWatch = numToWatch + 1
						if isComplete then
							watchState[index] = 'complete'
							numComplete = numComplete + 1
						else
							watchState[index] = 'show'
						end
					else
						watchState[index] = 'hide'
					end
					self:Debug('Managed quest: |cff00ffff', title, '|rid=', questId, 'mapId=', mapId, 'isDungeon=', isDungeonQuest, 'isRaidQuest=', isRaidQuest, 'recommendStrength=', recommendedGroupStrength, 'complete=', isComplete, 'state=|cffffff00', watchState[index], '|r')
				else
					self:Debug('Ignoring non-managed quest', title)
				end
			end
		end
	
		-- Update state
		self:Debug('numToWatch=', numToWatch, 'numComplete=', numComplete)
		local showComplete = (numComplete == numToWatch)
		for index, state in pairs(watchState) do
			if state == 'show' or (showComplete and state == 'complete') then
				if not IsQuestWatched(index) then
					self:Debug('Showing quest', index, 'state=', state)
					AddQuestWatch(index)
				else
					self:Debug('Quest already shown:', index, 'state=', state)
				end
			else
				if IsQuestWatched(index) then
					self:Debug('Hiding quest', index, 'state=', state)
					RemoveQuestWatch(index)
				else
					self:Debug('Quest already hidden:', index, 'state=', state)
				end
			end
		end
		wipe(watchState)

		-- Forgeting quest that are not in the log anymore
		if next(toForget) then
			for questId in pairs(toForget) do
				self:Debug('Forgetting about old quest', questId)
				managed[questId] = nil
			end
			wipe(toForget)
		end
	
	end
end

function mod:Update(event, ...)
	if updating then return self:Debug("Ignoring", event, "during updating") end
	self:Debug("Update", "event=", event)

	updating = true
	self.core:ExpandQuestLog()	
	local ok, msg = pcall(DoUpdate, self, event, ...)
	self.core:RestoreQuestLog()
	updating = false

	if not ok then
		geterrorhandler()(msg)
	end
end

