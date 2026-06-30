# Witchspire — Celestial Boost

Raises the spawn odds of the rare wild-familiar variants — **Celestial** (the
sparkling one), **Shifty** (recolour), and **Legendary** (3-star rarity) — and
gives you a **live cheat-menu panel** to dial each one in without restarting.

In vanilla, every wild familiar that spawns gets a single roll: **0.5%** to be
Celestial, **10%** to be Shifty, and a per-level rarity roll for its stars. This
mod multiplies those odds by amounts you choose, so the variants you're hunting
actually show up — without removing the thrill.

## Cheat menu

Press **F8** in normal gameplay to open the debug menu, then go to
**Cheats → Celestial Boost**. (The mod auto-enables Developer Mode; the toggle
key is `ToggleMenuKey` in the config.)

| Control | What it does |
| --- | --- |
| **Celestial multiplier** | ×vanilla Celestial rate. `10` ≈ 5%, `20` ≈ 10%, `50` ≈ 25%. |
| **Always Celestial** | Every wild familiar Celestial (drives `Herc.Familiars.AlwaysCelestial`). |
| **Shifty multiplier** | ×vanilla Shifty rate (`1.0` = untouched). |
| **Always Shifty** | Every wild familiar Shifty (drives `Herc.Familiars.AlwaysShifty`). |
| **Always Legendary** | Every wild familiar becomes 3-star. |
| **Extra Legendary chance (0–1)** | Flat chance to bump a sub-legendary wild familiar to 3-star. |
| **Verbose log** | Logs each upgrade to `Hercules.log`. |
| **Reset to defaults** | Back to 10× / 1× / off. |

Everything is also exposed as console variables (`Herc.CelestialBoost.*`), so you
can set them from the console too. Changes apply to **newly-spawned** wild
familiars (each one is boosted exactly once).

## What it does under the hood

A `UScriptWorldSubsystem` sweeps the world every couple of seconds, finds
**capturable, wild, living** familiars it hasn't seen yet (`ItemTag` valid, no
owner, alive), and gives each one a single top-up roll:

- **Celestial / Shifty** — the effective rate becomes `vanilla × multiplier`,
  computed from the familiar's *actual* chance so "10×" is honest
  (`q = base·(mult−1)/(1−base)`, rolled once per familiar so it can't compound).
  Upgrading calls the game's own `UFamiliarComponent::SetVisualVariant()`, which
  applies the sparkle visuals, the Celestial health bonus, and the
  SaveGame-persisted variant flag. A Shifty that gets upgraded becomes
  **ShiftyCelestial**, so its colour is kept — and Celestial/Shifty/rarity stay
  independent, so the elusive Shifty + Celestial + Legendary combo is possible.
- **Legendary** — sets `FamiliarComp.Rarity = Legendary`. The nameplate reads
  `Rarity` live, so the stars update immediately, and capture flows through
  `CreateItemStack() → RarityFrag.SetRarity(Rarity)`, so the **bonded** familiar
  is genuinely Legendary with proper legendary substats (re-rolled from the
  legendary pool on capture).

The boosting is server-authoritative, so it runs only on the host
(`System::IsServer()`) — single-player or listen-server.

> A familiar that's already on-screen when a sweep upgrades it will briefly
> "pop" into its new look; lower `ScanInterval` to shrink that window.

## Install

1. Copy `Mods/CelestialBoost.as` into
   `…\Witchspire\Hercules\Script\Mods\` (or run `./scripts/deploy.ps1` after
   editing the path inside it to match your install).
2. **Fully restart the game** (quit to desktop + relaunch) so AngelScript
   recompiles the mods. There is no hot reload — but once it's running, the cheat
   menu lets you retune everything live without further restarts.

## License

MIT — see [LICENSE](LICENSE).
