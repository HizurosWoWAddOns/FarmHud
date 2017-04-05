
local addon,ns=...;
local L=ns.L;

BINDING_HEADER_FARMHUD = "FarmHud";
BINDING_NAME_TOGGLEFARMHUD = L["Toggle FarmHud's Display"];
BINDING_NAME_TOGGLEFARMHUDMOUSE	= L["Toggle FarmHud's tooltips (Can't click through Hud)"];
BINDING_NAME_TOGGLEFARMHUDBACKGROUND = L["Toggle FarmHud's minimap background"];

local LibHijackMinimap_Token,AreaBorderStates,LibHijackMinimap,NPCScan = {},{};
local media, media_blizz, enableMouseTaintedOnLoad = "Interface\\AddOns\\"..addon.."\\media\\", "Interface\\Minimap\\";
local mps,mouseOnKeybind = {}; -- minimap_prev_state
local fh_scale, fh_font, updateRotations, HereBeDragonsPins, _ = 1.4;
local minimapScripts = {--[["OnMouseUp",]]"OnMouseDown","OnDragStart"};
local playerDot_updateLock, zoomLocked, playerDot_orig, playerDot_textures, playerDot_custom = false,false,"Interface\\Minimap\\MinimapArrow", {
	["blizz"]         = L["Blizzards player arrow"],
	["blizz-smaller"] = L["Blizzards player arrow (smaller)"],
	["gold"]          = L["Golden player dot"],
	["white"]         = L["White player dot"],
	["black"]         = L["Black player dot"],
	["hide"]          = L["Hide player arrow"],
};
local blobSets = {
	black = {"Interface\\glues\\credits\\bloodelf_priestess_master6","Interface\\common\\ShadowOverlay-Top","Interface\\glues\\credits\\bloodelf_priestess_master6","Interface\\common\\ShadowOverlay-Top"}
}
local dbDefaults = {
	hud_scale=1.4, text_scale=1.4,
	gathercircle_show=true,gathercircle_color={0,1,0,0.5},
	cardinalpoints_show=true,cardinalpoints_color1={1,0.82,0,0.7},cardinalpoints_color2={1,0.82,0,0.7},cardinalpoints_radius=0.47,
	coords_show=true,coords_bottom=false,coords_color={1,0.82,0,0.7},coords_radius=0.51,
	buttons_show=false,buttons_buttom=false,buttons_alpha=0.6,buttons_radius=0.56,
	mouseoverinfo_color={1,0.82,0,0.7},
	areaborder_arch_show="blizz",areaborder_arch_texture=false,areaborder_arch_alpha=1,
	areaborder_quest_show="blizz",areaborder_quest_texture=false,areaborder_quest_alpha=1,
	areaborder_tasks_show="blizz",areaborder_task_texture=false,areaborder_task_alpha=1,
	player_dot="blizz", background_alpha=0.8, holdKeyForMouseOn = "_none",
	support_gathermate=true,support_routes=true,support_npcscan=true,support_bloodhound2=true,support_tomtom=true,
}
local TrackingIndex={};
local modifiers = {
	A  = {LALT=1,RALT=1},
	AL = {LALT=1},
	AR = {RALT=1},
	C  = {LCTRL=1,RCTRL=1},
	CL = {LCTRL=1},
	CR = {RCTRL=1},
	S  = {LSHIFT=1,RSHIFT=1},
	SL = {LSHIFT=1},
	SR = {RSHIFT=1},
};


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
	FarmHudMinimap:SetPlayerTexture(tex);
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
	for i=1, GetNumTrackingTypes() do
		local name, texture, active, category, nested  = GetTrackingInfo(i);
		if name==MINIMAP_TRACKING_DIGSITES then
			TrackingIndex["ArchBlob"] = i;
			AreaBorderStates.Arch = active;
			if FarmHudDB.areaborder_arch_show~="blizz" and FarmHudDB.areaborder_arch_show~=tostring(active) then
				SetTracking(i,FarmHudDB.areaborder_arch_show=="true");
			end
		elseif name==MINIMAP_TRACKING_QUEST_POIS then
			TrackingIndex["QuestBlob"] = i;
			AreaBorderStates.Quest = active;
			if FarmHudDB.areaborder_quest_show~="blizz" and FarmHudDB.areaborder_quest_show~=tostring(active) then
				SetTracking(i,FarmHudDB.areaborder_quest_show=="true");
			end
		end
		-- Bonus Objective is not present in list... maybe using QuestBlog as toggle
	end
end

local function CheckEnableMouse()
	local enableMouseTainted = issecurevariable(_G.Minimap,"EnableMouse");
	if enableMouseFunc and FarmHudMinimap.EnableMouse~=enableMouseFunc then
		FarmHudMinimap.EnableMouse = enableMouseFunc;
	end
end

-------------------------------------------------
-- global functions
-------------------------------------------------

C_Timer.NewTicker(1/31, function()
	if FarmHud:IsShown() then
		local bearing = GetPlayerFacing();
		if bearing then
			for k, v in ipairs(FarmHud.TextFrame.cardinalPoints) do
				local x, y = math.sin(v.rad + bearing), math.cos(v.rad + bearing);
				v:ClearAllPoints();
				v:SetPoint("CENTER", FarmHud, "CENTER", x * (FarmHud.textScaledHeight * FarmHudDB.cardinalpoints_radius), y * (FarmHud.textScaledHeight * FarmHudDB.cardinalpoints_radius));
			end
		else
			for k, v in ipairs(FarmHud.TextFrame.cardinalPoints) do
				v:ClearAllPoints();
			end
		end
		if FarmHud.TextFrame.coords:IsShown() then
			local x,y=GetPlayerMapPosition("player");
			if x and x>0 then
				FarmHud.TextFrame.coords:SetFormattedText("%.1f, %.1f",x*100,y*100);
			else
				FarmHud.TextFrame.coords:SetText("");
			end
		end
	end
end);

function FarmHud_SetScales()
	FarmHud:SetPoint("CENTER");

	local size = UIParent:GetHeight();
	FarmHud:SetSize(size,size);

	local MinimalScaledSize = size / FarmHudDB.hud_scale;
	FarmHudMinimap:SetScale(FarmHudDB.hud_scale);
	FarmHudMinimap:SetSize(MinimalScaledSize, MinimalScaledSize);

	FarmHud.TextFrame:SetScale(FarmHudDB.text_scale);
	FarmHud.textScaledHeight = ((FarmHud:GetHeight()*FarmHud:GetScale()) / FarmHudDB.text_scale) * 0.5;

	local _size = size * 0.435;
	FarmHud.gatherCircle:SetSize(_size, _size);

	local y = ((FarmHud:GetHeight()*FarmHud:GetScale()) * FarmHudDB.buttons_radius) * 0.5;
	if (FarmHudDB.buttons_bottom) then
		FarmHud.onScreenButtons:SetPoint("CENTER", FarmHud, "CENTER", 0, -y);
	else
		FarmHud.onScreenButtons:SetPoint("CENTER", FarmHud, "CENTER", 0, y);
	end

	local y = FarmHud.textScaledHeight * FarmHudDB.coords_radius;
	if (FarmHudDB.coords_bottom) then
		FarmHud.TextFrame.coords:SetPoint("CENTER", FarmHud, "CENTER", 0, -y);
	else
		FarmHud.TextFrame.coords:SetPoint("CENTER", FarmHud, "CENTER", 0, y);
	end

	FarmHud.TextFrame.mouseWarn:SetPoint("CENTER",FarmHud,"CENTER",0,-16);
end

function FarmHud_UpdateScale()
	if not FarmHud:IsShown() then return end
end

function FarmHud_OnShow(self)
	playerDot_updateLock = true;
	zoomLocked = true;
	mps = {
		zoom = FarmHudMinimap:GetZoom(),
		rotation = GetCVar("rotateMinimap"),
	};

	if _G.Minimap==FarmHudMinimap then
		mps.anchors = {};
		mps.childs = {};
		mps.parent = FarmHudMinimap:GetParent();
		mps.scale = FarmHudMinimap:GetScale();
		mps.size = {FarmHudMinimap:GetSize()};
		mps.level = FarmHudMinimap:GetFrameLevel();
		mps.mouse = FarmHudMinimap:IsMouseEnabled();
		mps.mousewheel = FarmHudMinimap:IsMouseWheelEnabled();


		if mps.mouse then
			FarmHudMinimap:EnableMouse(false);
		end

		if mps.mousewheel then
			FarmHudMinimap:EnableMouseWheel(false);
		end

		-- Yeah... trouble maker ElvUI... TroubleUI :P
		local mc_points = {MinimapCluster:GetPoint(i)};
		if mc_points[2]==Minimap then
			mps.mc_mouse = MinimapCluster:IsMouseEnabled();
			mps.mc_mousewheel = MinimapCluster:IsMouseWheelEnabled();
			if mps.mc_mouse then
				MinimapCluster:EnableMouse(false);
			end
			if mps.mc_mousewheel then
				MinimapCluster:EnableMouseWheel(false);
			end
		end

		local onmouseup = FarmHudMinimap:GetScript("OnMouseUp");
		if onmouseup~=Minimap_OnClick then
			mps.ommouseup = onmouseup;
			FarmHudMinimap:SetScript("OnMouseUp",Minimap_OnClick);
		end

		for _,action in ipairs(minimapScripts)do
			local fnc = FarmHudMinimap:GetScript(action);
			if fnc then
				mps[action] = fnc;
				FarmHudMinimap:SetScript(action,nil);
			end
		end

		for i=1, FarmHudMinimap:GetNumPoints() do
			mps.anchors[i] = {FarmHudMinimap:GetPoint(i)};
		end

		local childs = {FarmHudMinimap:GetChildren()};
		for i=1, #childs do
			childs[i].fh_prev = {childs[i]:IsShown(),childs[i]:GetAlpha()};
			childs[i]:Hide();
			childs[i]:SetAlpha(0);
		end

		FarmHudMinimap:SetFrameLevel(1);
		FarmHudMinimap:SetScale(1);
		FarmHudMinimap:ClearAllPoints();
		FarmHudMinimap:SetParent(FarmHud);
		FarmHudMinimap:SetAllPoints();
		FarmHudMinimap:SetZoom(0);
		FarmHudMinimap:SetAlpha(0);

		CheckEnableMouse();
		FarmHudMinimap:EnableMouse(false);
	else
		CheckEnableMouse();
		FarmHudMinimap:EnableMouse(false);
		_G.Minimap:Hide();
	end

	SetCVar("rotateMinimap", "1", "ROTATE_MINIMAP");

	SetPlayerDotTexture(true);
	AreaBorder_Update(true);

	FarmHud_SetScales();

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

	--[[
	if (TomTom) and (FarmHudDB.support_tomtom==true) then
		if (LibStub.libs["HereBeDragons-Pins-1.0"]) then
			if(not HereBeDragonsPins)then
				HereBeDragonsPins = LibStub("HereBeDragons-Pins-1.0");
			end
			--HereBeDragonsPins:SetMinimapObject(FarmHudCluster);
		end
		if(TomTom.ReparentMinimap) then
			--TomTom:ReparentMinimap(FarmHudCluster);
		end
	end
	--]]

	if (LibHijackMinimap)then
		LibHijackMinimap:HijackMinimap(LibHijackMinimap_Token,FarmHudMinimap);
	end
end

function FarmHud_OnHide(self, force)
	MinimapBackdrop:Show();
	if _G.Minimap==FarmHudMinimap then
		FarmHudMinimap:SetAlpha(1);
		FarmHudMinimap:SetScale(mps.scale);
		FarmHudMinimap:SetSize(unpack(mps.size));
		FarmHudMinimap:SetFrameLevel(mps.level);
		FarmHudMinimap:SetParent(mps.parent);
		FarmHudMinimap:ClearAllPoints();
		FarmHudMinimap:EnableMouse(mps.mouse);
		FarmHudMinimap:EnableMouseWheel(mps.mousewheel);

		if mps.ommouseup then
			FarmHudMinimap:SetScript("OnMouseUp",mps.ommouseup);
		end

		for _,action in ipairs(minimapScripts)do
			if type(mps[action])=="function" then
				FarmHudMinimap:SetScript(action,mps[action]);
			end
		end

		if mps.mc_mouse then
			MinimapCluster:EnableMouse(true);
		end

		if mps.mc_mousewheel then
			MinimapCluster:EnableMouseWheel(true);
		end

		for i=1, #mps.anchors do
			FarmHudMinimap:SetPoint(unpack(mps.anchors[i]));
		end
		local childs = {Minimap:GetChildren()};
		for i=1, #childs do
			if childs[i].fh_prev~=nil then
				childs[i]:SetShown(childs[i].fh_prev[1]);
				childs[i]:SetAlpha(childs[i].fh_prev[2]);
			end
		end

	else
		_G.Minimap:Show();
	end

	SetCVar("rotateMinimap", mps.rotation, "ROTATE_MINIMAP");

	FarmHudMinimap:EnableMouse(true);

	zoomLocked = false;
	local maxLevels = Minimap:GetZoomLevels();
	if mps.zoom>maxLevels then mps.zoom = maxLevels; end
	FarmHudMinimap:SetZoom(mps.zoom);

	mps = false;

	SetPlayerDotTexture(false);
	AreaBorder_Update(false);

	if (GatherMate2) then
		GatherMate2:GetModule("Display"):ReparentMinimapPins(_G.Minimap);
	end
	if (Routes) and (Routes.ReparentMinimap) then
		Routes:ReparentMinimap(_G.Minimap);
	end
	if (NPCScan) and (NPCScan.SetMinimapFrame) then
		NPCScan:SetMinimapFrame(_G.Minimap);
	end
	if (Bloodhound2) and (Bloodhound2.ReparentMinimap) then
		Bloodhound2.ReparentMinimap(_G.Minimap,"Minimap");
	end
	--[[
	if (TomTom) then
		if (HereBeDragonsPins) then
			HereBeDragonsPins:SetMinimapObject(_G.Minimap);
		end
		if(TomTom.ReparentMinimap) then
			TomTom:ReparentMinimap(_G.Minimap);
		end
	end
	--]]
	if (LibHijackMinimap)then
		LibHijackMinimap:ReleaseMinimap(LibHijackMinimap_Token);
	end

	playerDot_updateLock = false;
end

-- Toggle FarmHud display
function FarmHud_Toggle(flag)
	if (flag==nil) then
		if (FarmHud:IsShown()) then
			FarmHud:Hide();
		else
			FarmHud:Show();
		end
	else
		if (flag) then
			FarmHud:Show();
		else
			FarmHud:Hide();
		end
	end
end

-- Toggle the mouse to check out herb / ore tooltips
function FarmHud_ToggleMouse(force)
	if FarmHudMinimap:GetParent()==FarmHud then
		if (force==nil and FarmHudMinimap:IsMouseEnabled()) or force then
			CheckEnableMouse();
			FarmHudMinimap:EnableMouse(false);
			FarmHud.TextFrame.mouseWarn:Hide();
			if not force then
				mouseOnKeybind = true;
			end
		else
			FarmHudMinimap:EnableMouse(true);
			FarmHud.TextFrame.mouseWarn:Show();
			if not force then
				mouseOnKeybind = false;
			end
		end
	end
end

function FarmHud_ToggleResizer()
end

function FarmHud_Mover()
end

function FarmHud_ToggleBackground()
	if FarmHudMinimap:GetParent()==FarmHud then
		FarmHudMinimap:SetAlpha(FarmHudMinimap:GetAlpha()==0 and FarmHudDB.background_alpha or 0);
	end
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

		FarmHud:SetFrameLevel(2);
		FarmHudCluster:SetFrameLevel(3);
		setmetatable(FarmHudCluster,getmetatable(_G.Minimap));

		FarmHud._GetScale = FarmHud.GetScale;
		FarmHud.GetScale = function() return 1; end

		if (FarmHudDB.gathercircle_show) then
			FarmHud.gatherCircle:Show();
		end

		FarmHud.gatherCircle:SetVertexColor(unpack(FarmHudDB.gathercircle_color));

		local radius = FarmHudMinimap:GetWidth() * 0.214;
		for i, v in ipairs(FarmHud.TextFrame.cardinalPoints) do
			local label = v:GetText();
			local rot = (0.785398163 * (i-1));
			local x, y = math.sin(rot), math.cos(rot);
			v:SetPoint("CENTER", FarmHud, "CENTER", x * radius, y * radius);
			v:SetText(L[label]);
			v:SetTextColor(1.0,0.82,0);
			v:SetFont(unpack(fh_font));
			if v.SetScale then
				v:SetScale(1.4);
			end
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
			FarmHud.TextFrame.coords:Show();
		end
		FarmHud.TextFrame.coords:SetFont(unpack(fh_font));
		FarmHud.TextFrame.coords:SetTextColor(unpack(FarmHudDB.coords_color));

		if (FarmHudDB.buttons_show) then
			FarmHud.onScreenButtons:Show();
		end
		FarmHud.onScreenButtons:SetAlpha(FarmHudDB.buttons_alpha);

		FarmHud.TextFrame.mouseWarn:SetText(L["MOUSE ON"]);
		FarmHud.TextFrame.mouseWarn:SetFont(unpack(fh_font));
		FarmHud.TextFrame.mouseWarn:SetTextColor(unpack(FarmHudDB.mouseoverinfo_color));

		if(LibStub.libs['LibHijackMinimap-1.0'])then
			LibHijackMinimap = LibStub('LibHijackMinimap-1.0');
			LibHijackMinimap:RegisterHijacker(addon,LibHijackMinimap_Token);
		end
	elseif event=="PLAYER_LOGOUT" then
		FarmHud_Toggle(false);
	elseif event=="MODIFIER_STATE_CHANGED" then
		local key, down = arg1,...;
		--ns.print(tostring(modifiers[FarmHudDB.holdKeyForMouseOn]),arg1,...);
		if not mouseOnKeybind and modifiers[FarmHudDB.holdKeyForMouseOn] and modifiers[FarmHudDB.holdKeyForMouseOn][key]==1 then
			FarmHud_ToggleMouse(down==0)
		end
	end
end

function FarmHud_OnLoad()
	local _

	FarmHud.Toggle=FarmHud_Toggle;

	_, enableMouseTaintedOnLoad = issecurevariable(_G.Minimap,"EnableMouse");

	if not enableMouseTaintedOnLoad then
		enableMouseFunc = Minimap.EnableMouse; -- reference to original function
	end

	if FarmHudMinimap==nil then
		FarmHudMinimap = _G.Minimap;
	end

	hooksecurefunc(Minimap,"SetPlayerTexture",function(self,texture)
		if not playerDot_updateLock then
			playerDot_custom = texture;
		end
	end);

	hooksecurefunc(FarmHudMinimap,"SetZoom",function(self,level)
		if zoomLocked and level~=0 then FarmHudMinimap:SetZoom(0); end
	end);

	FarmHud:RegisterEvent("ADDON_LOADED");
	FarmHud:RegisterEvent("PLAYER_LOGIN");
	FarmHud:RegisterEvent("PLAYER_LOGOUT");
	FarmHud:RegisterEvent("MODIFIER_STATE_CHANGED");
end

-------------------------------------------------
-- Option panel
-------------------------------------------------
local options = {
	type = "group",
	name = "FarmHud",
	childGroups = "tree",
	args = {
		hud = {
			type = "group",
			name = "Options",
			args = {
				minimapicon_show = {
					type = "toggle", order = 0,
					name = L["Minimap Icon"],
					desc = L["Show or hide the minimap icon."],
					get = function() return FarmHudDB.MinimapIcon.show; end,
					set = function(_,v) FarmHudDB.MinimapIcon.show = v;
						if (v) then LDBIcon:Show(addon) else LDBIcon:Hide(addon); end
					end,
				},
				spacer0 =  {
					type = "description", order = 1,
					name = " ", fontSize = "medium"
				},
				hud_scale = {
					type = "range", order = 2,
					name = L["HUD symbol scale"],
					desc = L["Scale the symbols on HUD"],
					min = 1, max = 2.5, step = 0.1, isPercent = true,
					get = function() return FarmHudDB.hud_scale; end,
					set = function(_,v)
						FarmHudDB.hud_scale = v;
						if FarmHud:IsShown() then
							FarmHud_SetScales();
						end
					end
				},
				text_scale = {
					type = "range", order = 2,
					name = L["Text scale"],
					desc = L["Scale text on HUD for cardinal points, mouse on and coordinations"],
					min = 1, max = 2.5, step = 0.1, isPercent = true,
					get = function() return FarmHudDB.text_scale; end,
					set = function(_,v)
						FarmHudDB.text_scale = v;
						if FarmHud:IsShown() then
							FarmHud_SetScales();
						end
					end
				},
				background_alpha = {
					type = "range", order = 3,
					name = L["Background transparency"],
					min = 0.1, max = 1, step = 0.1, isPercent = true,
					get = function() return FarmHudDB.background_alpha; end,
					set = function(_,v)
						FarmHudDB.background_alpha = v;
						if FarmHud:IsShown() then
							Minimap:SetAlpha(v);
						end
					end
				},
				playerdot = {
					type = "select", order = 4,
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
				spacer1 =  {
					type = "description", order = 5,
					name = " ", fontSize = "medium"
				},
				mouseoverinfo_color = {
					type = "color", order = 6,
					name = L["Mouse over info color"],
					hasAlpha = true,
					get = function() return unpack(FarmHudDB.mouseoverinfo_color); end,
					set = function(_,...) FarmHudDB.mouseoverinfo_color = {...};
						FarmHud.TextFrame.mouseWarn:SetTextColor(...);
					end
				},
				mouseoverinfo_resetcolor = {
					type = "execute", order = 7,
					name = L["Reset color"],
					func = function()
						FarmHudDB.mouseoverinfo_color = dbDefaults.mouseoverinfo_color;
						FarmHud.TextFrame.mouseWarn:SetVertexColor(unpack(FarmHudDB.mouseoverinfo_color));
					end
				},
				spacer2 =  {
					type = "description", order = 8,
					name = " ", fontSize = "medium"
				},
				mouseoverinfo_onholdkey = {
					type = "select", order = 9,
					name = L["Hold key for mouseover"],
					values = {
						["_NONE"] = NONE.."/"..ADDON_DISABLED,
						A  = L["Alt"],
						AL = L["Left alt"],
						AR = L["Right alt"],
						C  = L["Control"],
						CL = L["Left control"],
						CR = L["Right control"],
						S  = L["Shift"],
						SL = L["Left shift"],
						SR = L["Right shift"],
					},
					get = function() return FarmHudDB.holdKeyForMouseOn; end,
					set = function(_,v) FarmHudDB.holdKeyForMouseOn = v; end
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
								for i,e in ipairs(FarmHud.TextFrame.cardinalPoints) do e:SetShown(v); end
							end
						},
						cardinalpoints_radius = {
							type = "range", order = 2,
							name = L["Distance from center"],
							desc = L["Change the distance from center"],
							min = 0.1, max = 0.9, step=0.005, isPercent=true,
							get = function() return FarmHudDB.cardinalpoints_radius; end,
							set = function(_,v) FarmHudDB.cardinalpoints_radius = v; end
						},
						cardinalpoints_header1 = {
							type = "header", order = 3,
							name = L["N, W, S, E"]
						},
						cardinalpoints_color1 = {
							type = "color", order = 4, width = "double",
							name = L["Color"],
							desc = L["Adjust color and transparency of cardinal points N, W, S, E"],
							hasAlpha = true,
							get = function() return unpack(FarmHudDB.cardinalpoints_color1); end,
							set = function(_,...) FarmHudDB.cardinalpoints_color1 = {...};
								for i,e in ipairs(FarmHud.TextFrame.cardinalPoints) do if e.NWSE then e:SetTextColor(...); end end
							end
						},
						cardinalpoints_resetcolor1 = {
							type = "execute", order = 5,
							name = L["Reset color"],
							desc = L["Reset color and transparency of cardinal points N, W, S, E"],
							func = function()
								FarmHudDB.cardinalpoints_color1 = dbDefaults.cardinalpoints_color1;
								for i,e in ipairs(FarmHud.TextFrame.cardinalPoints) do if e.NWSE then e:SetTextColor(unpack(FarmHudDB.cardinalpoints_color1)); end end
							end
						},
						cardinalpoints_header2 = {
							type = "header", order = 6,
							name = L["NW, NE, SW, SE"]
						},
						cardinalpoints_color2 = {
							type = "color", order = 7, width = "double",
							name = L["Color"],
							desc = L["Adjust color and transparency of cardinal points NW, NE, SW, SE"],
							hasAlpha = true,
							get = function() return unpack(FarmHudDB.cardinalpoints_color2); end,
							set = function(_,...) FarmHudDB.cardinalpoints_color2 = {...};
								for i,e in ipairs(FarmHud.TextFrame.cardinalPoints) do if not e.NWSE then e:SetTextColor(...); end end
							end
						},
						cardinalpoints_resetcolor2 = {
							type = "execute", order = 8,
							name = L["Reset color"],
							desc = L["Reset color and transparency of cardinal points NW, NE, SW, SE"],
							func = function()
								FarmHudDB.cardinalpoints_color2 = dbDefaults.cardinalpoints_color2;
								for i,e in ipairs(FarmHud.TextFrame.cardinalPoints) do if not e.NWSE then e:SetTextColor(unpack(FarmHudDB.cardinalpoints_color2)); end end
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
								FarmHud.TextFrame.coords:SetShown(v);
							end
						},
						coords_radius = {
							type = "range", order = 2,
							name = L["Distance from center"],
							desc = L["Change the distance from center"],
							min = 0.1, max = 0.9, step=0.005, isPercent=true,
							get = function() return FarmHudDB.coords_radius; end,
							set = function(_,v)
								FarmHudDB.coords_radius = v;
								if FarmHud:IsShown() then
									FarmHud_SetScales();
								end
							end
						},
						coords_bottom = {
							type = "toggle", order = 3, width = "double",
							name = L["Coordinations on bottom"],
							desc = L["Display player coordinations on bottom"],
							get = function() return FarmHudDB.coords_bottom; end,
							set = function(_,v)
								FarmHudDB.coords_bottom = v;
								if FarmHud:IsShown() then
									FarmHud_SetScales();
								end
							end
						},
						coords_color = {
							type = "color", order = 4,
							name = L["Color"],
							desc = L["Adjust color and transparency of coordations"],
							hasAlpha = true,
							get = function() return unpack(FarmHudDB.coords_color); end,
							set = function(_,...) FarmHudDB.coords_color = {...};
								FarmHud.TextFrame.coords:SetTextColor(...);
							end
						},
						coords_resetcolor = {
							type = "execute", order = 5,
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
						buttons_radius = {
							type = "range", order = 3,
							name = L["Distance from center"],
							desc = L["Change the distance from center"],
							min = 0.1, max = 0.9, step=0.005, isPercent=true,
							get = function() return FarmHudDB.buttons_radius; end,
							set = function(_,v)
								FarmHudDB.buttons_radius = v;
								if FarmHud:IsShown() then
									FarmHud_SetScales();
								end
							end
						},
						buttons_alpha = {
							type = "range", order = 4,
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
							type = "select", order = 11, width = "double",
							name = L["%s area border in HUD"]:format(L["Archaeology"]),
							values = {
								["true"] = L["Show"],
								["false"] = L["Hide"],
								["blizz"] = L["Use tracking option from game client"]
							},
							get = function() return FarmHudDB.areaborder_arch_show; end,
							set = function(_,v) FarmHudDB.areaborder_arch_show = v; end
						},
						areaborder_quest_header = {
							type = "header", order = 20,
							name = TRACKING.." > "..MINIMAP_TRACKING_QUEST_POIS,
						},
						areaborder_quest_show = {
							type = "select", order = 21, width = "double",
							name = L["%s area border in HUD"]:format(L["Quest"]),
							values = {
								["true"] = L["Show"],
								["false"] = L["Hide"],
								["blizz"] = L["Use tracking option from game client"]
							},
							get = function() return FarmHudDB.areaborder_quest_show; end,
							set = function(_,v) FarmHudDB.areaborder_quest_show = v; end
						},
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
							get = function() FarmHudDB.support_tomtom=false; return false; end,
							set = function(_,v) FarmHudDB.support_tomtom = v; end,
							disabled = true
						}
					}
				}
			}
		}
	}
}

LibStub("AceConfig-3.0"):RegisterOptionsTable("FarmHud", options)
LibStub("AceConfigDialog-3.0"):AddToBlizOptions("FarmHud")
