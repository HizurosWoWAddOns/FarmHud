local addon,ns=...;
local L=ns.L;

FarmHud = CreateFrame("frame");

BINDING_HEADER_FARMHUD = "FarmHud";
BINDING_NAME_TOGGLEFARMHUD = L["Toggle FarmHud's Display"];
BINDING_NAME_TOGGLEFARMHUDMOUSE	= L["Toggle FarmHud's tooltips (Can't click through Hud)"];

local directions, blackborderblobs_Toggle = {};
local fh_scale = 1.4;
local fh_mapRotation, playerDot, updateRotations, mousewarn, coords, closebtn, mousebtn, Astrolabe, _
local indicators = {L["N"], L["NE"], L["E"], L["SE"], L["S"], L["SW"], L["W"], L["NW"]};

local LDB = LibStub("LibDataBroker-1.1"):NewDataObject("FarmHud",{
	type	= "launcher",
	icon	= "Interface\\Icons\\INV_Misc_Herb_MountainSilverSage.png",
	label	= "FarmHud",
	text	= "FarmHud",
	OnTooltipShow = function(tt)
		tt:AddLine("FarmHud");
		tt:AddLine(("|cffffff00%s|r %s"):format(L["Click"],L["to toggle FarmHud"]));
		tt:AddLine(("|cffffff00%s|r %s"):format(L["Right click"],L["to config"]));
		tt:AddLine(L["Or macro with /script FarmHud:Toggle()"]);
	end,
	OnClick = function(_, button)
		if (button=="LeftButton") then
			FarmHud:Toggle();
		else
			LibStub("AceConfigDialog-3.0"):Open("FarmHud");
		end
	end
});

local LDBIcon = LDB and LibStub("LibDBIcon-1.0", true);

local NPCScan = nil;

local options = {
	name = "FarmHud",
	type = "group",
	args = {
		confdesc = {
			order = 1,
			type = "description",
			name = L["A Hud for farming ore and herbs."],
			cmdHidden = true
		},

		displayheader = {
			order = 10,
			type = "header",
			name = L["FarmHud Options"],
		},
		hide_minimapicon = {
			type = "toggle", --[[width = "double",]] order = 11,
			name = L["Minimap Icon"],
			desc = L["Show or hide the minimap icon."],
			get = function() return not FarmHudDB.MinimapIcon.hide; end,
			set = function(_,v) FarmHudDB.MinimapIcon.hide = not v;
				if (not v) then LDBIcon:Hide("FarmHud") else LDBIcon:Show("FarmHud"); end
			end,
		},
		hide_gathercircle = {
			type = "toggle", --[[width = "double",]] order = 12,
			name = L["Green gather circle"],
			desc = L["Show or hide the green gather circle"],
			get = function() return not FarmHudDB.hide_gathercircle; end,
			set = function(_,v) FarmHudDB.hide_gathercircle = not v;
				if (not v) then gatherCircle:Hide(); else gatherCircle:Show(); end
			end
		},
		hide_indicators = {
			type = "toggle", --[[width = "double",]] order = 13,
			name = L["Direction indicators"],
			desc = L["Show or hide the direction indicators"],
			get = function() return not FarmHudDB.hide_indicators; end,
			set = function(_,v) FarmHudDB.hide_indicators = not v;
				if (not v) then
					for i,e in ipairs(directions) do e:Hide(); end
				else
					for i,e in ipairs(directions) do e:Show(); end
				end
			end
		},
		hide_coords = {
			type = "toggle", --[[width = "double",]] order = 14,
			name = L["Player coordinations"],
			desc = L["Show or hide player coordinations"],
			get = function() return not FarmHudDB.hide_coords; end,
			set = function(_,v) FarmHudDB.hide_coords = not v;
				if (not v) then FarmHudCoords:Hide(); else FarmHudCoords:Show(); end
			end
		},
		coords_bottom = {
			type = "toggle", width = "double", order = 15,
			name = L["Coordinations on bottom"],
			desc = L["Display player coordinations on bottom"],
			get = function() return FarmHudDB.coords_bottom; end,
			set = function(_,v) FarmHudDB.coords_bottom = v;
				if (v) then
					FarmHudCoords:SetPoint("CENTER", FarmHudMapCluster, "CENTER", 0, -FarmHudMapCluster:GetWidth()*.23);
				else
					FarmHudCoords:SetPoint("CENTER", FarmHudMapCluster, "CENTER", 0, FarmHudMapCluster:GetWidth()*.23);
				end
			end
		},
		hide_buttons = {
			type = "toggle", --[[width = "double",]] order = 16,
			name = L["OnScreen buttons"],
			desc = L["Show or hide OnScreen buttons (mouse mode and close hud button)"],
			get = function() return not FarmHudDB.hide_buttons; end,
			set = function(_,v) FarmHudDB.hide_buttons = not v;
				if (not v) then 
					closebtn:Hide();
					mousebtn:Hide();
				else
					closebtn:Show();
					mousebtn:Show();
				end
			end
		},
		buttons_bottom = {
			type = "toggle", width = "double", order = 17,
			name = L["OnScreen buttons on bottom"],
			desc = L["Display toggle buttons on bottom"],
			get = function() return FarmHudDB.buttons_bottom; end,
			set = function(_,v) FarmHudDB.buttons_bottom = v;
				if (v) then
					closebtn:SetPoint("CENTER", FarmHudMapCluster, "CENTER", 12, -FarmHudMapCluster:GetWidth()*.25);
					mousebtn:SetPoint("CENTER", FarmHudMapCluster, "CENTER", -12, -FarmHudMapCluster:GetWidth()*.25);
				else
					closebtn:SetPoint("CENTER", FarmHudMapCluster, "CENTER", 12, FarmHudMapCluster:GetWidth()*.25);
					mousebtn:SetPoint("CENTER", FarmHudMapCluster, "CENTER", -12, FarmHudMapCluster:GetWidth()*.25);
				end
			end
		},
		blackborderblobs = {
			type = "toggle", width = "double", order = 18,
			name = L["black bordered quest and archaeology blobs"],
			desc = L["Replace blizzards quest and archaeology blobs. (This option is experimental...)"],
			get = function() return FarmHudDB.blackborderblobs; end,
			set = function(_,v) FarmHudDB.blackborderblobs = v; blackborderblobs_Toggle(); end
		},
		keybindheader = {
			order = 30,
			type = "header",
			name = L["Keybind Options"],
		},
		bind_showtoggle = {
			type = "keybinding", width = "double", order = 31,
			name = L["Toggle FarmHud's Display"],
			desc = L["Set the keybinding to show FarmHud."],
			get = function() return GetBindingKey("TOGGLEFARMHUD"); end,
			set = function(_,v)
				local keyb = GetBindingKey("TOGGLEFARMHUD");
				if (keyb) then SetBinding(keyb); end
				if (v~="") then SetBinding(v, "TOGGLEFARMHUD"); end
				SaveBindings(GetCurrentBindingSet());
			end,
		},
		bind_mousetoggle = {
			type = "keybinding", width = "double", order = 32,
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

		supportheader = {
			order = 50,
			type = "header",
			name = L["Support Options"],
		},
		show_gathermate = {
			type = "toggle", order = 51,
			name = "GatherMate2", desc = L["Enable GatherMate2 support"],
			get = function() return FarmHudDB.show_gathermate; end,
			set = function(_,v) FarmHudDB.show_gathermate = v; end,
		},
		show_routes = {
			type = "toggle", order = 52,
			name = "Routes", desc = L["Enable Routes support"],
			get = function() return FarmHudDB.show_routes; end,
			set = function(_,v) FarmHudDB.show_routes = v; end,
		},
		show_npcscan = {
			type = "toggle", order = 53,
			name = "NPCScan", desc = L["Enable NPCScan support"],
			get = function() return FarmHudDB.show_npcscan; end,
			set = function(_,v) FarmHudDB.show_npcscan = v; end,
		},
		show_bloodhound2 = {
			type = "toggle", order = 54,
			name = "BloodHound2", desc = L["Enable Bloodhound2 support"],
			get = function() return FarmHudDB.show_bloodhound2; end,
			set = function(_,v) FarmHudDB.show_bloodhound2 = v; end
		},
		show_tomtom = {
			type = "toggle", order = 55,
			name = "TomTom", desc = L["Enable TomTom support"],
			get = function() return FarmHudDB.show_tomtom; end,
			set = function(_,v) FarmHudDB.show_tomtom = v; end
		}
	}
}

LibStub("AceConfig-3.0"):RegisterOptionsTable("FarmHud", options)
LibStub("AceConfigDialog-3.0"):AddToBlizOptions("FarmHud")

local onShow = function(self)
	fh_mapRotation = GetCVar("rotateMinimap");
	SetCVar("rotateMinimap", "1", "ROTATE_MINIMAP");

	if (GatherMate2) and (FarmHudDB.show_gathermate==true) then
		GatherMate2:GetModule("Display"):ReparentMinimapPins(FarmHudMapCluster);
	end

	if (Routes) and (Routes.ReparentMinimap) and (FarmHudDB.show_routes==true) then
		Routes:ReparentMinimap(FarmHudMapCluster);
	end

	if (NPCScan) and (NPCScan.SetMinimapFrame) and (FarmHudDB.show_npcscan==true) then
		NPCScan:SetMinimapFrame(FarmHudMapCluster);
	end

	if (Bloodhound2) and (Bloodhound2.ReparentMinimap) and (FarmHudDB.show_bloodhound2==true) then
		Bloodhound2.ReparentMinimap(FarmHudMapCluster,"FarmHud");
	end

	if (TomTom) and (TomTom.ReparentMinimap) and (FarmHudDB.show_tomtom==true) then
		TomTom:ReparentMinimap(FarmHudMapCluster);
		if (not Astrolabe) and (DongleStub) then
			_, Astrolabe = pcall(DongleStub,"Astrolabe-1.0");
			if(type(Astrolabe)~="table")then
				_, Astrolabe = pcall(DongleStub,"Astrolabe-TomTom-1.0");
			end
			if not type(Astrolabe) then
				Astrolabe=nil;
			end
		end
		if (Astrolabe and Astrolabe.SetTargetMinimap) then
			Astrolabe:SetTargetMinimap(FarmHudMinimap);
		end
	end

	FarmHud:SetScript("OnUpdate", updateRotations);
	Minimap:Hide();
end

local onHide = function(self, force)
	SetCVar("rotateMinimap", fh_mapRotation, "ROTATE_MINIMAP");

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

	if (TomTom) and (TomTom.ReparentMinimap) then
		TomTom:ReparentMinimap(_G.Minimap);
		if (Astrolabe and Astrolabe.SetTargetMinimap) then
			Astrolabe:SetTargetMinimap(_G.Minimap);
		end
	end

	FarmHud:SetScript("OnUpdate", nil);
	Minimap:Show();
end

local onUpdate = function(self,elapsed)
	local x,y=GetPlayerMapPosition("player");
	coords:SetFormattedText("%.1f, %.1f",x*100,y*100);
end

function FarmHud:SetScales()
	FarmHudMinimap:ClearAllPoints();
	FarmHudMinimap:SetPoint("CENTER", UIParent, "CENTER");

	FarmHudMapCluster:ClearAllPoints();
	FarmHudMapCluster:SetPoint("CENTER");

	local size = UIParent:GetHeight() / fh_scale;
	FarmHudMinimap:SetWidth(size);
	FarmHudMinimap:SetHeight(size);
	FarmHudMapCluster:SetHeight(size);
	FarmHudMapCluster:SetWidth(size);
	gatherCircle:SetWidth(size * 0.45);
	gatherCircle:SetHeight(size * 0.45);

	FarmHudMapCluster:SetScale(fh_scale);
	playerDot:SetWidth(15);
	playerDot:SetHeight(15);

	for k, v in ipairs(directions) do
		v.radius = FarmHudMinimap:GetWidth() * 0.214;
	end
end

-- Toggle FarmHud display
function FarmHud:Toggle(flag)
	if (flag==nil) then
		if (FarmHudMapCluster:IsVisible()) then
			FarmHudMapCluster:Hide();
		else
			FarmHudMapCluster:Show();
			FarmHud:SetScales();
		end
	else
		if (flag) then
			FarmHudMapCluster:Show();
			FarmHud:SetScales();
		else
			FarmHudMapCluster:Hide();
		end
	end
end

-- Toggle the mouse to check out herb / ore tooltips
function FarmHud:MouseToggle()
	if (FarmHudMinimap:IsMouseEnabled()) then
		FarmHudMinimap:EnableMouse(false);
		mousewarn:Hide();
	else
		FarmHudMinimap:EnableMouse(true);
		mousewarn:Show();
	end
end

do
	local target,total = 1 / 90, 0;

	function updateRotations(self, t)
		total = total + t;
		if (total < target) then return end
		while (total > target) do total = total - target; end
		if (Minimap:IsVisible()) then Minimap:Hide(); end
		local bearing = GetPlayerFacing();
		for k, v in ipairs(directions) do
			local x, y = math.sin(v.rad + bearing), math.cos(v.rad + bearing);
			v:ClearAllPoints();
			v:SetPoint("CENTER", FarmHudMapCluster, "CENTER", x * v.radius, y * v.radius);
		end
	end
end

function blackborderblobs_Toggle()
	local none, outside = [[Interface\glues\credits\bloodelf_priestess_master6]],[[Interface\common\ShadowOverlay-Top]]
	local media = "interface\\minimap\\"
	blobs = not blobs;
	FarmHudMinimap:SetArchBlobInsideTexture(			(blobs) and none	or media.."UI-ArchBlobMinimap-Inside");
	FarmHudMinimap:SetArchBlobOutsideTexture(			(blobs) and outside or media.."UI-ArchBlobMinimap-Outside");
	FarmHudMinimap:SetArchBlobRingTexture(				(blobs) and none	or media.."UI-ArchBlob-MinimapRing");
	FarmHudMinimap:SetQuestBlobInsideTexture(			(blobs) and none	or media.."UI-QuestBlobMinimap-Inside");
	FarmHudMinimap:SetQuestBlobOutsideSelectedTexture(	(blobs) and outside or media.."UI-QuestBlobMinimap-OutsideSelected");
	FarmHudMinimap:SetQuestBlobOutsideTexture(			(blobs) and outside or media.."UI-QuestBlobMinimap-Outside");
	FarmHudMinimap:SetQuestBlobRingTexture(				(blobs) and none	or media.."UI-QuestBlob-MinimapRing");
end

function FarmHud:PLAYER_LOGIN()

	NPCScan = (_NPCScan) and (_NPCScan.Overlay) and _NPCScan.Overlay.Modules.List[ "Minimap" ];

	if (FarmHudDB==nil) then
		FarmHudDB={};
	end

	if (FarmHudDB.MinimapIcon==nil) then
		FarmHudDB.MinimapIcon = {
			hide = false,
			minimapPos = 220,
			radius = 80,
		};
	end

	for k,v in pairs({
		-- FarmHud options
		hide_gathercircle = false,
		hide_indicators = false,
		hide_coords = false,
		coords_bottom = false,
		hide_buttons = false,
		buttons_buttom = false,
		blackborderblobs = true,

		-- Support other addons options
		show_gathermate = true,
		show_routes = true,
		show_npcscan = true,
		show_bloodhound2 = true,
		show_tomtom = true,
	})do
		if (FarmHudDB[k]==nil) then
			FarmHudDB[k]=v;
		end
	end

	if (LDBIcon) then
		LDBIcon:Register("FarmHud", LDB, FarmHudDB.MinimapIcon);
	end

	FarmHudMinimap:SetPoint("CENTER", UIParent, "CENTER");
	FarmHudMapCluster:SetFrameStrata("BACKGROUND");
	FarmHudMapCluster:SetAlpha(0.7);
	FarmHudMinimap:SetAlpha(0);
	FarmHudMinimap:EnableMouse(false);

	setmetatable(FarmHudMapCluster, { __index = FarmHudMinimap });

	FarmHudMapCluster._GetScale = FarmHudMapCluster.GetScale;
	FarmHudMapCluster.GetScale = function() return 1; end

	gatherCircle = FarmHudMapCluster:CreateTexture();
	gatherCircle:SetTexture([[SPELLS\CIRCLE.BLP]]);
	gatherCircle:SetBlendMode("ADD");
	gatherCircle:SetPoint("CENTER");
	local radius = FarmHudMinimap:GetWidth() * 0.45;
	gatherCircle:SetWidth(radius);
	gatherCircle:SetHeight(radius);
	gatherCircle.alphaFactor = 0.5;
	gatherCircle:SetVertexColor(0, 1, 0, 1 * (gatherCircle.alphaFactor or 1) / FarmHudMapCluster:GetAlpha());
	if FarmHudDB.hide_gathercircle==true then
		gatherCircle:Hide();
	end

	playerDot = FarmHudMapCluster:CreateTexture();
	playerDot:SetTexture([[Interface\GLUES\MODELS\UI_Tauren\gradientCircle.blp]]);
	playerDot:SetBlendMode("ADD");
	playerDot:SetPoint("CENTER");
	playerDot.alphaFactor = 2;
	playerDot:SetWidth(15);
	playerDot:SetHeight(15);

	local radius = FarmHudMinimap:GetWidth() * 0.214;
	for k, v in ipairs(indicators) do
		local rot = (0.785398163 * (k-1));
		local ind = FarmHudMapCluster:CreateFontString(nil, nil, "GameFontNormalSmall");
		local x, y = math.sin(rot), math.cos(rot);
		ind:SetPoint("CENTER", FarmHudMapCluster, "CENTER", x * radius, y * radius);
		ind:SetText(v);
		ind:SetShadowOffset(0.2,-0.2);
		ind.rad = rot;
		ind.radius = radius;
		if (FarmHudDB.hide_indicators==true) then
			ind:Hide();
		end
		tinsert(directions, ind);
	end

	FarmHud:SetScales();

	mousewarn = FarmHudMapCluster:CreateFontString(nil, nil, "GameFontNormalSmall");
	mousewarn:SetPoint("CENTER", FarmHudMapCluster, "CENTER", 0, FarmHudMapCluster:GetWidth()*.05);
	mousewarn:SetText(L["MOUSE ON"]);
	mousewarn:Hide();

	coords = FarmHudMapCluster:CreateFontString("FarmHudCoords", nil, "GameFontNormalSmall");
	if (FarmHudDB.coords_bottom==true) then
		coords:SetPoint("CENTER", FarmHudMapCluster, "CENTER", 0, -FarmHudMapCluster:GetWidth()*.23);
	else
		coords:SetPoint("CENTER", FarmHudMapCluster, "CENTER", 0, FarmHudMapCluster:GetWidth()*.23);
	end
	if (FarmHudDB.hide_coords==true) then
		coords:Hide();
	else
		coords:Show();
	end

	if (FarmHudDB.blackborderblobs) then
		blackborderblobs_Toggle();
	end

	local t = "Interface\\BUTTONS\\UI-Panel-MinimizeButton-";
	closebtn = CreateFrame("Button",nil,FarmHudMapCluster);
	closebtn:SetPoint("CENTER", FarmHudMapCluster, "CENTER", 12, FarmHudMapCluster:GetWidth()*.26);
	closebtn:SetSize(20,20);
	closebtn:SetNormalTexture(t.."Up");
	closebtn:SetHighlightTexture(t.."Highlight");
	closebtn:SetPushedTexture(t.."Down");
	closebtn:SetAlpha(0.7);
	closebtn:SetScript("OnClick",function()
		FarmHud:Toggle()
	end);

	local t = "Interface\\Addons\\"..addon.."\\mouse";
	mousebtn = CreateFrame("Button",nil,FarmHudMapCluster);
	mousebtn:SetPoint("CENTER", FarmHudMapCluster, "CENTER", -12, FarmHudMapCluster:GetWidth()*.26);
	mousebtn:SetSize(20,20);
	mousebtn:SetNormalTexture(t.."1");
	mousebtn:SetHighlightTexture(t.."2");
	mousebtn:SetPushedTexture(t.."3");
	mousebtn:SetAlpha(0.9);
	mousebtn:SetScript("OnClick",function()
		FarmHud:MouseToggle()
	end);

	if(FarmHudDB.hide_buttons) then
		closebtn:Hide();
		mousebtn:Hide();
	end

	FarmHudMapCluster:Hide();
	FarmHudMapCluster:SetScript("OnShow", onShow);
	FarmHudMapCluster:SetScript("OnHide", onHide);
	FarmHudMapCluster:SetScript("OnUpdate", onUpdate);
end

function FarmHud:PLAYER_LOGOUT()
	FarmHud:Toggle(false);
end

FarmHud:SetScript("OnEvent", function(self, event, ...) if self[event] then return self[event](self, event, ...) end end);
FarmHud:RegisterEvent("PLAYER_LOGIN");
FarmHud:RegisterEvent("PLAYER_LOGOUT");

