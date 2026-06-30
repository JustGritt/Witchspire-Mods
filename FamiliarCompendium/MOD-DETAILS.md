# Familiar Compendium

## Description

Adds a "pokedex" panel to the game so you can track your familiar collection at a glance. Press P to open a floating window that lists every familiar species grouped by element, marks the ones you've already caught, and shows how many are still left to find in each element. It's read-only, so nothing in your game or save gets changed.

## Config

You can change the hotkey by editing `FamiliarCompendium.as`:

1. Open the file and locate `ToggleKey`:
```
const FKey ToggleKey = EKeys::P;
```
2. Change the value to any other key, e.g. to set the G hotkey -> `EKeys::G`

## Installation Instructions

1. Download and extract the archive
2. Navigate to your game folder and check if a "Mods" folder exists, if not create one at:
   `C:\Program Files (x86)\Steam\steamapps\common\Witchspire\Hercules\Script\Mods`
3. Copy/paste `FamiliarCompendium.as` into the "Mods" folder
4. Fully restart the game
