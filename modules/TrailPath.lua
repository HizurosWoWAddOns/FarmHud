
local addon, ns = ...;
local L = ns.L;
--LibStub("HizurosSharedTools").RegisterPrint(ns,addon,"FH/TP");

local HBD = LibStub("HereBeDragons-2.0")
local HBDPins = LibStub("HereBeDragons-Pins-2.0")

local EnableMouse, SetShown
local media = "Interface\\AddOns\\FarmHud\\media\\";
local minDistanceBetween = 12;
local maxTeleportJumpDistance = 1000;
local trailPathActive,trailPathMinimapPool,trailPathWorldmapPool,lastInstance,lastInInstance,trailMode = {},{},{},nil,nil,nil;
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

local function IsAnyTrailEnabled()
	return FarmHudDB.trailPathShow or FarmHudDB.trailPathOnMinimap or FarmHudDB.trailPathOnWorldmap;
end

local function ShouldShowMinimapPin()
	if FarmHud:IsShown() then
		return FarmHudDB.trailPathShow;
	end
	return FarmHudDB.trailPathOnMinimap;
end

local function UpdateVisibility(self)
	if not SetShown then return end
	SetShown(self, ShouldShowMinimapPin());
end

FarmHudTrailPathPinMixin.EnableMouse = function() end;

function FarmHudTrailPathPinMixin:OnShow()
	if not self.pin.Facing:IsPlaying() then
		self.pin.Facing:Play();
	end
	if self.savedRadians then
		self.pin.Facing.Rotate:SetRadians(self.savedRadians);
	end
end

function FarmHudTrailPathPinMixin:UpdatePin(info,facing,isHUD)
	-- facing
	-- Not everyone has rotateMinimap turned on. Handle both situations accordingly so icon rotates properly on HUD, Minimap, and WorldMap.
	local radians;
	if self.isWorldMapPin then
		radians = info.f;
	elseif C_CVar.GetCVarBool("rotateMinimap") then
		radians = info.f - (facing or GetPlayerFacing() or 0);
	else
		radians = info.f;
	end
	self.savedRadians = radians;
	if not self.pin.Facing:IsPlaying() then
		self.pin.Facing:Play();
	end
	self.pin.Facing.Rotate:SetRadians(radians);

	-- texture
	local pinIcon;
	if self.isWorldMapPin then
		pinIcon = FarmHudDB.trailPathWorldmapIcon;
	elseif isHUD then
		pinIcon = FarmHudDB.trailPathIcon;
	else
		pinIcon = FarmHudDB.trailPathMinimapIcon;
	end
	if self.currentPinIcon ~= pinIcon then
		local icon = trailPathIcons[pinIcon];
		if icon then
			self.pin.icon:SetTexture(icon.file);
			if not icon.coords then
				icon.coords = {0,1,0,1};
			end
			self.pin.icon:SetTexCoord(unpack(icon.coords));
			self.pin.icon:SetDesaturated(icon.desaturated==true);
			self.pin.icon:SetBlendMode(icon.mode or "BLEND");
			self.currentPinIcon = pinIcon;
		end
	end

	-- scaling
	local scale;
	if self.isWorldMapPin then
		scale = FarmHudDB.trailPathWorldmapScale;
	elseif isHUD then
		scale = FarmHudDB.trailPathScale;
	else
		scale = FarmHudDB.trailPathMinimapScale;
	end
	if self.currentPinScale ~= scale then
		self.pin:SetScale(scale);
		self.currentPinScale = scale;
	end

	-- color
	local color = FarmHudDB.trailPathColor1;
	if self.currentPinColor1 ~= color then
		self.pin.icon:SetVertexColor(color[1], color[2], color[3], color[4]);
		self.currentPinColor1 = color;
	end

	-- Force EnableMouse off
	if EnableMouse then
		EnableMouse(self,false);
	end

	-- visibility (minimap/HUD pins override Show/SetShown; worldmap pins are managed by HBD's MapCanvas provider)
	if not self.isWorldMapPin then
		UpdateVisibility(self);
	end
end

local function GetMicrotime()
	return ceil(GetTime()*100);
end

local function AcquirePin(pool, isWorldMapPin)
	local pin = tremove(pool, 1);
	if not pin then
		pin = CreateFrame("Frame",nil,nil,"FarmHudTrailPathPinTemplate");
		pin.isWorldMapPin = isWorldMapPin;
		if not isWorldMapPin then
			pin.Show = UpdateVisibility;
			pin.SetShown = UpdateVisibility;
		end
		pin.pin.Facing:Play();
		if EnableMouse then
			EnableMouse(pin, false);
		end
	end
	return pin;
end

local function ResetPinVisualState(pin)
	pin.currentPinIcon = nil;
	pin.currentPinScale = nil;
	pin.currentPinColor1 = nil;
	pin.savedRadians = nil;
end

local function ReleaseMinimapPin(entry)
	local pin = entry.minimapPin;
	if not pin then return end
	HBDPins:RemoveMinimapIcon(FarmHud, pin);
	if SetShown then
		SetShown(pin, false);
	else
		pin:Hide();
	end
	ResetPinVisualState(pin);
	tinsert(trailPathMinimapPool, pin);
	entry.minimapPin = nil;
end

local function ReleaseWorldMapPin(entry)
	local pin = entry.worldmapPin;
	if not pin then return end
	HBDPins:RemoveWorldMapIcon(FarmHud, pin);
	pin:Hide();
	pin:ClearAllPoints();
	ResetPinVisualState(pin);
	tinsert(trailPathWorldmapPool, pin);
	entry.worldmapPin = nil;
end

local function SyncWorldMapPin(entry, needWorldmap, forceColorRefresh, useMapCoords)
	if needWorldmap then
		if not entry.worldmapPin then
			entry.worldmapPin = AcquirePin(trailPathWorldmapPool, true);
			entry.worldmapPin:UpdatePin(entry.info, nil, false);
			if useMapCoords then
				HBDPins:AddWorldMapIconMap(FarmHud, entry.worldmapPin, entry.info.uiMapID, entry.info.mx, entry.info.my);
			else
				HBDPins:AddWorldMapIconWorld(FarmHud, entry.worldmapPin, entry.info.map, entry.info.x, entry.info.y);
			end
		else
			if forceColorRefresh then
				entry.worldmapPin.currentPinColor1 = nil;
			end
			entry.worldmapPin:UpdatePin(entry.info, nil, false);
		end
	elseif entry.worldmapPin then
		ReleaseWorldMapPin(entry);
	end
end

local function SyncAndRefreshPins(forceColorRefresh)
	if #trailPathActive == 0 then return end

	local currentTime = GetMicrotime();
	local currentFacing = GetPlayerFacing() or 0;
	local isHUD = FarmHud:IsShown();
	local needMinimap = FarmHudDB.trailPathShow or FarmHudDB.trailPathOnMinimap;
	local needWorldmap = FarmHudDB.trailPathOnWorldmap;

	for i=#trailPathActive, 1, -1 do
		local entry = trailPathActive[i];
		if i>1 and (i>FarmHudDB.trailPathCount or (entry.info.t and currentTime-entry.info.t>(FarmHudDB.trailPathTimeout*100))) then
			ReleaseMinimapPin(entry);
			ReleaseWorldMapPin(entry);
			wipe(entry.info);
			tremove(trailPathActive, i);
		else
			if entry.info.uiMapID then
				if entry.minimapPin then
					ReleaseMinimapPin(entry);
				end
				SyncWorldMapPin(entry, needWorldmap, forceColorRefresh, true);
			else
				if needMinimap then
					if not entry.minimapPin then
						entry.minimapPin = AcquirePin(trailPathMinimapPool, false);
						HBDPins:AddMinimapIconWorld(FarmHud, entry.minimapPin, entry.info.map, entry.info.x, entry.info.y);
					end
					if forceColorRefresh then
						entry.minimapPin.currentPinColor1 = nil;
					end
					entry.minimapPin:UpdatePin(entry.info, currentFacing, isHUD);
				elseif entry.minimapPin then
					ReleaseMinimapPin(entry);
				end

				SyncWorldMapPin(entry, needWorldmap, forceColorRefresh, false);
			end
		end
	end
end

local function ClearAllTrailPins()
	for i=#trailPathActive, 1, -1 do
		local entry = trailPathActive[i];
		ReleaseMinimapPin(entry);
		ReleaseWorldMapPin(entry);
		wipe(entry.info);
		tremove(trailPathActive, i);
	end
	lastInstance = nil;
	lastInInstance = nil;
	trailMode = nil;
	HBDPins:RemoveAllMinimapIcons(FarmHud);
	HBDPins:RemoveAllWorldMapIcons(FarmHud);
end

local function GetMapFallbackPosition()
	if not FarmHudDB.trailPathOnWorldmap then
		return nil;
	end
	local uiMapID = C_Map.GetBestMapForUnit("player");
	local pos = uiMapID and C_Map.GetPlayerMapPosition(uiMapID, "player");
	if not pos then
		return nil;
	end
	local mx, my = pos:GetXY();
	if not (mx and my) then
		return nil;
	end
	local wx, wy, wInstance = HBD:GetWorldCoordinatesFromZone(mx, my, uiMapID);
	if not (wx and wy and wInstance) then
		return nil;
	end
	return uiMapID, mx, my, wx, wy, wInstance;
end

local function IsTrailPositionValid()
	local x,y,instance = HBD:GetPlayerWorldPosition();
	if x and y and instance then
		return true;
	end
	return GetMapFallbackPosition() ~= nil;
end

local UpdateTrailPath;

local function TrailPath_TickerFunc()
	local inInstance = IsInInstance() and true or false;
	if lastInInstance ~= nil and inInstance ~= lastInInstance then
		ClearAllTrailPins();
	end

	-- Prefer world coordinates (works outdoors and in non-restricted instances like delves)
	local x,y,instance = HBD:GetPlayerWorldPosition();
	if x and y and instance then
		if trailMode and trailMode ~= "world" then
			ClearAllTrailPins();
		end
		if lastInstance and lastInstance ~= instance then
			ClearAllTrailPins();
		end
		trailMode = "world";
		lastInInstance = inInstance;
		lastInstance = instance;

		local registerNew = true;
		local currentTime = GetMicrotime();
		local currentFacing = GetPlayerFacing() or 0; -- 0 - 6.5

		-- check distance between current and prev. position; skip function or reset on large teleport
		if trailPathActive[1] and trailPathActive[1].info.map == instance then
			local _, distance = HBD:GetWorldVector(instance,trailPathActive[1].info.x,trailPathActive[1].info.y,x,y);
			if distance then
				if distance > maxTeleportJumpDistance then
					ClearAllTrailPins();
					trailMode = "world";
					lastInInstance = inInstance;
					lastInstance = instance;
				elseif distance <= minDistanceBetween then
					trailPathActive[1].info.f = currentFacing;
					registerNew = false;
				end
			end
		end

		if registerNew then
			local entry = {
				info = {
					map = instance,
					x = x,
					y = y,
					f = currentFacing,
					t = currentTime,
				}
			};
			tinsert(trailPathActive, 1, entry);
		end

		SyncAndRefreshPins();
		return
	end

	-- World Map-only fallback for restricted instances (dungeons/raids where UnitPosition is nil)
	local uiMapID, mx, my, wx, wy, wInstance = GetMapFallbackPosition();
	if not uiMapID then
		lastInInstance = inInstance;
		return
	end

	if trailMode and trailMode ~= "map" then
		ClearAllTrailPins();
	end
	trailMode = "map";
	lastInInstance = inInstance;

	local registerNew = true;
	local currentTime = GetMicrotime();
	local facing = GetPlayerFacing();
	local entryFacing = facing or 0;
	local needsDirection = facing == nil;

	if trailPathActive[1] and trailPathActive[1].info.uiMapID == uiMapID then
		local angle, distance = HBD:GetWorldVector(wInstance,trailPathActive[1].info.wx,trailPathActive[1].info.wy,wx,wy);
		if distance then
			if distance > maxTeleportJumpDistance then
				ClearAllTrailPins();
				trailMode = "map";
				lastInInstance = inInstance;
			elseif distance <= minDistanceBetween then
				if facing then
					trailPathActive[1].info.f = facing;
					trailPathActive[1].info.needsDirection = nil;
				end
				registerNew = false;
			elseif needsDirection and angle then
				if trailPathActive[1].info.needsDirection then
					trailPathActive[1].info.f = angle;
					trailPathActive[1].info.needsDirection = nil;
				end
				entryFacing = angle;
			end
		end
	end

	if registerNew then
		local entry = {
			info = {
				uiMapID = uiMapID,
				mx = mx,
				my = my,
				wx = wx,
				wy = wy,
				wInstance = wInstance,
				f = entryFacing,
				needsDirection = needsDirection,
				t = currentTime,
			}
		};
		tinsert(trailPathActive, 1, entry);
	end

	SyncAndRefreshPins();
end

function UpdateTrailPath(force)
	if force==nil then
		force = IsAnyTrailEnabled() and IsTrailPositionValid();
	end
	if force==true then
		if trailPathTicker==nil then
			trailPathTicker = C_Timer.NewTicker(0.5,TrailPath_TickerFunc);
			TrailPath_TickerFunc();
		end
	elseif force==false then
		if trailPathTicker then
			trailPathTicker:Cancel();
			trailPathTicker = nil;
		end
		ClearAllTrailPins();
	end
end

local module = {
	dbDefaults = {
		trailPathShow = true,
		trailPathOnMinimap = true,
		trailPathOnWorldmap = true,
		trailPathCount = 32,
		trailPathTimeout = 60,
		trailPathIcon = "arrow01",
		trailPathColor1 = {1,.2,.2,1,.65},
		trailPathScale = 1,
		trailPathMinimapIcon = "dot01",
		trailPathMinimapScale = 1,
		trailPathWorldmapIcon = "arrow01",
		trailPathWorldmapScale = 1,
	},
	events = {},
	OnShow = nil,
	OnHide = nil,
	Update = nil,
	OnLoad = nil,
	OnSetScale = nil,
	AddOptions = nil,
}

function module.AddOptions()
	return {
		trial = {
			type = "group", --order = 9,
			name = L["TrailPath"],
			childGroups = "tab",
			args = {
				pointOptions = {
					type = "group", order=1, inline = true,
					name = L["TrailPathOptions"],
					args = {
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
						resetColor = {
							type = "execute",
							name = L["ResetColor"],
							func = function()
								FarmHudDB.trailPathColor1 = CopyTable(module.dbDefaults.trailPathColor1);
								module.UpdateOptions("trailPathColor1");
							end
						}
					}
				},
				onFarmHud = {
					type = "group", order = 2, inline = true,
					name = L["TrailPathOnFarmHud"],
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
					type = "group", order = 3, inline = true,
					name = L["TrailPathOnMinimap"],
					args = {
						trailPathOnMinimap = {
							type = "toggle", order = 2,
							name = L["TrailPathShow"], --desc = L["TrailPathOnMinimapDesc"]
						},
						trailPathMinimapIcon = {
							type = "select", order = 5,
							name = L["TrailPathIcon"], desc = L["TrailPathIconDesc"],
							values = TrailPathIconValues
						},
						trailPathMinimapScale = {
							type = "range", order = 6,
							name = L["TrailPathScale"], desc = L["TrailPathScaleDesc"],
							min=0.1, step=0.1, max=1, isPercent = true
						},
					}
				},
				onWorldmap = {
					type = "group", order = 4, inline = true,
					name = L["TrailPathOnWorldmap"],
					args = {
						trailPathOnWorldmap = {
							type = "toggle", order = 1,
							name = L["TrailPathShow"],
						},
						trailPathWorldmapIcon = {
							type = "select", order = 5,
							name = L["TrailPathIcon"], desc = L["TrailPathIconDesc"],
							values = TrailPathIconValues
						},
						trailPathWorldmapScale = {
							type = "range", order = 6,
							name = L["TrailPathScale"], desc = L["TrailPathScaleDesc"],
							min=0.1, step=0.1, max=1, isPercent = true
						},
					}
				},
			}
		}
	};
end

function module.OnShow()
	SyncAndRefreshPins();
end

function module.OnHide()
	SyncAndRefreshPins();
end

function module.UpdateOptions(key,value)
	if key=="trailPathShow" or key=="trailPathOnMinimap" or key=="trailPathOnWorldmap" then
		if not IsTrailPositionValid() then
			UpdateTrailPath(false);
		else
			UpdateTrailPath();
			SyncAndRefreshPins();
		end
	elseif key=="trailPathColor1" then
		SyncAndRefreshPins(true);
	else
		SyncAndRefreshPins();
	end
end

function module.events.CVAR_UPDATE(eventFrame, cvar)
	if cvar=="rotateMinimap" or cvar=="ROTATE_MINIMAP" then
		SyncAndRefreshPins();
	end
end

local function HandleZoneOrInstanceChange()
	local inInstance = IsInInstance() and true or false;
	if lastInInstance ~= nil and inInstance ~= lastInInstance then
		ClearAllTrailPins();
	end
	if not IsTrailPositionValid() then
		UpdateTrailPath(false);
		return
	end
	local _,_,instance = HBD:GetPlayerWorldPosition();
	if lastInstance and instance and instance ~= lastInstance then
		ClearAllTrailPins();
	end
	UpdateTrailPath();
end

function module.events.PLAYER_ENTERING_WORLD()
	ClearAllTrailPins();
	UpdateTrailPath();
end

module.events.ZONE_CHANGED_NEW_AREA = HandleZoneOrInstanceChange;
module.events.ZONE_CHANGED = HandleZoneOrInstanceChange;
module.events.ZONE_CHANGED_INDOORS = HandleZoneOrInstanceChange;

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
