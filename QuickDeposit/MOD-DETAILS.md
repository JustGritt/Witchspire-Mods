# QuickDeposit

> One hotkey at base: quick-stack your backpack into the chests that already hold each item.

**Type:** QoL · **Scope:** Client convenience, but item moves are host-gated (the base inventory list is server-side, so single-player / listen-server host) · **Hotkey:** H (set `QuickDepositConfig::HotkeyKey`, default `EKeys::H`)

Press H while standing in your base and every item in your backpack that a chest already stores is sent to that chest — a base-wide "quick stack to chests." Anything the base doesn't already stock, and anything in your toolbar/hotbar, stays with you; outside the base the key does nothing.

## Features
- One-key, base-wide deposit: sweeps the backpack into every registered base storage inventory at once.
- Only deposits into chests that already stock a matching item (by item tag), so it won't scatter new item types around.
- Fills existing stacks first via `SmartTransferItemStack`, then adds a new stack if the chest has a free slot; respects each item's max stack size.
- Never touches toolbar/hotbar items (slots below `HotbarComp.GetSlotCount()` are skipped).
- "At base" gate via `Hearth::IsLocationInHearth` — the hotkey is inert anywhere else.
- Optional cyan deposit beam (the crafting resource-pull VFX, reversed) arcs from the player to each chest that received items; toggle with `bShowDepositBeam`, linger time via `BeamLifetime`.
- Non-consuming `BindKey`, so it coexists with the game's own controls.

## Requirements
- Witchspire with the Hercules AngelScript mod framework.
- Single-player or listen-server host: the base inventory list is server-side, and the mod only moves items between live inventories (no save tampering).

## Installation
1. Copy `Mods/QuickDeposit.as` into your game's `...\Witchspire\Hercules\Script\Mods\` folder — or run `scripts/deploy.ps1` (or the repo's `deploy-all.bat`).
2. Fully restart Witchspire so AngelScript recompiles the mods.

## Controls
| Key | Action |
| --- | --- |
| H | Deposit all backpack items your base chests already store (only while at base; toolbar items excluded) |

Rebind by editing `QuickDepositConfig::HotkeyKey` (e.g. `EKeys::G`, `EKeys::V`, `EKeys::B`); a script-only mod can't add a row to the in-game keyboard settings page.

## Compatibility
- Coexists with the other Witchspire mods (unique `QuickDeposit*` type prefixes, non-consuming hotkey).
- Single-player / listen-server-host focused, since the base inventory list is server-side.
- With the StackBoost mod active (cap 1000), it consolidates up toward 1000 — the same as the game's own "Store All," not a bypass.

## Notes & limitations
- A "match" is by item tag: a chest must already hold at least one of an item (`GetTotalItemCountByTag(...) > 0`) before that item will be deposited there.
- Works only at base (inside a hearth's range); the hotkey does nothing elsewhere.
- Toolbar/hotbar items are always left in place.
- Stack sizes are respected per item (max stack, or 1000 with StackBoost).
- The deposit beam reuses a crafting station's resource-pull effect and chest "BuildingConnectionSocket"; if no station effect is found it simply doesn't draw (deposits still happen).

## Changelog
### Unreleased
- Initial documented release.
