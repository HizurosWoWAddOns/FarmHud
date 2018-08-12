
local addon, ns = ...

local L = {};
ns.L = setmetatable(L,{__index=function(t,k)
	local v = tostring(k)
	rawset(t,k,v)
	return v
end});

-- Do you want to help localize this addon?
-- https://wow.curseforge.com/projects/farmhud/localization

--@do-not-package@
L["AddOnLoaded"] = "AddOn loaded..."
L["AddOnLoadedDesc"] = "Show 'AddOn loaded...' message on login"
L["AreaBorder"] = "Area border"
L["AreaBorderByClient"] = "Use tracking option from game client"
L["AreaBorderOnHUD"] = "%s area border in HUD"
L["BgTransparency"] = "Background transparency"
L["CardinalPoints"] = "Cardinal points"
L["CardinalPointsColorDesc"] = "Adjust the color of cardinal points (%s)"
L["CardinalPointsColorResetDesc"] = "Reset the color of cardinal points (%s)"
L["CardinalPointsGroup1"] = "N, W, S, E"
L["CardinalPointsGroup2"] = "NW, NE, SW, SE"
L["CardinalPointsShow"] = "Show cardinal points"
L["CardinalPointsShowDesc"] = "Display the cardinal points on HUD"
L["ChangeRadius"] = "Distance from center"
L["ChangeRadiusDesc"] = "Change the distance from center from the HUD"
L["Coords"] = "Coordinations"
L["CoordsBottom"] = "Coordinations on bottom"
L["CoordsBottomDesc"] = "Display the player coordinations on bottom"
L["CoordsColorDesc"] = "Adjust the color of coordations"
L["CoordsColorResetDesc"] = "Reset the color of coordations"
L["CoordsShow"] = "Show coordinations"
L["CoordsShowDesc"] = "Show player coordinations on HUD"
L["DataBrokerOptions"] = "to open FarmHud options"
L["DataBrokerToggle"] = "to toggle FarmHud"
L["E"] = "E"
L["GatherCircle"] = "Gather circle"
L["GatherCircleColorDesc"] = "Adjust the color of the gather circle"
L["GatherCircleDesc"] = "The gather circle is a visual help line. It stands for the distance around your position in there all points of interest (mailbox, ore, herb) will be appear on minimap and FarmHud"
L["GatherCircleShow"] = "Show gather circle"
L["GatherCircleShowDesc"] = "Show the gather circle on HUD"
L["HudSymbolScale"] = "HUD symbol scale"
L["HudSymbolScaleDesc"] = "Scale the symbols on HUD"
L["KeyBindBackground"] = "Toggle FarmHud's minimap background"
L["KeyBindBackgroundDesc"] = "Set the keybinding to show minimap background."
L["KeyBindMouse"] = "Toggle FarmHud's tooltips (Can't click through Hud)"
L["KeyBindMouseDesc"] = "Set the keybinding to allow mouse over for tooltips from point of interest nodes (like ore,herb or quest giver). Or for clicking on the hud to submit a ping to your group or raid."
L["KeyBindToggle"] = "Toggle FarmHud's Display"
L["KeyBindToggleDesc"] = "Set the keybinding to show FarmHud."
L["MinimapIcon"] = "Minimap Icon"
L["MinimapIconDesc"] = "Show the minimap icon."
L["MouseOn"] = "MOUSE ON"
L["MouseOver"] = "Mouse over options"
L["MouseOverOnHold"] = "Mouse over on hold modifier key"
L["MouseOverOnHoldDesc"] = "This is an option to enable mouse over mode while you are holding a modifier key like Alt"
L["N"] = "N"
L["NE"] = "NE"
L["NW"] = "NW"
L["OnScreen"] = "OnScreen buttons"
L["OnScreenAlphaDesc"] = "Adjust the transparency the the OnScreen buttons"
L["OnScreenBottom"] = "OnScreen buttons on bottom"
L["OnScreenBottomDesc"] = "Display the OnScreen buttons on bottom from center of the HUD"
L["OnScreenShow"] = "Show OnScreen buttons"
L["OnScreenShowDesc"] = "Show OnScreen buttons (\"mouse on\"-mode, hud close button and more)"
L["PlayerDot"] = "Player arrow or dot"
L["PlayerDotDesc"] = "Change the look of your player dot/arrow on opened FarmHud"
L["ResetColor"] = "Reset color"
L["S"] = "S"
L["SE"] = "SE"
L["SupportBlizzard"] = "Blizzard have made some changes that makes useless to offer optional support of single addons or libraries."
L["SupportHereBeDragon"] = "Tomtom and HandyNotes are supported through the library HereBeDragon but HandyNotes have a problem with Hud toggling. All icons around you position will be disappear by toggling FarmHud. But through a littble bit walking/flying arround should be displayed again."
L["SupportOptions"] = "Support options"
L["SW"] = "SW"
L["TextScale"] = "Text scale"
L["TextScaleDesc"] = "Text scaling on HUD for cardinal points, mouse on and coordinations"
L["W"] = "W"
L["Rotation"] = "Rotation"
L["RotationDesc"] = "Force enable minimap rotation on HUD mode"
L["Time"] = "Server/Local time"
L["TimeShow"] = "Show time"
L["TimeShowDesc"] = "Display server or local time on HUD mode"
L["TimeServer"] = "Server time"
L["TimeServerDesc"] = "Display server time otherwise local time"
L["TimeBottom"] = "Time on bottom"
L["TimeBottomDesc"] = "Display the time on bottom"
L["TimeColorDesc"] = "Adjust the color of time"
L["TimeColorResetDesc"] = "Reset the color of time"
--L["BgTransparencyDesc"] = ""
--L["KeyMouseOverDesc"] = ""
--L["MouseOverInfoColorDesc"] = "Adjust color for the text 'MOUSE ON' on the HUD"
--L["MouseOverInfoKeybind"] =
--L["ResetColorDesc"] = ""
--@end-do-not-package@

--@localization(locale="enUS", format="lua_additive_table", handle-subnamespaces="none", handle-unlocalized="ignore")@

if LOCALE_deDE then
--@do-not-package@
	L["AddOnLoaded"] = "AddOn geladen..."
	L["AddOnLoadedDesc"] = "Zeige \"AddOn geladen...\" Mitteilung beim Login"
	L["AreaBorder"] = "Gebietsgrenze"
	L["AreaBorderByClient"] = "Nutze Aufspur-Option vom Spiel"
	L["AreaBorderOnHUD"] = "%s Gebietsgrenze auf dem HUD"
	L["BgTransparency"] = "Hintergrundtransparenz"
	L["CardinalPoints"] = "Himmelsrichtungen"
	L["CardinalPointsColorDesc"] = "Ändere die Farbe der Himmelsrichtungen (%s)"
	L["CardinalPointsColorResetDesc"] = "Die Farbe der Himmelsrichtungen (%s) zurücksetzen"
	L["CardinalPointsGroup1"] = "N, W, S, O"
	L["CardinalPointsGroup2"] = "NW, NO, SW, SO"
	L["CardinalPointsShow"] = "Zeige Himmelsrichtungen"
	L["CardinalPointsShowDesc"] = "Zeige die Himmelsrichtungen auf dem HUD"
	L["ChangeRadius"] = "Distanz zum Zentrum"
	L["ChangeRadiusDesc"] = "Ändere die Distanze zum Zentrum vom HUD"
	L["Coords"] = "Koordinaten"
	L["CoordsBottom"] = "Koordinaten unten"
	L["CoordsBottomDesc"] = "Zeige die Spielerkoordinaten unten"
	L["CoordsColorDesc"] = "Ändere die Farbe der Koordinaten"
	L["CoordsColorResetDesc"] = "Die Farbe der Koordinaten zurücksetzen"
	L["CoordsShow"] = "Zeige Spielerkoordinaten"
	L["CoordsShowDesc"] = "Zeige die Spielerkoordinaten auf dem HUD"
	L["DataBrokerOptions"] = "zum öffnen der FarmHud Optionen"
	L["DataBrokerToggle"] = "um FarmHud ein-/auszublenden"
	L["E"] = "O"
	L["GatherCircle"] = "Sammelkreis"
	L["GatherCircleColorDesc"] = "Ändere die Farbe des Sammelkreises"
	L["GatherCircleDesc"] = "Der Sammelkreis ist eine visuelle Hilfslinie. Sie steht für die Distanz um deine Position, in der alle Punkte von Interesse (Briefkasten, Erze, Kräuter) auf Minikarte und FarmHud erscheinen"
	L["GatherCircleShow"] = "Zeige Sammelkreis"
	L["GatherCircleShowDesc"] = "Zeige den Sammelkreis auf dem HUD"
	L["HudSymbolScale"] = "HUD Symbolskalierung"
	L["HudSymbolScaleDesc"] = "Skaliere die Symbole auf dem HUD"
	L["KeyBindBackground"] = "FarmHud's Minikartenhintergrund umschalten"
	L["KeyBindBackgroundDesc"] = "Setzte eine Tastaturbelegung zum Anzeigen des Minikartenhintergrunds"
	L["KeyBindMouse"] = "FarmHud's tooltips umschalten (Kann nicht durch Hud klicken)"
	L["KeyBindToggle"] = "FarmHud's Anzeige umschalten"
	L["KeyBindToggleDesc"] = "Setze eine Tastaturbelegung um FarmHud anzuzeigen"
	L["MinimapIcon"] = "Minikartensymbol"
	L["MinimapIconDesc"] = "Zeige das Minikartensymbol"
	L["MouseOn"] = "MAUS AN"
	L["MouseOver"] = "Mausdrüber Optionen"
	L["MouseOverOnHold"] = "Mausdrüber beim Halten einer Zusatztaste"
	L["MouseOverOnHoldDesc"] = "Dies ist eine Option zum aktieren des Mausdrüber-Modus solange du eine Zusatztaste wie Alt gedrückt hälst"
	L["N"] = "N"
	L["NE"] = "NO"
	L["NW"] = "NW"
	L["OnScreen"] = "OnScreen Schaltflächen"
	L["OnScreenAlphaDesc"] = "Ändere die Transparenz der OnScreen Schaltflächen"
	L["OnScreenBottom"] = "OnScreen Schaltflächen unten"
	L["OnScreenBottomDesc"] = "Zeige die OnScreen Schaltflächen unterhalb des Zentrums vom HUD an"
	L["OnScreenShow"] = "Zeige OnScreen Schaltflächen"
	L["OnScreenShowDesc"] = "Zeige OnScreen Schaltflächen (\"Maus an\"-Modus, Hud-Schließen-Schaltflächen und mehr)"
	L["PlayerDot"] = "Spielerpfeil oder Punkt"
	L["PlayerDotDesc"] = "Verändere das Aussehen deines Spielerpunkts/-pfeils im geöffneten FarmHud"
	L["ResetColor"] = "Farbe zurücksetzen"
	L["S"] = "S"
	L["SE"] = "SO"
	L["SupportBlizzard"] = "Blizzard hat ein paar Änderungen gemacht, die es Nutzslos machen noch optionale Unterstützungen für einzelne AddOns und Bibliotheken anzubieten."
	L["SupportHereBeDragon"] = "TomTom und HandyNotes werden durch die Bibliothek HereBeDragon unterstützt, aber HandyNotes hat ein Problem beim Umschalten des HUD's. Alle Symbole um deine Position verschwinden beim ein/-ausblenden von FarmHud. Aber durch ein wenig herumlaufen/-fliegen sollten sie bald wieder angezeigt werden."
	L["SupportOptions"] = "Unterstützungsoptionen"
	L["SW"] = "SW"
	L["TextScale"] = "Textskalierung"
	L["TextScaleDesc"] = "Textskalierung auf dem HUD für Himmelsrichtungen, \"MAUS AN\" und Koordinaten"
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

if LOCALE_ptBR or LOCALE_ptPT then
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
BINDING_NAME_TOGGLEFARMHUD = L.KeyBindToggle;
BINDING_NAME_TOGGLEFARMHUDMOUSE	= L.KeyBindMouse;
BINDING_NAME_TOGGLEFARMHUDBACKGROUND = L.KeyBindBackground;
