
local addon,ns=...;
local L=ns.L;

function ns.RegisterDataBroker()
	local LDBObject = {
		type	= "launcher",
		icon	= 134215,
		label	= addon,
		text	= addon,
		OnTooltipShow = function(tt)
			tt:AddLine(addon);
			tt:AddLine(("|cffffff00%s|r %s"):format(KEY_BUTTON1,L["DataBrokerToggle"]));
			tt:AddLine(("|cffffff00%s|r %s"):format(KEY_BUTTON2,L["DataBrokerOptions"]));
			tt:AddLine(("|cffffff00%s|r %s"):format(SHIFT_KEY.."+"..KEY_BUTTON1,L["DataBrokerToggleBackground"]));
		end,
		OnClick = function(_, button)
			if button=="LeftButton" and IsShiftKeyDown() then
				FarmHud:ToggleBackground();
			elseif button=="LeftButton" then
				FarmHud:Toggle();
			else
				FarmHud:ToggleOptions();
			end
		end
	};

	local LDB = LibStub("LibDataBroker-1.1"):NewDataObject(addon,LDBObject);
	local LDBIcon = LDB and LibStub("LibDBIcon-1.0", true);
	if LDBIcon then
		LDBIcon:Register(addon, LDB, FarmHudDB.MinimapIcon);
	end
end
