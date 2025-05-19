
local addon,ns=...;
local L=ns.L;
ns.debugMode = "@project-version@"=="@".."project-version".."@";
LibStub("HizurosSharedTools").RegisterPrint(ns,addon,"FH");

local ACD = LibStub("AceConfigDialog-3.0");
local HBDPins = LibStub("HereBeDragons-Pins-2.0")

FarmHudMixin = {};

local _G,type,wipe,tinsert,unpack,tostring,C_Map = _G,type,wipe,table.insert,unpack,tostring,C_Map;
local Minimap_OnClick = (MinimapMixin and MinimapMixin.Onclick) or Minimap_OnClick; -- TODO: check it - needed for classic 1.15 / wotlk 3.4.3
local Minimap_UpdateRotationSetting = Minimap_UpdateRotationSetting or function() end -- TODO: check it - need for classic 1.15 / wotlk 3.4.3

ns.QuestArrowToken = {};
local LibHijackMinimap_Token,LibHijackMinimap,_ = {},nil,nil;
local media = "Interface\\AddOns\\"..addon.."\\media\\";
local mps,Minimap,MinimapMT,mouseOnKeybind = {},_G.Minimap,getmetatable(_G.Minimap).__index,nil;
local playerDot_orig, playerDot_custom = "Interface\\Minimap\\MinimapArrow",nil;
if WOW_PROJECT_ID==WOW_PROJECT_MAINLINE then
	playerDot_orig = "minimaparrow" -- blizzard using atlas entry of ObjectIconsAtlas.blp now
end
local timeTicker,cardinalTicker,coordsTicker,background_alpha_current;
local knownProblematicAddOns, knownProblematicAddOnsDetected = {BasicMinimap=true},{};
local SetPointToken,SetParentToken = {},{};
local trackingTypes,trackingTypesStates,numTrackingTypes,trackingHookLocked = {},{},0,false;
local MinimapFunctionHijacked --= {"SetParent","ClearAllPoints","SetAllPoints","GetPoint","GetNumPoints"};
local rotationMode,mTI
local foreignObjects = {}
local anchoredFrames = { -- frames there aren't childs of minimap but anchored it.
	-- <name[string]> - Could be a path from _G delimited by dots.
	-- Blizzard
	"GameTimeFrame", -- required if foreign addon changed
	"GarrisonLandingPageMinimapButton",
	"MinimapCluster.InstanceDifficulty", -- required if foreign addon changed (ElvUI)
	"MinimapBackdrop", -- required if foreign addon changed
	"MinimapCompassTexture",
	"MinimapNorthTag",
	"MiniMapTracking",
	"MiniMapWorldMapButton",
	"MinimapZoneText",
	"MinimapZoomIn",
	"MinimapZoomOut",
	"TimeManagerClockButton", -- required if foreign addon changed
	"TimerTracker",
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
	"Minimap.gwTrackingButton", -- added with parent key, without SetParent, but with SetAllPoints to the Minimap. Has prevented mouse interaction with 3d world.
	"GwAddonToggle",
	"GwCalendarButton",
	"GwGarrisonButton",
	"GwMailButton",
};
local ignoreFrames = {
	FarmHudRangeCircles=true
}
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
local minimapScripts = {
	-- <ScriptFunctionName> = <action[CurrenctlyNotImplemented]>
	OnMouseDown="Dummy",
	OnDragStart="nil",
	OnDragStop="nil"
}
local minimapCreateTextureTable = {};
local trackEnableMouse,suppressNextMouseEnable = false,false; -- try to get more info for mouse enable bug
local excludeInstance = { -- exclude instance from hideInInstace option

}

local function moduleEventFunc(self,event,...)
	if self.module.events[event] then
		self.module.events[event](self.module.eventFrame,...)
	end
end

ns.modules = setmetatable({},{
	__newindex = function(t,name,module)
		rawset(t,name,module)
		if module.events then
			local c=0;
			for event,func in pairs(module.events) do
				c=c+1;
				if type(func)=="function" then
					if not module.eventFrame then
						module.eventFrame = CreateFrame("Frame");
						module.eventFrame.module = module;
						module.eventFrame.moduleName = name;
						module.eventFrame:SetScript("OnEvent",moduleEventFunc)
					end
					module.eventFrame:RegisterEvent(event);
				end
			end
		end
	end,
	__call = function(t,arg1,...)
		ns:debug("<nsModulesCall>",arg1)
		for modName,mod in pairs(t)do
			local modObj = mod[arg1];
			if modObj then
				local objType = type(modObj);
				if objType=="function" then
					modObj(...);
				elseif objType=="string" and type(mod[modObj])=="function" then
					mod[modObj](...);
				elseif objType=="table" then
					ns:debug("<nsModulesCall>",arg1,objType,modObj.frame)
					local frame = type(modObj.frame)=="string" and (_G[modObj.frame] or FarmHud[modObj.frame]) or false;
					if frame and frame.GetObjectType and frame:GetObjectType()=="Frame" and frame[modObj.func] then
						frame[modObj.func](frame,...)
					end
				end
			elseif arg1=="Event" and mod[arg1] then
				ns:debug("<nsModulesCall>",arg1)
				mod[arg1](FarmHud,arg1,...);
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

-- continent id of map id

function ns.GetContinentID(mapID)
	if not mapID then
		mapID = C_Map.GetBestMapForUnit("player");
		if not mapID then
			return false;
		end
	end
	local mapInfo = C_Map.GetMapInfo(mapID);
	if mapInfo and mapInfo.parentMapID and mapInfo.mapType>2 then
		return ns.GetContinentID(mapInfo.parentMapID);
	end
	return mapID
end

-- transparency options

function FarmHudMixin:UpdateMapAlpha(by,force)
	local alpha={
		main = FarmHudDB.background_alpha,
		alt = FarmHudDB.background_alpha2
	}
	if by=="OptChange" or by=="OnShow" or by=="ToggleBackground" then
		if by=="OnShow" and FarmHudDB.background_alpha_default then
			FarmHudDB.background_alpha_toggle = true
		elseif by=="ToggleBackground" then
			FarmHudDB.background_alpha_toggle = not FarmHudDB.background_alpha_toggle;
		end
		background_alpha_current = FarmHudDB.background_alpha_toggle and "main" or "alt";
	end
	MinimapMT.SetAlpha(Minimap,force and force or alpha[background_alpha_current]);
end

-- tracking options

function ns.GetTrackingTypes()
	if ns.IsClassic() then return {}; end
	local num = C_Minimap.GetNumTrackingTypes();
	if numTrackingTypes~=num then
		numTrackingTypes = num;
		wipe(trackingTypes);
		for i=1, num do
			local info = C_Minimap.GetTrackingInfo(i) or {}
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
	local info = C_Minimap.GetTrackingInfo(data.index) or {};
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
	function Minimap:CreateTexture(...)
		local tex = MinimapMT.CreateTexture(self,...);
		tinsert(minimapCreateTextureTable,tex);
		return tex;
	end
end

-- dummyOnly; prevent changes by foreign addons while farmhud is visible
local function dummyOnly_SetPoint(self,point,relTo,relPoint,x,y)
	if relTo==Minimap or relTo=="Minimap" then
		relTo = FarmHudMinimapDummy
	end
	return self[SetPointToken](self,point,relTo,relPoint,x,y);
end

local function dummyOnly_SetParent(self,parent)
	if parent==Minimap or parent=="Minimap" then
		parent = FarmHudMinimapDummy;
	end
	return self[SetParentToken](self,parent);
end

-- function replacements for Minimap while FarmHud is enabled.
-- Should prevent problems with repositioning of minimap buttons from other addons.
local replacements,addHooks
do
	local alreadyHooked,useDummy,lockedBy = {},nil,nil;
	local function MinimapOrDummy(func,...)
		if useDummy then
			return FarmHudMinimapDummy[func](FarmHudMinimapDummy,...);
		end
		return MinimapMT[func](Minimap,...);
	end
	replacements = {
		GetWidth = function() return MinimapOrDummy("GetWidth") end,
		GetHeight = function() return MinimapOrDummy("GetHeight") end,
		GetSize = function() return MinimapOrDummy("GetSize") end,
		GetCenter = function() return FarmHudMinimapDummy :GetCenter() end,
		GetEffectiveScale = function() return FarmHudMinimapDummy :GetEffectiveScale() end,
		GetLeft = function() return FarmHudMinimapDummy :GetLeft() end,
		GetRight = function() return FarmHudMinimapDummy :GetRight() end,
		GetBottom = function() return FarmHudMinimapDummy :GetBottom() end,
		GetTop = function() return FarmHudMinimapDummy :GetTop() end,
		SetZoom = function(m,z) end, -- prevent zoom
	}

	local objHookedFunctions = {
		OnEnter=function(self,...)
			if lockedBy~=false then
				return alreadyHooked[self].OnEnter(self,...)
			end
			lockedBy = self;
			useDummy = true;
		end,
		OnLeave=function(self,...)
			if lockedBy~=self then
				return alreadyHooked[self].OnLeave(self,...)
			end
			useDummy = false;
		end,
		OnDragStart=function(self,...)
			if lockedBy~=false then
				return alreadyHooked[self].OnDragStart(self,...)
			end
			lockedBy = self;
			useDummy = true;
		end,
		OnDragStop=function(self,...)
			if lockedBy~=self then
				return alreadyHooked[self].OnDragStop(self,...)
			end
			useDummy = false;
		end
	}

	function addHooks(obj)
		if alreadyHooked[obj] then
			return;
		end
		alreadyHooked[obj] = {}
		for e,f in pairs(objHookedFunctions) do
			local func = obj:GetScript(e)
			if func then
				alreadyHooked[obj][e] = func;
				obj:SetScript(e,f);
			end
		end
	end
end

-- move anchoring of objects from minimap to dummy and back
local objSetPoint = {};
local objSetParent = {};
local function objectToDummy(object,enable,debugStr)
	local objName = object:GetDebugName();
	local objType = object:GetObjectType();

	-- == ignore == --
	if (HBDPins and HBDPins.minimapPins[object]) -- ignore herebedragons pins
	or objType=="Line" -- ignore object type "Line"
	or (ignoreFrames[objName])
	then
		return;
	end

	-- == prepare == --
	local changedSetParent,changedSetPoint = false,false;
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
		objSetParent[objType](object,FarmHudMinimapDummy);
		changedSetParent = true;
	elseif enable==false and parent==FarmHudMinimapDummy then
		objSetParent[objType](object,Minimap);
		changedSetParent = true;
	end

	if changedSetParent then
		-- get mouse enabled boolean
		local MouseEnabledState = object:IsMouseEnabled()

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

		-- revert unwanted changed mouse enable status
		if object:IsMouseEnabled()~=MouseEnabledState then
			ns:debug("objectToDummy",objName,"unwanted mouse enabled... revert it!")
			-- found problem with <frame>:HookScript. It enables mouse for frames on use. If this normal?
			object:EnableMouse(MouseEnabledState)
		end
	end

	-- == anchors == --
	local changedSetPoint = false; -- reset for SetPoint

	-- search and change anchors on minimap
	if object.GetNumPoints then
		for p=1, (object:GetNumPoints()) do
			local point,relTo,relPoint,x,y = object:GetPoint(p);
			if enable==true and relTo==Minimap then
				objSetPoint[objType](object,point,FarmHudMinimapDummy,relPoint,x,y);
				changedSetPoint=true;
			elseif enable==false and relTo==FarmHudMinimapDummy then
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
	if self ~= FarmHud then
		self = FarmHud
	end

	-- using WorldFrame size for changable view port by users
	local eScale = UIParent:GetEffectiveScale();
	local width,height = WorldFrame:GetSize();
	width,height = width/eScale,height/eScale;
	local size = min(width,height);

	self:SetSize(size,size);

	local MinimapSize = size * FarmHudDB.hud_size;
	local MinimapScaledSize =  MinimapSize / FarmHudDB.hud_scale;
	MinimapMT.SetScale(Minimap,FarmHudDB.hud_scale);
	MinimapMT.SetSize(Minimap,MinimapScaledSize, MinimapScaledSize);

	self.size = MinimapSize;

	self.cluster:SetScale(FarmHudDB.hud_scale);
	self.cluster:SetSize(MinimapScaledSize, MinimapScaledSize);
	self.cluster:SetFrameStrata(Minimap:GetFrameStrata());
	self.cluster:SetFrameLevel(Minimap:GetFrameLevel());

	ns.modules("Update",enabled)

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

	if _G["GatherMate2"] then
		_G["GatherMate2"]:GetModule("Display"):ReparentMinimapPins(Map);
	end
	if _G["Routes"] and _G["Routes"].ReparentMinimap then
		_G["Routes"]:ReparentMinimap(Map);
	end
	if _G["Bloodhound2"] and _G["Bloodhound2"].ReparentMinimap then
		_G["Bloodhound2"].ReparentMinimap(Map,"Minimap");
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

		if IsKey(key,"background_alpha") or IsKey(key,"background_alpha2") or IsKey(key,"background_alpha_toggle") then
			self:UpdateMapAlpha("OptChange")
		elseif IsKey(key,"player_dot") then
			SetPlayerDotTexture(true);
		elseif IsKey(key,"mouseoverinfo_color") then
			self.TextFrame.mouseWarn:SetTextColor(unpack(FarmHudDB.mouseoverinfo_color));
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
			FarmHudMinimapDummy:SetShown(FarmHudDB.showDummy);
		elseif IsKey(key,"showDummyBg") then
			FarmHudMinimapDummy.bg:SetShown(FarmHudDB.showDummyBg and (not HybridMinimap or (HybridMinimap and not HybridMinimap:IsShown())) );
		elseif key:find("tracking^%d+") and not ns.IsClassic() then
			local id = tonumber((key:match("^tracking%^(%d+)$")));
			if id then
				TrackingTypes_Update(true,id);
			end
		elseif key:find("rotation") then
			rotationMode = FarmHudDB.rotation and "1" or "0";
			C_CVar.SetCVar("rotateMinimap", rotationMode);
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

	FarmHudMinimapDummy:SetParent(Minimap:GetParent());
	FarmHudMinimapDummy:SetScale(Minimap:GetScale());
	FarmHudMinimapDummy:SetSize(Minimap:GetSize());
	FarmHudMinimapDummy:SetFrameStrata(Minimap:GetFrameStrata());
	FarmHudMinimapDummy:SetFrameLevel(Minimap:GetFrameLevel());
	FarmHudMinimapDummy:ClearAllPoints();
	for i=1, Minimap:GetNumPoints() do
		FarmHudMinimapDummy:SetPoint(Minimap:GetPoint(i));
	end
	FarmHudMinimapDummy.bg:SetShown(FarmHudDB.showDummyBg and (not HybridMinimap or (HybridMinimap and not HybridMinimap:IsShown())) );
	FarmHudMinimapDummy:SetShown(FarmHudDB.showDummy);
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


	-- cache script entries
	local OnMouseUp = Minimap:GetScript("OnMouseUp");
	local OnMouseDown = Minimap:GetScript("OnMouseDown");
	if OnMouseDown and OnMouseUp==nil then -- for ElvUI. They added to OnMouseUp a dummy function and using OnMouseDown instead.
		mps.OnMouseDown = OnMouseDown;
		MinimapMT.SetScript(Minimap,"OnMouseDown",Minimap_OnClick);
	elseif OnMouseUp~=Minimap_OnClick then
		mps.OnMouseUp = OnMouseUp;
		MinimapMT.SetScript(Minimap,"OnMouseUp",Minimap_OnClick);
	end
	for name, todo in pairs(minimapScripts)do
		local fnc
		if name=="OnMouseDown" and not mps.OnMouseDown then
			fnc = Minimap:GetScript(name);
		end
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
			if not ignoreFrames[childs[i]:GetName()] then
				parent,point = objectToDummy(childs[i],true,"OnShow.GetChildren");
				if parent or point then
					tinsert(movedElements.childs,childs[i]);
				end
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
		local frame;
		if frameName:match("%.") then
			local path = {strsplit(".",frameName)};
			if _G[path[1]] then
				local f = _G[path[1]]
				for i=2, #path do
					if f[path[i]] then
						f = f[path[i]];
					end
				end
				frame = f;
			end
		end
		if _G[frameName] then
			frame = _G[frameName];
		end
		if frame and objectToDummy(frame,true,"OnShow.anchoredFrames") then
			mps.anchoredFrames[frameName]=true;
		end
	end

	-- nameless textures
	if #minimapCreateTextureTable>0 then
		for i=1, #minimapCreateTextureTable do
			objectToDummy(minimapCreateTextureTable[i],true,"OnShow.minimapCreateTextureTable");
		end
	end

	-- move and change minimap for FarmHud
	Minimap:Hide();
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
	self:UpdateMapAlpha("OnShow");

	-- disable mouse enabled frames
	suppressNextMouseEnable = true;
	MinimapMT.EnableMouse(Minimap,false);
	MinimapMT.EnableMouseWheel(Minimap,false);

	mps.backdropMouse = MinimapBackdrop:IsMouseEnabled();
	if mps.backdropMouse then
		MinimapBackdrop:EnableMouse(false);
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
		C_CVar.SetCVar("rotateMinimap", rotationMode);
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
	self:UpdateCoords(FarmHudDB.coords_show);
	self:UpdateTime(FarmHudDB.time_show);

	-- second try to suppress mouse enable state
	suppressNextMouseEnable = true;
	MinimapMT.EnableMouse(Minimap,false);
	MinimapMT.EnableMouseWheel(Minimap,false);

	ns.modules("OnShow",true)

	Minimap:Show();
end

function FarmHudMixin:OnHide()
	if rotationMode ~= mps.rotation then
		C_CVar.SetCVar("rotateMinimap", mps.rotation);
		rotationMode = mps.rotation
		Minimap_UpdateRotationSetting();
	end

	trackEnableMouse = false;

	-- restore function replacements for Minimap
	for k in pairs(replacements)do
		Minimap[k] = mps.replacements[k];
	end

	Minimap:Hide();
	MinimapMT.SetParent(Minimap,mps.parent);
	MinimapMT.SetScale(Minimap,mps.scale);
	MinimapMT.SetSize(Minimap,unpack(mps.size));
	MinimapMT.SetFrameStrata(Minimap,mps.strata);
	MinimapMT.SetFrameLevel(Minimap,mps.level);
	MinimapMT.EnableMouse(Minimap,mps.mouse);
	MinimapMT.EnableMouseWheel(Minimap,mps.mousewheel);

	self:UpdateMapAlpha("OnHide",mps.alpha)
	Minimap:Show();

	FarmHudMinimapDummy.bg:Hide();
	FarmHudMinimapDummy:Hide();
	self.cluster:Hide();

	if mps.OnMouseDown and Minimap:GetScript("OnMouseDown")==nil then
		MinimapMT.SetScript(Minimap,"OnMouseUp",mps.OnMouseUp);
		MinimapMT.SetScript(Minimap,"OnMouseDown",mps.OnMouseDown);
		FarmHudMinimapDummy:SetScript("OnMouseUp",nil);
		FarmHudMinimapDummy:SetScript("OnMouseDown",nil);
		FarmHudMinimapDummy:EnableMouse(false);
	elseif mps.OnMouseUp then
		MinimapMT.SetScript(Minimap,"OnMouseUp",mps.OnMouseUp);
		FarmHudMinimapDummy:SetScript("OnMouseUp",nil);
		FarmHudMinimapDummy:EnableMouse(false);
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

	ns.modules("OnHide");

	SetPlayerDotTexture(false);
	TrackingTypes_Update(false);

	wipe(mps);

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
		self:UpdateMapAlpha("ToggleBackground")
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

		if _G["BasicMinimap"] and _G["BasicMinimap"].backdrop then
			self:RegisterForeignAddOnObject(_G["BasicMinimap"].backdrop:GetParent(),"BasicMinimap");
		end

		checkOnKnownProblematicAddOns()
		self.playerIsLoggedIn = true
	elseif event=="PLAYER_LOGOUT" and mps.rotation and rotationMode and rotationMode~=mps.rotation then
		-- reset rotation on logout and reload if FarmHud was open
		C_CVar.SetCVar("rotateMinimap", mps.rotation);
	elseif event=="MODIFIER_STATE_CHANGED" and self:IsShown() then
		local key, down = ...;
		if not mouseOnKeybind and modifiers[FarmHudDB.holdKeyForMouseOn] and modifiers[FarmHudDB.holdKeyForMouseOn][key]==1 then
			self:ToggleMouse(down==0);
		end
	elseif event=="PLAYER_ENTERING_WORLD" then
		if FarmHudDB.hideInInstance then
			if IsInInstance() and FarmHud:IsShown() and not excludeInstance[1] then
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
end

function FarmHudMixin:OnLoad()
	FarmHudMinimapDummy.bg:SetMask("interface/CHARACTERFRAME/TempPortraitAlphaMask");

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
		if not FarmHud:IsVisible() then
			return; -- ignore
		end
		if FarmHudDB.background_alpha~=level then
			FarmHud:UpdateMapAlpha("HookSetAlpha")
		end
	end);

	hooksecurefunc(Minimap,"SetMaskTexture",function(_,texture)
		FarmHudMinimapDummy.bg:SetMask(texture);
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

	self:RegisterEvent("ADDON_LOADED");
	self:RegisterEvent("PLAYER_LOGIN");
	self:RegisterEvent("PLAYER_ENTERING_WORLD");
	self:RegisterEvent("PLAYER_LOGOUT");

	self:RegisterEvent("MODIFIER_STATE_CHANGED");

	self:RegisterEvent("PLAYER_REGEN_DISABLED");
	self:RegisterEvent("PLAYER_REGEN_ENABLED");

	ns.modules("OnLoad");
end

