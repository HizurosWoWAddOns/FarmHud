
local addon, ns = ...;
local L = ns.L;

local dirs = {
	Buttons = "Interface/Buttons/",
	WorldMap = "Interface/WorldMap/",
	media = "Interface/AddOns/FarmHud/media/",
}

local iName, iElement, iTexNormal, iTexPushed, iTexPushedDesaturated, iScriptFunc = 1,2,3,4,5,6
local buttons = {
	{ "mouseButton",      false, dirs.media.."Mouse-Normal",                 dirs.media.."Mouse-Pushed",                   false, function() FarmHud:ToggleMouse() end},
	{ "backgroundButton", false, dirs.WorldMap.."WorldMap-Icon",             dirs.WorldMap.."WorldMap-Icon",               true,  function() FarmHud:ToggleBackground() end},
	{ "optionsButton",    false, dirs.media.."options",                      dirs.media.."options",                        true,  function() FarmHud:ToggleOptions() end},
	{ "closeButton",      false, dirs.Buttons.."UI-Panel-MinimizeButton-Up", dirs.Buttons.."UI-Panel-MinimizeButton-Down", false, function() FarmHud:Toggle(false) end},
}

local module = {
	dbDefaults={
		buttons_show=false,
		buttons_buttom=false,
		buttons_radius=0.56,
		buttons_alpha=0.6,
	},
	events = {},
	OnShow = nil,
	OnHide = nil,
	OnLoad = nil,
	OnSetScale = nil,
	AddOptions = nil,
}

local function createOnScreenButtons()
	FarmHud.onScreenButtons = CreateFrame("Frame",nil,FarmHud)
	local width = 0
	for i=1, #buttons do
		local size = FarmHudDB.button_size
		local btn = CreateFrame("Button", nil, FarmHud.onScreenButtons)
		buttons[i][iElement] = btn
		btn:SetSize(size,size)
		btn:SetNormalTexture(buttons[i][iTexNormal])
		btn:SetPushedTexture(buttons[i][iTexPushed])
		btn:SetHighlightTexture("Interface/Buttons/UI-Panel-MinimizeButton-Highlight")
		btn:GetHighlightTexture():SetBlendMode("ADD")
		if buttons[i][iTexPushedDesaturated] then
			btn:GetPushedTexture():SetDesaturated(true)
		end
		btn:SetScript("OnClick",buttons[i][iScriptFunc])
		FarmHud.onScreenButtons[buttons[i][iName]] = btn
		if i==1 then
			btn:SetPoint("LEFT", FarmHud.onScreenButtons, "LEFT", 0, 0)
		else
			btn:SetPoint("LEFT", buttons[i-1][iElement], "RIGHT", FarmHudDB.button_spacing, 0)
			width = width+FarmHudDB.button_spacing
		end
		width = width+size
	end
	FarmHud.onScreenButtons:SetSize(width,1)
	FarmHud.onScreenButtons:SetAlpha(FarmHudDB.buttons_alpha)
end

function module.OnShow()
	if not FarmHudDB.buttons_show then return end
	FarmHud.onScreenButtons:Show()
end

function module.OnHide()
	FarmHud.onScreenButtons:Hide()
end

function module.OnSetScales()
	FarmHud.onScreenButtons:SetPoint("CENTER", FarmHud, "CENTER", 0, ns.calcDistance(FarmHudDB.buttons_radius,FarmHudDB.buttons_bottom))
end

-- function module.OnLoad() end

-- function module.events.ADDON_LOADED() end

function module.events.PLAYER_LOGIN()
	createOnScreenButtons()
end

local function updateOpts(key)
	if key=="buttons_show" then
		FarmHud.onScreenButtons:SetShown(FarmHudDB.buttons_show)
	elseif key=="buttons_radius" or key=="buttons_bottom" then
		FarmHud.onScreenButtons:SetPoint("CENTER", FarmHud, "CENTER", 0, ns.calcDistance(FarmHudDB.buttons_radius,FarmHudDB.buttons_bottom))
	elseif key=="buttons_alpha" then
		FarmHud.onScreenButtons:SetAlpha(FarmHudDB.buttons_alpha)
	elseif key=="button_spacing" or key=="button_size" then
		local spacing = FarmHudDB.button_spacing
		local size = FarmHudDB.button_size
		buttons[1][iElement]:SetSize(size,size)
		for i=2, #buttons do
			buttons[i][iElement]:SetSize(size,size)
			buttons[i][iElement]:SetPoint("LEFT", buttons[i-1][iElement], "RIGHT", spacing, 0)
		end
		FarmHud.onScreenButtons:SetSize((size+spacing)*#buttons-spacing,1)
	end
end

-- function module.events.ADDON_LOADED() end

-- function module.events.PLAYER_LOGIN() end

local function opt(info,value,...)
	local key = info[#info];
	if value~=nil then
		if (...)~=nil then
			value = {value,...}
		end
		FarmHudDB[key] = value
		updateOpts(key)
	end
	if type(FarmHudDB[key])=="table" then
		return unpack(FarmHudDB[key]);
	end
	return FarmHudDB[key]
end

function module.AddOptions()
	return {
		onscreenbuttons = {
			type = "group",
			name = L["OnScreen"],
			get = opt,
			set = opt,
			args = {
				buttons_show = {
					type = "toggle", order = 1, width = "double",
					name = L["OnScreenShow"], desc = L["OnScreenShowDesc"]
				},
				buttons_alpha = {
					type = "range", order = 4,
					name = OPACITY, desc = L["OnScreenAlphaDesc"],
					min = 0, max = 1, step = 0.1, isPercent = true
				},
				positionOptions = {
					type = "group", order=10, inline = true,
					name = L["Position options"],
					args = {
						buttons_radius = {
							type = "range", order = 1, width = "double",
							name = L["ChangeRadius"], desc = L["ChangeRadiusDesc"],
							min = 0.1, max = 0.95, step=0.01, isPercent=true
						},
						buttons_bottom = {
							type = "toggle", order = 2, width = "double",
							name = L["OnScreenBottom"], desc = L["OnScreenBottomDesc"],
						},
					}
				},
			}
		}
	}
end

ns.modules["OnScreenButtons"] = module;
