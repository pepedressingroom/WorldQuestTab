﻿local addonName, addon = ...

local _legionZoneIds = {1014, 1015, 1033, 1017, 1024, 1018};
local BWQ_WHITE_FONT_COLOR = CreateColor(0.8, 0.8, 0.8);
local questList = {};
local updatedDuringCombat = false;
-- 1007 Broken Isles
local soundId = 0;
local questInfoPool = {};
local _sortOptions = {[1] = "Time", [2] = "Faction", [3] = "Type", [4] = "Zone", [5] = "Name", [6] = "Reward"}
local artifactSpells = {
		"Empowering" -- ENG
		,"Macht verleihen" -- DE
		,"Potenciando" -- ESP
		,"Fortalecendo" -- PT
		,"Renforcement" -- FR
		,"Potenziamento" -- IT
	}
local factionIcons = {
	[1894] = "Interface/ICONS/INV_LegionCircle_Faction_Warden"
	,[1859] = "Interface/ICONS/INV_LegionCircle_Faction_NightFallen"
	,[1900] = "Interface/ICONS/INV_LegionCircle_Faction_CourtofFarnodis"
	,[1948] = "Interface/ICONS/INV_LegionCircle_Faction_Valarjar"
	,[1828] = "Interface/ICONS/INV_LegionCircle_Faction_HightmountainTribes"
	,[1883] = "Interface/ICONS/INV_LegionCircle_Faction_DreamWeavers"
	,[1090] = "Interface/ICONS/INV_LegionCircle_Faction_KirinTor"
}
local _filters = {
		[1] = {["name"] = "Faction"
				, ["flags"] = {[GetFactionInfoByID(1859)] = false, [GetFactionInfoByID(1894)] = false, [GetFactionInfoByID(1828)] = false, [GetFactionInfoByID(1883)] = false
								, [GetFactionInfoByID(1948)] = false, [GetFactionInfoByID(1900)] = false, [GetFactionInfoByID(1090)] = false, }}
		,[2] = {["name"] = "Type"
				, ["flags"] = {["Default"] = false, ["Elite"] = false, ["PvP"] = false, ["Petbattle"] = false, ["Dungeon"] = false, ["Profession"] = false, }}
		,[3] = {["name"] = "Reward"
				, ["flags"] = {["Item"] = false, ["Armor"] = false, ["Gold"] = false, ["Resources"] = false, ["Artifact"] = false, }}
	}

local BWQ_REWARDTYPE_ITEM = 3;
local BWQ_REWARDTYPE_GOLD = 4;
local BWQ_REWARDTYPE_CURRENCY = 5;
local BWQ_REWARDTYPE_ARMOR = 1;
local BWQ_REWARDTYPE_ARTIFACT = 2;
local BWQ_COMBATLOCK = "Disabled during combat.";
local BWQ_NOT_HERE = "You can't view world quests here.";
local BWQ_FILTERS = "Filters: %s";
local BWQ_SORT_BY = "By %s";

function BWQ_Tab_Onclick(self)
	if InCombatLockdown() then return end
	id = self and self:GetID() or 1;
	if id == 1 then
		HideUIPanel(BWQ_WorldQuestFrame);
		ShowUIPanel(QuestScrollFrame);
		BWQ_TabNormal.Highlight:Show();
		BWQ_TabNormal.TabBg:SetTexCoord(0.01562500, 0.79687500, 0.78906250, 0.95703125);
		BWQ_TabWorld.TabBg:SetTexCoord(0.01562500, 0.79687500, 0.61328125, 0.78125000);
	else
		BWQ_TabWorld.Highlight:Show();
		ShowUIPanel(BWQ_WorldQuestFrame);
		HideUIPanel(QuestScrollFrame);
		BWQ_TabWorld.TabBg:SetTexCoord(0.01562500, 0.79687500, 0.78906250, 0.95703125);
		BWQ_TabNormal.TabBg:SetTexCoord(0.01562500, 0.79687500, 0.61328125, 0.78125000);
	end
end

function BWQ_Quest_OnClick(self)
	PlaySound("igMainMenuOptionCheckBoxOn");
	if not self.questId or self.questId== -1 then return end
	if IsShiftKeyDown() then
		if IsWorldQuestHardWatched(self.questId) or (IsWorldQuestWatched(self.questId) and GetSuperTrackedQuestID() == self.questId) then
			BonusObjectiveTracker_UntrackWorldQuest(self.questId);
		else
			BonusObjectiveTracker_TrackWorldQuest(self.questId, true);
		end
	else
		if IsWorldQuestHardWatched(self.questId) then
			SetSuperTrackedQuestID(self.questId);
		else
			BonusObjectiveTracker_TrackWorldQuest(self.questId);
		end
	end

	SetMapByID(self.zoneId or 1007);
	addon:DisplayQuestList();
end

function BWQ_Quest_OnEnter(self)
	WorldMapTooltip:SetOwner(self, "ANCHOR_RIGHT");

	local i = 1;
	local button = _G["WorldMapFrameTaskPOI"..i]
	while(button) do
		if button.questID == self.questId then
			BWQ_PoISelectIndicator:SetParent(button);
			BWQ_PoISelectIndicator:ClearAllPoints();
			BWQ_PoISelectIndicator:SetPoint("CENTER", button);
			BWQ_PoISelectIndicator:SetFrameLevel(button:GetFrameLevel()+1);
			BWQ_PoISelectIndicator:Show();
		end
		i = i + 1;
		button = _G["WorldMapFrameTaskPOI"..i]
	end
	
	if ( not HaveQuestData(self.questId) ) then
		WorldMapTooltip:SetText(RETRIEVING_DATA, RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b);
		WorldMapTooltip:Show();
		return;
	end
	
	if self.info.rewardTexture == "" then
		addon:SetQuestReward(self.info)
	end
	self.reward.icon:SetTexture(self.info.rewardTexture ~= "" and self.info.rewardTexture or "Interface/ICONS/INV_Misc_QuestionMark");

	local title, factionID, capped = C_TaskQuest.GetQuestInfoByQuestID(self.questId);
		local tagID, tagName, worldQuestType, rarity, isElite, tradeskillLineIndex = GetQuestTagInfo(self.questId);
		local color = WORLD_QUEST_QUALITY_COLORS[rarity];
		WorldMapTooltip:SetText(title, color.r, color.g, color.b);

		if ( factionID ) then
			local factionName = GetFactionInfoByID(factionID);
			if ( factionName ) then
				if (capped) then
					WorldMapTooltip:AddLine(factionName, GRAY_FONT_COLOR:GetRGB());
				else
					WorldMapTooltip:AddLine(factionName);
				end
			end
		end

		WorldMap_AddQuestTimeToTooltip(self.questId);

	for objectiveIndex = 1, self.numObjectives do
		local objectiveText, objectiveType, finished = GetQuestObjectiveInfo(self.questId, objectiveIndex, false);
		if ( objectiveText and #objectiveText > 0 ) then
			local color = finished and GRAY_FONT_COLOR or HIGHLIGHT_FONT_COLOR;
			WorldMapTooltip:AddLine(QUEST_DASH .. objectiveText, color.r, color.g, color.b, true);
		end
	end

	local percent = C_TaskQuest.GetQuestProgressBarInfo(self.questId);
	if ( percent ) then
		GameTooltip_InsertFrame(WorldMapTooltip, WorldMapTaskTooltipStatusBar);
		WorldMapTaskTooltipStatusBar.Bar:SetValue(percent);
		WorldMapTaskTooltipStatusBar.Bar.Label:SetFormattedText(PERCENTAGE_STRING, percent);
	end

	WorldMap_AddQuestRewardsToTooltip(self.questId);

	WorldMapTooltip:Show();
end

local function IsArtifactItem(itemId)
	local spell = GetItemSpell(itemId)
	for k, v in ipairs(artifactSpells) do
		if v == spell then return true; end
	end
	return false;
end

local function ShowOverlayMessage(message)
	local scrollFrame = BWQ_QuestScrollFrame;
	local buttons = scrollFrame.buttons;
	message = message or "";
	
	ShowUIPanel(BWQ_WorldQuestFrame.blocker);
	BWQ_WorldQuestFrame.blocker.text:SetText(message);
	BWQ_QuestScrollFrame:EnableMouseWheel(false);
	
	BWQ_WorldQuestFrameFilterButton:Disable();
	BWQ_WorldQuestFrameSortButton:Disable();
	
	for k, button in ipairs(buttons) do
		button:Disable();
	end
end

local function HideOverlayMessage()
	local scrollFrame = BWQ_QuestScrollFrame;
	local buttons = scrollFrame.buttons;
	HideUIPanel(BWQ_WorldQuestFrame.blocker);
	BWQ_QuestScrollFrame:EnableMouseWheel(true);
	--addon:DisplayQuestList();
	
	BWQ_WorldQuestFrameFilterButton:Enable();
	BWQ_WorldQuestFrameSortButton:Enable();
	
	for k, button in ipairs(buttons) do
		button:Enable();
	end
end

local function ZoneHasSpecificQuests(zoneId)
	for k, v in ipairs(_legionZoneIds) do
		if v == zoneId then return true; end
	end
	return false;
end

local function GetOrCreateQuestInfo()
	for k, info in ipairs(questInfoPool) do
		if info.id == -1 then
			return info;
		end
	end

	local info = {["id"] = -1, ["title"] = "", ["timeString"] = "", ["color"] = BWQ_WHITE_FONT_COLOR, ["minutes"] = 0
					, ["faction"] = 0, ["type"] = 0, ["rarity"] = 0, ["isElite"] = false, ["tradeskill"] = 0
					, ["numObjectives"] = 0, ["numItems"] = 0, ["rewardTexture"] = "", ["rewardQuality"] = 1
					, ["rewardType"] = 0};
	table.insert(questInfoPool, info);
	
	return info
end

local function SortQuestList(list)
	table.sort(list, function(a, b) 
			-- if both times are not showing actual minutes, check if they are within 2 minutes, else just check if they are the same
			if (a.minutes > 60 and b.minutes > 60 and math.abs(a.minutes - b.minutes) < 2) or a.minutes == b.minutes then
				return a.title < b.title;
			end	
			return a.minutes < b.minutes;
	end);
end

local function SortQuestListByZone(list)
	table.sort(list, function(a, b) 
		if a.zoneId == b.zoneId then
			-- if both times are not showing actual minutes, check if they are within 2 minutes, else just check if they are the same
			if (a.minutes > 60 and b.minutes > 60 and math.abs(a.minutes - b.minutes) < 2) or a.minutes == b.minutes then
				return a.title < b.title;
			end	
			return a.minutes < b.minutes;
		end
		return a.zoneId < b.zoneId;
	end);
end

local function SortQuestListByFaction(list)
	table.sort(list, function(a, b) 
		-- I don't even know how b could be nil but apparently it can..
		--if a and not b then return true; end
		if a.faction == b.faction then
			-- if both times are not showing actual minutes, check if they are within 2 minutes, else just check if they are the same
			if (a.minutes > 60 and b.minutes > 60 and math.abs(a.minutes - b.minutes) < 2) or a.minutes == b.minutes then
				return a.title < b.title;
			end	
			return a.minutes < b.minutes;
		end
		local aIsCriteria = WorldMapFrame.UIElementsFrame.BountyBoard:IsWorldQuestCriteriaForSelectedBounty(a.id);
		local bIsCriteria = WorldMapFrame.UIElementsFrame.BountyBoard:IsWorldQuestCriteriaForSelectedBounty(b.id);
		if aIsCriteria ~= bIsCriteria then
			return aIsCriteria and not bIsCriteria;
		end
		return a.faction < b.faction;
	end);
end

local function SortQuestListByType(list)
	table.sort(list, function(a, b) 
		if a.type == b.type then
			if a.rarity == b.rarity then
				if (a.isElite and b.isElite) or (not a.isElite and not b.isElite) then
					-- if both times are not showing actual minutes, check if they are within 2 minutes, else just check if they are the same
					if (a.minutes > 60 and b.minutes > 60 and math.abs(a.minutes - b.minutes) < 2) or a.minutes == b.minutes then
						return a.title < b.title;
					end	
					return a.minutes < b.minutes;
				end
				return b.isElite;
			end
			return a.rarity < b.rarity;
		end
		return a.type < b.type;
	end);
end

local function SortQuestListByName(list)
	table.sort(list, function(a, b) 
		return a.title < b.title;
	end);
end

local function SortQuestListByReward(list)
	table.sort(list, function(a, b) 
		if a.rewardType == b.rewardType then
			if not a.numItems or not b.numItems or a.numItems == b.numItems then
				-- if both times are not showing actual minutes, check if they are within 2 minutes, else just check if they are the same
				if (a.minutes > 60 and b.minutes > 60 and math.abs(a.minutes - b.minutes) < 2) or a.minutes == b.minutes then
					return a.title < b.title;
				end	
				return a.minutes < b.minutes;
			end
			return a.numItems > b.numItems;
		end
		return a.rewardType < b.rewardType;
	end);
end

local function GetQuestTimeString(questId)
	local timeLeftMinutes = C_TaskQuest.GetQuestTimeLeftMinutes(questId);
	local timeString = "";
	local color = BWQ_WHITE_FONT_COLOR;
	if ( timeLeftMinutes ) then
		if ( timeLeftMinutes <= WORLD_QUESTS_TIME_CRITICAL_MINUTES ) then
			-- Grace period, show the actual time left
			color = RED_FONT_COLOR;
			timeString = SecondsToTime(timeLeftMinutes * 60);
		elseif timeLeftMinutes <= 60 + WORLD_QUESTS_TIME_CRITICAL_MINUTES then
			timeString = SecondsToTime((timeLeftMinutes - WORLD_QUESTS_TIME_CRITICAL_MINUTES) * 60);
		elseif timeLeftMinutes < 24 * 60 + WORLD_QUESTS_TIME_CRITICAL_MINUTES then
			timeString = D_HOURS:format(math.floor(timeLeftMinutes - WORLD_QUESTS_TIME_CRITICAL_MINUTES) / 60);
		else
			timeString = D_DAYS:format(math.floor(timeLeftMinutes - WORLD_QUESTS_TIME_CRITICAL_MINUTES) / 1440);
		end
	end

	return timeLeftMinutes, timeString, color;
end

function addon:SetQuestReward(info)
	local _, texture, numItems, quality, rewardType = nil, "", 0, 1, 0;
	
	if GetNumQuestLogRewards(info.id) > 0 then
		_, texture, numItems, quality = GetQuestLogRewardInfo(1, info.id);
		local itemId = select(6, GetQuestLogRewardInfo(1, info.id))
		if itemId and IsArtifactItem(itemId) then
			WorldMap_AddQuestRewardsToTooltip(info.id);
			numItems = tonumber(string.match(WorldMapTooltipTooltipTextLeft4:GetText(), '%d+'));
			rewardType = BWQ_REWARDTYPE_ARTIFACT;
			WorldMapTooltip:Hide();
		elseif itemId and select(9, GetItemInfo(itemId)) ~= "" then
			rewardType = BWQ_REWARDTYPE_ARMOR;
		else
			rewardType = BWQ_REWARDTYPE_ITEM;
		end
		
	elseif GetQuestLogRewardMoney(info.id) > 0 then
		numItems = floor(abs(GetQuestLogRewardMoney(info.id) / 10000))
		texture = "Interface/ICONS/INV_Misc_Coin_01";
		rewardType = BWQ_REWARDTYPE_GOLD;
	elseif GetNumQuestLogRewardCurrencies(info.id) > 0 then
		_, texture, numItems = GetQuestLogRewardCurrencyInfo(1, info.id)
		rewardType = BWQ_REWARDTYPE_CURRENCY;
	end
	info.rewardQuality = quality;
	info.rewardTexture = texture;
	info.numItems = numItems;
	info.rewardType = rewardType;
end

local function AddQuestToList(list, qInfo, zoneId)
	local tagID, tagName, worldQuestType, rarity, isElite, tradeskillLineIndex = GetQuestTagInfo(qInfo.questId);
	local title, factionId = C_TaskQuest.GetQuestInfoByQuestID(qInfo.questId);
	local minutes, timeString, color = GetQuestTimeString(qInfo.questId);
	if minutes == 0 then return end;
	local faction = factionId and GetFactionInfoByID(factionId) or "";
	
	local info = GetOrCreateQuestInfo();
	info.id = qInfo.questId;
	info.title = title;
	info.timeString = timeString;
	info.color = color;
	info.minutes = minutes;
	info.faction = faction;
	info.factionId = factionId;
	info.type = worldQuestType;
	info.rarity = rarity;
	info.isElite = isElite;
	info.zoneId = zoneId;
	info.tradeskill = tradeskillLineIndex;
	info.numObjectives = qInfo.numObjectives;
	addon:SetQuestReward(info)
	table.insert(list, info)
end

local function DisplayQuestType(frame, questInfo)
	local inProgress = false;
	local isCriteria = WorldMapFrame.UIElementsFrame.BountyBoard:IsWorldQuestCriteriaForSelectedBounty(questInfo.id);
	local questType, rarity, isElite, tradeskillLineIndex = questInfo.type, questInfo.rarity, questInfo.isElite, questInfo.tradeskill
	
	frame:Show();
	
	if isElite then
		frame.elite:Show();
	else
		frame.elite:Hide();
	end
	
	if rarity == LE_WORLD_QUEST_QUALITY_COMMON then
		frame.bg:SetTexture("Interface/WorldMap/UI-QuestPoi-NumberIcons");
		frame.bg:SetTexCoord(0.875, 1, 0.375, 0.5);
		frame.bg:SetSize(28, 28);
	elseif rarity == LE_WORLD_QUEST_QUALITY_RARE then
		frame.bg:SetAtlas("worldquest-questmarker-rare");
		frame.bg:SetTexCoord(0, 1, 0, 1);
		frame.bg:SetSize(18, 18);
		--ApplyAtlasTexturesToPOI(button, "worldquest-questmarker-rare", "worldquest-questmarker-rare-down", "worldquest-questmarker-rare", 18, 18);
	elseif rarity == LE_WORLD_QUEST_QUALITY_EPIC then
		frame.bg:SetAtlas("worldquest-questmarker-epic");
		frame.bg:SetTexCoord(0, 1, 0, 1);
		frame.bg:SetSize(18, 18);
		--ApplyAtlasTexturesToPOI(button, "worldquest-questmarker-epic", "worldquest-questmarker-epic-down", "worldquest-questmarker-epic", 18, 18);
	end
	
	local tradeskillLineID = tradeskillLineIndex and select(7, GetProfessionInfo(tradeskillLineIndex));
	if ( questType == LE_QUEST_TAG_TYPE_PVP ) then
		if ( inProgress ) then
			frame.texture:SetAtlas("worldquest-questmarker-questionmark");
			frame.texture:SetSize(10, 15);
		else
			frame.texture:SetAtlas("worldquest-icon-pvp-ffa", true);
		end
	elseif ( questType == LE_QUEST_TAG_TYPE_PET_BATTLE ) then
		if ( inProgress ) then
			frame.texture:SetAtlas("worldquest-questmarker-questionmark");
			frame.texture:SetSize(10, 15);
		else
			frame.texture:SetAtlas("worldquest-icon-petbattle", true);
		end
	elseif ( questType == LE_QUEST_TAG_TYPE_PROFESSION and WORLD_QUEST_ICONS_BY_PROFESSION[tradeskillLineID] ) then
		if ( inProgress ) then
			frame.texture:SetAtlas("worldquest-questmarker-questionmark");
			frame.texture:SetSize(10, 15);
		else
			frame.texture:SetAtlas(WORLD_QUEST_ICONS_BY_PROFESSION[tradeskillLineID], true);
		end
	elseif ( questType == LE_QUEST_TAG_TYPE_DUNGEON ) then
		if ( inProgress ) then
			frame.texture:SetAtlas("worldquest-questmarker-questionmark");
			frame.texture:SetSize(10, 15);
		else
			frame.texture:SetAtlas("worldquest-icon-dungeon", true);
		end
	else
		if ( inProgress ) then
			frame.texture:SetAtlas("worldquest-questmarker-questionmark");
			frame.texture:SetSize(10, 15);
		else
			frame.texture:SetAtlas("worldquest-questmarker-questbang");
			frame.texture:SetSize(6, 15);
		end
	end
	
	if ( isCriteria ) then
		if ( isElite ) then
			frame.criteriaGlow:SetAtlas("worldquest-questmarker-dragon-glow", false);
			frame.criteriaGlow:SetPoint("CENTER", 0, -1);
		else
			frame.criteriaGlow:SetAtlas("worldquest-questmarker-glow", false);
			frame.criteriaGlow:SetPoint("CENTER", 0, 0);
		end
		frame.criteriaGlow:Show();
	else
		frame.criteriaGlow:Hide();
	end
end

function addon:IsFiltering()
	for k, category in pairs(_filters)do
		for k2, flag in pairs(category.flags) do
			if flag then return true; end
		end
	end
	return false;
end

function addon:isUsingFilterNr(id)
	if not _filters[id] then return false end
	local flags = _filters[id].flags;
	for k, flag in pairs(flags) do
		if flag then return true; end
	end
	return false;
end

function addon:PassesAllFilters(qInfo)
	local tagID, tagName, worldQuestType, rarity, isElite, tradeskillLineIndex = GetQuestTagInfo(qInfo.questId);
	local title, factionId = C_TaskQuest.GetQuestInfoByQuestID(qInfo.questId);
	local faction = factionId and GetFactionInfoByID(factionId) or "";
	
	if addon:isUsingFilterNr(1) and not addon:PassesFactionFilter(faction ,factionId) then return false; end
	if addon:isUsingFilterNr(2) and not addon:PassesTypeFilter(worldQuestType, isElite) then return false; end
	if addon:isUsingFilterNr(3) and not addon:PassesRewardFilter(qInfo.questId) then return false; end
	
	return true;
end

function addon:PassesFactionFilter(faction ,factionId)
	local faction = factionId and GetFactionInfoByID(factionId) or "";
	-- Factions (1)
	local flags = _filters[1].flags
	if flags[faction] ~= nil and flags[faction] then return true; end
	return false;
end

function addon:PassesTypeFilter(worldQuestType, isElite)
	-- Factions (1)
	flags = _filters[2].flags
	-- Default
	if  flags["Default"] and worldQuestType ~= LE_QUEST_TAG_TYPE_PVP and worldQuestType ~= LE_QUEST_TAG_TYPE_PET_BATTLE and worldQuestType ~= LE_QUEST_TAG_TYPE_DUNGEON and  worldQuestType ~= LE_QUEST_TAG_TYPE_PROFESSION then
		return true;
	end
	-- Elite
	if  flags["Elite"] and isElite then return true; end
	-- PvP
	if  flags["PvP"] and worldQuestType == LE_QUEST_TAG_TYPE_PVP then return true; end
	-- Petbattle
	if  flags["Petbattle"] and worldQuestType == LE_QUEST_TAG_TYPE_PET_BATTLE then return true; end
	-- Dungeon
	if  flags["Dungeon"] and worldQuestType == LE_QUEST_TAG_TYPE_DUNGEON then return true; end
	-- Profession
	if  flags["Profession"] and worldQuestType == LE_QUEST_TAG_TYPE_PROFESSION then return true; end
	return false;
end

function addon:PassesRewardFilter(questId)
	local flags = _filters[3].flags
	-- ["Item"] = true, ["Gold"] = true, ["Resources"] = true, 
	-- Item
	if (flags["Armor"] or flags["Artifact"] or flags["Item"]) and GetNumQuestLogRewards(questId) > 0 then
		
		local id = select(6, GetQuestLogRewardInfo(1, questId))
		if not id then return false end
		local link = select(2, GetItemInfo(id));
		-- Armor
		if id and flags["Armor"] and select(9, GetItemInfo(id)) ~= "" then
			return true;
		end
		-- Item
		if id and flags["Item"] and select(9, GetItemInfo(id)) == "" and not IsArtifactItem(id) then
			return true;
		end
		-- Artifact power
		if id and flags["Artifact"] and IsArtifactItem(id) then
			return true;
		end
	end
	-- Gold
	if  flags["Gold"] and GetQuestLogRewardMoney(questId) > 0 then return true; end
	-- Resources
	if  flags["Resources"] and GetNumQuestLogRewardCurrencies(questId) > 0 then return true; end
end

function addon:UpdateFilterDisplay()
	local filterList = "";
	
	for kO, option in pairs(_filters) do
		for kF, flag in pairs(option.flags) do
			if flag then
				filterList = filterList == "" and kF or string.format("%s, %s", filterList, kF);
			end
		end
	end

	BWQ_WorldQuestFrame.filterBar.text:SetText(BWQ_FILTERS:format(filterList)); 
	BWQ_WorldQuestFrame.filterBar:SetHeight(20);
end

function addon:UpdateQuestList()
	if (InCombatLockdown() or UnitLevel("player") < 110 or not WorldMapFrame:IsShown() or not BWQ_WorldQuestFrame:IsShown()) then return end
	local list = questList;
	local mapAreaID = GetCurrentMapAreaID();
	local isQuestZone = ZoneHasSpecificQuests(mapAreaID);
	local filteredOut = 0;
	local isFiltering = addon:IsFiltering()
	
	
	-- if soundId and soundId ~= 0 then
		-- StopSound(soundId);
	-- end
	-- soundId = select(2, PlaySound("PutDownRing"));
	
	for i=#list, 1, -1 do
		list[i].id = -1;
		table.remove(list, i);
	end
	
	if isQuestZone then
		for k, info in ipairs(C_TaskQuest.GetQuestsForPlayerByMapID(mapAreaID)) do
			if not isFiltering or addon:PassesAllFilters(info) then
				AddQuestToList(list, info, mapAreaID);
			elseif GetQuestTimeString(info.questId) ~= 0 then
				filteredOut = filteredOut + 1;
			end
		end
	else
		for k, zoneId in ipairs(_legionZoneIds) do
			for k2, info in ipairs(C_TaskQuest.GetQuestsForPlayerByMapID(zoneId)) do
				if not isFiltering or addon:PassesAllFilters(info) then
					AddQuestToList(list, info, zoneId);
				elseif GetQuestTimeString(info.questId) ~= 0 then
					filteredOut = filteredOut + 1;
				end
			end
		end
		if #list == 0 then
			ShowOverlayMessage(BWQ_NOT_HERE);
		end
	end

	local sortOption = Lib_UIDropDownMenu_GetSelectedValue(BWQ_WorldQuestFrameSortButton);
	if sortOption == 2 then -- faction
		SortQuestListByFaction(list);
	elseif sortOption == 3 then -- type
		SortQuestListByType(list);
	elseif sortOption == 4 then -- zone
		SortQuestListByZone(list);
	elseif sortOption == 5 then -- name
		SortQuestListByName(list);
	elseif sortOption == 6 then -- reward
		SortQuestListByReward(list)
	else -- time or anything else
		SortQuestList(list)
	end
	
	self.time = 0;
	addon:DisplayQuestList();
	
	if isFiltering then
		addon:UpdateFilterDisplay()
	else
		BWQ_WorldQuestFrame.filterBar.text:SetText(""); 
		BWQ_WorldQuestFrame.filterBar:SetHeight(0.1);
	end
	BWQ_WorldQuestFrame.filterBar.clearButton:SetShown(isFiltering);
end

function addon:DisplayQuestList()
	if InCombatLockdown() or UnitLevel("player") < 110 or not WorldMapFrame:IsShown() or not BWQ_WorldQuestFrame:IsShown() then return end
	local scrollFrame = BWQ_QuestScrollFrame;
	local offset = HybridScrollFrame_GetOffset(scrollFrame);
	local buttons = scrollFrame.buttons;
	if buttons == nil then return; end
	
	local list = questList;
	local mapAreaID = GetCurrentMapAreaID();
	local isQuestZone = ZoneHasSpecificQuests(mapAreaID);
	local rewardMissing = false;
	local r, g, b = 1, 1, 1;
	
	HideOverlayMessage();
	
	for i=1, #buttons do
		local button = buttons[i];
		local displayIndex = i + offset;
		button:Hide();
		button.reward.amount:Hide();
		button.trackedBorder:Hide();
		if ( displayIndex <= #list) then
			local q = list[displayIndex];
			button:Show();
			button.title:SetText(q.title);
			button.time:SetTextColor(q.color.r, q.color.g, q.color.b, 1);
			button.time:SetText(q.timeString);
			button.extra:SetText(isQuestZone and "" or GetMapNameByID(q.zoneId));
			button.faction.icon:SetTexture(factionIcons[q.factionId] or "");
			DisplayQuestType(button.type, q)
			-- display reward
			button.reward:Show();
			button.reward.icon:Show();
			r, g, b = GetItemQualityColor(q.rewardQuality);
			button.reward.iconBorder:SetVertexColor(r, g, b);
			if q.rewardTexture and q.rewardTexture ~= "" then
				button.reward.icon:SetTexture(q.rewardTexture);
			else
				rewardMissing = true;
				button.reward.icon:SetTexture("Interface/ICONS/INV_Misc_QuestionMark");
			end
			

			if q.numItems > 1 then
				button.reward.amount:SetText(q.numItems);
				button.reward.amount:Show();
				if q.rewardType == BWQ_REWARDTYPE_ARTIFACT then
					r, g, b = GetItemQualityColor(2);
				else
					r, g, b = 1, 1, 1;
				end
				button.reward.amount:SetVertexColor(r, g, b);
			end
			
			if GetSuperTrackedQuestID() == q.id then
				button.trackedBorder:Show();
			end
			
			button.info = q;
			button.zoneId = q.zoneId;
			button.questId = q.id;
			button.numObjectives = q.numObjectives;
		end
	end
	
	HybridScrollFrame_Update(BWQ_QuestScrollFrame, #list * 38, scrollFrame:GetHeight());
	
	addon.events.updatePeriod = rewardMissing and 0.1 or 60;
	
end

function addon:SetAllFilterTo(id, value)
	local options = _filters[id].flags;
	for k, v in pairs(options) do
		options[k] = value;
	end
end

function addon:InitFilter(self, level)
	local info = Lib_UIDropDownMenu_CreateInfo();
	info.keepShownOnClick = true;	
	
	if level == 1 then
		info.checked = 	nil;
		info.isNotRadio = nil;
		info.func =  nil;
		info.hasArrow = true;
		info.notCheckable = true;
		
		for k, v in pairs(_filters) do
			info.text = v.name;
			info.value = k;
			Lib_UIDropDownMenu_AddButton(info, level)
		end
	else --if level == 2 then
		
		info.hasArrow = false;
		info.isNotRadio = true;
		info.notCheckable = true;
			
		info.text = CHECK_ALL
		info.func = function()
						addon:SetAllFilterTo(LIB_UIDROPDOWNMENU_MENU_VALUE, true);
						Lib_UIDropDownMenu_Refresh(self, 1, 2);
						addon:UpdateQuestList();
					end
		Lib_UIDropDownMenu_AddButton(info, level)
		
		info.text = UNCHECK_ALL
		info.func = function()
						addon:SetAllFilterTo(LIB_UIDROPDOWNMENU_MENU_VALUE, false);
						Lib_UIDropDownMenu_Refresh(self, 1, 2);
						addon:UpdateQuestList();
					end
		Lib_UIDropDownMenu_AddButton(info, level)

		if LIB_UIDROPDOWNMENU_MENU_VALUE then
			local options = _filters[LIB_UIDROPDOWNMENU_MENU_VALUE].flags;
			info.notCheckable = false;
			for k, v in pairs(options) do
			
				info.text = k;
				info.func = function(_, _, _, value)
									options[k] = value;
									addon:UpdateQuestList();
								end
				info.checked = function() return options[k] end;
				Lib_UIDropDownMenu_AddButton(info, level);			
			end
		end
	end

end

function addon:InitSort(self, level)
	local selectedValue = Lib_UIDropDownMenu_GetSelectedValue(self);
	local info = Lib_UIDropDownMenu_CreateInfo();
	--info.func = WardrobeCollectionFrameWeaponDropDown_OnClick;
	local buttonsAdded = 0;
	info.func = function(self, category) addon:Sort_OnClick(self, category) end
	
	for k, option in ipairs(_sortOptions) do
		info.text = option;
		info.arg1 = k;
		info.value = k;
		if k == selectedValue then
			info.checked = 1;
		else
			info.checked = nil;
		end
		Lib_UIDropDownMenu_AddButton(info, level);
		buttonsAdded = buttonsAdded + 1;
	end
	
	return buttonsAdded;
end

function addon:Sort_OnClick(self, category)
	
	local dropdown = BWQ_WorldQuestFrameSortButton;
	if ( category and dropdown.active ~= category ) then
		Lib_CloseDropDownMenus();
		dropdown.active = category
		--WardrobeCollectionFrame_SetActiveCategory(category);
		Lib_UIDropDownMenu_SetSelectedValue(dropdown, category);
		Lib_UIDropDownMenu_SetText(dropdown, BWQ_SORT_BY:format(_sortOptions[category]));
		addon:UpdateQuestList();
	end
end



local missing = 0;
		
addon.events = CreateFrame("FRAME", "BWQ_EventFrame"); 
addon.events:RegisterEvent("WORLD_MAP_UPDATE");
addon.events:RegisterEvent("PLAYER_REGEN_DISABLED");
addon.events:RegisterEvent("PLAYER_REGEN_ENABLED");
addon.events:RegisterEvent("QUEST_TURNED_IN");
addon.events:RegisterEvent("ADDON_LOADED");
addon.events:SetScript("OnEvent", function(self, event, ...) if self[event] then self[event](self, ...) else print(event) end end)
addon.events.updatePeriod = 60;
addon.events.time = 0;
addon.events:SetScript("OnUpdate", function(self, elapsed) 
		self.time = self.time + elapsed;
		if addon.events.updatePeriod ~= 60 then 
			missing = missing + elapsed
		elseif missing ~= 0 then
			missing = 0;
		end
		
		if self.time >= self.updatePeriod then
			addon:UpdateQuestList();
			self.time = 0;
		end
	end)

function addon.events:ADDON_LOADED(loaded_addon)
	if (loaded_addon ~= addonName) then return; end
	
	QuestMapFrame:Hide()
	
	BWQ_TabNormal.Highlight:Show();
	BWQ_TabNormal.TabBg:SetTexCoord(0.01562500, 0.79687500, 0.78906250, 0.95703125);
	BWQ_TabWorld.TabBg:SetTexCoord(0.01562500, 0.79687500, 0.61328125, 0.78125000);
	
	BWQ_QuestScrollFrame.scrollBar.doNotHide = true;
	HybridScrollFrame_CreateButtons(BWQ_QuestScrollFrame, "BWQ_QuestTemplate", 1, 0);
	HybridScrollFrame_Update(BWQ_QuestScrollFrame, 200, BWQ_QuestScrollFrame:GetHeight());
		
	BWQ_QuestScrollFrame.update = function() addon:DisplayQuestList() end;

	BWQ_WorldQuestFrameFilterDropDown.noResize = true;
	Lib_UIDropDownMenu_Initialize(BWQ_WorldQuestFrameFilterDropDown, function(self, level) addon:InitFilter(self, level) end, "MENU");
	--Lib_UIDropDownMenu_Initialize(BWQ_WorldQuestFrameSortDropDown, function(self, level) addon:InitFilter(self, level) end, "MENU");

	Lib_UIDropDownMenu_Initialize(BWQ_WorldQuestFrameSortButton, function(self) addon:InitSort(self, level) end);
	Lib_UIDropDownMenu_SetWidth(BWQ_WorldQuestFrameSortButton, 90);
	Lib_UIDropDownMenu_SetSelectedValue(BWQ_WorldQuestFrameSortButton, 1);
	Lib_UIDropDownMenu_SetText(BWQ_WorldQuestFrameSortButton, BWQ_SORT_BY:format(_sortOptions[1]));

	-- Update display when clicking world quest tabs to change glow
	hooksecurefunc(WorldMapFrame.UIElementsFrame.BountyBoard, "SetSelectedBountyIndex", function() addon:UpdateQuestList(); end)
	hooksecurefunc("TaskPOI_OnClick", function() addon:DisplayQuestList() end)
	hooksecurefunc("QuestMapFrame_ShowQuestDetails", function() 
			BWQ_WorldQuestFrame:Hide();
			BWQ_TabNormal.Highlight:Show();
			BWQ_TabNormal.TabBg:SetTexCoord(0.01562500, 0.79687500, 0.78906250, 0.95703125);
			BWQ_TabWorld.TabBg:SetTexCoord(0.01562500, 0.79687500, 0.61328125, 0.78125000);
		end)

	BWQ_WorldQuestFrame:SetScript("OnShow", function() 
				addon:UpdateQuestList();
			end);
	BWQ_TabNormal:SetScript("OnEnter", function(self)
				GameTooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT");
				if InCombatLockdown() then
					GameTooltip:SetText(BWQ_COMBATLOCK, nil, nil, nil, nil, true);
				else
					GameTooltip:SetText("Questlog", nil, nil, nil, nil, true);
				end
				GameTooltip:Show();
			end);
	BWQ_TabWorld:SetScript("OnEnter", function(self)
				GameTooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT");
				if InCombatLockdown() then
					GameTooltip:SetText(BWQ_COMBATLOCK, nil, nil, nil, nil, true);
				else
					GameTooltip:SetText("World Quests", nil, nil, nil, nil, true);
				end
				GameTooltip:Show();
			end);
	BWQ_WorldQuestFrame.filterBar.clearButton:SetScript("OnClick", function (self)
				Lib_CloseDropDownMenus();
				for k, v in pairs(_filters) do
					addon:SetAllFilterTo(k, false);
				end
				self:Hide();
				addon:UpdateQuestList();
			end)
	
	self:UnregisterEvent("ADDON_LOADED")
end
	
function addon.events:WORLD_MAP_UPDATE(loaded_addon)
	-- Only update when map is visible
	local mapAreaID = GetCurrentMapAreaID();
	if not InCombatLockdown() and addon.lastMapId ~= mapAreaID then
		addon:UpdateQuestList();
		addon.lastMapId = mapAreaID;
	end
end

function addon.events:PLAYER_REGEN_DISABLED(loaded_addon)
	ShowOverlayMessage(BWQ_COMBATLOCK);
end

function addon.events:PLAYER_REGEN_ENABLED(loaded_addon)
	addon:UpdateQuestList();
end

function addon.events:QUEST_TURNED_IN(loaded_addon)
	addon:UpdateQuestList();
end

----------
-- Slash
----------

SLASH_BWQSLASH1 = '/bwq';
local function slashcmd(msg, editbox)
--	print(missing);
	-- for k, info in pairs(questList) do
		-- print(info.id, info.title);
	-- end
end
SlashCmdList["BWQSLASH"] = slashcmd