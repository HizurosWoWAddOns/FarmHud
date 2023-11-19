
if not LibStub.libs["HizurosSharedTools"] or C_AddOns.GetAddOnMetadata("FarmHud","Version")~="@project-version@" then
	local FarmHudInvalidInstallation = "Your current installation of FarmHud is invalid. Please uninstall all other addons with 'FarmHud' in its name and reinstall FarmHud."
	StaticPopupDialogs["FARMHUD_INVALID_INSTALLATION"] = {
		text = FarmHudInvalidInstallation,
		button1 = OKAY,
		showAlert = 1,
		timeout = 0,
		whileDead = 1,
	};
	StaticPopup_Show("FARMHUD_INVALID_INSTALLATION")
end

local addon, ns = ...;
ns.debugMode = "@project-version@"=="@".."project-version".."@";
LibStub("HizurosSharedTools").RegisterPrint(ns,addon,"FH/QA");

local GetSuperTrackedQuestID,SetSuperTrackedQuestID_Orig,TrackedQuestID = GetSuperTrackedQuestID,SetSuperTrackedQuestID;

if C_SuperTrack then
	GetSuperTrackedQuestID = C_SuperTrack.GetSuperTrackedQuestID;
	SetSuperTrackedQuestID_Orig = C_SuperTrack.SetSuperTrackedQuestID;
end

local function SetSuperTrackedQuestID_Replacement(questID)
	questID = tonumber(questID) or 0;
	if questID~=0 and GetSuperTrackedQuestID()==0 and FarmHudDB.SuperTrackedQuest and FarmHud:IsVisible() then
		TrackedQuestID = questID
		return;
	end
	SetSuperTrackedQuestID_Orig(questID);
end

function FarmHud_ToggleSuperTrackedQuest(token,state)
	if state==nil then return; end
	local msg, currentID = false,GetSuperTrackedQuestID();
	if state and currentID~=0 then
		if C_SuperTrack then
			C_SuperTrack.SetSuperTrackedQuestID = SetSuperTrackedQuestID_Replacement;
		else
			SetSuperTrackedQuestID = SetSuperTrackedQuestID_Replacement;
		end
		TrackedQuestID = GetSuperTrackedQuestID();
		SetSuperTrackedQuestID_Orig(0);
		msg = "QuestArrowInfoMsgDisabled";
	elseif state==false and tonumber(TrackedQuestID) and TrackedQuestID>0 then
		if C_SuperTrack then
			C_SuperTrack.SetSuperTrackedQuestID = SetSuperTrackedQuestID_Orig;
		else
			SetSuperTrackedQuestID = SetSuperTrackedQuestID_Orig;
		end
		SetSuperTrackedQuestID_Orig(TrackedQuestID);
		msg = "QuestArrowInfoMsgRestored";
	end
	if msg and token and FarmHudDB.QuestArrowInfoMsg then
		if FarmHud.AddChatMessage then
			FarmHud:AddChatMessage(token,msg);
		else
			ns:print(msg); -- fallback without localizations from main addon
		end
	end
end

