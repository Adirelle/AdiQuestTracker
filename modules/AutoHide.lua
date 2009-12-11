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
	mod.db = core.db:RegisterNameSpace("AutoHide", DEFAULTS)
end

function mod:OnEnable()
	self:RegisterEvent('PLAYER_REGEN_DISABLED', "CheckVisibility")
	self:RegisterEvent('PLAYER_REGEN_ENABLED', "CheckVisibility")
	self:RegisterEvent('PLAYER_ENTERING_WORLD', "CheckVisibility")
	self:RegisterEvent('PARTY_MEMBERS_CHANGED', "CheckVisibility")
	self:SecureHook("WatchFrame_Update")
	if IsLoggedIn() then
		self:CheckVisibility("OnEnable")
	end
end

function mod:OnDisable()
	WatchFrame:Show()
	WatchFrameLines:Show()
end

local function IsWatchFrameEmpty()
	return not (WATCHFRAME_LINKBUTTONS[1] and WATCHFRAME_LINKBUTTONS[1]:IsShown())
end

function mod:CheckVisibility(event)
	self:Debug("CheckVisibility", event, IncombatLockdown())
	if IncombatLockdown() then return end
	local _, instanceType = IsInInstance()
	if 
			(self.db.profile.empty and IsWatchFrameEmpty())
			or (self.db.profile.combat and event == 'PLAYER_REGEN_DISABLED') 
			or (self.db.profile.arena and instanceType == 'arena')
			or (self.db.profile.battleground and instanceType == 'pvp')
			or (self.db.profile.raid and GetRealNumRaidMembers() > 0)
	then
		WatchFrame:Hide()
		WatchFrameLines:Hide()
	else
		WatchFrame:Show()
		WatchFrameLines:Show()
	end
end

function mod:WatchFrame_Update()
	return self:CheckVisibility("WatchFrame_Update")
end
