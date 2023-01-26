# FarmHud (WoW AddOn)
![Build](https://github.com/HizurosWoWAddOns/FarmHud/actions/workflows/bigwigsmods-packager.yml/badge.svg)
![Tag](https://img.shields.io/github/v/tag/HizurosWoWAddOns/FarmHud?style=flat-square)
![Downloads](https://img.shields.io/github/downloads/HizurosWoWAddOns/FarmHud/total?style=flat-square)
![Downloads](https://img.shields.io/github/downloads/HizurosWoWAddOns/FarmHud/latest/total?style=flat-square)
&nbsp; &nbsp; &nbsp; &nbsp;
[![Patreon](https://img.shields.io/badge/&zwj;-Patreon-gray?logo=patreon&color=red&style=flat-square)](https://www.patreon.com/bePatron?u=12558524)
[![Paypal](https://img.shields.io/badge/&zwj;-Paypal-gray?logo=paypal&color=blue&style=flat-square)](https://paypal.me/hizuro)
![Sponsors](https://img.shields.io/github/sponsors/HizurosWoWAddOns?logo=github&style=flat-square)

## Description
Turn your minimap into a hud for farming ore / herb.

![FarmHud Screenshot1](./.github/media/farmhud1.jpg) ![FarmHud Screenshot2](./.github/media/farmhud2.jpg)

## Minimap / Nodes / FarmHud
Blizzard has designed the Minimap element as All-in-One (Terrain texture + Nodes).
It could not be separated. It could not be copied. Minimap and FarmHud can't be displayed at the same time.
While mouseover is activated (Mouse on), the area for access to the 3D world is limited to the left and right on the screen boundaries.
*(It's like the Highlander: There can only be one.)*

## Contains
* Gather circle *( color / transparency adjustable )*
* Direction indicators (cardinal points) *( color / transparency adjustable )*
* Player coordinations *( color / transparency adjustable )*
* Minimap button (and broker panel integration) *( optional )*
* Show minimap terrain texture *( transparency adjustable )*
* Key bindings
* OnScreen buttons *( transparency adjustable )*
  * Toggle mouseover mode
  * Toggle background
  * Toggle option panel
  * Close HUD
* Tracking options *( retail client only )*
* !! New experimental module !! TrailPath
   * Display your path on Minimap/FarmHud with red arrows.
   * Color, transparency and icons are adjustable
TrailPath - Display your path on minimap and farmhud with red arrows. Color, transparency and icons are adjustable.Trail path options

## Option panel
The option panel are available over  Game Menu > Interface > AddOns > FarmHud
or by chat command  `/run FarmHud:ToggleOptions()`

## Supports
* GatherMate2
* Routes
* \_NPCScan.Overlay *( outdated )*
* Bloodhound2 *( outdated )*
* By library LibHijackMinimap
  * Magneto *( outdated, owner is missing )*
* By library HereBeDragon
  * TomTom
  * HandyNotes

## Addon compatibility
I know it is not a complete list of addons, but you can report addons for the list.
From time to time i will look on updated versions.

## Minimap AddOns
* BasicMinimap v9.2.0 | Okay
* bdMinimap v1.53 | Unknown -- *outdated since 9.x*
* Chinchilla Minimap v2.12.2 | Okay
* Mappy v3.8.5 | Unknown -- *outdated since 9.x*
* ObeliskMinimap r14 | Okay  -- *outdated since 9.x / owner is missing*
* SexyMap v9.2.0 | Okay

## UI AddOns
* ElvUI | Okay
* GW2_UI R1.913_Retail | Difficulty -- *No Lua errors but could not move some elements to placeholder.*
  * QuestTracker disappears (move out of screen). Calendar and minimap button container moved on screen.

## Problems and possible workarounds
1. Use of anonymous frames makes correct functioning more difficult. Possible workaround: Disable "Show elements" in FarmHud Options.

## @Authors of Minimap and UI AddOns
I've added a function to register (anonymous) frames that anchored on Minimap.
Please use it to make smooth cooperation between our AddOns possible.
* `FarmHud:RegisterForeignAddOnObject( <frame object>, <addon name>)`
* Or let me known your function i could trigger on show and hide farmhud.

## Dragonflight problems
* I'm currently getting error messages after changing the keyboard layout. Hope it only happens to me.

## Bug reports, feature requests and Support
* [Bug reports & feature requests on Github](https://github.com/HizurosWoWAddOns/FarmHud/issues)
* [Comments & Criticism on Curseforge](https://www.curseforge.com/wow/addons/farmhud)

## Localization
Do you want to help translate this addon?
See Curseforge localization tool

## Macro functions
* `/run FarmHud:Toggle()`
* `/run FarmHud:ToggleMouse()`
* `/run FarmHud:ToggleBackground()`
* `/run FarmHud:ToggleOptions()`

## Our other projects
* [TorvaldsMP1's projects](https://www.curseforge.com/members/torvaldsmp1/projects) (also known as CodeRedLin before Twitch as purchased Curseforge)
* Hizuro's projects on: [Curseforge](https://www.curseforge.com/members/hizuro_de/projects) or [Github](https://github.com/HizurosWoWAddOns?tab=repositories)

## Disclaimer
> World of Warcraft© and Blizzard Entertainment© are all trademarks or registered trademarks of Blizzard Entertainment in the United States and/or other countries. These terms and all related materials, logos, and images are copyright © Blizzard Entertainment.
