--[[
AdiQuestTracker - a collection of quest tracker enhancement modules.
(c) 2009 Adirelle (adirelle@tagada-team.net)
All rights reserverd.
--]]

local _, core = ...
local mod = core:NewModule('TitleTags', 'AceHook-3.0')
local L = core.L

mod.title = L["Add level and tags to quest titles"]

local tags = {}
for _, tag in pairs({"Dungeon", "Elite", "Group", "Heroic", "PVP", "Raid"}) do
	tags[L[tag]] = L[tag..'Tag']
end

function mod:OnEnable()
	self:RawHook('GetQuestLogTitle', 'GetQuestLogTitle', true)
end

function mod:OnDisable()
	self:UnhookAll()
end

local function TagTitle(title, level, questTag, suggestedGroup, isHeader, isCollapsed, isComplete, isDaily, ...)
	if title and not isHeader then
		title = string.format("[%d%s%s] %s", level, questTag and tags[questTag] or "", isDaily and L['DailyTag'] or "", title)
	end
	return title, level, questTag, suggestedGroup, isHeader, isCollapsed, isComplete, isDaily, ...
end

function mod:GetQuestLogTitle(...)
	return TagTitle(self.hooks.GetQuestLogTitle(...))
end

