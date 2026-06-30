# CelestialBoost

> Raises the spawn odds of rare wild-familiar variants — Celestial, Shifty, and Legendary (3-star) — with a live cheat-menu panel to tune each one without restarting.

**Type:** Cheat · **Scope:** Host-authoritative (single-player / listen-server host) · **Hotkey:** F8 to open the cheat-menu panel

In vanilla, every wild familiar gets a single server-side roll when it spawns (0.5% Celestial, 10% Shifty, plus a per-level rarity roll for its stars). A script can't hook those one-shot rolls, so CelestialBoost runs a `UScriptWorldSubsystem` that sweeps the world every couple of seconds, finds freshly-spawned wild familiars it hasn't seen yet, and gives each one a single honest top-up roll — multiplying the effective odds by amounts you choose and upgrading via the game's own variant/rarity methods.

## Features
- Boosts the **Celestial** odds by a multiplier you set (default 10×; the menu shows the effective ~%).
- Boosts the **Shifty** odds by a multiplier (default 1× = untouched).
- "**Always Celestial**" and "**Always Shifty**" toggles that drive the game's own `Herc.Familiars.*` cheats, so even the engine's spawn roll honors them.
- "**Always Legendary**" makes every wild familiar 3-star, plus a flat "**Extra Legendary chance (0–1)**" to bump sub-legendary wild familiars to 3 stars.
- Variants stay independent — Shifty that's upgraded becomes **ShiftyCelestial** (keeps its colour), so the Shifty + Celestial + Legendary combo is possible.
- Upgrades use the game's `SetVisualVariant()` (sparkle visuals, Celestial health bonus, SaveGame-persisted) and set `Rarity = Legendary` so captured familiars are genuinely Legendary with legendary substats.
- Live, restart-free tuning via the cheat-menu panel; every knob is also exposed as a `Herc.CelestialBoost.*` console variable.
- Optional **Verbose log** that records each upgrade to `Hercules.log`, and a **Reset to defaults** button.

## Requirements
- Witchspire with the Hercules AngelScript mod framework.
- Host / single-player (this mod's boosting is server-authoritative).
- Developer Mode for the panel — the mod's driver auto-enables it on startup (`bAutoEnableDeveloperMode = true`).

## Installation
1. Copy `Mods/CelestialBoost.as` into your game's `...\Witchspire\Hercules\Script\Mods\` folder — or run `scripts/deploy.ps1` (or the repo's `deploy-all.bat` to install every mod).
2. Fully restart Witchspire so AngelScript recompiles the mods.

## Controls
Press **F8** in normal gameplay to open the debug menu, then go to **Cheats → Celestial Boost**.

| Control | Action |
| --- | --- |
| **F8** | Toggle the ImGui debug menu open/closed |
| **Celestial multiplier** | ×vanilla Celestial rate (default 10; `20` ≈ 10%, `50` ≈ 25%) |
| **Always Celestial** | Make every wild familiar Celestial (drives `Herc.Familiars.AlwaysCelestial`) |
| **Shifty multiplier** | ×vanilla Shifty rate (default 1.0 = untouched) |
| **Always Shifty** | Make every wild familiar Shifty (drives `Herc.Familiars.AlwaysShifty`) |
| **Always Legendary** | Make every wild familiar 3-star |
| **Extra Legendary chance (0–1)** | Flat chance to bump a sub-legendary wild familiar to 3-star |
| **Verbose log** | Log each upgrade to `Hercules.log` |
| **Reset to defaults** | Restore 10× / 1× / off |

## Compatibility
- Client-side mod; safe in single-player and as the listen-server host.
- Coexists with the other Witchspire mods — unique `U.../A...` type prefixes and non-consuming hotkeys mean no collisions.
- Reuses the game's own `Herc.Familiars.AlwaysCelestial` / `AlwaysShifty` CVars for its "Always" toggles, so those settings carry through to the engine's spawn roll.

## Notes & limitations
- The boosting is server-authoritative and runs only on the host (`System::IsServer()`) — single-player or listen-server host.
- Changes apply to **newly-spawned** wild familiars only; each is boosted **exactly once** (the subsystem tracks what it has already processed, pruning despawned actors so the list can't grow forever).
- Multipliers are applied from each familiar's *actual* chance (`q = base·(mult−1)/(1−base)`) so the stated multiplier is honest and rolls can't compound.
- The familiar must be **capturable, wild (unowned), and alive** to be eligible.
- A familiar already on-screen when a sweep upgrades it will briefly "pop" into its new look; lowering `ScanInterval` (default 2.0s) shrinks that window.

## Changelog
### Unreleased
- Initial documented release.
