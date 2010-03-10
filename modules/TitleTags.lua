--[[
AdiQuestTracker - a collection of quest tracker enhancement modules.
(c) 2009 Adirelle (adirelle@tagada-team.net)
All rights reserverd.
--]]

local _, core = ...
local mod = core:NewModule('TitleTags', 'AceHook-3.0', 'AceEvent-3.0')
local L = core.L

mod.title = L["Add level and tags to quest titles"]

local tags = {}
for _, tag in pairs({"Dungeon", "Elite", "Group", "Heroic", "PVP", "Raid"}) do
	tags[L[tag]] = L[tag..'Tag']
end

function mod:OnEnable()
	self:RegisterEvent('GOSSIP_SHOW', 'ClearTitleCache')
	self:RegisterEvent('GOSSIP_CLOSED', 'ClearTitleCache')
	self:RawHook('GetTitleText', 'GetTitleText', true)
	self:RawHook('GetQuestLogTitle', 'GetQuestLogTitle', true)
	self:RawHook('GetGossipActiveQuests', 'GetGossipActiveQuests', true)
	self:RawHook('GetGossipAvailableQuests', 'GetGossipAvailableQuests', true)
end

function mod:OnDisable()
	self:UnhookAll()
end

local function FormatTitle(title, level, tag, isDaily, suggestedGroup)
	if title and type(level) == "number" and level > 0 then
		local color = GetQuestDifficultyColor(level)
		title = string.format("|cff%02x%02x%02x[%s%s%s%s]|r %s", 255*color.r, 255*color.g, 255*color.b, (level or ""), tag and tags[tag] or "", isDaily and L['DailyTag'] or "", (tonumber(suggestedGroup) or 0) > 1 and suggestedGroup or "", title)
	end
	return title
end

local function FormatQuestLogTitle(title, level, questTag, suggestedGroup, isHeader, isCollapsed, isComplete, isDaily, questId, ...)
	if title and not isHeader then
		title = FormatTitle(title, level, questTag, isDaily, suggestedGroup)
	end
	return title, level, questTag, suggestedGroup, isHeader, isCollapsed, isComplete, isDaily, questId, ...
end

function mod:GetQuestLogTitle(...)
	return FormatQuestLogTitle(self.hooks.GetQuestLogTitle(...))
end

local gossipTitleCache = {}

local function FormatGossipQuestTitles(title, level, trivial, ...)
	if not title then return end
	local newTitle = title
	if title then
		newTitle = FormatTitle(title, level)
		gossipTitleCache[title] = newTitle
	end
	mod:Debug('FormatGossipQuestTitles', title, newTitle, level, trivial, more, ...)
	return newTitle, level, trivial, FormatGossipQuestTitles(...)
end

function mod:ClearTitleCache()
	wipe(gossipTitleCache)
end

function mod:GetGossipAvailableQuests(...)
	return FormatGossipQuestTitles(self.hooks.GetGossipAvailableQuests(...))
end

function mod:GetGossipActiveQuests(...)
	return FormatGossipQuestTitles(self.hooks.GetGossipActiveQuests(...))
end

function mod:GetTitleText(...)
	local title = self.hooks.GetTitleText(...)
	return gossipTitleCache[title or ""] or title
end

