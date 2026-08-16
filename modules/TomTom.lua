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
	if hookInstalled or not _G.TomTomCrazyArrow then
		return;
	end
	hooksecurefunc(_G.TomTomCrazyArrow, "Show", function(self)
		if suppressArrow then
			self:Hide();
		end
	end);
	hookInstalled = true;
end

local function SetSuppressed(state)
	if not IsTomTomAvailable() then
		return;
	end

	InstallShowHook();
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

local function ApplySuppression()
	SetSuppressed(ShouldSuppress());
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
		ApplySuppression();
	end
end

function module.events.ADDON_LOADED(loadedAddon)
	if loadedAddon == "TomTom" and FarmHud:IsShown() and FarmHudDB.hideTomTomArrow then
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

local options = {
	integrations = {
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
				name = L["HideTomTomArrow"],
				desc = L["HideTomTomArrowDesc"],
			},
		},
	},
};

function module.AddOptions()
	return options;
end

ns.modules["TomTomIntegration"] = module;
