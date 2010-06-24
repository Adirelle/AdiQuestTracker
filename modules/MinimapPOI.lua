--[[
AdiQuestTracker - a collection of quest tracker enhancement modules.
(c) 2009 Adirelle (adirelle@tagada-team.net)
All rights reserverd.
--]]

local _, core = ...
local mod = core:NewModule('MinimapPOI', 'AceHook-3.0', 'AceEvent-3.0', 'AceTimer-3.0')
local modName = mod.name
local L = core.L

mod.title = L["Display quest POI on minimap"]

local Astrolabe = DongleStub("Astrolabe-0.4")

function mod:OnEnable()
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "RequiresUpdate")
	self:RegisterEvent("QUEST_LOG_UPDATE", "RequiresUpdate")
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "RequiresUpdate")
	self:RegisterEvent("QUEST_POI_UPDATE", "RequiresUpdate")
	self:SecureHook("WatchFrame_Update")
	self:ScheduleRepeatingTimer("RepeatingTask", 0.1)
	if _G.SexyMapHudMap and _G.HudMapCluster then
		self:Debug('SexyHudMap support enabled')
		self:SecureHookScript(HudMapCluster, 'OnShow', 'ReparentPOIs')
		self:SecureHookScript(HudMapCluster, 'OnHide', 'ReparentPOIs')
	end
	
	self:RequiresUpdate("OnEnable")
end

function mod:OnDisable()
	self:ReleaseAllPOIs()
end

local needUpdate
function mod:RepeatingTask()
	if needUpdate then
		self:UpdatePOIs()
		needUpdate = nil
	end
	
	for poi in self:IterateActivePOIs() do
		local onEdge = Astrolabe:IsIconOnEdge(poi)
		if poi.button and (onEdge or poi.complete) then
			local button = poi.button
			local isShown = button:IsShown()
			local show, alpha = true, 1.0
			local distance = Astrolabe:GetDistanceToIcon(poi)
			if onEdge then
				alpha = 0.4 + 0.6 * math.min(math.max(1 - (distance - 200) / 200, 0), 1)
			elseif poi.complete then
				show = (distance > 100) or (isShown and distance > 80)
			end
			if show then
				if not isShown then
					button:Show()
				end
				if button:GetAlpha() ~= alpha then
					button:SetAlpha(alpha)
				end
			elseif isShown then
				button:Hide()
			end
		end
	end
end

function mod:RequiresUpdate(event)
	self:Debug('Requiring update on', event)
	needUpdate = true
end

function mod:WatchFrame_Update()
	return self:RequiresUpdate("WatchFrame_Update")
end

local titleByQuestId = {}
local poiByQuestId = {}
function mod:UpdatePOIs()
	self:Debug('Updating POIs')

	wipe(titleByQuestId)
	for i = 1, GetNumQuestWatches() do
		local logIndex = GetQuestIndexForWatch(i)
		if logIndex then
			local title, _, _, _, _, _, _, _, questId = GetQuestLogTitle(logIndex)
			titleByQuestId[questId] = title
		end
	end

	for poi in self:IterateActivePOIs() do
		poiByQuestId[poi.questId or tostring(poi)] = poi
	end
	
	local continent, zone = GetCurrentMapContinent(), GetCurrentMapZone()
	QuestPOIUpdateIcons()
	QuestMapUpdateAllQuests()

	local maxIndex = GetNumQuestWatches()
	for buttonType = QUEST_POI_NUMERIC, QUEST_POI_COMPLETE_IN do
		QuestPOI_HideButtons("Minimap", buttonType, 1)
		local complete = (buttonType == QUEST_POI_COMPLETE_IN)
		for buttonIndex = 1, maxIndex do
			local wfButton = _G["poiWatchFrameLines"..buttonType.."_"..buttonIndex]
			if not wfButton or not wfButton:IsShown() then break end
			local questId = wfButton.questId
			local title = titleByQuestId[questId or ""]
			if questId and title then
				local _, x, y = QuestPOIGetIconInfo(questId)
				self:Debug('button:', wfButton and wfButton:GetName(), 'questId:', questId, 'title:', title, 'x,y:', x, y)
				if x and y then
					local poi = poiByQuestId[questId]
					if not poi then
						poi = self:AcquirePOI()
					end
					if Astrolabe:PlaceIconOnMinimap(poi, continent, zone, x, y) ~= -1 then
						poiByQuestId[questId] = nil
						self:Debug('Placed', poi:GetName() ,'on minimap, quest:', title, 'x,y:', math.ceil(x*100)/100, math.ceil(y*100)/100)
						if poi.title ~= title or poi.questId ~= questId or poi.complete ~= complete or poi.index ~= buttonIndex then
							self:Debug(poi:GetName(), ' data needs an update, complete=', complete, 'index=', buttonIndex)
							poi.title, poi.questId, poi.complete, poi.index = title, questId, complete, buttonIndex
							local button = QuestPOI_DisplayButton("Minimap", buttonType, buttonIndex, questId)
							poi.button = button
							button:SetParent(poi)
							button:SetPoint("CENTER")
							button:SetScale(0.7)
							button:EnableMouse(false)
						end
						poi.button:Show()
					else
						self:Debug("Can't add icon to minimap", title, 'x,y:', math.ceil(x*100)/100, math.ceil(y*100)/100)
					end
				else
					self:Debug('No coordinate for quest', title)
				end
			end
		end
	end

	for k, poi in pairs(poiByQuestId) do
		self:Debug('Releasing unused POI', poi:GetName())
		self:ReleasePOI(poi)
	end
	wipe(poiByQuestId)
end

do
	local minimap = Minimap
	local tooltip = GameTooltip
	local poiCount = 1
	local poiHeap = {}
	local activePOIs = {}

	local function POI_OnEnter(poi)
		tooltip:SetOwner(poi, "ANCHOR_BOTTOMLEFT")
		tooltip:ClearLines()
		tooltip:AddLine(poi.title)
		tooltip:Show()
	end

	local function POI_OnLeave(poi)
		if tooltip:GetOwner() == poi then
			tooltip:Hide()
		end
	end

	function mod:SpawnPOI()
		self:Debug('Spawning POI', poiCount)
		local poi = CreateFrame("Frame", modName..poiCount, Minimap)
		poiCount = poiCount + 1
		poi:SetWidth(10)
		poi:SetHeight(10)
		poi:SetScript("OnEnter", POI_OnEnter)
		poi:SetScript("OnLeave", POI_OnLeave)
		poi:SetScript("OnMouseUp", WatchFrameQuestPOI_OnClick) --POI_OnMouseUp)
		poi:EnableMouse()
		return poi
	end

	function mod:AcquirePOI()
		poi = next(poiHeap) or self:SpawnPOI()
		poiHeap[poi], activePOIs[poi] = nil, true
		poi:SetParent(minimap)
		self:Debug('Acquired POI', poi:GetName())
		return poi
	end

	function mod:ReleasePOI(poi)
		Astrolabe:RemoveIconFromMinimap(poi)
		poi.title = nil
		poi.questId = nil
		poi.complete = nil
		poi.index = nil
		poi.button = nil
		poi:SetParent(nil)
		poi:Hide()
		poiHeap[poi], activePOIs[poi] = true, nil
		self:Debug('Released POI', poi:GetName())
	end

	function mod:ReleaseAllPOIs()
		self:Debug('Releasing all POIs')
		for poi in pairs(activePOIs) do
			Astrolabe:RemoveIconFromMinimap(poi)
			poiHeap[poi] = true
		end
		wipe(activePOIs)
	end
	
	function mod:ReparentPOIs(newMinimap)
		if newMinimap:IsVisible() then
			minimap = newMinimap
		else
			minimap = Minimap
		end
		mod:Debug('ReparentPOIs', minimap:GetName() or tostring(minimap))
		for poi in pairs(activePOIs) do
			poi:SetParent(minimap)
		end
		self:RequiresUpdate('ReparentPOIs')
	end
	
	function mod:IterateActivePOIs()
		return next, activePOIs
	end
end
