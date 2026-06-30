# Witchspire — Quick Deposit

A client-side quality-of-life mod for **Witchspire** (Unreal Engine + AngelScript /
the "Hercules" script framework). One hotkey deposits everything in your backpack that
your base chests **already store** — a base-wide "quick stack to chests."

![type: QoL](https://img.shields.io/badge/type-QoL-blue) ![scripting: AngelScript](https://img.shields.io/badge/scripting-AngelScript-green)

## What it does

Press **H** while standing in your base and every item in your bag that a chest already
holds gets sent to that chest. Anything the base doesn't already stock — and anything in
your **toolbar** — stays with you. Outside the base, the key does nothing.

It only deposits items a chest already stocks (so it won't scatter new item types around),
filling existing stacks first and adding a new stack if there's room, and it respects each
item's max stack size. A cyan beam arcs from you to each chest as the items land — the
game's crafting resource-pull effect, in reverse.

## How it works

- `Hearth::IsLocationInHearth(player)` gates it to "at base" only.
- `AHearthManager.GetInventories()` enumerates every registered base storage inventory.
- For items a chest already stocks, `SmartTransferItemStack` fills its existing stacks
  then adds a new stack if there's a free slot — up to the item's max stack size.
- Input uses a non-consuming `BindKey` (mirrors the engine's `Example_CharacterInput.as`),
  so it coexists with the game's own controls.

## Install

Copy `Mods/QuickDeposit.as` into the game's script mods folder:

```
<Steam>/steamapps/common/Witchspire/Hercules/Script/Mods/
```

Or run the deploy script (edit the path inside if your install differs):

```powershell
./scripts/deploy.ps1
```

Then **fully restart the game** — AngelScript compiles mods once at launch, so any change
requires a restart to take effect.

All settings live in the `QuickDepositConfig` namespace at the top of the file:

- **Hotkey:** `HotkeyKey` — set it to any key, e.g. `EKeys::G`, `EKeys::V`, `EKeys::B`.
- **Deposit beam:** `bShowDepositBeam` (on/off) and `BeamLifetime` (seconds).

> **Why config and not the in-game Settings → Keyboard page?** That page is built from
> packed Unreal input-mapping-context assets wired into a fixed settings UMG. A script-only
> mod can't ship a new input asset or add a row to that menu, so rebinding is done here in
> the config instead.

## Notes & limitations

- **Single-player / host** focused: the base inventory list is server-side. It only moves
  items between live inventories — no save tampering.
- **Stack sizes:** it respects each item's max stack size. If you also run the **StackBoost**
  mod (cap 1000), it will consolidate up toward 1000 — that's expected, the same as the
  game's own "Store All" with StackBoost active, not a bypass.
