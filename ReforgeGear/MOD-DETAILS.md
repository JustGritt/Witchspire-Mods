# ReforgeGear

> Reroll the random substats on starred gear (Rare / Epic / Legendary) without changing rarity, and see the best obtainable roll for every stat.

**Type:** QoL · **Scope:** Host-authoritative (single-player / listen-server host) · **Hotkey:** F9 summon altar · F7 cheat panel · F10 debug gold (F8 for the separate GodForge mod)

Starred gear carries random **substats** — the bonuses below the divider in the tooltip, one per star (Rare = 1, Epic = 2, Legendary = 3). ReforgeGear re-rolls *only* those substats (the fixed base stats above the divider are never touched) by calling the engine's own `RarityFrag.SetRarity(...)`, which empties and re-rolls the rarity-effect pool — same rarity in, same star count, fresh substats out. Because each possible substat is a fixed entry in the game's rarity pools rather than a min–max range, the best obtainable value for every stat is fully knowable, so the mod also flags maxed rolls.

## Editions

Ships as **three editions** that share no class/namespace names but **must not run at once** — each deploy script installs its edition and removes the others from the game folder, so only one is active.

| Edition | File | Deploy | Controls | Developer Mode | Cost |
|---|---|---|---|---|---|
| **Reforge Altar** | `Mods/ReforgeAltar.as` | `scripts/deploy-altar.ps1` | **F9** summon → **hold Interact** to reroll | No | 100 coins / reroll |
| **Cheat GUI** | `Mods/ReforgeCheatGui.as` | `scripts/deploy-gui.ps1` | **F7** → Cheats → Reforge Gear | Yes (auto) | Free |
| **Full** | `Mods/ReforgeGear.as` | `scripts/deploy.ps1` | Both of the above | Yes (auto) | 100 coins / reroll |

**GodForge** (`Mods/GodForge.as`, `scripts/deploy-godforge.ps1`) is a **separate companion mod** with distinct class names and the **F8** key, so it installs **alongside** any Reforge edition. It hand-picks substats on a freshly granted item instead of rerolling one you own.

## Features

- **Reroll substats on starred gear** — keeps the item's stars and rarity, re-rolls only the substats from the game's own rarity pool.
- **Works on bag and equipped gear** — equipped items refresh in place (`HandleUnequipped` → reroll → `HandleEquipped`) so live stats update without moving the item.
- **Familiars too** — they store substats as the same rarity effects; a reroll updates the familiar item immediately and the live creature picks it up on its next summon.
- **Max-roll highlighting** — a green `[MAX]` tag on any substat that's already the best possible roll for its stat on that item; others show a dimmed `(max: …)` ceiling hint.
- **Best obtainable substats** — a collapsible per-item list of each stat's loot ceiling (Cheat GUI / Full editions).
- **Roll quality score** — `N/M maxed` per item, reading `*** PERFECT ***` when every substat is maxed.
- **Coin cost as a real sink** — a flat 100 coins per reroll (Altar / Full), gated in the UI and re-checked host-side; set `RerollCost = 0` for free mode. The Cheat GUI edition is free.
- **Two reforge paths** — a no-Developer-Mode **Altar** that reforges the item selected in your hotbar via hold-to-Interact, and an **ImGui panel** that reforges any single bag or equipped item.
- **GodForge companion** — grant any gear or familiar at a chosen rarity, then hand-pick each substat at its maximum obtainable magnitude, with item-level control for equipment.

## Requirements

- Witchspire with the Hercules AngelScript mod framework.
- Host / single-player — `SetRarity` is server-authoritative, so rerolls only take effect on the host.
- **Developer Mode** for the ImGui panel (Cheat GUI / Full editions and GodForge auto-enable it). The Altar edition needs no Developer Mode.

## Installation

1. Pick **one** Reforge edition and run its deploy script — they share `scripts/_deploy-common.ps1` (edit `$GameModsDir` there if your install differs), and each script installs its `.as` and removes the others so only one edition is active:
   ```powershell
   ./scripts/deploy-altar.ps1   # Reforge Altar (no Developer Mode)
   ./scripts/deploy-gui.ps1     # Cheat GUI panel
   ./scripts/deploy.ps1         # Full (altar + panel)
   ```
2. Optionally add **GodForge** alongside it: `./scripts/deploy-godforge.ps1`.
3. Or copy the one file you want by hand into `...\Witchspire\Hercules\Script\Mods\` (the repo's `deploy-all.bat` installs the Full edition plus GodForge).
4. Fully restart Witchspire so AngelScript recompiles the mods. Don't keep more than one Reforge edition in the folder at once.

## Controls

**Reforge Altar (no Developer Mode)**

| Key / Control | Action |
|---|---|
| **F9** | Summon / dismiss a Reforge marker in front of you that spins the model of your selected hotbar item and shows its substats, cost, and your gold. |
| Select a hotbar slot | Targets that item for reforging (there's no clickable picker without Developer Mode). |
| **Hold Interact** (your normal key) | Hold past the fill bar to reroll the selected item and deduct 100 coins. A quick tap does nothing — built-in confirmation. |

**ImGui panel (Cheat GUI / Full — Developer Mode auto-enabled)**

| Key / Control | Action |
|---|---|
| **F7** | Open / close the ImGui debug menu (then pick **Cheats → Reforge Gear**). |
| **[Reroll]** button | Reroll that item; coins deduct on the spot. Disabled (cost turns red) when you can't afford it. |
| **F10** | Grant test coins (`DebugGoldAmount`, default 1000). Cheat GUI / Full only — the Altar edition binds only F9. |

**GodForge (F8)** — press **F8** → **Cheats → God Forge**, then walk three steps: pick a gear/familiar, choose rarity and grant the base item, then pick each substat from a dropdown (and set item level for equipment) and apply.

## Compatibility

- Client-side mod; safe in single-player and as the listen-server host. Rerolls are server-authoritative, so they apply on the host.
- The three Reforge editions are **mutually exclusive** — run only one; the deploy scripts enforce this by removing the others.
- **GodForge installs alongside** any Reforge edition (distinct class names, F8 key).
- Coexists with the other Witchspire mods (unique type prefixes, non-consuming hotkeys). F8 is the shared cheat-menu key (CelestialBoost / InfiniteEndurance / GodForge all open the one ImGui menu); if another mod already opens it, set `bBindOwnMenuKey = false` in GodForge's config to skip its redundant binding.

## Notes & limitations

- **Rarity is preserved, never upgraded** — this rerolls substats only; it won't turn a Rare into a Legendary. The substat pool is the same one the game uses when the item drops.
- **No save tampering** — it only modifies a live item; the coin cost is consumed via the same inventory API vendors and crafting use (`RemoveItemsByTag`), and re-checked host-side before `SetRarity`, so a stale panel can't reroll for free.
- **Familiars** apply new substats on their next summon (the readout/item updates immediately; re-summon to see them on the live creature).
- **Why the Altar targets the hotbar:** a script-only `.as` mod can't ship a UMG widget for a clickable bag picker, and gameplay input is frozen while the inventory is open — so the Altar targets the selected hotbar slot (`UHotbarComponent::GetSelectedItemStack`), while the ImGui panel (its own input layer) gets a full clickable list but lives behind Developer Mode.
- **Gear only is analyzed** for max-roll hints; familiars roll from a separate pool, so they reforge but aren't scored. "Best" assumes higher is better and counts only beneficial effects.
- Configurable in the `ReforgeGearConfig` namespace: `ToggleMenuKey` (F7), `SummonAltarKey` (F9), `RerollCost` (100; 0 = free), `CostItemTag` (Items_Coin), `AltarHoldSeconds` (0.75), `bEnableReforgeAltar`, `bAutoEnableDeveloperMode`, debug-gold (`DebugGoldKey` F10 / `DebugGoldAmount` 1000), and altar layout/model sizing.
- **Also in this repo:** `SkipIntroMovies/` — a config override (not an AngelScript mod) that skips the startup videos; apply with `./scripts/skip-intro.ps1` (`-Revert` to undo).

## Changelog

### Unreleased
- Initial documented release covering all three Reforge editions and the GodForge companion mod.
