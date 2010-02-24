--[[
AdiQuestTracker - a collection of quest tracker enhancement modules.
(c) 2009 Adirelle (adirelle@tagada-team.net)
All rights reserverd.
--]]

local addonName, addon = ...
addon = LibStub('AceAddon-3.0'):NewAddon(addon, addonName)
local L = addon.L

local DEFAULTS = {
	profile = {
		modules = { ['*'] = true },
	}
}

function addon:OnInitialize()
	self.db = LibStub('AceDB-3.0'):New("AdiQuestTrackerDB", DEFAULTS, true)
	self.db.RegisterCallback(self, 'OnNewProfile', 'Reboot')
	self.db.RegisterCallback(self, 'OnProfileChanged', 'Reboot')
	self.db.RegisterCallback(self, 'OnProfileCopied', 'Reboot')
	self.db.RegisterCallback(self, 'OnProfileReset', 'Reboot')

	LibStub('AceConfig-3.0'):RegisterOptionsTable(addonName, self.GetOptionsTable)
	LibStub('AceConfigDialog-3.0'):AddToBlizOptions(addonName, GetAddOnMetadata(addonName, "Title"))
end

function addon:OnEnable()
	-- Update module enabled states
	for name, module in self:IterateModules() do
		module:SetEnabledState(self.db.profile.modules[name])
	end
end

function addon:Reboot()
	self:Disable()
	self:Enable()
end

-- Options
local options
function addon.GetOptionsTable()
	if options then return options end

	local profileOptions = LibStub('AceDBOptions-3.0'):GetOptionsTable(addon.db)
	profileOptions.order = -1

	options = {
		name = GetAddOnMetadata(addonName, "Title"),
		type = 'group',
		childGroups = 'tab',
		args = {
			general = {
				name = L['General'],
				type = 'group',
				args = {
					modules = {
						name = L['Modules'],
						type = 'multiselect',
						values = {},
						get = function(info, key) return addon.db.profile.modules[key] end,
						set = function(info, key, value)
							addon.db.profile.modules[key]  = value
							if value then addon:EnableModule(key) else addon:DisableModule(key) end
						end,
						order = 0,
					},
				},
				plugins = {},
			},
			profiles = profileOptions
		},
		plugins = {},
	}

	for name, module in addon:IterateModules() do
		local mod = module
		options.args.general.args.modules.values[name] = mod.title or name
		local modOptions = mod:GetOptionsTable()
		if modOptions then
			modOptions.hidden = function() return not mod:IsEnabled() end
			if modOptions.type == 'group' then
				options.plugins[name] = { [name] = modOptions	}
			else
				options.args.general.plugins[name] = { [name] = modOptions	}
			end
		end
	end

	return options
end

-- Debug output
if tekDebug then
	local debugFrame = tekDebug:GetFrame(addonName)
	function addon:Debug(...)
		debugFrame:AddMessage('|cffff8800['..tostring(self)..']|r '..strjoin(" ", tostringall(...)):gsub("= ", "="))
	end
	function addon:HasDebug() return true end
else
	function addon:Debug() end
	function addon:HasDebug() return false end
end

-- Module methods
addon:SetDefaultModulePrototype({
	core = addon,
	Debug = addon.Debug,
	HasDebug = addon.HasDebug,
	GetOptionsTable = function() end,
})
-- Expand/restore questlog headers
local expandLock = 0
local wasCollapsed = {}

function addon:ExpandQuestLog()
	expandLock = expandLock + 1
	for index = 1, GetNumQuestLogEntries() do
		local title, _, _, _, isHeader, isCollapsed = GetQuestLogTitle(index)
		if isHeader and isCollapsed then
			wasCollapsed[title] = true
			ExpandQuestHeader(index)
		end
	end
end

function addon:RestoreQuestLog()
	if expandLock > 0 then
		expandLock = expandLock - 1
		return
	end
	for index = 1, GetNumQuestLogEntries() do
		local title, _, _, _, isHeader = GetQuestLogTitle(index)
		if isHeader and wasCollapsed[title] then
			CollapseQuestHeader(index)
			wasCollapsed[title] = nil
		end
	end
end

