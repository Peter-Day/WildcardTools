
local ModuleName = 'Options'
local WildcardTools, AceGUI = unpack(select(2, ...)); --Import: WildcardTools,
local O = WildcardTools:NewModule(ModuleName, 'AceEvent-3.0', "AceTimer-3.0")

local SEP = "^"

--LUA API
local tinsert = table.insert

local function PopulateTab(container)
	container:SetLayout("Fill")
	
	local scrollFrame = AceGUI:Create("ScrollFrame")
	scrollFrame:SetLayout("Flow")
	container:AddChildren(scrollFrame)
	
	if WildcardTools.Options then
		local moduleHeading = AceGUI:Create("Heading")
		moduleHeading:SetFullWidth(true)
		moduleHeading:SetText(WildcardTools:GetName())
		scrollFrame:AddChild(moduleHeading)
		WildcardTools:Options(scrollFrame)
	end
	
	for i,m in ipairs(WildcardTools.orderedModules) do
		if m.Options then
			local moduleHeading = AceGUI:Create("Heading")
			moduleHeading:SetFullWidth(true)
			moduleHeading:SetText(m:GetName())
			scrollFrame:AddChild(moduleHeading)
			m:Options(scrollFrame)
		end
	end
	
	local fin = AceGUI:Create("Heading")
	fin:SetFullWidth(true)
	scrollFrame:AddChild(fin)
end

local function TabCloseFunction()
	
end

function O:GetTabs()
	WildcardTools.TabFunctions.Options = PopulateTab
	WildcardTools.TabCloseFunctions[ModuleName] = TabCloseFunction
    return {text="Options", value="Options"}
end

function O:OnInitialize()
    -- Called when the addon is loaded
end

function O:OnEnable()
    -- Called when the addon is enabled
end

function O:OnDisable()
    -- Called when the addon is disabled
end