# Witchspire — Reforge Gear

A client-side quality-of-life mod for **Witchspire** (Unreal Engine + AngelScript /
the "Hercules" script framework). Rerolls the random **substats** on starred gear
(Rare / Epic / Legendary) without changing the item's rarity, and highlights the
**best obtainable roll** for every stat so you know when a line is maxed.

Ships as **three editions** — pick one (see [Editions](#editions)): a summonable
**Reforge Altar** (no Developer Mode), an **ImGui Cheat GUI** panel, or the **Full**
build with both.

![type: QoL](https://img.shields.io/badge/type-QoL-blue) ![scripting: AngelScript](https://img.shields.io/badge/scripting-AngelScript-green)

## What it does

Starred gear carries random **substats** — the bonuses listed *below the divider* in
the tooltip (e.g. `+40% Critical Strike Damage`, `+30 Max Health`, `+15% Wand Damage`).
The number of substats matches the star count: **Rare = 1, Epic = 2, Legendary = 3**.

This mod adds a panel that lists every starred item in your **bag and equipment**, shows
its current substats, and gives each a **[Reroll]** button. Rerolling keeps the item's
stars and re-rolls **only** the substats. The stats *above* the divider (the item's fixed
base stats) are never touched.

Each reroll **costs coins** — so reforging is a real resource sink, not a free respin.
The button is **disabled** until you can afford it.

## Max-roll highlighting

Substats are **not** rolled from a min–max range — each possible substat (e.g.
`+50% Spellblade Damage` vs `+25% Spellblade Damage`) is its own fixed entry in the
game's rarity pools (`UItemRaritySettings`). That makes the **best obtainable value
for every stat fully knowable**, and the mod surfaces it:

- **`[MAX]` tag** (green) on any current substat that's already the best possible roll
  for its stat on that item; others show a dimmed `(max: …)` hint with the ceiling.
- **Best obtainable substats** — a collapsible per-item list of the highest value every
  stat that item can roll (its loot ceiling). *(Cheat GUI / Full editions.)*
- **Roll quality: N/M maxed** — a score per item, reading `*** PERFECT ***` when every
  substat is maxed.

Gear only (familiars roll from a separate pool, so they reforge but aren't analyzed);
"best" assumes higher is better and only counts beneficial effects.

## Editions

The three editions share **no** class/namespace names, but you should run **one at a
time**. Each deploy script installs its edition and removes the others from the game
folder so only one is active.

| Edition | File | Deploy | Controls | Developer Mode |
|---|---|---|---|---|
| **Reforge Altar** | `Mods/ReforgeAltar.as` | `./scripts/deploy-altar.ps1` | **F9** summon → **Interact** to reforge | No |
| **Cheat GUI** | `Mods/ReforgeCheatGui.as` | `./scripts/deploy-gui.ps1` | **F7** opens **Cheats → Reforge Gear** | Yes (auto) |
| **Full** | `Mods/ReforgeGear.as` | `./scripts/deploy.ps1` | Both of the above | Yes (auto) |

The **Cheat GUI** edition reforges for **free**; the **Altar** and **Full** editions
cost 100 coins per reroll. `F10` grants test coins in the **Cheat GUI** and **Full**
editions — the **Altar** edition binds **only F9**. After deploying, **fully restart
the game**.

## Two ways to reforge

| | **Reforge Altar** (no Developer Mode) | **ImGui panel** (Developer Mode) |
|---|---|---|
| Opens with | **F9** — summons a world object you Interact with | **F7** — the debug menu |
| Reforges | the item **selected in your hotbar**, one interact = one reroll | any single item, **bag or equipped** |
| Needs Developer Mode | **No** | Yes (auto-enabled) |
| Best for | quick, legit in-game reforging | bag items / browsing all gear |

### Reforge Altar (recommended — no Developer Mode)

1. **Put the gear or familiar you want to reforge in a hotbar slot and select that slot**
   (the thing you'd “wield”). This is how you target it — there's no clickable picker
   without Developer Mode (see below).
2. Press **F9**. A **Reforge** marker appears in front of you, spinning the **model of your
   selected item** and showing a live readout: the target, **its current substats**, the
   cost, and **your current gold** (press F9 again to dismiss). Non-rerollable picks (potions,
   materials) show no model, say *“no substats to reforge”*, and the altar becomes
   **non-interactable** (no prompt) so you can't waste a hold on them.
3. **Hold** your normal **Interact** key on it (a fill bar appears). On release-after-fill it
   rerolls **your selected item** and deducts the flat **100-coin** cost. A quick tap does
   nothing — that's the built-in confirmation against accidental rerolls.
4. You'll see an on-screen message with the item name **and its new substats**, e.g.
   *“Reforged 'Oak Wand' (-100 coins) / +12% Wand Damage / +30 Max Health”* — so you always
   know what you rolled. Hold again to chase.
   - Select a different hotbar slot to target a different item.
   - **Familiars** work too. A familiar's new substats apply when it's next **summoned**, so
     re-summon an active familiar to see them on the live creature (the readout updates
     immediately either way).

### ImGui panel (per-item, needs Developer Mode)

This mod auto-enables **Developer Mode** and binds a world hotkey to open the debug menu.

1. In normal gameplay (not in a menu), press **F7**. The ImGui debug menu opens.
2. Find **Cheats → Reforge Gear**. The panel shows your current **coin balance** at the top.
3. Each starred item shows its substats, its **reroll cost**, and a **[Reroll]** button.
   Click to reroll — the coins are deducted on the spot.
   - The cost is a flat **100 coins** per reroll (any rarity).
   - If you can't afford it, the button is greyed out and the cost turns red
     (e.g. *"need 30 more"*).
   - For **equipped** gear the new substats apply to your live stats immediately.
   - For **bag** gear they apply as soon as you equip it.
4. Press **F7** again to close the menu.

> The game's own debug-menu key also opens it once Developer Mode is on. Prefer the Altar
> and don't want the panel? Set `bAutoEnableDeveloperMode = false` in the config.

## Why the Altar targets the hotbar (and the panel needs Developer Mode)

To pick an **arbitrary bag item** you need a clickable on-screen list. In Witchspire a real
UMG menu requires a **Widget Blueprint authored in the editor**, and a script-only mod
(just an `.as` file) can't ship one into the cooked game — the engine's own UMG example
confirms script widgets are only *base classes* for editor-built blueprints, and there's no
generic "show a list, call me back" UI hook exposed to scripts. The game **also freezes
gameplay input while the inventory is open**, so a hotkey can't fire while you're hovering a
bag item.

Two consequences:

- The **ImGui debug menu** *can* show a full clickable list (it runs its own input layer),
  so it gets per-item control over bag **and** equipped gear — but it lives behind
  **Developer Mode**.
- The **Reforge Altar** avoids Developer Mode by using the game's real **world-interactable**
  system (no UMG asset needed). Without a picker it needs a script-addressable "target", and
  the **selected hotbar slot** is exactly that (`UHotbarComponent::GetSelectedItemStack`). So
  you target an item by selecting it in your hotbar — no list required.

(A “custom crafting recipe” isn’t an option either: the crafting system only ever spawns
brand-new items from a tag — it has no way to reroll a specific item you already own.)

## How it works

In Witchspire, a starred item's substats are its rarity **passive effects**, stored on
the item's `UItemRuntimeFragment_Rarity` as `RarityEffects`.

- `RarityFrag.SetRarity(RarityFrag.GetRarity())` — the engine's own method that empties
  `RarityEffects` and **re-rolls** them from the same rarity pool
  (`ItemRaritySettings::RollPassiveEffects`). Same rarity in → same star count, fresh
  substats out.
- The reroll + flat coin cost live in one shared `ReforgeCore` namespace, used by both
  entry points below.
- For **equipped** gear the equipment instance is refreshed in place
  (`HandleUnequipped` → reroll → `HandleEquipped`) so the live stats update without moving
  the item between inventories.

**ImGui panel:** a `UImGuiDebugMenuWindow` registered under `Cheats|Reforge Gear` (the same
pattern as the game's `Item Granter` debug menu). A world hotkey
(`UInputComponent::BindKey`, like the QuickDeposit mod) opens/closes it via
`UImGuiDebugMenuSubsystem::Show/Hide` + `ImGuiModule::SetInputEnabled`.

**Reforge Altar:** a runtime-spawned `AReforgeAltar` actor with the engine's
`UInteractableComponent` (a capsule on the `Interactable` collision layer), a spinning
`UStaticMeshComponent` that mirrors the **selected hotbar item's** world mesh
(`Item.GetItemDefinition().ActorsToSpawn[0].StaticMesh`, refreshed in `Tick` — the same
mesh-borrowing trick the vendor uses, since a script mod can't load cooked meshes by path),
and a floating, camera-facing `UTextRenderComponent` label. The interaction is a **sustained** one
(`InteractionDuration > 0`), so you **hold** to reforge and the engine draws the fill bar;
on completion `UInteraction_ReforgeSelected::OnInteractServer` reads
`HotbarComp.GetSelectedItemStack()`, consumes coins, rerolls that one item, and `Print(...)`s
the new substats — mirroring `UInteraction_VendorBuyItem` (server-authoritative
pay-then-reward). The F9 hotkey summons/dismisses the altar in front of you.

## Install

Pick an [edition](#editions) and run its deploy script (they share
`scripts/_deploy-common.ps1` — edit `$GameModsDir` there if your install differs) — it
copies that one `.as` into the game's script mods folder and removes the others so only
one is active:

```powershell
./scripts/deploy-altar.ps1   # Reforge Altar (no Developer Mode)
./scripts/deploy-gui.ps1     # Cheat GUI panel
./scripts/deploy.ps1         # Full (altar + panel)
```

Or copy the one file you want by hand into:

```
<Steam>/steamapps/common/Witchspire/Hercules/Script/Mods/
```

Don't keep more than one edition in that folder at once. Then **fully restart the game**
— AngelScript compiles mods once at launch.

## Config

All settings live in the `ReforgeGearConfig` namespace at the top of the file:

- **Toggle key:** `ToggleMenuKey` — the world hotkey that opens the debug menu (default
  `EKeys::F7`).
- **Auto Developer Mode:** `bAutoEnableDeveloperMode` — set `false` if you'd rather enable
  `Herc.Cheats.DeveloperMode` yourself.
- **Cost currency:** `CostItemTag` — the item spent per reroll (default `Items_Coin`, the
  same coins NPC vendors take). Point it at any item gameplay tag — e.g. a crafting material.
- **Reroll cost:** `RerollCost` — flat coins charged per reroll, the same for every rarity
  (default `100`). **Set to `0` to make reforging free.**
- **Reforge Altar:** `bEnableReforgeAltar` — set `false` to disable the F9 altar entirely.
- **Summon key:** `SummonAltarKey` — the world hotkey that summons/dismisses the altar
  (default `EKeys::F9`).
- **Hold-to-confirm:** `AltarHoldSeconds` — seconds you must hold Interact before the altar
  reforges (default `0.75`; set `0` for instant, no confirmation).
- **Altar model:** the altar floats and spins the **model of the item you have selected**
  (the one you're about to reforge) — a script mod can't load cooked workbench/circle meshes
  by path, so it reuses the live item's own world mesh. Each item is **auto-scaled** so its
  largest dimension is about `AltarItemTargetSize` cm (default `60`) — so a huge sword and a
  tiny trinket all show at a consistent size. `AltarSpinDegreesPerSec` (default `45`) spins it
  (`0` = still). No item selected (or a mesh-less item) just shows the text label.
- **Altar layout** (so the item and text don't overlap): `AltarMeshHeight` (default `50`) and
  `AltarLabelHeight` (default `165`) are the cm heights of the floating item and the text;
  `AltarLabelSize` (default `32`) is the text size; `AltarSummonDistance` (default `150`) is
  how far in front of you it spawns. Raise/lower to taste.
- **Debug gold:** `bEnableDebugGold` / `DebugGoldKey` (default `EKeys::F10`) /
  `DebugGoldAmount` (default `1000`) — press the key to grant yourself coins for testing
  (no Developer Mode needed). Set `bEnableDebugGold = false` for "real" play.

## Notes & limitations

- **Single-player / host** focused: `SetRarity` is server-authoritative. On a listen-server
  host (or single-player) you *are* the server, so it works. No save tampering; it only
  modifies a live item.
- **Rarity is preserved**, never upgraded — this rerolls substats, it does not turn a Rare
  into a Legendary. The substat pool is the same one the game uses when the item drops.
- **Developer Mode** is required for the ImGui menu; the mod enables it automatically. This
  also unlocks the game's other debug menus while active.
- **Familiars are supported** — they store substats as rarity effects just like gear, so the
  altar (and panel) can reroll them. A reroll updates the familiar **item** immediately; the
  live summoned creature picks up the new substats on its **next summon**.
- **Costs coins**, scaling with rarity. The cost is both gated in the UI (disabled button)
  and re-checked host-side in `Reroll()` before `SetRarity`, so a stale panel can never
  reroll for free. Coins are consumed via the same inventory API the game's vendors and
  crafting use (`UInventoryComponent::RemoveItemsByTag`). Set the costs to `0` for free mode.

## God Forge — grant gear or familiars with chosen substats

The Reforge editions reroll an item you already own. **God Forge** is a separate
companion panel that closes the other gap: the game's native **Cheats → Item Granter**
can spawn any item at any rarity, but the substats still roll **randomly** — so you can
ask for a Legendary ring but never the one *with attack speed*. God Forge lets you
**hand-pick** them, for weapons, armor, accessories **and familiars**.

- Deploy: `./scripts/deploy-godforge.ps1` — it uses distinct class names and the **F8**
  key, so it installs **alongside** any Reforge edition (or on its own). Fully restart
  the game afterwards.
- Key sharing: **F8** is the same "cheat menu" key the CelestialBoost / InfiniteEndurance
  mods use — that's fine, they all open the *one* shared ImGui debug menu and God Forge's
  window simply appears under **Cheats** too. If another mod already opens that menu, set
  `bBindOwnMenuKey = false` in the config to skip God Forge's own (redundant) binding.
- Use: press **F8** → **Cheats → God Forge**. The panel walks three collapsible steps —
  **(1)** search and pick a piece of gear or a familiar from the results table, **(2)** choose
  its rarity (Rare/Epic/Legendary = 1/2/3 substats) and click **Grant base item**, **(3)** pick
  each substat from a dropdown of that item's obtainable stats, set the **item level** for
  equipment, and click **Apply chosen stats**.
- Familiars: they store substats as the same rarity effects gear does, just drawn from a
  separate pool (filtered against the familiar's actor). The new substats apply when the
  familiar is next **summoned**; if it's already out, God Forge re-pushes them to the live
  creature immediately. Familiars have no item level (they level via XP), so that control is
  hidden for them and their current level is shown for reference.
- Item level (equipment): the native grant leaves gear at a low default (e.g. level 3 → 5
  damage), whereas crafting stamps the *crafter's* level (e.g. level 26 → 43 damage). God
  Forge defaults a granted piece to **your character level** (matching crafting) and lets you
  type any level or click **Match my level**. It reads `UItemRuntimeFragment_Equipment.ItemLevel`
  (a curve-table input for base power) and writes it with `SetItemLevel(...)`.
- Each picked stat is granted at its **maximum obtainable magnitude** (the loot ceiling for
  that stat on that item), pulled straight from the game's `UItemRaritySettings` pools — a
  legitimate in-pool god-roll, just hand-chosen instead of random.

**How it works:** it grants the item like the native granter
(`InventoryComponent::AddItemsByTagWithRarity`, which returns the live stack), then writes
the chosen substats with the engine's own deterministic overload
`UItemRuntimeFragment_Rarity::SetRarity(Rarity, PassiveEffects)` — the same `RarityEffects`
array the reroll fills, set directly instead of rolled. Familiars share that fragment, so
the same setter works on them; God Forge enumerates the `FamiliarPassivePool_*` against the
familiar's class-default actor and refreshes a summoned familiar with
`UFamiliarComponent::OnSpawnedFromItem`. Server-authoritative (host / single-player),
Developer Mode auto-enabled.

## Also in this repo

- **[Skip Intro Movies](SkipIntroMovies/README.md)** — a small config override that boots
  the game straight to the menu by skipping the Unreal / Envar / Witchspire startup videos.
  Apply with `./scripts/skip-intro.ps1` (revert with `-Revert`). It's a config tweak, not an
  AngelScript mod, because the logos play before the script framework loads.
