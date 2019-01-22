----[[
local ModuleName = 'Landing'
local WildcardTools, AceGUI = unpack(select(2, ...)); --Import: WildcardTools,
local LD = WildcardTools:NewModule(ModuleName, 'AceEvent-3.0', "AceTimer-3.0")

local SEP = "^"

--LUA API
local tinsert, tremove = table.insert, table.remove

local function PopulateTab(container)
	container:SetLayout("Flow")
	
	--fix centering issues. don't try to understand.
	container.content.width = 524--container.content:GetWidth()
	--print(container.content.width,container.content:GetWidth())
	
	local WildcardIcon = AceGUI:Create("IconNoHighlight")
	WildcardIcon:SetFullWidth(true)
	WildcardIcon:SetImageSize(128,128)
	WildcardIcon:SetHeight(128)
	WildcardIcon:SetImage("Interface\\AddOns\\WildcardTools\\assets\\Wildcard_Icon")
	container:AddChild(WildcardIcon)
	
	local WildcardNameLabel = AceGUI:Create("InteractiveLabel")
	WildcardNameLabel:SetFullWidth(true)
	WildcardNameLabel:SetJustifyH("CENTER")
	WildcardNameLabel:SetFont((WildcardNameLabel.label:GetFont()),22)
	WildcardNameLabel:SetText("Wildcard Gaming")
	container:AddChild(WildcardNameLabel)
	
	local WildcardWebsiteLabel = AceGUI:Create("InteractiveLabel")
	WildcardWebsiteLabel:SetFullWidth(true)
	WildcardWebsiteLabel:SetJustifyH("CENTER")
	WildcardWebsiteLabel:SetFont((WildcardWebsiteLabel.label:GetFont()),12)
	WildcardWebsiteLabel:SetText("http://wildcard.gg/")
	container:AddChild(WildcardWebsiteLabel)
	
	local WildcardTwitterLabel = AceGUI:Create("InteractiveLabel")
	WildcardTwitterLabel:SetFullWidth(true)
	WildcardTwitterLabel:SetJustifyH("CENTER")
	WildcardTwitterLabel:SetFont((WildcardTwitterLabel.label:GetFont()),12)
	WildcardTwitterLabel:SetText("@Wildcard_GG")
	container:AddChild(WildcardTwitterLabel)
	
	local space = AceGUI:Create("InteractiveLabel")
	space:SetFullWidth(true)
	space:SetJustifyH("CENTER")
	space:SetText(" ")
	container:AddChild(space)
	
	local StreamersLabel = AceGUI:Create("InteractiveLabel")
	StreamersLabel:SetFullWidth(true)
	StreamersLabel:SetJustifyH("CENTER")
	StreamersLabel:SetFont((StreamersLabel.label:GetFont()),14)
	StreamersLabel:SetText("Wildcard Streamers")
	container:AddChild(StreamersLabel)
	
	local StreamersLink = AceGUI:Create("InteractiveLabel")
	StreamersLink:SetFullWidth(true)
	StreamersLink:SetJustifyH("CENTER")
	StreamersLink:SetFont((StreamersLink.label:GetFont()),12)
	StreamersLink:SetText("twitch.tv/team/wildcardgaming")
	container:AddChild(StreamersLink)
	
	local space2 = AceGUI:Create("InteractiveLabel")
	space2:SetFullWidth(true)
	space2:SetJustifyH("CENTER")
	space2:SetText(" ")
	container:AddChild(space2)
	
	local ContactLabel = AceGUI:Create("InteractiveLabel")
	ContactLabel:SetFullWidth(true)
	ContactLabel:SetJustifyH("CENTER")
	ContactLabel:SetFont((ContactLabel.label:GetFont()),11)
	ContactLabel:SetText("Contact me @Telerithis, or Discord Tel#6594, or BNet Tel#11724.")
	container:AddChild(ContactLabel)
end

local function TabCloseFunction()
	
end

function LD:GetTabs()
	WildcardTools.TabFunctions[ModuleName] = PopulateTab
	WildcardTools.TabCloseFunctions[ModuleName] = TabCloseFunction
    return {text="Wildcard Gaming", value=ModuleName}
end

function LD:OnInitialize()
    -- Called when the addon is loaded
end

function LD:OnEnable()
    -- Called when the addon is enabled
end

function LD:OnDisable()
    -- Called when the addon is disabled
end
--]]
