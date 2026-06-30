# Linger Chance Indicator

## Description

Ever wondered what your actual odds are of catching that wild familiar? This mod floats a little "Capture X%" label right above whatever wild familiar you're looking at, showing your real chance to catch it (gear bonuses included).

Want the full math behind the number? Press **L** to cycle the display: each press steps through compact "Capture X%" → the full breakdown showing exactly how the odds are calculated → label off → back to compact.

## Config

You can change the hotkey by editing `LingerChanceIndicator.as`:

1. Open the file and locate `ToggleDetailsKey`:
```
const FKey ToggleDetailsKey = EKeys::L;
```
2. Change the value to any other key, e.g. to set the K hotkey -> `EKeys::K`

## Installation Instructions

1. Download and extract the archive
2. Navigate to your game folder and check if a "Mods" folder exists, if not create one at:
   `C:\Program Files (x86)\Steam\steamapps\common\Witchspire\Hercules\Script\Mods`
3. Copy/paste `LingerChanceIndicator.as` into the "Mods" folder
4. Fully restart the game
