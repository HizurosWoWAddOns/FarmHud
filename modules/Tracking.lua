
local addon,ns = ...;

if ns.IsClassic() or ns.IsForever() then
	return -- disable module on classic/forever clients
end

local L = ns.L;
local trackingTypes,trackingTypesStates = {},{}
-- info: I'm using textureIds as keys for trackingTypes and trackingTypesStates tables.
-- i don't trust the numeric index from C_Minimap.GetTrackingInfo().
local trackingOpts,numTrackingTypes,trackingHookLocked = {},0,false;
local trackingPattern = "|T%d:26:26:0:0|t %s"
local trackingTemplate = {
	type = "select", name = "",
	values = {
		["true"] = SHOW,
		["false"] = HIDE,
		["client"] = L["TrackingOptionsLikeMinimap"]
	}
}

local module = {
	dbDefaults = {},
	events = {},
	OnShow = nil,
	OnHide = nil,
	Update = nil,
	OnLoad = nil,
	OnSetScale = nil,
	AddOptions = nil,
}

local function UpdateTrackingTypes()
	local num = C_Minimap.GetNumTrackingTypes();
	if numTrackingTypes==num then
		return
	end
	numTrackingTypes = num;
	wipe(trackingTypes);
	for i=1, num do
		local info = C_Minimap.GetTrackingInfo(i) or {}
		trackingTypes[info.texture] = {index=i,name=info.name,active=info.active,level=info.subType}
		--
		if not module.dbDefaults["tracking^"..info.texture] then
			module.dbDefaults["tracking^"..info.texture] = "client"
		end
		if FarmHudDB["tracking^"..info.texture] then
			local v = FarmHudDB["tracking^"..info.texture];
			-- check on non valid values
			if not (v=="client" or v=="true" or v=="false") then
				FarmHudDB["tracking^"..info.texture] = "client";
				-- value must be string ("true" and "false" too). see trackingTemplate.values table.
			end
		end
	end
end

local function TrackingTypes_Update(FH_Show, textureId)
	if not textureId then
		UpdateTrackingTypes()
		for tId in pairs(trackingTypes) do
			if FarmHudDB["tracking^"..tId]=="true" or FarmHudDB["tracking^"..tId]=="false" then
				TrackingTypes_Update(FH_Show, tId)
			end
		end
		return
	end

	trackingHookLocked = true;

	local key, data = "tracking^"..textureId, trackingTypes[textureId];
	local info = C_Minimap.GetTrackingInfo(data.index) or {};

	if FH_Show then
		if FarmHudDB[key]=="client" then
			if trackingTypesStates[textureId]~=nil then
				C_Minimap.SetTracking(data.index,trackingTypesStates[textureId]);
				trackingTypesStates[textureId] = nil;
			end
		elseif FarmHudDB[key]~=tostring(info.active) then
			if trackingTypesStates[textureId]==nil then
				trackingTypesStates[textureId] = info.active;
			end
			C_Minimap.SetTracking(data.index,FarmHudDB[key]=="true");
		end
	elseif not FH_Show and trackingTypesStates[textureId]~=nil then
		C_Minimap.SetTracking(data.index,trackingTypesStates[textureId]);
		trackingTypesStates[textureId] = nil;
	end

	trackingHookLocked = false;
end

function module.OnShow()
	TrackingTypes_Update(true)
end

function module.OnHide()
	TrackingTypes_Update(false)
end

function module.OnLoad()
	hooksecurefunc(C_Minimap,"SetTracking",function(index, enabled)
		local info = C_Minimap.GetTrackingInfo(index) or {};
		if not trackingHookLocked and FarmHud:IsVisible() and info.texture and trackingTypesStates[info.texture]~=nil then
			trackingTypesStates[info.texture] = enabled;
		end
	end);
end

local function updateOpts(key)
	local textureId = tonumber((key:match("^tracking%^(%d+)$")));
	if textureId then
		TrackingTypes_Update(nil,textureId);
	end
end

local function opt(info,value)
	local key = info[#info];
	if not key:find("^tracking^%d+$") then return end

	if value~=nil then
		FarmHudDB[key] = value;
		updateOpts(key)
		return;
	end
	return FarmHudDB[key];
end

local options = {
	tracking = {
		type = "group", order=52,
		name = L["TrackingOptions"],
		get = opt, set = opt,
		childGroups = "tab",
		args = {
			desc = {
				type = "description", order = 1, fontSize = "medium",
				name = L["TrackingOptionsDesc"]
			},
			misc = {
				type = "group", order = 2,
				name = MISCELLANEOUS,
				args = {
					-- filled by function updateTrackingOptions
				},
				hidden = true,
			},
			townsfolk = {
				type = "group", order = 3,
				name = TOWNSFOLK_TRACKING_TEXT,
				args = {
					-- filled by function updateTrackingOptions
				},
				hidden = true,
			}
		}
	}
}

local function sortTrackingTypes(a,b)
	return a.index<b.index;
end

local function updateTrackingOptions(info)
	if info[#info]~="tracking" then return false end

	local townsfolk, misc = options.tracking.args.townsfolk, options.tracking.args.misc
	wipe(townsfolk.args);
	wipe(misc.args);

	UpdateTrackingTypes()

	table.sort(trackingTypes,sortTrackingTypes);

	for textureId,data in pairs(trackingTypes)do
		local key = "tracking^"..textureId;
		if trackingOpts[textureId]==nil then
			trackingOpts[textureId] = CopyTable(trackingTemplate);
			trackingOpts[textureId].name = trackingPattern:format(textureId,data.name);
			trackingOpts[textureId].order = data.index;
		end
		if data.level==2 then -- townfolk
			townsfolk.args[key] = trackingOpts[textureId]
			townsfolk.hidden=false;
		else -- misc
			misc.args[key] = trackingOpts[textureId];
			misc.hidden=false;
		end
		-- todo: add extra levels idea from broker_everything?
	end

	return false;
end

function module.AddOptions()
	UpdateTrackingTypes();
	options.tracking.hidden = updateTrackingOptions
	return options
end

ns.modules["Tracking"] = module;
