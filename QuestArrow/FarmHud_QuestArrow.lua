
local SetSuperTrackedQuestID_Orig,TrackedQuestID = SetSuperTrackedQuestID

function SetSuperTrackedQuestID(questID)
	questID = tonumber(questID) or 0;
	if questID~=0 and GetSuperTrackedQuestID()==0 and FarmHudDB.SuperTrackedQuest and FarmHud:IsVisible() then
		TrackedQuestID = questID
		return;
	end
	SetSuperTrackedQuestID_Orig(questID);
end

function FarmHud_ToggleSuperTrackedQuest(state)
	local currentID = GetSuperTrackedQuestID();
	if state==nil then
		state = currentID~=0;
	end
	if state and currentID~=0 then
		TrackedQuestID = GetSuperTrackedQuestID();
		SetSuperTrackedQuestID_Orig(0);
	elseif state==false and tonumber(TrackedQuestID) and TrackedQuestID>0 then
		SetSuperTrackedQuestID_Orig(TrackedQuestID);
	end
end

