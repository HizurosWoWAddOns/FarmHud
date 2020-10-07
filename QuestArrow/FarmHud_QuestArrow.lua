
local addon, ns = ...;
do
	local addon_short = "FH";
	local colors = {"0099ff","00ff00","ff6060","44ffff","ffff00","ff8800","ff44ff","ffffff"};
	local function colorize(...)
		local t,c,a1 = {tostringall(...)},1,...;
		if type(a1)=="boolean" then tremove(t,1); end
		if a1~=false then
			local header = "FarmHud (QuestArrow)";
			if a1==true then
				header = addon_short;
			elseif a1=="||" then
				header = "||";
			elseif a1=="()" then
				header = header .. " (" ..t[2]..")";
				tremove(t,2);
				tremove(t,1);
			end
			tinsert(t,1,"|cff0099ff"..header.."|r"..(a1~="||" and HEADER_COLON or ""));
			c=2;
		end
		for i=c, #t do
			if not t[i]:find("\124c") then
				t[i],c = "|cff"..colors[c]..t[i].."|r", c<#colors and c+1 or 1;
			end
		end
		return unpack(t);
	end
	function ns.print(...)
		print(colorize(...));
	end
end

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
			ns.print(msg); -- fallback without localizations from main addon
		end
	end
end

