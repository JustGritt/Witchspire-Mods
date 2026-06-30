# VanityWardrobe

> Terraria-style transmog: change how your gear *looks* without touching what it *does*.

**Type:** Cosmetic · **Scope:** Single-player / listen-server (host); appearance is applied locally and the world Wardrobe's interaction is server logic (`HasAuthority()` gated) · **Hotkey:** `F6` to summon/dismiss the world Wardrobe, `F7` to toggle the ImGui panel (both confirmed in `VanityWardrobeConfig`)

Per visible equipment slot (Hat, Robe, Broom, ...) you pick an appearance that renders on your witch while your real equipped gear keeps 100% of its stats. The mod performs only the *visual* half of equipping a chosen item and never the stat half, leaning on the game's `UEquipmentInstance` split between visuals (`SpawnEquipmentActors()` / `EquipCharacterParts()`) and stats (`HandleEquipped()`).

## Features
- Per-slot appearance override with three modes: **Default** (your real gear), **Hidden** (base look), or **Vanity** (any item's look).
- Pick the look of **any item in the game** via the ImGui panel — even items you haven't found.
- Handles both look types automatically: **character-part items** (Hat/Robe/outfit) are swapped on the body via `UCharacterVisualsComponent` `RemovePart`/`AddPart` (like the character-creation screen), and **attached-actor items** (e.g. the broom) stow the real actor with `RequestHideItem` and spawn a cosmetic `AEquipmentActor` on the same socket.
- Two interfaces: a searchable ImGui Wardrobe panel (full item catalog, grouped by slot), and a summonable world Wardrobe object for use without Developer Mode.
- A light reconciler re-asserts your chosen looks every quarter-second (`ReconcileInterval = 0.25`), so they survive changing gear, respawning, or the body mesh rebuilding. It is idempotent and change-tracked, acting only when something actually differs.
- Saves the original body-slot part (e.g. your hairstyle, since hats live in the hair slot) so reverting to Default restores it instead of leaving the slot empty.
- Hides developer placeholder / retired items so they don't appear as cosmetics (matched by name marker `"not used"` or description marker `"no longer be used"`, case-insensitive; toggle with `bHideUnusedItems`).
- Weapon (Hand) slot is opt-in via `bIncludeWeaponSlot` (off by default, since the wielded item is constantly shown/hidden/animated by combat and building).

## Requirements
- Witchspire with the Hercules AngelScript mod framework.
- Single-player or listen-server host: the world Wardrobe interaction runs as server logic (`OnInteractServer`, gated by `HasAuthority()`), and appearance changes are applied to your local player.

## Installation
1. Copy `Mods/VanityWardrobe.as` into your game's `...\Witchspire\Hercules\Script\Mods\` folder — or run `scripts/deploy.ps1` (or the repo's `deploy-all.bat`).
2. Fully restart Witchspire so AngelScript recompiles the mods.

## Controls

| Key / Control | Action |
| --- | --- |
| `F7` | Toggle the ImGui **Vanity Wardrobe** panel (auto-enables Developer Mode). Find it under **Cheats → Vanity Wardrobe**. |
| `F6` | Summon / dismiss the in-world **Wardrobe** object (no Developer Mode needed). |
| Game **Interact** key (on the Wardrobe) | Applies the look of the item currently **selected in your hotbar** to its slot. Interact again with the same item to revert that slot. Limited to items you own. |
| ImGui panel — per slot | Choose **Default** (real gear), **Hidden** (base look), or any item; **Search** box filters; **Reset all** clears every override. |

> Press `F7` / `F6` during normal gameplay, not while a game menu is open. The mod auto-enables Developer Mode (`bAutoEnableDeveloperMode = true`) so the ImGui panel is reachable; set it false if you only want the world Wardrobe.

## Compatibility
- Coexists with the other Witchspire mods: unique `Vanity*` type prefixes and non-consuming `BindKey` hotkeys (`F6` summon, `F7` menu) mean no collisions when installed together.
- Single-player / listen-server-host focused — the world Wardrobe interaction only runs on the host.

## Notes & limitations
- **Cosmetic only.** No stat changes, no save tampering; the look swap is purely visual and your equipped gear stays fully effective.
- **No custom assets.** Looks can only reuse existing in-game meshes/parts — a script mod can't create new items.
- **Persistence:** selections survive map/level loads within a play session but reset when you fully quit. Re-pick from the panel after a restart.
- **No inventory-screen row:** the in-game inventory is a packed UMG asset a script-only mod can't extend, so the ImGui panel and the world Wardrobe are the two interfaces shipped.
- **Hidden** on a body slot (Hat/Robe) shows the *base* look (there's always a default body part); on an attached-actor slot it removes the mesh entirely.
- The weapon slot is opt-in (`bIncludeWeaponSlot`) and may look off during attacks since cosmetic weapons aren't animation-synced.

## Changelog
### Unreleased
- Initial documented release.
