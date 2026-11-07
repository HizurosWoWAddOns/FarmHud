
local addon, ns = ...;
local L = ns.L;
local playerDot_textures = {
	["blizz"]         = L["Blizzards player arrow"],
	["blizz-smaller"] = L["Blizzards player arrow (smaller)"],
	["gold"]          = L["Golden player dot"],
	["white"]         = L["White player dot"],
	["black"]         = L["Black player dot"],
	["hide"]          = L["Hide player arrow"],
};
local groupColor = "|cff22ccef"
local framestrataValues = {
	-- https://warcraft.wiki.gg/wiki/Frame_Strata
	--   WORLD [reserved]
	L1 = L["Background"], -- BACKGROUND
	L2 = L["Low"],    -- LOW
	L3 = L["Medium"], -- MEDIUM
	L4 = L["High"],   -- HIGH
	L5 = L["Higher"], -- DIALOG
	--   FULLSCREEN
	--   FULLSCREEN_DIALOG
	L8 = L["Highest"] -- TOOLTIP
}
local dbDefaults = {
	hud_scale=1.4, hud_size=1,
	mouseoverinfo_color={1,0.82,0,0.7},
	player_dot="blizz", holdKeyForMouseOn = "_none",
	rotation=true, showDummy = true, showDummyBg = true,
	QuestArrowInfoMsg = false,
	hideInInstance=false, hideInCombat=false, showWithHiddenUI=false,
	background_alpha=0, background_alpha2=0.5, background_alpha_toggle=true, background_alpha_default=true,
	strata="L1",
	mouseoverinfo_textscale=1.4,
}
local modDB = {};
local excludeFrames = {}
local isAddOnsLoadedForOption = {
}

local supporter = {
	-- {<color>,<name>}, <localizations>, <donations>, <otherSupportTypes>, <special text>,
	{"github","bruteostrich"},		false,false,false,{"githubPR"},
	{"github","grzegorzkarolewski"},false,false,false,{"githubPR"},
	{"github","Mayron"},			false,false,false,{"githubPR"},
	{"github","MrStrugglez"},		false,false,false,{"githubPR"},
	{"github","mtdo"},				false,false,false,{"githubPR"},
	{"github","Sockdolager"},		false,false,false,{"githubPR"},
	{"github","tucomel"},			false,false,false,{"githubPR"},
	{"curseforge","Dathwada"},		{"deDE"},false,false,false,
	{"curseforge","g0ldenev1l"},	{"zhCN"},false,false,false,
	{"curseforge","gjfleo"},		{"zhCN"},false,false,false,
	{"curseforge","justregular16"},	{"esMX"},false,false,false,
	{"curseforge","kuaishan"},		{"zhCN"},false,false,false,
	{"curseforge","LvWind"},		{"zhCN"},false,false,false,
	{"curseforge","mccma"},			{"zhTW"},false,false,false,
	{"curseforge","netaras"},		{"koKR"},false,false,false,
	{"curseforge","oxscott"},		{"itIT"},false,false,false,
	{"curseforge","Subly"},			{"frFR"},false,false,false,
	{"curseforge","supahmexman"},	{"esES"},false,false,false,
	{"curseforge","Zickwik"},		{"frFR"},false,false,false,
	{"curseforge","Zurent"},		{"esES"},false,false,false,
	{"battlenet","pas06",false,"/", "curseforge","Bullseiify"},{"deDE"},false,false,false,
}

local function printFrames(key,value)
	local keyType = type(key);
	if keyType=="table" then
		if not FarmHud:IsVisible() then
			ns:print("FarmHud must be enabled before use this option");
			return;
		end

		ns:print("Search for unwanted elements anchored on minimap...");
		local count = 0;
		local regions = {Minimap:GetRegions()};
		for r=1, #regions do
			print("GetRegions()"," - ",regions[r]:GetDebugName());
			count = count + 1;
		end

		--ns:print("Search for unwanted frames anchored on minimap... (deep reverse search)");
		for k,v in pairs(_G) do
			if not (issecurevariable(_G,k)) and (not excludeFrames[key]) and (type(value)=="table") and (type(value[0])=="userdata") and (not (value:IsProtected() or value:IsForbidden())) then
				if printFrames(k,v) then
					count = count + 1;
				end
			end
		end

		--ns:print("Search for unwanted textures/fontstrings anchored on minimap...");
		local childs = {Minimap:GetChildren()};
		for i=1, #childs do
			print("GetChildren()"," - ",childs[i]:GetDebugName());
			count = count + 1;
		end

		if count>0 then
			ns:print("Finished...");
		else
			ns:print("No elements found...");
		end
		return;
	end

	for i=1, value:GetNumPoints() do
		local _,parent = value:GetPoint(i);
		if parent==Minimap then
			print("pairs(_G)"," - ",value:GetDebugName());
			return true;
		end
	end
end

local function opt(info,value,...)
	local key,reset = info[#info],info[#info]:gsub("reset","");
	if key~=reset then
		if dbDefaults[reset]~=nil then
			FarmHudDB[reset] = type(dbDefaults[reset])=="table" and CopyTable(dbDefaults[reset]) or dbDefaults[reset];
			FarmHud:UpdateOptions(reset);
		end
		return;
	elseif value~=nil then
		if key=="MinimapIcon" then
			FarmHudDB[key].hide = not value;
			local LBDi = LibStub("LibDBIcon-1.0", true)
			if LBDi then
				LBDi:Refresh(addon);
			end
		else
			if (...) then
				value = {value,...}; -- color table
			end
			FarmHudDB[key] = value;
		end
		if modDB[key] and ns.modules[modDB[key]] then
			ns.modules[modDB[key]].UpdateOptions(key,value)
		else
			FarmHud:UpdateOptions(key);
		end
		return;
	elseif key=="MinimapIcon" then
		return not FarmHudDB[key].hide;
	elseif type(FarmHudDB[key])=="table" then
		return unpack(FarmHudDB[key]); -- color table
	end
	return FarmHudDB[key];
end

local function optKeyBind(info,value)
	local key = info[#info];
	if value~=nil then
		local valueB = GetBindingKey(key);
		if valueB then
			SetBinding(valueB);
		end
		if value~="" then
			SetBinding(value, key);
		end
		SaveBindings(GetCurrentBindingSet());
	end
	return GetBindingKey(key);
end

local options = {
	type = "group",
	name = addon,
	childGroups = "tree",
	get = opt,
	set = opt,
	func = opt,
	args = {
		general = {
			type = "group", order = 1,
			name = COMPACT_UNIT_FRAME_PROFILE_SUBTYPE_ALL,
			args = {
				MinimapIcon = {
					type = "toggle", order = 1,
					name = L["MinimapIcon"], desc = L["MinimapIconDesc"]
				},
				AddOnLoaded = {
					type = "toggle", order = 2,
					name = L["AddOnLoaded"], desc = L["AddOnLoadedDesc"].."|n|n|cff44ff44"..L["AddOnLoadedDescAlt"].."|r"
				},
				rotation = {
					type = "toggle", order = 3,
					name = L["Rotation"], desc = L["RotationDesc"]
				},
				strata = {
					type = "select", order = 4,
					name = L["Strata"], desc = L["StrataDesc"],
					values = framestrataValues
				},
				showWithHiddenUI = {
					type = "toggle", order = 5, width = "full",
					name = L["ShowWithHiddenUI"], desc = L["ShowWithHiddenUIDesc"]
				},
				hud_scale = {
					type = "range", order = 11,
					name = L["HudSymbolScale"], desc = L["HudSymbolScaleDesc"],
					min = 1, max = 2.5, step = 0.1, isPercent = true
				},
				hud_size = {
					type = "range", order = 12,
					name = L["HudSize"], desc = L["HudSizeDesc"],
					min = 0.1, max = 1, step = 0.1, isPercent = true
				},
				player_dot = {
					type = "select", order = 15,
					name = L["PlayerDot"], desc = L["PlayerDotDesc"],
					values = playerDot_textures,
					hidden = function()
						return ns.sickMove1
					end
				},
				player_dot_sickMove = {
					type = "group", order=15, inline=true,
					name = INFO,
					args = {
						desc = {
							type = "description", order=15, fontSize="medium",
							name = "|cffffcc00"..L["PlayerDotNoLongerChangable"].."|r",
						}
					},
					hidden = function()
						return not ns.sickMove1
					end
				},
				autohide = {
					type="group", order = 20, inline=true,
					name = L["AutoHide"],
					args = {
						hideInInstance = {
							type="toggle", order=1,
							name=L["HideInInstance"], desc=L["HideInInstanceDesc"]
						},
						hideInCombat = {
							type="toggle", order=2,
							name=L["hideInCombat"], desc=L["hideInCombatDesc"]
						},
					}
				},
				background = {
					type="group", order = 97, inline=true,
					name=L["BgMinimap"],
					args={
						desc = {
							type="description", order=0,
							name=L["BgMinimapDesc"]
						},
						background_alpha = {
							type = "range", order = 1,
							name = L["BgTransparency1"], desc = L["BgTransparencyDesc1"],
							min = 0.0, max = 1, step = 0.1, isPercent = true,
							get = function()
								return 1-FarmHudDB.background_alpha
							end,
							set = function(info,value)
								FarmHudDB.background_alpha = 1-value;
								FarmHud:UpdateOptions("background_alpha");
							end
						},
						background_alpha2 = {
							type = "range", order = 2,
							name = L["BgTransparency2"], desc = L["BgTransparencyDesc2"],
							min = 0.0, max = 1, step = 0.1, isPercent = true,
							get = function()
								return 1-FarmHudDB.background_alpha2
							end,
							set = function(info,value)
								FarmHudDB.background_alpha2 = 1-value;
								FarmHud:UpdateOptions("background_alpha2");
							end
						},
						background_alpha_default = {
							type = "toggle", order = 4,
							name = L["BgAlphaDefault"],
							desc = L["BgAlphaDefaultDesc"]
						}
					}
				},
				placeholder = {
					type = "group", order = 98, inline = true,
					name = L["Placeholder"],
					args = {
						desc = {
							type = "description", order = 0, fontSize = "medium",
							name = L["PlaceholderDesc"]
						},
						showDummy = {
							type = "toggle", order = 1,
							name = L["ShowPlaceholder"], desc = L["ShowPlaceholderDesc"]
						},
						showDummyBg = {
							type = "toggle", order = 2,
							name = L["ShowPlaceholderBg"], desc = L["ShowPlaceholderBgDesc"]
						},
					}
				},
				mouseover = {
					type = "group", order = 99, inline=true,
					name = L["MouseOver"],
					args = {
						holdKeyForMouseOn = {
							type = "select", order = 3, width="double";
							name = L["MouseOverOnHold"],
							desc = L["MouseOverOnHoldDesc"],
							values = {
								["_NONE"] = NONE.."/"..ADDON_DISABLED,
								A  = ALT_KEY,
								AL = LALT_KEY_TEXT,
								AR = RALT_KEY_TEXT,
								C  = CTRL_KEY,
								CL = LCTRL_KEY_TEXT,
								CR = RCTRL_KEY_TEXT,
								S  = SHIFT_KEY,
								SL = LSHIFT_KEY_TEXT,
								SR = RSHIFT_KEY_TEXT,
							}
						},
						mouseoverinfo_textscale = {
							type = "range", order = 13,
							name = L["TextScale"], desc = L["TextScaleDesc"],
							min = 1, max = 2.5, step = 0.1, isPercent = true
						},
						mouseoverinfo_color = {
							type = "color", order = 1,
							name = COLOR, desc = L["MouseOverInfoColorDesc"],
							hasAlpha = true
						},
						mouseoverinfo_resetcolor = {
							type = "execute", order = 2,
							name = L["ResetColor"], --desc = L["ResetColorDesc"]
						},
					}
				}
			}
		},

		keybindings = {
			type = "group", order = 2,
			name = KEY_BINDINGS,
			get = optKeyBind,
			set = optKeyBind,
			args = {
				TOGGLEFARMHUD = {
					type = "keybinding", order = 1, width = "double",
					name = L["KeyBindToggle"], desc = L["KeyBindToggleDesc"]
				},
				TOGGLEFARMHUDMOUSE = {
					type = "keybinding", order = 2, width = "double",
					name = L["KeyBindMouse"], desc = L["KeyBindMouseDesc"]
				},
				TOGGLEFARMHUDBACKGROUND = {
					type = "keybinding", order = 3, width = "double",
					name = L["KeyBindBackground"], desc = L["KeyBindBackgroundDesc"]
				},
			}
		},

		separator1 = {
			type = "group", order=50,
			name=" ",
			args = {},
			disabled = true
		},

		headerModules={
			type = "group", order=51,
			name=groupColor..L["Modules"].."|r",
			args = {},
			disabled = true
		},

		-- debugging = {
		-- 	type = "group", order = 100,
		-- 	name = BINDING_HEADER_DEBUG,
		-- 	hidden=true,
		-- 	args = {
		-- 		info = {
		-- 			type = "description", order = 1, fontSize = "med",
		-- 			name = L["DebugOptInfo"]
		-- 		},
		-- 		frames = {
		-- 			type = "execute", order = 2,
		-- 			name = L["DebugOptFrames"],
		-- 			func = printFrames
		-- 		}
		-- 	}
		-- },
	},
	plugins = {}
};

local InfoMessageAdd
do
	local InfoMessageIndex=1
	local InfoMessage = {
		type = "group", order = 0,
		name = groupColor..INFO.."|r",
		args = {
			desc = {
				type = "description", fontSize = "large",
				name = "|cffffcc00"..table.concat(L["InfoMessage"..ns.InfoMessageIndex],"|n|n").."|r"
			}
		}
	}
	function InfoMessageAdd()
		local t = time()
		local timeout = 43200 -- a half day in seconds
		if FarmHudDB.InfoMessageShown==ns.InfoMessageIndex and FarmHudDB.InfoMessageTime~=nil and (t-FarmHudDB.InfoMessageTime)>timeout then
			return -- don't add it
		end
		options.args.info = InfoMessage
		FarmHudDB.InfoMessageShown = ns.InfoMessageIndex
		FarmHudDB.InfoMessageTime = t
	end
end

local function UpdateGroupNames(tbl)
	if tbl.type=="group" then
		if type(tbl.name)=="string" and tbl.name~="" and not tbl.name:match("^\124") and tbl.inline then
			tbl.name = groupColor..tbl.name.."|r"
		end
		for _, child in pairs(tbl.args) do
			UpdateGroupNames(child)
		end
		if tbl.plugins then
			for _,plg in pairs(tbl.plugins) do
				for _, plgEntry in pairs(plg) do
					UpdateGroupNames(plgEntry)
				end
			end
		end
	end
end

function ns.RegisterOptions()
	if FarmHudDB==nil then
		FarmHudDB={};
	end

	if FarmHudDB.MinimapIcon==nil then
		FarmHudDB.MinimapIcon = {
			hide = false,
			minimapPos = 220,
			radius = 80
		};
	end

	local modOptsOrder = 52;
	for modName, mod in pairs(ns.modules)do
		if mod.dbDefaults then
			for k,v in pairs(mod.dbDefaults)do
				if (dbDefaults[k]==nil) then
					dbDefaults[k] = v
					modDB[k] = modName;
				end
			end
		end
		if mod.AddOptions then
			local opts = mod.AddOptions()
			if type(opts)=="table" then
				for _,v in pairs(opts)do
					if v.order==nil then
						v.order = modOptsOrder;
					end
				end
				options.plugins[modName] = opts
			end
		end
	end

	-- little migration
	if FarmHudDB.text_scale~=nil then
		if FarmHudDB.mouseoverinfo_textscale==nil then
			FarmHudDB.mouseoverinfo_textscale = FarmHudDB.text_scale
		end
		if FarmHudDB.cardinalpoints_textscale==nil then
			FarmHudDB.cardinalpoints_textscale1 = FarmHudDB.text_scale
			FarmHudDB.cardinalpoints_textscale2 = FarmHudDB.text_scale
		end
		if FarmHudDB.coords_textscale==nil then
			FarmHudDB.coords_textscale = FarmHudDB.text_scale
		end
		if FarmHudDB.time_textscale==nil then
			FarmHudDB.time_textscale = FarmHudDB.text_scale
		end
		FarmHudDB.text_scale=nil
	end

	for k,v in pairs(dbDefaults)do
		if FarmHudDB[k]==nil then
			FarmHudDB[k]=v;
		end
	end

	if FarmHudDB.hud_size==0 then
		FarmHudDB.hud_size=1;
	end

	if FarmHudDB.MinimapIcon.show~=nil then
		FarmHudDB.MinimapIcon.hide = not FarmHudDB.MinimapIcon.show;
		FarmHudDB.MinimapIcon.show = nil;
	end

	InfoMessageAdd()
	UpdateGroupNames(options)

	LibStub("AceConfig-3.0"):RegisterOptionsTable(addon, options);
	LibStub("AceConfigDialog-3.0"):AddToBlizOptions(addon);

	LibStub("HizurosSharedTools").AddCredit(addon,options.args,{supporter=supporter,order=6});
end

if AddonCompartmentFrame then
	AddonCompartmentFrame:RegisterAddon({
		icon = 134215,
		text = addon,
		notCheckable = true,
		func = FarmHudMixin.ToggleOptions
	 })
end
