# Infinite Endurance

## Description

A simple toggle in the Cheats menu that keeps your endurance topped up so it never runs out — both your on-foot stamina (sprint and dodge forever, no Exhaustion) and your broom's boost power (hold boost without dropping back to a glide).

Press **F8** to open the Cheats menu, then tick **Infinite Endurance** under **Cheats**.

This is a cheat, so it only works in single-player or when you're the host.

## Config

You can change the hotkey by editing `InfiniteEndurance.as`:

1. Open the file and locate `MenuKey`:
```
const FKey MenuKey = EKeys::F8;
```
2. Change the value to any other key, e.g. to set the G hotkey -> `EKeys::G`

## Installation Instructions

1. Download and extract the archive
2. Navigate to your game folder and check if a "Mods" folder exists, if not create one at:
   `C:\Program Files (x86)\Steam\steamapps\common\Witchspire\Hercules\Script\Mods`
3. Copy/paste `InfiniteEndurance.as` into the "Mods" folder
4. Fully restart the game
