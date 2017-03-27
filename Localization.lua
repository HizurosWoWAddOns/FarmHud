
local addon, ns = ...

ns.L = setmetatable({},{__index=function(t,k)
	local v = tostring(k)
	rawset(t,k,v)
	return v
end})

-- Do you want to help localize this addon?
-- https://wow.curseforge.com/projects/farmhud/localization

if LOCALE_deDE then
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
end

if LOCALE_zhTW then
	L["A Hud for farming ore and herbs."] = "一個雷達幫助你農礦石以及草藥"
	L["Click"] = "點選"
	L["Coordinations on bottom"] = "底部座標"
	L["Direction indicators"] = "方位提示"
	L["Display player coordinations on bottom"] = "在底部顯示玩家座標"
	L["E"] = "東"
	L["Enable Bloodhound2 support"] = "啟用 Bloodhound2 支援"
	L["Enable GatherMate2 support"] = "啟用 GatherMate2 支援"
	L["Enable NPCScan support"] = "啟用 NPCScan 支援"
	L["Enable Routes support"] = "啟用 Routes 支援"
	L["Enable TomTom support"] = "啟用 TomTom 支援"
	L["Enable/Disable custom bordered quest and archaeology blobs"] = "啟用/停用 自訂邊界給任務和考古區域"
	L["FarmHud Options"] = "FarmHud選項"
	L["Green gather circle"] = "綠色採集圈圈"
	L["Keybind Options"] = "快捷建設定"
	L["Minimap Icon"] = "小地圖圖示"
	L["MOUSE ON"] = "滑鼠開啟"
	L["N"] = "北"
	L["NE"] = "東北"
	L["NW"] = "西北"
	L["Or macro with /script FarmHud:Toggle()"] = "或是使用巨集 /script FarmHud:Toggle()"
	L["Player coordinations"] = "玩家座標"
	L["Right click"] = "右鍵"
	L["S"] = "南"
	L["SE"] = "東南"
	L["Set the keybinding to allow mouse over tooltips."] = "設定快捷建來允許滑鼠提示"
	L["Set the keybinding to show FarmHud."] = "射的快捷建來顯示FarmHud"
	L["Show or hide player coordinations"] = "顯示或隱藏座標"
	L["Show or hide the direction indicators"] = "顯示或隱藏方位"
	L["Show or hide the green gather circle"] = "顯示或隱藏綠色的採集圈圈"
	L["Show or hide the minimap icon."] = "顯示或隱藏小地圖圖示"
	L["Support Options"] = "支援選項"
	L["SW"] = "西南"
	L["to config"] = "開啟設定"
	L["to toggle FarmHud"] = "打開農人雷達"
	L["Toggle FarmHud's Display"] = "開啟FarmHud的顯示"
	L["Toggle FarmHud's tooltips (Can't click through Hud)"] = "開啟FarmHud的提示 (無法點選hud後面的東西)"
	L["W"] = "西"
end
