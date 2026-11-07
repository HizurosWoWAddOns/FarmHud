
local addon,ns = ...;
local L = ns.L;
local timeTicker
local module = {
	dbDefaults={
		time_show=true,
		time_server=true,
		time_local=true,
		time_radius=0.48,
		time_bottom=false,
		time_color={1,0.82,0,0.7},
		time_textscale = 1,
	},
	events = {},
	OnShow = nil,
	OnHide = nil,
	OnLoad = nil,
	OnSetScale = nil,
	AddOptions = nil,
}

local function TimeUpdate_TickerFunc()
	local timeStr = {};
	if FarmHudDB.time_server then
		local h,m = GetGameTime();
		tinsert(timeStr,string.format("%d:%02d",h,m)); -- realm time
	end
	if FarmHudDB.time_local then
		tinsert(timeStr,date("%H:%M")); -- local time
		if #timeStr==2 then
			timeStr[1] = "R: "..timeStr[1];
			timeStr[2] = "L: "..timeStr[2];
		end
	end
	FarmHud.TextFrame.time:SetText(table.concat(timeStr," / "));
end

function module.OnShow()
	if not FarmHudDB.time_show then
		return
	end
	if timeTicker==nil then
		timeTicker = C_Timer.NewTicker(1/24,TimeUpdate_TickerFunc);
	end
	FarmHud.TextFrame.time:SetTextColor(unpack(FarmHudDB.time_color));
	FarmHud.TextFrame.time:SetTextScale(FarmHudDB.time_textscale)
	FarmHud.TextFrame.time:Show();
end

function module.OnHide()
	if timeTicker then
		timeTicker:Cancel();
		timeTicker=nil;
	end
	FarmHud.TextFrame.time:Hide();
end

function module.OnSetScales()
	FarmHud.TextFrame.time:SetPoint("CENTER",FarmHud,"CENTER",0,ns.calcDistance(FarmHudDB.time_radius,FarmHudDB.time_bottom));
end

function module.OnLoad()
	-- create time font string
	FarmHud.TextFrame.time = FarmHud.TextFrame:CreateFontString(nil,"ARTWORK","FarmHudFont")
	FarmHud.TextFrame.time:Hide()
end

-- function module.events.ADDON_LOADED() end

-- function module.events.PLAYER_LOGIN() end

local function updateOpts(key)
	if key=="time_show" then
		FarmHud.TextFrame.time:SetShown(FarmHudDB.time_show and FarmHud:IsShown())
	end
	if key=="time_radius" then
		module.OnSetScales()
	end
	if key=="time_bottom" then
		module.OnSetScales()
	end
	if key=="time_color" then
		FarmHud.TextFrame.time:SetTextColor(unpack(FarmHudDB.time_color));
	end
	if key=="time_textscale" then
		FarmHud.TextFrame.time:SetTextScale(FarmHudDB.time_textscale)
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
	FarmHudDB.time_color = CopyTable(module.dbDefaults.time_color)
	updateOpts("time_color")
end

local options = {
	time = {
		type = "group", --order = 5,
		name = L["Time"],
		get = opt, set = opt,
		args = {
			time_show = {
				type = "toggle", order = 1, width = "full",
				name = L["TimeShow"], desc = L["TimeShowDesc"]
			},
			positionOptions = {
				type = "group", order=10, inline = true,
				name = L["Position options"],
				args = {
					time_radius = {
						type = "range", order = 1, width = "double",
						name = L["ChangeRadius"], desc = L["ChangeRadiusDesc"],
						min = 0.1, max = 0.95, step=0.01, isPercent=true
					},
					time_bottom = {
						type = "toggle", order = 2, width = "double",
						name = L["TimeBottom"], desc = L["TimeBottomDesc"]
					},
				}
			},

			textOptions = {
				type = "group", order=20, inline = true,
				name = L["Text options"],
				args = {
					time_server = {
						type = "toggle", order = 1,
						name = L["TimeServer"], desc = L["TimeServerDesc"]
					},
					time_local = {
						type = "toggle", order = 2,
						name = L["TimeLocal"], desc = L["TimeLocalDesc"]
					},

					time_textscale = {
						type = "range", order = 3, width="full",
						name = L["TextScale"], desc = L["TextScaleDesc"],
						min = 1, max = 2.5, step = 0.1, isPercent = true
					},
					time_color = {
						type = "color", order = 4, hasAlpha = true,
						name = COLOR, desc = L["TimeColorDesc"]
					},
					time_resetcolor = {
						type = "execute", order = 5,
						name = L["ResetColor"], desc = L["TimeColorResetDesc"],
						func = resetColor
					},
				}
			}
		}
	}
}

function module.AddOptions()
	return options
end

ns.modules["Time"] = module;
