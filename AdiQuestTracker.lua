--[[
AdiQuestTracker - a collection of quest tracker enhancement modules.
(c) 2009 Adirelle (adirelle@tagada-team.net)
All rights reserverd.
--]]

local addonName, addon = ...
addon = LibStub('AceAddon-3.0'):NewAddon(addon, addonName)

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
		module:SetEnabledState(self.db.profile.module[name])
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
	
	local profileOptions = LibStub('AceDBOptions-3.0'):GetOptionsTable(self.db)
	profileOptions.order = -1
	
	options = {
		name = GetAddOnMetadata(addonName, "Title"),
		type = 'group',
		childGroups = 'tab',
		args = {
			modules = {
				name = 'Modules',
				type = 'multiselect',
				values = {},
				get = function(info, key) return addon:GetModule(key):IsEnabled() end,
				set = function(info, key, value) if value then addon:EnableModule(key) else addon:DisableModule(key) end end,
				order = 0,
			},
			profiles = profileOptions
		},
	}
	
	for name, module in addon:IterateModules() do
		local mod = module
		options.args.modules.values[name] = name
		local modOptions = mod:GetOptionsTable()
		modOptions.hidden = function() return not mod:IsEnabled() end
		options.plugins[name] = modOptions
	end
	
	return options
end

-- Debug output
if tekDebug then
	local debugFrame = tekDebug:GetFrame(addonName)
	function addon:Debug(...)
		debugFrame:AddMessage('['..tostring(self)..'] '..string.join(", ", tostringall(...)):gsub("([:=]), ", "%1 "))
	end
	function addon:HasDebug() return true end
else
	function addon:Debug() end
	function addon:HasDebug() return false end
end

-- Module methods
addon:SetDefaultModulePrototype({
	Debug = addon.Debug,
	HasDebug = addon.HasDebug,
	GetOptionsTable = function() end,
})
