
local addon, ns = ...;
local L = ns.L;
local SaveBindings = SaveBindings or AttemptToSaveBindings
local playerDot_textures = {
	["blizz"]         = L["Blizzards player arrow"],
	["blizz-smaller"] = L["Blizzards player arrow (smaller)"],
	["gold"]          = L["Golden player dot"],
	["white"]         = L["White player dot"],
	["black"]         = L["Black player dot"],
	["hide"]          = L["Hide player arrow"],
};
local TrackingValues = {
	["true"] = SHOW,
	["false"] = HIDE,
	["client"] = L["TrackingOptionsLikeMinimap"]
}
local dbDefaults = {
	hud_scale=1.4, text_scale=1.4, hud_size=1,
	gathercircle_show=true,gathercircle_color={0,1,0,0.5},
	cardinalpoints_show=true,cardinalpoints_color1={1,0.82,0,0.7},cardinalpoints_color2={1,0.82,0,0.7},cardinalpoints_radius=0.47,
	coords_show=true,coords_bottom=false,coords_color={1,0.82,0,0.7},coords_radius=0.51,
	buttons_show=false,buttons_buttom=false,buttons_alpha=0.6,buttons_radius=0.56,
	time_show=true, time_server=true, time_local=true, time_radius = 0.48, time_bottom=false, time_color={1,0.82,0,0.7},
	mouseoverinfo_color={1,0.82,0,0.7},
	player_dot="blizz", background_alpha=0, holdKeyForMouseOn = "_none",
	rotation=true, SuperTrackedQuest = true, showDummy = true, showDummyBg = true,
	QuestArrowInfoMsg = false,
	healcircle_show=true,healcircle_color={0,.7,1,0.5},
}
local excludeFrames = {}
local isAddOnsLoadedForOption = {
	SuperTrackedQuest = {
		addon="FarmHud_QuestArrow",
		descLoaded=GREEN_FONT_COLOR_CODE..L.ExtraAddOnLoaded:format("FarmHud [QuestArrow]").."|r",
		descNotLoaded=ORANGE_FONT_COLOR_CODE..L.ExtraAddOnNotLoaded:format("FarmHud [QuestArrow]").."|r"
	}
}

local function printFrames(key,value)
	local keyType = type(key);
	if keyType=="table" then
		if not FarmHud:IsVisible() then
			ns.print("FarmHud must be enabled before use this option");
			return;
		end

		ns.print("Search for unwanted elements anchored on minimap...");
		local count = 0;
		local regions = {Minimap:GetRegions()};
		for r=1, #regions do
			print("GetRegions()"," - ",regions[r]:GetDebugName());
			count = count + 1;
		end

		--ns.print("Search for unwanted frames anchored on minimap... (deep reverse search)");
		for k,v in pairs(_G) do
			if not (issecurevariable(_G,k)) and (not excludeFrames[key]) and (type(value)=="table") and (type(value[0])=="userdata") and (not (value:IsProtected() or value:IsForbidden())) then
				if printFrames(k,v) then
					count = count + 1;
				end
			end
		end

		--ns.print("Search for unwanted textures/fontstrings anchored on minimap...");
		local childs = {Minimap:GetChildren()};
		for i=1, #childs do
			print("GetChildren()"," - ",childs[i]:GetDebugName());
			count = count + 1;
		end

		if count>0 then
			ns.print("Finished...");
		else
			ns.print("No elements found...");
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

local function checkAddOnLoaded(info)
	local key,pKey = info[#info],info[#info-1];
	if isAddOnsLoadedForOption[key] then
		return not IsAddOnLoaded(isAddOnsLoadedForOption[key].addon);
	elseif isAddOnsLoadedForOption[pKey] then
		local isLoaded = IsAddOnLoaded(isAddOnsLoadedForOption[pKey].addon) and "Loaded" or "NotLoaded";
		if isAddOnsLoadedForOption[pKey][key..isLoaded] then
			return isAddOnsLoadedForOption[pKey][key..isLoaded];
		elseif isAddOnsLoadedForOption[pKey][key] then
			return isAddOnsLoadedForOption[pKey][key];
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

local function optTracking(info,value)
	local key = info[#info];
	if not key:find("^tracking^%d+$") then return end

	if value~=nil then
		FarmHudDB[key] = value;
		FarmHud:UpdateOptions(key);
		return;
	end
	return FarmHudDB[key];
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
			name = COMPACT_UNIT_FRAME_PROFILE_SUBTYPE_ALL,
			args = {
				MinimapIcon = {
					type = "toggle", order = 1,
					name = L.MinimapIcon, desc = L.MinimapIconDesc
				},
				AddOnLoaded = {
					type = "toggle", order = 2,
					name = L.AddOnLoaded, desc = L.AddOnLoadedDesc
				},
				rotation = {
					type = "toggle", order = 3, width="full",
					name = L.Rotation, desc = L.RotationDesc
				},
				hud_scale = {
					type = "range", order = 11,
					name = L.HudSymbolScale, desc = L.HudSymbolScaleDesc,
					min = 1, max = 2.5, step = 0.1, isPercent = true
				},
				hud_size = {
					type = "range", order = 12,
					name = L.HudSize, desc = L.HudSizeDesc,
					min = 0.4, max = 1, step = 0.1, isPercent = true
				},
				text_scale = {
					type = "range", order = 13,
					name = L.TextScale, desc = L.TextScaleDesc,
					min = 1, max = 2.5, step = 0.1, isPercent = true
				},
				background_alpha = {
					type = "range", order = 14,
					name = L.BgTransparency, --desc = L.BgTransparencyDesc
					min = 0.0, max = 1, step = 0.1, isPercent = true,
					get = function()
						return 1-FarmHudDB.background_alpha
					end,
					set = function(info,value)
						FarmHudDB.background_alpha = 1-value;
						FarmHud:UpdateOptions("background_alpha");
					end
				},
				player_dot = {
					type = "select", order = 15,
					name = L.PlayerDot, desc = L.PlayerDotDesc,
					values = playerDot_textures
				},
				placeholder = {
					type = "group", order = 19, inline = true,
					name = L.Placeholder,
					args = {
						desc = {
							type = "description", order = 0, fontSize = "medium",
							name = L.PlaceholderDesc
						},
						showDummy = {
							type = "toggle", order = 1,
							name = L.ShowPlaceholder, desc = L.ShowPlaceholderDesc
						},
						showDummyBg = {
							type = "toggle", order = 2,
							name = L.ShowPlaceholderBg, desc = L.ShowPlaceholderBgDesc
						}
					}
				},
				mouseover = {
					type = "group", order = 20, inline=true,
					name = L.MouseOver,
					args = {
						holdKeyForMouseOn = {
							type = "select", order = 3, width="double";
							name = L.MouseOverOnHold,
							desc = L.MouseOverOnHoldDesc,
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
						mouseoverinfo_color = {
							type = "color", order = 1,
							name = COLOR, desc = L.MouseOverInfoColorDesc,
							hasAlpha = true
						},
						mouseoverinfo_resetcolor = {
							type = "execute", order = 2,
							name = L.ResetColor, --desc = L.ResetColorDesc
						},
					}
				}
			}
		},
		----------------------------------------------
		SuperTrackedQuest = {
			type = "group", order = 1,
			name = L.QuestArrow,
			args = {
				desc = {
					type = "description", order=1, fontSize="medium",
					name = checkAddOnLoaded,-- ({"SuperTrackedQuest","desc"}),
				},
				SuperTrackedQuest = {
					type = "toggle", order = 2, width = "full",
					name = L["QuestArrowHide"], --desc = L["QuestArrowHideDesc"],
					disabled = checkAddOnLoaded
				},
				QuestArrowInfoMsg = {
					type = "toggle", order = 3, width = "full",
					name = L["QuestArrowInfoMsg"], desc = L["QuestArrowInfoMsgDesc"]
				}
			}
		},
		rangecircles = {
			type = "group", order = 2,
			name = L.RangeCircles,
			args = {
				-- gathercircle
				gathercircle = {
					type = "header", order = 10,
					name = L.GatherCircle,
				},
				gathercircle_desc = {
					type = "description", order = 11, fontSize = "medium",
					name = L.GatherCircleDesc
				},
				gathercircle_show = {
					type = "toggle", order = 12, width = "double",
					name = L.GatherCircleShow, desc = L.GatherCircleShowDesc
				},
				gathercircle_color = {
					type = "color", order = 13,
					name = COLOR, desc = L.GatherCircleColorDesc,
					hasAlpha = true
				},
				gathercircle_resetcolor = {
					type = "execute", order = 14,
					name = L.ResetColor, --desc = L.ResetColorDesc
				},
				-- healcircle
				healcircle = {
					type = "header", order = 20,
					name = L.HealCircle,
				},
				healcircle_desc = {
					type = "description", order = 21, fontSize = "medium",
					name = L.HealcircleDesc
				},
				healcircle_show = {
					type = "toggle", order = 22, width = "double",
					name = L.HealcircleShow, desc = L.HealcircleShowDesc
				},
				healcircle_color = {
					type = "color", order = 23,
					name = COLOR, desc = L.HealcircleColorDesc,
					hasAlpha = true
				},
				healcircle_resetcolor = {
					type = "execute", order = 24,
					name = L.ResetColor, --desc = L.ResetColorDesc
				},
			}
		},
		cardinalpoints = {
			type = "group", order = 3,
			name = L.CardinalPoints,
			args = {
				cardinalpoints_show = {
					type = "toggle", order = 1, width = "double",
					name = L.CardinalPointsShow, desc = L.CardinalPointsShowDesc,
				},
				cardinalpoints_radius = {
					type = "range", order = 2,
					name = L.ChangeRadius, desc = L.ChangeRadiusDesc,
					min = 0.1, max = 0.9, step=0.005, isPercent=true
				},
				cardinalpoints_header1 = {
					type = "header", order = 3,
					name = L.CardinalPointsGroup1
				},
				cardinalpoints_color1 = {
					type = "color", order = 4, hasAlpha = true,
					name = COLOR, desc = L.CardinalPointsColorDesc:format(L.CardinalPointsGroup1)
				},
				cardinalpoints_resetcolor1 = {
					type = "execute", order = 5,
					name = L.ResetColor, desc = L.CardinalPointsColorResetDesc:format(L.CardinalPointsGroup1)
				},
				cardinalpoints_header2 = {
					type = "header", order = 6,
					name = L.CardinalPointsGroup2
				},
				cardinalpoints_color2 = {
					type = "color", order = 7, hasAlpha = true,
					name = COLOR, desc = L.CardinalPointsColorDesc:format(L.CardinalPointsGroup2)
				},
				cardinalpoints_resetcolor2 = {
					type = "execute", order = 8,
					name = L.ResetColor, desc = L.CardinalPointsColorResetDesc:format(L.CardinalPointsGroup2)
				}
			}
		},
		coords = {
			type = "group", order = 4,
			name = L.Coords,
			args = {
				coords_show = {
					type = "toggle", order = 1,
					name = L.CoordsShow, desc = L.CoordsShowDesc
				},
				coords_radius = {
					type = "range", order = 2,
					name = L.ChangeRadius, desc = L.ChangeRadiusDesc,
					min = 0.1, max = 0.9, step=0.005, isPercent=true
				},
				coords_bottom = {
					type = "toggle", order = 3, width = "double",
					name = L.CoordsBottom, desc = L.CoordsBottomDesc
				},
				coords_color = {
					type = "color", order = 4, hasAlpha = true,
					name = COLOR, desc = L.CoordsColorDesc
				},
				coords_resetcolor = {
					type = "execute", order = 5,
					name = L.ResetColor, desc = L.CoordsColorResetDesc
				}
			}
		},
		time = {
			type = "group", order = 5,
			name = L.Time,
			args = {
				time_show = {
					type = "toggle", order = 1, width = "full",
					name = L.TimeShow, desc = L.TimeShowDesc
				},
				time_server = {
					type = "toggle", order = 2,
					name = L.TimeServer, desc = L.TimeServerDesc
				},
				time_local = {
					type = "toggle", order = 3,
					name = L.TimeLocal, desc = L.TimeLocalDesc
				},
				time_radius = {
					type = "range", order = 4,
					name = L.ChangeRadius, desc = L.ChangeRadiusDesc,
					min = 0.1, max = 0.9, step=0.005, isPercent=true
				},
				time_bottom = {
					type = "toggle", order = 5, width = "double",
					name = L.TimeBottom, desc = L.TimeBottomDesc
				},
				time_color = {
					type = "color", order = 6, hasAlpha = true,
					name = COLOR, desc = L.TimeColorDesc
				},
				time_resetcolor = {
					type = "execute", order = 7,
					name = L.ResetColor, desc = L.TimeColorResetDesc
				},
			}
		},
		onscreenbuttons = {
			type = "group", order = 6,
			name = L.OnScreen,
			args = {
				buttons_show = {
					type = "toggle", order = 1, width = "double",
					name = L.OnScreenShow, desc = L.OnScreenShowDesc
				},
				buttons_bottom = {
					type = "toggle", order = 2, width = "double",
					name = L.OnScreenBottom, desc = L.OnScreenBottomDesc,
				},
				buttons_radius = {
					type = "range", order = 3,
					name = L.ChangeRadius, desc = L.ChangeRadiusDesc,
					min = 0.1, max = 0.9, step=0.005, isPercent=true
				},
				buttons_alpha = {
					type = "range", order = 4,
					name = OPACITY, desc = L.OnScreenAlphaDesc,
					min = 0, max = 1, step = 0.1, isPercent = true
				}
			}
		},
		tracking = {
			type = "group", order = 8,
			name = L.TrackingOptions,
			get = optTracking, set = optTracking,
			childGroups = "tab",
			args = {
				desc = {
					type = "description", order = 1, fontSize = "medium",
					name = L.TrackingOptionsDesc
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
		},
		keybindings = {
			type = "group", order = 99,
			name = KEY_BINDINGS,
			get = optKeyBind,
			set = optKeyBind,
			args = {
				TOGGLEFARMHUD = {
					type = "keybinding", order = 1, width = "double",
					name = L.KeyBindToggle, desc = L.KeyBindToggleDesc
				},
				TOGGLEFARMHUDMOUSE = {
					type = "keybinding", order = 2, width = "double",
					name = L.KeyBindMouse, desc = L.KeyBindMouseDesc
				},
				TOGGLEFARMHUDBACKGROUND = {
					type = "keybinding", order = 3, width = "double",
					name = L.KeyBindBackground, desc = L.KeyBindBackgroundDesc
				},
			}
		},
		debugging = {
			type = "group", order = 100,
			name = BINDING_HEADER_DEBUG,
			args = {
				info = {
					type = "description", order = 1, fontSize = "med",
					name = L["DebugOptInfo"]
				},
				frames = {
					type = "execute", order = 2,
					name = L["DebugOptFrames"],
					func = printFrames
				}
			}
		}
	}
};

local trackingTypes,trackingOpts,trackingTemplate = {},{},{
	type = "select", name = "", values = TrackingValues
};
local trackingPattern = "|T%d:26:26:0:0|t %s"

local function sortTrackingTypes(a,b)
	return a.index<b.index;
end

local function updateTrackingOptions(info)
	if info[#info]~="tracking" then return false end
	if ns.IsClassic() then
		return true;
	end
	wipe(options.args.tracking.args.townsfolk.args);
	wipe(options.args.tracking.args.misc.args);
	trackingTypes = ns.GetTrackingTypes(); -- defined in FarmHud.lua
	table.sort(trackingTypes,sortTrackingTypes);
	for textureId,data in pairs(trackingTypes)do
		local key = "tracking^"..textureId;
		if trackingOpts[textureId]==nil then
			trackingOpts[textureId] = CopyTable(trackingTemplate);
			trackingOpts[textureId].name = trackingPattern:format(textureId,data.name);
			trackingOpts[textureId].order = data.index;
		end
		if data.level==2 then -- townfolk
			options.args.tracking.args.townsfolk.args[key] = trackingOpts[textureId]
			options.args.tracking.args.townsfolk.hidden=false;
		else -- misc
			options.args.tracking.args.misc.args[key] = trackingOpts[textureId];
			options.args.tracking.args.misc.hidden=false;
		end
	end
	return false;
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

	if not ns.IsClassic() then
		trackingTypes = ns.GetTrackingTypes();
		for id, data in pairs(trackingTypes)do
			dbDefaults["tracking^"..id] = "client"
		end
	end

	for k,v in pairs(dbDefaults)do
		if (FarmHudDB[k]==nil) then
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

	if not ns.IsClassic() then
		for id, data in pairs(trackingTypes)do
			local v = FarmHudDB["tracking^"..id];
			if not (v=="client" or v=="true" or v=="false") then
				FarmHudDB["tracking^"..id] = "client";
			end
		end
		options.args.tracking.hidden = updateTrackingOptions
	else
		options.args.tracking = nil;
	end


	LibStub("AceConfig-3.0"):RegisterOptionsTable(addon, options);
	LibStub("AceConfigDialog-3.0"):AddToBlizOptions(addon);
end
