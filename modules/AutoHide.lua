--[[
AdiQuestTracker - a collection of quest tracker enhancement modules.
(c) 2009 Adirelle (adirelle@tagada-team.net)
All rights reserverd.
--]]

local _, core = ...
local mod = core:NewModule('AutoHide', 'AceEvent-3.0', 'AceHook-3.0')

local DEFAULTS = {
	profile = {
			empty = true,
			combat = false,
			arena = true,
			battleground = true,
			raid = true,
	}
}

function mod:OnInitialize()
	mod.db = core.db:RegisterNamespace("AutoHide", DEFAULTS)
end

function mod:GetOptionsTable()
	return {
		name = 'Automatically hide the tracker...',
		type = 'multiselect',
		get = function(info, key) return self.db.profile[key]	end,
		set = function(info, key, value)
			self.db.profile[key] = value
			self:CheckVisibility('ConfigChanged')
		end,
		values = {
			empty = 'When empty',
			combat = 'In combat',
			arena = 'In arenas',
			battleground = 'In battlegrounds',
			raid = 'In raid groups',
		},
	}
end

local function IsWatchFrameEmpty()
	return not (WATCHFRAME_LINKBUTTONS[1] and WATCHFRAME_LINKBUTTONS[1]:IsShown())
end

local isEmpty

function mod:OnEnable()
	isEmpty = IsWatchFrameEmpty()
	self:RegisterEvent('PLAYER_REGEN_DISABLED', "CheckVisibility")
	self:RegisterEvent('PLAYER_REGEN_ENABLED', "CheckVisibility")
	self:RegisterEvent('PLAYER_ENTERING_WORLD', "CheckVisibility")
	self:RegisterEvent('PARTY_MEMBERS_CHANGED', "CheckVisibility")
	self:RegisterEvent('QUEST_LOG_UPDATE', "CheckVisibility")	
	self:SecureHook("WatchFrame_Update")
	if IsLoggedIn() then
		self:CheckVisibility("OnEnable")
	end
end

function mod:OnDisable()
	WatchFrame:Show()
end

function mod:CheckVisibility(event)
	if InCombatLockdown() then return end
	local _, instanceType = IsInInstance()
	if
			(self.db.profile.empty and isEmpty)
			or (self.db.profile.combat and event == 'PLAYER_REGEN_DISABLED') 
			or (self.db.profile.arena and instanceType == 'arena')
			or (self.db.profile.battleground and instanceType == 'pvp')
			or (self.db.profile.raid and GetRealNumRaidMembers() > 0)
	then
		if WatchFrame:IsShown() then
			self:Debug('Hiding the watchframe')
			WatchFrame:Hide()
		end
	elseif not WatchFrame:IsShown() then
		self:Debug('Showing the watchframe')
		WatchFrame:Show()
	end
end

function mod:WatchFrame_Update()
	local newEmpty = IsWatchFrameEmpty()
	if newEmpty ~= isEmpty then
		isEmpty = newEmpty
		return self:CheckVisibility("WatchFrame_Update")
	end
end
