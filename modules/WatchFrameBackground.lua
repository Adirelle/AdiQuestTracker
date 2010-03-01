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
	backdrop:Show()
end

function mod:OnDisable()
	backdrop:Hide()
end

function mod:Update()
	if WatchFrameLines:IsShown() then
		self:Debug('Updating size to', WatchFrame.nextOffset)
		backdrop:SetHeight(-WatchFrame.nextOffset)
	end
end

