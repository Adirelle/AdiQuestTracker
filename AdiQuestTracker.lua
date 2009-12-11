--[[
AdiQuestTracker - a collection of quest tracker enhancement modules.
(c) 2009 Adirelle (adirelle@tagada-team.net)
All rights reserverd.
--]]

local addonName, addon = ...
addon = LibStub('AceAddon-3.0'):NewAddon(addon, addonName)

function addon:OnInitialize()
	self.db = LibStub('AceDB-3.0'):New("AdiQuestTrackerDB", {}, true)
	
	LibStub('AceConfig-3.0'):RegisterOptionsTable(addonName, self.GetOptionsTable)
	LibStub('AceConfigDialog-3.0'):AddToBlizOptions(addonName, GetAddOnMetadata(addonName, "Title"))
end

-- Options
local options
function addon.GetOptionsTable()
	if options then return options end
	options = {
		name = GetAddOnMetadata(addonName, "Title"),
		type = 'group',
		childGroups = 'tab',
		args = {
			profiles = LibStub('AceDBOptions-3.0'):GetOptionsTable(self.db),
		},
	}
	for name, module in addon:IterateModules() do
		options.plugins[name] = module:GetOptionsTable()
	end
	return options
end

-- Debug output
if tekDebug then
	local debugFrame = tekDebug:GetFrame(addonName)
	function addon:Debug(...)
		local prefix = (type(self) == "table" and (self.moduleName or self.name or (type(self.GetName) == "function" and self:GetName()))) or tostring(self)
		debugFrame:AddMessage(prefix..': '..string.join(", ", tostringall(...)):gsub("([:=]), ", "%1 "))
	end
	function addon:HasDebug() return true end
else
	function addon:Debug() end
	function addon:HasDebug() return false end
end

-- Export debug methods to modules
addon:SetDefaultModulePrototype({
	Debug = addon.Debug,
	HasDebug = addon.HasDebug,
	GetOptionsTable = function() end,
})
