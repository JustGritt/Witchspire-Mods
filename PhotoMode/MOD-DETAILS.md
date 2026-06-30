# Photo Mode

## Description

A one-stop panel for setting up and taking screenshots. Pose the scene, fix the lighting, dress up the frame, then grab your shot.

The panel can:

- **Freeze familiars & monsters** in place while you keep moving around to frame the shot
- **Change or hold the time of day** (Dawn / Noon / Golden hour / Sunset / Night), or scrub the hour by hand
- **Clear the sky** by hiding the clouds
- **Apply color filters** (Vivid / B&W / Noir / Sepia / Warm / Cool, plus saturation, contrast and warm/cool sliders)
- **Blur the background** with adjustable depth of field
- **Pose the player** into one of the game's idle, combat or broom-mount stances
- **Hide the HUD**, including the aiming crosshair and the familiar/monster nameplates

Photo Mode lives in the in-game debug/cheats menu under **Cheats → Photo Mode**. Open that menu with the shared cheat-menu key (**F7**) if you're running another cheat mod that already binds it, then pick Photo Mode. If you'd rather Photo Mode open the menu itself, you can turn on its own key in the config (see below).

## Config

You can let Photo Mode open the menu with its own key by editing `PhotoMode.as`:

1. Open the file and find these lines near the top:
```
const bool bBindOwnMenuKey = false;
const FKey MenuKey = EKeys::F8;
```
2. Set `bBindOwnMenuKey` to `true` so Photo Mode opens the menu with `MenuKey` (default `F8`).
3. You can change `MenuKey` to any other key, e.g. `EKeys::G`. Leave `bBindOwnMenuKey` at `false` if another cheat mod already binds that key, or the two will cancel each other out.

## Installation Instructions

1. Download and extract the archive
2. Navigate to your game folder and check if a "Mods" folder exists, if not create one at:
   `C:\Program Files (x86)\Steam\steamapps\common\Witchspire\Hercules\Script\Mods`
3. Copy/paste `PhotoMode.as` into the "Mods" folder
4. Fully restart the game
