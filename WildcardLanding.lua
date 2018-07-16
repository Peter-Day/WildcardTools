----[[
local ModuleName = 'Landing'
local WildcardTools, AceGUI = unpack(select(2, ...)); --Import: WildcardTools,
local LD = WildcardTools:NewModule(ModuleName, 'AceEvent-3.0', "AceTimer-3.0")

local SEP = "^"

--LUA API
local tinsert, tremove = table.insert, table.remove

local thanks = {
	"Lumilol",
	"Nnogga",
	"Mortytide",
	"Newmie",
	"& Others"
}

local streamers = {
	"TMSean",
	"Utility",
	"lumi_tv",
	"ikkuza",
	"keilosh",
	"Driney_"
}

local function PopulateTab(container)
	container:SetLayout("Flow")
	container.content.width = container.content:GetWidth()
	
	local WildcardIcon = AceGUI:Create("IconNoHighlight")
	WildcardIcon:SetFullWidth(true)
	WildcardIcon:SetImageSize(128,128)
	WildcardIcon:SetHeight(128)
	WildcardIcon:SetImage("Interface\\AddOns\\WildcardTools\\assets\\WC_Logo_Skull")
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
	
	local LeftColumnLabel = AceGUI:Create("InteractiveLabel")
	LeftColumnLabel:SetRelativeWidth(0.5)
	LeftColumnLabel:SetJustifyH("CENTER")
	LeftColumnLabel:SetFont((LeftColumnLabel.label:GetFont()),14)
	LeftColumnLabel:SetText("Special Thanks To")
	container:AddChild(LeftColumnLabel)
	
	local RightColumnLabel = AceGUI:Create("InteractiveLabel")
	RightColumnLabel:SetRelativeWidth(0.5)
	RightColumnLabel:SetJustifyH("CENTER")
	RightColumnLabel:SetFont((RightColumnLabel.label:GetFont()),14)
	RightColumnLabel:SetText("Wildcard Streamers")
	container:AddChild(RightColumnLabel)
	
	for i=1,max(#thanks,#streamers) do
		local label = AceGUI:Create("InteractiveLabel")
		label:SetRelativeWidth(0.5)
		label:SetJustifyH("CENTER")
		label:SetText(thanks[i])
		container:AddChild(label)
		local label = AceGUI:Create("InteractiveLabel")
		label:SetRelativeWidth(0.5)
		label:SetJustifyH("CENTER")
		label:SetText(streamers[i])
		container:AddChild(label)
	end
	
	local space = AceGUI:Create("InteractiveLabel")
	space:SetFullWidth(true)
	space:SetJustifyH("CENTER")
	space:SetText(" ")
	space:SetFont((space.label:GetFont()),72)
	container:AddChild(space)
	
	local ContactLabel = AceGUI:Create("InteractiveLabel")
	ContactLabel:SetFullWidth(true)
	ContactLabel:SetJustifyH("CENTER")
	ContactLabel:SetFont((ContactLabel.label:GetFont()),11)
	ContactLabel:SetText("Contact me @Telerithis, or Discord Tel#6594, or BNet Telerithis#1954.")
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