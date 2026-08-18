
-- module created by Mayron@github.

local _, ns = ...;
local L = ns.L;

local suppressArrow = false;
local hookInstalled = false;

local module = {
	dbDefaults = {
		hideTomTomArrow = false,
	},
	events = {},
};

local function IsTomTomAvailable()
	local TomTom = _G.TomTom;
	return TomTom and _G.TomTomCrazyArrow and TomTom.ShowHideCrazyArrow;
end

local function InstallShowHook()
	if not _G.TomTomCrazyArrow then
		return;
	end
	hooksecurefunc(_G.TomTomCrazyArrow, "Show", function(self)
		if suppressArrow then
			self:Hide();
		end
	end);
end

local function SetSuppressed(state)
	if not IsTomTomAvailable() then
		return;
	end

	if InstallShowHook then
		InstallShowHook();
		InstallShowHook = nil
	end
	suppressArrow = state;

	if state then
		_G.TomTomCrazyArrow:Hide();
	elseif _G.TomTom.ShowHideCrazyArrow then
		_G.TomTom:ShowHideCrazyArrow();
	end
end

local function ShouldSuppress()
	return FarmHudDB.hideTomTomArrow and IsTomTomAvailable();
end

function module.OnShow()
	if ShouldSuppress() then
		SetSuppressed(true);
	end
end

function module.OnHide()
	if IsTomTomAvailable() then
		SetSuppressed(false);
	end
end

function module.UpdateOptions(key)
	if key == "hideTomTomArrow" then
		SetSuppressed(ShouldSuppress());
	end
end

function module.events.ADDON_LOADED(eventFrame,loadedAddon)
	if loadedAddon ~= "TomTom" then return end
	eventFrame:UnregisterEvent("ADDON_LOADED")
	if FarmHud:IsShown() and FarmHudDB.hideTomTomArrow then
		SetSuppressed(true);
	end
end

local function opt(info, value)
	local key = info[#info];
	if value ~= nil then
		FarmHudDB[key] = value;
		module.UpdateOptions(key);
	end
	return FarmHudDB[key];
end

function module.AddOptions()
	return {
		tomtom_integrations = {
			type = "group",
			order = 98,
			name = "TomTom",
			hidden = function()
				return not IsTomTomAvailable();
			end,
			get = opt,
			set = opt,
			args = {
				hideTomTomArrow = {
					type = "toggle",
					order = 1,
					width = "full",
					name = L["TomTomHideArrow"],
					desc = L["TomTomHideArrowDesc"],
				},
			},
		},
	}
end

ns.modules["TomTomIntegration"] = module;
