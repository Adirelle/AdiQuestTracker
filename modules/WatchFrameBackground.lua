--[[
AdiQuestTracker - a collection of quest tracker enhancement modules.
(c) 2009 Adirelle (adirelle@tagada-team.net)
All rights reserverd.
--]]

local _, core = ...
local mod = core:NewModule('WatchFrameBackground', 'AceHook-3.0')
local L = core.L

mod.title = L["Add a background to the WatchFrame."]

local MARGIN = 5

local backdrop

function mod:OnEnable()
	if not backdrop then
		backdrop = CreateFrame("Frame", nil, WatchFrameLines)
		backdrop:SetPoint("LEFT", WatchFrame, "LEFT", -24-MARGIN, 0)
		backdrop:SetPoint("RIGHT", WatchFrame, "RIGHT", MARGIN, 0)
		backdrop:SetPoint("TOP", WatchFrameLines, "TOP", 0, MARGIN)
		backdrop:SetBackdrop({bgFile = [[Interface\Tooltips\UI-Tooltip-Background]], tile = true, tileSize = 16})
		backdrop:SetBackdropColor(0, 0, 0, 0.5)
		backdrop:SetBackdropBorderColor(0, 0, 0, 0)
	end
	self:SecureHook('WatchFrame_Update', 'Update')
	self:SecureHookScript(WatchFrameLines, 'OnShow', 'Update')
	self:Update()
end

function mod:OnDisable()
	backdrop:Hide()
end

local function GetBottomMax(...)
	local bottom = nil
	for i = 1, select('#', ...) do
		for j, line in pairs(select(i, ...)) do
			if line:IsShown() then
				local lineBottom = line:GetBottom()
				if lineBottom then
					if bottom and lineBottom < bottom then
						bottom = lineBottom
					else
						bottom = lineBottom
					end
				end
			end
		end
	end
	return bottom
end

function mod:Update()
	if not WatchFrameLines:IsVisible() then return end
	local bottom = GetBottomMax(WATCHFRAME_TIMERLINES, WATCHFRAME_ACHIEVEMENTLINES, WATCHFRAME_QUESTLINES)
	if bottom then
		local size = WatchFrameLines:GetTop() - bottom
		self:Debug(bottom, WatchFrameLines:GetTop(), size)
		self:Debug('Updating size to', size)
		backdrop:SetHeight(size + 12)
		backdrop:Show()
	else
		self:Debug('Hiding background')
		backdrop:Hide()
	end
end

