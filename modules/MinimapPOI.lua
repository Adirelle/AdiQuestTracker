--[[
AdiQuestTracker - a collection of quest tracker enhancement modules.
(c) 2009 Adirelle (adirelle@tagada-team.net)
All rights reserverd.
--]]

local _, core = ...
local mod = core:NewModule('MinimapPOI', 'AceHook-3.0', 'AceEvent-3.0')
local modName = mod.name
local L = core.L

mod.title = L["Display quest POI on minimap"]

local Astrolabe = DongleStub("Astrolabe-0.4")

local activePOIs = {}

function mod:OnEnable()
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdatePOIs")
	self:RegisterEvent("QUEST_LOG_UPDATE", "UpdatePOIs")
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "UpdatePOIs")
	self:RegisterEvent("QUEST_POI_UPDATE", "UpdatePOIs")
	self:SecureHook("WatchFrame_Update")
	Astrolabe:Register_OnEdgeChanged_Callback(mod.OnEdgeChanged, mod)
	self:UpdatePOIs('OnEnable')
end

function mod:OnDisable()
	Astrolabe:Register_OnEdgeChanged_Callback(mod.OnEdgeChanged)
	self:ReleaseAllPOIs()
end

function mod:WatchFrame_Update()
	return self:UpdatePOIs("WatchFrame_Update")
end

local poiByQuestId = {}
local inUpdate
function mod:UpdatePOIs(event)
	if inUpdate then return end
	self:Debug('Updating POIs on', event)

	inUpdate = true
	local continent, zone, x, y = Astrolabe:GetCurrentPlayerPosition()
	inUpdate = nil
	if not (continent and zone and x and y) then
		self:Debug("We're somewhere we can't display anything on the minimap")
		return self:ReleaseAllPOIs()
	end

	for poi in pairs(activePOIs) do
		if poi.button then
			poiByQuestId[poi.button.questId] = poi
		else
			self:Debug('POI has no button:', poi:GetName())
			poiByQuestId[poi:GetName()] = poi
		end
	end

	QuestPOIUpdateIcons()
	QuestMapUpdateAllQuests()

	local playerMoney = GetMoney()
	local hideComplete = bit.band(WATCHFRAME_FILTER_TYPE, WATCHFRAME_FILTER_COMPLETED_QUESTS) ~= WATCHFRAME_FILTER_COMPLETED_QUESTS
	local hideRemote = bit.band(WATCHFRAME_FILTER_TYPE, WATCHFRAME_FILTER_REMOTE_ZONES) ~= WATCHFRAME_FILTER_REMOTE_ZONES

	local completedIndex, objectiveIndex = 1, 1
	for watchIndex = 1, GetNumQuestWatches() do
		local logIndex = GetQuestIndexForWatch(watchIndex)
		if logIndex then
			local title, _, _, _, _, _, complete, _, questId = GetQuestLogTitle(logIndex)
			if complete == -1 then
				complete = false
			elseif complete == 1 then
				complete = true
			elseif GetNumQuestLeaderBoards(logIndex) == 0 and playerMoney > (GetQuestLogRequiredMoney(logIndex) or 0) then
				complete = true
			else
				complete = false
			end
			if (complete and hideComplete) or (not LOCAL_MAP_QUESTS[questId or ""] and hideRemote) then
				self:Debug('Ignoring completed/remote quest', title)
			elseif title and questId then
				local _, x, y = QuestPOIGetIconInfo(questId)
				if x and y then
					local poi = poiByQuestId[questId]
					poiByQuestId[questId] = nil
					if not poi then
						poi = self:AcquirePOI()
					end

					-- Increase indexes even if we can't place the icon
					local poiIndex
					if complete then
						poiIndex, completedIndex = completedIndex, completedIndex + 1
					else
						poiIndex, objectiveIndex = objectiveIndex, objectiveIndex + 1
					end

					if Astrolabe:PlaceIconOnMinimap(poi, continent, zone, x, y) == -1 then
						self:Debug("Can't add icon to minimap", title, 'x,y:', math.ceil(x*100)/100, math.ceil(y*100)/100)
						self:ReleasePOI(poi)
					else
						self:Debug('Placed', poi:GetName() ,'on minimap, quest:', title, 'x,y:', math.ceil(x*100)/100, math.ceil(y*100)/100)
						if poi.title ~= title or poi.questId ~= questId or poi.complete ~= complete or poi.index ~= poiIndex then
							self:Debug(poi:GetName(), ' data needs an update, complete=', complete, 'index=', poiIndex)
							poi.title, poi.questId, poi.complete, poi.index = title, questId, complete, poiIndex
							poi.button = QuestPOI_DisplayButton("Minimap", complete and QUEST_POI_COMPLETE_IN or QUEST_POI_NUMERIC, poiIndex, questId)
							poi.button:SetParent(poi)
							poi.button:SetPoint("CENTER")
							poi.button:EnableMouse(false)
							poi.button:SetScale(0.7)
							self:UpdatePOI(poi)
						end
					end
				else
					self:Debug('No coordinate for quest', title)
				end
			else
				self:Debug('No title nor quest id for quest #', logIndex)
			end
		else
			self:Debug('No QuestLog index for watched quest #', watchIndex)
		end
	end

	for questId, poi in pairs(poiByQuestId) do
		self:Debug('Releasing unused POI', poi:GetName())
		self:ReleasePOI(poi)
	end
	wipe(poiByQuestId)
end

function mod:OnEdgeChanged()
	self = self or mod
	self:Debug('OnEdgeChanged')
	for poi in pairs(activePOIs) do
		self:UpdatePOI(poi)
	end
end

local POI_OnEnter, POI_OnLeave
do
	local tooltip = GameTooltip

	function POI_OnEnter(poi)
		tooltip:SetOwner(poi, "ANCHOR_BOTTOMLEFT")
		tooltip:ClearLines()
		tooltip:AddLine(poi.title)
		tooltip:Show()
	end

	function POI_OnLeave(poi)
		if tooltip:GetOwner() == poi then
			tooltip:Hide()
		end
	end
end

--local function POI_OnMouseUp(poi)
--	WorldMap_OpenToQuest(poi.questId)
--end

local function POI_OnUpdate(poi, elapsed)
	poi.delay = poi.delay - elapsed
	if poi.delay > 0 then return end
	poi.delay = 0.1
	local distance = Astrolabe:GetDistanceToIcon(poi)
	if poi.onEdge then
		local alpha = math.min(math.max(1 - (distance - 200) / 200, 0.4), 1)
		if poi:GetAlpha() ~= alpha then
			poi:SetAlpha(alpha)
		end
	elseif poi.complete then
		if distance < 80 then
			if poi.button:IsShown() then
				poi.button:Hide()
			end
		elseif distance > 100 then
			if not poi.button:IsShown() then
				poi.button:Show()
			end
		end
	end
end

function mod:UpdatePOI(poi)
	poi.button:Show()
	poi.onEdge = Astrolabe:IsIconOnEdge(poi)
	if not poi.onEdge then
		self:Debug('Icon not on edge:', poi:GetName())
		poi:SetAlpha(1)
		if not poi.complete then
			return poi:SetScript("OnUpdate", nil)
		end
	end
	poi.delay = 0
	poi:SetScript("OnUpdate", POI_OnUpdate)
end

do
	local poiCount = 1

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
end

do
	local poiHeap = {}

	function mod:AcquirePOI()
		poi = next(poiHeap) or self:SpawnPOI()
		poiHeap[poi], activePOIs[poi] = nil, true
		self:Debug('Acquired POI', poi:GetName())
		return poi
	end

	function mod:ReleasePOI(poi)
		poi:SetScript("OnUpdate", nil)
		poi.button = nil
		Astrolabe:RemoveIconFromMinimap(poi)
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
end
