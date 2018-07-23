if IsAddOnLoaded("WeakAuras") then

local ModuleName = "WeakAuras"
local WildcardTools, AceGUI = unpack(select(2, ...)); --Import: WildcardTools,
local WA = WildcardTools:NewModule(ModuleName, 'AceEvent-3.0', "AceTimer-3.0")

--holds info about tracked weakauras
--holds info other users gave us about weakauras we do not have
--holds info about other people's weakauras
--if a new version is sent with an updated url, that is held here
local Data, NewWA, WACache, WAURLOverride = {}, {}, {}, {}

local DetailFrames = {}
local Categories = {}
local AurasForRefresh = {}
local WidgetsReference = {}
local TabOneScrollFrameRef = false

local auras = WeakAurasSaved.displays
local SEP = "^"

--LUA API
local tinsert = table.insert
local SendAddonMessage, RegisterAddonMessagePrefix = C_ChatInfo.SendAddonMessage, C_ChatInfo.RegisterAddonMessagePrefix

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

local function TrimWago(url)
	if string.find(url,"https://wago.io/") then
		if select(5,strsplit("/",url)) then
			local t1, t2, t3, t4 = strsplit("/",url)
			return strjoin("/",t1,t2,t3,t4)
		else
			return url
		end
	end
	return url
end

function WA:ClearLatestVer()
	WCTSaved.LatestVerSeen = {}
	for _,aura in pairs(Data) do
		WCTSaved.LatestVerSeen[aura.uid] = aura.version
	end
	WAURLOverride = {}
end

--spaces out to refresh all weakauras
local function RefreshAll(cat)
	local x = 0
	for uid,aura in pairs(Data) do
		if (not AurasForRefresh[uid]) and (not cat or aura.category == cat) then
			AurasForRefresh[uid] = true
			WA:ScheduleTimer(function()
				if AurasForRefresh[uid] then
					AurasForRefresh[uid] = nil
					local sendmessage = strjoin(SEP, UnitGUID("player"), "Y", aura.uid, aura.version, aura.wago)
					SendAddonMessage("WCAURA", sendmessage, "RAID")
				end
			end, x)
			x=x+0.1
		end
	end
end

local function NeedsRefresh(uid)
	if IsInRaid() then
		for i=1,GetNumGroupMembers() do
			local unit = WeakAuras.raidUnits[i]
			local guid = UnitGUID(unit)
			--if online and not player
			if UnitIsConnected(unit) and not UnitIsUnit(unit,"player") then
				if not WACache[uid] or WACache[uid][guid] == nil then
					return true
				end
			end
		end
	elseif IsInGroup() then
		for i=1,GetNumGroupMembers()-1 do
			local unit = WeakAuras.partyUnits[i]
			local guid = UnitGUID(unit)
			--if online and not player
			if UnitIsConnected(unit) and (not WACache[uid] or WACache[uid][guid] == nil) then
				return true
			end
		end
	end
	return false
end

--gives info about how many group members have an aura
function WA:GroupWithWA(uid)
	local uptodate = 0
	local online = 0
	
	if IsInRaid() then
		for i=1,GetNumGroupMembers() do
			local unit = WeakAuras.raidUnits[i]
			local guid = UnitGUID(unit)
			if (select(8,GetRaidRosterInfo(i))) then
				online = online + 1
				if WACache[uid] and WACache[uid][guid] and WACache[uid][guid] >= Data[uid].version then
					uptodate = uptodate + 1
				end
			end
		end
		if Data[uid] then uptodate = uptodate + 1 end
		return uptodate, online
	elseif IsInGroup() then
		for i=1,GetNumGroupMembers()-1 do
			local unit = WeakAuras.partyUnits[i]
			local guid = UnitGUID(unit)
			if UnitIsConnected(unit) then
				online = online + 1
				if WACache[uid] and WACache[uid][guid] and WACache[uid][guid] >= Data[uid].version then
					uptodate = uptodate + 1
				end
			end
		end
		online = online + 1
		if Data[uid] then uptodate = uptodate + 1 end
		return uptodate, online
	end
	return nil, nil
end

--Data
--LatestVerSeen
--Categories
--auras
--updates cache on weakaura data for player
function WA:UpdateWAData()
	local LatestVerSeen = WCTSaved.LatestVerSeen
	--[[
		Data Format
		{
			uid
			name
			category
			version
			wago
		}
	]]
	--clear old data <<<<<This used to only clear old data, now it clears all data so all data has to be updated each time
	--[[
	for uid, d in pairs(Data) do
		if not auras[d.name] then
			d = nil
		end
	end
	--]]
	Data = {}
	--add new data
	for n, aura in pairs(auras) do
		--check only tracked, ungrouped auras
		if (not aura.parent) and aura.TelUID and aura.TelCat and aura.TelVer then
			--cleanup weakauras save info
			WACache[aura.TelUID] = WACache[aura.TelUID] or {}
			aura.version = nil
			if aura.url then
				aura.TelURL = TrimWago(aura.url)
				aura.url = nil
			end
			if Data[aura.TelUID] then
				if aura.TelVer > Data[aura.TelUID].version then
					--update entry
					Data[aura.TelUID] = {
						["uid"] = aura.TelUID,
						["name"] = aura.id,
						["category"] = aura.TelCat,
						["version"] = aura.TelVer,
						["wago"] = aura.TelURL or " ",
					}
					--update latest version seen if necessary
					if (not LatestVerSeen[aura.TelUID]) or aura.TelVer > LatestVerSeen[aura.TelUID] then
						LatestVerSeen[aura.TelUID] = aura.TelVer
					end
				end
			else
				--add entry
				Data[aura.TelUID] = {
					["uid"] = aura.TelUID,
					["name"] = aura.id,
					["category"] = aura.TelCat,
					["version"] = aura.TelVer,
					["wago"] = aura.TelURL or " ",
				}
				--update latest version seen if necessary
				if (not LatestVerSeen[aura.TelUID]) or aura.TelVer > LatestVerSeen[aura.TelUID] then
					LatestVerSeen[aura.TelUID] = aura.TelVer
				end
			end
			
			--remove if present in NewWA
			if NewWA[aura.TelUID] then
				NewWA[aura.TelUID] = nil
			end
		end
	end
	--add and order categories
	Categories = {}
	local added = {}
	for _, aura in pairs(Data) do
		if not added[aura.category] then
			tinsert(Categories,aura.category)
			added[aura.category] = true
		end
	end
	table.sort(Categories)
end

-- function that draws the widgets for the first tab
local function PopulateTab1(container)
	local LatestVerSeen = WCTSaved.LatestVerSeen
	local Widgets = WidgetsReference
	
	WA:UpdateWAData()
	
	container:SetLayout("Fill")
	
	local scrollFrame = AceGUI:Create("ScrollFrame")
	scrollFrame:SetLayout("List")
	
	container:AddChildren(scrollFrame)
	TabOneScrollFrameRef = scrollFrame
	
	local topRowGroup = AceGUI:Create("SimpleGroup")
	topRowGroup:SetLayout("Flow")
	topRowGroup:SetHeight(200)
	topRowGroup:SetFullWidth(true)
	scrollFrame:AddChild(topRowGroup)
	
	--generate category headers
	for _, category in ipairs(Categories) do
		local catHeading = AceGUI:Create("Heading")
		catHeading:SetFullWidth(true)
		catHeading:SetText(category)
		scrollFrame:AddChild(catHeading)
		
		--find auras for this header
		local aurasInCategory = {}
		
		for _, aura in pairs(Data) do
			if aura.category == category then
				tinsert(aurasInCategory,aura)
			end
		end
		table.sort(aurasInCategory, function(a,b) return a.name < b.name end)
		--generate rows for the auras under this header
		for _, aura in ipairs(aurasInCategory) do
			local rowGroup = AceGUI:Create("SimpleGroup")
			rowGroup:SetLayout("Flow")
			rowGroup:SetHeight(200)
			rowGroup:SetFullWidth(true)
			scrollFrame:AddChild(rowGroup)
			
			local refreshButton = AceGUI:Create("IconNoHighlight")
			refreshButton:SetUserData("item",item)
			refreshButton:SetWidth(40)
			refreshButton:SetHeight(40)
			refreshButton:SetImageSize(30,30)
			refreshButton:SetImage("Interface\\AddOns\\WildcardTools\\assets\\refresh")
			if NeedsRefresh(aura.uid) then
				refreshButton.image:SetVertexColor(1,1,1)
			else
				refreshButton.image:SetVertexColor(0.5,0.5,0.5)
			end
			refreshButton:SetCallback("OnClick",function(widget, callback, button)
				if button == "LeftButton" then
					local sendmessage = strjoin(SEP, UnitGUID("player"), "Y", aura.uid, aura.version, aura.wago)
					SendAddonMessage("WCAURA", sendmessage, "RAID")
				elseif button == "RightButton" then
					RefreshAll(aura.category)
				end
			end)
			refreshButton:SetCallback("OnEnter", function(widget)
				GameTooltip:SetOwner(widget.frame, "ANCHOR_LEFT", 0, -33)
				GameTooltip:SetText(aura.uid, nil, nil, nil, nil, true)
				GameTooltip:Show()
			end)
			refreshButton:SetCallback("OnLeave", function(widget)
				GameTooltip:Hide()
			end)
			rowGroup:AddChild(refreshButton)
			
			local nameLabel = AceGUI:Create("InteractiveLabel")
			nameLabel:SetText("   "..aura.name)
			nameLabel:SetWidth(202) --0.4
			if LatestVerSeen[aura.uid] > aura.version then
				nameLabel:SetColor(0,1,1)
			end
			nameLabel:SetCallback("OnClick", function(widget, callback, click)
				local editbox = GetCurrentKeyBoardFocus();
				if(editbox) then
					local name, realm = UnitFullName("player")
					local fullName = name.."-"..realm
					editbox:Insert("[WeakAuras: "..fullName.." - "..aura.name.."]");
				end
			end)
			rowGroup:AddChild(nameLabel)
			
			local currentVerLabel = AceGUI:Create("InteractiveLabel")
			currentVerLabel:SetText("v"..aura.version)
			currentVerLabel:SetWidth(50) --50
			currentVerLabel:SetCallback("OnEnter", function(widget)
				GameTooltip:SetOwner(widget.frame, "ANCHOR_LEFT", -10, 10)
				GameTooltip:ClearLines()
				if LatestVerSeen[aura.uid] > aura.version then
					GameTooltip:AddLine("Out of date:",1,0.6,0.6)
					GameTooltip:AddLine("Version "..LatestVerSeen[aura.uid].." available.",1,0.6,0.6)
				else
					GameTooltip:AddLine("Up to date!",1,1,1)
				end
				GameTooltip:Show()
			end)
			currentVerLabel:SetCallback("OnLeave", function(widget)
				GameTooltip:Hide()
			end)
			rowGroup:AddChild(currentVerLabel)
			
			local groupLabel = AceGUI:Create("InteractiveLabel")
			if WA:GroupWithWA(aura.uid) then
				groupLabel:SetText(strjoin("/",WA:GroupWithWA(aura.uid)))
			else
				groupLabel:SetText("-")
			end
			groupLabel:SetWidth(50) --50
			groupLabel:SetCallback("OnEnter", function(widget)
				if IsInGroup() then
					GameTooltip:SetOwner(widget.frame, "ANCHOR_LEFT", -10, 10)
					GameTooltip:ClearLines()---------------------------------------------------------------------------------------------------------
					if IsInRaid() then
						for i=1,GetNumGroupMembers() do
							local unit = WeakAuras.raidUnits[i]
							local guid = UnitGUID(unit)
							local _,class = UnitClass(unit)
							if UnitIsConnected(unit) and not UnitIsUnit("player",unit) then
								local r,g,b = unpack(classColor[class])
								if WACache[aura.uid] and WACache[aura.uid][guid] then
									if WACache[aura.uid][guid] < Data[aura.uid].version then
										GameTooltip:AddDoubleLine(UnitName(unit),"v"..WACache[aura.uid][guid],r,g,b,1,0.6,0)
									elseif WACache[aura.uid][guid] > Data[aura.uid].version then
										GameTooltip:AddDoubleLine(UnitName(unit),"v"..WACache[aura.uid][guid],r,g,b,0,1,1)
									else
										GameTooltip:AddDoubleLine(UnitName(unit),"v"..WACache[aura.uid][guid],r,g,b,1,1,1)
									end
								else
									GameTooltip:AddDoubleLine(UnitName(unit),"X",r,g,b,1,0.6,0.6)
								end
							end
						end
					else
						for i=1,GetNumGroupMembers()-1 do
							local unit = WeakAuras.partyUnits[i]
							local guid = UnitGUID(unit)
							local _,class = UnitClass(unit)
							if UnitIsConnected(unit) then
								local r,g,b = unpack(classColor[class])
								if WACache[aura.uid] and WACache[aura.uid][guid] then
									if WACache[aura.uid][guid] < Data[aura.uid].version then
										GameTooltip:AddDoubleLine(UnitName(unit),"v"..WACache[aura.uid][guid],r,g,b,1,0.6,0)
									elseif WACache[aura.uid][guid] > Data[aura.uid].version then
										GameTooltip:AddDoubleLine(UnitName(unit),"v"..WACache[aura.uid][guid],r,g,b,0,1,1)
									else
										GameTooltip:AddDoubleLine(UnitName(unit),"v"..WACache[aura.uid][guid],r,g,b,1,1,1)
									end
								else
									GameTooltip:AddDoubleLine(UnitName(unit),"X",r,g,b,1,0.6,0.6)
								end
							end
						end
					end
					GameTooltip:Show()
				end
			end)
			groupLabel:SetCallback("OnLeave", function(widget)
				GameTooltip:Hide()
			end)
			rowGroup:AddChild(groupLabel)
			
			local wagoBox = AceGUI:Create("EditBox")
			if WAURLOverride[aura.uid] then
				wagoBox:SetText(WAURLOverride[aura.uid])
				wagoBox:SetUserData("url",WAURLOverride[aura.uid])
			else
				wagoBox:SetText(aura.wago)
				wagoBox:SetUserData("url",aura.wago)
			end
			wagoBox:DisableButton(true)
			wagoBox:SetWidth(150)
			wagoBox:SetCallback("OnTextChanged",function(text) wagoBox:SetText(wagoBox:GetUserData("url")) end)
			rowGroup:AddChild(wagoBox)
			
			--give reference to these widgets elsewhere in addon to update them
			Widgets[aura.uid] = {
				["refreshButton"] = refreshButton,
				["nameLabel"] = nameLabel,
				["currentVerLabel"] = currentVerLabel,
				["groupLabel"] = groupLabel,
				["wagoBox"] = wagoBox,
			}
		end
	end
	
	--generate new weakaura header
	if not (next(NewWA) == nil) then
		local newHeading = AceGUI:Create("Heading")
		newHeading:SetFullWidth(true)
		newHeading:SetText("New WeakAuras")
		scrollFrame:AddChild(newHeading)
	end
	--generate new weakaura rows
	for _, newWA in pairs(NewWA) do
		local rowGroup = AceGUI:Create("SimpleGroup")
		rowGroup:SetLayout("Flow")
		rowGroup:SetHeight(200)
		rowGroup:SetFullWidth(true)
		scrollFrame:AddChild(rowGroup)
		
		local refreshButton = AceGUI:Create("IconNoHighlight")
		refreshButton:SetUserData("item",item)
		refreshButton:SetWidth(40)
		refreshButton:SetHeight(40)
		refreshButton:SetImageSize(30,30)
		refreshButton:SetImage("Interface\\AddOns\\WildcardTools\\assets\\refresh")
		refreshButton.image:SetVertexColor(0.5,0.5,0.5)
		rowGroup:AddChild(refreshButton)
		
		local nameLabel = AceGUI:Create("InteractiveLabel")
		nameLabel:SetText("   "..newWA.uid)
		nameLabel:SetWidth(202) --0.4
		rowGroup:AddChild(nameLabel)
		
		local currentVerLabel = AceGUI:Create("InteractiveLabel")
		currentVerLabel:SetText(" ")
		currentVerLabel:SetWidth(50) --50
		rowGroup:AddChild(currentVerLabel)
		
		local newestVerLabel = AceGUI:Create("InteractiveLabel")
		newestVerLabel:SetText("v"..(LatestVerSeen[newWA.uid] or "0"))
		newestVerLabel:SetWidth(50) --50
		rowGroup:AddChild(newestVerLabel)
		
		local wagoBox = AceGUI:Create("EditBox")
		if WAURLOverride[newWA.uid] then
			wagoBox:SetText(WAURLOverride[newWA.uid])
			wagoBox:SetUserData("url",WAURLOverride[newWA.uid])
		else
			wagoBox:SetText(newWA.wago)
			wagoBox:SetUserData("url",newWA.wago)
		end
		wagoBox:DisableButton(true)
		wagoBox:SetWidth(150)
		wagoBox:SetCallback("OnTextChanged",function(text) wagoBox:SetText(wagoBox:GetUserData("url")) end)
		rowGroup:AddChild(wagoBox)
		
		--give reference to these widgets elsewhere in addon to update them
		Widgets[newWA.uid] = {
			["refreshButton"] = refreshButton,
			["nameLabel"] = nameLabel,
			["newestVerLabel"] = newestVerLabel,
			["wagoBox"] = wagoBox,
			["new"] = true,
		}
	end
end

--updates with joining/leaving raid
function WA:RosterUpdate()
	if not isempty(WidgetsReference) then
		local Widgets = WidgetsReference
		for uid, group in pairs(Widgets) do
			if NeedsRefresh(uid) then
				group.refreshButton.image:SetVertexColor(1,1,1)
			else
				group.refreshButton.image:SetVertexColor(0.5,0.5,0.5)
			end
		end
	end
	if not isempty(WidgetsReference) then
		for uid,frame in pairs(WidgetsReference) do
			if frame.groupLabel then
				if IsInGroup() then
					frame.groupLabel:SetText(strjoin("/",WA:GroupWithWA(uid)))
				else
					frame.groupLabel:SetText("-")
				end
			end
		end
	end
end

--SEP
--WACache
--NewWA
--LatestVerSeen
--Data
--WAURLOverride
--WidgetsReference
--Handles messages from other clients to request and complete syncs
function WA:MessageHandler(event, prefix, message, channel, fullName, name)
	if prefix == "WCAURA" then
		local LatestVerSeen = WCTSaved.LatestVerSeen
		local unitguid, request, uid, version, wago = strsplit(SEP,message)
		request = request == "Y"
		version = tonumber(version)
		wago = TrimWago(wago)
		
		--update latest version seen
		if (not LatestVerSeen[uid]) or version > LatestVerSeen[uid] then
			if LatestVerSeen[uid] then
				if (not Data[uid]) or Data[uid].wago ~= wago then
					WAURLOverride[uid] = wago
					if WidgetsReference and WidgetsReference[uid] then
						WidgetsReference[uid].wagoBox:SetText(wago)
						WidgetsReference[uid].wagoBox:SetUserData("url",wago)
					end
				end
			end
			
			LatestVerSeen[uid] = version
			if WidgetsReference and WidgetsReference[uid] then
				if not WidgetsReference[uid].new then
					WidgetsReference[uid].nameLabel:SetColor(0,1,1)
				end
			end
		end
		
		--cache the version data for the sending player
		if unitguid ~= UnitGUID("player") then
			if not (WACache[uid] and WACache[uid][unitguid] and WACache[uid][unitguid] == version) then
				WACache[uid] = WACache[uid] or {}
				WACache[uid][unitguid] = version
				WA:RosterUpdate()
			end
		end
		
		--update to show all these players have had a chance to send cache info
		if request then
			if IsInRaid() then
				for i=1,GetNumGroupMembers() do
					local unit = WeakAuras.raidUnits[i]
					local guid = UnitGUID(unit)
					--if online and not player
					if (select(8,GetRaidRosterInfo(i))) and guid ~= UnitGUID("player") then
						WACache[uid] = WACache[uid] or {}
						WACache[uid][guid] = WACache[uid][guid] or false
					end
				end
			elseif IsInGroup() then
				for i=1,GetNumGroupMembers()-1 do
					local unit = WeakAuras.partyUnits[i]
					local guid = UnitGUID(unit)
					--if online and not player
					if not WACache[uid] or not WACache[uid][guid] then
						WACache[uid] = WACache[uid] or {}
						WACache[uid][guid] = WACache[uid][guid] or false
					end
				end
			end
		end
		
		--update button highlights
		if WidgetsReference then
			local Widgets = WidgetsReference
			if Widgets[uid] then
				if NeedsRefresh(uid) then
					Widgets[uid].refreshButton.image:SetVertexColor(1,1,1)
				else
					Widgets[uid].refreshButton.image:SetVertexColor(0.5,0.5,0.5)
				end
			end
		end
		
		--save data for new weakauras
		if (not Data[uid]) and (not NewWA[uid]) then
		
			--put in frame if open
			if TabOneScrollFrameRef then
				--generate new weakaura header
				if next(NewWA) == nil then
					local newHeading = AceGUI:Create("Heading")
					newHeading:SetFullWidth(true)
					newHeading:SetText("New WeakAuras")
					TabOneScrollFrameRef:AddChild(newHeading)
				end
				--generate new weakaura rows
				local rowGroup = AceGUI:Create("SimpleGroup")
				rowGroup:SetLayout("Flow")
				rowGroup:SetHeight(200)
				rowGroup:SetFullWidth(true)
				TabOneScrollFrameRef:AddChild(rowGroup)
				
				local refreshButton = AceGUI:Create("IconNoHighlight")
				refreshButton:SetUserData("item",item)
				refreshButton:SetWidth(40)
				refreshButton:SetHeight(40)
				refreshButton:SetImageSize(30,30)
				refreshButton:SetImage("Interface\\AddOns\\WildcardTools\\assets\\refresh")
				refreshButton.image:SetVertexColor(0.5,0.5,0.5)
				rowGroup:AddChild(refreshButton)
				
				local nameLabel = AceGUI:Create("InteractiveLabel")
				nameLabel:SetText("   "..uid)
				nameLabel:SetWidth(202) --0.4
				rowGroup:AddChild(nameLabel)
				
				local currentVerLabel = AceGUI:Create("InteractiveLabel")
				currentVerLabel:SetText(" ")
				currentVerLabel:SetWidth(50) --50
				rowGroup:AddChild(currentVerLabel)
				
				local newestVerLabel = AceGUI:Create("InteractiveLabel")
				newestVerLabel:SetText("v"..(LatestVerSeen[uid] or "0"))
				newestVerLabel:SetWidth(50) --50
				rowGroup:AddChild(newestVerLabel)
				
				local wagoBox = AceGUI:Create("EditBox")
				if WAURLOverride[uid] then
					wagoBox:SetText(WAURLOverride[uid])
					wagoBox:SetUserData("url",WAURLOverride[uid])
				else
					wagoBox:SetText(wago)
					wagoBox:SetUserData("url",wago)
				end
				wagoBox:DisableButton(true)
				wagoBox:SetWidth(150)
				wagoBox:SetCallback("OnTextChanged",function(text) wagoBox:SetText(wagoBox:GetUserData("url")) end)
				rowGroup:AddChild(wagoBox)
				
				--give reference to these widgets elsewhere in addon to update them
				WidgetsReference[uid] = {
					["refreshButton"] = refreshButton,
					["nameLabel"] = nameLabel,
					["newestVerLabel"] = newestVerLabel,
					["wagoBox"] = wagoBox,
					["new"] = true,
				}
			end
			
			--save data for new weakauras
			NewWA[uid] = {
				["uid"] = uid,
				["wago"] = wago,
			}
		end
		
		--cancel any pending data sendings
		if request and Data[uid] then
			AurasForRefresh[uid] = nil
		end
		
		--send back requested data
		if request and Data[uid] and unitguid ~= UnitGUID("player") then
			local sendmessage = strjoin(SEP, UnitGUID("player"), "N", uid, Data[uid].version, Data[uid].wago)
			SendAddonMessage("WCAURA", sendmessage, channel)
		end
	end
end

-------------------- these 2 functions are the jankiest shit ever, probably a better solution
--update wa data when wa options closed
local function WAOptionScript()
	if WeakAuras.OptionsFrame() then
		local script = WeakAuras.OptionsFrame():GetScript("OnHide")
		WeakAuras.OptionsFrame():SetScript("OnHide",function()
			script(self)
			WA:UpdateWAData()
		end)
	end
end
local function AddonLoaded(_,addon)
	if addon == "WeakAurasOptions" then
		WA:ScheduleTimer(WAOptionScript,2)
	end
end
--------------------

function WA:Options(container)
	local button = AceGUI:Create("Button")
	button:SetText("Reset Out of Date")
	button:SetRelativeWidth(0.33)
	button:SetCallback("OnClick",function(widget)
		WA:ClearLatestVer()
		print("Latest WA Versions Reset")
	end)
	container:AddChild(button)
	
	--metadata settings to add auras to track
	local AuraMetaGroup = AceGUI:Create("InlineGroup")
	AuraMetaGroup:SetLayout("Flow")
	AuraMetaGroup:SetFullWidth(true)
	AuraMetaGroup:SetTitle("WeakAura Metadata Settings")
	container:AddChild(AuraMetaGroup)
	
	local showUntracked = false
	local searchText = ""
	local attemptedSave = false
	local aura
	
	--widgets by row
	local AuraMetaSelect, AuraMetaSearchBox, AuraMetaShowAllCheck
	local AuraMetaGenerateUIDButton, AuraMetaOwnerCheck, AuraMetaProtectMetaCheck
	local AuraMetaUIDIcon, AuraMetaUIDBox, AuraMetaUIDMessage
	local AuraMetaVersionIcon, AuraMetaVersionBox, AuraMetaVersionMessage
	local AuraMetaLinkIcon, AuraMetaLinkBox, AuraMetaLinkMessage
	local AuraMetaCategoryIcon, AuraMetaCategoryBox, AuraMetaCategoryMessage
	local AuraMetaClearMetaButton, AuraMetaGeneralMessage, AuraMetaLoadButton, AuraMetaSaveButton
	
	--flags (soft flags will not prevent saving, just notify user)
	local flags = {
		UIDContainsCircumflex = false,
		UIDEmpty = false,
		UIDNew = false, --soft flag
		UIDDuplicate = false,
		VersionLess = false, --soft flag
		VersionNAN = false,
		VersionNew = false, --soft flag
		VersionEmpty = false,
		LinkEmpty = false,
		LinkContainsCircumflex = false,
		LinkNew = false, --soft flag
		CategoryEmpty = false,
		CategoryNew = false, --soft flag
		GeneralDifferentOwner = false, --soft flag
		GeneralSecure = false,
	}
	
	-- variation on code from https://gist.github.com/haggen/2fd643ea9a261fea2094
	local charset = {}  do -- [0-9a-zA-Z]
		for c = 48, 57  do table.insert(charset, string.char(c)) end
		for c = 65, 90  do table.insert(charset, string.char(c)) end
		for c = 97, 122 do table.insert(charset, string.char(c)) end
	end

	local function randomString(length)
		if not length or length <= 0 then return '' end
		return randomString(length - 1) .. charset[random(1, #charset)]
	end
	
	local function randomUID()
		local name = UnitName("player")
		name = string.sub(name,1,min(4,#name))
		return name .. randomString(12-#name)
	end
		
	local function LoadAura()
		attemptedSave = false
		aura = auras[AuraMetaSelect:GetValue()]
		if aura and aura.TelUID then --if aura is selected
			if aura.TelOwn == select(2,BNGetInfo()) then
				AuraMetaOwnerCheck:SetValue(true)
				AuraMetaOwnerCheck:Fire("OnValueChanged", true)
			else
				AuraMetaOwnerCheck:SetValue(false)
				AuraMetaOwnerCheck:Fire("OnValueChanged", false)
			end
			if aura.TelSec then
				AuraMetaProtectMetaCheck:SetValue(true)
				AuraMetaProtectMetaCheck:Fire("OnValueChanged", true)
			else
				AuraMetaProtectMetaCheck:SetValue(false)
				AuraMetaProtectMetaCheck:Fire("OnValueChanged", false)
			end
			AuraMetaUIDBox:SetText(aura.TelUID)
			AuraMetaUIDBox:Fire("OnTextChanged",aura.TelUID)
			AuraMetaVersionBox:SetText(aura.TelVer)
			AuraMetaVersionBox:Fire("OnTextChanged",aura.TelVer)
			AuraMetaLinkBox:SetText(aura.TelURL)
			AuraMetaLinkBox:Fire("OnTextChanged",aura.TelURL)
			AuraMetaCategoryBox:SetText(aura.TelCat)
			AuraMetaCategoryBox:Fire("OnTextChanged",aura.TelCat)
		else --no aura selected or aura with no metadata
			AuraMetaOwnerCheck:SetValue(false)
			AuraMetaOwnerCheck:Fire("OnValueChanged", false)
			AuraMetaProtectMetaCheck:SetValue(false)
			AuraMetaProtectMetaCheck:Fire("OnValueChanged", false)
			if aura then
				local randUID = randomUID()
				AuraMetaUIDBox:SetText(randUID)
				AuraMetaUIDBox:Fire("OnTextChanged",randUID)
			else
				AuraMetaUIDBox:SetText("")
				AuraMetaUIDBox:Fire("OnTextChanged","")
			end
			AuraMetaVersionBox:SetText("")
			AuraMetaVersionBox:Fire("OnTextChanged","")
			AuraMetaLinkBox:SetText("")
			AuraMetaLinkBox:Fire("OnTextChanged","")
			AuraMetaCategoryBox:SetText("")
			AuraMetaCategoryBox:Fire("OnTextChanged","")
		end
	end
	
	local function updateAuraDropdown(dropdown)
		local value = dropdown:GetValue()
		local list = {}
		for n, aura in pairs(auras) do
			--check only tracked, ungrouped auras
			if (not aura.parent) and (showUntracked or (aura.TelUID and aura.TelCat and aura.TelVer)) and (searchText == "" or string.find(string.lower(n),string.lower(searchText)) or (aura.TelOwn and string.find(string.lower(aura.TelOwn),string.lower(searchText)))) then
				if aura.TelOwn then
					list[n] = n .. "|cff00B4FF " .. aura.TelOwn .. "|r"
				elseif aura.TelUID then
					list[n] = n
				else
					list[n] = "|cffa0a0a0" .. n .. "|r"
				end
			end
		end
		if isempty(list) then
			list[1] = "No auras within parameters"
		end
		dropdown:SetList(list)
		if value and list[value] then
			dropdown:SetValue(value)
		else
			dropdown:SetValue(nil)
			dropdown:SetText("Select a WeakAura")
			dropdown:Fire("OnValueChanged", nil)
		end
	end
	
	--row 1
	AuraMetaSelect = AceGUI:Create("Dropdown")
	AuraMetaSelect:SetRelativeWidth(0.55)
	AuraMetaSelect:SetLabel("Select WeakAura")
	updateAuraDropdown(AuraMetaSelect)
	AuraMetaSelect:SetCallback("OnValueChanged",function(widget,callback,key)
		LoadAura()
	end)
	AuraMetaGroup:AddChild(AuraMetaSelect)
	
	AuraMetaSearchBox = AceGUI:Create("EditBox")
	AuraMetaSearchBox:SetRelativeWidth(0.22)
	AuraMetaSearchBox:SetLabel("Search")
	AuraMetaSearchBox:SetCallback("OnEnterPressed",function(widget,callback,text)
		widget:ClearFocus()
		searchText = text
		updateAuraDropdown(AuraMetaSelect)
	end)
	AuraMetaGroup:AddChild(AuraMetaSearchBox)
	
	AuraMetaShowAllCheck = AceGUI:Create("CheckBox")
	AuraMetaShowAllCheck:SetRelativeWidth(0.22)
	AuraMetaShowAllCheck:SetLabel("Show Untracked")
	AuraMetaShowAllCheck:SetCallback("OnValueChanged",function(widget,callback,value)
		showUntracked = value
		updateAuraDropdown(AuraMetaSelect)
	end)
	AuraMetaGroup:AddChild(AuraMetaShowAllCheck)
	
	--row 2	
	AuraMetaGenerateUIDButton = AceGUI:Create("Button")
	AuraMetaGenerateUIDButton:SetRelativeWidth(0.33)
	AuraMetaGenerateUIDButton:SetText("Generate Random UID")
	AuraMetaGenerateUIDButton:SetCallback("OnClick",function(widget,callback,click)
		local randUID = randomUID()
		AuraMetaUIDBox:SetText(randUID)
		AuraMetaUIDBox:Fire("OnTextChanged",randUID)
	end)
	AuraMetaGroup:AddChild(AuraMetaGenerateUIDButton)
	
	AuraMetaOwnerCheck = AceGUI:Create("CheckBox")
	AuraMetaOwnerCheck:SetRelativeWidth(0.33)
	AuraMetaOwnerCheck:SetLabel("Declare Ownership")
	AuraMetaOwnerCheck:SetCallback("OnValueChanged",function(widget,callback,value)
		if aura then
			if value and aura.TelOwn and aura.TelOwn ~= select(2,BNGetInfo()) then
				flags.GeneralDifferentOwner = true
			else
				flags.GeneralDifferentOwner = false
			end
			if aura.TelOwn ~= select(2,BNGetInfo()) and aura.TelSec then
				flags.GeneralSecure = true
			else
				flags.GeneralSecure = false
			end
		else
			flags.GeneralDifferentOwner = false
			flags.GeneralSecure = false
		end
		AuraMetaGeneralMessage:Fire("Update")
	end)
	AuraMetaGroup:AddChild(AuraMetaOwnerCheck)
	
	AuraMetaProtectMetaCheck = AceGUI:Create("CheckBox")
	AuraMetaProtectMetaCheck:SetRelativeWidth(0.33)
	AuraMetaProtectMetaCheck:SetLabel("Protect Metadata")
	AuraMetaProtectMetaCheck:SetCallback("OnValueChanged",function(widget,callback,value)
		if value then
			AuraMetaOwnerCheck:SetValue(true)
			AuraMetaOwnerCheck:Fire("OnValueChanged",true)
		end
	end)
	AuraMetaGroup:AddChild(AuraMetaProtectMetaCheck)
	
	--row 3
	AuraMetaUIDIcon = AceGUI:Create("IconNoHighlight")
	AuraMetaUIDIcon:SetWidth(30)
	AuraMetaUIDIcon:SetHeight(30)
	AuraMetaUIDIcon:SetImageSize(30,30)
	AuraMetaUIDIcon:SetImage("Interface\\AddOns\\WildcardTools\\assets\\arrow_right")
	AuraMetaUIDIcon:SetCallback("Update",function(widget,callback)
		if flags.UIDContainsCircumflex or flags.UIDDuplicate or (flags.UIDEmpty and aura.TelUID) then
			--set red
			widget.image:SetVertexColor(1,0,0,1)
		elseif not aura or flags.UIDEmpty or AuraMetaUIDBox:GetText() == aura.TelUID then
			--hide
			widget.image:SetVertexColor(1,1,1,0)
		else
			--set white
			widget.image:SetVertexColor(1,1,1,1)
		end
	end)
	AuraMetaUIDIcon:Fire("Update")
	AuraMetaGroup:AddChild(AuraMetaUIDIcon)
	
	AuraMetaUIDBox = AceGUI:Create("EditBox")
	AuraMetaUIDBox:SetRelativeWidth(0.3)
	AuraMetaUIDBox:SetLabel("UID")
	AuraMetaUIDBox:SetMaxLetters(15)
	AuraMetaUIDBox:SetCallback("OnEnterPressed",function(widget,callback,text)
		widget:ClearFocus()
	end)
	AuraMetaUIDBox:SetCallback("OnTextChanged",function(widget,callback,text)
		if aura then
			if string.find(text,"%^") then
				flags.UIDContainsCircumflex = true
			else
				flags.UIDContainsCircumflex = false
			end
			if text == "" then
				flags.UIDEmpty = true
			else
				flags.UIDEmpty = false
			end
			if aura.TelUID and aura.TelUID ~= text then
				flags.UIDNew = true
			else
				flags.UIDNew = false
			end
			flags.UIDDuplicate = false
			for n,a in pairs(auras) do
				if n~=aura.id and a.TelUID == text then
					flags.UIDDuplicate = true
				end
			end
		else
			flags.UIDContainsCircumflex = false
			flags.UIDEmpty = false
			flags.UIDNew = false
			flags.UIDDuplicate = false
		end
		AuraMetaUIDMessage:Fire("Update")
		AuraMetaUIDIcon:Fire("Update")
	end)
	AuraMetaGroup:AddChild(AuraMetaUIDBox)
	
	local spacing = AceGUI:Create("Label")
	spacing:SetRelativeWidth(0.05)
	AuraMetaGroup:AddChild(spacing)
	
	--UIDContainsCircumflex
	--UIDEmpty
	--UIDNew  --soft flag
	--UIDDuplicate
	AuraMetaUIDMessage = AceGUI:Create("InteractiveLabel")
	AuraMetaUIDMessage:SetRelativeWidth(0.55)
	AuraMetaUIDMessage:SetText("{message}")
	AuraMetaUIDMessage:SetCallback("Update",function(widget,callback)
		local text = ""
		if flags.UIDContainsCircumflex then
			text = "|cffff0000UIDs cannot contain circumflex (^) symbols.|r"
		elseif flags.UIDDuplicate then
			text = "|cffff0000You cannot create duplicate UIDs.|r"
		elseif flags.UIDEmpty then
			if attemptedSave or (aura and aura.TelUID) then
				text = "|cffff0000You must provide a UID for each aura. Try the random UID button above.|r"
			end
		elseif flags.UIDNew then
			text = "|cffffff00Are you sure you want to change the UID of this aura?|r"
		end
		widget:SetText(text)
	end)
	AuraMetaUIDMessage:Fire("Update")
	AuraMetaGroup:AddChild(AuraMetaUIDMessage)
	
	--row 4
	AuraMetaVersionIcon = AceGUI:Create("IconNoHighlight")
	AuraMetaVersionIcon:SetWidth(30)
	AuraMetaVersionIcon:SetHeight(30)
	AuraMetaVersionIcon:SetImageSize(30,30)
	AuraMetaVersionIcon:SetImage("Interface\\AddOns\\WildcardTools\\assets\\arrow_right")
	AuraMetaVersionIcon:SetCallback("Update",function(widget,callback)
		if not aura or (flags.VersionEmpty and not aura.TelVer) or not flags.VersionNew then
			--hide
			widget.image:SetVertexColor(1,1,1,0)
		elseif flags.VersionNAN then
			--set red
			widget.image:SetVertexColor(1,0,0,1)
		else
			--set white
			widget.image:SetVertexColor(1,1,1,1)
		end
	end)
	AuraMetaVersionIcon:Fire("Update")
	AuraMetaGroup:AddChild(AuraMetaVersionIcon)
	
	AuraMetaVersionBox = AceGUI:Create("EditBox")
	AuraMetaVersionBox:SetRelativeWidth(0.3)
	AuraMetaVersionBox:SetLabel("Version")
	AuraMetaVersionBox:SetMaxLetters(10)
	AuraMetaVersionBox:SetCallback("OnEnterPressed",function(widget,callback,text)
		widget:ClearFocus()
	end)
	AuraMetaVersionBox:SetCallback("OnTextChanged",function(widget,callback,text)
		if aura then
			if tonumber(text) then
				flags.VersionNAN = false
				local number = tonumber(text)
				if number == aura.TelVer then
					flags.VersionNew = false
				else
					flags.VersionNew = true
				end
				if aura.TelVer and number < aura.TelVer then
					flags.VersionLess = true
				else
					flags.VersionLess = false
				end
			else
				flags.VersionNAN = true
				if aura.TelVer or text ~= "" then
					flags.VersionNew = true
				else
					flags.VersionNew = false
				end
			end
			if text == "" then
				flags.VersionEmpty = true
			else
				flags.VersionEmpty = false
			end
		else
			flags.VersionLess = false
			flags.VersionNAN = false
			flags.VersionNew = false
			flags.VersionEmpty = false
		end
		AuraMetaVersionMessage:Fire("Update")
		AuraMetaVersionIcon:Fire("Update")
	end)
	AuraMetaGroup:AddChild(AuraMetaVersionBox)
	
	local spacing = AceGUI:Create("Label")
	spacing:SetRelativeWidth(0.05)
	AuraMetaGroup:AddChild(spacing)
	
	--VersionLess  --soft flag
	--VersionNAN
	--VersionNew  --soft flag
	--VersionEmpty
	AuraMetaVersionMessage = AceGUI:Create("InteractiveLabel")
	AuraMetaVersionMessage:SetRelativeWidth(0.55)
	AuraMetaVersionMessage:SetText("{message}")
	AuraMetaVersionMessage:SetCallback("Update",function(widget,callback)		
		local text = ""
		if flags.VersionEmpty then
			if attemptedSave or (aura and aura.TelVer) then
				text = "|cffff0000You must provide a Version for each aura.|r"
			end
		elseif flags.VersionNAN then
			text = "|cffff0000The version must be a number.|r"
		elseif flags.VersionLess then
			text = "|cffffff00Are you certain you wish to lower the version number?|r"
		end
		widget:SetText(text)
	end)
	AuraMetaVersionMessage:Fire("Update")
	AuraMetaGroup:AddChild(AuraMetaVersionMessage)
	
	--row 5
	AuraMetaLinkIcon = AceGUI:Create("IconNoHighlight")
	AuraMetaLinkIcon:SetWidth(30)
	AuraMetaLinkIcon:SetHeight(30)
	AuraMetaLinkIcon:SetImageSize(30,30)
	AuraMetaLinkIcon:SetImage("Interface\\AddOns\\WildcardTools\\assets\\arrow_right")
	AuraMetaLinkIcon:SetCallback("Update",function(widget,callback)
		if not aura or (flags.LinkEmpty and not aura.TelURL) or AuraMetaLinkBox:GetText() == aura.TelURL then
			--hide
			widget.image:SetVertexColor(1,1,1,0)
		elseif flags.LinkContainsCircumflex then
			--set red
			widget.image:SetVertexColor(1,0,0,1)
		else
			--set white
			widget.image:SetVertexColor(1,1,1,1)
		end
	end)
	AuraMetaLinkIcon:Fire("Update")
	AuraMetaGroup:AddChild(AuraMetaLinkIcon)
	
	AuraMetaLinkBox = AceGUI:Create("EditBox")
	AuraMetaLinkBox:SetRelativeWidth(0.3)
	AuraMetaLinkBox:SetLabel("Link")
	AuraMetaLinkBox:SetMaxLetters(100)
	AuraMetaLinkBox:SetCallback("OnEnterPressed",function(widget,callback,text)
		widget:ClearFocus()
	end)
	AuraMetaLinkBox:SetCallback("OnTextChanged",function(widget,callback,text)
		if aura then
			if string.find(text,"%^") then
				flags.LinkContainsCircumflex = true
			else
				flags.LinkContainsCircumflex = false
			end
			if text == "" then
				flags.LinkEmpty = true
			else
				flags.LinkEmpty = false
			end
			if aura.TelURL and aura.TelURL ~= text then
				flags.LinkNew = true
			else
				flags.LinkNew = false
			end
		else
			flags.LinkEmpty = false
			flags.LinkContainsCircumflex = false
			flags.LinkNew = false
		end
		AuraMetaLinkMessage:Fire("Update")
		AuraMetaLinkIcon:Fire("Update")
	end)
	AuraMetaGroup:AddChild(AuraMetaLinkBox)
	
	local spacing = AceGUI:Create("Label")
	spacing:SetRelativeWidth(0.05)
	AuraMetaGroup:AddChild(spacing)
	
	--LinkEmpty --soft flag
	--LinkContainsCircumflex
	--LinkNew  --soft flag
	AuraMetaLinkMessage = AceGUI:Create("InteractiveLabel")
	AuraMetaLinkMessage:SetRelativeWidth(0.55)
	AuraMetaLinkMessage:SetText("{message}")
	AuraMetaLinkMessage:SetCallback("Update",function(widget,callback)		
		local text = ""
		if flags.LinkContainsCircumflex then
			text = "|cffff0000Links cannot contain circumflex (^) symbols.|r"
		elseif flags.LinkNew then
			text = "|cffffff00Are you sure you want to change the download link for this aura?|r"
		end
		widget:SetText(text)
	end)
	AuraMetaLinkMessage:Fire("Update")
	AuraMetaGroup:AddChild(AuraMetaLinkMessage)
	
	--row 6
	AuraMetaCategoryIcon = AceGUI:Create("IconNoHighlight")
	AuraMetaCategoryIcon:SetWidth(30)
	AuraMetaCategoryIcon:SetHeight(30)
	AuraMetaCategoryIcon:SetImageSize(30,30)
	AuraMetaCategoryIcon:SetImage("Interface\\AddOns\\WildcardTools\\assets\\arrow_right")
	AuraMetaCategoryIcon:SetCallback("Update",function(widget,callback)
		if not aura or (flags.CategoryEmpty and not aura.TelCat) or AuraMetaCategoryBox:GetText() == aura.TelCat then
			--hide
			widget.image:SetVertexColor(1,1,1,0)
		elseif flags.CategoryEmpty and aura.TelCat then
			--set red
			widget.image:SetVertexColor(1,0,0,1)
		else
			--set white
			widget.image:SetVertexColor(1,1,1,1)
		end
	end)
	AuraMetaCategoryIcon:Fire("Update")
	AuraMetaGroup:AddChild(AuraMetaCategoryIcon)
	
	AuraMetaCategoryBox = AceGUI:Create("EditBox")
	AuraMetaCategoryBox:SetRelativeWidth(0.3)
	AuraMetaCategoryBox:SetLabel("Category")
	AuraMetaCategoryBox:SetMaxLetters(25)
	AuraMetaCategoryBox:SetCallback("OnEnterPressed",function(widget,callback,text)
		widget:ClearFocus()
	end)
	AuraMetaCategoryBox:SetCallback("OnTextChanged",function(widget,callback,text)
		if aura then
			if text == "" then
				flags.CategoryEmpty = true
			else
				flags.CategoryEmpty = false
			end
			if aura.TelCat and aura.TelCat ~= text then
				flags.CategoryNew = true
			else
				flags.CategoryNew = false
			end
		else
			flags.CategoryEmpty = false
			flags.CategoryContainsCircumflex = false
			flags.CategoryNew = false
		end
		AuraMetaCategoryMessage:Fire("Update")
		AuraMetaCategoryIcon:Fire("Update")
	end)
	AuraMetaGroup:AddChild(AuraMetaCategoryBox)
	
	local spacing = AceGUI:Create("Label")
	spacing:SetRelativeWidth(0.05)
	AuraMetaGroup:AddChild(spacing)
	
	--CategoryEmpty
	--CategoryNew  --soft flag
	AuraMetaCategoryMessage = AceGUI:Create("InteractiveLabel")
	AuraMetaCategoryMessage:SetRelativeWidth(0.55)
	AuraMetaCategoryMessage:SetText("{message}")
	AuraMetaCategoryMessage:SetCallback("Update",function(widget,callback)		
		local text = ""
		if flags.CategoryEmpty then
			if attemptedSave or (aura and aura.TelCat) then
				text = "|cffff0000You must provide a category for each aura.|r"
			end
		end
		widget:SetText(text)
	end)
	AuraMetaCategoryMessage:Fire("Update")
	AuraMetaGroup:AddChild(AuraMetaCategoryMessage)
	
	--row 7
	AuraMetaClearMetaButton = AceGUI:Create("Button")
	AuraMetaClearMetaButton:SetRelativeWidth(0.3)
	AuraMetaClearMetaButton:SetText("Clear Metadata")
	AuraMetaClearMetaButton:SetCallback("OnClick",function(widget,callback,click)
		if aura and not flags.GeneralSecure then
			WildcardTools.ConfirmationBox("Confirm to |cffff0000delete|r metadata.",
			function()
				aura.TelUID = nil
				aura.TelVer = nil
				aura.TelURL = nil
				aura.TelCat = nil
				aura.TelOwn = nil
				aura.TelSec = nil
				LoadAura()
				updateAuraDropdown(AuraMetaSelect)
			end)
		end
	end)
	AuraMetaGroup:AddChild(AuraMetaClearMetaButton)
	
	--GeneralDifferentOwner  --soft flag
	--GeneralSecure
	AuraMetaGeneralMessage = AceGUI:Create("Label")
	AuraMetaGeneralMessage:SetRelativeWidth(0.4)
	AuraMetaGeneralMessage:SetJustifyH("CENTER")
	AuraMetaGeneralMessage:SetCallback("Update",function(widget,callback)
		local text = ""
		if flags.GeneralSecure then
			text = "|cffff0000This aura is secure. Only |r|cff00B4FF" .. aura.TelOwn .. "|r|cffff0000 can edit its metadata.|r"
		elseif flags.GeneralDifferentOwner then
			text = "|cffffff00Are you sure you want to seize ownership from |r|cff00B4FF" .. aura.TelOwn .. "|r|cffffff00?|r"
		end
		widget:SetText(text)
	end)
	AuraMetaGeneralMessage:Fire("Update")
	AuraMetaGroup:AddChild(AuraMetaGeneralMessage)
	
	AuraMetaLoadButton = AceGUI:Create("Button")
	AuraMetaLoadButton:SetRelativeWidth(0.15)
	AuraMetaLoadButton:SetText("Load")
	AuraMetaLoadButton:SetCallback("OnClick",LoadAura)
	AuraMetaGroup:AddChild(AuraMetaLoadButton)
	
	AuraMetaSaveButton = AceGUI:Create("Button")
	AuraMetaSaveButton:SetRelativeWidth(0.15)
	AuraMetaSaveButton:SetText("Save")
	AuraMetaSaveButton:SetCallback("OnClick",function(widget,callback,click)
		if aura and not (flags.UIDContainsCircumflex or flags.UIDEmpty or flags.UIDDuplicate or flags.VersionNAN or flags.VersionEmpty or flags.LinkContainsCircumflex or flags.CategoryEmpty or flags.GeneralSecure) then
			local newUID, newVer, newURL, newCat = AuraMetaUIDBox:GetText(), AuraMetaVersionBox:GetText(), AuraMetaLinkBox:GetText(), AuraMetaCategoryBox:GetText()
			local newOwn, newSec = AuraMetaOwnerCheck:GetValue(), AuraMetaProtectMetaCheck:GetValue()
			newOwn = newOwn and (select(2,BNGetInfo())) or newOwn
			newVer = tonumber(newVer)
			WildcardTools.ConfirmationBox("Confirm to save metadata.",
			function()
				aura.TelUID = newUID
				aura.TelVer = newVer
				aura.TelURL = newURL
				aura.TelCat = newCat
				aura.TelOwn = newOwn
				aura.TelSec = newSec
				LoadAura()
				updateAuraDropdown(AuraMetaSelect)
			end)
		else
			attemptedSave = true
			AuraMetaUIDIcon:Fire("Update")
			AuraMetaUIDMessage:Fire("Update")
			AuraMetaVersionIcon:Fire("Update")
			AuraMetaVersionMessage:Fire("Update")
			AuraMetaLinkIcon:Fire("Update")
			AuraMetaLinkMessage:Fire("Update")
			AuraMetaCategoryIcon:Fire("Update")
			AuraMetaCategoryMessage:Fire("Update")
			AuraMetaGeneralMessage:Fire("Update")
		end
	end)
	AuraMetaGroup:AddChild(AuraMetaSaveButton)
end

local function TabCloseFunction()
	WidgetsReference = {}
	TabOneScrollFrameRef = false
end

function WA:GetTabs()
	WildcardTools.TabFunctions.WeakAuras1 = PopulateTab1
	WildcardTools.TabCloseFunctions[ModuleName] = TabCloseFunction
    return {text="WeakAuras", value="WeakAuras1"}
end

function WA:OnInitialize()
    -- Called when the addon is loaded
	WCTSaved.Options.AcceptAurasFromOnlyGuild = WCTSaved.Options.AcceptAurasFromOnlyGuild or false
	WCTSaved.Options.AcceptAurasFromOnlyLeader = WCTSaved.Options.AcceptAurasFromOnlyLeader or false
	WCTSaved.LatestVerSeen = WCTSaved.LatestVerSeen or {}
	
	WA:RegisterEvent("ADDON_LOADED", AddonLoaded)
end

function WA:OnEnable()
    -- Called when the addon is enabled
	WA:UpdateWAData()
	RegisterAddonMessagePrefix("WCAURA")
	WA:RegisterEvent("CHAT_MSG_ADDON", "MessageHandler")
	WA:RegisterEvent("GROUP_ROSTER_UPDATE", "RosterUpdate")
	WA:RegisterEvent("UNIT_CONNECTION", "RosterUpdate")
	WA:RegisterEvent("RAID_ROSTER_UPDATE", "RosterUpdate")
end

function WA:OnDisable()
    -- Called when the addon is disabled
end

end
