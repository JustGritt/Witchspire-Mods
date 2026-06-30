# Witchspire — Familiar Compendium

A client-side, read-only **"pokedex"** for Witchspire. Press a key to open a
floating panel that lists **every familiar species in the game, grouped by
element**, showing which you've captured and how many remain.

The game gives you no overview of your collection or what's left to bond — this
fills that gap without touching any save data or game logic.

![concept](docs/concept.png)

## What it shows

```
FAMILIAR COMPENDIUM     Captured 7 / 24

Fire   2/5
  [x] Fire Rat
  [x] Cinder Moth
  [ ] ???
  [ ] ???
  [ ] ???

Water  3/6
  [x] Tide Sprite
  ...

[Up/Down] Scroll    [P] Close        rows 1-16 / 38
```

- **Caught** species show their real name with `[x]`.
- **Uncaught** species show as `[ ] ???` — so you can see exactly how many are
  left to find in each element, without spoiling what they are.
- Each element header shows a `caught/total` count.

## Controls

| Key | Action |
| --- | --- |
| `P` | Open / close the compendium |
| `↑` / `↓` | Scroll the list |

All hotkeys are configurable at the top of `Mods/FamiliarCompendium.as`
(`FamiliarDexConfig`). While the compendium is open the player is frozen
(movement + camera), the game HUD is hidden, and the world behind the panel is
**blurred and dimmed** so it reads like a real modal menu — toggle these with
`bFreezePlayerWhileOpen` / `bHideHudWhileOpen` / `bBlurBackgroundWhileOpen` /
`bDimBackgroundWhileOpen`.

## How it works

Everything is read from existing game systems — nothing is modified or saved by
the mod:

- **Roster** — walks the `Items` gameplay-tag tree and keeps every
  `UItemDefinition` that carries a `UItemFragment_Familiar`, then filters down to
  the base **catchable** species. The game has no "is this catchable" flag, and its
  data also contains elemental recolor variants, named bosses, and cut/broken
  content (e.g. `FamiliarTylocq`, `FamiliarOcton`), which would otherwise inflate
  the count. The filter (configurable in `FamiliarDexConfig`) drops tags that
  extend a base species' tag (variants), tags matching boss/variant keywords
  (`Named`, `Variant`, `Matriarch`, …), and an explicit cut-content list, then
  merges entries that share a display name. Turn on `bVerboseLog` to see exactly
  what each rule **kept** vs **dropped** in `Hercules.log`, then tune the lists.
- **Captured** — `UPlayerStatisticsComponent::IsItemKnown(tag)`. The game already
  records (and **saves**) every item you've ever held, and a bonded familiar is
  added to your inventory — so your dex persists across releasing a familiar and
  quitting to desktop, with zero custom save code.
- **Element** — `UItemRuntimeFragment_FamiliarActions.ProgressionElementalType`.

The panel is drawn with `UTextRenderComponent` (world-space 3D text) anchored in
front of the camera — the same Shipping-build-safe approach as
[Linger Chance Indicator](../Witchspire-LingerChanceIndicator); no UMG or
Blueprint asset is required, so the mod is a single `.as` file.

## Install

1. Copy `Mods/FamiliarCompendium.as` into
   `…\Witchspire\Hercules\Script\Mods\` (or run `./scripts/deploy.ps1` after
   editing the path inside it to match your install).
2. **Fully restart the game** (quit to desktop + relaunch) so AngelScript
   recompiles the mods. There is no hot reload.

## Tuning

The panel is sized as **fractions of the viewport**, so it looks the same on
16:9, 21:9, ultrawide and any resolution (it measures the on-screen world span
each frame via `DeprojectScreenPositionToWorld`). Tweak the layout in
`FamiliarDexConfig`: `TextFracH` (text height), `LineFracH` (row spacing),
`LeftFracX` (left edge, fraction from screen left), `TopFracY` (title, fraction
from top), and `MaxVisibleRows`. On first open the mod logs the full roster it
found to `Hercules.log` (`%LOCALAPPDATA%\Hercules\Saved\Logs\Hercules.log`); set
`bVerboseLog = false` once you've confirmed it.

**Background effect.** The blur is an asset-free depth-of-field post-process
(`UPostProcessComponent`) focused at the panel depth, so the panel text stays
sharp while the world behind it goes soft — tune `BlurFstop` (lower = stronger
blur) and `BlurFocalDistance` (keep it equal to `PanelDistance`). The dim is a
held manual camera fade; tune `DimAmount` (0–1) and `DimColor`. Disable either
with `bBlurBackgroundWhileOpen` / `bDimBackgroundWhileOpen`.

## License

MIT — see [LICENSE](LICENSE).
