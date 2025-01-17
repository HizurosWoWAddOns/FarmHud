
local addon,ns=...;
local L=ns.L;
ns.debugMode = "@project-version@"=="@".."project-version".."@";
LibStub("HizurosSharedTools").RegisterPrint(ns,addon,"FH");

local ACD = LibStub("AceConfigDialog-3.0");
local HBDPins = LibStub("HereBeDragons-Pins-2.0")

FarmHudMixin = {};

local _G,type,wipe,tinsert,unpack,tostring = _G,type,wipe,tinsert,unpack,tostring;
local GetPlayerFacing,C_Map = GetPlayerFacing,C_Map;
local Minimap_OnClick = (MinimapMixin and MinimapMixin.Onclick) or Minimap_OnClick; -- TODO: check it - needed for classic 1.15 / wotlk 3.4.3
local Minimap_UpdateRotationSetting = Minimap_UpdateRotationSetting or function() end -- TODO: check it - need for classic 1.15 / wotlk 3.4.3

ns.QuestArrowToken = {};
local modEvents,events = {},{"ADDON_LOADED","PLAYER_ENTERING_WORLD","PLAYER_LOGIN","PLAYER_LOGOUT","MODIFIER_STATE_CHANGED","PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED"};
local LibHijackMinimap_Token,LibHijackMinimap,_ = {};
local media = "Interface\\AddOns\\"..addon.."\\media\\";
local mps,Minimap,MinimapMT,mouseOnKeybind,Dummy = {},_G.Minimap,getmetatable(_G.Minimap).__index;
local minimapScripts,cardinalTicker,coordsTicker = { --[["OnMouseUp",]] OnMouseDown="Dummy", OnDragStart="nil" };
local playerDot_orig, playerDot_custom = "Interface\\Minimap\\MinimapArrow";
if WOW_PROJECT_ID==WOW_PROJECT_MAINLINE then
	playerDot_orig = "minimaparrow" -- blizzard using atlas entry of ObjectIconsAtlas.blp now
end
local timeTicker;
local knownProblematicAddOns, knownProblematicAddOnsDetected = {BasicMinimap=true},{};
local SetPointToken,SetParentToken = {},{};
local trackingTypes,trackingTypesStates,numTrackingTypes,trackingHookLocked = {},{},0,false;
local MinimapFunctionHijacked --= {"SetParent","ClearAllPoints","SetAllPoints","GetPoint","GetNumPoints"};
local rotationMode,mTI
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

ns.modules = setmetatable({},{
	__newindex = function(t,name,module)
		rawset(t,name,module)
		for _,event in ipairs(events) do
			if module[event] and type(module[event])=="function" then
				if not modEvents[event] then
					modEvents[event] = {}
				end
				tinsert(modEvents[event],name);
			end
		end
	end
})

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
	local _,_,_,b = GetBuildInfo();
	function ns.IsDragonFlight()
		return b>=100000;
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
	local num = C_Minimap.GetNumTrackingTypes();
	if numTrackingTypes~=num then
		numTrackingTypes = num;
		wipe(trackingTypes);
		for i=1, num do
			local info = C_Minimap.GetTrackingInfo(i)
			trackingTypes[info.texture] = {index=i,name=info.name,active=info.active,level=info.subType}
		end
	end
	return trackingTypes;
end

local function TrackingTypes_Update(bool, id)
	if ns.IsClassic() then return end
	if not id then
		ns.GetTrackingTypes();
		for tId in pairs(trackingTypes) do
			if FarmHudDB["tracking^"..tId]=="true" or FarmHudDB["tracking^"..tId]=="false" then
				TrackingTypes_Update(bool, tId);
			end
		end

		if bool==false and mps.minimapTrackedInfov3 then
			-- try to restore on close. blizzard changing it outside the lua code area.
			mTI = mps.minimapTrackedInfov3>0 and mps.minimapTrackedInfov3 or 1006319;
			C_Timer.After(0.314159,function() C_CVar.SetCVar("minimapTrackedInfov3",mTI) end);
		end

		return;
	end
	local key,data = "tracking^"..id,trackingTypes[id];
	local info = C_Minimap.GetTrackingInfo(data.index);
	trackingHookLocked = true;
	if bool then
		if FarmHudDB[key]=="client" then
			if trackingTypesStates[data.index]~=nil then
				C_Minimap.SetTracking(data.index,trackingTypesStates[data.index]);
				trackingTypesStates[data.index] = nil;
			end
		elseif FarmHudDB[key]~=tostring(info.active) then
			if trackingTypesStates[data.index]==nil then
				trackingTypesStates[data.index] = info.active;
			end
			C_Minimap.SetTracking(data.index,FarmHudDB[key]=="true");
		end
	elseif not bool and trackingTypesStates[data.index]~=nil then
		C_Minimap.SetTracking(data.index,trackingTypesStates[data.index]);
		trackingTypesStates[data.index] = nil;
	end
	trackingHookLocked = false;
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
		SetZoom = function(m,z) end, -- prevent zoom
	}
	local function objHookStart(self)
		if lockedBy~=false then return end
		lockedBy = self;
		useDummy = true;
	end
	local function objHookStop(self)
		if lockedBy~=self then
			return
		end
		useDummy = false;
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

	local oType = object:GetObjectType();
	if oType  == "Line" then -- unknown object type "Line" after install a new addon.
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
	if object.GetNumPoints then
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

-- dummy frame mixin functions

FarmHudMinimapDummyMixin = {}

function FarmHudMinimapDummyMixin:OnMouseUp()
	if type(mps.OnMouseUp)~="function" then return end
	mps.OnMouseUp(self);
end

function FarmHudMinimapDummyMixin:OnMouseDown()
	if type(mps.OnMouseDown)~="function" and not type(mps.OnMouseUp)~="function" then
		return -- Ignore OnMouseDown of OnMouseUp present
	end
	mps.OnMouseDown(self);
end

-- main frame mixin functions

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

	self.size = MinimapSize

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
			local id = tonumber((key:match("^tracking%^(%d+)$")));
			if id then
				TrackingTypes_Update(true,id);
			end
		elseif key:find("rotation") then
			rotationMode = FarmHudDB.rotation and "1" or "0";
			C_CVar.SetCVar("rotateMinimap", rotationMode, "ROTATE_MINIMAP");
			Minimap_UpdateRotationSetting();
		elseif IsKey(key,"SuperTrackedQuest") and FarmHud_ToggleSuperTrackedQuest and FarmHud:IsShown() then
			FarmHud_ToggleSuperTrackedQuest(ns.QuestArrowToken,FarmHudDB.SuperTrackedQuest);
		elseif IsKey(key,"hud_size") then
			FarmHud:SetScales();
		end
	end
end

local function Minimap_OnClick(self)
	-- Copy of Minimap_OnClick. Require for replaced functions GetCenter and GetEffectiveScale
	local x, y = GetCursorPosition();
	local s, X,Y = MinimapMT.GetEffectiveScale(Minimap)
	x = x / s;
	y = y / s;

	local cx, cy = MinimapMT.GetCenter(Minimap)
	X = x - cx;
	Y = y - cy;

	if ( sqrt(X * X + Y * Y) < (self:GetWidth() / 2) ) then
		Minimap:PingLocation(X, Y);
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
	mps.minimapTrackedInfov3 = tonumber(GetCVar("minimapTrackedInfov3"));

	-- cache mouse enable state
	local OnMouseUp = Minimap:GetScript("OnMouseUp");
	if OnMouseUp~=Minimap_OnClick then
		mps.OnMouseUp = OnMouseUp;
		MinimapMT.SetScript(Minimap,"OnMouseUp",Minimap_OnClick);
	end

	-- cache non original frame script entries from foreign addons
	for name, todo in pairs(minimapScripts)do
		local fnc = Minimap:GetScript(name);
		if fnc then
			mps[name] = fnc;
			MinimapMT.SetScript(Minimap,name,nil);
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
	for _,frameName in ipairs(anchoredFrames) do
		if _G[frameName] then
			mps.anchoredFrames[frameName]=true;
			objectToDummy(_G[frameName],true,"OnShow.anchoredFrames");
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
	local f, err = loadstring('FarmHud.SetPoint(Minimap,"CENTER",0,0)');
	if f then f() else
		MinimapMT.SetAllPoints(Minimap); -- but SetAllPoints results in an offset for somebody
		MinimapMT.ClearAllPoints(Minimap);
		MinimapMT.SetPoint(Minimap,"CENTER",0,0); -- next try...
	end
	MinimapMT.SetFrameStrata(Minimap,"BACKGROUND");
	MinimapMT.SetFrameLevel(Minimap,1);
	MinimapMT.SetScale(Minimap,1);
	MinimapMT.SetZoom(Minimap,0);
	MinimapMT.SetAlpha(Minimap,FarmHudDB.background_alpha);

	-- disable mouse enabled frames
	suppressNextMouseEnable = true;
	MinimapMT.EnableMouse(Minimap,false);
	MinimapMT.EnableMouseWheel(Minimap,false);

	mps.backdropMouse = MinimapBackdrop:IsMouseEnabled();
	if mps.backdropMouse then
		MinimapBackdrop:EnableMouse(false);
	end

	-- elvui special
	if _G.MMHolder and _G.MMHolder:IsMouseEnabled() then
		mps.mmholder_mouse = true;
		_G.MMHolder:EnableMouse(false);
	elseif _G.ElvUI_MinimapHolder and _G.ElvUI_MinimapHolder:IsMouseEnabled() then
		mps.elvui_mmholder_mouse = true;
		_G.ElvUI_MinimapHolder:EnableMouse(false);
	end

	local mc_points = {MinimapCluster:GetPoint()};
	if mc_points[2]==Minimap then
		mps.mc_mouse = MinimapCluster:IsMouseEnabled();
		mps.mc_mousewheel = MinimapCluster:IsMouseWheelEnabled();
		MinimapCluster:EnableMouse(false);
		MinimapCluster:EnableMouseWheel(false);
	end

	mps.rotation = C_CVar.GetCVar("rotateMinimap");
	if FarmHudDB.rotation ~= (mps.rotation=="1") then
		rotationMode = FarmHudDB.rotation and "1" or "0";
		C_CVar.SetCVar("rotateMinimap", rotationMode, "ROTATE_MINIMAP");
		Minimap_UpdateRotationSetting();
		if not ns.IsDragonFlight() then
			MinimapCompassTexture:Hide(); -- Note: Compass Texture is the new border texture in dragonflight
		end
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
		if type(mod.OnShow)=="function" then
			mod.OnShow();
		elseif type(mod.OnShow)=="table" and type(mod.OnShow.fnc)=="string" and FarmHud[mod.OnShow.fnc] then
			FarmHud[mod.OnShow.fnc](unpack(mod.OnShow.args));
		end
	end
end

function FarmHudMixin:OnHide()
	if rotationMode ~= mps.rotation then
		C_CVar.SetCVar("rotateMinimap", mps.rotation, "ROTATE_MINIMAP");
		rotationMode = mps.rotation
		Minimap_UpdateRotationSetting();
	end

	trackEnableMouse = false;

	-- restore function replacements for Minimap
	for k in pairs(replacements)do
		Minimap[k] = mps.replacements[k];
	end

	MinimapMT.SetParent(Minimap,mps.parent);
	MinimapMT.SetScale(Minimap,mps.scale);
	MinimapMT.SetSize(Minimap,unpack(mps.size));
	MinimapMT.SetFrameStrata(Minimap,mps.strata);
	MinimapMT.SetFrameLevel(Minimap,mps.level);
	MinimapMT.EnableMouse(Minimap,mps.mouse);
	MinimapMT.EnableMouseWheel(Minimap,mps.mousewheel);

	MinimapMT.SetAlpha(Minimap,mps.alpha);

	Dummy.bg:Hide();
	Dummy:Hide();
	self.cluster:Hide();

	if mps.OnMouseUp then
		MinimapMT.SetScript(Minimap,"OnMouseUp",mps.OnMouseUp);
		FarmHudMinimapDummy: SetScript("OnMouseUp",nil);
		FarmHudMinimapDummy: EnableMouse(false);
	end

	for name,todo in pairs(minimapScripts)do
		if type(mps[name])=="function" then
			MinimapMT.SetScript(Minimap,name,mps[name]);
		end
	end

	MinimapMT.ClearAllPoints(Minimap);
	for i=1, #mps.anchors do
		MinimapMT.SetPoint(Minimap,unpack(mps.anchors[i]));
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
	for frameName in pairs(mps.anchoredFrames) do
		if _G[frameName] then
			objectToDummy(_G[frameName],false,"OnHide.anchoredFrames");
		end
	end

	-- nameless textures
	if #minimapCreateTextureTable>0 then
		for i=1, #minimapCreateTextureTable do
			objectToDummy(minimapCreateTextureTable[i],false,"OnHide.minimapCreateTextureTable");
		end
	end

	-- elvui special on hide hud
	if mps.mmholder_mouse then
		_G.MMHolder:EnableMouse(true);
	elseif mps.elvui_mmholder_mouse then
		_G.ElvUI_MinimapHolder:EnableMouse(true);
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
		if type(mod.OnHide)=="function" then
			mod.OnHide();
		elseif type(mod.OnHide)=="table" and type(mod.OnHide.fnc)=="string" and FarmHud[mod.OnHide.fnc] then
			FarmHud[mod.OnHide.fnc](unpack(mod.OnHide.args));
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
		if bool and (C_AddOns.IsAddOnLoaded(addOnName)) then
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
		ns:print("|cffffee00"..L["KnownProblematicAddOnDetected"].."|r","|cffff8000("..table.concat(knownProblematicAddOnsDetected,", ")..")|r")
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
			ns:print("|cffffee00"..L["AnotherAddOnsHijackedFunc"].."|r",table.concat(isHijacked,", "));
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
		ns:print("()",from,L[msg]);
	end
end

function FarmHudMixin:RegisterModule(name,module)
	assert(type(name)=="string" and type(module)=="table", "FarmHud:RegisterModule(<moduleName[string]>, <module[table]>)" );
	ns.modules[name] = module;
end

function FarmHudMixin:OnEvent(event,...)
	if event=="ADDON_LOADED" and addon==... then
		ns.RegisterOptions();
		ns.RegisterDataBroker();
		if FarmHudDB.AddOnLoaded or IsShiftKeyDown() then
			ns:print(L.AddOnLoaded);
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

		--local radius = Minimap:GetWidth() * 0.214;
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
		C_CVar.SetCVar("rotateMinimap", mps.rotation, "ROTATE_MINIMAP");
	elseif event=="MODIFIER_STATE_CHANGED" and self:IsShown() then
		local key, down = ...;
		if not mouseOnKeybind and modifiers[FarmHudDB.holdKeyForMouseOn] and modifiers[FarmHudDB.holdKeyForMouseOn][key]==1 then
			self:ToggleMouse(down==0);
		end
	elseif event=="PLAYER_ENTERING_WORLD" then
		if FarmHudDB.hideInInstance then
			if IsInInstance() and FarmHud:IsShown() then
				self.hideInInstanceActive = true;
				self:Hide() -- hide FarmHud in Instance
			elseif self.hideInInstanceActive then
				self.hideInInstanceActive = nil;
				self:Show(); -- restore visibility on leaving instance
			end
		end
	elseif event=="PLAYER_REGEN_DISABLED" and FarmHudDB.hideInCombat and FarmHud:IsShown() then
		self.hideInCombatActive = true;
		self:Hide() -- hide FarmHud in combat
		return
	elseif event=="PLAYER_REGEN_ENABLED" and FarmHudDB.hideInCombat and self.hideInCombatActive then
		self.hideInCombatActive = nil;
		self:Show(); -- restore visibility after combat
		return;
	end
	if modEvents[event] then
		for _,modName in pairs(modEvents[event])do
			if ns.modules[modName] and ns.modules[modName][event] then
				ns.modules[modName][event](...);
			end
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
		ns:print(L.PleaseReportThisMessage,"<EnableMouse>",bool,"|n"..debugstack());
	end);

	if EditModeManagerFrame and EditModeManagerFrame.IsShown then
		-- Close FarmHud on ShowUIPanel(EditModeManagerFrame) to prevent problems
		hooksecurefunc(EditModeManagerFrame,"IsShown",function(self)
			local dbg = debugstack(); -- nil sucks
			if dbg and dbg:match("ShowUIPanel") then
				FarmHud:Toggle(false);
			end
		end);

		hooksecurefunc(_G,"ShowUIPanel",function(frame)
			if EditModeManagerFrame==frame or frame=="EditModeManagerFrame" then
				FarmHud:Toggle(false)
			end
		end);
	end

	if not ns.IsClassic() then
		local function hookSetTracking(index,bool)
			if not trackingHookLocked and FarmHud:IsVisible() and trackingTypesStates[index]~=nil then
				trackingTypesStates[index]=nil;
			end
		end
		hooksecurefunc(C_Minimap,"SetTracking",hookSetTracking);
	end

	function self.cluster:GetZoom()
		return Minimap:GetZoom();
	end

	function self.cluster:SetZoom()
		-- dummy
	end

	for _,event in ipairs(events) do
		self:RegisterEvent(event);
	end

	for name, module in pairs(ns.modules)do
		if type(module.OnLoad)=="function" then
			module:OnLoad();
		end
	end

end

