# LegendaryTracker

> Find rare wild familiars: surfaces nearby Legendary (3-star) familiars with an orb, a label, and a directional beam while you carry the detector trinket.

**Type:** QoL · **Scope:** Client-side (visual readouts; the orb/label/beam are pure local. Inventory upkeep — granting, single-locket trim, vanishing drops — is server-authoritative, host / single-player only) · **Hotkey:** **K** — context-sensitive: grants the detector locket if you don't carry one, otherwise toggles the permanent beam (`LegendaryTrackerConfig::GrantDetectorKey = EKeys::K`)

LegendaryTracker reads each wild familiar's replicated `UFamiliarComponent::Rarity` (Common=0, Rare=1★, Epic=2★, Legendary=3★) directly on the local client and floats markers over any familiar at or above the configured star threshold (3★ by default). A true custom item can't be created from script, so the mod **borrows an existing item** — "Vesper's Locket of Lost Things" (`Items.Unique_StarlingsLocket`), an orphaned, never-obtainable trinket — as its detector: you're granted it once, and selecting it on the hotbar switches tracking on.

## Features
- Detects nearby wild **Legendary (3-star)** familiars within a configurable radius (default 150 m) by reading their replicated rarity; the star threshold is tunable down to Rare/Epic via `MinStars`.
- Also tracks the **Celestial** and **Shifty** visual variants (any rarity), each with its own label colour and orb mesh (toggle with `bTrackCelestial` / `bTrackShifty`).
- **Glowing orb** above each target — a borrowed item static mesh (default the Asterine Gem) that spins and bobs; per-variant items give per-variant colours. Off by default (`bShowOrb`).
- **Camera-facing gold label** (e.g. `*** Traxio  22m`) via a `UTextRenderComponent` with a drop-shadow (Shipping-safe, no UMG asset). Off by default (`bShowText`).
- **Directional trail beam** (borrows a crafting station's blue connection VFX): by default a single "ping" from you to the nearest target the moment you select the locket; `bBeamOnSelectOnly = false` makes it continuous, and pressing K while holding the locket toggles a permanent reversed beam.
- **Detector upkeep** (host-side): granted once on first play (gated on `IsItemKnown`, waits for a free slot if the bag is full), keeps at most **one** locket, and **vanishes** any dropped copy so it never litters the floor.

## Requirements
- Witchspire with the Hercules AngelScript mod framework.
- The detector trinket — **Vesper's Locket of Lost Things** — placed on a hotbar slot and **selected**. It's granted automatically the first time; press **K** to re-grant if you lose it.

## Installation
1. Copy `Mods/LegendaryTracker.as` into your game's `...\Witchspire\Hercules\Script\Mods\` folder — or run `scripts/deploy.ps1` (or the repo's `deploy-all.bat`).
2. Fully restart Witchspire so AngelScript recompiles the mods.

## Controls
| Key / Control | Action |
|---|---|
| Select locket on hotbar | Switch tracking **ON** (markers/beam appear) |
| Select any other item | Switch tracking **OFF** |
| **K** (no locket carried) | Grant the detector locket |
| **K** (locket carried) | Toggle the permanent beam (permanent ↔ ping-on-select) |
| Drop the locket | It vanishes; press K to get a fresh one |

## Compatibility
- Client-side visuals; safe in single-player and multiplayer (markers render on every client).
- Coexists with the other Witchspire mods (unique `Legendary*` type prefixes, non-consuming hotkey).
- Adds no new item — it borrows the orphaned "Vesper's Locket of Lost Things", which nothing in the shipped game references, so it collides with no quest, vendor, or loot table.

## Notes & limitations
- Inventory-authoritative actions (granting, single-locket trim, vanishing dropped lockets) only run on the **host / single-player**; on a client you can still see all markers but won't be auto-granted the locket.
- Detection is poll-based: the world is rescanned every `ScanInterval` (0.5 s) within `DetectRadius` (15000 UU ≈ 150 m); markers reposition every frame. Only **wild, unowned, alive** familiars are tracked.
- The trail beam is sourced from a crafting station's connection VFX, which only resolves once a workstation has loaded (near base). Until then there's no beam, though once cached it works anywhere; the orb and label use always-loaded item meshes, so they work everywhere.
- The orb and label are **off by default** (trail-only mode) — enable them with `bShowOrb` / `bShowText` in the `LegendaryTrackerConfig` namespace.
- Stars indicate rarity only; the mod is read-only on gameplay state and never modifies familiars or saves.

## Changelog
### Unreleased
- Initial documented release.
