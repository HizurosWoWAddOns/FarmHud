local FarmHud = CreateFrame("frame")
_G["FarmHud"] = FarmHud

local LDB = LibStub("LibDataBroker-1.1"):NewDataObject("FarmHud",
{
	type	= "launcher",
	icon	= "Interface\\Icons\\INV_Misc_Herb_MountainSilverSage.png",
	label	= "FarmHud",
	text	= "FarmHud",
	OnTooltipShow = function(tt)
		tt:AddLine("FarmHud")
		tt:AddLine("|cffffff00Click|r to toggle FarmHud")
		tt:AddLine("|cffffff00Right click|r to config")
		tt:AddLine("Or macro with /script FarmHud:Toggle()")
	end,
	OnClick = function(_, button)
		if button == "LeftButton" then
			FarmHud:Toggle()
		else
			LibStub("AceConfigDialog-3.0"):Open("FarmHud")
		end
	end
})

local LDBIcon = LDB and LibStub("LibDBIcon-1.0", true)

local NPCScan = _NPCScan and _NPCScan.Overlay and _NPCScan.Overlay.Modules.List[ "Minimap" ];

BINDING_HEADER_FARMHUD		= "FarmHud"
BINDING_NAME_TOGGLEFARMHUD	= "Toggle FarmHud's Display"
BINDING_NAME_TOGGLEFARMHUDMOUSE	= "Toggle FarmHud's tooltips (Can't click through Hud)"

local options = {
	name = "FarmHud",
	type = "group",
	args = {
		confdesc = {
			order = 1,
			type = "description",
			name = "A Hud for farming ore and herbs.\n",
			cmdHidden = true
		},
		displayheader = {
			order = 2,
			type = "header",
			name = "FarmHud Options",
		},
		hide_minimapicon = {
			type = "toggle", width = "double",
			name = "Hide Minimap Icon",
			desc = "Show or hide the minimap icon.",
			order = 3,
			get = function() return FarmHudDB.MinimapIcon.hide end,
			set = function(_, v)
				FarmHudDB.MinimapIcon.hide = v
				if v then LDBIcon:Hide("FarmHud") else LDBIcon:Show("FarmHud") end
			end,
		},
		bind_showtoggle = {
			type = "keybinding", width = "double",
			name = "Toggle FarmHud's Display",
			desc = "Set the keybinding to show FarmHud.",
			order = 4,
			get = function() return GetBindingKey("TOGGLEFARMHUD") end,
			set = function(_, v)
				local keyb = GetBindingKey("TOGGLEFARMHUD")
				if keyb then SetBinding(keyb) end
				if v ~= "" then SetBinding(v, "TOGGLEFARMHUD") end
				SaveBindings(GetCurrentBindingSet())
			end,
		},
		bind_mousetoggle = {
			type = "keybinding", width = "double",
			name = "Toggle FarmHud's tooltips (Can't click through Hud)",
			desc = "Set the keybinding to allow mouse over tooltips.",
			order = 5,
			get = function() return GetBindingKey("TOGGLEFARMHUDMOUSE") end,
			set = function(_, v)
				local keyb = GetBindingKey("TOGGLEFARMHUDMOUSE")
				if keyb then SetBinding(keyb) end
				if v ~= "" then SetBinding(v, "TOGGLEFARMHUDMOUSE") end
				SaveBindings(GetCurrentBindingSet())
			end,
		},
		show_gathermate = {
			type = "toggle", width = "double",
			name = "Toggle GatherMate2 support",
			order = 6,
			get = function() return FarmHudDB.show_gathermate end,
			set = function(_, v)
				FarmHudDB.show_gathermate = v
			end,
		},
		show_routes = {
			type = "toggle", width = "double",
			name = "Toggle Routes support",
			order = 7,
			get = function() return FarmHudDB.show_routes end,
			set = function(_, v)
				FarmHudDB.show_routes = v
			end,
		},
		show_npcscan = {
			type = "toggle", width = "double",
			name = "Toggle NPCScan support",
			order = 8,
			get = function() return FarmHudDB.show_npcscan end,
			set = function(_, v)
				FarmHudDB.show_npcscan = v
			end,
		},
	}
}

LibStub("AceConfig-3.0"):RegisterOptionsTable("FarmHud", options)
LibStub("AceConfigDialog-3.0"):AddToBlizOptions("FarmHud")


local fh_scale = 1.4
local fh_mapRotation
local indicators = {"N", "NE", "E", "SE", "S", "SW", "W", "NW"}
local directions = {}
local playerDot
local updateRotations
local mousewarn

local onShow = function(self)
	fh_mapRotation = GetCVar("rotateMinimap")
	SetCVar("rotateMinimap", "1")
	if GatherMate2 and (FarmHudDB.show_gathermate == true) then
		GatherMate2:GetModule("Display"):ReparentMinimapPins(FarmHudMapCluster)
		GatherMate2:GetModule("Display"):ChangedVars(nil, "ROTATE_MINIMAP", "1")
	end
	
	if Routes and Routes.ReparentMinimap and (FarmHudDB.show_routes == true) then
		Routes:ReparentMinimap(FarmHudMapCluster)
		Routes:CVAR_UPDATE(nil, "ROTATE_MINIMAP", "1")
	end

	if NPCScan and NPCScan.SetMinimapFrame and (FarmHudDB.show_npcscan == true) then
		NPCScan:SetMinimapFrame(FarmHudMapCluster)
	end

	FarmHud:SetScript("OnUpdate", updateRotations)
	MinimapCluster:Hide()
end

local onHide = function(self, force)
	SetCVar("rotateMinimap", fh_mapRotation)
	if GatherMate2 then
		GatherMate2:GetModule("Display"):ReparentMinimapPins(Minimap)
		GatherMate2:GetModule("Display"):ChangedVars(nil, "ROTATE_MINIMAP", fh_mapRotation)
	end
	
	if Routes and Routes.ReparentMinimap then
		Routes:ReparentMinimap(Minimap)
		Routes:CVAR_UPDATE(nil, "ROTATE_MINIMAP", fh_mapRotation)
	end
	
	if NPCScan and NPCScan.SetMinimapFrame then
		NPCScan:SetMinimapFrame(Minimap)
	end

	FarmHud:SetScript("OnUpdate", nil)
	MinimapCluster:Show()
end


function FarmHud:SetScales()
	FarmHudMinimap:ClearAllPoints()
	FarmHudMinimap:SetPoint("CENTER", UIParent, "CENTER")
	
	FarmHudMapCluster:ClearAllPoints()
	FarmHudMapCluster:SetPoint("CENTER")
	
	local size = UIParent:GetHeight() / fh_scale
	FarmHudMinimap:SetWidth(size)
	FarmHudMinimap:SetHeight(size)
	FarmHudMapCluster:SetHeight(size)
	FarmHudMapCluster:SetWidth(size)
	gatherCircle:SetWidth(size * 0.45)
	gatherCircle:SetHeight(size * 0.45)
	
	FarmHudMapCluster:SetScale(fh_scale)
	playerDot:SetWidth(15)
	playerDot:SetHeight(15)
	
	for k, v in ipairs(directions) do
		v.radius = FarmHudMinimap:GetWidth() * 0.214
	end
end

-- Toggle FarmHud display
function FarmHud:Toggle(flag)
	if flag == nil then
		if FarmHudMapCluster:IsVisible() then
			FarmHudMapCluster:Hide()
		else
			FarmHudMapCluster:Show()
			FarmHud:SetScales()
		end
	else
		if flag then
			FarmHudMapCluster:Show()
			FarmHud:SetScales()
		else
			FarmHudMapCluster:Hide()
		end
	end
end

-- Toggle the mouse to check out herb / ore tooltips
function FarmHud:MouseToggle()
	if FarmHudMinimap:IsMouseEnabled() then
		FarmHudMinimap:EnableMouse(false)
		mousewarn:Hide()
	else
		FarmHudMinimap:EnableMouse(true)
		mousewarn:Show()
	end
end

do
	local target = 1 / 90
	local total = 0
	
	function updateRotations(self, t)
		total = total + t
		if total < target then return end
		while total > target do total = total - target end
		if MinimapCluster:IsVisible() then MinimapCluster:Hide() end
		local bearing = GetPlayerFacing()
		for k, v in ipairs(directions) do
			local x, y = math.sin(v.rad + bearing), math.cos(v.rad + bearing)
			v:ClearAllPoints()
			v:SetPoint("CENTER", FarmHudMapCluster, "CENTER", x * v.radius, y * v.radius)
		end
	end
end

function FarmHud:PLAYER_LOGIN()

	if not FarmHudDB then
		FarmHudDB = {}
	end

	if not FarmHudDB.MinimapIcon then
		FarmHudDB.MinimapIcon = {
			hide = false,
			minimapPos = 220,
			radius = 80,
		}
	end

	if not FarmHudDB.show_gathermate then
		FarmHudDB.show_gathermate = true
	end

	if not FarmHudDB.show_routes then
		FarmHudDB.show_routes = true
	end

	if not FarmHudDB.show_npcscan then
		FarmHudDB.show_npcscan = true
	end

	if LDBIcon then
		LDBIcon:Register("FarmHud", LDB, FarmHudDB.MinimapIcon)
	end

	FarmHudMinimap:SetPoint("CENTER", UIParent, "CENTER")
	FarmHudMapCluster:SetFrameStrata("BACKGROUND")
	FarmHudMapCluster:SetAlpha(0.7)
	FarmHudMinimap:SetAlpha(0)
	FarmHudMinimap:EnableMouse(false)

	setmetatable(FarmHudMapCluster, { __index = FarmHudMinimap })

	FarmHudMapCluster._GetScale = FarmHudMapCluster.GetScale
	FarmHudMapCluster.GetScale = function()
	return 1
	end

	gatherCircle = FarmHudMapCluster:CreateTexture()
	gatherCircle:SetTexture([[SPELLS\CIRCLE.BLP]])
	gatherCircle:SetBlendMode("ADD")
	gatherCircle:SetPoint("CENTER")
	local radius = FarmHudMinimap:GetWidth() * 0.45
	gatherCircle:SetWidth(radius)
	gatherCircle:SetHeight(radius)
	gatherCircle.alphaFactor = 0.5
	gatherCircle:SetVertexColor(0, 1, 0, 1 * (gatherCircle.alphaFactor or 1) / FarmHudMapCluster:GetAlpha())

	playerDot = FarmHudMapCluster:CreateTexture()
	playerDot:SetTexture([[Interface\GLUES\MODELS\UI_Tauren\gradientCircle.blp]])
	playerDot:SetBlendMode("ADD")
	playerDot:SetPoint("CENTER")
	playerDot.alphaFactor = 2
	playerDot:SetWidth(15)
	playerDot:SetHeight(15)

	local radius = FarmHudMinimap:GetWidth() * 0.214
	for k, v in ipairs(indicators) do
		local rot = (0.785398163 * (k-1))
		local ind = FarmHudMapCluster:CreateFontString(nil, nil, "GameFontNormalSmall")
		local x, y = math.sin(rot), math.cos(rot)
		ind:SetPoint("CENTER", FarmHudMapCluster, "CENTER", x * radius, y * radius)
		ind:SetText(v)
		ind:SetShadowOffset(0.2,-0.2)
		ind.rad = rot
		ind.radius = radius
		tinsert(directions, ind)
	end

	FarmHud:SetScales()

	mousewarn = FarmHudMapCluster:CreateFontString(nil, nil, "GameFontNormalSmall")
	mousewarn:SetPoint("CENTER", FarmHudMapCluster, "CENTER", 0, FarmHudMapCluster:GetWidth()*.05)
	mousewarn:SetText("MOUSE ON")
	mousewarn:Hide()

	FarmHudMapCluster:Hide()
	FarmHudMapCluster:SetScript("OnShow", onShow)
	FarmHudMapCluster:SetScript("OnHide", onHide)
end

function FarmHud:PLAYER_LOGOUT()
	FarmHud:Toggle(false)
end

FarmHud:SetScript("OnEvent", function(self, event, ...) if self[event] then return self[event](self, event, ...) end end)
FarmHud:RegisterEvent("PLAYER_LOGIN")
FarmHud:RegisterEvent("PLAYER_LOGOUT")
