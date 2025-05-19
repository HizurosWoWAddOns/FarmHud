
local addon,ns = ...;
local L = ns.L;
local cardinalTicker;

local module = {
	dbDefaults={
		cardinalpoints_show=true,
		cardinalpoints_color1={1,0.82,0,0.7},
		cardinalpoints_color2={1,0.82,0,0.7},
		cardinalpoints_radius=0.47,
		cardinalpoints_gathercircle_bind = false,
		cardinalpoints_gathercircle_pos = "inside",
	},
	events = {},
	OnShow = nil,
	OnHide = nil
}


local function CardinalPointsUpdate_TickerFunc()
	local bearing = GetPlayerFacing();
	local scaledRadius = FarmHud.TextFrame.ScaledHeight * FarmHudDB.cardinalpoints_radius;
	for i=1, #FarmHud.TextFrame.cardinalPoints do
		local cp = FarmHud.TextFrame.cardinalPoints[i];
		cp:ClearAllPoints();
		if bearing then
			cp:SetPoint("CENTER", FarmHud, "CENTER", math.sin(cp.rot+bearing)*scaledRadius, math.cos(cp.rot+bearing)*scaledRadius);
		end
	end
end

function module.ToggleCardicalPoints(state)
	if not cardinalTicker and state~=false then
		cardinalTicker = C_Timer.NewTicker(1/24, CardinalPointsUpdate_TickerFunc);
	elseif cardinalTicker and state==false then
		cardinalTicker:Cancel();
		cardinalTicker = nil;
	end
	if not GetPlayerFacing() then
		state = false;
	end
	for i,e in ipairs(FarmHud.TextFrame.cardinalPoints) do
		e:SetShown(state);
	end
end

function module.OnShow()
	module.ToggleCardicalPoints(true)
end

function module.OnHide()
	module.ToggleCardicalPoints(false)
end

local function opt(info,value,...)
	local key = info[#info];
	if value~=nil then
		if (...)~=nil then
			value = {value,...}
		end
		FarmHudDB[key] = value
	end
	if type(FarmHudDB[key])=="table" then
		return unpack(FarmHudDB[key]);
	end
	return FarmHudDB[key]
end

local options = {
	cardinalpoints = {
		type = "group", order = 3,
		name = L["CardinalPoints"],
		get=opt,set=opt,
		args = {
			cardinalpoints_show = {
				type = "toggle", order = 1, width = "double",
				name = L["CardinalPointsShow"], desc = L["CardinalPointsShowDesc"],
			},
			cardinalpoints_gathercircle_bind = {
				type = "toggle", order = 2, width = "full",
				name = L["CardinalPointsGatherCircleBind"], desc = L["CardinalPointsGatherCircleBindDesc"]
			},
			cardinalpoints_radius = {
				type = "range", order = 3,
				name = L["ChangeRadius"], desc = L["ChangeRadiusDesc"],
				min = 0.1, max = 0.95, step=0.005, isPercent=true,
				disabled = function() return FarmHudDB.cardinalpoints_gathercircle_bind; end
			},
			cardinalpoints_gathercircle_pos = {
				type = "select", order = 4,
				name = L["CardinalPointsGatherCirclePos"], desc = L["CardinalPointsGatherCirclePosDesc"],
				values = {
					inside = L["CardinalPointsInside"],
					outside = L["CardinalPointsOutside"]
				},
				disabled = function() return not FarmHudDB.cardinalpoints_gathercircle_bind; end
			},
			cardinalpoints_header1 = {
				type = "header", order = 5,
				name = L["CardinalPointsGroup1"]
			},
			cardinalpoints_color1 = {
				type = "color", order = 6, hasAlpha = true,
				name = COLOR, desc = L["CardinalPointsColorDesc"]:format(L["CardinalPointsGroup1"])
			},
			cardinalpoints_resetcolor1 = {
				type = "execute", order = 7,
				name = L["ResetColor"], desc = L["CardinalPointsColorResetDesc"]:format(L["CardinalPointsGroup1"])
			},
			cardinalpoints_header2 = {
				type = "header", order = 8,
				name = L["CardinalPointsGroup2"]
			},
			cardinalpoints_color2 = {
				type = "color", order = 9, hasAlpha = true,
				name = COLOR, desc = L["CardinalPointsColorDesc"]:format(L["CardinalPointsGroup2"])
			},
			cardinalpoints_resetcolor2 = {
				type = "execute", order = 10,
				name = L["ResetColor"], desc = L["CardinalPointsColorResetDesc"]:format(L["CardinalPointsGroup2"])
			}
		}
	},
}

function module.AddOptions()
	return options
end

--function module.events.ADDON_LOADED() end

function module.events.PLAYER_LOGIN()
	--FarmHud:UpdateCardinalPoints();
	for k,v in pairs(module.dbDefaults)do
		if FarmHudDB[k]==nil then
			FarmHudDB[k] = CopyTable(module.dbDefaults);
		end
	end
end

ns.modules["CardinalPoints"] = module;
