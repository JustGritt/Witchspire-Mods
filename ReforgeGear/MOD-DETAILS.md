# Reforge Gear

## Description

Adds a reroll feature to the game for the gear or familiar that is your active item.

**Reforge Altar**
Spawns a little floating window when pressing F9 to reroll the substats of the held gear or familiar. It costs 100 gold per reroll.

**Reforge Altar - Cheat GUI**
Enables the debug GUI and adds a reroll menu under the Cheats section. Use F7 to show the debug GUI; sets reroll cost to 0 gold and shows all available substats.

**Reforge Altar - Full**
Enables both the Reforge Altar and the debug menu. Use F10 to add 1000 gold to your inventory.

> Pick one edition — only one can be installed at a time, so copy in just the `.as` file you want.

**God Forge** (optional companion file)
Grants a piece of gear or a familiar and lets you hand-pick its substats instead of rerolling one you own. Press F8 → Cheats → God Forge. Installs alongside any Reforge edition.

## Config

You can change the hotkeys by editing `ReforgeAltar.as`:

1. Open the file and locate `SummonAltarKey`, `ToggleMenuKey` or `DebugGoldKey`:
```
const FKey ToggleMenuKey = EKeys::F7;
const FKey SummonAltarKey = EKeys::F9;
const FKey DebugGoldKey = EKeys::F10;
```
2. Change the value to any other key, e.g. to set the G hotkey -> `EKeys::G`

## Installation Instructions

1. Download and extract the archive
2. Navigate to your game folder and check if a "Mods" folder exists, if not create one at:
   `C:\Program Files (x86)\Steam\steamapps\common\Witchspire\Hercules\Script\Mods`
3. Copy/paste `ReforgeAltar.as` into the "Mods" folder
4. Fully restart the game
