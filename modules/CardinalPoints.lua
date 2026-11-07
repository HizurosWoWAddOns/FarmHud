
local addon,ns = ...;
local L = ns.L;
local cardinalTicker;

local points,cp = {"N","NE","E","SE","S","SW","W","NW"},{}
local module = {
	dbDefaults={
		cardinalpoints_show=true,
		cardinalpoints_color1={1,0.82,0,0.7},
		cardinalpoints_color2={1,0.82,0,0.7},
		cardinalpoints_radius=0.47,
		cardinalpoints_gathercircle_bind = false,
		cardinalpoints_gathercircle_pos = "inside",
		cardinalpoints_gathercircle_distance = 10,
		cardinalpoints_textscale = 1,
	},
	events = {},
	OnShow = nil,
	OnHide = nil,
	OnLoad = nil,
	OnSetScale = nil,
	AddOptions = nil,
}

local function CardinalPointsUpdate_TickerFunc()
	local bearing, scaledRadius = GetPlayerFacing()

	if not bearing then
		-- zones without access on player facing. mostly in dungeons and raids.
		return
	end

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

	for _, point in ipairs(cp.points) do
		point:ClearAllPoints();
		point:SetPoint("CENTER", FarmHud, "CENTER", math.sin(point.rot+bearing)*scaledRadius, math.cos(point.rot+bearing)*scaledRadius);
	end
end

function module.OnShow()
	if not FarmHudDB.cardinalpoints_show then
		return
	end
	local r1,g1,b1,a1 = unpack(FarmHudDB.cardinalpoints_color1)
	local r2,g2,b2,a2 = unpack(FarmHudDB.cardinalpoints_color2)
	for _, point in ipairs(cp.points) do
		if point.NWSE then
			point:SetTextColor(r1,g1,b1,a1);
		else
			point:SetTextColor(r2,g2,b2,a2);
		end
	end
	if not cardinalTicker then
		cardinalTicker = C_Timer.NewTicker(1/24, CardinalPointsUpdate_TickerFunc);
	end
	cp:Show()
	ns:debug("<cp>","<OnShow>",cp.points[1]:IsShown(),cp:IsShown())
end

function module.OnHide()
	if cardinalTicker then
		cardinalTicker:Cancel();
		cardinalTicker = nil;
	end
	cp:Hide()
end

function module.OnSetScales(enabled,scaledHeight)
	cp.ScaledHeight = scaledHeight
end

function module.OnLoad()
	-- create cardinal points
	cp = CreateFrame("Frame",nil,FarmHud)
	FarmHud.CardinalPoints = cp
	cp:SetSize(1,1)
	cp:SetPoint("CENTER")
	cp:Hide();
	cp.points = {}
	for i,pointLetter in ipairs(points)do
		local point = cp:CreateFontString(nil,"ARTWORK","FarmHudFont")
		point.key = pointLetter
		point.NWSE = strlen(pointLetter)==1
		point.rot = (math.pi / 4 * (i-1))
		point:SetText(L[pointLetter])
		point:Show()
		tinsert(cp.points,point)
	end
end

-- function module.events.PLAYER_LOGIN() end

-- function module.events.PLAYER_LOGIN() end

local function updateVisibility()
	ns:debug("<cp>","<updateVisibility>")
	-- for entering zones with disabled player facing
	if not FarmHud:IsShown() then
		if cardinalTicker then
			module.OnHide()
		end
		return
	end
	local state = FarmHudDB.cardinalpoints_show
	if not GetPlayerFacing() then
		state = false
	end
	module[state and "OnShow" or "OnHide"]();
end

module.events.PLAYER_ENTERING_WORLD = updateVisibility
module.events.ZONE_CHANGED = updateVisibility

local function updateOpts(key)
	if key=="cardinalpoints_show" and FarmHud:IsShown() then
		module[FarmHudDB[key] and "OnShow" or "OnHide"]()
	end
	if key=="cardinalpoints_color1" then
		local r,g,b,a = unpack(FarmHudDB.cardinalpoints_color1)
		for _, point in ipairs(cp.points)do
			if point.NWSE then
				point:SetTextColor(r,g,b,a)
			end
		end
	end
	if key=="cardinalpoints_color2" then
		local r,g,b,a = unpack(FarmHudDB.cardinalpoints_color2)
		for _, point in ipairs(cp.points)do
			if not point.NWSE then
				point:SetTextColor(r,g,b,a)
			end
		end
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

local function resetColor(info)
	local key = info[#info]:gsub("reset","")
	FarmHudDB[key] = CopyTable(module.dbDefaults[key])
	updateOpts(key)
end

local options = {
	cardinalpoints = {
		type = "group", --order = 3,
		name = L["CardinalPoints"],
		get=opt, set=opt,
		args = {
			cardinalpoints_show = {
				type = "toggle", order = 1, width = "double",
				name = L["CardinalPointsShow"], desc = L["CardinalPointsShowDesc"],
			},
			positionOptions = {
				type = "group", order=10, inline = true,
				name = L["Position options"],
				args = {
					cardinalpoints_gathercircle_bind = {
						type = "toggle", order = 1, width = "full",
						name = L["CardinalPointsGatherCircleBind"], desc = L["CardinalPointsGatherCircleBindDesc"]
					},
					cardinalpoints_radius = {
						type = "range", order = 2, width = "double",
						name = L["ChangeRadius"], desc = L["ChangeRadiusDesc"],
						min = 0.1, max = 0.95, step=0.005, isPercent=true,
						disabled = function() return FarmHudDB.cardinalpoints_gathercircle_bind; end
					},
					cardinalpoints_gathercircle_pos = {
						type = "select", order = 3,
						name = L["CardinalPointsGatherCirclePos"], desc = L["CardinalPointsGatherCirclePosDesc"],
						values = {
							inside = L["CardinalPointsInside"],
							outside = L["CardinalPointsOutside"]
						},
						disabled = function() return not FarmHudDB.cardinalpoints_gathercircle_bind; end
					},
					cardinalpoints_gathercircle_distance = {
						type = "range", order = 4,
						name = L["CardinalPointsGatherCircleDistance"], desc = L["CardinalPointsGatherCircleDistanceDesc"],
						min = 10, max = 100, step=2,
						disabled = function() return not FarmHudDB.cardinalpoints_gathercircle_bind; end
					},

				}
			},
			textOptions = {
				type = "group", order=20, inline = true,
				name = L["Text options"],
				args = {
					cardinalpoints_textscale = {
						type = "range", order = 1, width="full",
						name = L["TextScale"], desc = L["TextScaleDesc"],
						min = 1, max = 2.5, step = 0.1, isPercent = true
					},
					cardinalpoints_header1 = {
						type = "header", order = 10,
						name = L["CardinalPointsGroup1"]
					},
					cardinalpoints_color1 = {
						type = "color", order = 11, hasAlpha = true,
						name = COLOR, desc = L["CardinalPointsColorDesc"]:format(L["CardinalPointsGroup1"])
					},
					cardinalpoints_resetcolor1 = {
						type = "execute", order = 12,
						name = L["ResetColor"], desc = L["CardinalPointsColorResetDesc"]:format(L["CardinalPointsGroup1"]),
						func = resetColor
					},
					cardinalpoints_header2 = {
						type = "header", order = 20,
						name = L["CardinalPointsGroup2"]
					},
					cardinalpoints_color2 = {
						type = "color", order = 21, hasAlpha = true,
						name = COLOR, desc = L["CardinalPointsColorDesc"]:format(L["CardinalPointsGroup2"])
					},
					cardinalpoints_resetcolor2 = {
						type = "execute", order = 22,
						name = L["ResetColor"], desc = L["CardinalPointsColorResetDesc"]:format(L["CardinalPointsGroup2"]),
						func = resetColor
					}
				}
			},

		}
	},
}

function module.AddOptions()
	return options
end

ns.modules["CardinalPoints"] = module;
