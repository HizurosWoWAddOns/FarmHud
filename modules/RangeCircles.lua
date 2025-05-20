
local addon,ns = ...;
local L = ns.L;

--[[
note: could be hide on indoor?

]]
local maxYards = 40/0.2047; -- calculate from 40 yards to max from percentage value of the heal circle; 195 yards
local hcScale = 0.2047; -- heal circle (40 yards)
local gcScale = {
	0.45, -- gathercircle default size.
	0.60, -- gathercircle increased 1th time (since dragonflight or with tww? i don't saw it while dragonflight).
		  -- (continent id 1978)
	0.80, -- gathercircle increased 2th time.
		  -- (continent id 2274 and higher/later)
}

local updateOptions
local module = {
	dbDefaults = {
		-- { <name|string>, <visible|bool>, <color|table>, <scale|int>, <thickness|int>, <lineScale|int>, <onMinimap|bool>
		{"GatherCircle",true,{0,1,0,0.35},false,2,1,true}, -- default circle
		{"HealCircle",true,{0,.7,1,0.35},false,2,1,true}, -- default circle
		{false,true,{1,1,1,0.5},0.5,2,1,false}, -- custom circle
	},
	OnShow = {frame="FarmHudRangeCircles",func="Update"},
	OnHide = {frame="FarmHudRangeCircles",func="Update"},
	Update = {frame="FarmHudRangeCircles",func="Update"},
	events = {}
}

local function UpdateCircle(parent,circleType,index,force)
	local label,scale,show,color,circle,thick,lineScale,onMinimap,_
	if circleType=="default" then
		local currentContinent = ns.GetContinentID() or 0;
		label,show,color,_,thick,lineScale,onMinimap = unpack(FarmHudDB.defaultCircles[index]);
		if index==1 then
			scale = gcScale[1];
			if currentContinent==1978 then
				scale = gcScale[2];
			elseif currentContinent>=2274 then
				scale = gcScale[3];
			end
		elseif index==2 then
			scale = hcScale;
		end
		if parent.CirclesDefault[index]==nil then
			parent.CirclesDefault[index] = CreateFrame("Frame",nil,parent,"FarmHudCircleLineTemplate")
		end
		circle = parent.CirclesDefault[index];
	elseif circleType=="custom" then
		label,show,color,scale,thick,lineScale,onMinimap = unpack(FarmHudDB.rangeCircles[index]);
		if parent.CirclesCustom[index]==nil then
			if #parent.CirclesCustomUnused>0 then
				tinsert(parent.CirclesCustom,tremove(parent.CirclesCustomUnused,1));
			else
				parent.CirclesCustom[index] = CreateFrame("Frame",nil,parent,"FarmHudCircleLineTemplate")
			end
		end
		circle = parent.CirclesCustom[index];
	end
	if parent.curentParent=="Minimap" and lineScale==1 then
		lineScale=2; -- too small on minimap
	end
	circle.info = {}
	circle.info.type = circleType
	circle.info.index = index
	circle.info.label = label
	circle.info.scale = scale
	circle.info.lineScale = lineScale;
	circle.info.color = color
	circle.info.thickness = thick or 1;
	circle.info.onMinimap = onMinimap;

	circle:UpdateDraw(force);
	local cParent = parent.currentParent
	circle:SetShown((cParent=="Minimap" and onMinimap) or (cParent=="FarmHud" and show));
	circle.dirty = nil
end

FarmHudRangeCirclesMixin = {}

function FarmHudRangeCirclesMixin:Update(...)
	self.currentParent=FarmHud:IsShown() and "FarmHud" or "Minimap";
	if self:GetParent()~=_G[self.currentParent] then
		self:SetParent(_G[self.currentParent])
		self:ClearAllPoints();
		self:SetPoint("CENTER")
	end

	local s = min(_G["Minimap"]:GetSize());
	self:SetSize(s*4,s*4); -- frame is scaled to 0.25. size must be multiplied. makes the lines a little bit smoother.

	local force = false;
	if self.lastSize ~= Minimap:GetWidth() then
		force = true;
	end
	if not self.CirclesDefault then
		self.CirclesDefault = {}
		self.CirclesCustom = {};
		self.CirclesCustomUnused = {};
	end
	for i=1, #self.CirclesCustom do
		self.CirclesCustom[i].dirty=true
	end
	for index=1, #FarmHudDB.defaultCircles do
		UpdateCircle(self,"default",index,force)
	end
	for index=1, #FarmHudDB.rangeCircles do
		UpdateCircle(self,"custom",index,force)
	end
	for i=#self.CirclesCustom, 1, -1 do
		if self.CirclesCustom[i].dirty then
			self.CirclesCustom[i]:Hide()
			tinsert(self.CirclesCustomUnused,tremove(self.CirclesCustom,i));
		end
	end
end
--[[
local circlesRotationTicker
local function circlesRotation_TickerFunc()
	for i,circle in ipairs(FarmHudRangeCircles.CirclesDefault) do
		circle:UpdatePos();
	end
	for i,circle in ipairs(FarmHudRangeCircles.CirclesCustom) do
		circle:UpdatePos();
	end
end

local function circlesRotationToggle(state)
	if not circlesRotationTicker and state~=false then
		circlesRotationTicker = C_Timer.NewTicker(1/24, circlesRotation_TickerFunc);
	elseif circlesRotationTicker and state==false then
		circlesRotationTicker:Cancel();
		circlesRotationTicker = nil;
	end
	if not GetPlayerFacing() then
		state = false;
	end
end

if true then
	circlesRotationToggle();
end
--]]
local function opt(info,value,...)
	local key = info[#info];
	local circleType,circleIndex = info[#info-1]:match("^(.+)_(%d+)$"); circleIndex=tonumber(circleIndex);
	local keyIndex = { CircleName=1, CircleShow=2, CircleColor=3, CircleYards=4, CircleLineThickness=5, CircleLineScale=6, CircleMinimap=7 };
	local tbl = FarmHudDB[circleType=="default" and "defaultCircles" or "rangeCircles"];

	if value~=nil then -- set
		if (...) then
			value = {value,...}
		end
		if keyIndex[key]==4 then
			value = value/maxYards; -- yards to scaling for internal use
		end
		tbl[circleIndex][keyIndex[key]] = value;
		updateOptions()
		FarmHudRangeCircles:Update()
		return
	end

	local result = tbl[circleIndex][keyIndex[key]];
	local defCircle = module.dbDefaults[circleType~="default" and 3 or circleIndex];

	if circleType and circleIndex and #tbl[circleIndex]~=#defCircle then
		-- different table size; add missing values
		for i=1, #defCircle do
			if tbl[circleIndex][i]==nil then
				tbl[circleIndex][i] = defCircle[i];
			end
		end
	end

	if keyIndex[key]==4 then
		result = result*maxYards; -- scaling to yards for user expectation
	end
	if type(result)=="table" then
		return unpack(result)
	end

	return result
end

local function func(info)
	local circleType,circleIndex = info[#info-1]:match("^(.+)_(%d+)$"); circleIndex=tonumber(circleIndex);
	if circleType=="circle" and info[#info]=="CircleDelete" and circleIndex and FarmHudDB.rangeCircles[circleIndex] then
		tremove(FarmHudDB.rangeCircles,circleIndex)
	elseif circleType=="default" and info[#info]=="CircleResetColor" then
		FarmHudDB.defaultCircles[circleIndex][3] = CopyTable(module.dbDefaults[circleIndex][3])
	end
	updateOptions();
	FarmHudRangeCircles:Update(true);
end

local options = {
	rangeCircles = {
		type = "group", order = 2,
		name = L["RangeCircles"],
		args = {
			welcome = {
				type = "description", fontSize = "large", order = 1,
				name = L["RangeCirclesWelcome"]
			},
			desc = {
				type = "description", fontSize = "medium", order = 2,
				name = L["RangeCirclesDesc"]
			},
			defaultCirclesHeader = {
				type="header", order = 3,
				name=DEFAULT, --L["RangeCirclesDefault"]
			},
			defaultCircles = {
				type = "group", order = 4, inline = true,
				name = "",
				get = opt,
				set = opt,
				func = func,
				args = {}
			},
			customCirclesHeader = {
				type="header", order = 5,
				name=CHANNEL_CATEGORY_CUSTOM or VIDEO_QUALITY_LABEL6, --L["RangeCirclesCustom"]
			},
			add_circle = {
				type = "execute", order = 6,
				name = ADD,
			},
			customCircles = {
				type = "group", order = 7, inline = true,
				name = "",
				get = opt,
				set = opt,
				func = func,
				args = {}
			}
		}
	}
}

local defaultCircleTpl = {
	type = "group", order = 0, inline=true,
	name = "",
	args = {
		CircleShow = {
			type = "toggle", order = 1,
			name = SHOW, desc = L["RangeCircleShowDesc"]
		},
		CircleMinimap = {
			type = "toggle", order = 2,
			name =  MINIMAP_LABEL --[[ L["RangeCircleShowOnMinimap"] ]], desc = L["RangeCircleShowOnMinimapDesc"]
		},
		--
		CircleColor = {
			type = "color", order = 3,
			name = COLOR, desc = L["RangeCircleColorDesc"],
			hasAlpha = true
		},
		CircleResetColor = {
			type = "execute", order = 4,
			name = L["ResetColor"], --desc = L["ResetColorDesc"]
		},
		--
		CircleLineThickness = {
			type = "range", order = 5, width = "double",
			name = L["RangeCircleLineThickness"], desc=L["RangeCircleLineThicknessDesc"],
			min=1, max=15, step=1,
		},
		--
		-- CircleLineScale = {
		-- 	type = "range", order = 6, hidden=true,
		-- 	name = L["RangeCircleLineScale"], desc = L["RangeCircleLineScaleDesc"],
		-- 	min=0.1, max=1, step=0.1, isPercent=true
		-- },
	}
}

local customCircleTpl = {
	type = "group", order = 0, inline=true,
	name = "",
	args = {
		CircleShow = CopyTable(defaultCircleTpl.args.CircleShow), -- order 1
		CircleMinimap = CopyTable(defaultCircleTpl.args.CircleMinimap), -- order 2
		--
		CircleColor = CopyTable(defaultCircleTpl.args.CircleColor), -- order 3
		CircleName = {
			type = "input", order = 4,
			name = NAME, desc = L["RangeCircleNameDesc"]
		},
		--
		CircleLineThickness = CopyTable(defaultCircleTpl.args.CircleLineThickness), -- order 5
		--
		CircleYards = {
			type = "range", order = 6, width = "double",
			name = L["Range"], desc = L["RangeCircleYardsDesc"],
			min=5, max=floor(maxYards), step=1
		},
		--
		--CircleLineScale = CopyTable(defaultCircleTpl.args.CircleLineScale), -- order 7
		--
		hidden_separator = {
			type = "description", order=-2, width="full", fontSize="large",
			name = " "
		},
		--
		CircleDelete = {
			type = "execute", order = -1,
			name = DELETE, desc = L["RangeCircleDeleteDesc"]
		},
	}
}

function updateOptions(oPrefix,oTbl,dbTbl,tpl)
	if not oTbl then
		if #options.rangeCircles.args.defaultCircles==0 then
			if FarmHudDB.defaultCircles==nil then
				ns:debugPrint("defaultCircles nil")
			end
			updateOptions(
				"default",
				options.rangeCircles.args.defaultCircles,
				FarmHudDB.defaultCircles,
				defaultCircleTpl
			)
		end
		if FarmHudDB.rangeCircles==nil then
			ns:debugPrint("rangeCircles nil")
		end
		updateOptions(
			"circle",
			options.rangeCircles.args.customCircles,
			FarmHudDB.rangeCircles,
			customCircleTpl
		)
		return;
	end
	wipe(oTbl.args);
	for i,v in ipairs(dbTbl) do
		oTbl.args[oPrefix.."_"..i] = CopyTable(tpl);
		oTbl.args[oPrefix.."_"..i].name = --[[ oPrefix=="default" and ]] L[v[1]] or v[1];
		oTbl.args[oPrefix.."_"..i].order = i + (oPrefix=="default" and 0 or 20);
	end
end

function options.rangeCircles.args.add_circle.func(info)
	local n = #FarmHudDB.rangeCircles + 1;
	local tmp = CopyTable(module.dbDefaults[3]); -- custom
	tmp[1] = (SELF_HIGHLIGHT_MODE_CIRCLE or L["Circle"]).." "..n;
	tinsert(FarmHudDB.rangeCircles,tmp)
	updateOptions();
	FarmHudRangeCircles:Update(true);
end

function module.AddOptions()
	return options
end

function module.events.PLAYER_LOGIN()
	if not FarmHudDB.defaultCircles then
		FarmHudDB.defaultCircles = {}
	end
	if not FarmHudDB.rangeCircles then
		FarmHudDB.rangeCircles = {}
	end
	if not FarmHudDB.defaultCircles[1] then
		FarmHudDB.defaultCircles[1] = CopyTable(module.dbDefaults[1]) -- gather
	elseif not FarmHudDB.defaultCircles[2] then
		FarmHudDB.defaultCircles[2] = CopyTable(module.dbDefaults[2]) -- heal
	end
	updateOptions()
	hooksecurefunc(FarmHud,"SetScales",function()
		FarmHudRangeCircles:Update(true)
	end)
	FarmHudRangeCircles:Update();
end

function module.events.PLAYER_ENTERING_WORLD()
	if FarmHud:IsVisible() then
		C_Timer.After(.3,function()
			FarmHudRangeCircles:Update();
		end);
	end
end

function module.events.ZONE_CHANGED()
	if not FarmHud.playerIsLoggedIn then return end
	FarmHudRangeCircles:Update()
end

-- need event on screen size changed...


--== Mixin for FarmHudCircleLineTemplate ==--

FarmHudCircleLineMixin = {}
FarmHudCircleLineMixin.info = {
	label = "dummy",
	steps = 48,
	color = {1,1,1,.3},
	scale = .5,
	lineScale = 1,
	thickness = 1,
};

local function GetRadiusAndSteps(self)
	-- radius is higher than screen size because the RangeCircles frame is scaled down to 25% to get a smoother line.
	local diameter = FarmHudRangeCircles:GetHeight();
	local radius = diameter/2*self.info.scale;

	-- calculate the number of lines to create the circle
	local Steps = floor(360/2*self.info.scale)
	local s = 48;
	Steps = (Steps<32 and 32) or (Steps<s and s) or floor(Steps/s)*s;
	local step = math.pi * 2 / Steps;

	return radius, Steps, step;
end

function FarmHudCircleLineMixin:UpdateDraw(force)
	-- create line pools
	if not self.linePool then
		self.linePool={};
	end

	-- flag all lines as dirty; used later to hide unused lines
	for i=1, #self.linePool do
		self.linePool[i].dirty=true;
	end

	local radius, Steps, step = GetRadiusAndSteps(self)
	local half_step = step*self.info.lineScale/2;

	-- check to update part of line
	local updateLine,updateThickness,updateColor = force or false,force or false,force or false;
	if self.linePool[1] then
		local line = self.linePool[1];
		if line.info.scale~=self.info.scale or line.info.steps~=Steps or line.info.lineScale~=self.info.lineScale then
			updateLine = true;
		end
		if line.info.thickness~=self.info.thickness then
			updateThickness = true;
		end
		local c1, c2,hex=line.info.color,self.info.color,"%02x";
		if hex:format(c1[1]*255,c1[2]*255,c1[3]*255)~=hex:format(c2[1]*255,c2[2]*255,c2[3]*255) then
			updateColor = true;
		end
	else
		updateLine,updateColor = true,true;
	end

	for i=0, Steps-1 do
		local lineIndex = i+1;
		local angle = i*step;
		-- get current line
		local forceUpdate,circleLine = false,self.linePool[lineIndex];
		if not circleLine then
			-- create new line
			circleLine = self:CreateLine();
			circleLine.info = {}
			tinsert(self.linePool,circleLine)
			forceUpdate = true;
		end
		-- check line is hidden (created but unused line)
		if circleLine and not circleLine:IsShown() then
			forceUpdate = true;
		end
		-- update circle line position
		if updateLine or forceUpdate then
			circleLine:SetStartPoint("CENTER", self, radius*math.cos(angle-half_step), radius*math.sin(angle-half_step));
			circleLine:SetEndPoint(  "CENTER", self, radius*math.cos(angle+half_step), radius*math.sin(angle+half_step));
			circleLine:Show();
			circleLine.info.steps = Steps;
			circleLine.info.scale = self.info.scale;
			circleLine.info.lineScale = self.info.lineScale;
		end
		-- update line thickness
		if updateThickness or forceUpdate then
			-- the line is 4 times thicker than visible because the parent frame is scaled down to 25% to get a smoother line.
			circleLine:SetThickness(4*self.info.thickness)
			circleLine.info.thickness = self.info.thickness;
		end
		-- update color of circle
		if updateColor or forceUpdate then
			circleLine:SetColorTexture(unpack(self.info.color))
			circleLine.info.color = self.info.color;
		end
		circleLine.dirty=nil;
	end

	-- hide not used lines
	local cHide = 0;
	for _,line in ipairs(self.linePool) do
		if line.dirty==true then
			--line:ClearAllPoints(); -- this function doesn't have any effect on line elements...
			--line:SetColorTexture(0,0,0,0)
			line:Hide();
			wipe(line.info)
			line.dirty=nil;
		end
	end
end

--[[
function FarmHudCircleLineMixin:UpdatePos()
	local rotateMiniMap = C_CVar.GetCVarBool("rotateMinimap");
	local facing = rotateMiniMap and GetPlayerFacing() or 0;
	if self.info.facing == facing then
		return;
	end
	local radius, Steps, step = GetRadiusAndSteps(self)
	for i=0, Steps-1 do
		local lineIndex = i+1;
		local angle = i*step-facing;
		-- get current line
		local circleLine = self.linePool[lineIndex];
		local half_step = step*self.info.lineScale/2;
		circleLine:SetStartPoint("CENTER", self, radius*math.cos(angle-half_step), radius*math.sin(angle-half_step));
		circleLine:SetEndPoint(  "CENTER", self, radius*math.cos(angle+half_step), radius*math.sin(angle+half_step));
	end
end
--]]

ns.modules["RangeCircles"] = module;
