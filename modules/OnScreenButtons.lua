
local addon, ns = ...;
local L = ns.L;

local dirs = {
	Buttons = "Interface/Buttons/",
	WorldMap = "Interface/WorldMap/",
	media = "Interface/AddOns/FarmHud/media/",
}

local buttons = {
	mouseButton      = { 1, {"CENTER",-34,0}, {dirs.media.."Mouse-Normal"},                 {dirs.media.."Mouse-Pushed"},                   function() FarmHud:ToggleMouse() end},
	backgroundButton = { 2, {"CENTER",-12,0}, {dirs.WorldMap.."WorldMap-Icon"},             {dirs.WorldMap.."WorldMap-Icon",true},          function() FarmHud:ToggleBackground() end},
	optionsButton    = { 3, {"CENTER", 12,0}, {dirs.media.."options"},                      {dirs.media.."options",true},                   function() FarmHud:ToggleOptions() end},
	closeButton      = { 4, {"CENTER", 34,0}, {dirs.Buttons.."UI-Panel-MinimizeButton-Up"}, {dirs.Buttons.."UI-Panel-MinimizeButton-Down"}, function() FarmHud:Toggle(false) end},
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
	OnHide = nil
}

local function updateButtons()
	local parent = FarmHud
	local Buttons = FarmHud.onScreenButtons
	FarmHud.onScreenButtons:SetShown(FarmHudDB.buttons_show)
	local y = parent:GetHeight()*FarmHudDB.buttons_radius*0.5
	if FarmHudDB.buttons_bottom then
		y = -y
	end
	Buttons:ClearAllPoints()
	Buttons:SetPoint("CENTER", parent, "CENTER", 0, y)
	for n in pairs(buttons) do
		Buttons[n]:SetAlpha(FarmHudDB.buttons_alpha)
	end
end

function module.ToggleButtons(state)
	if not FarmHudDB.buttons_show then return end
	if state==nil then
		state = FarmHudDB.buttons_show
	end
	FarmHud.onScreenButtons:SetShown(state)
	if state then
		updateButtons()
	end
end

function module.OnShow()
	updateButtons()
end

--function module.OnHide() end

local function opt(info,value,...)
	local key = info[#info];
	if value~=nil then
		if (...)~=nil then
			value = {value,...}
		end
		FarmHudDB[key] = value
		updateButtons()
	end
	if type(FarmHudDB[key])=="table" then
		return unpack(FarmHudDB[key]);
	end
	return FarmHudDB[key]
end

function module.AddOptions()
	return {
		onscreenbuttons = {
			type = "group", order = 6,
			name = L["OnScreen"],
			get = opt,
			set = opt,
			args = {
				buttons_show = {
					type = "toggle", order = 1, width = "double",
					name = L["OnScreenShow"], desc = L["OnScreenShowDesc"]
				},
				buttons_bottom = {
					type = "toggle", order = 2, width = "double",
					name = L["OnScreenBottom"], desc = L["OnScreenBottomDesc"],
				},
				buttons_radius = {
					type = "range", order = 3,
					name = L["ChangeRadius"], desc = L["ChangeRadiusDesc"],
					min = 0.1, max = 0.9, step=0.005, isPercent=true
				},
				buttons_alpha = {
					type = "range", order = 4,
					name = OPACITY, desc = L["OnScreenAlphaDesc"],
					min = 0, max = 1, step = 0.1, isPercent = true
				}
			}
		}
	}
end

function module.events.ADDON_LOADED()
	FarmHud.onScreenButtons = CreateFrame("Frame",nil,FarmHud,"FarmHudOnScreenButtonsTemplate")
	for buttonName,buttonData in pairs(buttons)do
		local btn = CreateFrame("Button", nil, FarmHud.onScreenButtons, "FarmHudonScreenButtonTemplate")
		btn:SetPoint(unpack(buttonData[2]))
		btn:SetNormalTexture(buttonData[3][1])
		btn:SetPushedTexture(buttonData[4][1])
		if buttonData[4][2] then
			btn:GetPushedTexture():SetDesaturated(true)
		end
		btn:SetScript("OnClick",buttonData[5])
		FarmHud.onScreenButtons[buttonName] = btn
	end
end

function module.events.PLAYER_LOGIN()
	for k,v in pairs(module.dbDefaults)do
		if FarmHudDB[k]==nil then
			FarmHudDB[k] = v;
		end
	end

end

ns.modules["OnScreenButtons"] = module;