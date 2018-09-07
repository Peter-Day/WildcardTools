
--Written by Tel of <Wildcard Gaming> | Telerithis#1954

local AddonName,Engine = ...

local WildcardTools = LibStub("AceAddon-3.0"):NewAddon("WildcardTools","AceEvent-3.0")
local AceGUI = LibStub("AceGUI-3.0")

Engine[1] = WildcardTools
Engine[2] = AceGUI

_G[AddonName] = WildcardTools

local SEP = "^"
local lastTab = 1
local tabData = {}
local VER = "1.1.5"
local pos

SLASH_WILDCARDTOOLS1 = "/wct"
SLASH_WILDCARDTOOLS2 = "/wc"
SLASH_WILDCARDTOOLS3 = "/wildcard"
SLASH_WILDCARDTOOLS4 = "/wildcardtools"
SLASH_WILDCARDTOOLS5 = "/tel"

--LUA API
local tinsert = table.insert

WildcardTools.TabFunctions = {}
WildcardTools.TabCloseFunctions = {}

function SlashCmdList.WILDCARDTOOLS(cmd, editbox)
	local rqst, arg = strsplit(' ', cmd)
	if rqst then
		rqst = tonumber(rqst)-- or rqst
		WildcardTools:Populate_MainFrame(rqst)
	else
		WildcardTools:Populate_MainFrame()
	end
end

function isempty(t)
    for _,_ in pairs(t) do
        return false
    end
    return true
end

local confirmframe

function WildcardTools.ConfirmationBox(message, yesfunc, yesargs, nofunc, noargs)
	if not confirmframe then
		local frame = AceGUI:Create("Window")
		frame:SetLayout("flow")
		frame:SetWidth(300)
		frame:SetHeight(65)
		frame:EnableResize(false)
		frame:SetTitle(message)
		frame:SetCallback("OnClose", function(widget)
			widget:Release()
			confirmframe = false
		end)
		
		local yes = AceGUI:Create("Button")
		yes:SetText("Yes")
		yes:SetRelativeWidth(0.5)
		yes:SetCallback("OnClick",function(widget)
			if yesfunc and type(yesfunc) == "function" then
				if yesargs and type(yesargs) == "table" then
					yesfunc(unpack(yesargs))
				else
					yesfunc()
				end
			end
			frame:Release()
			confirmframe = false
		end)
		frame:AddChild(yes)
		
		local no = AceGUI:Create("Button")
		no:SetText("No")
		no:SetRelativeWidth(0.5)
		no:SetCallback("OnClick",function(widget)
			if nofunc and type(nofunc) == "function" then
				if noargs and type(noargs) == "table" then
					nofunc(unpack(noargs))
				else
					nofunc()
				end
			end
			frame:Release()
			confirmframe = false
		end)
		frame:AddChild(no)
		frame.frame:Raise()
		confirmframe = frame
		return frame
	else
		confirmframe.frame:Raise()
	end
end

-- Callback function for OnClose
local function OnClose(container, event)
	for _,f in pairs(WildcardTools.TabCloseFunctions) do
		f()
	end
	if WCTSaved.Options.SaveFramePos then
		pos = {container:GetPoint()}
	end
	container.frame:SetClampedToScreen(false)
	AceGUI:Release(container)
	WildcardTools_MainFrame=nil
end

-- Callback function for OnGroupSelected
local function SelectGroup(container, event, value)
	container:ReleaseChildren()
	for _,f in pairs(WildcardTools.TabCloseFunctions) do
		f()
	end
	WildcardTools.TabFunctions[value](container)
	for i,d in ipairs(tabData) do
		if d.value == value then
			lastTab = i
		end
	end
end

--function to populate the main frame of the addon
function WildcardTools:Populate_MainFrame(tab)
    if WildcardTools_MainFrame then
		WildcardTools_MainFrame:Fire("OnClose")
		return
	end
	WildcardTools_MainFrame = AceGUI:Create("Frame")
	WildcardTools_MainFrame:SetWidth(580) --547
	WildcardTools_MainFrame:EnableResize(false)
	WildcardTools_MainFrame.frame:SetClampedToScreen(true)
	if pos then
		WildcardTools_MainFrame:SetPoint(unpack(pos))
	end
	WildcardTools_MainFrame:SetTitle("Wildcard Tools")
	WildcardTools_MainFrame:SetStatusText("v"..VER)
	WildcardTools_MainFrame:SetCallback("OnClose", OnClose)
	WildcardTools_MainFrame:SetLayout("Fill") --causes the inset TabGroup to fill the whole frame
	
	-- Create the TabGroup
	local MainTab =  AceGUI:Create("TabGroup")
	MainTab:SetLayout("List") --List (Vertical) | Flow (horizontal) | Fill
	-- Setup which tabs to show
	tabData = {}
	for i,m in ipairs(WildcardTools.orderedModules) do
		local tabs = {m:GetTabs()}
		for _,t in ipairs(tabs) do
			tinsert(tabData,t)
		end
	end
	MainTab:SetTabs(tabData)
	-- Register callback
	MainTab:SetCallback("OnGroupSelected", SelectGroup)
	-- Set initial Tab (this will fire the OnGroupSelected callback)
	-------
	
	-- add to the frame container
	WildcardTools_MainFrame:AddChild(MainTab)
	
	if tab and type(tab) == "number" and tab > 0 and tab <= #tabData then
		MainTab:SelectTab(tabData[tab].value)
	elseif tab and type(tab) == "string" then
		MainTab:SelectTab(tab)
	else
		MainTab:SelectTab(tabData[lastTab].value)
	end
end

function WildcardTools:Options(container)
	local SavePosBox = AceGUI:Create("CheckBox")
	SavePosBox:SetLabel("Save Frame Position")
	SavePosBox:SetDescription("Otherwise frame always opens at screen center.")
	SavePosBox:SetRelativeWidth(0.33)
	SavePosBox:SetValue(WCTSaved.Options.SaveFramePos)
	SavePosBox:SetCallback("OnValueChanged",function(widget) WCTSaved.Options.SaveFramePos = widget:GetValue(); pos = nil end)
	container:AddChild(SavePosBox)
end

function WildcardTools:OnInitialize()
    -- Called when the addon is loaded
	WCTSaved = WCTSaved or {}
	WCTSaved.Options = WCTSaved.Options or {}
	
	WCTSaved.Options.SaveFramePos = WCTSaved.Options.SaveFramePos or false
end

function WildcardTools:OnEnable()
    -- Called when the addon is enabled
end

function WildcardTools:OnDisable()
    -- Called when the addon is disabled
end
