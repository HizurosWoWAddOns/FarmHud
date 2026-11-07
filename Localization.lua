
local L, addon, ns = {}, ...;

ns.L = setmetatable(L,{__index=function(t,k)
	local v = tostring(k);
	rawset(t,k,v);
	return v;
end});

-- Do you want to help localize this addon?
-- https://www.curseforge.com/wow/addons/@cf-project-name@/localization

L["CardinalPointsBindingDisabled"] = "Gathercircle binding is temporarily disabled as long as Range Circles are not available."

ns.InfoMessageIndex = 1
L["InfoMessage1"] = {
	"Hi",
	"Due to a few changes, the positions of the time, coordinates, on-screen buttons, and cardinal points may shift for you. I would like to apologize for any inconvenience this may cause.",
	"The text sizes for MOUSE ON, time, coordinates, and cardinal points can now be scaled individually.",
	"For Forever, I have temporarily disabled the range circles.",
	"Greetings Hizuro"
}

--@localization(locale="enUS", format="lua_additive_table", handle-subnamespaces="none", handle-unlocalized="ignore")@

if LOCALE_deDE then
	L["InfoMessage1"] = {
		"Hi",
		"Durch ein paar Änderungen kann es bei euch zu geänderten Positionen von Zeit, Koordinaten, OnScreen Schaltflächen und Himmelsrichtungen kommen. Dafür möchte ich mich hier für die Unannehmlichkeiten entschuldigen.",
		"Die Textgrößen für MAUS AN, Zeit, Koordinaten und Himmelsrichtungen lassen sich nun einzeln skalieren.",
		"Für Forever habe ich die Reichweitenkreise vorrübergehend deaktiviert.",
		"",
		"Gruß Hizuro"
	}
--@localization(locale="deDE", format="lua_additive_table", handle-subnamespaces="none", handle-unlocalized="ignore")@
elseif LOCALE_esES then
--@localization(locale="esES", format="lua_additive_table", handle-subnamespaces="none", handle-unlocalized="ignore")@
elseif LOCALE_esMX then
--@localization(locale="esMX", format="lua_additive_table", handle-subnamespaces="none", handle-unlocalized="ignore")@
elseif LOCALE_frFR then
--@localization(locale="frFR", format="lua_additive_table", handle-subnamespaces="none", handle-unlocalized="ignore")@
elseif LOCALE_itIT then
--@localization(locale="itIT", format="lua_additive_table", handle-subnamespaces="none", handle-unlocalized="ignore")@
elseif LOCALE_koKR then
--@localization(locale="koKR", format="lua_additive_table", handle-subnamespaces="none", handle-unlocalized="ignore")@
elseif LOCALE_ptBR or LOCALE_ptPT then
--@localization(locale="ptBR", format="lua_additive_table", handle-subnamespaces="none", handle-unlocalized="ignore")@
elseif LOCALE_ruRU then
--@localization(locale="ruRU", format="lua_additive_table", handle-subnamespaces="none", handle-unlocalized="ignore")@
elseif LOCALE_zhCN then
--@localization(locale="zhCN", format="lua_additive_table", handle-subnamespaces="none", handle-unlocalized="ignore")@
elseif LOCALE_zhTW then
--@localization(locale="zhTW", format="lua_additive_table", handle-subnamespaces="none", handle-unlocalized="ignore")@
end

BINDING_HEADER_FARMHUD = addon;
BINDING_NAME_TOGGLEFARMHUD = L.KeyBindToggle;
BINDING_NAME_TOGGLEFARMHUDMOUSE	= L.KeyBindMouse;
BINDING_NAME_TOGGLEFARMHUDBACKGROUND = L.KeyBindBackground;
