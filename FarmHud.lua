
local addon,ns=...;
local L=ns.L;

BINDING_HEADER_FARMHUD = addon;
BINDING_NAME_TOGGLEFARMHUD = L["Toggle FarmHud's Display"];
BINDING_NAME_TOGGLEFARMHUDMOUSE	= L["Toggle FarmHud's tooltips (Can't click through Hud)"];
BINDING_NAME_TOGGLEFARMHUDBACKGROUND = L["Toggle FarmHud's minimap background"];

local LibHijackMinimap_Token,AreaBorderStates,LibHijackMinimap,NPCScan = {},{};
local media, media_blizz, enableMouseTaintedOnLoad = "Interface\\AddOns\\"..addon.."\\media\\", "Interface\\Minimap\\";
local mps,mouseOnKeybind = {}; -- minimap_prev_state
local fh_scale, fh_font, updateRotations, HereBeDragonsPins, _ = 1.4;
local minimapScripts = {--[["OnMouseUp",]]"OnMouseDown","OnDragStart"};
local playerDot_updateLock, zoomLocked, playerDot_orig, playerDot_custom = false,false,"Interface\\Minimap\\MinimapArrow"
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
	player_dot="blizz", background_alpha=0.8, holdKeyForMouseOn = "_none"
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

function ns.print(...)
	local a,colors,t,c,v = {...},{"0099ff","00ff00","ff6060","44ffff","ffff00","ff8800","ff44ff","ffffff"},{},1;
	for i=1, #a do
		v = tostring(a[i]);
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
		mps.alpha = FarmHudMinimap:GetAlpha();

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
			-- ignore HereBeDragonPins
			if not (childs[i].arrow and childs[i].point) then
				childs[i].fh_prev = {childs[i]:IsShown(),childs[i]:GetAlpha()};
				childs[i]:Hide();
				childs[i]:SetAlpha(0);
			end
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

	if (GatherMate2) then
		GatherMate2:GetModule("Display"):ReparentMinimapPins(FarmHudCluster);
	end
	if (Routes) and (Routes.ReparentMinimap) then
		Routes:ReparentMinimap(FarmHudCluster);
	end
	if (NPCScan) and (NPCScan.SetMinimapFrame) then
		NPCScan:SetMinimapFrame(FarmHudCluster);
	end
	if (Bloodhound2) and (Bloodhound2.ReparentMinimap) then
		Bloodhound2.ReparentMinimap(FarmHudCluster,"FarmHud");
	end
	if LibStub.libs["HereBeDragons-Pins-1.0"] then
		LibStub("HereBeDragons-Pins-1.0"):SetMinimapObject(FarmHudCluster);
	end
	if (LibHijackMinimap) then
		LibHijackMinimap:HijackMinimap(LibHijackMinimap_Token,FarmHudMinimap);
	end
end

function FarmHud_OnHide(self, force)
	MinimapBackdrop:Show();
	if _G.Minimap==FarmHudMinimap then
		FarmHudMinimap:SetAlpha(mps.alpha);
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
	if LibStub.libs["HereBeDragons-Pins-1.0"] then
		LibStub("HereBeDragons-Pins-1.0"):SetMinimapObject();
	end
	if (LibHijackMinimap) then
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
				hide = false,
				minimapPos = 220,
				radius = 80
			};
		end

		for k,v in pairs(dbDefaults)do
			if (FarmHudDB[k]==nil) then
				FarmHudDB[k]=v;
			end
		end

		if FarmHudDB.MinimapIcon.show~=nil then
			FarmHudDB.MinimapIcon.hide = not FarmHudDB.MinimapIcon.show;
			FarmHudDB.MinimapIcon.show = nil;
		end

		if (LDBIcon) then
			LDBIcon:Register(addon, LDB, FarmHudDB.MinimapIcon);
		end

		fh_font = {SystemFont_Small2:GetFont()};

		FarmHud:SetFrameLevel(2);
		FarmHudCluster:SetFrameLevel(3);

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

	FarmHudCluster.GetZoom = function()
		return _G.Minimap:GetZoom();
	end

	FarmHudCluster.SetZoom = function()
		-- dummy
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
