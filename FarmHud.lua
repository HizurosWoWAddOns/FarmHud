
local addon,ns=...;
local L=ns.L;

BINDING_HEADER_FARMHUD = "FarmHud";
BINDING_NAME_TOGGLEFARMHUD = L["Toggle FarmHud's Display"];
BINDING_NAME_TOGGLEFARMHUDMOUSE	= L["Toggle FarmHud's tooltips (Can't click through Hud)"];
BINDING_NAME_TOGGLEFARMHUDBACKGROUND = L["Toggle FarmHud's minimap background"];

local LibHijackMinimap_Token,AreaBorderStates,LibHijackMinimap,NPCScan = {},{};
local media, media_blizz = "Interface\\AddOns\\"..addon.."\\media\\", "Interface\\Minimap\\";
local fh_scale, fh_mapRotation, fh_mapZoom, fh_font, updateRotations, Astrolabe, HereBeDragonsPins, _ = 1.4;
local playerDot_updateLock, playerDot_orig, playerDot_textures, playerDot_custom = false,"Interface\\Minimap\\MinimapArrow", {
	["blizz"]         = L["Blizzards player arrow"],
	["blizz-smaller"] = L["Blizzards player arrow (smaller)"],
	["gold"]          = L["Golden player dot"],
	["white"]         = L["White player dot"],
	["hide"]          = L["Hide player arrow"],
};
local blobSets = {
	black = {"Interface\\glues\\credits\\bloodelf_priestess_master6","Interface\\common\\ShadowOverlay-Top","Interface\\glues\\credits\\bloodelf_priestess_master6","Interface\\common\\ShadowOverlay-Top"}
}
local dbDefaults = {
	gathercircle_show=false,gathercircle_color={0,1,0,0.5},
	cardinalpoints_show=false,cardinalpoints_color1={1,0.82,0,0.7},cardinalpoints_color2={1,0.82,0,0.7},
	coords_show=false,coords_bottom=false,coords_color={1,0.82,0,0.7},
	buttons_show=false,buttons_buttom=false,buttons_alpha=0.6, mouseoverinfo_color={1,0.82,0,0.7},
	areaborder_arch_show=false,areaborder_arch_texture=false,areaborder_arch_alpha=1,
	areaborder_quest_show=false,areaborder_quest_texture=false,areaborder_quest_alpha=1,
	areaborder_tasks_show=false,areaborder_task_texture=false,areaborder_task_alpha=1,
	player_dot="blizz", background_alpha=0.8,
	support_gathermate=true,support_routes=true,support_npcscan=true,support_bloodhound2=true,support_tomtom=true,
}
local TrackingIndex={};

-------------------------------------------------
-- LibDataBroker & Icon
-------------------------------------------------
local LDB = LibStub("LibDataBroker-1.1"):NewDataObject("FarmHud",{
	type	= "launcher",
	icon	= "Interface\\Icons\\INV_Misc_Herb_MountainSilverSage.png",
	label	= "FarmHud",
	text	= "FarmHud",
	OnTooltipShow = function(tt)
		tt:AddLine("FarmHud");
		tt:AddLine(("|cffffff00%s|r %s"):format(L["Click"],L["to toggle FarmHud"]));
		tt:AddLine(("|cffffff00%s|r %s"):format(L["Right click"],L["to config"]));
		tt:AddLine(L["Or macro with /script FarmHud_Toggle()"]);
	end,
	OnClick = function(_, button)
		if (button=="LeftButton") then
			FarmHud_Toggle();
		else
			local Lib = LibStub("AceConfigDialog-3.0");
			if Lib.OpenFrames["FarmHud"]~=nil then
				Lib:Close("FarmHud");
			else
				Lib:Open("FarmHud");
				Lib.OpenFrames["FarmHud"]:SetStatusText(GAME_VERSION_LABEL..": "..GetAddOnMetadata(addon,"Version"));
			end
		end
	end
});
local LDBIcon = LDB and LibStub("LibDBIcon-1.0", true);


-------------------------------------------------
-- local functions
-------------------------------------------------
ns.print = function (...)
	local colors,t,c = {"0099ff","00ff00","ff6060","44ffff","ffff00","ff8800","ff44ff","ffffff"},{},1;
	for i,v in ipairs({...}) do
		v = tostring(v);
		if i==1 and v~="" then
			tinsert(t,"|cff0099ff"..addon.."|r:"); c=2;
		end
		if not v:match("||c") then
			v,c = "|cff"..colors[c]..v.."|r", c<#colors and c+1 or 1;
		end
		tinsert(t,v);
	end
	print(unpack(t));
end


local function SetPlayerDotTexture(bool)
	local tex = media.."playerDot-"..FarmHudDB.player_dot
	if FarmHudDB.player_dot=="blizz" or not bool then
		tex = playerDot_custom or playerDot_orig;
	end
	Minimap:SetPlayerTexture(tex);
end

local function AreaBorder_SetAlpha(Type,Value)
	if not (Type=="Arch" or Type=="Quest" or Type=="Task") then return end
	FarmHudMinimap["Set"..Type.."BlobInsideAlpha"](Value);
	FarmHudMinimap["Set"..Type.."BlobOutsideAlpha"](Value);
	FarmHudMinimap["Set"..Type.."BlobRingAlpha"](Value);
end

local function AreaBorder_SetTexture(Type,Inside,Outside,Ring,Selected)
	if not (Type=="Arch" or Type=="Quest" or Type=="Task") then return end
	FarmHudMinimap["Set"..Type.."BlobInsideTexture"](Inside);
	FarmHudMinimap["Set"..Type.."BlobOutsideTexture"](Outside);
	FarmHudMinimap["Set"..Type.."BlobRingTexture"](Ring);
	if t=="Quest" and Selected then
		FarmHudMinimap["Set"..v.."BlobOutsideSelectedTexture"](Selected);
	end
end

local function AreaBorder_Update(bool)
	--[[
	local opts = {
		Arch  = {media_blizz.."UI-ArchBlobMinimap-Inside",    media_blizz.."UI-ArchBlobMinimap-Outside",    media_blizz.."UI-QuestBlob-MinimapRing"};
		Quest = {media_blizz.."UI-QuestBlobMinimap-Inside",   media_blizz.."UI-QuestBlobMinimap-Outside",   media_blizz.."UI-QuestBlob-MinimapRing", media_blizz.."UI-QuestBlobMinimap-OutsideSelected"};
		Task  = {media_blizz.."UI-BonusObjectiveBlob-Inside", media_blizz.."UI-BonusObjectiveBlob-Outside", media_blizz.."UI-BonusObjectiveBlob-MinimapRing"};
	}
	--]]
	if bool then
		for i=1, GetNumTrackingTypes() do
			local name, texture, active, category, nested  = GetTrackingInfo(i);
			if texture:find("ArchBlob") and FarmHudDB.areaborder_arch_show~="blizz" and FarmHudDB.areaborder_arch_show~=active then
				AreaBorderStates.Arch = active;
				SetTracking(i,FarmHudDB.areaborder_arch_show);
				TrackingIndex["ArchBlob"] = i;
			elseif texture:find("QuestBlob") and FarmHudDB.areaborder_quest_show~="blizz" and FarmHudDB.areaborder_quest_show~=active then
				AreaBorderStates.Quest = active;
				SetTracking(i,FarmHudDB.areaborder_quest_show);
				TrackingIndex["QuestBlob"] = i;
			end
			-- Bonus Objective is not present in list... maybe using QuestBlog as toggle
		end

		--[[
		if FarmHudDB.areaborder_arch_alpha<1 then
			AreaBorderStates.ArchAlpha = FarmHudDB.areaborder_arch_alpha;
		end
		if FarmHudDB.areaborder_quest_alpha<1 then
			AreaBorderStates.QuestAlpha = FarmHudDB.areaborder_quest_alpha;
		end
		if FarmHudDB.areaborder_task_alpha<1 then
			AreaBorderStates.TaskAlpha = FarmHudDB.areaborder_task_alpha;
		end
		]]

		--[[
		if FarmHudDB.areaborder_arch_texture then
			opts.Arch.Textures = {
				FarmHudDB.areaborder_arch_texture.."Inside",
				FarmHudDB.areaborder_arch_texture.."Outside",
				FarmHudDB.areaborder_arch_texture.."Ring"
			};
			AreaBorderStates.ArchTexture=true;
		end


		if FarmHudDB.areaborder_quest_texture then
			opts.Quest.Textures = {
				FarmHudDB.areaborder_quest_texture.."Inside";
				FarmHudDB.areaborder_quest_texture.."Outside";
				FarmHudDB.areaborder_quest_texture.."Ring";
				FarmHudDB.areaborder_quest_texture.."Selected";
			}
			AreaBorderStates.QuestTexture=true;
		end

		if FarmHudDB.areaborder_task_texture then
			opts.Task.Textures = {
				FarmHudDB.areaborder_task_texture.."Inside";
				FarmHudDB.areaborder_task_texture.."Outside";
				FarmHudDB.areaborder_task_texture.."Ring";
			}
			AreaBorderStates.TaskTexture=true;
		end
		--]]
	else
		if AreaBorderStates.Arch~=nil then
			SetTracking(TrackingIndex["ArchBlob"],AreaBorderStates.Arch);
		end
		if AreaBorderStates.Quest~=nil then
			SetTracking(TrackingIndex["QuestBlob"],AreaBorderStates.Quest);
		end
	end

	--[[
	for _,Type in ipairs({"Arch","Quest","Task"})do
		if AreaBorderStates[Type.."Alpha"] then
			if bool and type(AreaBorderStates[Type.."Alpha"])=="number" then
				AreaBorder_SetAlpha(i,AreaBorderStates[Type.."Alpha"]);
				--print("AreaBorder changed",AreaBorderStates[Type.."Alpha"]);
				AreaBorderStates[Type.."Alpha"]=true;
			else
				AreaBorder_SetAlpha(i,1);
				AreaBorderStates[Type.."Alpha"]=nil;
				--print("AreaBorder changed",1);
			end
		end
		if AreaBorderStates[Type.."Texture"] then
			--AreaBorder_SetTexture(Type,unpack(opts[i].Textures));
		end
	end
	--]]
end


-------------------------------------------------
-- global functions
-------------------------------------------------
function FarmHud_OnShow(self)
	playerDot_updateLock = true;
	fh_mapRotation = GetCVar("rotateMinimap");
	SetCVar("rotateMinimap", "1", "ROTATE_MINIMAP");

	fh_mapZoom = FarmHudMinimap:GetZoom();
	FarmHudMinimap:SetZoom(0);
	FarmHudMinimap.zoomLocked = nil;

	SetPlayerDotTexture(true);
	AreaBorder_Update(true);

	if (GatherMate2) and (FarmHudDB.support_gathermate==true) then
		GatherMate2:GetModule("Display"):ReparentMinimapPins(FarmHudCluster);
	end

	if (Routes) and (Routes.ReparentMinimap) and (FarmHudDB.support_routes==true) then
		Routes:ReparentMinimap(FarmHudCluster);
	end

	if (NPCScan) and (NPCScan.SetMinimapFrame) and (FarmHudDB.support_npcscan==true) then
		NPCScan:SetMinimapFrame(FarmHudCluster);
	end

	if (Bloodhound2) and (Bloodhound2.ReparentMinimap) and (FarmHudDB.support_bloodhound2==true) then
		Bloodhound2.ReparentMinimap(FarmHudCluster,"FarmHud");
	end

	if (TomTom) and (FarmHudDB.support_tomtom==true) then
		if (LibStub.libs["HereBeDragons-Pins-1.0"]) then
			if(not HereBeDragonsPins)then
				HereBeDragonsPins = LibStub("HereBeDragons-Pins-1.0");
			end
			HereBeDragonsPins:SetMinimapObject(FarmHudMinimap);
		end
		if (DongleStub) and (not Astrolabe) then
			_, Astrolabe = pcall(DongleStub,"Astrolabe-1.0");
			if(type(Astrolabe)~="table")then
				_, Astrolabe = pcall(DongleStub,"Astrolabe-TomTom-1.0");
			end
			if type(Astrolabe)~="table" then
				Astrolabe=nil;
			end
		end
		if (Astrolabe) and (Astrolabe.SetTargetMinimap) then
			Astrolabe:SetTargetMinimap(FarmHudCluster);
		end
		if(TomTom.ReparentMinimap) then
			TomTom:ReparentMinimap(FarmHudCluster);
		end
	end

	if (LibHijackMinimap)then
		LibHijackMinimap:HijackMinimap(LibHijackMinimap_Token,FarmHudCluster);
	end

	FarmHud:SetScript("OnUpdate", FarmHud_OnUpdate);
	Minimap:Hide();
end

function FarmHud_OnHide(self, force)
	SetCVar("rotateMinimap", fh_mapRotation, "ROTATE_MINIMAP");

	local maxLevels = FarmHudMinimap:GetZoomLevels();
	if fh_mapZoom>maxLevels then fh_mapZoom = maxLevels; end
	FarmHudMinimap.zoomLocked = true;
	FarmHudMinimap:SetZoom(fh_mapZoom);

	SetPlayerDotTexture(false);
	AreaBorder_Update(false);

	if (GatherMate2) then
		GatherMate2:GetModule("Display"):ReparentMinimapPins(Minimap);
	end

	if (Routes) and (Routes.ReparentMinimap) then
		Routes:ReparentMinimap(Minimap);
	end

	if (NPCScan) and (NPCScan.SetMinimapFrame) then
		NPCScan:SetMinimapFrame(Minimap);
	end

	if (Bloodhound2) and (Bloodhound2.ReparentMinimap) then
		Bloodhound2.ReparentMinimap(_G.Minimap,"Minimap");
	end

	if (TomTom) then
		if (HereBeDragonsPins) then
			HereBeDragonsPins:SetMinimapObject(_G.Minimap);
		end
		if (Astrolabe and Astrolabe.SetTargetMinimap) then
			Astrolabe:SetTargetMinimap(_G.Minimap);
		end
		if(TomTom.ReparentMinimap) then
			TomTom:ReparentMinimap(_G.Minimap);
		end
	end

	if (LibHijackMinimap)then
		LibHijackMinimap:ReleaseMinimap(LibHijackMinimap_Token);
	end

	FarmHud:SetScript("OnUpdate", nil);
	Minimap:Show();
	playerDot_updateLock = false;
end

function FarmHud_OnUpdate(self, elapse)
	if not FarmHud.coords:IsShown() then return end
	if self.elapse==nil then self.elapse=0; end

	self.elapse = self.elapse + elapse;

	if (self.elapse >= 0.02) then
		if Minimap:IsShown() then
			Minimap:Hide();
		end

		local bearing = GetPlayerFacing();
		for k, v in ipairs(FarmHud.cardinalPoints) do
			local x, y = math.sin(v.rad + bearing), math.cos(v.rad + bearing);
			v:ClearAllPoints();
			v:SetPoint("CENTER", FarmHud, "CENTER", x * FarmHud.cardinalPoints_radius, y * FarmHud.cardinalPoints_radius);
		end

		local x,y=GetPlayerMapPosition("player");
		FarmHud.coords:SetFormattedText("%.1f, %.1f",x*100,y*100);

		self.elapse=0;
	end
end

function FarmHud_SetScales()
	--FarmHudMinimap:ClearAllPoints();
	--FarmHudMinimap:SetPoint("CENTER", UIParent, "CENTER");

	FarmHud:ClearAllPoints();
	FarmHud:SetPoint("CENTER");
	FarmHud:SetScale(fh_scale);

	local size = UIParent:GetHeight() / fh_scale;

	FarmHudMinimap:SetSize(size, size);
	FarmHud:SetSize(size, size);

	local _size = size * 0.435;
	FarmHud.gatherCircle:SetSize(_size, _size);

	FarmHud.cardinalPoints_radius = size * 0.214;

	local y = size * 0.260;
	if (FarmHudDB.buttons_bottom) then
		FarmHud.onScreenButtons:SetPoint("CENTER", FarmHud, "CENTER", 0, -y);
	else
		FarmHud.onScreenButtons:SetPoint("CENTER", FarmHud, "CENTER", 0, y);
	end

	local y = size * 0.235;
	if (FarmHudDB.coords_bottom) then
		FarmHud.coords:SetPoint("CENTER", FarmHud, "CENTER", 0, -y);
	else
		FarmHud.coords:SetPoint("CENTER", FarmHud, "CENTER", 0, y);
	end

	FarmHud.mouseWarn:SetPoint("CENTER",FarmHud,"CENTER",0,-16);
end

-- Toggle FarmHud display
function FarmHud_Toggle(flag)
	if (flag==nil) then
		if (FarmHud:IsShown()) then
			FarmHud:Hide();
		else
			FarmHud:Show();
			FarmHud_SetScales();
		end
	else
		if (flag) then
			FarmHud:Show();
			FarmHud_SetScales();
		else
			FarmHud:Hide();
		end
	end
end

-- Toggle the mouse to check out herb / ore tooltips
function FarmHud_ToggleMouse()
	if (FarmHudMinimap:IsMouseEnabled()) then
		FarmHudMinimap:EnableMouse(false);
		FarmHud.mouseWarn:Hide();
	else
		FarmHudMinimap:EnableMouse(true);
		FarmHud.mouseWarn:Show();
	end
end

function FarmHud_ToggleBackground()
	FarmHudMinimap:SetAlpha(FarmHudMinimap:GetAlpha()==0 and FarmHudDB.background_alpha or 0);
end

function FarmHudCloseButton_OnClick()
	FarmHud_Toggle()
end

function FarmHud_OnEvent(self,event,arg1,...)
	if event=="ADDON_LOADED" and arg1==addon then
		ns.print(L["AddOn loaded..."]);
	elseif event=="PLAYER_LOGIN" then
		NPCScan = (_NPCScan) and (_NPCScan.Overlay) and _NPCScan.Overlay.Modules.List[ "Minimap" ];

		if (FarmHudDB==nil) then
			FarmHudDB={};
		end

		if (FarmHudDB.MinimapIcon==nil) then
			FarmHudDB.MinimapIcon = {
				show = true,
				minimapPos = 220,
				radius = 80
			};
		end
		
		-- little migration of options
		if FarmHudDB.MinimapIcon.hide~=nil then
			FarmHudDB.MinimapIcon.show = not FarmHudDB.MinimapIcon.hide;
			FarmHudDB.MinimapIcon.hide = nil;
		end
		if FarmHudDB.hide_gathercircle~=nil then
			FarmHudDB.gathercircle_show = not FarmHudDB.hide_gathercircle;
			FarmHudDB.hide_gathercircle = nil;
		end
		if FarmHudDB.hide_indicators~=nil then
			FarmHudDB.cardinalpoints_show = not FarmHudDB.hide_indicators;
			FarmHudDB.hide_indicators = nil;
		end
		if FarmHudDB.hide_coords~=nil then
			FarmHudDB.coords_show = not FarmHudDB.hide_coords;
			FarmHudDB.hide_coords = nil;
		end
		if FarmHudDB.hide_buttons~=nil then
			FarmHudDB.buttons_show = not FarmHudDB.hide_buttons;
			FarmHudDB.hide_buttons = nil;
		end
		if FarmHudDB.show_gathermate~=nil then
			FarmHudDB.support_gathermate = FarmHudDB.show_gathermate;
			FarmHudDB.show_gathermate = nil;
		end
		if FarmHudDB.show_routes~=nil then
			FarmHudDB.support_routes = FarmHudDB.show_routes;
			FarmHudDB.show_routes = nil;
		end
		if FarmHudDB.show_npcscan~=nil then
			FarmHudDB.support_npcscan = FarmHudDB.show_npcscan;
			FarmHudDB.show_npcscan = nil;
		end
		if FarmHudDB.show_bloodhound2~=nil then
			FarmHudDB.support_bloodhound2 = FarmHudDB.show_bloodhound2;
			FarmHudDB.show_bloodhound2 = nil;
		end
		if FarmHudDB.show_tomtom~=nil then
			FarmHudDB.support_tomtom = FarmHudDB.show_tomtom;
			FarmHudDB.show_tomtom = nil;
		end

		for k,v in pairs(dbDefaults)do
			if (FarmHudDB[k]==nil) then
				FarmHudDB[k]=v;
			end
		end

		if (LDBIcon) then
			LDBIcon:Register(addon, LDB, FarmHudDB.MinimapIcon);
			if not FarmHudDB.MinimapIcon.show then
				LDBIcon:Hide(addon);
			end
		end

		fh_font = {SystemFont_Small2:GetFont()};
		--fh_font[3] = "MONOCHROME";

		FarmHudMinimap:SetFrameLevel(1);
		FarmHud:SetFrameLevel(2);
		FarmHudCluster:SetFrameLevel(3);
		setmetatable(FarmHudCluster, { __index = FarmHudMinimap });

		FarmHud._GetScale = FarmHud.GetScale;
		FarmHud.GetScale = function() return 1; end

		if (FarmHudDB.gathercircle_show) then
			FarmHud.gatherCircle:Show();
		end

		FarmHud.gatherCircle:SetVertexColor(unpack(FarmHudDB.gathercircle_color));

		local radius = FarmHudMinimap:GetWidth() * 0.214;
		for i, v in ipairs(FarmHud.cardinalPoints) do
			local label = v:GetText();
			local rot = (0.785398163 * (i-1));
			local x, y = math.sin(rot), math.cos(rot);
			v:SetPoint("CENTER", FarmHud, "CENTER", x * radius, y * radius);
			v:SetText(L[label]);
			v:SetTextColor(1.0,0.82,0);
			v:SetFont(unpack(fh_font));
			v.rad = rot;
			v.radius = radius;
			v.NWSE = strlen(label)==1;
			if (FarmHudDB.cardinalpoints_show) then
				v:Show();
			end
			if v.NWSE then
				v:SetTextColor(unpack(FarmHudDB.cardinalpoints_color1));
			else
				v:SetTextColor(unpack(FarmHudDB.cardinalpoints_color2));
			end
		end

		if (FarmHudDB.coords_show) then
			FarmHud.coords:Show();
		end
		FarmHud.coords:SetFont(unpack(fh_font));
		FarmHud.coords:SetTextColor(unpack(FarmHudDB.coords_color));

		if (FarmHudDB.buttons_show) then
			FarmHud.onScreenButtons:Show();
		end
		FarmHud.onScreenButtons:SetAlpha(FarmHudDB.buttons_alpha);

		FarmHudMinimap:EnableMouse(false);

		FarmHud.mouseWarn:SetText(L["MOUSE ON"]);
		FarmHud.mouseWarn:SetFont(unpack(fh_font));
		FarmHud.mouseWarn:SetTextColor(unpack(FarmHudDB.mouseoverinfo_color));

		FarmHud_SetScales();

		if(LibStub.libs['LibHijackMinimap-1.0'])then
			LibHijackMinimap = LibStub('LibHijackMinimap-1.0');
			LibHijackMinimap:RegisterHijacker(addon,LibHijackMinimap_Token);
		end
	elseif event=="PLAYER_LOGOUT" then
		FarmHud_Toggle(false);
	end
end

function FarmHud_OnLoad()
	FarmHud.Toggle=FarmHud_Toggle;

	hooksecurefunc(FarmHudMinimap,"SetPlayerTexture",function(self,texture)
		if not playerDot_updateLock then
			playerDot_custom = texture;
		end
	end);

	hooksecurefunc(Minimap,"SetZoom",function(self,level)
		if not self.zoomLocked and FarmHudMinimap:IsShown() and FarmHudMinimap:IsVisible() then
			self.zoomLocked = true;
			self:SetZoom(0);
			self.zoomLocked = nil;
		end
	end);
	FarmHud:RegisterEvent("ADDON_LOADED");
	FarmHud:RegisterEvent("PLAYER_LOGIN");
	FarmHud:RegisterEvent("PLAYER_LOGOUT");
end

-------------------------------------------------
-- Option panel
-------------------------------------------------
local options = {
	type = "group",
	name = "FarmHud",
	args = {
		hud = {
			type = "group",
			name = "Options",
			args = {
				minimapicon_show = {
					type = "toggle", order = 1, width="double",
					name = L["Minimap Icon"],
					desc = L["Show or hide the minimap icon."],
					get = function() return FarmHudDB.MinimapIcon.show; end,
					set = function(_,v) FarmHudDB.MinimapIcon.show = v;
						if (v) then LDBIcon:Show(addon) else LDBIcon:Hide(addon); end
					end,
				},
				playerdot = {
					type = "select", order = 2,
					name = L["Player arrow or dot"],
					desc = L["Change the look of your player dot/arrow on opened FarmHud"],
					values = playerDot_textures,
					get = function() return FarmHudDB.player_dot; end,
					set = function(_,v)
						FarmHudDB.player_dot = v;
						if FarmHud:IsShown() and playerDot_updateLock then
							SetPlayerDotTexture(true);
						end
					end,
				},
				background_alpha = {
					type = "range", order = 3,
					name = L["Background transparency"],
					min = 0.1, max = 1, step = 0.1, isPercent = true,
					get = function() return FarmHudDB.background_alpha; end,
					set = function(_,v)
						FarmHudDB.background_alpha = v;
						if FarmHud:IsShown() then
							FarmHudMinimap:SetAlpha(v);
						end
					end
				},
				mouseoverinfo_color = {
					type = "color", order = 4, width = "double",
					name = L["Mouse over info color"],
					hasAlpha = true,
					get = function() return unpack(FarmHudDB.mouseoverinfo_color); end,
					set = function(_,...) FarmHudDB.mouseoverinfo_color = {...};
						FarmHud.mouseWarn:SetTextColor(...);
					end
				},
				mouseoverinfo_resetcolor = {
					type = "execute", order = 5,
					name = L["Reset color"],
					func = function()
						FarmHudDB.mouseoverinfo_color = dbDefaults.mouseoverinfo_color;
						FarmHud.mouseWarn:SetVertexColor(unpack(FarmHudDB.mouseoverinfo_color));
					end
				},
		----------------------------------------------
				gathercircle = {
					type = "group", order = 1,
					name = L["Garther circle"],
					args = {
						gathercircle_show = {
							type = "toggle", order = 1, width = "double",
							name = L["Show gather circle"],
							desc = L["Show or hide the gather circle"],
							get = function() return FarmHudDB.gathercircle_show; end,
							set = function(_,v)
								FarmHudDB.gathercircle_show = v;
								FarmHud.gatherCircle:SetShown(v);
							end
						},
						gathercircle_color = {
							type = "color", order = 2, width = "double",
							name = L["Color"],
							hasAlpha = true,
							get = function() return unpack(FarmHudDB.gathercircle_color); end,
							set = function(_,...) FarmHudDB.gathercircle_color = {...};
								FarmHud.gatherCircle:SetVertexColor(...);
							end
						},
						gathetcircle_resetcolor = {
							type = "execute", order = 3,
							name = L["Reset color"],
							func = function()
								FarmHudDB.gathercircle_color = dbDefaults.gathercircle_color;
								FarmHud.gatherCircle:SetVertexColor(unpack(FarmHudDB.gathercircle_color));
							end
						}
					}
				},
				cardinalpoints = {
					type = "group", order = 2,
					name = L["Cardinal points"],
					args = {
						cardinalpoints_show = {
							type = "toggle", order = 1, width = "double",
							name = L["Show cardinal points"],
							desc = L["Show or hide the direction indicators"],
							get = function() return FarmHudDB.cardinalpoints_show; end,
							set = function(_,v)
								FarmHudDB.cardinalpoints_show = v;
								if (v) then
									for i,e in ipairs(FarmHud.cardinalPoints) do e:Show(); end
								else
									for i,e in ipairs(FarmHud.cardinalPoints) do e:Hide(); end
								end
							end
						},
						cardinalpoints_header1 = {
							type = "header", order = 2,
							name = L["N, W, S, E"]
						},
						cardinalpoints_color1 = {
							type = "color", order = 3, width = "double",
							name = L["Color"],
							desc = L["Adjust color and transparency of cardinal points N, W, S, E"],
							hasAlpha = true,
							get = function() return unpack(FarmHudDB.cardinalpoints_color1); end,
							set = function(_,...) FarmHudDB.cardinalpoints_color1 = {...};
								for i,e in ipairs(FarmHud.cardinalPoints) do if e.NWSE then e:SetTextColor(...); end end
							end
						},
						cardinalpoints_resetcolor1 = {
							type = "execute", order = 4,
							name = L["Reset color"],
							desc = L["Reset color and transparency of cardinal points N, W, S, E"],
							func = function()
								FarmHudDB.cardinalpoints_color1 = dbDefaults.cardinalpoints_color1;
								for i,e in ipairs(FarmHud.cardinalPoints) do if e.NWSE then e:SetTextColor(unpack(FarmHudDB.cardinalpoints_color1)); end end
							end
						},
						cardinalpoints_header2 = {
							type = "header", order = 5,
							name = L["NW, NE, SW, SE"]
						},
						cardinalpoints_color2 = {
							type = "color", order = 6, width = "double",
							name = L["Color"],
							desc = L["Adjust color and transparency of cardinal points NW, NE, SW, SE"],
							hasAlpha = true,
							get = function() return unpack(FarmHudDB.cardinalpoints_color2); end,
							set = function(_,...) FarmHudDB.cardinalpoints_color2 = {...};
								for i,e in ipairs(FarmHud.cardinalPoints) do if not e.NWSE then e:SetTextColor(...); end end
							end
						},
						cardinalpoints_resetcolor2 = {
							type = "execute", order = 7,
							name = L["Reset color"],
							desc = L["Reset color and transparency of cardinal points NW, NE, SW, SE"],
							func = function()
								FarmHudDB.cardinalpoints_color2 = dbDefaults.cardinalpoints_color2;
								for i,e in ipairs(FarmHud.cardinalPoints) do if not e.NWSE then e:SetTextColor(unpack(FarmHudDB.cardinalpoints_color2)); end end
							end
						}
					}
				},
				coords = {
					type = "group", order = 3,
					name = L["Coordinations"],
					args = {
						coords_show = {
							type = "toggle", order = 1, width = "double",
							name = L["Player coordinations"],
							desc = L["Show or hide player coordinations"],
							get = function() return FarmHudDB.coords_show; end,
							set = function(_,v) FarmHudDB.coords_show = v;
								FarmHud.coords:SetShown(v);
							end
						},
						coords_bottom = {
							type = "toggle", order = 2, width = "double",
							name = L["Coordinations on bottom"],
							desc = L["Display player coordinations on bottom"],
							get = function() return FarmHudDB.coords_bottom; end,
							set = function(_,v)
								FarmHudDB.coords_bottom = v;
								if (v) then
									FarmHud.coords:SetPoint("CENTER", FarmHud, "CENTER", 0, -FarmHud:GetWidth()*.23);
								else
									FarmHud.coords:SetPoint("CENTER", FarmHud, "CENTER", 0, FarmHud:GetWidth()*.23);
								end
							end
						},
						coords_color = {
							type = "color", order = 3,
							name = L["Color"],
							desc = L["Adjust color and transparency of coordations"],
							hasAlpha = true,
							get = function() return unpack(FarmHudDB.coords_color); end,
							set = function(_,...) FarmHudDB.coords_color = {...};
								FarmHud.coords:SetTextColor(...);
							end
						},
						coords_resetcolor = {
							type = "execute", order = 4,
							name = L["Reset color"],
							desc = L["Reset color and transparency of coordations"],
							func = function()
								FarmHudDB.coords_color = dbDefaults.coords_color;
								FarmHudDB.coords_color:SetTextColor(unpack(FarmHudDB.coords_color));
							end
						}
					}
				},
				onscreenbuttons = {
					type = "group", order = 4,
					name = L["OnScreen buttons"],
					args = {
						buttons_show = {
							type = "toggle", order = 1, width = "double",
							name = L["Show OnScreen buttons"],
							desc = L["Show or hide OnScreen buttons (mouse mode and close hud button)"],
							get = function() return FarmHudDB.buttons_show; end,
							set = function(_,v) FarmHudDB.buttons_show = v;
								FarmHud.onScreenButtons:SetShown(v);
							end
						},
						buttons_bottom = {
							type = "toggle", order = 2, width = "double",
							name = L["OnScreen buttons on bottom"],
							desc = L["Display toggle buttons on bottom"],
							get = function() return FarmHudDB.buttons_bottom; end,
							set = function(_,v)
								FarmHudDB.buttons_bottom = v;
								if (v) then
									FarmHud.onScreenButtons:SetPoint("CENTER", FarmHud, "CENTER", 0, -FarmHud:GetWidth()*.25);
								else
									FarmHud.onScreenButtons:SetPoint("CENTER", FarmHud, "CENTER", 0, FarmHud:GetWidth()*.25);
								end
							end
						},
						buttons_alpha = {
							type = "range", order = 3,
							name = L["Transparency"],
							min = 0,
							max = 1,
							step = 0.1,
							isPercent = true,
							get = function() return FarmHudDB.buttons_alpha; end,
							set = function(_,v)
								FarmHudDB.buttons_alpha = v;
								if FarmHud:IsShown() then
									FarmHud.onScreenButtons:SetAlpha(v);
								end
							end,
						}
					}
				},
				areaborder = {
					type = "group", order = 5,
					name = L["Area border"],
					args = {
						areaborder_arch_header = {
							type = "header", order = 10,
							name = TRACKING.." > "..MINIMAP_TRACKING_DIGSITES,
						},
						areaborder_arch_show = {
							type = "toggle", order = 11, width = "double",
							name = L["Show %s area border in HUD"]:format(L["archaeology"]),
							desc = L["Previous state will be restored on closing HUD|n|n|cffaaaaaaSilver checkmark: Don't change tracking option|r"]:format(L["archaeology"]),
							tristate = true,
							get = function()
								if FarmHudDB.areaborder_arch_show=="blizz" then return nil; end
								return FarmHudDB.areaborder_arch_show;
							end,
							set = function(_,v)
								FarmHudDB.areaborder_arch_show = v==nil and "blizz" or v;
								if FarmHud:IsShown() then AreaBorder_Update(true); end
							end,
						},
						--[[areaborder_arch_alpha = {
							type = "range", order = 12,
							name = L["Transparency"],
							min = 0,
							max = 1,
							step = 0.1,
							isPercent = true,
							get = function() return FarmHudDB.areaborder_arch_alpha; end,
							set = function(_,v)
								FarmHudDB.areaborder_arch_alpha = v;
								if FarmHud:IsShown() then AreaBorder_Update(true); end
							end,
						}, --]]
						--areaborder_arch_texture = {
						--	type = "select", order = 13, width = "double",
						--},
						areaborder_quest_header = {
							type = "header", order = 20,
							name = TRACKING.." > "..MINIMAP_TRACKING_QUEST_POIS,
						},
						areaborder_quest_show = {
							type = "toggle", order = 21, width = "double",
							name = L["Show %s area border in HUD"]:format(L["quest"]),
							desc = L["Previous state will be restored on closing HUD|n|n|cffaaaaaaSilver checkmark: Don't change tracking option|r"]:format(L["quest"]),
							tristate = true,
							get = function()
								if FarmHudDB.areaborder_quest_show=="blizz" then return nil; end
								return FarmHudDB.areaborder_quest_show;
							end,
							set = function(_,v)
								FarmHudDB.areaborder_quest_show = v==nil and "blizz" or v;
								if FarmHud:IsShown() then AreaBorder_Update(true); end
							end,
						},
						--[[areaborder_quest_alpha = {
							type = "range", order = 22,
							name = L["Transparency"],
							min = 0,
							max = 1,
							step = 0.1,
							isPercent = true,
							get = function() return FarmHudDB.areaborder_quest_alpha; end,
							set = function(_,v)
								FarmHudDB.areaborder_quest_alpha = v;
								if FarmHud:IsShown() then AreaBorder_Update(true); end
							end,
						}, --]]
						--areaborder_quest_texture = {
						--	type = "select", order = 23, width = "double",
						--},
						--[[
						areaborder_task_header = {
							type = "header", order = 30,
							name = L["Bonus objectives"],
						},
						areaborder_info = {
							type = "description", order = 31,
							name = L["This option has no own entry in blizzards tracking menu.|nMaybe Blizzard using \"Track Quest POIs\"."],
						},
						areaborder_task_show = {
							type = "toggle", order = 32, width = "double",
							name = L["Show %s area border"]:format(L["bonus objective"]),
							--desc = L["Show or hide %s area border.|n|n|cffaaaaaaSilver checkmark: Show if tracking option enabled|r"]:format(L["bonus objective"]),
							--tristate = true,
							get = function()
								if FarmHudDB.areaborder_task_show=="blizz" then return nil; end
								return FarmHudDB.areaborder_task_show;
							end,
							set = function(_,v)
								FarmHudDB.areaborder_task_show = v==nil and "blizz" or v;
								if FarmHud:IsShown() then AreaBorder_Update(true); end
							end,
						},
						areaborder_tasks_alpha = {
							type = "range", order = 33,
							name = L["Transparency"],
							min = 0,
							max = 1,
							step = 0.1,
							isPercent = true,
							get = function() return FarmHudDB.areaborder_task_alpha; end,
							set = function(_,v)
								FarmHudDB.areaborder_task_alpha = v;
								if FarmHud:IsShown() then AreaBorder_Update(true); end
							end,
						},
						--]]
						--areaborder_tasks_texture = {
						--	type = "select", order = 33, width = "double",
						--},
					}
				},
				keybindings = {
					type = "group", order = 6,
					name = L["Keybind Options"],
					args = {
						bind_showtoggle = {
							type = "keybinding", order = 1, width = "double",
							name = L["Toggle FarmHud's Display"],
							desc = L["Set the keybinding to show FarmHud."],
							get = function(self) return GetBindingKey("TOGGLEFARMHUD"); end,
							set = function(_,v)
								local keyb = GetBindingKey("TOGGLEFARMHUD");
								if (keyb) then SetBinding(keyb); end
								if (v~="") then SetBinding(v, "TOGGLEFARMHUD"); end
								SaveBindings(GetCurrentBindingSet());
							end,
						},
						bind_mousetoggle = {
							type = "keybinding", order = 2, width = "double",
							name = L["Toggle FarmHud's tooltips (Can't click through Hud)"],
							desc = L["Set the keybinding to allow mouse over tooltips."],
							get = function() return GetBindingKey("TOGGLEFARMHUDMOUSE"); end,
							set = function(_,v)
								local keyb = GetBindingKey("TOGGLEFARMHUDMOUSE");
								if (keyb) then SetBinding(keyb); end
								if (v~="") then SetBinding(v, "TOGGLEFARMHUDMOUSE"); end
								SaveBindings(GetCurrentBindingSet());
							end,
						},
						bind_backgroundtoggle = {
							type = "keybinding", order = 3, width = "double",
							name = L["Toggle FarmHud's minimap background"],
							desc = L["Set the keybinding to show minimap background."],
							get = function() return GetBindingKey("TOGGLEFARMHUDBACKGROUND"); end,
							set = function(_,v)
								local keyb = GetBindingKey("TOGGLEFARMHUDBACKGROUND");
								if (keyb) then SetBinding(keyb); end
								if (v~="") then SetBinding(v, "TOGGLEFARMHUDBACKGROUND"); end
								SaveBindings(GetCurrentBindingSet());
							end,
						},
					}
				},
				supports = {
					type = "group", order = 7,
					name = L["Support Options"],
					args = {
						support_gathermate = {
							type = "toggle", order = 1,
							name = "GatherMate2", desc = L["Enable GatherMate2 support"],
							get = function() return FarmHudDB.support_gathermate; end,
							set = function(_,v) FarmHudDB.support_gathermate = v; end,
						},
						support_routes = {
							type = "toggle", order = 2,
							name = "Routes", desc = L["Enable Routes support"],
							get = function() return FarmHudDB.support_routes; end,
							set = function(_,v) FarmHudDB.support_routes = v; end,
						},
						support_npcscan = {
							type = "toggle", order = 3,
							name = "NPCScan", desc = L["Enable NPCScan support"],
							get = function() return FarmHudDB.support_npcscan; end,
							set = function(_,v) FarmHudDB.support_npcscan = v; end,
						},
						support_bloodhound2 = {
							type = "toggle", order = 4,
							name = "BloodHound2", desc = L["Enable Bloodhound2 support"],
							get = function() return FarmHudDB.support_bloodhound2; end,
							set = function(_,v) FarmHudDB.support_bloodhound2 = v; end
						},
						support_tomtom = {
							type = "toggle", order = 5,
							name = "TomTom", desc = L["Enable TomTom support"],
							get = function() return FarmHudDB.support_tomtom; end,
							set = function(_,v) FarmHudDB.support_tomtom = v; end
						}
					}
				}
			}
		}
	}
}

LibStub("AceConfig-3.0"):RegisterOptionsTable("FarmHud", options)
LibStub("AceConfigDialog-3.0"):AddToBlizOptions("FarmHud")

--[[

NEW:
- removed blackborderblobs to add area border options
- tomtom support restored
- added keybind to toggle minimap background
- added onscreen button to toggle minimap background
- added minimap zoom change on show/hide farmhud
- added player arrow customization
- added color (+transparency) option for gathercircle
- added color (+transparency) option for cardinalpoints
- added color (+transparency) option for coordinations
- added transparency option for onscreen buttons

---------------------------

TODO:
-- cardinal points radius (maybe)
-- added transparency option for areaborder

-- area borders
	-- archaeology
		set texture (inside/ouside/ring)
		set alpha
	-- quests
		set texture (inside/ouside/selected/ring)
		set alpha
	-- tasks (bonus objective)
		set texture (inside/ouside/ring)
		set alpha

-- LibShareMedia support (fonts/textures)
	-- player arrow by LSM
	-- blobs by LSM
	-- coords font by LSM
	-- cardinalpoints font 1 by LSM
	-- cardinalpoints font 2 by LSM

]]
