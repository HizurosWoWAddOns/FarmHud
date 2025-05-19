
local addon, ns = ...;
local L = ns.L;
--LibStub("HizurosSharedTools").RegisterPrint(ns,addon,"FH/TP");

local HBD = LibStub("HereBeDragons-2.0")
local HBDPins = LibStub("HereBeDragons-Pins-2.0")

local EnableMouse, SetShown
local media = "Interface\\AddOns\\FarmHud\\media\\";
local minDistanceBetween = 12;
local trailPathActive,trailPathPool,lastX,lastY,lastM,lastFacing,IsOpened = {},{},nil,nil,nil,nil,nil;
local trailPathTicker,trailPathIcons = nil,{ -- coords_pos = { <left>, <right>, <top>, <bottom>, <sizeW>, <sizeH> }
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

local function UpdateVisibility(self)
	local HUD = FarmHud:IsShown();
	SetShown(self,HUD or (not HUD and FarmHudDB.trailPathOnMinimap))
end

FarmHudTrailPathPinMixin.Show = UpdateVisibility
FarmHudTrailPathPinMixin.SetShown = UpdateVisibility;
FarmHudTrailPathPinMixin.EnableMouse = function() end;

function FarmHudTrailPathPinMixin:UpdatePin(facing,onCluster)
	-- facing
	-- Not everyone has rotateMinimap turned on. Handle both situations accordingly so icon rotates properly on HUD and on trailPathOnMinimap.
	local rotateMiniMap = C_CVar.GetCVarBool("rotateMinimap");
	if facing and onCluster then
		if rotateMiniMap then
			self.pin.Facing.Rotate:SetRadians(self.info.f - facing);
		elseif not rotateMiniMap then
			self.pin.Facing.Rotate:SetRadians(self.info.f);
		end
    end
	-- texture
	local pinIcon = (onCluster and FarmHudDB.rotation and FarmHudDB.trailPathIcon) or "dot02"; -- There is no "dot2"
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
	local scale = onCluster and FarmHudDB.trailPathScale or 0.7;
	if self.info.currentPinScale~=scale then
		self.pin :SetScale(scale);
		self.info.currentPinScale = scale;
	end
	-- color
	if self.info.currentPinColor1~=FarmHudDB.trailPathColor1 then
		self.pin.icon :SetVertexColor(unpack(FarmHudDB.trailPathColor1))
		self.info.currentPinColor1 = FarmHudDB.trailPathColor1;
	end

	-- Force EnableMouse off
	EnableMouse(self,false);

	-- visibility
	UpdateVisibility(self);
end

local function GetMicrotime()
	return ceil(GetTime()*100);
end

local function TrailPath_TickerFunc()
	-- get position from HereBeDragon
	local x,y,instance = HBD:GetPlayerWorldPosition();

	-- skip function on invalid result; in dungeons/raids
	if not (x and y and instance) then
		return
	end

	local registerNew = true;
	local currentTime = GetMicrotime();
	local currentFacing = GetPlayerFacing() or 0; -- 0 - 6.5
	-- Make HUD icon settings apply to trailPathOnMinimap
	local HUD = FarmHud:IsShown();
	local IsOnCluster = HUD or (not HUD and FarmHudDB.trailPathOnMinimap);

	-- check distance between current and prev. position; skip function
	if trailPathActive[1] then
		local a, distance =  HBD:GetWorldVector(instance,trailPathActive[1].info.x,trailPathActive[1].info.y,x,y);
		if distance <= minDistanceBetween then
			trailPathActive[1].info.f = currentFacing;
			trailPathActive[1]:UpdatePin(nil,IsOnCluster);
			registerNew = false;
		end
	end

	if registerNew then
		-- reuse pin frame from pool or create new
		local entry = trailPathPool[1];
		if entry then
			tremove(trailPathPool,1);
		else
			entry = CreateFrame("Frame",nil,nil,"FarmHudTrailPathPinTemplate");
			entry.info = {};
			entry.pin.Facing:Play();
			entry:EnableMouse(false);
		end

		-- update info table entries
		entry.info.map = instance;
		entry.info.x = x;
		entry.info.y = y;
		entry.info.f = currentFacing;
		entry.info.t = currentTime;
		entry:UpdatePin(nil,IsOnCluster); -- There is no "IsInCluster"

		-- register pin frame at HereBeDragon
		HBDPins:AddMinimapIconWorld(FarmHud, entry, instance, x, y );
		tinsert(trailPathActive,1,entry);
	end

	-- check pin frame too old; remove or update
	if #trailPathActive>0 then
		for i=#trailPathActive, 1, -1 do
			local v = trailPathActive[i];
			if i>1 and (i>FarmHudDB.trailPathCount or (v.info.t and currentTime-v.info.t>(FarmHudDB.trailPathTimeout*100))) then
				HBDPins:RemoveMinimapIcon(FarmHud,v);
				wipe(v.info);
				tinsert(trailPathPool,v);
				tremove(trailPathActive,i);
			else
 				trailPathActive[i]:UpdatePin(currentFacing,IsOnCluster);
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
		if FarmHud.TrailPathPool then
			for i,v in ipairs(FarmHud.TrailPathPool)do
				v:Hide();
			end
		end
	end
end

local module = {};
module.events = {};
module.dbDefaults = {
	trailPathShow = true,
	trailPathOnMinimap = true,
	trailPathCount = 32,
	trailPathTimeout = 60,
	trailPathIcon = "arrow01",
	trailPathColor1 = {1,.2,.2,1,.75},
	trailPathScale = 1,
};

function module.AddOptions()
	return {
		trial = {
			type = "group", --order = 9,
			name = L["TrailPath"],
			childGroups = "tab",
			args = {
				onWorldmap = {
					type = "group", inline = true,
					name = L["TrailPathOnWorldmap"],
					args = {
						trailPathShow = {
							type = "toggle", order = 1,
							name = L["TrailPathShow"], -- desc = L["TrailPathShowDesc"],
						},
						trailPathIcon = {
							type = "select", order = 5,
							name = L["TrailPathIcon"], desc = L["TrailPathIconDesc"],
							values = TrailPathIconValues
						},
						trailPathScale = {
							type = "range", order = 6,
							name = L["TrailPathScale"], desc = L["TrailPathScaleDesc"],
							min=0.1, step=0.1, max=1, isPercent = true
						},
					}
				},
				onMinimap = {
					type = "group", inline = true,
					name = L["TrailPathOnMinimap"],
					desc = L["TrailPathOnMinimapDesc"],
					args = {
						trailPathOnMinimap = {
							type = "toggle", order = 2,
							name = SHOW,
						},
						trailPathMinimapIcon = {
							type = "select", order = 5,
							name = L["TrailPathMinimapIcon"], desc = L["TrailPathMinimapIconDesc"],
							values = TrailPathIconValues
						},
						trailPathMinimapScale = {
							type = "range", order = 6,
							name = L["TrailPathMinimapScale"], desc = L["TrailPathMinimapScaleDesc"],
							min=0.1, step=0.1, max=1, isPercent = true
						},
					}
				},
				trailPathCount = {
					type = "range", order = 3,
					name = L["TrailPathCount"], desc = L["TrailPathCountDesc"],
					min = 10, step = 1, max = 64,
				},
				trailPathTimeout = {
					type = "range", order = 4,
					name = L["TrailPathTimeout"], desc = L["TrailPathTimeoutDesc"],
					min = 10, step = 10, max = 600,
				},
				-- TODO: header ?
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
					type = "color", order = 7,
					name = COLOR, desc = L["TrailPathColorsDesc"],
					hasAlpha = true,
					hidden = false -- function to check color mode
				},
				--[[
				trailPathColor2 = {
					type = "color", order = 8,
					name = COLOR.." 2", desc = L["TrailPathColorsDesc"],
					hidden = false -- function to check color mode
				},
				trailPathColor3 = {
					type = "color", order = 9,
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

function module.events.PLAYER_ENTERING_WORLD()
	if IsInInstance() then
		UpdateTrailPath(false)
	else
		UpdateTrailPath()
	end
end

function module.events.PLAYER_LOGIN()
	local mt = getmetatable(FarmHud).__index;
	EnableMouse,SetShown = mt.EnableMouse, mt.SetShown;

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

--ns.RegisterModule("TrailPath",module)
ns.modules["TrailPath"] = module;

--[[
	known problems:
		- sometimes icons disappear on turn off famrhud. invisible not removed.
]]
