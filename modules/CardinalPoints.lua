
local addon,ns = ...;
local L = ns.L;
local cardinalTicker;

local points,cp = {"N","NE","E","SE","S","SW","W","NW"}
local module = {
	dbDefaults={
		cardinalpoints_show=true,
		cardinalpoints_color1={1,0.82,0,0.7},
		cardinalpoints_color2={1,0.82,0,0.7},
		cardinalpoints_radius=0.47,
		cardinalpoints_gathercircle_bind = false,
		cardinalpoints_gathercircle_pos = "inside",
		cardinalpoints_gathercircle_distance = 10,
	},
	events = {},
	OnShow = nil,
	OnHide = nil,
	OnLoad = nil,
	OnSetScales = nil,
}

local function CardinalPointsUpdate_TickerFunc()
	local bearing = GetPlayerFacing();
	local scaledRadius;

	if FarmHudDB.cardinalpoints_gathercircle_bind then
		local lp,radius,_ = FarmHudRangeCircles.CirclesDefault[1].linePool,nil,nil; -- gather circle
		_,_,radius = lp[#lp-1]:GetEndPoint()
		local distance = FarmHudDB.cardinalpoints_gathercircle_distance;
		if FarmHudDB.cardinalpoints_gathercircle_pos=="inside" then
			distance = -distance;
		end
		scaledRadius = radius * 0.925 + distance;
	else
		scaledRadius = cp.ScaledHeight * FarmHudDB.cardinalpoints_radius;
	end

	for i=1, #cp.points do
		local p = cp.points[i];
		p:ClearAllPoints();
		if bearing then
			p:SetPoint("CENTER", FarmHud, "CENTER", math.sin(p.rot+bearing)*scaledRadius, math.cos(p.rot+bearing)*scaledRadius);
		end
		-- cardinal points disappearing in zones without access on player facing. mostly in dungeons and raids.
	end
end

local function ToggleCardicalPoints(state)
	if FarmHudDB.cardinalpoints_show then
		if not cardinalTicker and state~=false then
			cardinalTicker = C_Timer.NewTicker(1/24, CardinalPointsUpdate_TickerFunc);
		elseif cardinalTicker and state==false then
			cardinalTicker:Cancel();
			cardinalTicker = nil;
		end
		if not GetPlayerFacing() then
			state = false;
		end
		for i,e in ipairs(cp.points) do
			e:SetShown(state);
		end
	else
		if cardinalTicker then
			cardinalTicker:Cancel();
			cardinalTicker = nil;
		end
		for i,e in ipairs(cp.points) do
			e:SetShown(false);
		end
	end
end

function module.OnShow()
	ToggleCardicalPoints(true)
end

function module.OnHide()
	ToggleCardicalPoints(false)
end

function module.OnSetScales(enabled,scaledHeight)
	cp.ScaledHeight = scaledHeight
end

function module.OnLoad()
	cp = CreateFrame("Frame",nil,FarmHud)
	FarmHud.CardinalPoints = cp
	cp:SetSize(1,1)
	cp:SetPoint("CENTER")
	cp.points = {}
	for i,p in ipairs(points)do
		local P = cp:CreateFontString(nil,"ARTWORK","FarmHudFont")
		P:SetText(p)
		P.key = p
		P.NWSE = strlen(p)==1
		P.rot = (math.pi / 4 * (i-1))
		P:SetText(L[p])
		P:SetTextColor(1.0,0.82,0)
		tinsert(cp.points,P)
	end
end

function module.events.ADDON_LOADED()
	if not cp then
		return
	end
	for _,p in ipairs(cp.points)do
		if p.NWSE then
			p:SetTextColor(unpack(FarmHudDB.cardinalpoints_color1));
		else
			p:SetTextColor(unpack(FarmHudDB.cardinalpoints_color2));
		end
	end
end

--function module.events.PLAYER_LOGIN() end

local function opt(info,value,...)
	local key = info[#info];
	if value~=nil then
		if (...)~=nil then
			value = {value,...}
		end
		FarmHudDB[key] = value
		if key=="cardinalpoints_show" then
			ToggleCardicalPoints(FarmHud:IsShown())
		end
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
				type = "range", order = 3, width = "double",
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
			cardinalpoints_gathercircle_distance = {
				type = "range", order = 5,
				name = L["CardinalPointsGatherCircleDistance"], desc = L["CardinalPointsGatherCircleDistanceDesc"],
				min = 10, max = 100, step=2,
				disabled = function() return not FarmHudDB.cardinalpoints_gathercircle_bind; end
			},
			cardinalpoints_header1 = {
				type = "header", order = 6,
				name = L["CardinalPointsGroup1"]
			},
			cardinalpoints_color1 = {
				type = "color", order = 7, hasAlpha = true,
				name = COLOR, desc = L["CardinalPointsColorDesc"]:format(L["CardinalPointsGroup1"])
			},
			cardinalpoints_resetcolor1 = {
				type = "execute", order = 8,
				name = L["ResetColor"], desc = L["CardinalPointsColorResetDesc"]:format(L["CardinalPointsGroup1"])
			},
			cardinalpoints_header2 = {
				type = "header", order = 9,
				name = L["CardinalPointsGroup2"]
			},
			cardinalpoints_color2 = {
				type = "color", order = 10, hasAlpha = true,
				name = COLOR, desc = L["CardinalPointsColorDesc"]:format(L["CardinalPointsGroup2"])
			},
			cardinalpoints_resetcolor2 = {
				type = "execute", order = 11,
				name = L["ResetColor"], desc = L["CardinalPointsColorResetDesc"]:format(L["CardinalPointsGroup2"])
			}
		}
	},
}

function module.AddOptions()
	return options
end

ns.modules["CardinalPoints"] = module;
