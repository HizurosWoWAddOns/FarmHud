
local addon, ns = ...

local L = {};
ns.L = setmetatable(L,{__index=function(t,k)
	local v = tostring(k)
	rawset(t,k,v)
	return v
end});

-- Do you want to help localize this addon?
-- https://wow.curseforge.com/projects/farmhud/localization

--@localization(locale="enUS", format="lua_additive_table", handle-subnamespaces="none", handle-unlocalized="ignore")@

if LOCALE_deDE then
--@do-not-package@
	L["Click"] = "Klick"
	L["Direction indicators"] = "Himmelsrichtungen"
	L["E"] = "O"
	L["Enable Bloodhound2 support"] = "Aktiviere BloodHound2 Unterstützung"
	L["Enable GatherMate2 support"] = "Aktiviere GatherMate2 Unterstützung"
	L["Enable NPCScan support"] = "Aktiviere NPCScan Unterstützung"
	L["Enable Routes support"] = "Aktiviere Routes Unterstützung"
	L["Enable TomTom support"] = "Aktiviere TomTom Unterstützung"
	L["FarmHud Options"] = "FarmHud Optionen"
	L["Keybind Options"] = "Tastaturbelegungsoptionen"
	L["Minimap Icon"] = "Minikartensymbol"
	L["MOUSE ON"] = "MAUS AN"
	L["N"] = "N"
	L["NE"] = "NO"
	L["NW"] = "NW"
	L["Or macro with /script FarmHud:Toggle()"] = "Oder Makro mit /script FarmHud:Toggle()"
	L["Player coordinations"] = "Spielerkoordinaten"
	L["Right click"] = "Rechtsklick"
	L["S"] = "S"
	L["SE"] = "SO"
	L["Show or hide player coordinations"] = "Zeige oder verstecke die Spielerkoordinaten"
	L["Show or hide the direction indicators"] = "Zeige oder verstecke die Himmelsrichtungen"
	L["Show or hide the minimap icon."] = "Zeige oder verstecke das Minikartensymbol"
	L["Support Options"] = "Unterstützungsoptionen"
	L["SW"] = "SW"
	L["to toggle FarmHud"] = "um FarmHud ein-/auszublenden"
	L["W"] = "W"
--@end-do-not-package@
--@localization(locale="deDE", format="lua_additive_table", handle-subnamespaces="none", handle-unlocalized="ignore")@
end

if LOCALE_esES then
--@localization(locale="esES", format="lua_additive_table", handle-subnamespaces="none", handle-unlocalized="ignore")@
end

if LOCALE_esMX then
--@localization(locale="esMX", format="lua_additive_table", handle-subnamespaces="none", handle-unlocalized="ignore")@
end

if LOCALE_frFR then
--@localization(locale="frFR", format="lua_additive_table", handle-subnamespaces="none", handle-unlocalized="ignore")@
end

if LOCALE_itIT then
--@localization(locale="itIT", format="lua_additive_table", handle-subnamespaces="none", handle-unlocalized="ignore")@
end

if LOCALE_koKR then
--@localization(locale="koKR", format="lua_additive_table", handle-subnamespaces="none", handle-unlocalized="ignore")@
end

if LOCALE_ptBR then
--@localization(locale="ptBR", format="lua_additive_table", handle-subnamespaces="none", handle-unlocalized="ignore")@
end

if LOCALE_ruRU then
--@localization(locale="ruRU", format="lua_additive_table", handle-subnamespaces="none", handle-unlocalized="ignore")@
end

if LOCALE_zhCN then
--@localization(locale="zhCN", format="lua_additive_table", handle-subnamespaces="none", handle-unlocalized="ignore")@
end

if LOCALE_zhTW then
--@localization(locale="zhTW", format="lua_additive_table", handle-subnamespaces="none", handle-unlocalized="ignore")@
end

BINDING_HEADER_FARMHUD = addon;
BINDING_NAME_TOGGLEFARMHUD = L["Toggle FarmHud's Display"];
BINDING_NAME_TOGGLEFARMHUDMOUSE	= L["Toggle FarmHud's tooltips (Can't click through Hud)"];
BINDING_NAME_TOGGLEFARMHUDBACKGROUND = L["Toggle FarmHud's minimap background"];
