
local addon,ns=...;
local L=ns.L;
local ACD = LibStub("AceConfigDialog-3.0");

FarmHudMixin = {};

local _G,type,wipe,tinsert,unpack,tostring = _G,type,wipe,tinsert,unpack,tostring;
local GetPlayerFacing,C_Map = GetPlayerFacing,C_Map;
local Minimap_OnClick = Minimap_OnClick;

local LibHijackMinimap_Token,AreaBorderStates,TrackingIndex,LibHijackMinimap,_ = {},{},{};
local media, media_blizz = "Interface\\AddOns\\"..addon.."\\media\\", "Interface\\Minimap\\";
local mps,MinimapMT,mouseOnKeybind,Dummy = {},getmetatable(_G.Minimap).__index;
local minimapScripts,cardinalTicker,coordsTicker = {--[["OnMouseUp",]]"OnMouseDown","OnDragStart"};
local playerDot_orig, playerDot_custom = "Interface\\Minimap\\MinimapArrow";
local TrackingIndex,timeTicker={};
local SetPointToken,SetParentToken = {},{};
local breadcrumps = {path={},pool={}};
local anchoredFrames = { -- <name[string]>, <SetParent[bool]>, <SetPoint[bool]>,
	-- Blizzard
	"TimeManagerClockButton",true,true,
	"GameTimeFrame",true,true,
	"TimerTracker",true,true,
	"MinimapBackdrop",true,true,
	"MinimapNorthTag",true,true,
	"MinimapCompassTexture",true,true,
	"MiniMapTracking",true,true,
	"MinimapZoomIn",true,true,
	"MinimapZoomOut",true,true,
	"MiniMapWorldMapButton",true,true,
	"GarrisonLandingPageMinimapButton",true,true,
	-- MinimapButtonFrame
	"MBB_MinimapButtonFrame",true,true,
	-- SexyMap
	"SexyMapCustomBackdrop",true,true,
	-- chinchilla minimap
	"Chinchilla_Coordinates_Frame",true,true,
	"Chinchilla_Location_Frame",true,true,
	"Chinchilla_Compass_Frame",true,true,
	"Chinchilla_Appearance_MinimapCorner1",true,true,
	"Chinchilla_Appearance_MinimapCorner2",true,true,
	"Chinchilla_Appearance_MinimapCorner3",true,true,
	"Chinchilla_Appearance_MinimapCorner4",true,true,
	-- obeliskminimap
	"ObeliskMinimapZoneText",true,true,
	"ObeliskMinimapInformationFrame",true,true,
};
ns.SuperTrackedQuestID = 0;
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

local debugMode = "@project-version@"=="@".."project-version".."@";
function ns.debug(...)
	if debugMode then
		ns.print("<debug>",...);
	end
end

local function SetPlayerDotTexture(bool)
	local tex = media.."playerDot-"..FarmHudDB.player_dot
	if FarmHudDB.player_dot=="blizz" or not bool then
		tex = playerDot_custom or playerDot_orig;
	end
	MinimapMT.SetPlayerTexture(_G.Minimap,tex);
end

-- unusable. changes from lower to upper values are ignored by blizzards api.
local function AreaBorder_SetAlpha(Type,Value)
	if not (Type=="Arch" or Type=="Quest" or Type=="Task") then return end
	_G.Minimap["Set"..Type.."BlobInsideAlpha"](Value);
	_G.Minimap["Set"..Type.."BlobOutsideAlpha"](Value);
	_G.Minimap["Set"..Type.."BlobRingAlpha"](Value);
end

local function AreaBorder_SetTexture(Type,Inside,Outside,Ring,Selected)
	if not (Type=="Arch" or Type=="Quest" or Type=="Task") then return end
	_G.Minimap["Set"..Type.."BlobInsideTexture"](Inside);
	_G.Minimap["Set"..Type.."BlobOutsideTexture"](Outside);
	_G.Minimap["Set"..Type.."BlobRingTexture"](Ring);
	if t=="Quest" and Selected then
		_G.Minimap["Set"..v.."BlobOutsideSelectedTexture"](Selected);
	end
end

local function AreaBorder_Update(bool, key, dbValue)
	if key then
		local _, _, active = GetTrackingInfo(TrackingIndex[key]);
		if bool and dbValue~=tostring(active) then
			AreaBorderStates[key] = active;
			SetTracking(TrackingIndex[key],dbValue=="true");
		elseif not bool and AreaBorderStates[key]~=nil then
			SetTracking(TrackingIndex[key],AreaBorderStates[key]);
			AreaBorderStates[key] = nil;
		end
	else
		local num = GetNumTrackingTypes();
		if TrackingIndex.NumTypes~=num then
			TrackingIndex.NumTypes = num;
			for i=1, num do
				local name = GetTrackingInfo(i);
				if name==MINIMAP_TRACKING_DIGSITES then
					TrackingIndex.Arch = i;
				elseif name==MINIMAP_TRACKING_QUEST_POIS then
					TrackingIndex.Quest = i;
				end
			end
		end
		if FarmHudDB.areaborder_arch_show~="blizz" then
			AreaBorder_Update(bool, "Arch", FarmHudDB.areaborder_arch_show);
		end
		if FarmHudDB.areaborder_quest_show~="blizz" then
			AreaBorder_Update(bool, "Quest", FarmHudDB.areaborder_quest_show);
		end
	end
end

local function dummyOnlySetPoint(self,a,b,c,d,e)
	return self[SetPointToken](self,a,(b==_G.Minimap or b=="Minimap") and Dummy or b,c,d,e);
end

local function dummyOnlySetParent(self,parent)
	if parent==_G.Minimap or p=="Minimap" then
		return self[SetParentToken](self,Dummy);
	end
	return self[SetParentToken](self,parent);
end

local function objectToDummy(object,doSetPoint,doSetParent,enable)
	local parent,fstrata,flevel,dlayer,dlevel = object:GetParent();
	if doSetParent then
		if object.GetDrawLayer then
			dlayer,dlevel = object:GetDrawLayer(); -- textures
		else
			fstrata = object:GetFrameStrata(); -- frames
			flevel = object:GetFrameLevel();
		end
		if object[SetParentToken]==nil then
			object[SetParentToken] = object.SetParent;
		end
		if enable==true and parent==_G.Minimap then
			object.SetParent = dummyOnlySetParent;
			object[SetParentToken](object,Dummy);
		elseif enable==false and parent==Dummy then
			object.SetParent = object[SetParentToken];
			object[SetParentToken](object,_G.Minimap);
		end
		if dlayer then
			object:SetDrawLayer(dlayer,dlevel);
		else
			object:SetFrameStrata(fstrata);
			object:SetFrameLevel(flevel);
		end
	end
	if doSetPoint then
		if object[SetPointToken]==nil then
			object[SetPointToken] = object.SetPoint;
		end
		local changed = false;
		for p=1, (object:GetNumPoints()) do
			local point,relTo,relPoint,x,y = object:GetPoint(p);
			if enable==true and relTo==_G.Minimap then
				object[SetPointToken](object,point,Dummy,relPoint,x,y);
				changed=true;
			elseif enable==false and relTo==Dummy then
				object[SetPointToken](object,point,_G.Minimap,relPoint,x,y);
				changed=true;
			end
		end
		if changed then
			object.SetPoint = enable and dummyOnlySetPoint or object[SetPointToken];
		end
	end
	return parent;
end

local function CardinalPointsUpdate_TickerFunc()
	local bearing = GetPlayerFacing();
	if bearing then
		for k, v in ipairs(FarmHud.TextFrame.cardinalPoints) do
			local x, y = math.sin(v.rot + bearing), math.cos(v.rot + bearing);
			v:ClearAllPoints();
			v:SetPoint("CENTER", FarmHud, "CENTER", x * (FarmHud.TextFrame.ScaledHeight * FarmHudDB.cardinalpoints_radius), y * (FarmHud.TextFrame.ScaledHeight * FarmHudDB.cardinalpoints_radius));
		end
	else
		for k, v in ipairs(FarmHud.TextFrame.cardinalPoints) do
			v:ClearAllPoints();
		end
	end
end

function FarmHudMixin:UpdateCardinalPoints(state)
	if not cardinalTicker and state~=false then
		cardinalTicker = C_Timer.NewTicker(1/30, CardinalPointsUpdate_TickerFunc);
	elseif cardinalTicker and state==false then
		cardinalTicker:Cancel();
		cardinalTicker = nil;
	end
	for i,e in ipairs(self.TextFrame.cardinalPoints) do
		e:SetShown(state);
	end
end

local function CoordsUpdate_TickerFunc()
	local x,y,uiMapID = 0,0,C_Map.GetBestMapForUnit("player");
	if uiMapID then
		local obj = C_Map.GetPlayerMapPosition(uiMapID,"player");
		if obj and obj.GetXY then
			x,y = obj:GetXY();
		end
	end
	if x and x>0 then
		FarmHud.TextFrame.coords:SetFormattedText("%.1f, %.1f",x*100,y*100);
	else
		FarmHud.TextFrame.coords:SetText("");
	end
end

function FarmHudMixin:UpdateCoords(state)
	if state==true and coordsTicker==nil then
		coordsTicker = C_Timer.NewTicker(1/30,CoordsUpdate_TickerFunc);
	elseif state==false and coordsTicker then
		coordsTicker:Cancel();
		coordsTicker=nil;
	end
	self.TextFrame.coords:SetShown(state);
end

local function TimeUpdate_TickerFunc()
	if FarmHudDB.time_server then
		local h,m = GetGameTime();
		FarmHud.TextFrame.time:SetFormattedText("%d:%02d",h,m);
	else
		FarmHud.TextFrame.time:SetText(date("%H:%M"));
	end
end

function FarmHudMixin:UpdateTime(state)
	if state==true and timeTicker==nil then
		timeTicker = C_Timer.NewTicker(1,TimeUpdate_TickerFunc);
		TimeUpdate_TickerFunc();
	elseif state==false and timeTicker then
		timeTicker:Cancel();
		timeTicker=nil;
	end
	self.TextFrame.time:SetShown(state);
end

function FarmHudMixin:SetScales(enabled)
	self:SetPoint("CENTER");

	local size = UIParent:GetHeight();
	self:SetSize(size,size);

	local MinimapSize = size * FarmHudDB.hud_size;
	local MinimapScaledSize =  MinimapSize / FarmHudDB.hud_scale;
	MinimapMT.SetScale(_G.Minimap,FarmHudDB.hud_scale);
	MinimapMT.SetSize(_G.Minimap,MinimapScaledSize, MinimapScaledSize);

	self.cluster:SetScale(FarmHudDB.hud_scale);
	self.cluster:SetSize(MinimapScaledSize, MinimapScaledSize);
	self.cluster:SetFrameStrata(_G.Minimap:GetFrameStrata());
	self.cluster:SetFrameLevel(_G.Minimap:GetFrameLevel());

	local gcSize = MinimapSize * 0.432;
	self.gatherCircle:SetSize(gcSize, gcSize);

	local y = ((self:GetHeight()*self:GetScale()) * FarmHudDB.buttons_radius) * 0.5;
	if (FarmHudDB.buttons_bottom) then y = -y; end
	self.onScreenButtons:SetPoint("CENTER", self, "CENTER", 0, y);

	self.TextFrame:SetScale(FarmHudDB.text_scale);
	self.TextFrame.ScaledHeight = ((self:GetHeight()*self:GetScale()) / FarmHudDB.text_scale) * 0.5;

	local coords_y = self.TextFrame.ScaledHeight * FarmHudDB.coords_radius;
	local time_y = self.TextFrame.ScaledHeight * FarmHudDB.time_radius;
	if (FarmHudDB.coords_bottom) then coords_y = -coords_y; end
	if (FarmHudDB.time_bottom) then time_y = -time_y; end

	self.TextFrame.coords:SetPoint("CENTER", self, "CENTER", 0, coords_y);
	self.TextFrame.time:SetPoint("CENTER",self,"CENTER",0, time_y);
	self.TextFrame.mouseWarn:SetPoint("CENTER",self,"CENTER",0,-16);

	if enabled then
		self:UpdateForeignAddOns(true)
	end
end

function FarmHudMixin:UpdateScale()
	if not self:IsShown() then return end
end

function FarmHudMixin:UpdateForeignAddOns(state)
	local Map = state and self.cluster or _G.Minimap;

	if GatherMate2 then
		GatherMate2:GetModule("Display"):ReparentMinimapPins(Map);
	end
	if Routes and Routes.ReparentMinimap then
		Routes:ReparentMinimap(Map);
	end
	if Bloodhound2 and Bloodhound2.ReparentMinimap then
		Bloodhound2.ReparentMinimap(Map,"Minimap");
	end
	if LibStub.libs["HereBeDragons-Pins-1.0"] then
		LibStub("HereBeDragons-Pins-1.0"):SetMinimapObject(state and Map or nil);
	end
	if LibStub.libs["HereBeDragons-Pins-2.0"] then
		LibStub("HereBeDragons-Pins-2.0"):SetMinimapObject(state and Map or nil);
	end
	if LibHijackMinimap then
		LibHijackMinimap:ReleaseMinimap(LibHijackMinimap_Token,state and Map or nil);
	end
end

do
	local function IsKey(k1,k2)
		return k1==k2 or k1==nil;
	end
	function FarmHudMixin:UpdateOptions(key)
		if not self:IsVisible() then return end

		self:SetScales(true);

		if IsKey(key,"background_alpha") then
			MinimapMT.SetAlpha(_G.Minimap,FarmHudDB.background_alpha);
		elseif IsKey(key,"player_dot") then
			SetPlayerDotTexture(true);
		elseif IsKey(key,"mouseoverinfo_color") then
			self.TextFrame.mouseWarn:SetTextColor(unpack(FarmHudDB.mouseoverinfo_color));
		elseif IsKey(key,"gathercircle_show") then
			self.gatherCircle:SetShown(FarmHudDB.gathercircle_show);
		elseif IsKey(key,"gathercircle_color") or key=="gathetcircle_resetcolor" then
			self.gatherCircle:SetVertexColor(unpack(FarmHudDB.gathercircle_color));
		elseif IsKey(key,"cardinalpoints_show") then
			self:UpdateCardinalPoints(FarmHudDB.cardinalpoints_show);
		elseif IsKey(key,"cardinalpoints_color1") or IsKey(key,"cardinalpoints_color2") then
			local col = key=="cardinalpoints_color1";
			for i,e in ipairs(self.TextFrame.cardinalPoints) do
				if e.NWSE==col then
					e:SetTextColor(unpack(FarmHudDB["cardinalpoints_color"..(col and 1 or 2)]));
				end
			end
		elseif IsKey(key,"coords_show") then
			self.TextFrame.coords:SetShown(FarmHudDB.coords_show);
		elseif IsKey(key,"coords_color") then
			self.TextFrame.coords:SetTextColor(unpack(FarmHudDB.coords_color));
		elseif IsKey(key,"time_show") then
			self.TextFrame.time:SetShown(FarmHudDB.time_show);
		elseif IsKey(key,"time_color") then
			self.TextFrame.time:SetTextColor(unpack(FarmHudDB.time_color));
		elseif IsKey(key,"buttons_show") then
			self.onScreenButtons:SetShown(FarmHudDB.buttons_show);
		elseif IsKey(key,"buttons_alpha") then
			self.onScreenButtons:SetAlpha(FarmHudDB.buttons_alpha);
		end
	end
end

function FarmHudMixin:OnShow()
	Dummy:SetParent(_G.Minimap:GetParent());
	Dummy:SetScale(_G.Minimap:GetScale());
	Dummy:SetSize(_G.Minimap:GetSize());
	Dummy:SetFrameStrata(_G.Minimap:GetFrameStrata());
	Dummy:SetFrameLevel(_G.Minimap:GetFrameLevel());
	Dummy:ClearAllPoints();
	for i=1, _G.Minimap:GetNumPoints() do
		Dummy:SetPoint(_G.Minimap:GetPoint(i));
	end
	Dummy.bg:Show();
	self.cluster:Show();

	mps.anchors = {};
	mps.childs = {};
	mps.zoom = _G.Minimap:GetZoom();
	mps.parent = _G.Minimap:GetParent();
	mps.scale = _G.Minimap:GetScale();
	mps.size = {_G.Minimap:GetSize()};
	mps.strata = _G.Minimap:GetFrameStrata();
	mps.level = _G.Minimap:GetFrameLevel();
	mps.mouse = _G.Minimap:IsMouseEnabled();
	mps.mousewheel = _G.Minimap:IsMouseWheelEnabled();
	mps.alpha = _G.Minimap:GetAlpha();

	local onmouseup = _G.Minimap:GetScript("OnMouseUp");
	if onmouseup~=Minimap_OnClick then
		mps.ommouseup = onmouseup;
		MinimapMT.SetScript(_G.Minimap,"OnMouseUp",Minimap_OnClick);
	end

	for _,action in ipairs(minimapScripts)do
		local fnc = _G.Minimap:GetScript(action);
		if fnc then
			mps[action] = fnc;
			MinimapMT.SetScript(_G.Minimap,action,nil);
		end
	end

	for i=1, _G.Minimap:GetNumPoints() do
		mps.anchors[i] = {_G.Minimap:GetPoint(i)};
	end

	mps.anchoredFrames = {};
	for i=1, #anchoredFrames, 3 do
		if _G[anchoredFrames[i]] then
			mps.anchoredFrames[i]=true;
			objectToDummy(_G[anchoredFrames[i]],anchoredFrames[i+1],anchoredFrames[i+2],true);
		end
	end

	local childs = {_G.Minimap:GetChildren()};
	for i=1, #childs do
		if not (childs[i].arrow and childs[i].point) or not childs[i].keep==true then -- try to ignore HereBeDragonPins
			objectToDummy(childs[i],true,true,true);
		end
	end

	local regions = {_G.Minimap:GetRegions()}; -- child textures and more; mostly by sexymap
	for r=1, #regions do
		objectToDummy(regions[r],true,true,true);
	end

	MinimapMT.ClearAllPoints(_G.Minimap);
	MinimapMT.SetParent(_G.Minimap,FarmHud);
	MinimapMT.SetPoint(_G.Minimap,"CENTER");
	MinimapMT.SetFrameStrata(_G.Minimap,"BACKGROUND");
	MinimapMT.SetFrameLevel(_G.Minimap,1);
	MinimapMT.SetScale(_G.Minimap,1);
	MinimapMT.SetZoom(_G.Minimap,0);
	MinimapMT.SetAlpha(_G.Minimap,FarmHudDB.background_alpha);

	MinimapMT.EnableMouse(_G.Minimap,false);
	MinimapMT.EnableMouseWheel(_G.Minimap,false);

	local mc_points = {_G.MinimapCluster:GetPoint(i)};
	if mc_points[2]==Minimap then
		mps.mc_mouse = _G.MinimapCluster:IsMouseEnabled();
		mps.mc_mousewheel = _G.MinimapCluster:IsMouseWheelEnabled();
		_G.MinimapCluster:EnableMouse(false);
		_G.MinimapCluster:EnableMouseWheel(false);
	end

	if FarmHudDB.rotation then
		mps.rotation = GetCVar("rotateMinimap");
		ns.rotation = mps.rotation;
		SetCVar("rotateMinimap", "1", "ROTATE_MINIMAP");
	end

	if not FarmHudDB.SuperTrackedQuest then
		ns.SuperTrackedQuestID = GetSuperTrackedQuestID();
		SetSuperTrackedQuestID(0);
	end

	SetPlayerDotTexture(true);
	AreaBorder_Update(true);

	self:SetScales(true);
	self:UpdateCardinalPoints(FarmHudDB.cardinalpoints_show);
	self:UpdateCoords(FarmHudDB.coords_show);
	self:UpdateTime(FarmHudDB.time_show);
end

function FarmHudMixin:OnHide(force)
	if mps.rotation=="0" then
		SetCVar("rotateMinimap", mps.rotation, "ROTATE_MINIMAP");
		ns.rotation = nil;
		Minimap_UpdateRotationSetting();
	end

	MinimapMT.ClearAllPoints(_G.Minimap);
	MinimapMT.SetParent(_G.Minimap,mps.parent);
	MinimapMT.SetScale(_G.Minimap,mps.scale);
	MinimapMT.SetSize(_G.Minimap,unpack(mps.size));
	MinimapMT.SetFrameStrata(_G.Minimap,mps.strata);
	MinimapMT.SetFrameLevel(_G.Minimap,mps.level);
	MinimapMT.EnableMouse(_G.Minimap,mps.mouse);
	MinimapMT.EnableMouseWheel(_G.Minimap,mps.mousewheel);

	MinimapMT.SetAlpha(_G.Minimap,mps.alpha);

	Dummy.bg:Hide();
	self.cluster:Hide();

	if mps.ommouseup then
		MinimapMT.SetScript(_G.Minimap,"OnMouseUp",mps.ommouseup);
	end

	for _,action in ipairs(minimapScripts)do
		if type(mps[action])=="function" then
			MinimapMT.SetScript(_G.Minimap,action,mps[action]);
		end
	end

	for i=1, #mps.anchors do
		MinimapMT.SetPoint(_G.Minimap,unpack(mps.anchors[i]));
	end

	for i=1, #anchoredFrames, 3 do
		if mps.anchoredFrames[i] then
			objectToDummy(_G[anchoredFrames[i]],anchoredFrames[i+1],anchoredFrames[i+2],false);
		end
	end

	local childs = {Dummy:GetChildren()}; -- child frames
	for i=1, #childs do
		objectToDummy(childs[i],true,true,false);
	end

	local regions = {Dummy:GetRegions()}; -- child textures and more; mostly by sexymap
	for r=1, #regions do
		objectToDummy(regions[r],true,true,false);
	end

	if mps.mc_mouse then
		MinimapCluster:EnableMouse(true);
	end
	if mps.mc_mousewheel then
		MinimapCluster:EnableMouseWheel(true);
	end

	local maxLevels = Minimap:GetZoomLevels();
	if mps.zoom>maxLevels then mps.zoom = maxLevels; end
	MinimapMT.SetZoom(_G.Minimap,mps.zoom);

	if not FarmHudDB.SuperTrackedQuest and ns.SuperTrackedQuestID~=0 then
		SetSuperTrackedQuestID(ns.SuperTrackedQuestID);
	end

	wipe(mps);

	SetPlayerDotTexture(false);
	AreaBorder_Update(false);

	self:UpdateCardinalPoints(false);
	self:UpdateCoords(false);
	self:UpdateTime(false);
	self:UpdateForeignAddOns(false);

	MinimapBackdrop:Show();
end

-- Toggle FarmHud display
function FarmHudMixin:Toggle(force)
	if force==nil then
		force = not self:IsShown();
	end
	self:SetShown(force);
end

-- Toggle the mouse to check out herb / ore tooltips
function FarmHudMixin:ToggleMouse(force)
	if _G.Minimap:GetParent()==self then
		if (force==nil and _G.Minimap:IsMouseEnabled()) or force then
			MinimapMT.EnableMouse(_G.Minimap,false);
			self.TextFrame.mouseWarn:Hide();
			if not force then
				mouseOnKeybind = true;
			end
		else
			MinimapMT.EnableMouse(_G.Minimap,true);
			self.TextFrame.mouseWarn:Show();
			if not force then
				mouseOnKeybind = false;
			end
		end
	end
end

function FarmHudMixin:ToggleBackground()
	if _G.Minimap:GetParent()==self then
		MinimapMT.SetAlpha(_G.Minimap,_G.Minimap:GetAlpha()==0 and FarmHudDB.background_alpha or 0);
	end
end

function FarmHudMixin:ToggleOptions()
	if ACD.OpenFrames[addon]~=nil then
		ACD:Close(addon);
	else
		ACD:Open(addon);
		ACD.OpenFrames[addon]:SetStatusText(GAME_VERSION_LABEL..": @project-version@");
	end
end

function FarmHudMixin:OnEvent(event,...)
	if event=="ADDON_LOADED" and ...==addon then
		ns.RegisterOptions();
		ns.RegisterDataBroker();
		if FarmHudDB.AddOnLoaded then
			ns.print(L.AddOnLoaded);
		end
	elseif event=="PLAYER_LOGIN" then
		self:SetFrameLevel(2);

		if (FarmHudDB.gathercircle_show) then
			self.gatherCircle:Show();
		end

		self.gatherCircle:SetVertexColor(unpack(FarmHudDB.gathercircle_color));

		local radius = _G.Minimap:GetWidth() * 0.214;
		for i, v in ipairs(self.TextFrame.cardinalPoints) do
			local label = v:GetText();
			v.NWSE = strlen(label)==1;
			v.rot = (0.785398163 * (i-1));
			v:SetText(L[label]);
			v:SetTextColor(1.0,0.82,0);
			if v.NWSE then
				v:SetTextColor(unpack(FarmHudDB.cardinalpoints_color1));
			else
				v:SetTextColor(unpack(FarmHudDB.cardinalpoints_color2));
			end
		end

		if (FarmHudDB.coords_show) then
			self.TextFrame.coords:Show();
		end

		self.TextFrame.coords:SetTextColor(unpack(FarmHudDB.coords_color));

		self.TextFrame.time:SetTextColor(unpack(FarmHudDB.time_color));

		if (FarmHudDB.buttons_show) then
			self.onScreenButtons:Show();
		end
		self.onScreenButtons:SetAlpha(FarmHudDB.buttons_alpha);

		self.TextFrame.mouseWarn:SetText(L.MouseOn);
		self.TextFrame.mouseWarn:SetTextColor(unpack(FarmHudDB.mouseoverinfo_color));

		if(LibStub.libs['LibHijackMinimap-1.0'])then
			LibHijackMinimap = LibStub('LibHijackMinimap-1.0');
			LibHijackMinimap:RegisterHijacker(addon,LibHijackMinimap_Token);
		end
	elseif event=="PLAYER_LOGOUT" then
		self:Toggle(false);
	elseif event=="MODIFIER_STATE_CHANGED" and self:IsShown() then
		local key, down = ...;
		if not mouseOnKeybind and modifiers[FarmHudDB.holdKeyForMouseOn] and modifiers[FarmHudDB.holdKeyForMouseOn][key]==1 then
			self:ToggleMouse(down==0);
		end
	end
end

function FarmHudMixin:OnLoad()
	Dummy = FarmHudMinimapDummy;
	Dummy.bg:SetMask("interface/CHARACTERFRAME/TempPortraitAlphaMask");

	hooksecurefunc(_G.Minimap,"SetPlayerTexture",function(_,texture)
		if FarmHud:IsVisible() then
			playerDot_custom = texture;
			SetPlayerDotTexture(true);
		end
	end);

	hooksecurefunc(_G.Minimap,"SetZoom",function(_,level)
		if FarmHud:IsVisible() and level~=0 then
			MinimapMT.SetZoom(_G.Minimap,0);
		end
	end);

	hooksecurefunc(_G.Minimap,"SetAlpha",function(_,level)
		if FarmHud:IsVisible() and FarmHudDB.background_alpha~=level then
			MinimapMT.SetAlpha(_G.Minimap,FarmHudDB.background_alpha);
		end
	end);

	hooksecurefunc(_G.Minimap,"SetMaskTexture",function(_,texture)
		Dummy.bg:SetMask(texture);
	end);

	hooksecurefunc("SetSuperTrackedQuestID",function(questID)
		questID = tonumber(questID) or 0;
		if questID~=0 and not FarmHudDB.SuperTrackedQuest and FarmHud:IsVisible() then
			ns.SuperTrackedQuestID = questID;
			SetSuperTrackedQuestID(0);
		end
	end);

	function self.cluster:GetZoom()
		return _G.Minimap:GetZoom();
	end

	function self.cluster:SetZoom()
		-- dummy
	end

	self:RegisterEvent("ADDON_LOADED");
	self:RegisterEvent("PLAYER_LOGIN");
	self:RegisterEvent("PLAYER_LOGOUT");
	self:RegisterEvent("MODIFIER_STATE_CHANGED");

	FarmHudMixin=nil;
end

