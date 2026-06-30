# Quick Deposit

## Description

Press H while you're at your base and everything in your backpack gets quick-stacked into the chests that already hold those items. Stuff your chests don't already store stays in your bag, and your toolbar items are never touched. Outside your base the key does nothing.

This one is for single-player / when you're hosting.

## Config

You can change the hotkey by editing `QuickDeposit.as`:

1. Open the file and locate `HotkeyKey`:
```
const FKey HotkeyKey = EKeys::H;
```
2. Change the value to any other key, e.g. to set the G hotkey -> `EKeys::G`

## Installation Instructions

1. Download and extract the archive
2. Navigate to your game folder and check if a "Mods" folder exists, if not create one at:
   `C:\Program Files (x86)\Steam\steamapps\common\Witchspire\Hercules\Script\Mods`
3. Copy/paste `QuickDeposit.as` into the "Mods" folder
4. Fully restart the game
