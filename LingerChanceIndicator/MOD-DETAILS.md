# LingerChanceIndicator

> Floats a "Capture X.X%" label over the wild familiar you're looking at, showing your true odds of capturing it.

**Type:** QoL · **Scope:** Client-side (read-only) · **Hotkey:** L (toggle the breakdown)

When you look at a wild, capturable familiar, a subtle world-space label appears above it reading `Capture X.X%`. That number is the true capture chance — the product of the two gates the game rolls (`linger × bond`), where linger is `(base × difficulty + pity) × your gear` and bond defaults to ~100%. The label is rendered with a `UTextRenderComponent` so it works in the game's Shipping build without any UMG asset.

## Features
- Headline `Capture X.X%` readout above the targeted familiar, shown to one decimal so small gear bonuses stay visible.
- Press `L` to expand the full equation behind the number, e.g. `Capture 7.9%  =  2.0% x 3.00 x 1.31` (base lingering chance × difficulty multiplier × your gear/bond multiplier); press again to hide it.
- Pity (`SuccessiveFailBonus`) is folded in and parenthesized since it adds before the gear step, e.g. `(2.0% x 3.00 + 2.4% pity) x 1.31`; the second bond gate is only surfaced when it actually drops below ~100%.
- Default factors (`×1.00`, `+0%`) are dropped from the equation to keep it tidy; the gear factor is shown as a multiplier so it's never mistaken for percentage-points.
- Rarity-tinted color (red → gold → green) by capture odds, with a black drop shadow so it stays legible on any background.
- Distance-scaled sizing keeps the label a roughly constant on-screen size; placement and scaling are tunable in `LingerChanceConfig`.
- Performance-throttled: odds/look-at target recompute at 20 Hz while positioning tracks every frame, and the expensive glyph rebuild (`SetText`) only fires when the text, size, or color actually changes.

## Requirements
- Witchspire with the Hercules AngelScript mod framework.

## Installation
1. Copy `Mods/LingerChanceIndicator.as` into your game's `...\Witchspire\Hercules\Script\Mods\` folder — or run `scripts/deploy.ps1` (or the repo's `deploy-all.bat`).
2. Fully restart Witchspire so AngelScript recompiles the mods.

## Controls

| Key | Action |
|---|---|
| `L` | Toggle the full capture-chance breakdown (equation) on/off — non-consuming, configurable as `ToggleDetailsKey` in `LingerChanceConfig` |

## Compatibility
- Client-side, read-only; safe in single-player and multiplayer.
- Coexists with the other Witchspire mods (unique type prefixes, non-consuming hotkeys).

## Notes & limitations
- Read-only: it only reads attributes and floats a label — it never modifies the server, other players, or your save.
- The label only appears for wild, capturable familiars you look at. Owned familiars and species with no bond `ItemTag` are filtered out (mirroring the engine's own capture gate).
- Uses a world-space `UTextRenderComponent` rather than a true screen-space nameplate, because the Shipping build renders nothing from engine debug draw and a script-only mod can't ship a UMG asset.
- Tunables (vertical offset, distance scaling, min/max text size, recompute rate, start-visible toggle) live in the `LingerChanceConfig` namespace at the top of the `.as` file.

## Changelog
### Unreleased
- Initial documented release.
