
local addon,ns=...;
local L=ns.L;
local ACD = LibStub("AceConfigDialog-3.0");

FarmHudMixin = {};

local _G,type,wipe,tinsert,unpack,tostring = _G,type,wipe,tinsert,unpack,tostring;
local GetPlayerFacing,C_Map = GetPlayerFacing,C_Map;
local Minimap_OnClick = Minimap_OnClick;

ns.QuestArrowToken = {};
local LibHijackMinimap_Token,TrackingIndex,LibHijackMinimap,_ = {},{};
local media, media_blizz = "Interface\\AddOns\\"..addon.."\\media\\", "Interface\\Minimap\\";
local mps,MinimapMT,mouseOnKeybind,Dummy = {},getmetatable(_G.Minimap).__index;
local minimapScripts,cardinalTicker,coordsTicker = {--[["OnMouseUp",]]"OnMouseDown","OnDragStart"};
local playerDot_orig, playerDot_custom = "Interface\\Minimap\\MinimapArrow";
local TrackingIndex,timeTicker={};
local SetPointToken,SetParentToken = {},{};
local trackingTypes,trackingTypesStates,numTrackingTypes,trackingHookLocked = {},{},0,false;
local anchoredFrames = { -- <name[string]>, <SetPoint[bool]>, <SetParent[bool]>
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
	"MinimapZoneText",true,false,
	"MiniMapWorldMapButton",true,true,
	"GarrisonLandingPageMinimapButton",true,true,
	-- MinimapButtonFrame
	"MBB_MinimapButtonFrame",true,true,
	-- SexyMap
	"SexyMapCustomBackdrop",true,true,
	"QueueStatusMinimapButton",true,true,
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
	-- Lorti-UI / Lorti-UI-Classic
	"rBFS_BuffDragFrame",true,false,
	"rBFS_DebuffDragFrame",true,false,
	-- BtWQuests
	"BtWQuestsMinimapButton",true,true,
};
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

do
	local addon_short = "FH";
	local colors = {"0099ff","00ff00","ff6060","44ffff","ffff00","ff8800","ff44ff","ffffff"};
	local function colorize(...)
		local t,c,a1 = {tostringall(...)},1,...;
		if type(a1)=="boolean" then tremove(t,1); end
		if a1~=false then
			local header = addon;
			if a1==true then
				header = addon_short;
			elseif a1=="||" then
				header = "||";
			elseif a1=="()" then
				header = header .. " (" ..t[2]..")";
				tremove(t,2);
				tremove(t,1);
			end
			tinsert(t,1,"|cff0099ff"..header.."|r"..(a1~="||" and HEADER_COLON or ""));
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
	function ns.debug(...)
		--print(colorize("<debug>",...));
		ConsolePrint(date("|cff999999%X|r"),colorize(...));
	end
end

ns.IsClassic = IsClassic or IsClassicClient;
if not ns.IsClassic then
	local version,build,datestr,interface = GetBuildInfo()
	function ns.IsClassic()
		return interface<20000;
	end
end

local function SetPlayerDotTexture(bool) -- executed by FarmHud:UpdateOptions(), FrameHud:OnShow(), FarmHud:OnHide() and FarmHud:OnLoad()
	local tex = media.."playerDot-"..FarmHudDB.player_dot
	if FarmHudDB.player_dot=="blizz" or not bool then
		tex = playerDot_custom or playerDot_orig;
	end
	MinimapMT.SetPlayerTexture(_G.Minimap,tex);
end

-- tracking options

function ns.GetTrackingTypes()
	if ns.IsClassic() then
		return {};
	end
	local num = GetNumTrackingTypes();
	if numTrackingTypes~=num then
		numTrackingTypes = num;
		wipe(trackingTypes);
		for i=1, num do
			local name, textureId, active, objType, objLevel, objId = GetTrackingInfo(i);
			trackingTypes[textureId] = {index=i,name=name,active=active,level=objLevel};
		end
	end
	return trackingTypes;
end

local function TrackingTypes_Update(bool, id)
	if ns.IsClassic() then return end
	if tonumber(id) then
		local key,data = "tracking^"..id,trackingTypes[id];
		local _, _, active = GetTrackingInfo(data.index);
		trackingHookLocked = true;
		if bool then
			if FarmHudDB[key]=="client" then
				if trackingTypesStates[data.index]~=nil then
					SetTracking(data.index,trackingTypesStates[data.index]);
					trackingTypesStates[data.index] = nil;
				end
			elseif FarmHudDB[key]~=tostring(active) then
				if trackingTypesStates[data.index]==nil then
					trackingTypesStates[data.index] = active;
				end
				SetTracking(data.index,FarmHudDB[key]=="true");
			end
		elseif not bool and trackingTypesStates[data.index]~=nil then
			SetTracking(data.index,trackingTypesStates[data.index]);
			trackingTypesStates[data.index] = nil;
		end
		trackingHookLocked = false;
	else
		ns.GetTrackingTypes();
		for id, data in pairs(trackingTypes) do
			if FarmHudDB["tracking^"..id]=="true" or FarmHudDB["tracking^"..id]=="false" then
				TrackingTypes_Update(bool, id);
			end
		end
	end
end

-- dummyOnly; prevent changes by foreign addons while farmhud is visible

local function dummyOnly_SetPoint(self,a,b,c,d,e)
	return self[SetPointToken](self,a,(b==_G.Minimap or b=="Minimap") and Dummy or b,c,d,e);
end

local function dummyOnly_SetParent(self,parent)
	if parent==_G.Minimap or p=="Minimap" then
		return self[SetParentToken](self,Dummy);
	end
	return self[SetParentToken](self,parent);
end

local function objectToDummy(object,enable,doSetPoint,doSetParent)
	local parent,fstrata,flevel,dlayer,dlevel = object:GetParent();
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
			object.SetPoint = enable and dummyOnly_SetPoint or object[SetPointToken];
		end
	end
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
			object.SetParent = dummyOnly_SetParent;
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
	return parent;
end


-- function replacements for _G.Minimap while FarmHud is enabled.
-- Should prevent problems with repositioning of minimap buttons from other addons.
local replacements = {
	GetWidth = function() return Dummy:GetWidth() end,
	GetHeight = function() return Dummy:GetHeight() end,
	GetSize = function() return Dummy:GetSize() end,
	GetCenter = function() return Dummy:GetCenter() end,
	GetEffectiveScale = function() return Dummy:GetEffectiveScale() end,
	GetLeft = function() return Dummy:GetLeft() end,
	GetRight = function() return Dummy:GetRight() end,
	GetBottom = function() return Dummy:GetBottom() end,
	GetTop = function() return Dummy:GetTop() end,
}


-- cardinal points

local function CardinalPointsUpdate_TickerFunc()
	local bearing = GetPlayerFacing();
	local scaledRadius = FarmHud.TextFrame.ScaledHeight * FarmHudDB.cardinalpoints_radius;
	for i=1, #FarmHud.TextFrame.cardinalPoints do
		local v = FarmHud.TextFrame.cardinalPoints[i];
		v:ClearAllPoints();
		if bearing then
			v:SetPoint("CENTER", FarmHud, "CENTER", math.sin(v.rot+bearing)*scaledRadius, math.cos(v.rot+bearing)*scaledRadius);
		end
	end
end

function FarmHudMixin:UpdateCardinalPoints(state)
	if not cardinalTicker and state~=false then
		cardinalTicker = C_Timer.NewTicker(1/24, CardinalPointsUpdate_TickerFunc);
	elseif cardinalTicker and state==false then
		cardinalTicker:Cancel();
		cardinalTicker = nil;
	end
	if not GetPlayerFacing() then
		state = false;
	end
	for i,e in ipairs(self.TextFrame.cardinalPoints) do
		e:SetShown(state);
	end
end

-- coordinates

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
		coordsTicker = C_Timer.NewTicker(1/24,CoordsUpdate_TickerFunc);
	elseif state==false and coordsTicker then
		coordsTicker:Cancel();
		coordsTicker=nil;
	end
	self.TextFrame.coords:SetShown(state);
end

-- time

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

-- main frame functions

function FarmHudMixin:SetScales(enabled)
	local self = FarmHud;
	local eScale = UIParent:GetEffectiveScale();
	local width,height,size = WorldFrame:GetSize();
	width,height = width/eScale,height/eScale;
	size = height;
	if width<height then
		size = width;
	end
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

	local y = (self:GetHeight()*FarmHudDB.buttons_radius) * 0.5;
	if (FarmHudDB.buttons_bottom) then y = -y; end
	self.onScreenButtons:ClearAllPoints();
	self.onScreenButtons:SetPoint("CENTER", self, "CENTER", 0, y);

	self.TextFrame:SetScale(FarmHudDB.text_scale);
	self.TextFrame.ScaledHeight = (self:GetHeight()/FarmHudDB.text_scale) * 0.5;

	local coords_y = self.TextFrame.ScaledHeight * FarmHudDB.coords_radius;
	local time_y = self.TextFrame.ScaledHeight * FarmHudDB.time_radius;
	if (FarmHudDB.coords_bottom) then coords_y = -coords_y; end
	if (FarmHudDB.time_bottom) then time_y = -time_y; end

	self.TextFrame.coords:ClearAllPoints()
	self.TextFrame.time:ClearAllPoints()
	self.TextFrame.mouseWarn:ClearAllPoints()

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
	local HBD1 = LibStub.libs["HereBeDragons-Pins-1.0"];
	if HBD1 and HBD1.SetMinimapObject then
		HBD1:SetMinimapObject(state and Map or nil);
	end
	local HBD2 = LibStub.libs["HereBeDragons-Pins-2.0"];
	if HBD2 and HBD2.SetMinimapObject then
		HBD2:SetMinimapObject(state and Map or nil);
	end
	if LibStub.libs["HereBeDragonsQuestie-Pins-2.0"] then
		LibStub("HereBeDragonsQuestie-Pins-2.0"):SetMinimapObject(state and Map or nil);
	end
	if LibHijackMinimap then
		LibHijackMinimap:ReleaseMinimap(LibHijackMinimap_Token,state and Map or nil);
	end
end

do
	-- the following part apply some config changes while FarmHud is enabled
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
		elseif IsKey(key,"showDummy") then
			Dummy:SetShown(FarmHudDB.showDummy);
		elseif IsKey(key,"showDummyBg") then
			Dummy.bg:SetShown(FarmHudDB.showDummyBg);
		elseif key:find("tracking^%d+") and not ns.IsClassic() then
			local _, id = strsplit("^",key);
			id = tonumber(id);
			TrackingTypes_Update(true,id);
		elseif key:find("rotation") then
			rotationMode = FarmHudDB.rotation and "1" or "0";
			SetCVar("rotateMinimap", rotationMode, "ROTATE_MINIMAP");
			Minimap_UpdateRotationSetting();
		elseif IsKey(key,"SuperTrackedQuest") and FarmHud_ToggleSuperTrackedQuest and FarmHud:IsShown() then
			FarmHud_ToggleSuperTrackedQuest(ns.QuestArrowToken,FarmHudDB.SuperTrackedQuest);
		elseif IsKey(key,"hud_size") then
			FarmHud:SetScales();
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
	Dummy.bg:SetShown(FarmHudDB.showDummyBg);
	Dummy:SetShown(FarmHudDB.showDummy);
	self.cluster:Show();

	-- cache some data from minimap
	mps.anchors = {};
	mps.childs = {};
	mps.replacements = {};
	mps.zoom = _G.Minimap:GetZoom();
	mps.parent = _G.Minimap:GetParent();
	mps.scale = _G.Minimap:GetScale();
	mps.size = {_G.Minimap:GetSize()};
	mps.strata = _G.Minimap:GetFrameStrata();
	mps.level = _G.Minimap:GetFrameLevel();
	mps.mouse = _G.Minimap:IsMouseEnabled();
	mps.mousewheel = _G.Minimap:IsMouseWheelEnabled();
	mps.alpha = _G.Minimap:GetAlpha();

	-- cache mouse enable state
	local onmouseup = _G.Minimap:GetScript("OnMouseUp");
	if onmouseup~=Minimap_OnClick then
		mps.ommouseup = onmouseup;
		MinimapMT.SetScript(_G.Minimap,"OnMouseUp",Minimap_OnClick);
	end

	-- cache non original frame script entries from foreign addons
	for _,action in ipairs(minimapScripts)do
		local fnc = _G.Minimap:GetScript(action);
		if fnc then
			mps[action] = fnc;
			MinimapMT.SetScript(_G.Minimap,action,nil);
		end
	end

	-- cache minimap anchors
	for i=1, _G.Minimap:GetNumPoints() do
		mps.anchors[i] = {_G.Minimap:GetPoint(i)};
	end

	-- reanchor named frames that not have minimap as parent but anchored on it
	mps.anchoredFrames = {};
	for i=1, #anchoredFrames, 3 do
		if _G[anchoredFrames[i]] then
			mps.anchoredFrames[i]=true;
			objectToDummy(_G[anchoredFrames[i]],true,anchoredFrames[i+1],anchoredFrames[i+2]);
		end
	end

	-- move child frames to dummy frame
	local childs = {_G.Minimap:GetChildren()};
	for i=1, #childs do
		if not (childs[i].arrow and childs[i].point) or not childs[i].keep==true then -- try to ignore HereBeDragonPins
			objectToDummy(childs[i],true,true,true);
		end
	end

	-- move child textures to dummy frame; required by sexymap
	local regions = {_G.Minimap:GetRegions()};
	for r=1, #regions do
		objectToDummy(regions[r],true,true,true);
	end

	-- move and change minimap for FarmHud
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

	mps.rotation = GetCVar("rotateMinimap");
	if FarmHudDB.rotation ~= (mps.rotation=="1") then
		rotationMode = FarmHudDB.rotation and "1" or "0";
		SetCVar("rotateMinimap", rotationMode, "ROTATE_MINIMAP");
		Minimap_UpdateRotationSetting();
	end

	-- function replacements for _G.Minimap while FarmHud is enabled.
	-- Should prevent problems with repositioning of minimap buttons from other addons.
	for k,v in pairs(replacements)do
		mps.replacements[k] = _G.Minimap[k];
		_G.Minimap[k] = v;
	end

	if FarmHud_ToggleSuperTrackedQuest and FarmHudDB.SuperTrackedQuest then
		FarmHud_ToggleSuperTrackedQuest(ns.QuestArrowToken,true); -- FarmHud_QuestArrow
	end

	SetPlayerDotTexture(true);
	TrackingTypes_Update(true);

	self:SetScales(true);
	self:UpdateCardinalPoints(FarmHudDB.cardinalpoints_show);
	self:UpdateCoords(FarmHudDB.coords_show);
	self:UpdateTime(FarmHudDB.time_show);
end

function FarmHudMixin:OnHide(force)
	if rotationMode ~= mps.rotation then
		SetCVar("rotateMinimap", mps.rotation, "ROTATE_MINIMAP");
		rotationMode = mps.rotation
		Minimap_UpdateRotationSetting();
	end

	-- restore function replacements for _G.Minimap
	for k in pairs(replacements)do
		_G.Minimap[k] = mps.replacements[k];
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
	Dummy:Hide();
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
			objectToDummy(_G[anchoredFrames[i]],false,anchoredFrames[i+1],anchoredFrames[i+2]);
		end
	end

	local childs = {Dummy:GetChildren()}; -- child frames
	for i=1, #childs do
		objectToDummy(childs[i],false,true,true);
	end

	local regions = {Dummy:GetRegions()}; -- child textures and more; mostly by sexymap
	for r=1, #regions do
		objectToDummy(regions[r],false,true,true);
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

	if FarmHud_ToggleSuperTrackedQuest and FarmHudDB.SuperTrackedQuest then
		FarmHud_ToggleSuperTrackedQuest(ns.QuestArrowToken,false); -- FarmHud_QuestArrow
	end

	wipe(mps);

	SetPlayerDotTexture(false);
	TrackingTypes_Update(false);

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
		ACD.OpenFrames[addon]:SetStatusText(GAME_VERSION_LABEL..CHAT_HEADER_SUFFIX.."@project-version@");
	end
end

function FarmHudMixin:AddChatMessage(token,msg)
	local from = (token==ns.QuestArrowToken and "QuestArrow") or false
	if from and type(msg)=="string" then
		ns.print("()",from,L[msg]);
	end
end

function FarmHudMixin:OnEvent(event,...)
	if event=="VARIABLES_LOADED" then
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

	if not ns.IsClassic() then
		hooksecurefunc("SetTracking",function(index,bool)
			if not trackingHookLocked and FarmHud:IsVisible() and trackingTypesStates[index]~=nil then
				trackingTypesStates[index]=nil;
			end
		end);
	end

	function self.cluster:GetZoom()
		return _G.Minimap:GetZoom();
	end

	function self.cluster:SetZoom()
		-- dummy
	end

	self:RegisterEvent("VARIABLES_LOADED");
	self:RegisterEvent("PLAYER_LOGIN");
	self:RegisterEvent("PLAYER_LOGOUT");
	self:RegisterEvent("MODIFIER_STATE_CHANGED");

	FarmHudMixin=nil;
end

