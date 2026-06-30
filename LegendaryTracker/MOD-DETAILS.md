# Legendary Tracker

## Description

Helps you spot the rare wild familiars before you walk past them. While you're carrying the detector trinket, the mod points out nearby Legendary (3-star) familiars with a glowing orb, a floating label, and a beam pointing toward the closest one.

You get the detector trinket (Vesper's Locket of Lost Things) automatically the first time you play. Drop it on a hotbar slot and select it to switch tracking on; select anything else to turn it off.

Press **K** to grab a fresh detector if you ever lose it. If you're already carrying one, K instead flips the beam between a permanent always-on beam and the quick "ping" that fires when you select the trinket.

## Config

You can change the hotkey by editing `LegendaryTracker.as`:

1. Open the file and locate `GrantDetectorKey`:
```
const FKey GrantDetectorKey = EKeys::K;
```
2. Change the value to any other key, e.g. to set the G hotkey -> `EKeys::G`

## Installation Instructions

1. Download and extract the archive
2. Navigate to your game folder and check if a "Mods" folder exists, if not create one at:
   `C:\Program Files (x86)\Steam\steamapps\common\Witchspire\Hercules\Script\Mods`
3. Copy/paste `LegendaryTracker.as` into the "Mods" folder
4. Fully restart the game
