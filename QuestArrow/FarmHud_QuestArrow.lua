
local SetSuperTrackedQuestID_Orig,TrackedQuestID = SetSuperTrackedQuestID

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
		SetSuperTrackedQuestID = SetSuperTrackedQuestID_Replacement;
		TrackedQuestID = GetSuperTrackedQuestID();
		SetSuperTrackedQuestID_Orig(0);
		msg = "QuestArrowInfoMsgDisabled";
	elseif state==false and tonumber(TrackedQuestID) and TrackedQuestID>0 then
		SetSuperTrackedQuestID = SetSuperTrackedQuestID_Orig;
		SetSuperTrackedQuestID_Orig(TrackedQuestID);
		msg = "QuestArrowInfoMsgRestored";
	end
	if msg and token and FarmHudDB.QuestArrowInfoMsg then
		FarmHud:Print(token,msg);
	end
end

