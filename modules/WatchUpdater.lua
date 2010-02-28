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
	},
	profile = {
		limit = false,
		maxNumber = 8,
	},
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
	self:RegisterEvent('QUEST_LOG_UPDATE', 'Update')
	self:RegisterEvent('PARTY_MEMBERS_CHANGED', 'Update')
	self:SecureHook('AddQuestWatch', 'DoNotManage')
	self:SecureHook('RemoveQuestWatch', 'DoNotManage')
	if IsLoggedIn() then
		self:Update("OnEnable")
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

function mod:GetOptionsTable()
	local tmp = {}
	return {
		name = L['Watch Updater'],
		type = 'group',
		args = {
			limit = {
				name = L['Limit watched quests'],
				desc = L['Limit the number of watched quests.'],
				type = 'toggle',
				get = function() return self.db.profile.limit end,
				set = function(_, value)
					self.db.profile.limit = value
					self:Update('OnConfigChanged')
				end,
				order = 10,
			},
			maxNumber = {
				name = L['Maximum number of watched quests'],
				desc = L['The maximum number of quests to watch at a time.'],
				type = 'range',
				min = 1,
				max = 25,
				step = 1,
				get = function() return self.db.profile.maxNumber end,
				set = function(_, value)
					self.db.profile.maxNumber = value
					self:Update('OnConfigChanged')
				end,
				disabled = function() return not self.db.profile.limit end,
				order = 20,
			},
			reset = {
				name = L['Reset free quests'],
				desc = function()
					wipe(tmp)
					tinsert(tmp, L['Reset the list of quests that are not managed by this module:'])
					for index = 1, 50 do
						local	title, level, tag, suggestedGroup, isHeader, _, isComplete, _, questId = GetQuestLogTitle(index)
						if not title then break end
						if not isHeader and questId and not self.db.char.managed[questId] then
							tinsert(tmp, title)
						end
					end
					return table.concat(tmp, "\n")
				end,
				type = 'execute',
				func = function()
					wipe(self.db.char.managed)
					self:Update("OnResetManaged")
				end,
				disabled = function()
					for questId, managed in pairs(self.db.char.managed) do
						if not managed then
							return false
						end
					end
					return true
				end,
				order = 30,
			},
		},
	}
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
	local levels = {}
	local indexes = {}
	
	local function SortByLevel(a, b)
		return (levels[a or ""] or 0) < (levels[b or ""] or 0)
	end

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
		--self:Debug('Update data', 'inDungeon=', inDungeon, 'inRaid=', inRaid, 'groupStrength=', groupStrength)

		-- Scan all quests to create a map of the ones we want to show
		local numToWatch, numComplete, numForced = 0, 0, 0
		for index = 1, 50 do
			local	title, level, tag, suggestedGroup, isHeader, _, isComplete, _, questId = GetQuestLogTitle(index)
			if not title then break end
			if not isHeader and questId then
				levels[index] = level
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
					--self:Debug('Managed quest: |cff00ffff', title, '|rid=', questId, 'mapId=', mapId, 'isDungeon=', isDungeonQuest, 'isRaidQuest=', isRaidQuest, 'recommendStrength=', recommendedGroupStrength, 'complete=', isComplete, 'state=|cffffff00', watchState[index], '|r')
				else
					if IsQuestWatched(index) then
						numForced = numForced + 1
						watchState[index] = "force-show"
					else
						watchState[index] = "force-hide"
					end
				end
			end
		end

		-- State we want to show
		local showState = (numToWatch > 0 and numComplete == numToWatch) and "complete" or "show"
		local maxNumber = self.db.profile.limit and math.max(self.db.profile.maxNumber, numForced) or (numToWatch + numForced)
		local numManaged = math.max(0, maxNumber - numForced)
		self:Debug('Showing quests in state:', showState, 'numToWatch=', numToWatch, 'numComplete=', numComplete, 'numForced=', numForced, 'maxNumber=', maxNumber, 'numManaged=', numManaged)
		
		-- Build a list of the indexes of the quests we want to show
		for index, state in pairs(watchState) do
			if state == "force-show" then
				tinsert(indexes, index)
			elseif state == showState and numManaged > 0 then
				tinsert(indexes, index)
				numManaged = numManaged - 1
			end
		end
		table.sort(indexes, SortByLevel)
		
		local dirty = false
		
		-- Remove all quests we do not want
		for i = GetNumQuestWatches(), 1, -1 do
			local index = GetQuestIndexForWatch(i)
			if index ~= indexes[i] then
				self:Debug("Hiding quest:|cff00ffff", (GetQuestLogTitle(index)), '|r')
				RemoveQuestWatch(GetQuestIndexForWatch(i))
				dirty = true
			end
		end
		
		-- Add quests we want
		for i = GetNumQuestWatches()+1, #indexes do
			local index = indexes[i]
			if not IsQuestWatched(index) then
				self:Debug('Showing quest:|cff00ffff', (GetQuestLogTitle(index)), '|r')
				AddQuestWatch(index)
				dirty = true
			end
		end

		-- Cleanup
		wipe(indexes)
		wipe(levels)
		
		-- Ensure the WatchFrame is up-to-date
		if dirty then
			self:Debug('Forcing WatchFrame update')
			WatchFrame_Update()
		end

		--[[
		local dirty = false

		-- Scan the watched quest to remove those we want to hide
		for i = GetNumQuestWatches(), 1, -1 do
			local index = GetQuestIndexForWatch(i)
			local state = index and watchState[index]
			if state ~= "unmanaged" and state ~= showState then
				self:Debug("Hiding quest: |cff00ffff", (GetQuestLogTitle(index)), '|r state=', watchState[index])
				RemoveQuestWatch(index)
				dirty = true
			end
		end

		-- Start watching quests we want to show
		for index, state in pairs(watchState) do
			if state == showState then
				if not IsQuestWatched(index) then
					self:Debug('Showing quest: |cff00ffff', (GetQuestLogTitle(index)), '|r state=', state)
					AddQuestWatch(index)
					dirty = true
				end
			end
		end
		wipe(watchState)

		-- Force the WatchFrame to update
		if dirty then
			WatchFrame_Update()
		end
		--]]

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
	local ok, msg = pcall(DoUpdate, self, event, ...)
	updating = false

	if not ok then
		geterrorhandler()(msg)
	end
end

