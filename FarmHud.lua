
local addon,ns=...;
local L=ns.L;
local ACD = LibStub("AceConfigDialog-3.0");

FarmHudMixin = {};

local LibHijackMinimap_Token,AreaBorderStates,TrackingIndex,LibHijackMinimap,_ = {},{},{};
local media, media_blizz = "Interface\\AddOns\\"..addon.."\\media\\", "Interface\\Minimap\\";
local mps,mouseOnKeybind,MinimapEnableMouse,MinimapSetAlpha = {}; -- minimap_prev_state
local minimapScripts,cardinalTicker,coordsTicker = {--[["OnMouseUp",]]"OnMouseDown","OnDragStart"};
local playerDot_orig, playerDot_custom = "Interface\\Minimap\\MinimapArrow";
local TrackingIndex,setAlphaToken,timeTicker={},{};
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
	_G.Minimap:SetPlayerTexture(tex);
end

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
	if MinimapEnableMouse and _G.Minimap.EnableMouse~=MinimapEnableMouse then
		_G.Minimap.EnableMouse = MinimapEnableMouse;
	end
end

local function SetAlpha(self,alpha,lockedToken)
	if lockedToken~=setAlphaToken then return end
	MinimapSetAlpha(self,alpha);
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
	local x, y = 1,1;
	if GetPlayerMapPosition then -- removed in bfa
		x,y = GetPlayerMapPosition("player");
	elseif C_Map and C_Map.GetPlayerMapPosition then
		local obj = C_Map.GetPlayerMapPosition(C_Map.GetBestMapForUnit("player"),"player");
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
		FarmHud.TextFrame.time:SetText(h..":"..m);
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

function FarmHudMixin:SetScales()
	self:SetPoint("CENTER");

	local size = UIParent:GetHeight();
	self:SetSize(size,size);

	local MinimalScaledSize = size / FarmHudDB.hud_scale;
	_G.Minimap:SetScale(FarmHudDB.hud_scale);
	_G.Minimap:SetSize(MinimalScaledSize, MinimalScaledSize);

	local _size = size * 0.435;
	self.gatherCircle:SetSize(_size, _size);

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
end

function FarmHudMixin:UpdateScale()
	if not self:IsShown() then return end
end

function FarmHudMixin:UpdateForeignAddOns(state)
	local Map = state and self or _G.Minimap;

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
	if LibHijackMinimap then
		LibHijackMinimap:ReleaseMinimap(LibHijackMinimap_Token,state and Map or nil);
	end
end

do
	local function IsKey(k1,k2)
		return k1==k2 or k1==nil;
	end
	function FarmHudMixin:UpdateOptions(key)
		if not self:IsShown() then return end

		self:SetScales();

		if IsKey(key,"background_alpha") then
			_G.Minimap:SetAlpha(FarmHudDB.background_alpha);
		elseif IsKey(key,"player_dot") and self.PlayerDotLock then
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
	self.PlayerDotLock = true;
	self.ZoomLock = true;

	mps.anchors = {};
	mps.childs = {};
	mps.zoom = _G.Minimap:GetZoom();
	mps.parent = _G.Minimap:GetParent();
	mps.scale = _G.Minimap:GetScale();
	mps.size = {_G.Minimap:GetSize()};
	mps.level = _G.Minimap:GetFrameLevel();
	mps.mouse = _G.Minimap:IsMouseEnabled();
	mps.mousewheel = _G.Minimap:IsMouseWheelEnabled();
	mps.alpha = _G.Minimap:GetAlpha();

	local onmouseup = _G.Minimap:GetScript("OnMouseUp");
	if onmouseup~=Minimap_OnClick then
		mps.ommouseup = onmouseup;
		_G.Minimap:SetScript("OnMouseUp",Minimap_OnClick);
	end

	for _,action in ipairs(minimapScripts)do
		local fnc = _G.Minimap:GetScript(action);
		if fnc then
			mps[action] = fnc;
			_G.Minimap:SetScript(action,nil);
		end
	end

	for i=1, _G.Minimap:GetNumPoints() do
		mps.anchors[i] = {_G.Minimap:GetPoint(i)};
	end

	if SexyMapCustomBackdrop then
		SexyMapCustomBackdrop:SetParent(FarmHud.HideElements);
	end

	local childs = {_G.Minimap:GetChildren()};
	for i=1, #childs do
		if not (childs[i].arrow and childs[i].point) then -- try to ignore HereBeDragonPins
			mps.childs[i] = {childs[i]:IsShown(),childs[i]:GetAlpha()};
			--childs[i].fh_prev = {childs[i]:IsShown(),childs[i]:GetAlpha()};
			childs[i]:Hide();
			childs[i]:SetAlpha(0);
		end
	end

	_G.Minimap:ClearAllPoints();
	_G.Minimap:SetParent(FarmHud);
	_G.Minimap:SetPoint("CENTER");
	_G.Minimap:SetFrameLevel(1);
	_G.Minimap:SetScale(1);
	_G.Minimap:SetZoom(0);

	mps.setAlphaFunc=_G.Minimap.SetAlpha;
	_G.Minimap.SetAlpha = SetAlpha;
	_G.Minimap:SetAlpha(0,setAlphaToken);

	CheckEnableMouse();
	_G.Minimap:EnableMouse(false);
	_G.Minimap:EnableMouseWheel(false);

	local mc_points = {MinimapCluster:GetPoint(i)};
	if mc_points[2]==Minimap then
		mps.mc_mouse = MinimapCluster:IsMouseEnabled();
		mps.mc_mousewheel = MinimapCluster:IsMouseWheelEnabled();
		MinimapCluster:EnableMouse(false);
		MinimapCluster:EnableMouseWheel(false);
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

	self:SetScales();
	self:UpdateCardinalPoints(FarmHudDB.cardinalpoints_show);
	self:UpdateCoords(FarmHudDB.coords_show);
	self:UpdateTime(FarmHudDB.time_show);
	self:UpdateForeignAddOns(true);
end

function FarmHudMixin:OnHide(force)
	if mps.rotation=="0" then
		SetCVar("rotateMinimap", mps.rotation, "ROTATE_MINIMAP");
		ns.rotation = nil;
	end

	_G.Minimap:SetScale(mps.scale);
	_G.Minimap:SetSize(unpack(mps.size));
	_G.Minimap:SetFrameLevel(mps.level);
	_G.Minimap:SetParent(mps.parent);
	_G.Minimap:ClearAllPoints();
	_G.Minimap:EnableMouse(mps.mouse);
	_G.Minimap:EnableMouseWheel(mps.mousewheel);

	_G.Minimap:SetAlpha(mps.alpha,setAlphaToken);
	_G.Minimap.SetAlpha = mps.setAlphaFunc;

	if mps.ommouseup then
		_G.Minimap:SetScript("OnMouseUp",mps.ommouseup);
	end

	for _,action in ipairs(minimapScripts)do
		if type(mps[action])=="function" then
			_G.Minimap:SetScript(action,mps[action]);
		end
	end

	for i=1, #mps.anchors do
		_G.Minimap:SetPoint(unpack(mps.anchors[i]));
	end

	if SexyMapCustomBackdrop then
		SexyMapCustomBackdrop:SetParent(_G.Minimap);
	end

	local childs = {_G.Minimap:GetChildren()};
	for i=1, #childs do
		if mps.childs[i]~=nil then
			childs[i]:SetShown(mps.childs[i][1]);
			childs[i]:SetAlpha(mps.childs[i][2]);
		end
	end

	if mps.mc_mouse then
		MinimapCluster:EnableMouse(true);
	end
	if mps.mc_mousewheel then
		MinimapCluster:EnableMouseWheel(true);
	end

	self.ZoomLock = false;
	local maxLevels = Minimap:GetZoomLevels();
	if mps.zoom>maxLevels then mps.zoom = maxLevels; end
	_G.Minimap:SetZoom(mps.zoom);

	if not FarmHudDB.SuperTrackedQuest and ns.SuperTrackedQuestID~=0 then
		SetSuperTrackedQuestID(ns.SuperTrackedQuestID);
	end

	wipe(mps);

	SetPlayerDotTexture(false);
	self.PlayerDotLock = false;

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
			CheckEnableMouse();
			_G.Minimap:EnableMouse(false);
			self.TextFrame.mouseWarn:Hide();
			if not force then
				mouseOnKeybind = true;
			end
		else
			_G.Minimap:EnableMouse(true);
			self.TextFrame.mouseWarn:Show();
			if not force then
				mouseOnKeybind = false;
			end
		end
	end
end

function FarmHudMixin:GetZoom()
	return _G.Minimap:GetZoom();
end

function FarmHudMixin:SetZoom()
	-- dummy
end

function FarmHudMixin:ToggleBackground()
	if _G.Minimap:GetParent()==self then
		_G.Minimap:SetAlpha(_G.Minimap:GetAlpha()==0 and FarmHudDB.background_alpha or 0,setAlphaToken);
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
			self:ToggleMouse(down==0)
		end
	end
end

function FarmHudMixin:OnLoad()
	local minimapMeta = getmetatable(_G.Minimap).__index;
	MinimapEnableMouse = minimapMeta.EnableMouse; -- original EnableMouse function
	MinimapSetAlpha = minimapMeta.SetAlpha; -- original SetAlpha function

	hooksecurefunc(_G.Minimap,"SetPlayerTexture",function(_,texture)
		if not self.PlayerDotLock then
			playerDot_custom = texture;
		end
	end);

	hooksecurefunc(_G.Minimap,"SetZoom",function(_,level)
		if self.ZoomLock and level~=0 then _G.Minimap:SetZoom(0); end
	end);

	hooksecurefunc("SetSuperTrackedQuestID",function(questID)
		questID = tonumber(questID) or 0;
		if questID~=0 and not FarmHudDB.SuperTrackedQuest and FarmHud:IsVisible() then
			ns.SuperTrackedQuestID = questID;
			SetSuperTrackedQuestID(0);
		end
	end);

	self:RegisterEvent("ADDON_LOADED");
	self:RegisterEvent("PLAYER_LOGIN");
	self:RegisterEvent("PLAYER_LOGOUT");
	self:RegisterEvent("MODIFIER_STATE_CHANGED");

	FarmHudMixin=nil;
end
