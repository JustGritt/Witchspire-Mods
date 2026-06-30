# PhotoMode

> A one-stop screenshot panel: freeze the scene, set the light, dress the frame, then grab the shot.

**Type:** QoL · **Scope:** Mixed — freeze / time-of-day / player pose are host-authoritative; HUD / sky / filter / blur are local · **Hotkey:** Opens via the shared cheat menu (Cheats → Photo Mode); optional self-bind menu key F8 (`bBindOwnMenuKey`)

PhotoMode adds a single **Cheats → Photo Mode** panel that pulls together everything you'd otherwise juggle by hand for a screenshot. It drives the game's own systems — per-actor time dilation, the day-sequence world clock, post-process color grading and depth of field, the player's pose sequences, and the HUD/crosshair/nameplate CVars — so it can freeze creatures while you keep framing, move the sun, tint the screen, blur the background, pose your character, and hide the interface.

## Features
- **Freeze familiars & monsters** in place (per-actor `CustomTimeDilation = 0` to freeze the pose plus `MoverComp.Deactivate()` to freeze movement) while the player and free camera keep moving normally; re-scans periodically so late-spawning enemies freeze too.
- **Time scale** slider for whole-world slow-mo, or `0` for a full freeze (yourself included).
- **Time of day**: an Hour slider plus presets (**Dawn / Noon / Golden hour / Sunset / Night**, read from the game's day/night thresholds), with an optional **Hold** that re-pins the sky every frame.
- **Clear the sky** by hiding the cloud volumes (re-hides any that stream in).
- **Color filter** with saturation (down to full grayscale), contrast and a warm/cool temperature tint, plus one-tap presets (**None / Vivid / B&W / Noir / Sepia / Warm / Cool**).
- **Background blur** (cinematic depth of field): a Strength slider and **Auto focus** that line-traces onto whatever's at screen center (or a manual focus distance).
- **Player pose**: drop into one of the game's own stances (**Idle**, **Combat: Wand / Sword / Unarmed**, **Broom mount**) shown with your real equipped weapon, plus an experimental **Freeze player pose** that hard-locks your current frame mid-action.
- **Hide HUD** — turns the whole interface off, including the aiming crosshair (`Herc.UI.HideCursor`) and the familiar/monster nameplates (`Herc.UI.HideNameplates`).
- **Fly-while-frozen camera**: when Time scale hits 0, the active free camera flies on real (undilated) time so you can still reposition the shot.

## Requirements
- Witchspire with the Hercules AngelScript mod framework.
- The shared ImGui debug menu / Developer Mode (the driver auto-enables Developer Mode).
- Host / single-player for the freeze, time-of-day, and pose features (those are server-authoritative); the visual toggles work anywhere.

## Installation
1. Copy `Mods/PhotoMode.as` into your game's `...\Witchspire\Hercules\Script\Mods\` folder — or run `scripts/deploy.ps1` (or the repo's `deploy-all.bat`).
2. Fully restart Witchspire so AngelScript recompiles the mods.

## Controls

### Panel toggles

| Control | What it does |
| --- | --- |
| **Freeze familiars & monsters** | Holds every AI creature still (pose + movement) while you keep moving. Uncheck to resume. (host only) |
| **Time scale** | Whole-world slow-mo / speed-up (1.0 = normal). Drag to 0 to freeze everything, yourself included. |
| **Camera speed** | Base fly speed shown while the world is frozen. |
| **Pose** | Pick a stance: None / Idle / Combat: Wand / Sword / Unarmed / Broom mount. Stand still to hold it. (host only) |
| **Freeze player pose (experimental)** | Hard-locks your current frame — trigger an attack/cast, then tick to hold it. (host only) |
| **Hour** | Scrub the time of day; sticks while the world is frozen. (host only) |
| **Dawn / Noon / Golden hour / Sunset / Night** | Jump to a preset time. (host only) |
| **Hold time of day** | Re-pins the sky every frame so it never drifts. (host only) |
| **Hide clouds** | Hides the cloud volumes for a clear sky. |
| **Filter presets** | None / Vivid / B&W / Noir / Sepia / Warm / Cool — sets the sliders below. |
| **Saturation / Contrast / Temperature** | Color grade: 0 saturation = grayscale; contrast 1 = normal; temperature warm ↔ cool. |
| **Enable blur (depth of field)** | Turns background blur on; off leaves the game's own DoF untouched. |
| **Strength** | How shallow the focus is (higher = more background blur). |
| **Auto focus / Focus distance (cm)** | Auto focuses on screen center; turn off to set the distance by hand. |
| **Hide HUD** | Turns the HUD off, plus the aiming crosshair and the familiar/monster nameplates. |
| **Reset everything** | Unfreeze, show HUD, show clouds, release the time hold, clear the filter and blur, drop the pose. |

### Fly-while-frozen keys

Active only when **Time scale → 0** has frozen the world and a free camera is active. Keys are bound non-consuming, so they never affect normal movement.

| Key | Action |
| --- | --- |
| **W / A / S / D** | Move (follows where you're looking) |
| **E / Q** | Up / down |
| **Shift** (hold) | Boost (×5) |
| **Ctrl** (hold) | Slow (×0.2) |

## Compatibility
- Client-side; the visual toggles (HUD, clouds, filter, blur) are safe in single-player and multiplayer; host-authoritative features (freeze, time of day, pose) apply on the host.
- Coexists with the other Witchspire mods (unique `PhotoMode` type prefixes, non-consuming hotkeys). By default PhotoMode does not bind its own menu key, so it won't collide; if you set `bBindOwnMenuKey = true` it uses F8, which would clash with InfiniteEndurance / GodForge — don't enable both on F8.

## Notes & limitations
- Freeze, time-of-day and player-pose changes are server-authoritative: they only take effect on the host (single-player or listen-server) and replicate to clients; on a client these controls are shown disabled. The HUD, cloud, filter and blur toggles are local/visual and work anywhere.
- **Freeze familiars & monsters** vs **Time scale → 0** are independent: the former holds creatures still while you keep moving and framing; the latter stops the whole world (including you), which is when the fly-while-frozen assist kicks in.
- Hide HUD also hides the aiming crosshair and the floating familiar/monster nameplates (name, level, stars, health bar) — both are separate widgets outside `AHercHUD`, cleared via the same CVars the game's corruption sequence uses.
- "Weather" here means **time of day + clear-sky cloud toggle only** — Witchspire exposes no rain/storm/fog state machine to scripts (the sky is a UE5 Day Sequence + Sky System).
- **Freeze player pose** is experimental: it sets the player's own `CustomTimeDilation = 0` to lock the current frame.
- The driver enforces the toggles every frame (so they hold with the panel closed) and stores shared state on `UPhotoModeStore`; all settings reset to off on each launch.

## Changelog
### Unreleased
- Hide HUD now also hides the aiming crosshair and familiar/monster nameplates.
- Added background blur (depth of field) and a player-pose picker (incl. experimental freeze-player-pose).
