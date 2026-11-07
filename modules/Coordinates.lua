local addon,ns = ...;
local L = ns.L;
local coordsTicker
local module = {
	dbDefaults={
		coords_show=true,
		coords_bottom=false,
		coords_color={1,0.82,0,0.7},
		coords_radius=0.51,
		coords_textscale=1,
	},
	events = {},
	OnShow = nil,
	OnHide = nil,
	OnLoad = nil,
	OnSetScale = nil,
	AddOptions = nil,
}

local function CoordsUpdate_TickerFunc()
	local x,y,uiMapID = 0,0,C_Map.GetBestMapForUnit("player");
	if uiMapID then
		local obj = C_Map.GetPlayerMapPosition(uiMapID,"player");
		if obj and obj.GetXY then
			x,y = obj:GetXY();
		end
	end
	if x and x>0 then
		FarmHud.TextFrame.coords:SetFormattedText("%.1f, %.1f",x*100,y*100);
	else
		FarmHud.TextFrame.coords:SetText("");
	end
end

function module.OnShow()
	if not FarmHudDB.coords_show then
		return
	end
	if coordsTicker==nil then
		coordsTicker = C_Timer.NewTicker(1/24,CoordsUpdate_TickerFunc);
	end
	FarmHud.TextFrame.coords:SetTextColor(unpack(FarmHudDB.coords_color));
	FarmHud.TextFrame.coords:Show()
end

function module.OnHide()
	if coordsTicker then
		coordsTicker:Cancel();
		coordsTicker=nil;
	end
	FarmHud.TextFrame.coords:Hide();
end

local _scaledHeight
function module.OnSetScales(enabled,scaledHeight)
	_scaledHeight = scaledHeight
	if not FarmHudDB.coords_show then
		return
	end
	local coords_y = scaledHeight * FarmHudDB.coords_radius
	if FarmHudDB.coords_bottom then coords_y = -coords_y end
	FarmHud.TextFrame.coords:ClearAllPoints()
	FarmHud.TextFrame.coords:SetPoint("CENTER",FarmHud,"CENTER",0,coords_y)
end

function module.OnLoad()
	-- create coords font string
	FarmHud.TextFrame.coords = FarmHud.TextFrame:CreateFontString(nil,"ARTWORK","FarmHudFont")
	FarmHud.TextFrame.coords:Hide()
end

-- function module.events.ADDON_LOADED() end

-- function module.events.PLAYER_LOGIN() end

local function updateOpts(key)
	if key=="coords_show" or key==true then
		FarmHud.TextFrame.coords:SetShown(FarmHudDB.coords_show and FarmHud:IsShown())
	end
	if not FarmHudDB.coords_show then
		return
	end
	if (key=="coords_radius" or key==true) and _scaledHeight then
		module.OnSetScales(nil,_scaledHeight)
	end
	if (key=="coords_bottom" or key==true) and _scaledHeight then
		module.OnSetScales(nil,_scaledHeight)
	end
	if key=="coords_color" or key==true then
		FarmHud.TextFrame.coords:SetTextColor(unpack(FarmHudDB.coords_color));
	end
end

local function opt(info,value,...)
	local key = info[#info];
	if value~=nil then
		-- set option
		if (...)~=nil then
			value = {value,...}
		end
		FarmHudDB[key] = value
		updateOpts(key)
		return
	end
	-- get option
	if type(FarmHudDB[key])=="table" then
		return unpack(FarmHudDB[key]);
	end
	return FarmHudDB[key]
end

local function resetColor()
	FarmHudDB.coords_color = CopyTable(module.dbDefaults.coords_color)
	updateOpts("coords_color")
end

local options = {
	coords = {
		type = "group", --order = 4,
		name = L["Coords"],
		get = opt, set = opt,
		args = {
			coords_show = {
				type = "toggle", order = 1, width="full",
				name = L["CoordsShow"], desc = L["CoordsShowDesc"]
			},

			positionOptions = {
				type = "group", order=10, inline = true,
				name = "|cff00aaff"..L["Position options"].."|r",
				args = {
					coords_radius = {
						type = "range", order = 2,
						name = L["ChangeRadius"], desc = L["ChangeRadiusDesc"],
						min = 0.1, max = 0.9, step=0.005, isPercent=true
					},
					coords_bottom = {
						type = "toggle", order = 3,
						name = L["CoordsBottom"], desc = L["CoordsBottomDesc"]
					},
				}
			},

			textOptions = {
				type = "group", order=20, inline = true,
				name = "|cff00aaff"..L["Text options"].."|r",
				args = {
					coords_textscale = {
						type = "range", order = 4, width="full",
						name = L["TextScale"], desc = L["TextScaleDesc"],
						min = 1, max = 2.5, step = 0.1, isPercent = true
					},
					coords_color = {
						type = "color", order = 5, hasAlpha = true,
						name = COLOR, desc = L["CoordsColorDesc"]
					},
					coords_resetcolor = {
						type = "execute", order = 6,
						name = L["ResetColor"], desc = L["CoordsColorResetDesc"],
						func = resetColor
					}
				}
			}
		}
	}
}

function module.AddOptions()
	return options
end

ns.modules["Coordinates"] = module;
