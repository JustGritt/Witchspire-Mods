# FamiliarCompendium

> A client-side, read-only "pokedex" panel that lists every familiar species in the game, grouped by element, and shows which you've captured.

**Type:** QoL · **Scope:** Client-side (read-only) · **Hotkey:** `P` (open / close the compendium)

Press the toggle key to open a floating panel listing every familiar species grouped by element, with a selection cursor you move with the arrow keys. A right-hand detail pane shows the highlighted familiar's element, capture status and which forms you own (rarity stars + shifty / celestial), plus a floating 3D model of it. All data is read from existing game systems — nothing is modified or saved by the mod.

## Features
- Full roster of catchable familiar species, grouped by element, with a per-element `caught/total` count and an overall captured tally.
- Caught species show their name normally; species you've never bonded show greyed out, so you can see how many remain per element.
- Selection cursor (arrow keys) drives a right-hand detail pane: element, capture status, best rarity (stars) and the forms you own (Normal / Shifty / Celestial / Shifty Celestial), plus inline form badges in the list.
- Floating, spinning, bobbing 3D model of the selected familiar (borrows the familiar item's static mesh).
- Reads capture progress from the game's own statistics (`IsItemKnown`), so the dex persists across releasing a familiar and quitting to desktop with no custom save code.
- Smart roster filtering trims out elemental variants, named bosses and cut/broken content (configurable keyword, tag-variant, and explicit cut-content lists in `FamiliarDexConfig`); merges entries that share a display name.
- "Menu-like" presentation while open: freezes the player, hides the HUD, and blurs + dims the world behind the panel (each toggleable).
- Layout expressed as viewport fractions, so it looks consistent across 16:9, 21:9, ultrawide and any resolution.
- Drawn with `UTextRenderComponent` (world-space 3D text) — Shipping-build safe, no UMG/Blueprint asset, single `.as` file.

## Requirements
- Witchspire with the Hercules AngelScript mod framework.

## Installation
1. Copy `Mods/FamiliarCompendium.as` into your game's `...\Witchspire\Hercules\Script\Mods\` folder — or run `scripts/deploy.ps1` (or the repo's `deploy-all.bat`).
2. Fully restart Witchspire so AngelScript recompiles the mods.

## Controls

| Key | Action |
| --- | --- |
| `P` | Open / close the compendium |
| `↑` | Move the selection cursor up |
| `↓` | Move the selection cursor down |

All hotkeys are configurable at the top of `Mods/FamiliarCompendium.as` (`FamiliarDexConfig`). The binds are non-consuming, so they coexist with the game's own controls. While the panel is open the player is frozen, the HUD is hidden, and the world is blurred/dimmed — each is toggleable via `bFreezePlayerWhileOpen`, `bHideHudWhileOpen`, `bBlurBackgroundWhileOpen`, and `bDimBackgroundWhileOpen`.

## Compatibility
- Client-side; read-only, so it's safe in single-player and multiplayer.
- Coexists with the other Witchspire mods (unique type prefixes, non-consuming hotkeys).
- Does not use the game's Developer Mode / shared ImGui cheat menu — it's its own self-contained panel on the `P` key.

## Notes & limitations
- Read-only: the mod never modifies world state, game logic, or save data.
- Capture status comes from the game's saved "item known" record, so it persists across sessions. Per-form history is not persisted by the game, so form info (best rarity, owned variants) is only shown for familiars you currently own plus any seen this session — a species caught then released keeps its caught flag but loses its form badge.
- The game has no "is this catchable" flag, so the roster is built heuristically; turn on `bVerboseLog` to see exactly what each filter rule kept vs dropped in `Hercules.log`, then tune the lists in `FamiliarDexConfig`.
- There is no hot reload — fully restart the game after deploying.

## Changelog
### Unreleased
- Initial documented release.
