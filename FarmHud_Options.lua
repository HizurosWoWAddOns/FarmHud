
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
			LibStub("LibDBIcon-1.0", true):Refresh(addon);
		else
			if (...) then
				value = {value,...}; -- color table
			end
			FarmHudDB[key] = value;
		end
		FarmHud:UpdateOptions(key);
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
			type = "group", order = 0,
			name = L["General"],
			args = {
				MinimapIcon = {
					type = "toggle", order = 1,
					name = L["Minimap Icon"],
					desc = L["Show or hide the minimap icon."]
				},
				AddOnLoaded = {
					type = "toggle", order = 2,
					name = L["AddOn loaded..."],
					desc = L["Show 'AddOn loaded...' message on login"] -- new
				},
				spacer0 =  {
					type = "description", order = 10,
					name = " ", fontSize = "medium"
				},
				hud_scale = {
					type = "range", order = 11,
					name = L["HUD symbol scale"],
					desc = L["Scale the symbols on HUD"],
					min = 1, max = 2.5, step = 0.1, isPercent = true
				},
				text_scale = {
					type = "range", order = 12,
					name = L["Text scale"],
					desc = L["Scale text on HUD for cardinal points, mouse on and coordinations"],
					min = 1, max = 2.5, step = 0.1, isPercent = true
				},
				background_alpha = {
					type = "range", order = 13,
					name = L["Background transparency"],
					min = 0.1, max = 1, step = 0.1, isPercent = true
				},
				player_dot = {
					type = "select", order = 14,
					name = L["Player arrow or dot"],
					desc = L["Change the look of your player dot/arrow on opened FarmHud"],
					values = playerDot_textures
				},
				spacer1 =  {
					type = "description", order = 20,
					name = " ", fontSize = "medium"
				},
				mouseoverinfo_color = {
					type = "color", order = 21,
					name = L["Mouse over info color"],
					hasAlpha = true
				},
				mouseoverinfo_resetcolor = {
					type = "execute", order = 22,
					name = L["Reset color"]
				},
				spacer2 =  {
					type = "description", order = 23,
					name = " ", fontSize = "medium"
				},
				holdKeyForMouseOn = {
					type = "select", order = 24,
					name = L["Hold key for mouseover"],
					values = {
						["_NONE"] = NONE.."/"..ADDON_DISABLED,
						A  = L["Alt"],
						AL = L["Left alt"],
						AR = L["Right alt"],
						C  = L["Control"],
						CL = L["Left control"],
						CR = L["Right control"],
						S  = L["Shift"],
						SL = L["Left shift"],
						SR = L["Right shift"],
					}
				},
				supports = {
					type = "group", order = 25, inline=true,
					name = L["Support Options"],
					get = function() return true; end,
					args = {
						desc = {
							type = "description", order = 0, fontSize = "medium",
							name = L["Blizzard have made a background change that makes useless to offer optional support of single addons or libraries."]
						},
						desc2 = {
							type = "description", order = 99, fontSize = "small",
							name = L["Tomtom and HandyNotes are supported through the library HereBeDragon but HandyNotes have a problem with Hud toggling. All icons around you position will be disappear by toggling FarmHud. But you can walk or fly with opened FarmHud and the nodes come back."]
						},
						gathermate  = {type="toggle", order=1, disabled=true, name="GatherMate2"},
						routes      = {type="toggle", order=1, disabled=true, name="Routes"},
						npcscan     = {type="toggle", order=1, disabled=true, name="NPCScan"},
						bloodhound2 = {type="toggle", order=1, disabled=true, name="BloodHound2"},
						tomtom      = {type="toggle", order=1, disabled=true, name="TomTom"},
						handynotes  = {type="toggle", order=1, disabled=true, name="HandyNotes"}
					}
				}
			}
		},
		----------------------------------------------
		gathercircle = {
			type = "group", order = 1,
			name = L["Garther circle"],
			args = {
				gathercircle_show = {
					type = "toggle", order = 1, width = "double",
					name = L["Show gather circle"],
					desc = L["Show or hide the gather circle"]
				},
				gathercircle_color = {
					type = "color", order = 2,
					name = L["Color"],
					hasAlpha = true
				},
				gathercircle_resetcolor = {
					type = "execute", order = 3,
					name = L["Reset color"]
				}
			}
		},
		cardinalpoints = {
			type = "group", order = 2,
			name = L["Cardinal points"],
			args = {
				cardinalpoints_show = {
					type = "toggle", order = 1, width = "double",
					name = L["Show cardinal points"],
					desc = L["Show or hide the direction indicators"],
				},
				cardinalpoints_radius = {
					type = "range", order = 2,
					name = L["Distance from center"],
					desc = L["Change the distance from center"],
					min = 0.1, max = 0.9, step=0.005, isPercent=true
				},
				cardinalpoints_header1 = {
					type = "header", order = 3,
					name = L["N, W, S, E"]
				},
				cardinalpoints_color1 = {
					type = "color", order = 4, hasAlpha = true,
					name = L["Color"],
					desc = L["Adjust color and transparency of cardinal points N, W, S, E"]
				},
				cardinalpoints_resetcolor1 = {
					type = "execute", order = 5,
					name = L["Reset color"],
					desc = L["Reset color and transparency of cardinal points N, W, S, E"]
				},
				cardinalpoints_header2 = {
					type = "header", order = 6,
					name = L["NW, NE, SW, SE"]
				},
				cardinalpoints_color2 = {
					type = "color", order = 7, hasAlpha = true,
					name = L["Color"],
					desc = L["Adjust color and transparency of cardinal points NW, NE, SW, SE"]
				},
				cardinalpoints_resetcolor2 = {
					type = "execute", order = 8,
					name = L["Reset color"],
					desc = L["Reset color and transparency of cardinal points NW, NE, SW, SE"]
				}
			}
		},
		coords = {
			type = "group", order = 3,
			name = L["Coordinations"],
			args = {
				coords_show = {
					type = "toggle", order = 1,
					name = L["Player coordinations"],
					desc = L["Show or hide player coordinations"]
				},
				coords_radius = {
					type = "range", order = 2,
					name = L["Distance from center"],
					desc = L["Change the distance from center"],
					min = 0.1, max = 0.9, step=0.005, isPercent=true
				},
				coords_bottom = {
					type = "toggle", order = 3, width = "double",
					name = L["Coordinations on bottom"],
					desc = L["Display player coordinations on bottom"]
				},
				coords_color = {
					type = "color", order = 4, hasAlpha = true,
					name = L["Color"],
					desc = L["Adjust color and transparency of coordations"]
				},
				coords_resetcolor = {
					type = "execute", order = 5,
					name = L["Reset color"],
					desc = L["Reset color and transparency of coordations"]
				}
			}
		},
		onscreenbuttons = {
			type = "group", order = 4,
			name = L["OnScreen buttons"],
			args = {
				buttons_show = {
					type = "toggle", order = 1, width = "double",
					name = L["Show OnScreen buttons"],
					desc = L["Show or hide OnScreen buttons (mouse mode and close hud button)"]
				},
				buttons_bottom = {
					type = "toggle", order = 2, width = "double",
					name = L["OnScreen buttons on bottom"],
					desc = L["Display toggle buttons on bottom"],
				},
				buttons_radius = {
					type = "range", order = 3,
					name = L["Distance from center"],
					desc = L["Change the distance from center"],
					min = 0.1, max = 0.9, step=0.005, isPercent=true
				},
				buttons_alpha = {
					type = "range", order = 4,
					name = L["Transparency"],
					min = 0, max = 1, step = 0.1, isPercent = true
				}
			}
		},
		areaborder = {
			type = "group", order = 5,
			name = L["Area border"],
			args = {
				areaborder_arch_header = {
					type = "header", order = 10,
					name = TRACKING.." > "..MINIMAP_TRACKING_DIGSITES,
				},
				areaborder_arch_show = {
					type = "select", order = 11, width = "double",
					name = L["%s area border in HUD"]:format(L["Archaeology"]),
					values = {
						["true"] = L["Show"],
						["false"] = L["Hide"],
						["blizz"] = L["Use tracking option from game client"]
					}
				},
				areaborder_quest_header = {
					type = "header", order = 20,
					name = TRACKING.." > "..MINIMAP_TRACKING_QUEST_POIS,
				},
				areaborder_quest_show = {
					type = "select", order = 21, width = "double",
					name = L["%s area border in HUD"]:format(L["Quest"]),
					values = {
						["true"] = L["Show"],
						["false"] = L["Hide"],
						["blizz"] = L["Use tracking option from game client"]
					}
				},
			}
		},
		keybindings = {
			type = "group", order = 6,
			name = L["Keybind Options"],
			get = optKeyBind,
			set = optKeyBind,
			args = {
				TOGGLEFARMHUD = {
					type = "keybinding", order = 1, width = "double",
					name = L["Toggle FarmHud's Display"],
					desc = L["Set the keybinding to show FarmHud."]
				},
				TOGGLEFARMHUDMOUSE = {
					type = "keybinding", order = 2, width = "double",
					name = L["Toggle FarmHud's tooltips (Can't click through Hud)"],
					desc = L["Set the keybinding to allow mouse over tooltips."]
				},
				TOGGLEFARMHUDBACKGROUND = {
					type = "keybinding", order = 3, width = "double",
					name = L["Toggle FarmHud's minimap background"],
					desc = L["Set the keybinding to show minimap background."]
				},
			}
		},
	}
};

function ns.RegisterOptions()
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

	LibStub("AceConfig-3.0"):RegisterOptionsTable(addon, options);
	LibStub("AceConfigDialog-3.0"):AddToBlizOptions(addon);
end
