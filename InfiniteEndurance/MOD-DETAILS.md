# InfiniteEndurance

> Tick a box in the Cheats menu and your endurance never runs out — both on-foot stamina and broom boost power.

**Type:** Cheat · **Scope:** Host-authoritative (single-player / listen-server host) · **Hotkey:** `F8` opens the shared ImGui Cheats menu (default `MenuKey = EKeys::F8`, configurable / disableable); the cheat itself is a checkbox, not a gameplay key.

A toggleable cheat that, while enabled, tops up both endurance bars to their maximum every frame: on-foot **Stamina** (`UActionAttributeSet`) and the broom's **boost Power** (`UBroomAttributeSet`). Abilities still pay their cost / drain as normal — the bars just refill instantly behind them, and writing the base value directly bypasses the regen delay, the Exhaustion block, and the broom's post-boost power-regen suppression.

## Features
- Infinite on-foot stamina — sprint and dodge endlessly, and never pick up the **Exhaustion** debuff.
- Infinite broom boost power — hold the broom's boost/sprint forever without the power bar draining out and dropping you back to a glide.
- Single checkbox in the ImGui **Cheats → Infinite Endurance** menu, with a live readout of both bars (`Stamina: x / y`, `Broom boost: x / y`).
- Auto-enables Developer Mode so the menu is reachable, and binds its own opener key (`F8`) so it works stand-alone.
- Toggle resets to OFF on each launch (configurable via `bStartEnabled`).

## Requirements
- Witchspire with the Hercules AngelScript mod framework.
- Host / single-player — the stamina/power attributes are server-authoritative, so the refill only takes effect when you're the host.
- Developer Mode for the ImGui panel (auto-enabled by the mod; `bAutoEnableDeveloperMode = true`).

## Installation
1. Copy `Mods/InfiniteEndurance.as` into your game's `...\Witchspire\Hercules\Script\Mods\` folder — or run `scripts/deploy.ps1` (or the repo's `deploy-all.bat`).
2. Fully restart Witchspire so AngelScript recompiles the mods.

## Controls
| Key / Control | Action |
| ------------- | ------ |
| `F8` | Open / close the shared ImGui Cheats menu (or use any other mod's opener, e.g. Vanity Wardrobe's `F7` — it's the same menu). |
| Checkbox: **Cheats → Infinite Endurance** | Toggle the cheat on / off. |

The opener key is configurable in the `InfiniteEnduranceConfig` namespace (`MenuKey`), and can be disabled entirely with `bBindOwnMenuKey = false` to rely only on another mod's opener.

## Compatibility
- Client-side; safe in single-player and as the listen-server host. On a multiplayer client where you aren't the host, the toggle does nothing (server-authoritative attributes).
- Coexists with the other Witchspire mods (unique `InfiniteEndurance` type prefixes; the opener uses a non-consuming `BindKey`).
- The opener defaults to `F8`, which is also GodForge's hotkey. If both are installed, only one should bind `F8` — set `bBindOwnMenuKey = false` here (or change `MenuKey`) and open the shared menu via another mod's opener (e.g. `F7`).

## Notes & limitations
- Server-authoritative: the per-frame refill is gated behind `System::IsServer()`, so it only works when you host.
- It tops up by polling in the world subsystem's `Tick` — each frame, if a bar is below max it calls `UHercAbilityComponent::SetAttributeBaseValue` to set it back to max (the same attribute call the game uses internally).
- The on/off flag lives on a `UScriptGameInstanceSubsystem` singleton (`UInfiniteEnduranceStore::Get()`), shared between the ImGui checkbox and the world subsystem.
- No game files are modified and nothing is written to your save; the toggle resets to OFF on a full quit/relaunch.

## Changelog
### Unreleased
- Initial documented release.
