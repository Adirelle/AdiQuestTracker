--[[
AdiQuestTracker - a collection of quest tracker enhancement modules.
(c) 2009 Adirelle (adirelle@tagada-team.net)
All rights reserverd.
--]]

local _, core = ...
local mod = core:NewModule('TitleTags', 'AceHook-3.0')
local L = core.L

mod.title = L["Add level and tags to quest titles"]

local tags = {
	[L["Dungeon"]] = "D",
	[L["Elite"]] = "+",
	[L["Group"]] = "G",
	[L["Heroic"]] = "H",
	[L["PVP"]] = "P",
	[L["Raid"]] = "R",
}

function mod:OnEnable()
	self:RawHook('GetQuestLogTitle', 'GetQuestLogTitle', true)
end

function mod:OnDisable()
	self:UnhookAll()
end

local function TagTitle(title, level, questTag, suggestedGroup, isHeader, isCollapsed, isComplete, isDaily, ...)
	if not isHeader then
		title = string.format("[%d%s%s] %s", level, questTag and tags[questTag] or "", isDaily and "D" or "", title)		
	end
	return title, level, questTag, suggestedGroup, isHeader, isCollapsed, isComplete, isDaily, ...
end

function mod:GetQuestLogTitle(...)
	return TagTitle(self.hooks.GetQuestLogTitle(...))
end

