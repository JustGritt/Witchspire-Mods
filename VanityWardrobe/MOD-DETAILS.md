# Vanity Wardrobe

## Description

Transmog for your witch: change how your gear LOOKS without changing what it DOES. Your equipped gear keeps all of its stats, you just pick a different appearance to wear over it.

Press F6 to summon a Wardrobe in front of you. Put the gear whose look you want into a hotbar slot, select it, then use your Interact key on the Wardrobe to apply that look (Interact with the same item again to revert). Press F7 instead to open a panel where you can browse every item in the game and pick any look per slot.

## Config

You can change the hotkeys by editing `VanityWardrobe.as`:

1. Open the file and locate `ToggleMenuKey` or `SummonWardrobeKey`:
```
const FKey ToggleMenuKey = EKeys::F7;
const FKey SummonWardrobeKey = EKeys::F6;
```
2. Change the value to any other key, e.g. to set the G hotkey -> `EKeys::G`

## Installation Instructions

1. Download and extract the archive
2. Navigate to your game folder and check if a "Mods" folder exists, if not create one at:
   `C:\Program Files (x86)\Steam\steamapps\common\Witchspire\Hercules\Script\Mods`
3. Copy/paste `VanityWardrobe.as` into the "Mods" folder
4. Fully restart the game
