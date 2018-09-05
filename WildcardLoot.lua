
local ModuleName = 'Personal Loot'
local WildcardTools, AceGUI = unpack(select(2, ...)); --Import: WildcardTools,
local PL = WildcardTools:NewModule(ModuleName, 'AceEvent-3.0', "AceTimer-3.0", "AceComm-3.0")

local SEP = "^"
local NUMROW = 50

local RowGroup, RowGroupByEncounter, OutlineCache, UsedOutlines, LCRowGroup, LCRowGroupByGUID = {}, {}, {}, {}, {}, {}
local scrollFrameRef, moreRowButtonRef, LCRaiderInputGroupRef, LCScrollGroupRef
local LCGuildiesCache = {}
local needsUpdate = true
local selectedLCEncounter, selectedLCItem
local UpdateLCItem --function
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
local invSlot = {
	INVTYPE_HEAD = {1},
	INVTYPE_NECK = {2},
	INVTYPE_SHOULDER = {3},
	INVTYPE_BODY = {4},
	INVTYPE_CHEST = {5},
	INVTYPE_ROBE = {5},
	INVTYPE_WAIST = {6},
	INVTYPE_LEGS = {7},
	INVTYPE_FEET = {8},
	INVTYPE_WRIST = {9},
	INVTYPE_HAND = {10},
	INVTYPE_FINGER = {11, 12},
	INVTYPE_TRINKET = {13, 14},
	INVTYPE_CLOAK = {15},
	INVTYPE_WEAPON = {16, 17},
	INVTYPE_SHIELD = {16, 17},
	INVTYPE_2HWEAPON = {16, 17},
	INVTYPE_WEAPONMAINHAND = {16, 17},
	INVTYPE_WEAPONOFFHAND = {16, 17},
	INVTYPE_HOLDABLE = {16, 17},
	INVTYPE_RANGED = {16, 17},
	INVTYPE_RANGEDRIGHT = {16, 17},
	INVTYPE_TABARD = {19},
}
local interestText = {
	MAINSPEC = "Main Spec",
	MINORUP = "Minor Up",
	OFFSPEC = "Offspec",
	GREED = "Greed"
}

--needs updating for each new raid release
local TrackedEncounters = {
	--Antorus, the Burning Throne
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
	--Uldir
	[2144] = {icon=2032226, instance="Uldir"},--taloc
	[2141] = {icon=2032224, instance="Uldir"},--mother
	[2128] = {icon=2032222, instance="Uldir"},--fetid devourer
	[2136] = {icon=2032227, instance="Uldir"},--zek'voz
	[2134] = {icon=2032221, instance="Uldir"},--vectis
	[2145] = {icon=2032228, instance="Uldir"},--zul
	[2135] = {icon=2032225, instance="Uldir"},--mythrax
	[2122] = {icon=2032223, instance="Uldir"},--g'huun
}

local lootSources = {
	--Antorus, the Burning Throne
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
	--Uldir
	[137119]=2144, --taloc
    [291079]=2141, --mother
    [133298]=2128, --fetid devourer
    [134445]=2136, --zek'voz
    [134442]=2134, --vectis
    [138967]=2145, --zul
    [134546]=2135, --mythrax
    [132998]=2122, --g'huun
}

local lootInstances = {
	"Antorus",
	"Uldir"
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
			council
				GUID
					name
					class
			submissions
				GUID
					name
					guid
					class
					link1
					link2
					interest
					note
					voters
						GUID = currentlyOnCouncil (bool)
			awardeeGUID
			awardeeName
			awardeeClass
]]

local selectedEncounterFrame = CreateFrame("Frame")
selectedEncounterFrame.texture = selectedEncounterFrame:CreateTexture()
selectedEncounterFrame.texture:SetAllPoints(selectedEncounterFrame)
selectedEncounterFrame.texture:SetTexture("Interface\\BUTTONS\\UI-Listbox-Highlight2")
selectedEncounterFrame.texture:SetVertexColor(0.6,0.6,1,0.3)

local function BordifyIcon(icon, r, g, b)
	if icon:GetUserData("border") then
		icon:GetUserData("border"):SetBackdropBorderColor(r,g,b,1)
	else
		local border = nil
		if OutlineCache[1] then
			border = tremove(OutlineCache)
			border:SetParent(icon.frame)
			border:SetPoint("TOPLEFT",icon.image,"TOPLEFT",0,0)
			border:SetPoint("BOTTOMRIGHT",icon.image,"BOTTOMRIGHT",0,0)
		else
			border = CreateFrame("Frame",nil,icon.frame)
			border:SetBackdrop(IconOutlineBackdrop)
			border:SetBackdropColor(0,0,0,0)
			border:SetPoint("TOPLEFT",icon.image,"TOPLEFT",0,0)
			border:SetPoint("BOTTOMRIGHT",icon.image,"BOTTOMRIGHT",0,0)
		end
		border:SetBackdropBorderColor(r,g,b,1)
		border:Show()
		icon:SetUserData("border",border)
		tinsert(UsedOutlines,border)
	end
end

function PL:UpdateGuildyCache(event,changed)
	if changed or needsUpdate then
		needsUpdate = false
		LCGuildiesCache = {}
		for i=1,GetNumGuildMembers() do
			local _, _, rank, _, _, _, _, _, _, _, _, _, _, _, _, _, guid = GetGuildRosterInfo(i)
			if guid and rank then
				LCGuildiesCache[guid] = rank
			end
		end
	end
end

--compiles and sends out loot council specific to an item
local function StartLC(item)
	if IsInRaid() and item then
		--create council
		local council = {}
		local myServer = select(2,UnitFullName("player"))
		for i=1,GetNumGroupMembers() do
			local unit = WeakAuras.raidUnits[i]
			local guid = UnitGUID(unit)
			local name, server = UnitFullName(unit)
			if not server or server == "" then
				server = myServer
			end
			local fullName = name.."-"..server
			fullName = string.lower(fullName)
			if WCTSaved.Options.LootCouncil[fullName] or (LCGuildiesCache[guid] and LCGuildiesCache[guid] < WCTSaved.Options.LootCouncilGuildRank) or UnitIsUnit(unit,"player") then
				tinsert(council,guid)
			end
		end
		local message = strjoin(SEP,"COUNCIL",UnitGUID("player"),item.looterGUID,item.link,unpack(council))
		PL:SendCommMessage("WCLOOTCOUNCIL", message, "RAID")
	end
end

local function AddRow(container, encounter, top, lootCouncil) --encounter object, boolean
	local iconTable = {}
	
	local row = AceGUI:Create("SimpleGroup")
	row:SetLayout("Flow")
	row:SetFullWidth(true)
	row:SetUserData("encounter",encounter)
	row:SetUserData("icons",iconTable)
	if not lootCouncil then
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
	else
		container:AddChild(row)
		RowGroupByEncounter[encounter] = row
	end
	
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
	if not lootCouncil then
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
			else
				selectedEncounterFrame:SetParent(row.frame)
				selectedEncounterFrame:SetAllPoints(row.frame)
				selectedEncounterFrame:Show()
				selectedLCEncounter = encounter
			end
		end)
	end
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
	if not lootCouncil then
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
			else
				selectedEncounterFrame:SetParent(row.frame)
				selectedEncounterFrame:SetAllPoints(row.frame)
				selectedEncounterFrame:Show()
				selectedLCEncounter = encounter
			end
		end)
	end
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
			if item.looterClass and item.awardeeName then
				GameTooltip:AddLine("|c" .. (select(4,GetClassColor(item.looterClass))) .. item.looterName .. "|r >>> |c" .. (select(4,GetClassColor(item.awardeeClass))) .. item.awardeeName .. "|r", 1, 1, 1)
			else
				GameTooltip:AddLine(item.looterName,r,g,b)
			end
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
				StartLC(item)
			end
			if lootCouncil and button == "LeftButton" and not IsShiftKeyDown() and not IsControlKeyDown() then
				selectedLCItem = item
				UpdateLCItem()
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
	
	if encounter == selectedLCEncounter and not lootCouncil then
		selectedEncounterFrame:SetParent(row.frame)
		selectedEncounterFrame:SetAllPoints(row.frame)
		selectedEncounterFrame:Show()
	end
end

local function PopulateTab(container)
	GuildRoster()
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
			scrollFrame:DoLayout()
		end)
		scrollFrame:AddChild(moreRowButton)
		moreRowButtonRef = moreRowButton
	end
end

--LCRowGroup
--LCRowGroupByGUID
local function AdjustLCRows(numRows)
	local numRowsOld = #LCRowGroup
	if numRows > numRowsOld then
		for i = numRowsOld+1, numRows do
			local row = AceGUI:Create("SimpleGroup")
			row:SetLayout("Flow")
			row:SetFullWidth(true)
			LCScrollGroupRef:AddChild(row)
			
			local lootIcon1 = AceGUI:Create("IconNoHighlight")
			lootIcon1:SetRelativeWidth(0.065)
			lootIcon1:SetHeight(32)
			lootIcon1:SetImageSize(32,32)
			lootIcon1:SetCallback("OnRelease",function(widget, callback)
				--OutlineCache, UsedOutlines
				for i,frame in ipairs(UsedOutlines) do
					if frame == widget:GetUserData("border") then
						frame:Hide()
						tremove(UsedOutlines,i)
						tinsert(OutlineCache,frame)
						break;
					end
				end
			end)
			lootIcon1:SetCallback("OnEnter", function(widget)
				local submission = row:GetUserData("submission")
				if submission.link1 then
					GameTooltip:SetOwner(widget.frame, "ANCHOR_LEFT", 0, 0)
					GameTooltip:ClearLines()
					GameTooltip:SetHyperlink(submission.link1)
					GameTooltip:Show()
				end
			end)
			lootIcon1:SetCallback("OnLeave", function(widget)
				GameTooltip:Hide()
			end)
			lootIcon1:SetCallback("OnClick",function(widget,callback,button)
				local submission = row:GetUserData("submission")
				if submission.link1 then
					if button == "LeftButton" and IsShiftKeyDown() then
						local editbox = GetCurrentKeyBoardFocus()
						if editbox then
							editbox:Insert(submission.link1)
						end
					end
					if button == "LeftButton" and IsControlKeyDown() then
						DressUpItemLink(submission.link1)
					end
				end
			end)
			row:SetUserData("lootIcon1",lootIcon1)
			row:AddChild(lootIcon1)
			BordifyIcon(lootIcon1,0,0,0)
			lootIcon1:GetUserData("border"):Hide()
			
			local lootIcon2 = AceGUI:Create("IconNoHighlight")
			lootIcon2:SetRelativeWidth(0.065)
			lootIcon2:SetHeight(32)
			lootIcon2:SetImageSize(32,32)
			lootIcon2:SetCallback("OnRelease",function(widget, callback)
				--OutlineCache, UsedOutlines
				for i,frame in ipairs(UsedOutlines) do
					if frame == widget:GetUserData("border") then
						frame:Hide()
						tremove(UsedOutlines,i)
						tinsert(OutlineCache,frame)
						break;
					end
				end
			end)
			lootIcon2:SetCallback("OnEnter", function(widget)
				local submission = row:GetUserData("submission")
				if submission.link2 then
					GameTooltip:SetOwner(widget.frame, "ANCHOR_LEFT", 0, 0)
					GameTooltip:ClearLines()
					GameTooltip:SetHyperlink(submission.link2)
					GameTooltip:Show()
				end
			end)
			lootIcon2:SetCallback("OnLeave", function(widget)
				GameTooltip:Hide()
			end)
			lootIcon2:SetCallback("OnClick",function(widget,callback,button)
				local submission = row:GetUserData("submission")
				if submission.link2 then
					if button == "LeftButton" and IsShiftKeyDown() then
						local editbox = GetCurrentKeyBoardFocus()
						if editbox then
							editbox:Insert(submission.link2)
						end
					end
					if button == "LeftButton" and IsControlKeyDown() then
						DressUpItemLink(submission.link2)
					end
				end
			end)
			row:SetUserData("lootIcon2",lootIcon2)
			row:AddChild(lootIcon2)
			BordifyIcon(lootIcon2,0,0,0)
			lootIcon2:GetUserData("border"):Hide()
			
			local nameLabel = AceGUI:Create("InteractiveLabel")
			nameLabel:SetText(" ")
			nameLabel:SetRelativeWidth(0.24)
			row:SetUserData("nameLabel",nameLabel)
			row:AddChild(nameLabel)
			
			local rankLabel = AceGUI:Create("InteractiveLabel")
			rankLabel:SetText(" ")
			rankLabel:SetRelativeWidth(0.12)
			row:SetUserData("rankLabel",rankLabel)
			row:AddChild(rankLabel)
			
			local noteIcon = AceGUI:Create("IconNoHighlight")
			noteIcon:SetRelativeWidth(0.05)
			noteIcon:SetHeight(24)
			noteIcon:SetImageSize(24,24)
			--noteIcon:SetImage("Interface\\AddOns\\WildcardTools\\assets\\page") 
			noteIcon:SetCallback("OnEnter", function(widget)
				local submission = row:GetUserData("submission")
				if submission.note and submission.note ~= "" then
					GameTooltip:SetOwner(widget.frame, "ANCHOR_LEFT", 0, 0)
					GameTooltip:ClearLines()
					GameTooltip:AddLine(submission.note)
					GameTooltip:Show()
				end
			end)
			noteIcon:SetCallback("OnLeave", function(widget)
				GameTooltip:Hide()
			end)
			row:SetUserData("noteIcon",noteIcon)
			row:AddChild(noteIcon)
			
			local interestLabel = AceGUI:Create("InteractiveLabel")
			interestLabel:SetText(" ")
			interestLabel:SetRelativeWidth(0.1)
			row:SetUserData("interestLabel",interestLabel)
			row:AddChild(interestLabel)
			
			local voteLabel = AceGUI:Create("InteractiveLabel")
			voteLabel:SetText(" ")
			voteLabel:SetRelativeWidth(0.05)
			voteLabel:SetJustifyH("CENTER")
			row:SetUserData("voteLabel",voteLabel)
			row:AddChild(voteLabel)
			
			local voteButton = AceGUI:Create("Button")
			voteButton:SetText("Vote")
			voteButton:SetRelativeWidth(0.15)
			voteButton:SetCallback("OnClick",function(widget)
				if selectedLCItem and IsInRaid() then
					local submission = row:GetUserData("submission")
					local message = strjoin(SEP,"VOTE",UnitGUID("player"),selectedLCItem.looterGUID,selectedLCItem.link,submission.guid)
					PL:SendCommMessage("WCLOOTCOUNCIL", message, "RAID")
				end
			end)
			row:SetUserData("voteButton",voteButton)
			row:AddChild(voteButton)
			
			local awardButton = AceGUI:Create("Button")
			awardButton:SetText("Award")
			awardButton:SetRelativeWidth(0.15)
			awardButton:SetCallback("OnClick",function(widget)
				if selectedLCItem and IsInRaid() then
					local submission = row:GetUserData("submission")
					local message = strjoin(SEP,"AWARD",UnitGUID("player"),selectedLCItem.looterGUID,selectedLCItem.link,submission.guid)
					PL:SendCommMessage("WCLOOTCOUNCIL", message, "RAID")
				end
			end)
			row:SetUserData("awardButton",awardButton)
			row:AddChild(awardButton)
			
			LCRowGroup[i] = row
			LCScrollGroupRef:DoLayout()
		end
	elseif numRows < numRowsOld then
		for i = numRowsOld, numRows+1, -1 do
			LCRowGroup[i]:Release()
			LCRowGroup[i] = nil
			LCScrollGroupRef.children[i] = nil
			LCScrollGroupRef:DoLayout()
		end
	end
end

--for below
local function submissionCompare(sub1, sub2)
	if selectedLCItem then
		--VOTES > INTEREST > ILVL > NAME
		--VOTES
		local votes1, votes2 = 0, 0
		for _,_ in pairs(sub1.voters) do
			votes1 = votes1 + 1
		end
		for _,_ in pairs(sub2.voters) do
			votes2 = votes2 + 1
		end
		if votes1 > votes2 then
			return true
		elseif votes1 < votes2 then
			return false
		end
		--INTEREST
		local interestValue = {
			["MAINSPEC"] = 1,
			["MINORUP"] = 2,
			["OFFSPEC"] = 3,
			["GREED"] = 4,
		}
		local val1 = interestValue[sub1.interest]
		local val2 = interestValue[sub2.interest]
		if val1 and val2 then
			if val1 < val2 then
				return true
			elseif val1 > val2 then
				return false
			end
		end
		--ILVL
		if sub1.link1 and sub2.link1 then
			local ilvl1, ilvl2
			ilvl1 = min((select(4,GetItemInfo(sub1.link1))),(select(4,GetItemInfo(sub1.link2 or sub1.link1))))
			ilvl2 = min((select(4,GetItemInfo(sub2.link1))),(select(4,GetItemInfo(sub2.link2 or sub2.link1))))
			if ilvl1 < ilvl2 then
				return true
			elseif ilvl1 > ilvl2 then
				return false
			end
		end
		--NAME
		if sub1.name < sub2.name then
			return true
		elseif sub1.name > sub2.name then
			return false
		end
	end
	return true
end

--LCRaiderInputGroupRef
--[[local]] function UpdateLCItem()
	if selectedLCEncounter and not selectedLCItem then
		selectedLCItem = selectedLCEncounter.Loot[1] or nil
	end
	
	local row = RowGroupByEncounter[selectedLCEncounter]
	if row then
		local iconTable = row:GetUserData("icons")
		for _,icon in ipairs(iconTable) do
			local item = icon:GetUserData("item")
			if (item.tradeable + 7200) - time() > 0 then
				if item == selectedLCItem then
					BordifyIcon(icon,0,1,0)
				else
					BordifyIcon(icon,0,1,1)
				end
			elseif item.tradeable > 0 then
				if item == selectedLCItem then
					BordifyIcon(icon,1,0,0)
				else
					BordifyIcon(icon,0,0.5,0.5)
				end
			else
				if item == selectedLCItem then
					BordifyIcon(icon,0.5,0,0)
				else
					BordifyIcon(icon,0,0,0)
				end
			end
		end
	end
	if selectedLCItem then
		local item = selectedLCItem
		if (item.tradeable + 7200) - time() > 0 and IsInRaid() then
			LCRaiderInputGroupRef:GetUserData("mainspecButton"):SetDisabled(false)
			LCRaiderInputGroupRef:GetUserData("minorupButton"):SetDisabled(false)
			LCRaiderInputGroupRef:GetUserData("offspecButton"):SetDisabled(false)
			LCRaiderInputGroupRef:GetUserData("greedButton"):SetDisabled(false)
			LCRaiderInputGroupRef:GetUserData("passButton"):SetDisabled(false)
			LCRaiderInputGroupRef:GetUserData("noteButton"):SetDisabled(false)
		else
			LCRaiderInputGroupRef:GetUserData("mainspecButton"):SetDisabled(true)
			LCRaiderInputGroupRef:GetUserData("minorupButton"):SetDisabled(true)
			LCRaiderInputGroupRef:GetUserData("offspecButton"):SetDisabled(true)
			LCRaiderInputGroupRef:GetUserData("greedButton"):SetDisabled(true)
			LCRaiderInputGroupRef:GetUserData("passButton"):SetDisabled(true)
			LCRaiderInputGroupRef:GetUserData("noteBox"):SetText()
			LCRaiderInputGroupRef:GetUserData("noteButton"):SetDisabled(true)
			
			LCScrollGroupRef:ReleaseChildren()
			LCRowGroupByGUID, LCRowGroup = {}, {}
		end
		
		--add and subtract rows until accurate
		local isOnCouncil = (item.council and item.council[UnitGUID("player")]) and true or false
		local sortedSubmissions = {}
		if item.council then
			for _,s in pairs(item.submissions) do
				if (s.interest and s.interest ~= "PASS") and (isOnCouncil or s.guid == UnitGUID("player")) then
					tinsert(sortedSubmissions,s)
				end
			end
			table.sort(sortedSubmissions,submissionCompare)
		end
		AdjustLCRows(#sortedSubmissions)
		
		--add data to rows and add rows to rowsbyguid group
		LCRowGroupByGUID = {}
		for i,row in ipairs(LCRowGroup) do
			local submission = sortedSubmissions[i]
			if row:GetUserData("submission") ~= submission then
				row:SetUserData("submission",submission)
				--Change all the children in this row to be accurate
				if submission.link1 then
					row:GetUserData("lootIcon1"):SetImage((select(10,GetItemInfo(submission.link1))))
					row:GetUserData("lootIcon1"):GetUserData("border"):Show()
					local ilvl = select(4,GetItemInfo(submission.link1))
					row:GetUserData("lootIcon1"):SetLabel(ilvl)
				else
					row:GetUserData("lootIcon1"):SetImage()
					row:GetUserData("lootIcon1"):GetUserData("border"):Hide()
					row:GetUserData("lootIcon1"):SetLabel()
				end
				
				if submission.link2 then
					row:GetUserData("lootIcon2"):SetImage((select(10,GetItemInfo(submission.link2))))
					row:GetUserData("lootIcon2"):GetUserData("border"):Show()
					local ilvl = select(4,GetItemInfo(submission.link2))
					row:GetUserData("lootIcon2"):SetLabel(ilvl)
				else
					row:GetUserData("lootIcon2"):SetImage()
					row:GetUserData("lootIcon2"):GetUserData("border"):Hide()
					row:GetUserData("lootIcon2"):SetLabel()
				end
				
				row:GetUserData("nameLabel"):SetText(submission.name)
				row:GetUserData("nameLabel"):SetColor(unpack(classColor[submission.class]))
				
				if submission.rank then
					row:GetUserData("rankLabel"):SetText(submission.rank)
				else
					row:GetUserData("rankLabel"):SetText(" ")
				end
				
				if submission.note and submission.note ~= "" then
					row:GetUserData("noteIcon"):SetImage("Interface\\AddOns\\WildcardTools\\assets\\page")
				else
					row:GetUserData("noteIcon"):SetImage()
				end
				
				row:GetUserData("interestLabel"):SetText(interestText[submission.interest])
				
				local voteCount = 0
				for _,vote in pairs(submission.voters) do
					if vote then
						voteCount = voteCount + 1
					end
				end
				if voteCount == 0 then
					row:GetUserData("voteLabel"):SetText(" ")
				else
					row:GetUserData("voteLabel"):SetText(voteCount)
				end
				
				if IsInRaid() and item.council[UnitGUID("player")] then
					row:GetUserData("voteButton"):SetDisabled(false)
				else
					row:GetUserData("voteButton"):SetDisabled(true)
				end
				
				if IsInRaid() and item.council[UnitGUID("player")] and UnitIsGroupLeader("player") then
					row:GetUserData("awardButton"):SetDisabled(false)
				else
					row:GetUserData("awardButton"):SetDisabled(true)
				end
				
				if submission.guid == item.awardeeGUID then
					selectedEncounterFrame:SetParent(row.frame)
					selectedEncounterFrame:SetAllPoints(row.frame)
					selectedEncounterFrame:Show()
				end
			end
			LCRowGroupByGUID[submission.guid] = row
		end
		
		local hasItemLabel = LCRaiderInputGroupRef:GetUserData("hasItemLabel")
		if item.awardeeName and item.awardeeClass then
			hasItemLabel:SetColor()
			hasItemLabel:SetText("|c" .. (select(4,GetClassColor(item.looterClass))) .. item.looterName .. "|r >>> |c" .. (select(4,GetClassColor(item.awardeeClass))) .. item.awardeeName .. "|r")
		else
			hasItemLabel:SetText(item.looterName)
			hasItemLabel:SetColor(unpack(classColor[item.looterClass]))
		end
		
		if IsInRaid() and item.council and item.council[UnitGUID("player")] and UnitIsGroupLeader("player") then
			LCRaiderInputGroupRef:GetUserData("cancelButton"):SetDisabled(false)
		else
			LCRaiderInputGroupRef:GetUserData("cancelButton"):SetDisabled(true)
		end
		
		if not item.awardeeGUID or not LCRowGroupByGUID[item.awardeeGUID] then
			selectedEncounterFrame:Hide()
		end
	else
		LCRaiderInputGroupRef:GetUserData("mainspecButton"):SetDisabled(true)
		LCRaiderInputGroupRef:GetUserData("minorupButton"):SetDisabled(true)
		LCRaiderInputGroupRef:GetUserData("offspecButton"):SetDisabled(true)
		LCRaiderInputGroupRef:GetUserData("greedButton"):SetDisabled(true)
		LCRaiderInputGroupRef:GetUserData("passButton"):SetDisabled(true)
		LCRaiderInputGroupRef:GetUserData("noteBox"):SetText()
		LCRaiderInputGroupRef:GetUserData("noteButton"):SetDisabled(true)
		
		LCRaiderInputGroupRef:GetUserData("hasItemLabel"):SetText(" ")
		
		LCScrollGroupRef:ReleaseChildren()
		LCRowGroupByGUID, LCRowGroup = {}, {}
		
		LCRaiderInputGroupRef:GetUserData("cancelButton"):SetDisabled(true)
		
		selectedEncounterFrame:Hide()
	end
end

local function goInOnLoot(interest,note)
	if selectedLCItem and IsInRaid() then
		--local _,_,looterGUID,link,equippedLink1,equippedLink2,interest,message = unpack(packed)
		local slot = select(9,GetItemInfo(selectedLCItem.link))
		local slotNum1, slotNum2 = unpack(invSlot[slot] or {})
		local slotLink1, slotLink2
		if slotNum1 then
			slotLink1 = GetInventoryItemLink("player",slotNum1)
		end
		if slotNum2 then
			slotLink2 = GetInventoryItemLink("player",slotNum2)
		end
		if note then
			local message = strjoin(SEP,"SUBMIT",UnitGUID("player"),selectedLCItem.looterGUID,selectedLCItem.link,(slotLink1 or "nil"),(slotLink2 or "nil"),interest,note)
			PL:SendCommMessage("WCLOOTCOUNCIL", message, "RAID")
		else
			local message = strjoin(SEP,"SUBMIT",UnitGUID("player"),selectedLCItem.looterGUID,selectedLCItem.link,(slotLink1 or "nil"),(slotLink2 or "nil"),interest)
			PL:SendCommMessage("WCLOOTCOUNCIL", message, "RAID")
		end
	end
end

local function PopulateTabLC(container)
	GuildRoster()
	container.content.width = 524
	selectedLCEncounter = selectedLCEncounter or WCTSaved.Encounters[1]
	local encounter = selectedLCEncounter
	
	container:SetLayout("Flow")
	if encounter then
		AddRow(container,encounter,nil,true)
		--add lc raider input framework
		local inputRow = AceGUI:Create("SimpleGroup")
		inputRow:SetLayout("Flow")
		inputRow:SetFullWidth(true)
		inputRow:SetUserData("encounter",encounter)
		inputRow:SetUserData("icons",iconTable)
		container:AddChild(inputRow)
		
		LCRaiderInputGroupRef = inputRow
		
		local mainspecButton = AceGUI:Create("Button")
		mainspecButton:SetText("Mainspec")
		mainspecButton:SetRelativeWidth(0.2)
		mainspecButton:SetHeight(30)
		mainspecButton:SetCallback("OnClick",function(widget)
			goInOnLoot("MAINSPEC")
		end)
		inputRow:SetUserData("mainspecButton",mainspecButton)
		inputRow:AddChild(mainspecButton)
		
		local minorupButton = AceGUI:Create("Button")
		minorupButton:SetText("Minor Up")
		minorupButton:SetRelativeWidth(0.2)
		minorupButton:SetHeight(30)
		minorupButton:SetCallback("OnClick",function(widget)
			goInOnLoot("MINORUP")
		end)
		inputRow:SetUserData("minorupButton",minorupButton)
		inputRow:AddChild(minorupButton)
		
		local offspecButton = AceGUI:Create("Button")
		offspecButton:SetText("Offspec")
		offspecButton:SetRelativeWidth(0.2)
		offspecButton:SetHeight(30)
		offspecButton:SetCallback("OnClick",function(widget)
			goInOnLoot("OFFSPEC")
		end)
		inputRow:SetUserData("offspecButton",offspecButton)
		inputRow:AddChild(offspecButton)
		
		local greedButton = AceGUI:Create("Button")
		greedButton:SetText("Greed")
		greedButton:SetRelativeWidth(0.2)
		greedButton:SetHeight(30)
		greedButton:SetCallback("OnClick",function(widget)
			goInOnLoot("GREED")
		end)
		inputRow:SetUserData("greedButton",greedButton)
		inputRow:AddChild(greedButton)
		
		local passButton = AceGUI:Create("Button")
		passButton:SetText("Pass")
		passButton:SetRelativeWidth(0.2)
		passButton:SetHeight(30)
		passButton:SetCallback("OnClick",function(widget)
			goInOnLoot("PASS")
		end)
		inputRow:SetUserData("passButton",passButton)
		inputRow:AddChild(passButton)
		
		local noteBox = AceGUI:Create("EditBox")
		noteBox:DisableButton(true)
		noteBox:SetRelativeWidth(0.75)
		inputRow:SetUserData("noteBox",noteBox)
		inputRow:AddChild(noteBox)
		
		local noteButton = AceGUI:Create("Button")
		noteButton:SetText("Send Note")
		noteButton:SetRelativeWidth(0.25)
		noteButton:SetHeight(30)
		noteButton:SetCallback("OnClick",function(widget)
			goInOnLoot("NOTE",noteBox:GetText())
			noteBox:SetText()
		end)
		inputRow:SetUserData("noteButton",noteButton)
		inputRow:AddChild(noteButton)
		
		local scrollContainer = AceGUI:Create("SimpleGroup")
		scrollContainer:SetLayout("Fill")
		scrollContainer:SetFullWidth(true)
		scrollContainer:SetHeight(math.floor((container.content:GetTop() or 400) - (container.parent.content:GetBottom() or 4) - 161 + 0.5)) --235
		PL:ScheduleTimer(function() --fixes height when widgets get reused - sometimes caused issues before
			scrollContainer:SetHeight(math.floor((container.content:GetTop() or 400) - (container.parent.content:GetBottom() or 4) - 161 + 0.5))
			container:DoLayout()
		end, 0)
		container:AddChild(scrollContainer)
		
		local scrollGroup = AceGUI:Create("ScrollFrame")
		scrollGroup:SetLayout("Flow")
		scrollGroup:SetFullWidth(true)
		scrollContainer:AddChild(scrollGroup)
		
		LCScrollGroupRef = scrollGroup
		
		local lootMasterGroup = AceGUI:Create("SimpleGroup")
		lootMasterGroup:SetLayout("Flow")
		lootMasterGroup:SetFullWidth(true)
		container:AddChild(lootMasterGroup)
		
		local lootCouncilLabel = AceGUI:Create("InteractiveLabel")
		lootCouncilLabel:SetText("Loot Council")
		lootCouncilLabel:SetJustifyH("CENTER")
		lootCouncilLabel:SetRelativeWidth(0.2)
		lootCouncilLabel:SetCallback("OnEnter", function(widget)
			if selectedLCItem and selectedLCItem.council and not isempty(selectedLCItem.council) then
				GameTooltip:SetOwner(widget.frame, "ANCHOR_LEFT", 10, 5)
				GameTooltip:ClearLines()
				for guid,player in pairs(selectedLCItem.council) do
					GameTooltip:AddLine(player.name,unpack(classColor[player.class]))
				end
				GameTooltip:Show()
			end
		end)
		lootCouncilLabel:SetCallback("OnLeave", function(widget)
			GameTooltip:Hide()
		end)
		lootMasterGroup:AddChild(lootCouncilLabel)
		
		local hasItemLabel = AceGUI:Create("InteractiveLabel")
		hasItemLabel:SetText("")
		hasItemLabel:SetJustifyH("CENTER")
		hasItemLabel:SetRelativeWidth(0.6)
		hasItemLabel:SetText(" ")
		inputRow:SetUserData("hasItemLabel",hasItemLabel)
		lootMasterGroup:AddChild(hasItemLabel)
		
		local cancelButton = AceGUI:Create("Button")
		cancelButton:SetText("Cancel")
		cancelButton:SetRelativeWidth(0.2)
		cancelButton:SetCallback("OnClick",function(widget)
			local cancelItem = selectedLCItem
			WildcardTools.ConfirmationBox("Cancel the Loot Council for this item?",
			function(item)
				if item then
					local message = strjoin(SEP,"CANCEL",UnitGUID("player"),item.looterGUID,item.link)
					PL:SendCommMessage("WCLOOTCOUNCIL", message, "RAID")
				end
			end,
			{cancelItem})
		end)
		inputRow:SetUserData("cancelButton",cancelButton)
		lootMasterGroup:AddChild(cancelButton)
		
		--update everything for the selected item (none in this case)
		UpdateLCItem()
	end
end

function PL:EncounterEnd(event, encounterID, encounterName, difficultyID, groupSize, success)
	if success == 1 and IsInRaid() and (difficultyID == 14 or difficultyID == 15 or difficultyID == 16) and TrackedEncounters[encounterID] and WCTSaved.Options.TrackedInstances[TrackedEncounters[encounterID].instance] then
		local guild = false
		if UnitIsInMyGuild("raid1") and (InGuildParty()) then
			guild = GetGuildInfo("player")
		end
		local killDate = date("%m/%d/%y %H:%M:%S")
		local killTime = time()
		local roster, loot = {}, {}
		local playerZone = false
		for i = 1, GetNumGroupMembers() do
			local unit = WeakAuras.raidUnits[i]
			if UnitIsUnit("player",unit) then
				playerZone = select(7,GetRaidRosterInfo(i))
			end
		end
		for i = 1, GetNumGroupMembers() do
			local name, _, _, _, _, fileName, zone, online = GetRaidRosterInfo(i)
			local guid = UnitGUID(WeakAuras.raidUnits[i])
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
		selectedLCEncounter = encounter
		if WCTSaved.Options.EncounterLootPopup then
			if not WildcardTools_MainFrame then
				WildcardTools:Populate_MainFrame("Loot Council")
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
	local createNew = true
	for _,oldItem in ipairs(encounter.Loot) do
		if item.looterGUID == oldItem.looterGUID and item.link == oldItem.link then
			createNew = false
			if item.tradeable > 0 and oldItem.tradeable == 0 then
				oldItem.tradeable = item.tradeable
				--updates outline if needed to show tradeable
				local row = RowGroupByEncounter[encounter]
				if row then
					local iconTable = row:GetUserData("icons")
					for _,icon in ipairs(iconTable) do
						local iconItem = icon:GetUserData("item")
						if iconItem.link == item.link and iconItem.looterGUID == item.looterGUID then
							if (item.tradeable + 7200) - time() > 0 then
								if item.council then
									BordifyIcon(lootIcon,0,1,0)
								else
									BordifyIcon(lootIcon,0,1,1)
								end
							else
								BordifyIcon(icon,0,0,0)
							end
							return
						end
					end
				end
			end
			return
		end
	end
	if createNew then
		tinsert(encounter.Loot,item)
		
		if WCTSaved.Options.AutoStartLC and IsInRaid() and UnitIsGroupLeader("player") then
			PL:ScheduleTimer(function()
				StartLC(item)
			end, 3)
		end
		
		local row = RowGroupByEncounter[encounter]
		if row then
			local iconTable = row:GetUserData("icons")
			local ilvl = select(4,GetItemInfo(item.link))
			local lootCouncil = LCRaiderInputGroupRef and true or false
			
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
				if item.looterClass and item.awardeeName then
					GameTooltip:AddLine("|c" .. (select(4,GetClassColor(item.looterClass))) .. item.looterName .. "|r >>> |c" .. (select(4,GetClassColor(item.awardeeClass))) .. item.awardeeName .. "|r", 1, 1, 1)
				else
					GameTooltip:AddLine(item.looterName,r,g,b)
				end
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
					StartLC(item)
				end
				if lootCouncil and button == "LeftButton" and not IsShiftKeyDown() and not IsControlKeyDown() then
					selectedLCItem = item
					UpdateLCItem()
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
			if UnitGUID(WeakAuras.raidUnits[i]) == unitguid then
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
				submissions = {},
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

local function getItemByGUIDandLink(looterGUID, link)
	for _,encounter in ipairs(WCTSaved.Encounters) do
		if (time() - encounter.Time) > 10800 then
			break
		end
		for _,item in ipairs(encounter.Loot) do
			if (item.tradeable + 7200) - time() > 0 and item.link == link and item.looterGUID == looterGUID then
				return item, encounter
			end
		end
	end
	return nil
end

function PL:LCMessageHandler(prefix, message, distribution, sender)
	--print(#message)
	--print(message)
	local packed = {strsplit(SEP,message)}
	local operation, senderGUID = unpack(packed)
	if operation == "COUNCIL" then
		--check for leader
		--update council
		--update votes to be from active or inactive council member
		--update vote counts if showing
		--update icon border
		if IsInRaid() and UnitGUID("raid1") == senderGUID then
			local _,_,looterGUID,link = unpack(packed)
			local item = getItemByGUIDandLink(looterGUID, link)
			if item then
				local councilGUIDs = {select(5,unpack(packed))}
				local guids = {}
				for _,guid in ipairs(councilGUIDs) do
					guids[guid] = true
				end
				item.council = {}
				for i=1,GetNumGroupMembers() do
					local guid = UnitGUID(WeakAuras.raidUnits[i])
					if guids[guid] then
						local name, _, _, _, _, fileName = GetRaidRosterInfo(i)
						item.council[guid] = {
							name = name,
							class = fileName
						}
					end
				end
				for _,submission in pairs(item.submissions) do
					print(submission.name)
					for voterGUID,currentlyOnCouncil in pairs(submission.voters) do
						if item.council[voterGUID] then
							submission.voters[voterGUID] = true
						else
							submission.voters[voterGUID] = false
						end
					end
				end
				if item == selectedLCItem then
					UpdateLCItem()
				end
			end
		end
	elseif operation == "CANCEL" then
		--check for leader
		--delete council
		--UpdateLCItem() if showing
		--update icon border
		if IsInRaid() and UnitGUID("raid1") == senderGUID then
			local _,_,looterGUID,link = unpack(packed)
			local item = getItemByGUIDandLink(looterGUID, link)
			if item then
				item.council = nil
				if item == selectedLCItem then
					UpdateLCItem()
				end
			end
		end
	elseif operation == "VOTE" then
		--only update stuff if lc
		--add vote
		--remove votes elsewhere on item
		--update vote counts if showing
		local _,_,looterGUID,link,voteGUID = unpack(packed)
		local item, encounter = getItemByGUIDandLink(looterGUID, link)
		if item and item.council then
			local isOnCouncil = item.council[senderGUID] and true or false
			for _,submission in pairs(item.submissions) do
				if submission.guid == voteGUID then
					submission.voters[senderGUID] = isOnCouncil
				else
					submission.voters[senderGUID] = nil
				end
			end
			if isOnCouncil then
				for _,row in ipairs(LCRowGroup) do
					local submission = row:GetUserData("submission")
					
					local voteCount = 0
					for _,vote in pairs(submission.voters) do
						if vote then
							voteCount = voteCount + 1
						end
					end
					if voteCount == 0 then
						row:GetUserData("voteLabel"):SetText(" ")
					else
						row:GetUserData("voteLabel"):SetText(voteCount)
					end
				end
				
				UpdateLCItem()
			end
		end
	elseif operation == "AWARD" then
		--check for leader
		--add awardee tag
		--add selectedEncounterFrame
		if IsInRaid() and UnitGUID("raid1") == senderGUID then
			local _,_,looterGUID,link,awardeeGUID = unpack(packed)
			local item, encounter = getItemByGUIDandLink(looterGUID, link)
			if item and item.council and encounter.Roster[awardeeGUID] then
				item.awardeeGUID = awardeeGUID
				item.awardeeName = encounter.Roster[awardeeGUID].name
				item.awardeeClass = encounter.Roster[awardeeGUID].class
				
				if item == selectedLCItem then
					local row = LCRowGroupByGUID[awardeeGUID]
					if row then
						selectedEncounterFrame:SetParent(row.frame)
						selectedEncounterFrame:SetAllPoints(row.frame)
						selectedEncounterFrame:Show()
					else
						selectedEncounterFrame:Hide()
					end
					
					local hasItemLabel = LCRaiderInputGroupRef:GetUserData("hasItemLabel")
					if item.awardeeName and item.awardeeClass then
						hasItemLabel:SetColor()
						hasItemLabel:SetText("|c" .. (select(4,GetClassColor(item.looterClass))) .. item.looterName .. "|r >>> |c" .. (select(4,GetClassColor(item.awardeeClass))) .. item.awardeeName .. "|r")
					else
						hasItemLabel:SetText(item.looterName)
						hasItemLabel:SetColor(unpack(classColor[item.looterClass]))
					end
				end
				
				if senderGUID == UnitGUID("player") and WCTSaved.Options.AnnounceAwards then
					local message = item.looterName .. ", trade " .. item.link .. " to " .. item.awardeeName .. "."
					SendChatMessage(message,"RAID")
				end
			end
		end
	elseif operation == "SUBMIT" then
		--add submission
		--add or update submission row if showing
		local _,_,looterGUID,link,equippedLink1,equippedLink2,interest,message = unpack(packed)
		local item, encounter = getItemByGUIDandLink(looterGUID, link)
		if item and encounter.Roster[senderGUID] then
			item.submissions[senderGUID] = item.submissions[senderGUID] or {}
			local submission = item.submissions[senderGUID]
			submission.name = encounter.Roster[senderGUID].name
			submission.guid = senderGUID
			submission.class = encounter.Roster[senderGUID].class
			if LCGuildiesCache[senderGUID] then
				submission.rank = GuildControlGetRankName(LCGuildiesCache[senderGUID]+1)
			end
			if equippedLink1 == "nil" then
				submission.link1 = nil
			else
				submission.link1 = equippedLink1
			end
			if equippedLink2 == "nil" then
				submission.link2 = nil
			else
				submission.link2 = equippedLink2
			end
			if interest ~= "NOTE" then
				submission.interest = interest
			elseif not submission.interest then
				submission.interest = "PASS"
			end
			submission.note = message or submission.note or ""
			submission.voters = submission.voters or {}
			
			if item == selectedLCItem then
				local row = LCRowGroupByGUID[senderGUID]
				
				if row then
					if submission.link1 then
						row:GetUserData("lootIcon1"):SetImage((select(10,GetItemInfo(submission.link1))))
						row:GetUserData("lootIcon1"):GetUserData("border"):Show()
						local ilvl = select(4,GetItemInfo(submission.link1))
						row:GetUserData("lootIcon1"):SetLabel(ilvl)
					else
						row:GetUserData("lootIcon1"):SetImage()
						row:GetUserData("lootIcon1"):GetUserData("border"):Hide()
						row:GetUserData("lootIcon1"):SetLabel()
					end
					
					if submission.link2 then
						row:GetUserData("lootIcon2"):SetImage((select(10,GetItemInfo(submission.link2))))
						row:GetUserData("lootIcon2"):GetUserData("border"):Show()
						local ilvl = select(4,GetItemInfo(submission.link2))
						row:GetUserData("lootIcon2"):SetLabel(ilvl)
					else
						row:GetUserData("lootIcon2"):SetImage()
						row:GetUserData("lootIcon2"):GetUserData("border"):Hide()
						row:GetUserData("lootIcon2"):SetLabel()
					end
					
					row:GetUserData("nameLabel"):SetText(submission.name)
					row:GetUserData("nameLabel"):SetColor(unpack(classColor[submission.class]))
					
					if submission.rank then
						row:GetUserData("rankLabel"):SetText(submission.rank)
					else
						row:GetUserData("rankLabel"):SetText(" ")
					end
					
					if submission.note and submission.note ~= "" then
						row:GetUserData("noteIcon"):SetImage("Interface\\AddOns\\WildcardTools\\assets\\page")
					else
						row:GetUserData("noteIcon"):SetImage()
					end
					
					row:GetUserData("interestLabel"):SetText(interestText[submission.interest])
				end
				
				UpdateLCItem()
			end
		end
	end
end

function PL:RosterUpdate()
	if LCRaiderInputGroupRef then
		local item = selectedLCItem
		if item and (item.tradeable + 7200) - time() > 0 and IsInRaid() then
			LCRaiderInputGroupRef:GetUserData("mainspecButton"):SetDisabled(false)
			LCRaiderInputGroupRef:GetUserData("minorupButton"):SetDisabled(false)
			LCRaiderInputGroupRef:GetUserData("offspecButton"):SetDisabled(false)
			LCRaiderInputGroupRef:GetUserData("greedButton"):SetDisabled(false)
			LCRaiderInputGroupRef:GetUserData("passButton"):SetDisabled(false)
			LCRaiderInputGroupRef:GetUserData("noteButton"):SetDisabled(false)
			
			for _,row in ipairs(LCRowGroup) do
				if IsInRaid() and item.council[UnitGUID("player")] then
					row:GetUserData("voteButton"):SetDisabled(false)
				else
					row:GetUserData("voteButton"):SetDisabled(true)
				end
				
				if IsInRaid() and item.council[UnitGUID("player")] and UnitIsGroupLeader("player") then
					row:GetUserData("awardButton"):SetDisabled(false)
				else
					row:GetUserData("awardButton"):SetDisabled(true)
				end
			end
			
			if IsInRaid() and item.council and item.council[UnitGUID("player")] and UnitIsGroupLeader("player") then
				LCRaiderInputGroupRef:GetUserData("cancelButton"):SetDisabled(false)
			else
				LCRaiderInputGroupRef:GetUserData("cancelButton"):SetDisabled(true)
			end
		else
			LCRaiderInputGroupRef:GetUserData("mainspecButton"):SetDisabled(true)
			LCRaiderInputGroupRef:GetUserData("minorupButton"):SetDisabled(true)
			LCRaiderInputGroupRef:GetUserData("offspecButton"):SetDisabled(true)
			LCRaiderInputGroupRef:GetUserData("greedButton"):SetDisabled(true)
			LCRaiderInputGroupRef:GetUserData("passButton"):SetDisabled(true)
			LCRaiderInputGroupRef:GetUserData("noteBox"):SetText()
			LCRaiderInputGroupRef:GetUserData("noteButton"):SetDisabled(true)
			
			for _,row in ipairs(LCRowGroup) do
				row:GetUserData("voteButton"):SetDisabled(true)
				row:GetUserData("awardButton"):SetDisabled(true)
			end
			
			LCRaiderInputGroupRef:GetUserData("cancelButton"):SetDisabled(true)
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
	PopupBox:SetDescription("Show loot council tab after encounter.")
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
	FastLootBox:SetDescription("Fast autolooting. |cffee5555This addon breaks with other fast looting addons.|r")
	FastLootBox:SetRelativeWidth(0.33)
	FastLootBox:SetValue(WCTSaved.Options.FastLoot)
	FastLootBox:SetCallback("OnValueChanged",function(widget) WCTSaved.Options.FastLoot = widget:GetValue() end)
	container:AddChild(FastLootBox)
	
	local AnnounceAwardsBox = AceGUI:Create("CheckBox")
	AnnounceAwardsBox:SetLabel("Announce Awards")
	AnnounceAwardsBox:SetDescription("Raid message for items awarded by loot council.")
	AnnounceAwardsBox:SetRelativeWidth(0.33)
	AnnounceAwardsBox:SetValue(WCTSaved.Options.AnnounceAwards)
	AnnounceAwardsBox:SetCallback("OnValueChanged",function(widget) WCTSaved.Options.AnnounceAwards = widget:GetValue() end)
	container:AddChild(AnnounceAwardsBox)
	
	local AutoLCBox = AceGUI:Create("CheckBox")
	AutoLCBox:SetLabel("Auto Loot Council")
	AutoLCBox:SetDescription("Start LC on items automatically when you are raid leader.")
	AutoLCBox:SetRelativeWidth(0.33)
	AutoLCBox:SetValue(WCTSaved.Options.AutoStartLC)
	AutoLCBox:SetCallback("OnValueChanged",function(widget) WCTSaved.Options.AutoStartLC = widget:GetValue() end)
	container:AddChild(AutoLCBox)
	
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
	
	--loot council
	local lootcouncillist
	local LootCouncilDropdown
	
	local LootCouncilGroup = AceGUI:Create("InlineGroup")
	LootCouncilGroup:SetLayout("Flow")
	LootCouncilGroup:SetFullWidth(true)
	LootCouncilGroup:SetTitle("Loot Council")
	container:AddChild(LootCouncilGroup)
	
	local AddLCBox = AceGUI:Create("EditBox")
	AddLCBox:DisableButton(true)
	AddLCBox:SetRelativeWidth(0.45)
	AddLCBox:SetLabel("Add to the Whitelist. (Name-Realm)")
	LootCouncilGroup:AddChild(AddLCBox)
	
	local noteButton = AceGUI:Create("Button")
	noteButton:SetText("Add")
	noteButton:SetRelativeWidth(0.15)
	noteButton:SetCallback("OnClick",function(widget,callback,click)
		local name, realm = strsplit("-",AddLCBox:GetText())
		if name then name = string.gsub(name," ","") end
		if realm then realm = string.gsub(realm," ","") end
		if name ~= "" then
			if not realm or realm == "" then
				realm = select(2,UnitFullName("player"))
			end
			local fullName = name.."-"..realm
			fullName = string.lower(fullName)
			if not WCTSaved.Options.LootCouncil[fullName] then
				WCTSaved.Options.LootCouncil[fullName] = true
				lootcouncillist[#lootcouncillist+1] = fullName
				table.sort(lootcouncillist)
				LootCouncilDropdown:SetList(lootcouncillist)
			end
			AddLCBox:SetText()
		end
	end)
	LootCouncilGroup:AddChild(noteButton)
	
	lootcouncillist = {}
	for name,_ in pairs(WCTSaved.Options.LootCouncil) do
		tinsert(lootcouncillist,name)
	end
	table.sort(lootcouncillist)
	if isempty(lootcouncillist) then
		tinsert(lootcouncillist," ")
	end
	
	LootCouncilDropdown = AceGUI:Create("Dropdown")
	LootCouncilDropdown:SetLabel("Remove from the Whitelist")
	LootCouncilDropdown:SetRelativeWidth(0.4)
	LootCouncilDropdown:SetList(lootcouncillist)
	LootCouncilDropdown:SetText("--Select to Remove--")
	LootCouncilDropdown:SetCallback("OnValueChanged",function(widget,callback,value)
		WCTSaved.Options.LootCouncil[lootcouncillist[value]] = nil
		table.remove(lootcouncillist,value)
		widget:SetList(lootcouncillist)
		widget:SetValue()
		widget:SetText("--Select to Remove--")
	end)
	LootCouncilGroup:AddChild(LootCouncilDropdown)
	
	if IsInGuild() then
		local guildranklist = {}
		for i=1,GuildControlGetNumRanks() do
			guildranklist[i] = i.." | "..GuildControlGetRankName(i)
		end
		
		local GuildRankDropdown = AceGUI:Create("Dropdown")
		GuildRankDropdown:SetLabel("Guild Rank for Loot Council")
		GuildRankDropdown:SetRelativeWidth(0.4)
		GuildRankDropdown:SetList(guildranklist)
		GuildRankDropdown:SetValue(WCTSaved.Options.LootCouncilGuildRank)
		if WCTSaved.Options.LootCouncilGuildRank > GuildControlGetNumRanks() then
			GuildRankDropdown:SetText(WCTSaved.Options.LootCouncilGuildRank.." | ")
		end
		GuildRankDropdown:SetCallback("OnValueChanged",function(widget,callback,value)
			WCTSaved.Options.LootCouncilGuildRank = value
			PL:UpdateGuildyCache(nil,true)
			GuildRoster()
		end)
		LootCouncilGroup:AddChild(GuildRankDropdown)
	end
	
	--WCTSaved.Options.LootCouncilGuildRank = WCTSaved.Options.LootCouncilGuildRank or 0
	--WCTSaved.Options.LootCouncil = WCTSaved.Options.LootCouncil or {}
	
	--GuildControlGetRankName
end

local function TabCloseFunction()
	local Max, Encounters = WCTSaved.Options.MaxEncounters, WCTSaved.Encounters
	RowGroup, RowGroupByEncounter, LCRowGroup, LCRowGroupByGUID = {}, {}, {}, {}
	scrollFrameRef, moreRowButtonRef, LCRaiderInputGroupRef, LCScrollGroupRef = nil, nil, nil, nil
	for i,frame in ipairs(UsedOutlines) do
		frame:Hide()
		UsedOutlines[i] = nil
		tinsert(OutlineCache,frame)
	end
	--delete encounters marked for deletion
	local del
	del = function()
		for i,encounter in ipairs(Encounters) do
			if encounter.toDelete then
				if encounter == selectedLCEncounter then
					selectedLCEncounter = nil
				end
				tremove(Encounters,i)
				del()
				break
			end
		end
	end
	del()
	--delete encounters past max
	if Max > 0 then
		for i = (Max+1), #Encounters do
			Encounters[i] = nil
		end
	end
	--hide highlight frame
	selectedEncounterFrame:Hide()
	selectedLCItem = nil
end

function PL:GetTabs()
	WildcardTools.TabFunctions["Personal Loot"] = PopulateTab
	WildcardTools.TabFunctions["Loot Council"] = PopulateTabLC
	WildcardTools.TabCloseFunctions[ModuleName] = TabCloseFunction
    return {text="Loot Tracker", value="Personal Loot"}, {text="Loot Council", value="Loot Council"}
end

function PL:OnInitialize()
    -- Called when the addon is loaded
	WCTSaved.Options.MaxEncounters = WCTSaved.Options.MaxEncounters or 0
	WCTSaved.Options.DifficultyColor = WCTSaved.Options.DifficultyColor or false
	WCTSaved.Options.DifficultyShow = WCTSaved.Options.DifficultyShow or false
	WCTSaved.Options.EncounterLootPopup = WCTSaved.Options.EncounterLootPopup or false
	WCTSaved.Options.FastLoot = WCTSaved.Options.FastLoot or false
	WCTSaved.Options.AnnounceAwards = WCTSaved.Options.AnnounceAwards or true
	WCTSaved.Options.AutoStartLC = WCTSaved.Options.AutoStartLC or false
	WCTSaved.Options.TrackedInstances = WCTSaved.Options.TrackedInstances or {}
	WCTSaved.Options.LootCouncilGuildRank = WCTSaved.Options.LootCouncilGuildRank or 1
	WCTSaved.Options.LootCouncil = WCTSaved.Options.LootCouncil or {}
	WCTSaved.Encounters = WCTSaved.Encounters or {}
	
	for _,instance in ipairs(lootInstances) do
		if WCTSaved.Options.TrackedInstances[instance] == nil then
			WCTSaved.Options.TrackedInstances[instance] = true
		end
	end
end

function PL:OnEnable()
    -- Called when the addon is enabled
	RegisterAddonMessagePrefix("WCLOOT")
	PL:RegisterEvent("CHAT_MSG_ADDON", "MessageHandler")
	PL:RegisterEvent("ENCOUNTER_END", "EncounterEnd")
	PL:RegisterEvent("GROUP_ROSTER_UPDATE", "RosterUpdate")
	PL:RegisterEvent("RAID_ROSTER_UPDATE", "RosterUpdate")
	
	--for loot sender below
	PL:RegisterEvent("LOOT_OPENED", "SenderLootOpened")
	PL:RegisterEvent("LOOT_CLOSED", "SenderLootClosed")
	PL:RegisterEvent("LOOT_SLOT_CLEARED", "SenderLootSlotCleared")
	PL:RegisterEvent("CHAT_MSG_LOOT", "SenderChatMsgLoot")
	PL:RegisterEvent("BAG_UPDATE_DELAYED", "SenderBagUpdateDelayed")
	PL:RegisterEvent("GUILD_ROSTER_UPDATE", "UpdateGuildyCache")
	
	--comms
	PL:RegisterComm("WCLOOTCOUNCIL", "LCMessageHandler")
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
	[162461] = true,
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
