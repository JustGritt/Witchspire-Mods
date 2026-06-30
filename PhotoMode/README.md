# Witchspire — Photo Mode

A one-stop **Cheats → Photo Mode** panel for taking screenshots. Instead of
juggling the hide-HUD key and free-cam by hand, you get a single panel that can:

- **Freeze familiars & monsters** — holds every AI creature (familiars, monsters,
  NPCs) dead still so they don't drift out of your shot, **while you keep moving
  freely** to frame it. It works per-actor, so the player and the free camera are
  never frozen. (Plain "freeze world" can't do this: UE clamps global time
  dilation to a tiny non-zero floor, so creatures keep creeping — see
  [How it works](#how-it-works).) Plus a separate **Time scale** slider for
  whole-world slow-mo, or a full stop with a **fly-the-camera-while-frozen**
  assist (see below).
- **Set the time of day** — drag the **Hour** or hit a preset
  (**Dawn / Noon / Golden hour / Sunset / Night**) to move the sun, sky and
  lighting. Optionally **Hold** it so the sky stays put.
- **Clear the sky** — hide the cloud volumes for a clean backdrop.
- **Apply a color filter** — camera-app style looks: **saturation** (down to full
  grayscale), **contrast** and a **warm/cool** tint, with one-tap presets
  (**Vivid / B&W / Noir / Sepia / Warm / Cool**). Local & visual, so it works in
  multiplayer too and applies wherever the free camera flies.
- **Blur the background** — depth-of-field that keeps your subject sharp and blurs
  everything off the focal plane. A **Strength** slider sets how shallow the focus
  is, and **Auto focus** locks onto whatever's at the centre of your shot (or set
  the focus distance by hand). Local & visual, like the filter.
- **Pose the player** — drop into one of the game's own stances (**Idle**,
  **Combat: Wand / Sword / Unarmed**, **Broom mount**), shown with whatever weapon
  you're actually holding. Or flip **Freeze player pose** to hard-lock your current
  frame — trigger an attack or a cast in normal play, then freeze it mid-action.
- **Hide the HUD** — toggle the whole interface off (and back on), including the
  aiming crosshair and the floating familiar / monster nameplates (name, level,
  stars and health bar).

> **About "weather":** Witchspire has no rain/storm/weather state machine exposed
> to mods — the sky is a UE5 Day Sequence + Sky System. So the real atmosphere
> lever is **time of day** (golden hour, blue hour, night), plus the **clear-sky**
> cloud toggle. There is no rain/fog control to give.

## How to open it

This adds a panel to the shared **ImGui debug menu** (Developer Mode, which the
mod auto-enables). Open that menu the way you already do — e.g. **F8** if another
mod (like Celestial Boost) binds it, or the game's own debug-menu key — then pick
**Cheats → Photo Mode**.

If you run Photo Mode **on its own** and have no other way to open the menu, set
`bBindOwnMenuKey = true` in the config at the top of `Mods/PhotoMode.as` (it binds
**F8** by default). Leave it `false` if another mod already binds that key, or the
two openers will toggle each other and cancel out.

## Controls

| Control | What it does |
| --- | --- |
| **Freeze familiars & monsters** | Holds every AI creature still — freezes their pose (per-actor time dilation 0) and their movement (deactivates the Mover) — while you keep moving. Uncheck to resume. |
| **Time scale** | Whole-world slow-mo / speed-up (1.0 = normal). Drag to **0** to freeze everything, yourself included. |
| **Hour** | Drag to scrub the time of day. Sticks while the world is frozen. |
| **Dawn / Noon / Golden hour / Sunset / Night** | Jump to a preset time (read from the game's own day/night thresholds). |
| **Hold time of day** | Re-pins the sky every frame so it never drifts (also pauses the world clock — intended for posed shots). |
| **Hide clouds** | Hides the cloud volumes for a clear sky (re-hides any that stream in). |
| **Filter presets** | **None / Vivid / B&W / Noir / Sepia / Warm / Cool** — one tap sets the sliders below. |
| **Saturation** | Color intensity. **0 = grayscale**, 1 = normal, >1 = vivid. |
| **Contrast** | Tonal contrast (1 = normal). |
| **Temperature** | Warm ↔ cool tint (0 = neutral). |
| **Enable blur (depth of field)** | Turns background blur on. Off = the game's own DoF is untouched. |
| **Strength** | How shallow the focus is — higher blurs the off-focus background more (maps to a lower camera f-stop). |
| **Auto focus** | Focuses on whatever's at the centre of the shot. Turn off to set **Focus distance (cm)** by hand. |
| **Pose** | Pick a stance (**None / Idle / Combat: Wand / Sword / Unarmed / Broom mount**). Stand still to hold it. |
| **Freeze player pose** | Hard-locks your current frame (experimental) — trigger an attack/cast, then tick this to hold that exact pose. |
| **Hide HUD** | Turns the whole HUD off, plus the aiming crosshair and the familiar / monster nameplates. |
| **Reset everything** | Unfreeze, show HUD, show clouds, release the time hold, clear the filter and blur, drop the pose. |

The HUD, cloud, filter and blur toggles are **local** (visual only). Freeze, time
of day and the player pose are **server-authoritative**, so they apply on the
host — single-player or listen-server.

## Flying the free camera while frozen

This applies to the **Time scale → 0** whole-world freeze (the
*Freeze familiars & monsters* toggle leaves you and the camera moving normally,
so you don't need it there). The game's free camera moves by `velocity ×
frame-delta`, and a whole-world freeze sets that delta to **0** — so the camera
stops moving. Photo Mode fixes this: while the world is frozen, it flies the
active free camera on **real (undilated) time**, so you can still reposition the
shot. Mouse-look keeps working on its own (the game sets the camera's rotation
directly, with no delta).

| Key | Action |
| --- | --- |
| **W / A / S / D** | Move (follows where you're looking) |
| **E / Q** | Up / down |
| **Shift** (hold) | Boost (×5) |
| **Ctrl** (hold) | Slow (×0.2) |

Set a base **Camera speed** in the panel (shown while frozen). The keys are bound
*non-consuming*, so they never affect your normal movement — they only drive the
camera while the world is frozen and a free camera is active. Workflow: open the
panel → drag **Time scale** to 0 → close the menu → start your free camera → fly.

## How it works

Everything is driven through the game's own systems — the same ones the native
**Settings → World** debug window uses:

- **Freeze familiars & monsters** — two per-actor levers on each AI-driven
  `AHercCharacter`, because the pose and the movement freeze separately:
  - `CustomTimeDilation = 0` freezes the **pose** (the animation advances on the
    actor's dilated tick).
  - `MoverComp.Deactivate()` freezes the **movement**. The game runs on the UE
    **Mover plugin**, which simulates on its own clock and *ignores*
    `CustomTimeDilation` — so dilation alone freezes the animation while the
    creature keeps sliding around. Deactivating the Mover is exactly what the
    game's own `Herc.Cheats.AI.DisableMoverComponents` cheat does.

  A character counts as AI when its controller derives from `AAIController`, so
  the player (an `APlayerController`) is never touched. The driver records exactly
  which characters it froze and restores only those (so it never re-activates a
  Mover the game disabled itself — e.g. a far, significance-culled NPC), and
  re-scans periodically so newly spawned / streamed-in enemies freeze too. (A
  plain "freeze world" is no good here: it also freezes you, and UE clamps the
  **global** time dilation to a tiny non-zero floor so AI never truly stops.)
- **Whole-world slow-mo / freeze** — `Gameplay::SetGlobalTimeDilation()` (the
  Time scale slider), with the fly-cam assist above for the full-stop case.
- **Time of day** — the world clock on `AHercGameState`. Because the GameState
  re-applies the time of day every frame from that clock, the mod moves the clock
  itself (`SetWorldTimeStamp`) so the change actually sticks, then scrubs the
  `ADaySequenceActor` to match. Presets read the real sunrise/sunset hours from
  `UDayNightCicleSettings`.
- **Clouds** — `ACloudVolume::SetActorHiddenInGame()` across every cloud volume.
- **Filter** — an **unbound `UPostProcessComponent`** created on the local player
  (the same pattern the game's heat/corruption effects use), driving
  `FPostProcessSettings` color grading: `ColorSaturation` (0 = grayscale),
  `ColorContrast` and `ColorGain` (warm/cool red–blue tint). *Unbound* so it
  covers the whole screen no matter where the free camera flies, and each grade
  only overrides when its slider is off-neutral, so a neutral filter leaves the
  game's own color grading untouched.
- **Background blur** — the **same unbound `UPostProcessComponent`** as the filter,
  driving `FPostProcessSettings`' cinematic depth of field: `DepthOfFieldFocalDistance`
  (the focal plane), `DepthOfFieldFstop` (Strength maps a wider f-stop → shallower
  focus → more blur) and a wide `DepthOfFieldSensorWidth` so the blur reads on
  screen. **Auto focus** line-traces straight out from the camera and focuses on the
  first thing it hits (falling back to the manual distance over open sky). The DoF
  overrides are switched **off** when blur is disabled, so the game's own DoF returns.
- **Player pose** — the game's own pose sequences, played on the local player as a
  full-body slot animation via `AHercCharacter::PlaySlotAnimation()`. The sequences
  come straight from the player's `UPlayerAnimSet` (`Base.Idle`,
  `Base.CombatIdleWand` / `CombatIdleSword` / `CombatIdleNoWeapon`, `Broom.BroomMount`),
  so a stance shows the real pose for your equipped weapon. A held stance is
  re-asserted only once it has actually blended out (checked with `IsSlotActive`),
  so it never visibly restarts. **Freeze player pose** sets the player's own
  `CustomTimeDilation = 0` — the same per-actor freeze used for AI, but pointed at
  you — which holds whatever frame you're on, including a mid-swing attack or a cast.
- **HUD** — `AHercHUD::SetVisibility()`, plus the two widgets that live outside it:
  the aiming crosshair (`Herc.UI.HideCursor`) and the familiar / monster nameplates
  (`Herc.UI.HideNameplates`, which `UNameplateManagerSubsystem` watches to hide them
  all). These are the same CVars the game's own corruption sequence flips, so the
  widgets come back cleanly when Hide HUD is turned off.

A `UScriptWorldSubsystem` enforces the toggles every frame (so they hold with the
panel closed), and shared state lives on a `UScriptGameInstanceSubsystem`
(`UPhotoModeStore`) so the panel and the driver agree. Settings reset to off each
launch.

## Install

1. Copy `Mods/PhotoMode.as` into
   `…\Witchspire\Hercules\Script\Mods\` (or run `./scripts/deploy.ps1` after
   editing the path inside it to match your install).
2. **Fully restart the game** (quit to desktop + relaunch) so AngelScript
   recompiles the mods. There is no hot reload.

## License

MIT — see [LICENSE](LICENSE).
