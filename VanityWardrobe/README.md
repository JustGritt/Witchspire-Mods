# Witchspire — Vanity Wardrobe

A **transmog / vanity armor** mod for **Witchspire** (Unreal Engine + AngelScript /
the "Hercules" script framework). Terraria-style: change how your gear **looks**
without changing what it **does**. Your equipped gear keeps 100% of its stats —
the appearance you pick is purely cosmetic.

![type: cosmetic](https://img.shields.io/badge/type-cosmetic-purple) ![scripting: AngelScript](https://img.shields.io/badge/scripting-AngelScript-green)

## What it does

For each visible equipment slot (Hat, Robe, Broom, …) you choose an **appearance**
that renders on your witch while your real gear stays equipped and fully effective.
Pick the look of **any item in the game** — even ones you haven't found — or hide a
slot entirely. Your stats never change; only the mesh you see does.

## Why it works (no stat side-effects)

The game already separates an item's **visuals** from its **stats** (see
`EquipmentInstance.as`):

- **looks** = `SpawnEquipmentActors()` (attached meshes) + `EquipCharacterParts()`
  (body-mesh swaps via `UCharacterVisualsComponent::AddPart`)
- **stats** = `HandleEquipped()` (abilities / gameplay effects / actions)

A vanity look just performs the **visual half** for an item you choose, and never
the stat half. Two look types are handled automatically per item:

- **Character-part items** (the witch's Hat / Robe / outfit): swapped on the body
  with `RemovePart(slot)` / `AddPart(part)`, exactly like the character-creation
  screen (`PlayerCustomizationComponent`).
- **Attached-actor items** (e.g. the broom): the real one is stowed with
  `EquipmentComp.RequestHideItem(slot)` and a cosmetic `AEquipmentActor` is spawned
  and attached to the same socket.

A light reconciler re-asserts your chosen looks every quarter-second, so they
survive changing gear, respawning, or the body mesh rebuilding.

## Two ways to pick a look

**1. ImGui Wardrobe panel — press `F7`** *(full freedom; auto-enables Developer Mode)*

A panel listing **every** item in the game grouped by slot, with a search box.
Per slot choose **Default** (your real gear), **Hidden** (base look), or any item.
Find it under **Cheats → Vanity Wardrobe**.

> Press `F7` in normal gameplay (not while a menu is open). The mod auto-enables
> Developer Mode so the ImGui menu is available, mirroring the Reforge Gear mod.

**2. World Wardrobe object — press `F6`** *(no Developer Mode needed)*

Summons a Wardrobe in front of you. Put the gear whose look you want into a hotbar
slot, **select it**, then press the game's **Interact** key on the Wardrobe — that
look is applied to its slot. Interact again with the same item to revert that slot.
Press `F6` again to dismiss the Wardrobe. (This path is limited to items you own.)

## Install

Copy `Mods/VanityWardrobe.as` into the game's script mods folder:

```
<Steam>/steamapps/common/Witchspire/Hercules/Script/Mods/
```

Or run the deploy script (edit the path inside if your install differs):

```powershell
./scripts/deploy.ps1
```

Then **fully restart the game** — AngelScript compiles mods once at launch, so any
change requires a restart to take effect.

## Configuration

All settings live in the `VanityWardrobeConfig` namespace at the top of the file:

- **`ToggleMenuKey`** (`EKeys::F7`) — opens/closes the ImGui Wardrobe panel.
- **`SummonWardrobeKey`** (`EKeys::F6`) — summons/dismisses the world Wardrobe.
- **`bAutoEnableDeveloperMode`** (`true`) — enable Developer Mode so the panel is reachable.
- **`bIncludeWeaponSlot`** (`false`) — include the weapon (Hand) slot. Off by default
  because the wielded item is constantly shown/hidden/animated by combat, dodging and
  building, so a static cosmetic weapon can look out of place or get briefly overridden.
- **`ReconcileInterval`** (`0.25`) — how often the look is re-asserted.

> **Why no row in the in-game inventory screen?** That screen is a packed UMG asset;
> a script-only mod can't add slots to it. The ImGui panel and the world Wardrobe are
> the two interfaces a script mod *can* ship without bundling UI assets.

## Notes & limitations

- **Single-player / host** focused. The appearance is applied **locally** — it only
  swaps what you see; no save tampering, no stat changes.
- **Persistence:** selections survive map/level loads within a play session, but reset
  when you fully quit the game. Re-pick from the panel after a restart.
- **Hidden** on a body slot (Hat/Robe) shows the *base* look (there's always a default
  body part); on an attached-actor slot it removes the mesh entirely.
- The weapon slot is opt-in (see `bIncludeWeaponSlot`) and may look off during attacks
  since cosmetic weapons aren't animation-synced.
