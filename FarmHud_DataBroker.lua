
local addon,ns=...;
local L=ns.L;

function ns.RegisterDataBroker()
	local LDB = LibStub("LibDataBroker-1.1"):NewDataObject(addon,{
		type	= "launcher",
		icon	= "Interface\\Icons\\INV_Misc_Herb_MountainSilverSage",
		label	= addon,
		text	= addon,
		OnTooltipShow = function(tt)
			tt:AddLine(addon);
			tt:AddLine(("|cffffff00%s|r %s"):format(L["Click"],L["to toggle FarmHud"]));
			tt:AddLine(("|cffffff00%s|r %s"):format(L["Right click"],L["to config"]));
			tt:AddLine(L["Or macro with /script FarmHud_Toggle()"]);
		end,
		OnClick = function(_, button)
			if button=="LeftButton" then
				FarmHud:Toggle();
			else
				FarmHud:ToggleOptions();
			end
		end
	});

	local LDBIcon = LDB and LibStub("LibDBIcon-1.0", true);

	if (LDBIcon) then
		LDBIcon:Register(addon, LDB, FarmHudDB.MinimapIcon);
	end
end
