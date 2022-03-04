
local addon,ns=...;
local L=ns.L;
local ACD = LibStub("AceConfigDialog-3.0");
local HBD = LibStub("HereBeDragons-2.0")
local HBDPins = LibStub("HereBeDragons-Pins-2.0")

FarmHudMixin = {};

local _G,type,wipe,tinsert,unpack,tostring = _G,type,wipe,tinsert,unpack,tostring;
local GetPlayerFacing,C_Map = GetPlayerFacing,C_Map;
local Minimap_OnClick = Minimap_OnClick;

ns.QuestArrowToken = {};
ns.modules = {};
local modEvents,events = {},{VARIABLES_LOADED=true,PLAYER_ENTERING_WORLD=true,PLAYER_LOGIN=true,PLAYER_LOGOUT=true,MODIFIER_STATE_CHANGED=true};
local LibHijackMinimap_Token,TrackingIndex,LibHijackMinimap,_ = {},{};
local media, media_blizz = "Interface\\AddOns\\"..addon.."\\media\\", "Interface\\Minimap\\";
local mps,Minimap,MinimapMT,mouseOnKeybind,Dummy = {},_G.Minimap,getmetatable(_G.Minimap).__index;
local minimapScripts,cardinalTicker,coordsTicker = {--[["OnMouseUp",]]"OnMouseDown","OnDragStart"};
local playerDot_orig, playerDot_custom = "Interface\\Minimap\\MinimapArrow";
local TrackingIndex,timeTicker = {};
local knownProblematicAddOns, knownProblematicAddOnsDetected = {BasicMinimap=true},{};
local SetPointToken,SetParentToken = {},{};
local trackingTypes,trackingTypesStates,numTrackingTypes,trackingHookLocked = {},{},0,false;
local MinimapFunctionHijacked --= {"SetParent","ClearAllPoints","SetAllPoints","GetPoint","GetNumPoints"};
local PrintTokens,rotationMode,IsOpened = {
	FarmHud_QuestArrow = {}
};
local foreignObjects,anchoredFrames = {},{ -- <name[string]>
	-- Blizzard
	"TimeManagerClockButton", -- required if foreign addon changed
	"GameTimeFrame", -- required if foreign addon changed
	"TimerTracker",
	"MinimapBackdrop", -- required if foreign addon changed
	"MinimapNorthTag",
	"MinimapCompassTexture",
	"MiniMapTracking",
	"MinimapZoomIn",
	"MinimapZoomOut",
	"MinimapZoneText",
	"MiniMapWorldMapButton",
	"GarrisonLandingPageMinimapButton",
	-- MinimapButtonFrame
	--"MBB_MinimapButtonFrame",
	-- SexyMap
	--"SexyMapCustomBackdrop",
	"QueueStatusMinimapButton",
	-- chinchilla minimap
	"Chinchilla_Coordinates_Frame",
	"Chinchilla_Location_Frame",
	"Chinchilla_Compass_Frame",
	"Chinchilla_Appearance_MinimapCorner1",
	"Chinchilla_Appearance_MinimapCorner2",
	"Chinchilla_Appearance_MinimapCorner3",
	"Chinchilla_Appearance_MinimapCorner4",
	-- obeliskminimap
	"ObeliskMinimapZoneText",
	"ObeliskMinimapInformationFrame",
	-- Lorti-UI / Lorti-UI-Classic
	"rBFS_BuffDragFrame",
	"rBFS_DebuffDragFrame",
	-- BtWQuests
	"BtWQuestsMinimapButton",
	-- GW2_UI
	"GwQuestTracker",
	"GwAddonToggle",
	"GwCalendarButton",
	"GwGarrisonButton",
	"GwMailButton",
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
local minimapCreateTextureTable = {};
local trackEnableMouse,suppressNextMouseEnable = false,false; -- try to get more info for mouse enable bug


do
	local addon_short = "FH";
	local colors = {"82c5ff","00ff00","ff6060","44ffff","ffff00","ff8800","ff44ff","ffffff"};
	local debugMode = "@project-version@" == "@".."project-version".."@";
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
	function ns.debug(...)
		--print(colorize("<debug>",...));
		ConsolePrint(date("|cff999999%X|r"),colorize(...));
	end
	function ns.debugPrint(...)
		if not debugMode then return end
		print(colorize("<debug>",...))
	end
	if debugMode then
		_G[addon.."_GetNamespace"] = function()
			return ns;
		end
	end
end

do
	function ns.IsClassic()
		return WOW_PROJECT_ID==WOW_PROJECT_CLASSIC;
	end
	function ns.IsClassicBC()
		return WOW_PROJECT_ID==WOW_PROJECT_BURNING_CRUSADE_CLASSIC;
	end
	function ns.IsRetail()
		return WOW_PROJECT_ID==WOW_PROJECT_MAINLINE;
	end
end

local function SetPlayerDotTexture(bool) -- executed by FarmHud:UpdateOptions(), FrameHud:OnShow(), FarmHud:OnHide() and FarmHud:OnLoad()
	local tex = media.."playerDot-"..FarmHudDB.player_dot
	if FarmHudDB.player_dot=="blizz" or not bool then
		tex = playerDot_custom or playerDot_orig;
	end
	MinimapMT.SetPlayerTexture(Minimap,tex);
end

-- tracking options

function ns.GetTrackingTypes()
	if ns.IsClassic() then return {}; end
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


-- repalce CreateTexture function from Minimap to get access on nameless texture created by foreign addons; i hate such activity but forced to do...

do
	local Minimap_CreateTexture = Minimap.CreateTexture;
	function Minimap:CreateTexture(...)
		local byAddOn = ({strsplit("\\", ({strsplit("\n",debugstack())})[2] )})[3];
		local tex = Minimap_CreateTexture(self,...);
		tinsert(minimapCreateTextureTable,tex);
		return tex;
	end
end

-- dummyOnly; prevent changes by foreign addons while farmhud is visible

local function dummyOnly_SetPoint(self,point,relTo,relPoint,x,y)
	if relTo==Minimap or relTo=="Minimap" then
		relTo = Dummy
	end
	return self[SetPointToken](self,point,relTo,relPoint,x,y);
end

local function dummyOnly_SetParent(self,parent)
	if parent==Minimap or parent=="Minimap" then
		parent = Dummy;
	end
	return self[SetParentToken](self,parent);
end

-- function replacements for Minimap while FarmHud is enabled.
-- Should prevent problems with repositioning of minimap buttons from other addons.
local replacements,addHooks
do
	local alreadyHooked,useDummy,lockedBy = {};
	local function MinimapOrDummy(func,...)
		if useDummy then
			return Dummy[func](Dummy,...);
		end
		return MinimapMT[func](Minimap,...);
	end
	replacements = {
		GetWidth = function() return MinimapOrDummy("GetWidth") end,
		GetHeight = function() return MinimapOrDummy("GetHeight") end,
		GetSize = function() return MinimapOrDummy("GetSize") end,
		GetCenter = function() return Dummy :GetCenter() end,
		GetEffectiveScale = function() return Dummy :GetEffectiveScale() end,
		GetLeft = function() return Dummy :GetLeft() end,
		GetRight = function() return Dummy :GetRight() end,
		GetBottom = function() return Dummy :GetBottom() end,
		GetTop = function() return Dummy :GetTop() end,
	}
	local function objHookStart(self)
		if lockedBy~=false then return end
		lockedBy = self;
		useDummy = true;
		ns.debugPrint(self :GetDebugName(),true);
	end
	local function objHookStop(self)
		if lockedBy~=self then
			return
		end
		useDummy = false;
		ns.debugPrint(self :GetDebugName(),false);
	end
	function addHooks(obj)
		if alreadyHooked[obj] then
			return;
		end
		alreadyHooked[obj] = true;
		local objMT = getmetatable(obj).__index;
		objMT .HookScript(obj,"OnEnter",objHookStart);
		objMT .HookScript(obj,"OnDragStart",objHookStart);
		objMT .HookScript(obj,"OnLeave",objHookStop);
		objMT .HookScript(obj,"OnDragStop",objHookStop);
	end
end

-- move anchoring of objects from minimap to dummy and back
local objSetPoint = {};
local objSetParent = {};
local function objectToDummy(object,enable,debugStr)

	-- == ignore == --
	if (HBDPins and HBDPins.minimapPins[object]) -- ignore herebedragons pins
	then
		return;
	end

	-- == prepare == --
	local changedSetParent,changedSetPoint,objType = false,false,object:GetObjectType()
	if objSetParent[objType] == nil then
		objSetParent[objType] = getmetatable(object).__index.SetParent;
	end
	if objSetPoint[objType]==nil then
		objSetPoint[objType] = getmetatable(object).__index.SetPoint;
	end

	-- == parent == --

	-- get strata/layer/level info
	local fstrata,flevel,dlayer,dlevel
	if object.GetDrawLayer then
		dlayer,dlevel = object:GetDrawLayer(); -- textures
	else
		fstrata = object:GetFrameStrata(); -- frames
		flevel = object:GetFrameLevel();
	end

	local parent = object:GetParent();
	if enable==true and parent==Minimap then
		objSetParent[objType](object,Dummy);
		changedSetParent = true;
	elseif enable==false and parent==Dummy then
		objSetParent[objType](object,Minimap);
		changedSetParent = true;
	end

	if changedSetParent then
		-- replace SetParent function
		if enable then
			object[SetParentToken],object.SetParent = object.SetParent,dummyOnly_SetParent;
		else
			object.SetParent,object[SetParentToken] = object[SetParentToken],nil;
		end
		-- reapply strata/layer/level after change of parent
		if dlayer then
			object:SetDrawLayer(dlayer,dlevel);
		else
			object:SetFrameStrata(fstrata);
			object:SetFrameLevel(flevel);
			addHooks(object)
		end
	end

	-- == anchors == --
	local changedSetPoint = false; -- reset for SetPoint

	-- search and change anchors on minimap
	for p=1, (object:GetNumPoints()) do
		local point,relTo,relPoint,x,y = object:GetPoint(p);
		if enable==true and relTo==Minimap then
			objSetPoint[objType](object,point,Dummy,relPoint,x,y);
			changedSetPoint=true;
		elseif enable==false and relTo==Dummy then
			objSetPoint[objType](object,point,Minimap,relPoint,x,y);
			changedSetPoint=true;
		end
	end

	if changedSetPoint then
		-- replace SetPoint function
		if enable then
			object[SetPointToken],object.SetPoint = object.SetPoint,dummyOnly_SetPoint;
		else
			object.SetPoint,object[SetPointToken] = object[SetPointToken],nil;
		end
	end

	return changedSetParent,changedSetPoint;
end

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
	MinimapMT.SetScale(Minimap,FarmHudDB.hud_scale);
	MinimapMT.SetSize(Minimap,MinimapScaledSize, MinimapScaledSize);

	self.cluster:SetScale(FarmHudDB.hud_scale);
	self.cluster:SetSize(MinimapScaledSize, MinimapScaledSize);
	self.cluster:SetFrameStrata(Minimap:GetFrameStrata());
	self.cluster:SetFrameLevel(Minimap:GetFrameLevel());

	local gcSize = MinimapSize * 0.432;
	self.gatherCircle:SetSize(gcSize, gcSize);
	self.healCircle:SetSize(gcSize/2.11, gcSize/2.11);

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
	local Map = state and self.cluster or Minimap;

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
			MinimapMT.SetAlpha(Minimap,FarmHudDB.background_alpha);
		elseif IsKey(key,"player_dot") then
			SetPlayerDotTexture(true);
		elseif IsKey(key,"mouseoverinfo_color") then
			self.TextFrame.mouseWarn:SetTextColor(unpack(FarmHudDB.mouseoverinfo_color));
		elseif IsKey(key,"gathercircle_show") then
			self.gatherCircle:SetShown(FarmHudDB.gathercircle_show);
		elseif IsKey(key,"gathercircle_color") or key=="gathercircle_resetcolor" then
			self.gatherCircle:SetVertexColor(unpack(FarmHudDB.gathercircle_color));
		elseif IsKey(key,"healcircle_show") then
			self.healCircle:SetShown(FarmHudDB.healcircle_show);
		elseif IsKey(key,"healcircle_color") or key=="healcircle_resetcolor" then
			self.healCircle:SetVertexColor(unpack(FarmHudDB.healcircle_color));
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
			Dummy.bg:SetShown(FarmHudDB.showDummyBg and (not HybridMinimap or (HybridMinimap and not HybridMinimap:IsShown())) );
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
	trackEnableMouse = true;

	Dummy:SetParent(Minimap:GetParent());
	Dummy:SetScale(Minimap:GetScale());
	Dummy:SetSize(Minimap:GetSize());
	Dummy:SetFrameStrata(Minimap:GetFrameStrata());
	Dummy:SetFrameLevel(Minimap:GetFrameLevel());
	Dummy:ClearAllPoints();
	for i=1, Minimap:GetNumPoints() do
		Dummy:SetPoint(Minimap:GetPoint(i));
	end
	Dummy.bg:SetShown(FarmHudDB.showDummyBg and (not HybridMinimap or (HybridMinimap and not HybridMinimap:IsShown())) );
	Dummy:SetShown(FarmHudDB.showDummy);
	self.cluster:Show();

	-- cache some data from minimap
	mps.anchors = {};
	mps.childs = {};
	mps.replacements = {};
	mps.zoom = Minimap:GetZoom();
	mps.parent = Minimap:GetParent();
	mps.scale = Minimap:GetScale();
	mps.size = {Minimap:GetSize()};
	mps.strata = Minimap:GetFrameStrata();
	mps.level = Minimap:GetFrameLevel();
	mps.mouse = Minimap:IsMouseEnabled();
	mps.mousewheel = Minimap:IsMouseWheelEnabled();
	mps.alpha = Minimap:GetAlpha();
	mps.backdropMouse = MinimapBackdrop:IsMouseEnabled();

	-- cache mouse enable state
	local onmouseup = Minimap:GetScript("OnMouseUp");
	if onmouseup~=Minimap_OnClick then
		mps.ommouseup = onmouseup;
		MinimapMT.SetScript(Minimap,"OnMouseUp",Minimap_OnClick);
	end

	-- cache non original frame script entries from foreign addons
	for _,action in ipairs(minimapScripts)do
		local fnc = Minimap:GetScript(action);
		if fnc then
			mps[action] = fnc;
			MinimapMT.SetScript(Minimap,action,nil);
		end
	end

	-- cache minimap anchors
	for i=1, Minimap:GetNumPoints() do
		mps.anchors[i] = {Minimap:GetPoint(i)};
	end

	-- move child and regions of a frame to FarmHudDummy
	for object,movedElements in pairs(foreignObjects) do
		local parent,point
		-- childs
		local childs = {object:GetChildren()};
		for i=1, #childs do
			parent,point = objectToDummy(childs[i],true,"OnShow.GetChildren");
			if parent or point then
				tinsert(movedElements.childs,childs[i]);
			end
		end

		-- child textures/fontstrings
		local regions = {object:GetRegions()};
		for r=1, #regions do
			parent,point = objectToDummy(regions[r],true,"OnShow.GetRegions");
			if parent or point then
				tinsert(movedElements.regions,regions[r]);
			end
		end
	end

	-- reanchor named frames that not have minimap as parent but anchored on it
	mps.anchoredFrames = {};
	for i=1, #anchoredFrames do
		if _G[anchoredFrames[i]] then
			mps.anchoredFrames[i]=true;
			objectToDummy(_G[anchoredFrames[i]],true,"OnShow.anchoredFrames");
		end
	end

	-- nameless textures
	if #minimapCreateTextureTable>0 then
		for i=1, #minimapCreateTextureTable do
			objectToDummy(minimapCreateTextureTable[i],true,"OnShow.minimapCreateTextureTable");
		end
	end

	-- move and change minimap for FarmHud
	MinimapMT.SetParent(Minimap,FarmHud);
	MinimapMT.ClearAllPoints(Minimap);
	-- sometimes SetPoint produce error "because[SetPoint would result in anchor family connection]"
	local f, err = loadstring('Minimap:SetPoint("CENTER",0,0)');
	if f then f(); else
		MinimapMT.SetAllPoints(Minimap); -- but SetAllPoints results in an offset for somebody
		MinimapMT.ClearAllPoints(Minimap);
		MinimapMT.SetPoint(Minimap,"CENTER",0,0); -- next try...
	end
	MinimapMT.SetFrameStrata(Minimap,"BACKGROUND");
	MinimapMT.SetFrameLevel(Minimap,1);
	MinimapMT.SetScale(Minimap,1);
	MinimapMT.SetZoom(Minimap,0);
	MinimapMT.SetAlpha(Minimap,FarmHudDB.background_alpha);

	suppressNextMouseEnable = true;
	MinimapMT.EnableMouse(Minimap,false);
	MinimapMT.EnableMouseWheel(Minimap,false);

	local mc_points = {MinimapCluster:GetPoint()};
	if mc_points[2]==Minimap then
		mps.mc_mouse = MinimapCluster:IsMouseEnabled();
		mps.mc_mousewheel = MinimapCluster:IsMouseWheelEnabled();
		MinimapCluster:EnableMouse(false);
		MinimapCluster:EnableMouseWheel(false);
	end

	mps.rotation = GetCVar("rotateMinimap");
	if FarmHudDB.rotation ~= (mps.rotation=="1") then
		rotationMode = FarmHudDB.rotation and "1" or "0";
		SetCVar("rotateMinimap", rotationMode, "ROTATE_MINIMAP");
		Minimap_UpdateRotationSetting();
	end

	-- function replacements for Minimap while FarmHud is enabled.
	-- Should prevent problems with repositioning of minimap buttons from other addons.
	for k,v in pairs(replacements)do
		mps.replacements[k] = Minimap[k];
		Minimap[k] = v;
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

	-- second try to suppress mouse enable state
	suppressNextMouseEnable = true;
	MinimapMT.EnableMouse(Minimap,false);
	MinimapMT.EnableMouseWheel(Minimap,false);

	for modName,mod in pairs(ns.modules)do
		if mod.OnShow then
			mod.OnShow();
		end
	end
end

function FarmHudMixin:OnHide()
	if rotationMode ~= mps.rotation then
		SetCVar("rotateMinimap", mps.rotation, "ROTATE_MINIMAP");
		rotationMode = mps.rotation
		Minimap_UpdateRotationSetting();
	end

	trackEnableMouse = false;

	-- restore function replacements for Minimap
	for k in pairs(replacements)do
		Minimap[k] = mps.replacements[k];
	end

	Minimap:SetParent(mps.parent);
	Minimap.SetScale(Minimap,mps.scale);
	MinimapMT.SetSize(Minimap,unpack(mps.size));
	MinimapMT.SetFrameStrata(Minimap,mps.strata);
	MinimapMT.SetFrameLevel(Minimap,mps.level);
	MinimapMT.EnableMouse(Minimap,mps.mouse);
	MinimapMT.EnableMouseWheel(Minimap,mps.mousewheel);

	MinimapMT.SetAlpha(Minimap,mps.alpha);

	Dummy.bg:Hide();
	Dummy:Hide();
	self.cluster:Hide();

	if mps.ommouseup then
		MinimapMT.SetScript(Minimap,"OnMouseUp",mps.ommouseup);
	end

	for _,action in ipairs(minimapScripts)do
		if type(mps[action])=="function" then
			MinimapMT.SetScript(Minimap,action,mps[action]);
		end
	end

	Minimap:ClearAllPoints();
	for i=1, #mps.anchors do
		Minimap:SetPoint(unpack(mps.anchors[i]));
	end

	-- move child frames and regions (textures/fontstrings) of a frame back agian to Minimap
	for object,movedElements in pairs(foreignObjects) do
		-- childs
		for i=1, #movedElements.childs do
			objectToDummy(movedElements.childs[i],false,"OnHide.GetChildren");
		end
		wipe(movedElements.childs);

		-- child textures/fontstrings
		for r=1, #movedElements.regions do
			objectToDummy(movedElements.regions[r],false,"OnHide.GetRegions");
		end
		wipe(movedElements.regions);
	end

	-- anchored frames by name
	for i=1, #anchoredFrames do
		if mps.anchoredFrames[i] then
			objectToDummy(_G[anchoredFrames[i]],false,"OnHide.anchoredFrames");
		end
	end

	-- nameless textures
	if #minimapCreateTextureTable>0 then
		for i=1, #minimapCreateTextureTable do
			objectToDummy(minimapCreateTextureTable[i],false,"OnHide.minimapCreateTextureTable");
		end
	end

	if mps.mc_mouse then
		MinimapCluster:EnableMouse(true);
	end
	if mps.mc_mousewheel then
		MinimapCluster:EnableMouseWheel(true);
	end

	local maxLevels = Minimap:GetZoomLevels();
	if mps.zoom>maxLevels then mps.zoom = maxLevels; end
	MinimapMT.SetZoom(Minimap,mps.zoom);

	if FarmHud_ToggleSuperTrackedQuest and FarmHudDB.SuperTrackedQuest then
		FarmHud_ToggleSuperTrackedQuest(ns.QuestArrowToken,false); -- FarmHud_QuestArrow
	end

	wipe(mps);

	for modName,mod in pairs(ns.modules)do
		if mod.OnHide then
			mod.OnHide();
		end
	end

	SetPlayerDotTexture(false);
	TrackingTypes_Update(false);

	self:UpdateCardinalPoints(false);
	self:UpdateCoords(false);
	self:UpdateTime(false);
	self:UpdateForeignAddOns(false);

	if mps.backdropMouse~=MinimapBackdrop:IsMouseEnabled() then
		MinimapBackdrop:EnableMouse(mps.backdropMouse);
	end
end

local function checkOnKnownProblematicAddOns()
	wipe(knownProblematicAddOnsDetected);
	for addOnName,bool in pairs(knownProblematicAddOns) do
		if bool and (IsAddOnLoaded(addOnName)) then
			tinsert(knownProblematicAddOnsDetected,addOnName);
		end
	end
end

--- RegisterForeignAddOnObject
-- Register a frame or button or other type to help avoid problems with FarmHud.
-- FarmHud check childs and regions of the object and change SetPoint anchored from Minimap to FarmHudDummy
-- while FarmHud is enabled and OnHide back again.
-- @object: object - a frame table that is anchored on Minimap and holds texture, fontstrings or other elements that should be moved to FarmHudDummy while FarmHud is enabled.
-- @byAddOn: string - name of the addon. this will be disable warning message on toggle FarmHud.
-- @return: boolean - true on success

function FarmHudMixin:RegisterForeignAddOnObject(object,byAddOn)
	local arg1Type,arg2Type = type(object),type(byAddOn);
	assert(arg1Type=="table" and object.GetObjectType,"Argument #1 (called object) must be a table (frame,button,...), got "..arg1Type);
	assert(arg2Type=="string","Argument #2 (called byAddOn) must be a string, got "..arg2Type);
	foreignObjects[object] = {childs={},regions={},byAddOn=byAddOn};
	if knownProblematicAddOns[byAddOn] then
		knownProblematicAddOns[byAddOn] = nil; -- remove addon from knownProblematicAddOns table
		checkOnKnownProblematicAddOns();
	end
	return false;
end

-- Toggle FarmHud display
function FarmHudMixin:Toggle(force)
	if #knownProblematicAddOnsDetected>0 then
		ns.print("|cffffee00"..L["KnownProblematicAddOnDetected"].."|r","|cffff8000("..table.concat(knownProblematicAddOnsDetected,", ")..")|r")
	end
	if force==nil then
		force = not self:IsShown();
	end
	if force and MinimapFunctionHijacked then
		local isHijacked = {};
		for i=1, #MinimapFunctionHijacked do
			local k = MinimapFunctionHijacked[i];
			if MinimapMT[k] ~= Minimap[k] then
				local _,taintBy = issecurevariable(Minimap,k);
				tinsert(isHijacked,k.." ("..(taintBy or UNKNOWN)..")");
			end
		end
		if #isHijacked>0 then
			ns.print("|cffffee00"..L["AnotherAddOnsHijackedFunc"].."|r",table.concat(isHijacked,", "));
			return;
		end
	end
	self:SetShown(force);
end

-- Toggle the mouse to check out herb / ore tooltips
function FarmHudMixin:ToggleMouse(force)
	if Minimap:GetParent()==self then
		if (force==nil and Minimap:IsMouseEnabled()) or force then
			suppressNextMouseEnable = true;
			MinimapMT.EnableMouse(Minimap,false);
			self.TextFrame.mouseWarn:Hide();
			if not force then
				mouseOnKeybind = true;
			end
		else
			suppressNextMouseEnable = true;
			MinimapMT.EnableMouse(Minimap,true);
			self.TextFrame.mouseWarn:Show();
			if not force then
				mouseOnKeybind = false;
			end
		end
	end
end

function FarmHudMixin:ToggleBackground()
	if Minimap:GetParent()==self then
		MinimapMT.SetAlpha(Minimap,Minimap:GetAlpha()==0 and FarmHudDB.background_alpha or 0);
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

function FarmHudMixin:RegisterModule(name,module)
	assert(type(name)=="string" and type(module)=="table", "FarmHud:RegisterModule(<moduleName[string]>, <module[table]>)" );
	ns.modules[name] = module;

	for event in pairs(events) do
		if module[event] and type(module[event])=="function" then
			tinsert(modEvents[event],module[event]);
		end
	end

	if type(module.OnLoad)=="function" then
		module:OnLoad();
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
		if (FarmHudDB.healcircle_show) then
			self.healCircle:Show();
		end

		self.gatherCircle:SetVertexColor(unpack(FarmHudDB.gathercircle_color));
		self.healCircle:SetVertexColor(unpack(FarmHudDB.healcircle_color));

		local radius = Minimap:GetWidth() * 0.214;
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

		if BasicMinimap and BasicMinimap.backdrop then
			self:RegisterForeignAddOnObject(BasicMinimap.backdrop:GetParent(),"BasicMinimap");
		end

		checkOnKnownProblematicAddOns()
	elseif event=="PLAYER_LOGOUT" and mps.rotation and rotationMode and rotationMode~=mps.rotation then
		-- reset rotation on logout and reload if FarmHud was open
		SetCVar("rotateMinimap", mps.rotation, "ROTATE_MINIMAP");
	elseif event=="MODIFIER_STATE_CHANGED" and self:IsShown() then
		local key, down = ...;
		if not mouseOnKeybind and modifiers[FarmHudDB.holdKeyForMouseOn] and modifiers[FarmHudDB.holdKeyForMouseOn][key]==1 then
			self:ToggleMouse(down==0);
		end
	end
	for _,modEventFunc in ipairs(modEvents[event])do
		if modEventFunc then
			modEventFunc(...);
		end
	end
end

function FarmHudMixin:OnLoad()
	Dummy = FarmHudMinimapDummy;
	Dummy.bg:SetMask("interface/CHARACTERFRAME/TempPortraitAlphaMask");

	self:RegisterForeignAddOnObject(Minimap,addon);

	hooksecurefunc(Minimap,"SetPlayerTexture",function(_,texture)
		if FarmHud:IsVisible() then
			playerDot_custom = texture;
			SetPlayerDotTexture(true);
		end
	end);

	hooksecurefunc(Minimap,"SetZoom",function(_,level)
		if FarmHud:IsVisible() and level~=0 then
			MinimapMT.SetZoom(Minimap,0);
		end
	end);

	hooksecurefunc(Minimap,"SetAlpha",function(_,level)
		if FarmHud:IsVisible() and FarmHudDB.background_alpha~=level then
			MinimapMT.SetAlpha(Minimap,FarmHudDB.background_alpha);
		end
	end);

	hooksecurefunc(Minimap,"SetMaskTexture",function(_,texture)
		Dummy.bg:SetMask(texture);
	end);

	hooksecurefunc(Minimap,"EnableMouse",function(_,bool)
		if not trackEnableMouse or suppressNextMouseEnable then
			suppressNextMouseEnable = false;
			return
		end
		ns.print(L.PleaseReportThisMessage,"<EnableMouse>",bool,"|n"..debugstack());
	end);

	if not ns.IsClassic() then
		hooksecurefunc("SetTracking",function(index,bool)
			if not trackingHookLocked and FarmHud:IsVisible() and trackingTypesStates[index]~=nil then
				trackingTypesStates[index]=nil;
			end
		end);
	end

	function self.cluster:GetZoom()
		return Minimap:GetZoom();
	end

	function self.cluster:SetZoom()
		-- dummy
	end

	for event in pairs(events) do
		self:RegisterEvent(event);
		modEvents[event] = {};
	end

	FarmHudMixin=nil;
end

