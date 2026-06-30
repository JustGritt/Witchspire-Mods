# Witchspire — Legendary Tracker

A QoL mod for **Witchspire** that helps you find rare wild familiars: it detects
nearby **Legendary (3-star)** familiars and surfaces them so you never walk past
the good ones.

> **Stars = rarity.** The game shows `int(Rarity)` stars per familiar:
> Common = 0, Rare = ★, Epic = ★★, **Legendary = ★★★**. The tracker watches for
> 3-star (Legendary) wild familiars by default (configurable down to Rare/Epic).

## How it works

Each wild familiar's rarity lives on `UFamiliarComponent::Rarity`, which is a
**replicated** property — so the local client can read it directly. The mod is
**read-only**: a `UScriptWorldSubsystem` ticks on the local player, periodically
scans nearby wild familiars (`GetAllActorsOfClass`), and reports any at or above
the configured star threshold. Nothing about the game state is modified, so it's
safe to run on host or client, single- or multiplayer.

## The detector trinket

A true custom item isn't possible from script (items are cooked, C++-backed
assets), so the tracker **borrows an existing item** as its detector:
**Vesper's Locket of Lost Things** (`Items.Unique_StarlingsLocket`) — a
non-equipment trinket, so it just sits in your bag as a clean key item. It's an
ideal pick because it's **orphaned content**: a fully-authored item that the
shipped game never makes obtainable (see [Where the locket came
from](#where-the-locket-came-from)), so repurposing it collides with nothing.

- You're given the locket **once**, the first time only — gated on whether
  you've *ever* owned it. (If your bag is full at that moment the gift waits
  until a slot frees up, rather than being lost.)
- Put the locket on a hotbar slot and **select it** to switch tracking **on**;
  select anything else to switch it **off**.
- You can only ever hold **one** locket — extras you pick up are trimmed away,
  and the copy you currently have selected is always the one kept.
- **Drop it and it vanishes** — no clutter on the floor, no duplicate to grab.
- Lost it and want it back? Press the **grant hotkey** (default **K**). A full
  bag blocks the re-grant cleanly (the locket is never spilled on the ground).

Granting and the single-locket / vanish upkeep are inventory-authoritative
(host / single-player only); the markers render on every client.

## Where the locket came from

Digging through the cooked content (`Hercules-Windows.ucas`), the locket lives
at `/Game/Gameplay/Items/ID_Unique_StarlingsLocket` with an amulet icon
(`T_icon_amulet4`) and this flavor text:

> *"A small amulet that appears larger on the inside. Made up of small screws,
> trinkets, and one unidentified object that hums encouragingly."*

It's one of a family of five **named-character keepsakes** that all share the
same fate:

| Item | Display name |
|---|---|
| `ID_Unique_StarlingsLocket` | Vesper's Locket of Lost Things |
| `ID_Unique_CartimeusPendant` | Cartimeus' Pendant |
| `ID_Unique_ElliesBookOfHome` | Ellie's Book of Home |
| `ID_Unique_FlettysBrush` | Fletty's Brush |
| `ID_Unique_TulasBook` | Tula's Book (*"The magick of a Foreteller is imbued within…"*) |

**None of them is obtainable in the shipped game.** Each item path appears
exactly **twice** in the entire 6&nbsp;GB content container — both times inside
its own definition asset — i.e. nothing references them: no shop recipe, vendor,
loot table, or quest. For contrast, a keepsake that *is* wired up — Mirella's
amulet (there's a `RD_Shop_ReturnMirellasAmulet` "return the lost keepsake"
recipe) — shows up **22** times.

So these five were almost certainly meant for a **"return a lost keepsake"
questline** (the same pattern Mirella's amulet uses) that was cut or never
finished — which fits the locket's *"Lost Things"* name perfectly. That it's
real, fully-authored, yet inert is exactly why it's the safe item to borrow as
the detector.

## What you see

Over each nearby wild **Legendary** familiar, the tracker floats:

- a **glowing orb** — a real item's static mesh (default the Asterine Gem) that
  spins and bobs. It's sourced from an item definition, which is always loaded,
  so it works anywhere you roam (the crafting-beam VFX only exists near base, so
  an item mesh is the reliable choice). Same trick as the Reforge Altar.
- a gold, camera-facing **label** (`*** Traxio  22m`) that tracks it as you move,
  via a `UTextRenderComponent` with a drop-shadow (Shipping-safe, no UMG asset).

Toggle either with `bShowOrb` / `bShowText`, and swap the orb to any item's mesh
via `OrbItemTag` (e.g. `Items.FireGem`, `Items.ExperienceOrb`).

## Config

Edit the `LegendaryTrackerConfig` namespace at the top of
[`Mods/LegendaryTracker.as`](Mods/LegendaryTracker.as):

| Setting | Default | Meaning |
|---|---|---|
| `DetectorItemTag` | `Items.Unique_StarlingsLocket` | The borrowed detector item. |
| `bAutoGrantOnce` | `true` | Gift the detector the first time only. |
| `bEnableGrantHotkey` / `GrantDetectorKey` | `true` / `K` | Hotkey to re-grant the detector. |
| `MinStars` | `3` | Minimum star rating to mark (1 = Rare+, 2 = Epic+, 3 = Legendary). |
| `DetectRadius` | `15000` | Detection radius in Unreal units (100 = 1 m → 150 m). |
| `ScanInterval` | `0.5` | Seconds between world rescans (visuals reposition every frame). |
| `bShowOrb` / `OrbItemTag` | `true` / `Items.AsterineGem` | Floating orb, and the item whose mesh it borrows. |
| `OrbTargetSize` / `OrbVerticalOffset` | `45` / `60` | Orb size (cm) and height above the familiar's head. |
| `OrbSpinDegPerSec` / `OrbBobAmplitude` / `OrbBobSpeed` | `90` / `14` / `2.2` | Orb spin + bob animation. |
| `bShowText` / `MarkerColor` | `true` / gold | Floating label and its colour. |
| `bVerboseLog` | `true` | Log activation / grants / orb-mesh resolution to `Hercules.log`. |

## Install

1. Run `./scripts/deploy.ps1` (copies `Mods/LegendaryTracker.as` into
   `…\Witchspire\Hercules\Script\Mods\`), or copy the file there manually.
2. **Fully restart the game** — AngelScript mods only compile at launch.

## License

[MIT](LICENSE)
