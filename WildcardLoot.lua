
local ModuleName = 'Personal Loot'
local WildcardTools, AceGUI = unpack(select(2, ...)); --Import: WildcardTools,
local PL = WildcardTools:NewModule(ModuleName, 'AceEvent-3.0', "AceTimer-3.0")

local SEP = "^"
local NUMROW = 50

local RowGroup, RowGroupByEncounter, OutlineCache, UsedOutlines = {}, {}, {}, {}
local scrollFrameRef, moreRowButtonRef = nil, nil
local IconOutlineBackdrop = {
    bgFile = "",  
    edgeFile = "Interface\\AddOns\\WildcardTools\\assets\\plain_white",
    tile = false,
    tileSize = 0,
    edgeSize = 2,
    insets = {
        left = 0,
        right = 0,
        top = 0,
        bottom = 0
    }
}
local difficultyText = {
	[14] = "Normal",
	[15] = "Heroic",
	[16] = "Mythic"
}
local itemDifficultyToEncounterDifficulty = {
	[3] = 14,
	[5] = 15,
	[6] = 16
}
local classColor = {
	WARRIOR = {0.78, 0.61, 0.43},
	PALADIN = {0.96, 0.55, 0.73},
	HUNTER = {0.67, 0.83, 0.45},
	ROGUE = {1.00, 0.96, 0.41},
	PRIEST = {1.00, 1.00, 1.00},
	DEATHKNIGHT = {0.77, 0.12, 0.23},
	SHAMAN = {0.00, 0.44, 0.87},
	MAGE = {0.41, 0.80, 0.94},
	WARLOCK = {0.58, 0.51, 0.79},
	MONK = {0.00, 1.00, 0.59},
	DRUID = {1.00, 0.49, 0.04},
	DEMONHUNTER = {0.64, 0.19, 0.79}
}

--needs updating for each new raid release
local TrackedEncounters = {
	[2076] = {icon=1711328, instance="Antorus"},--gorothi
	[2074] = {icon=1711330, instance="Antorus"},--hounds
	[2070] = {icon=1711331, instance="Antorus"},--high command
	[2064] = {icon=1711329, instance="Antorus"},--portal keeper
	[2075] = {icon=1711327, instance="Antorus"},--eonar
	[2082] = {icon=1711326, instance="Antorus"},--imonar
	[2088] = {icon=1711333, instance="Antorus"},--kin'gorath
	[2069] = {icon=1711334, instance="Antorus"},--varimathras
	[2073] = {icon=1711332, instance="Antorus"},--coven
	[2063] = {icon=1711325, instance="Antorus"},--aggramar
	[2092] = {icon=1711335, instance="Antorus"},--argus
}

local lootSources = {
    [122450]=2076, --gorothi
    [122135]=2074, --hounds
    [122367]=2070, --high command
    [122104]=2064, --portal keeper
    [276503]=2075, --eonar
    [124158]=2082, --imonar
    [122578]=2088, --kin'gorath
    [122366]=2069, --varimathras
    [122467]=2073, --coven
    [121975]=2063, --aggramar
    [277355]=2092, --argus
}

local lootInstances = {
	"Antorus",
}

--LUA API
local tinsert, tremove = table.insert, table.remove
local SendAddonMessage, RegisterAddonMessagePrefix = C_ChatInfo.SendAddonMessage, C_ChatInfo.RegisterAddonMessagePrefix
local mathmin = math.min

--[[
	Encounter
		ID
		Name
		Difficulty
		GuildGroup
		Date
		Time
		Roster
			GUID
				index
				name
				lootStatus
				class
		Loot
			link
			looterGUID
			looterName
			looterClass
			icon
			tradeable
]]

local function BordifyIcon(icon, r, g, b)
	if icon:GetUserData("border") then
		icon:GetUserData("border"):SetBackdropBorderColor(r,g,b,1)
	else
		local border = nil
		if OutlineCache[1] then
			border = tremove(OutlineCache)
			border:SetParent(icon.frame)
			border:SetPoint("TOPLEFT",icon.frame,"TOPLEFT",0,-5)
			border:SetPoint("BOTTOMRIGHT",icon.frame,"BOTTOMRIGHT",0,5)
		else
			border = CreateFrame("Frame",nil,icon.frame)
			border:SetBackdrop(IconOutlineBackdrop)
			border:SetBackdropColor(0,0,0,0)
			border:SetPoint("TOPLEFT",icon.frame,"TOPLEFT",0,-5)
			border:SetPoint("BOTTOMRIGHT",icon.frame,"BOTTOMRIGHT",0,5)
		end
		border:SetBackdropBorderColor(r,g,b,1)
		border:Show()
		tinsert(UsedOutlines,border)
	end
end

local function AddRow(container, encounter, top) --encounter object, boolean
	local iconTable = {}
	
	local row = AceGUI:Create("SimpleGroup")
	row:SetLayout("Flow")
	row:SetFullWidth(true)
	row:SetUserData("encounter",encounter)
	row:SetUserData("icons",iconTable)
	if top then
		container:AddChild(row,RowGroup[1])
		tinsert(RowGroup,1,row)
	else
		if moreRowButtonRef then
			container:AddChild(row,moreRowButtonRef)
		else
			container:AddChild(row)
		end
		tinsert(RowGroup,row)
	end
	RowGroupByEncounter[encounter] = row
	
	--local of all variables to disable in bossIconButton
	local encounterName
	local encounterRoster
	
	local bossIcon = AceGUI:Create("IconNoHighlight")
	bossIcon:SetWidth(32)
	bossIcon:SetHeight(32)
	bossIcon:SetImageSize(32,32)
	bossIcon:SetImage(TrackedEncounters[encounter.ID] and TrackedEncounters[encounter.ID].icon or 341221)
	if WCTSaved.Options.DifficultyShow then
		bossIcon:SetLabel(string.sub(difficultyText[encounter.Difficulty],1,1))
	end
	bossIcon:SetCallback("OnEnter", function(widget)
		local timeRemaining = (encounter.Time + 7200) - time()
		GameTooltip:SetOwner(widget.frame, "ANCHOR_LEFT", 0, -60)
		GameTooltip:ClearLines()
		if encounter.toDelete then
			GameTooltip:AddLine("Marked For Deletion.",1,0,0)
			GameTooltip:AddLine("Finalized when loot tab is closed.",0.62,0.62,0.62)
			GameTooltip:AddLine("Shift-Click to Restore.",0.62,0.62,0.62)
		else
			GameTooltip:AddLine(encounter.Name,1,1,1)
			GameTooltip:AddDoubleLine(difficultyText[encounter.Difficulty],encounter.ID)
			GameTooltip:AddDoubleLine(strsplit(" ",encounter.Date))
			if timeRemaining > 60 then
				if timeRemaining > 3600 then
					local minutes = floor(timeRemaining / 60) - 60
					GameTooltip:AddLine("1 hour "..minutes.." minutes to trade.",0,1,1)
				else
					GameTooltip:AddLine(floor(timeRemaining / 60).." minutes to trade.",0,1,1)
				end
			elseif timeRemaining > 0 then
				GameTooltip:AddLine(timeRemaining.." seconds to trade.",0,1,1)
			end
		end
		GameTooltip:Show()
	end)
	bossIcon:SetCallback("OnLeave", function(widget)
		GameTooltip:Hide()
	end)
	bossIcon:SetCallback("OnClick", function(widget,callback,click)
		if IsShiftKeyDown() then
			if encounter.toDelete then
				--undelete
				encounter.toDelete = nil
				if WCTSaved.Options.DifficultyShow then
					widget:SetLabel(string.sub(difficultyText[encounter.Difficulty],1,1))
				else
					widget:SetLabel()
				end
				widget.image:SetDesaturated()
				if WCTSaved.Options.DifficultyColor and encounter.Difficulty == 16 then
					BordifyIcon(widget,0.64,0.21,0.93)
				elseif WCTSaved.Options.DifficultyColor and encounter.Difficulty == 15 then
					BordifyIcon(widget,0,0.44,0.87)
				else
					BordifyIcon(widget,0,0,0)
				end
				encounterName:SetText("   "..encounter.Name)
				for _,icon in ipairs(iconTable) do
					icon.image:SetDesaturated()
				end
			else
				--mark for deletion
				encounter.toDelete = true
				widget:SetLabel("|cffff0000X|r")
				widget.image:SetDesaturated(1)
				BordifyIcon(widget,1,0,0)
				encounterName:SetText("   |cffff0000Marked For Deletion|r")
				for _,icon in ipairs(iconTable) do
					icon.image:SetDesaturated(1)
				end
			end
		end
	end)
	if WCTSaved.Options.DifficultyColor and encounter.Difficulty == 16 then
		BordifyIcon(bossIcon,0.64,0.21,0.93)
	elseif WCTSaved.Options.DifficultyColor and encounter.Difficulty == 15 then
		BordifyIcon(bossIcon,0,0.44,0.87)
	else
		BordifyIcon(bossIcon,0,0,0)
	end
	row:AddChild(bossIcon)
	
	encounterName = AceGUI:Create("InteractiveLabel")
	encounterName:SetWidth(150)
	encounterName:SetText("   "..encounter.Name)
	if encounter.GuildGroup then
		encounterName:SetColor(0.25,1,0.25)
	end
	encounterName:SetCallback("OnEnter", function(widget)
		local timeRemaining = (encounter.Time + 7200) - time()
		GameTooltip:SetOwner(bossIcon.frame, "ANCHOR_LEFT", 0, -60)
		GameTooltip:ClearLines()
		if encounter.toDelete then
			GameTooltip:AddLine("Marked For Deletion.",1,0,0)
			GameTooltip:AddLine("Finalized when loot tab is closed.",0.62,0.62,0.62)
			GameTooltip:AddLine("Shift-Click to Restore.",0.62,0.62,0.62)
		else
			GameTooltip:AddLine(encounter.Name,1,1,1)
			GameTooltip:AddDoubleLine(difficultyText[encounter.Difficulty],encounter.ID)
			GameTooltip:AddDoubleLine(strsplit(" ",encounter.Date))
			if timeRemaining > 60 then
				if timeRemaining > 3600 then
					local minutes = floor(timeRemaining / 60) - 60
					GameTooltip:AddLine("1 hour "..minutes.." minutes to trade.",0,1,1)
				else
					GameTooltip:AddLine(floor(timeRemaining / 60).." minutes to trade.",0,1,1)
				end
			elseif timeRemaining > 0 then
				GameTooltip:AddLine(timeRemaining.." seconds to trade.",0,1,1)
			end
		end
		GameTooltip:Show()
	end)
	encounterName:SetCallback("OnLeave", function(widget)
		GameTooltip:Hide()
	end)
	encounterName:SetCallback("OnClick", function(widget,callback,click)
		if IsShiftKeyDown() then
			if encounter.toDelete then
				--undelete
				encounter.toDelete = nil
				if WCTSaved.Options.DifficultyShow then
					bossIcon:SetLabel(string.sub(difficultyText[encounter.Difficulty],1,1))
				else
					bossIcon:SetLabel()
				end
				bossIcon.image:SetDesaturated()
				if WCTSaved.Options.DifficultyColor and encounter.Difficulty == 16 then
					BordifyIcon(bossIcon,0.64,0.21,0.93)
				elseif WCTSaved.Options.DifficultyColor and encounter.Difficulty == 15 then
					BordifyIcon(bossIcon,0,0.44,0.87)
				else
					BordifyIcon(bossIcon,0,0,0)
				end
				widget:SetText("   "..encounter.Name)
				for _,icon in ipairs(iconTable) do
					icon.image:SetDesaturated()
				end
			else
				--mark for deletion
				encounter.toDelete = true
				bossIcon:SetLabel("|cffff0000X|r")
				bossIcon.image:SetDesaturated(1)
				BordifyIcon(bossIcon,1,0,0)
				widget:SetText("   |cffff0000Marked For Deletion|r")
				for _,icon in ipairs(iconTable) do
					icon.image:SetDesaturated(1)
				end
			end
		end
	end)
	row:AddChild(encounterName)
	
	local looted, rostersize = 0, 0
	for _,player in pairs(encounter.Roster) do
		rostersize = rostersize + 1
		if player.lootStatus then
			looted = looted + 1
		end
	end
	
	encounterRoster = AceGUI:Create("InteractiveLabel")
	encounterRoster:SetWidth(50)
	encounterRoster:SetText(tostring(looted).."/"..tostring(rostersize))
	encounterRoster:SetCallback("OnEnter", function(widget)
		local timeRemaining = (encounter.Time + 7200) - time()
		local orderedRoster = {}
		for _,player in pairs(encounter.Roster) do
			tinsert(orderedRoster,player)
		end
		table.sort(orderedRoster, function(a,b) return a.index < b.index end)
		GameTooltip:SetOwner(widget.frame, "ANCHOR_LEFT", -10, 10)
		GameTooltip:ClearLines()
		if encounter.GuildGroup then
			GameTooltip:AddLine(encounter.GuildGroup,0.25,1,0.25)
		end
		for _,player in ipairs(orderedRoster) do
			local timeRemaining = (encounter.Time + 7200) - time()
			local r,g,b = unpack(classColor[player.class])
			if player.lootStatus and player.lootStatus == 2 and timeRemaining > 0 then
				GameTooltip:AddDoubleLine(player.name,"Got Loot",r,g,b,0,1,1)
			elseif player.lootStatus and player.lootStatus >= 1 then
				GameTooltip:AddDoubleLine(player.name,"Got Loot",r,g,b,0.64,0.21,0.93)
			elseif player.lootStatus and player.lootStatus == 0 then
				GameTooltip:AddDoubleLine(player.name,"No Loot",r,g,b,1,1,1)
			--elseif timeRemaining > 0 then
			--	GameTooltip:AddDoubleLine(player.name,"Needs to Loot",r,g,b,1,0,0)
			else
				GameTooltip:AddDoubleLine(player.name,"Didn't Loot",r,g,b,0.62,0.62,0.62)
			end
		end
		GameTooltip:Show()
	end)
	encounterRoster:SetCallback("OnLeave", function(widget)
		GameTooltip:Hide()
	end)
	row:AddChild(encounterRoster)
	row:SetUserData("encounterRoster",encounterRoster)
	
	for i,item in ipairs(encounter.Loot) do
		local ilvl = select(4,GetItemInfo(item.link))
		
		local lootIcon = AceGUI:Create("IconNoHighlight")
		lootIcon:SetUserData("item",item)
		lootIcon:SetWidth(32)
		lootIcon:SetHeight(32)
		lootIcon:SetImageSize(32,32)
		lootIcon:SetImage(item.icon)
		if ilvl then
			lootIcon:SetLabel(tostring(ilvl))
		end
		lootIcon:SetCallback("OnEnter", function(widget)
			local timeRemaining = (item.tradeable + 7200) - time()
			local r,g,b = unpack(classColor[item.looterClass])
			GameTooltip:SetOwner(widget.frame, "ANCHOR_LEFT", 0, 0)
			GameTooltip:ClearLines()
			GameTooltip:SetHyperlink(item.link)
			GameTooltip:AddLine(" ")
			if timeRemaining > 0 then
				local text = "Tradeable for the next"
				if timeRemaining < 60 then
					text = text .. " " .. timeRemaining .. " sec."
				else
					timeRemaining = floor(timeRemaining / 60)
					if timeRemaining >= 60 then
						text = text .. " 1 hour"
						timeRemaining = timeRemaining - 60
					end
					if timeRemaining > 0 then
						text = text .. " " .. timeRemaining .. " min"
					end
					text = text .. "."
				end
				GameTooltip:AddLine(text,0,1,1)
			end
			GameTooltip:AddLine(item.looterName,r,g,b)
			GameTooltip:Show()
		end)
		lootIcon:SetCallback("OnLeave", function(widget)
			GameTooltip:Hide()
		end)
		lootIcon:SetCallback("OnClick",function(widget,callback,button)
			local timeRemaining = (item.tradeable + 7200) - time()
			if button == "LeftButton" and IsShiftKeyDown() then
				local editbox = GetCurrentKeyBoardFocus()
				if editbox then
					editbox:Insert(item.link)
				end
			end
			if button == "LeftButton" and IsControlKeyDown() then
				DressUpItemLink(item.link)
			end
			if button == "RightButton" and IsShiftKeyDown() and IsInRaid() and UnitIsGroupLeader("player") and timeRemaining > 0 then
				if IsAddOnLoaded("RCLootCouncil") then
					RCLootCouncil:GetActiveModule("masterlooter"):AddUserItem(item.link)
					return
				end
				if IsAddOnLoaded("BigDumbLootCouncil") then
					bdlc:sendAction("startSession", item.link, 1)
					return
				end
				SendChatMessage("Link for: "..item.link,"RAID_WARNING")
			end
		end)
		if (item.tradeable + 7200) - time() > 0 then
			BordifyIcon(lootIcon,0,1,1)
		else
			BordifyIcon(lootIcon,0,0,0)
		end
		row:AddChild(lootIcon)
		
		tinsert(iconTable,lootIcon)
	end
end

local function PopulateTab(container)
	local Encounters = WCTSaved.Encounters
	
	container:SetLayout("Fill")
	
	local scrollFrame = AceGUI:Create("ScrollFrame")
	scrollFrame:SetLayout("List")
	container:AddChildren(scrollFrame)
	scrollFrameRef = scrollFrame
	
	local numEncounters = #Encounters
	for i = 1, mathmin(numEncounters,NUMROW) do
		AddRow(scrollFrame, Encounters[i])
	end
	
	if numEncounters > NUMROW then
		local moreRowButton = AceGUI:Create("Button")
		moreRowButton:SetText("Load More Encounters")
		moreRowButton:SetFullWidth(true)
		moreRowButton:SetCallback("OnClick",function(widget)
			for i = #RowGroup+1, mathmin(#Encounters,#RowGroup+NUMROW) do
				AddRow(scrollFrame, Encounters[i])
			end
			if #Encounters == #RowGroup then
				widget:SetText("No More Encounters")
				widget:SetDisabled(true)
				--[[ DOESN'T WORK (for some fucking reason)
				widget:Release()
				moreRowButtonRef = nil
				--]]
			end
		end)
		scrollFrame:AddChild(moreRowButton)
		moreRowButtonRef = moreRowButton
	end
end

function PL:EncounterEnd(event, encounterID, encounterName, difficultyID, groupSize, success)
	if success == 1 and IsInRaid() and (difficultyID == 14 or difficultyID == 15 or difficultyID == 16) and TrackedEncounters[encounterID] and WCTSaved.Options.TrackedInstances[TrackedEncounters[encounterID].instance] and (GetLootMethod()) == "personalloot" then
		local guild = false
		if UnitIsInMyGuild("raid1") and (InGuildParty()) then
			guild = GetGuildInfo("player")
		end
		local killDate = date("%m/%d/%y %H:%M:%S")
		local killTime = time()
		local roster, loot = {}, {}
		local playerZone = false
		for i = 1, GetNumGroupMembers() do
			local unit = "raid"..i
			if UnitIsUnit("player",unit) then
				playerZone = select(7,GetRaidRosterInfo(i))
			end
		end
		for i = 1, GetNumGroupMembers() do
			local name, _, _, _, _, fileName, zone, online = GetRaidRosterInfo(i)
			local guid = UnitGUID("raid"..i)
			if online and zone == playerZone then
				roster[guid] = {index=i, name=name, lootStatus=nil, class=fileName}
			end
		end
		local encounter = {ID=encounterID, Name=encounterName, Difficulty=difficultyID, GuildGroup = guild, Date = killDate, Time = killTime, Roster=roster, Loot=loot}
		tinsert(WCTSaved.Encounters, 1, encounter)
		if WCTSaved.Options.MaxEncounters > 0 then
			WCTSaved.Encounters[WCTSaved.Options.MaxEncounters+1] = nil
		end
		if not isempty(RowGroup) then
			AddRow(scrollFrameRef,encounter,true)
		end
		if WCTSaved.Options.EncounterLootPopup then
			if not WildcardTools_MainFrame then
				WildcardTools:Populate_MainFrame("Personal Loot")
			end
		end
	end
end

local function UpdateEncounterRoster(encounter)
	if RowGroupByEncounter[encounter] then
		local looted, rostersize = 0, 0
		for _,player in pairs(encounter.Roster) do
			rostersize = rostersize + 1
			if player.lootStatus then
				looted = looted + 1
			end
		end
		RowGroupByEncounter[encounter]:GetUserData("encounterRoster"):SetText(tostring(looted).."/"..tostring(rostersize))
	end
end

local function UpdateEncounterLoot(encounter,item)
	for _,oldItem in ipairs(encounter.Loot) do
		if item.looterGUID == oldItem.looterGUID and item.link == oldItem.link then
			if item.tradeable > 0 and oldItem.tradeable == 0 then
				oldItem.tradeable = item.tradeable
				--updates outline if needed to show tradeable
				for i,row in ipairs(RowGroup) do
					if encounter == row:GetUserData("encounter") then
						local iconTable = row:GetUserData("icons")
						for _,icon in ipairs(iconTable) do
							local iconItem = icon:GetUserData("item")
							if iconItem.link == item.link and iconItem.looterGUID == item.looterGUID then
								if (item.tradeable + 7200) - time() > 0 then
									BordifyIcon(icon,0,1,1)
								else
									BordifyIcon(icon,0,0,0)
								end
								return
							end
						end
					end
				end
			end
			return
		end
	end
	tinsert(encounter.Loot,item)
	for i,row in ipairs(RowGroup) do
		if encounter == row:GetUserData("encounter") then
			local iconTable = row:GetUserData("icons")
			local ilvl = select(4,GetItemInfo(item.link))
			
			local lootIcon = AceGUI:Create("IconNoHighlight")
			lootIcon:SetUserData("item",item)
			lootIcon:SetWidth(32)
			lootIcon:SetHeight(32)
			lootIcon:SetImageSize(32,32)
			lootIcon:SetImage(item.icon)
			if ilvl then
				lootIcon:SetLabel(tostring(ilvl))
			end
			lootIcon:SetCallback("OnEnter", function(widget)
				local timeRemaining = (item.tradeable + 7200) - time()
				local r,g,b = unpack(classColor[item.looterClass])
				GameTooltip:SetOwner(widget.frame, "ANCHOR_LEFT", 0, 0)
				GameTooltip:ClearLines()
				GameTooltip:SetHyperlink(item.link)
				GameTooltip:AddLine(" ")
				if timeRemaining > 0 then
					local text = "Tradeable for the next"
					if timeRemaining < 60 then
						text = text .. " " .. timeRemaining .. " sec."
					else
						timeRemaining = floor(timeRemaining / 60)
						if timeRemaining >= 60 then
							text = text .. " 1 hour"
							timeRemaining = timeRemaining - 60
						end
						if timeRemaining > 0 then
							text = text .. " " .. timeRemaining .. " min"
						end
						text = text .. "."
					end
					GameTooltip:AddLine(text,0,1,1)
				end
				GameTooltip:AddLine(item.looterName,r,g,b)
				GameTooltip:Show()
			end)
			lootIcon:SetCallback("OnLeave", function(widget)
				GameTooltip:Hide()
			end)
			lootIcon:SetCallback("OnClick",function(widget,callback,button)
				local timeRemaining = (item.tradeable + 7200) - time()
				if button == "LeftButton" and IsShiftKeyDown() then
					local editbox = GetCurrentKeyBoardFocus()
					if editbox then
						editbox:Insert(item.link)
					end
				end
				if button == "RightButton" and IsShiftKeyDown() and IsInRaid() and (UnitIsGroupLeader("player") or UnitIsRaidOfficer("player")) and timeRemaining > 0 then
					SendChatMessage("Link for: "..item.link,"RAID_WARNING")
				end
			end)
			if (item.tradeable + 7200) - time() > 0 then
				BordifyIcon(lootIcon,0,1,1)
			else
				BordifyIcon(lootIcon,0,0,0)
			end
			row:AddChild(lootIcon)
			
			tinsert(iconTable,row)
			return
		end
	end
end

function PL:MessageHandler(event, prefix, message, channel, fullName, name)
	if prefix == "WCLOOT" and IsInRaid() then
		local unitguid, enc, icon, tradeable, itemlink = strsplit(SEP,message)
		enc = tonumber(enc)
		icon = tonumber(icon)
		tradeable = tradeable == "true"
		local difficulty = nil
		if itemlink then
			local diff = select(12,strsplit(":",itemlink))
			if diff ~= "" then
				difficulty = itemDifficultyToEncounterDifficulty[tonumber(diff)]
			end
		end
		local looterName, looterClass = nil, nil
		for i = 1, GetNumGroupMembers() do
			local n, _, _, _, _, fileName = GetRaidRosterInfo(i)
			if UnitGUID("raid"..i) == unitguid then
				looterName, looterClass = n, fileName
			end
		end
		if looterName then --confirms the sender is in the raid
			local Encounters = WCTSaved.Encounters
			
			local item = {
				link = itemlink,
				looterGUID = unitguid,
				looterName = looterName,
				looterClass = looterClass,				
				icon = icon,
				tradeable = tradeable and time() or 0
			}
			
			for i,encounter in ipairs(Encounters) do
				if (time() - encounter.Time) > 10800 then
					break
				end
				if encounter.Roster[unitguid] and (encounter.Difficulty == difficulty or not difficulty) and enc == encounter.ID then
					if itemlink then
						UpdateEncounterLoot(encounter,item)
						if tradeable then
							encounter.Roster[unitguid].lootStatus = 2
							UpdateEncounterRoster(encounter)
						elseif (not encounter.Roster[unitguid].lootStatus) or encounter.Roster[unitguid].lootStatus < 2 then
							encounter.Roster[unitguid].lootStatus = 1
							UpdateEncounterRoster(encounter)
						end
					elseif not encounter.Roster[unitguid].lootStatus then
						encounter.Roster[unitguid].lootStatus = 0
						UpdateEncounterRoster(encounter)
					end
					break
				end
			end
		end
	end
end

function PL:Options(container)
	local SliderWarning
	
	local DifficultyColorBox = AceGUI:Create("CheckBox")
	DifficultyColorBox:SetLabel("Colored Encounters")
	DifficultyColorBox:SetDescription("Color encounter outline by difficulty.")
	DifficultyColorBox:SetRelativeWidth(0.33)
	DifficultyColorBox:SetValue(WCTSaved.Options.DifficultyColor)
	DifficultyColorBox:SetCallback("OnValueChanged",function(widget) WCTSaved.Options.DifficultyColor = widget:GetValue() end)
	container:AddChild(DifficultyColorBox)
	
	local EncounterSlider = AceGUI:Create("Slider")
	EncounterSlider:SetLabel("Maximum Encounters Stored")
	EncounterSlider:SetRelativeWidth(0.33)
	EncounterSlider:SetSliderValues(0,1000,1)
	EncounterSlider:SetValue(WCTSaved.Options.MaxEncounters)
	EncounterSlider:SetCallback("OnValueChanged",function(widget)
		local newVal = widget:GetValue()
		if newVal < #WCTSaved.Encounters and newVal > 0 then
			SliderWarning:SetText("When you close this tab, encounter data will be deleted forever.")
		else
			SliderWarning:SetText(" ")
		end
		WCTSaved.Options.MaxEncounters = newVal
	end)
	EncounterSlider:SetCallback("OnEnter", function(widget)
		GameTooltip:SetOwner(widget.frame, "ANCHOR_LEFT", 0, -33)
		GameTooltip:SetText("0 means no max.", nil, nil, nil, nil, true)
		GameTooltip:Show()
	end)
	EncounterSlider:SetCallback("OnLeave", function(widget)
		GameTooltip:Hide()
	end)
	container:AddChild(EncounterSlider)
	
	local PopupBox = AceGUI:Create("CheckBox")
	PopupBox:SetLabel("Popup")
	PopupBox:SetDescription("Show loot frame after encounter.")
	PopupBox:SetRelativeWidth(0.33)
	PopupBox:SetValue(WCTSaved.Options.EncounterLootPopup)
	PopupBox:SetCallback("OnValueChanged",function(widget) WCTSaved.Options.EncounterLootPopup = widget:GetValue() end)
	container:AddChild(PopupBox)
	
	SliderWarning = AceGUI:Create("InteractiveLabel")
	SliderWarning:SetText(" ")
	SliderWarning:SetColor(1,0,0)
	SliderWarning:SetFullWidth(true)
	SliderWarning:SetJustifyH("CENTER")
	container:AddChild(SliderWarning)
	
	local DifficultyShowBox = AceGUI:Create("CheckBox")
	DifficultyShowBox:SetLabel("Difficulty Indicator")
	DifficultyShowBox:SetDescription("A letter to indicate encounter difficulty.")
	DifficultyShowBox:SetRelativeWidth(0.33)
	DifficultyShowBox:SetValue(WCTSaved.Options.DifficultyShow)
	DifficultyShowBox:SetCallback("OnValueChanged",function(widget) WCTSaved.Options.DifficultyShow = widget:GetValue() end)
	container:AddChild(DifficultyShowBox)
	
	local FastLootBox = AceGUI:Create("CheckBox")
	FastLootBox:SetLabel("Fast Looting")
	FastLootBox:SetDescription("Fast autolooting. |cffee5555This addon is not compatible with fast looting from other addons.|r")
	FastLootBox:SetRelativeWidth(0.35)
	FastLootBox:SetValue(WCTSaved.Options.FastLoot)
	FastLootBox:SetCallback("OnValueChanged",function(widget) WCTSaved.Options.FastLoot = widget:GetValue() end)
	container:AddChild(FastLootBox)
	
	for _,instance in ipairs(lootInstances) do
		if WCTSaved.Options.TrackedInstances[instance] == nil then
			WCTSaved.Options.TrackedInstances[instance] = true
		end
		local TrackInstanceBox = AceGUI:Create("CheckBox")
		TrackInstanceBox:SetLabel("Track "..instance.." Bosses")
		TrackInstanceBox:SetRelativeWidth(0.33)
		TrackInstanceBox:SetValue(WCTSaved.Options.TrackedInstances[instance])
		TrackInstanceBox:SetCallback("OnValueChanged",function(widget) WCTSaved.Options.TrackedInstances[instance] = widget:GetValue() end)
		container:AddChild(TrackInstanceBox)
	end
end

local function TabCloseFunction()
	local Max, Encounters = WCTSaved.Options.MaxEncounters, WCTSaved.Encounters
	RowGroup, RowGroupByEncounter = {}, {}
	scrollFrameRef, moreRowButtonRef = nil, nil
	for i,frame in ipairs(UsedOutlines) do
		frame:Hide()
		UsedOutlines[i] = nil
		tinsert(OutlineCache,frame)
	end
	--delete encounters marked for deletion
	for i,encounter in ipairs(Encounters) do
		if encounter.toDelete then
			tremove(Encounters,i)
		end
	end
	--delete encounters past max
	if Max > 0 then
		for i = (Max+1), #Encounters do
			Encounters[i] = nil
		end
	end
end

function PL:GetTabs()
	WildcardTools.TabFunctions["Personal Loot"] = PopulateTab
	WildcardTools.TabCloseFunctions[ModuleName] = TabCloseFunction
    return {text="Loot Tracker", value="Personal Loot"}
end

function PL:OnInitialize()
    -- Called when the addon is loaded
	WCTSaved.Options.MaxEncounters = WCTSaved.Options.MaxEncounters or 0
	WCTSaved.Options.DifficultyColor = WCTSaved.Options.DifficultyColor or false
	WCTSaved.Options.DifficultyShow = WCTSaved.Options.DifficultyShow or false
	WCTSaved.Options.EncounterLootPopup = WCTSaved.Options.EncounterLootPopup or false
	WCTSaved.Options.FastLoot = WCTSaved.Options.FastLoot or false
	WCTSaved.Options.TrackedInstances = WCTSaved.Options.TrackedInstances or {}
	WCTSaved.Encounters = WCTSaved.Encounters or {}
end

function PL:OnEnable()
    -- Called when the addon is enabled
	RegisterAddonMessagePrefix("WCLOOT")
	PL:RegisterEvent("CHAT_MSG_ADDON", "MessageHandler")
	PL:RegisterEvent("ENCOUNTER_END", "EncounterEnd")
	
	--for loot sender below
	PL:RegisterEvent("LOOT_OPENED", "SenderLootOpened")
	PL:RegisterEvent("LOOT_CLOSED", "SenderLootClosed")
	PL:RegisterEvent("LOOT_SLOT_CLEARED", "SenderLootSlotCleared")
	PL:RegisterEvent("CHAT_MSG_LOOT", "SenderChatMsgLoot")
	PL:RegisterEvent("BAG_UPDATE_DELAYED", "SenderBagUpdateDelayed")
end

function PL:OnDisable()
    -- Called when the addon is disabled
end

--------------- LOOT SENDER ---------------

CreateFrame('GameTooltip', 'ItemTradeableTooltip', nil, 'GameTooltipTemplate')
ItemTradeableTooltip:SetOwner(WorldFrame, 'ANCHOR_NONE')

local itemLinks, itemEncounters, pendingSwaps = {}, {}, {}

local itemBlacklist = {
    --[0] = true, 
}

local isQuestItem = function(i)
    ItemTradeableTooltip:SetLootItem(i)
    return ItemTradeableTooltipTextLeft2:GetText() == "Quest Item"
end

local swapBack = false
local looting = false
local openedTime
local updateBags = false
local addLootTime = GetTime()
local lootdelay = 0
local LOOT_DELAY = 0.3

local isTradeable = function(id)
    ItemTradeableTooltip:SetInventoryItemByID(id)
    local i = 1
    while _G["ItemTradeableTooltipTextLeft"..i] do
        local text = _G["ItemTradeableTooltipTextLeft"..i]:GetText() or ""
        if string.find(text,"may trade this item") then
            return true
        end
        i=i+1
    end
    return false
end

--LOOT_OPENED
function PL:SenderLootOpened(event, ...)
	local lootedBoss = false
	local lootFound = false
	--print("items"..GetNumLootItems())
	for i=1,GetNumLootItems() do
		for s=1,#{GetLootSourceInfo(i)},2 do
			local guid, count = select(s,GetLootSourceInfo(i))
			local id = tonumber((select(6,strsplit("-",guid))))
			--print(count,GetLootSlotLink(i))
			--print("mob guid: "..guid)
			--id = 124158
			if lootSources[id] then
				local encounter = lootSources[id]
				lootedBoss = encounter
				if GetLootSlotType(i) == 1 then
					local quality = select(5,GetLootSlotInfo(i))
					local itemID = select(2,strsplit(":",GetLootSlotLink(i)))
					--print("ItemID: "..itemID)
					--say loot is found if epic or better item is found that is not on blacklist and is not a quest item
					if quality >= 4 and (not itemBlacklist[itemID]) and (not isQuestItem(i)) then
						lootFound = true
						itemLinks[GetLootSlotLink(i)] = {i,encounter,false}
					end
				end
			end
		end
	end
	if lootedBoss and not lootFound then
		--print("no loot") --send no loot found message
		local guid = UnitGUID('player')
		local sendmessage = strjoin("^",guid,tostring(lootedBoss))
		SendAddonMessage("WCLOOT", sendmessage, "RAID")
	end
	looting = true
	openedTime = GetTime()
	----[[
	if WCTSaved.Options.FastLoot and GetCVarBool("autoLootDefault") ~= IsModifiedClick("AUTOLOOTTOGGLE") then
		if (GetTime() - lootdelay) >= LOOT_DELAY then
			for i = GetNumLootItems(), 1, -1 do
				LootSlot(i)
			end
			lootdelay = GetTime()
		end
	end
	--]]
end

--LOOT_CLOSED
function PL:SenderLootClosed(event, ...)
	looting = false
	--[[
	if openedTime and openedTime + 0.2 > GetTime() then
		--print("fast")
	end
	--]]
end

--LOOT_SLOT_CLEARED
function PL:SenderLootSlotCleared(event, ...)
	local slot = ...
	for link, info in pairs(itemLinks) do
		if info[1] == slot then
			info[3] = true
		end
	end
end

--CHAT_MSG_LOOT
function PL:SenderChatMsgLoot(event, ...)
	local message = ...
	if string.find(message,"You receive loot:") then
		message = string.gsub(message,"You receive loot: ","")
		message = string.sub(message,1,-2)
		if itemLinks[message] then
			itemLinks[message][3] = true
		end
	end
end

--BAG_UPDATE_DELAYED
function PL:SenderBagUpdateDelayed(event, ...)
	if not isempty(itemLinks) then
		updateBags = true
	end
end

--ON_UPDATE
function PL:SenderOnUpdate(elapsed)
	if updateBags then
		
		if InCombatLockdown() then
			addLootTime = GetTime()
		else
			local isLocked = false
			for i = 0, NUM_BAG_SLOTS do
				for j = 1, GetContainerNumSlots(i) do
					local _, _, locked = GetContainerItemInfo(i,j)
					isLocked = isLocked or locked
				end
			end
			if isLocked then
				addLootTime = GetTime()
			elseif GetTime() - addLootTime > 0.2 then
				if not isLocked then
					updateBags = false
					local links = {}
					for i = 0, NUM_BAG_SLOTS do
						for j = 1, GetContainerNumSlots(i) do
							local link = GetContainerItemLink(i, j);
							if itemLinks[link] and itemLinks[link][3] then
								links[link] = true
								local a = {i,j}
								pendingSwaps[a]=link
								itemEncounters[a]=itemLinks[link][2]
								--add to list of swaps to do
							end
						end
					end
					for l,_ in pairs(links) do
						itemLinks[l] = nil
					end
					
					if not looting then
						itemLinks = {}
					end
				end
			end
		end
	end
	if swapBack then
        local i,j = unpack(swapBack)
        local _, _, locked = GetContainerItemInfo(i,j)
        local _, _, slotOneLocked = GetContainerItemInfo(0,1)
        if not (locked or slotOneLocked or InCombatLockdown()) then
            local link = pendingSwaps[swapBack]
            local itemID = tonumber((select(2,strsplit(":",link))))
            if isTradeable(itemID) then
                local guid = UnitGUID("player")
                local encounter = itemEncounters[swapBack]
                local icon = (GetContainerItemInfo(0,1)) or 347737
                local sendmessage = strjoin("^",guid,encounter,icon,"true",link)
                SendAddonMessage("WCLOOT", sendmessage, "RAID")
                --print(sendmessage)
            else
                local guid = UnitGUID("player")
                local encounter = itemEncounters[swapBack]
                local icon = (GetContainerItemInfo(0,1)) or 347737
                local sendmessage = strjoin("^",guid,tostring(encounter),tostring(icon),"false",link)
                SendAddonMessage("WCLOOT", sendmessage, "RAID")
                --print(sendmessage)
            end
            PickupContainerItem(0,1)
            PickupContainerItem(i,j)
            pendingSwaps[swapBack] = nil
            itemEncounters[swapBack] = nil
            swapBack = false
        end
    else
        for slot,link in pairs(pendingSwaps) do
            if CursorHasItem() then
                ClearCursor()
            end
            local i,j = unpack(slot)
            local _, _, locked, _, _, _, _, _, _, itemID = GetContainerItemInfo(i,j)
            local _, _, slotOneLocked = GetContainerItemInfo(0,1)
            if not (locked or slotOneLocked or InCombatLockdown()) then
                PickupContainerItem(i,j)
                PickupContainerItem(0,1)
                swapBack = slot
            end
        end
    end
end

local lootCheckFrame = CreateFrame("Frame")
lootCheckFrame:SetScript("OnUpdate", PL.SenderOnUpdate)
