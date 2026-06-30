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
- **Hide the HUD** — toggle the whole interface off (and back on).

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
| **Hide HUD** | Turns the whole HUD off. |
| **Reset everything** | Unfreeze, show HUD, show clouds, release the time hold, clear the filter. |

The HUD and cloud toggles are **local** (visual only). Freeze and time of day are
**server-authoritative**, so they apply on the host — single-player or
listen-server.

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
- **HUD** — `AHercHUD::SetVisibility()`.

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
