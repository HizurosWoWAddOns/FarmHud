
local addon, ns = ...;
do
	local addon_short = "FH-TP";
	local colors = {"82c5ff","00ff00","ff6060","44ffff","ffff00","ff8800","ff44ff","ffffff"};
	local function colorize(...)
		local t,c,a1 = {tostringall(...)},1,...;
		if type(a1)=="boolean" then tremove(t,1); end
		if a1~=false then
			local header = "FarmHud (TrailPath)";
			if a1==true then
				header = addon_short;
			elseif a1=="||" then
				header = "||";
			elseif a1=="()" then
				header = header .. " (" ..t[2]..")";
				tremove(t,2);
				tremove(t,1);
			end
			tinsert(t,1,"|cff82c5ff"..header.."|r"..(a1~="||" and HEADER_COLON or ""));
			c=2;
		end
		for i=c, #t do
			if not t[i]:find("\124c") then
				t[i],c = "|cff"..colors[c]..t[i].."|r", c<#colors and c+1 or 1;
			end
		end
		return unpack(t);
	end
	function ns.print(...)
		print(colorize(...));
	end
end

local HBD = LibStub("HereBeDragons-2.0")
local HBDPins = LibStub("HereBeDragons-Pins-2.0")

local L = ns.L;
local pi2 = math.pi*2;
local media, media_blizz = "Interface\\AddOns\\FarmHud\\media\\", "Interface\\Minimap\\";
local minDistanceBetween = 12;
local trailPathActive,trailPathPool,lastX,lastY,lastM,lastFacing = {},{};
local trailPathIcons,trailPathTicker = { -- coords_pos = { <left>, <right>, <top>, <bottom>, <sizeW>, <sizeH> }
	-- arrows1.tga
	arrow01 = {file=media.."arrows1.tga",coords_pos={58,122, 64,128,  128,128},desaturated=true},
	arrow02 = {file=media.."arrows1.tga",coords_pos={69,98,  0,29,    128,128},desaturated=true},
	arrow03 = {file=media.."arrows1.tga",coords_pos={39,54,  30,45,   128,128},desaturated=true},
	arrow04 = {file=media.."arrows1.tga",coords_pos={18,33,  107,125, 128,128},desaturated=true},
	arrow05 = {file=media.."arrows1.tga",coords_pos={74,105, 29,59,   128,128},desaturated=false},
	arrow06 = {file=media.."arrows1.tga",coords_pos={34,57,  68,91,   128,128},desaturated=false},

	--
	dot01 = {file=media.."playerDot-white.tga",coords={0.2,0.8,0.2,0.8}},
	dot02 = {file="interface/Challenges/challenges-metalglow",coords={0.2,0.8,0.2,0.8},desaturated=true},

	--
	ring1 = {file="interface/COMMON/portrait-ring-withbg-highlight",coords={0.2,0.8,0.2,0.8},desaturated=true},
	ring2 = {file="interface/Calendar/EventNotificationGlow",desaturated=true,mode="ADD"},

	--== ideas for other icons to use as trail pin icon? ==--
	-- hexagon = {"interface/ARCHEOLOGY/Arch-Keystone-Mask",coords},
	-- /Animations/PowerSwirlAnimation ( atlas entries )
	-- /Azerite/Azerite ( atlas entry + adjustments )
	-- /Artifacts/Artifacts ( atlas entry + adjustments )
	-- /ARCHEOLOGY/Arch-Keystone-Mask
	-- /BUTTONS/Arrow-Up-Down ( desaturated )
	-- /COMMON/ReputationStar
	-- /COMMON/common-mask-diamond
	-- /Challenges/challenges-metalglow
	-- /ENCOUNTERJOURNAL/UI-EJ-Icons
	-- /FriendsFrame/UI-Toast-ToastIcons
	-- /GLUES/LOGIN/UI-BackArrow
	-- /GLUES/Models/UI_BloodElf/BloodElfFemaleEyeGlowGreenGuard
	-- /GLUES/Models/UI_DarkIronDwarf/T_VFX_Glow01_64
	-- /GUILDFRAME/Communities
	-- /Garrison/GarrisonBuildingUI
	-- /Garrison/GarrisonMissionUI1
	-- /Garrison/OrderHallTalents
	-- /LootFrame/LootToastAtlas
	-- /MINIMAP/ObjectIconsAtlas
	-- /PETBATTLES/PetBattle-StatIcons
	-- /PLAYERFRAME/PALADINPOWERTEXTURES
	-- /SPELLBOOK/GlyphIconSpellbook
	-- /Store/Services

	--== trailPath pin icons by LibSharedMedia? maybe later...
}
local TrailPathIconValues = {
	arrow01 = L["Arrow 1"],
	arrow02 = L["Arrow 2"],
	arrow03 = L["Arrow 3"],
	arrow04 = L["Arrow 4"],
	arrow05 = L["Arrow 5"],
	arrow06 = L["Arrow 6"],
	dot01 = L["Dot 1"],
	dot02 = L["Dot 2"],
	ring1 = L["Ring 1"],
	ring2 = L["Ring 2"],
}
FarmHudTrailPathPinMixin = {}

function FarmHudTrailPathPinMixin:UpdatePin(facing,pinIcon,scale)
	-- facing
	if facing and IsOpened then
		if rotationMode == "0" then
			facing = self.info.f;
		else
			facing = -(facing-self.info.f);
		end
		self.pin.Facing.Rotate :SetRadians(facing);
	end
	-- texture
	if self.info.currentPinIcon ~= pinIcon then
		local icon = trailPathIcons[pinIcon];
		if icon then
			self.pin.icon :SetTexture(icon.file)
			if not icon.coords then
				icon.coords = {0,1,0,1};
			end
			self.pin.icon :SetTexCoord(unpack(icon.coords));
			self.pin.icon :SetDesaturated(icon.desaturated==true)
			self.pin.icon :SetBlendMode(icon.mode or "BLEND");
			self.info.currentPinIcon = pinIcon
		end
	end
	-- scaling
	if self.info.currentPinScale~=scale then
		self.pin :SetScale(scale);
		self.info.currentPinScale = scale;
	end
	-- color
	if self.info.currentPinColor1~=FarmHudDB.trailPathColor1 then
		self.pin.icon :SetVertexColor(unpack(FarmHudDB.trailPathColor1))
		self.info.currentPinColor1 = FarmHudDB.trailPathColor1;
	end
end

function FarmHudTrailPathPinMixin:EnableMouse()
	-- dummy
end

local function GetMicrotime()
	return ceil(GetTime()*100);
end

local function TrailPath_TickerFunc()
	local x,y,instance = HBD :GetPlayerWorldPosition();

	local currentFacing = GetPlayerFacing() or 0; -- 0 - 6.5

	if x and y and instance then
		if lastX and lastY and lastM==instance then
			local a, distance = HBD :GetWorldVector(instance,lastX,lastY,x,y);
			if distance < minDistanceBetween then
				x,y = nil,nil;
				if currentFacing then
					trailPathActive[1].info.f = currentFacing;
				end
			end
		end
	end

	if x and y and instance then
		local entry,new = trailPathPool[1],false;
		if not entry then
			entry = CreateFrame("Frame",nil,FarmHud,"FarmHudTrailPathPinTemplate");
			entry.info = {};
			entry.pin.Facing:Play();
			new = true;
		end

		lastX,lastY,lastM = x,y,instance;
		entry.info.map = instance;
		entry.info.x = x;
		entry.info.y = y;
		entry.info.f = currentFacing;
		entry.info.t = GetMicrotime();
		HBDPins:AddMinimapIconWorld(FarmHud, entry, instance, x, y );
		tinsert(trailPathActive,1,entry);
		if not new then
			tremove(trailPathPool,1);
		end
	end

	if #trailPathActive>0 then
		local currentScale,currentPinIcon = FarmHudDB.trailPathScale;
		local currentTime = GetMicrotime();
		local IsOnCluster = trailPathActive[1] :GetParent()~=Minimap;
		if IsOnCluster then
			if FarmHudDB.rotation then
				currentPinIcon = FarmHudDB.trailPathIcon or "arrow01";
			else
				currentPinIcon = "dot02";
			end
			IsOpened = true;
		else
			currentPinIcon = "dot02"
			currentScale = 0.7;
			IsOpened = false;
		end
		for i=#trailPathActive, 1, -1 do
			local v = trailPathActive[i];
			if i>1 and (i>FarmHudDB.trailPathCount or (v.info.t and currentTime-v.info.t>(FarmHudDB.trailPathTimeout*100))) then
				HBDPins:RemoveMinimapIcon(FarmHud,v);
				wipe(v.info);
				tinsert(trailPathPool,v);
				tremove(trailPathActive,i);
			else
				if i==1 then
					trailPathActive[i].info.t = currentTime;
				end
				trailPathActive[i]:UpdatePin(currentFacing,currentPinIcon,currentScale);
			end
		end
	end
end

local function UpdateTrailPath(force)
	if force==nil then
		force = FarmHudDB.trailPathShow;
	end
	if force==true and trailPathTicker==nil then
		trailPathTicker = C_Timer.NewTicker(0.5,TrailPath_TickerFunc);
	elseif force==false and trailPathTicker then
		trailPathTicker:Cancel();
		trailPathTicker = nil;
		for i,v in ipairs(FarmHud.TrailPathPool)do
			v:Hide();
		end
	end
end

local module = {};

module.dbDefaults = {
	trailPathShow = true, trailPathCount = 32, trailPathTimeout = 60, trailPathIcon = "arrow01", trailPathColor1 = {1,.2,.2,1,.75}, trailPathScale = 1,
};

function module.AddOptions()
	return {
		trial = {
			type = "group", --order = 9,
			name = L["TrailPath"],
			args = {
				trailPathShow = {
					type = "toggle", order = 0, width = "full",
					name = L["TrailPathShow"]
				},
				trailPathCount = {
					type = "range", order = 1,
					name = L["TrailPathCount"], desc = L["TrailPathCountDesc"],
					min = 10, step = 1, max = 64,
				},
				trailPathTimeout = {
					type = "range", order = 2,
					name = L["TrailPathTimeout"], desc = L["TrailPathTimeoutDesc"],
					min = 10, step = 10, max = 600,
				},
				-- TODO: header ?
				trailPathIcon = {
					type = "select", order = 4,
					name = L["TrailPathIcon"], desc = L["TrailPathIconDesc"],
					values = TrailPathIconValues
				},
				trailPathScale = {
					type = "range", order = 5,
					name = L["TrailPathScale"], desc = L["TrailPathScaleDesc"],
					min=0.1, step=0.1, max=1, isPercent = true
				},
				-- TODO: Little description for LibSharedMedia support... maybe later?
				--[[
				trailPathColorMode = {
					type = "select", order = 5,
					name = L["TrailPathColorMode"],
					values = {
						-- single
						-- 2 colors
						-- 3 colors
					}
				},
				]]
				trailPathColor1 = {
					type = "color", order = 6,
					name = COLOR, desc = L["TrailPathColorsDesc"],
					hasAlpha = true,
					hidden = false -- function to check color mode
				},
				--[[
				trailPathColor2 = {
					type = "color", order = 6,
					name = COLOR.." 2", desc = L["TrailPathColorsDesc"],
					hidden = false -- function to check color mode
				},
				trailPathColor3 = {
					type = "color", order = 6,
					name = COLOR.." 2", desc = L["TrailPathColorsDesc"],
					hidden = false -- function to check color mode
				},
				]]
			}
		}
	};
end

-- function module.OnShow() end

-- function module.OnHide() end

-- function module.<eventName>(...) end

function module.UpdateOptions(key,value)
	if key=="trailPathShow" then
		UpdateTrailPath(value);
	end
end

function module.PLAYER_ENTERING_WORLD()
	if IsInInstance() then
		UpdateTrailPath(false)
	else
		UpdateTrailPath()
	end
end

function module.OnLoad()
	-- prepare trailPathIcons texture coords from coords_pos entries
	FarmHud.UpdateTrailPath = UpdateTrailPath;

	for key, value in pairs(trailPathIcons)do
		if value.coords_pos then
			if not value.coords then
				value.coords = {0,1,0,1};
			end
			for i, pos in ipairs(value.coords_pos)do
				if i>4 then break; end
				if pos>1 then
					value.coords[i] = pos/value.coords_pos[i<=2 and 5 or 6];
				end
			end
		end
	end

	UpdateTrailPath();
end

FarmHud:RegisterModule("TrailPath",module)


--[[
	known problems:
		- sometimes icons disappear on turn off famrhud. invisible not removed.
]]
