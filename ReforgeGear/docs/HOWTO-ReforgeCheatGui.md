# Reforge Cheat GUI — How to use

Reroll the random **substats** on starred gear (Rare / Epic / Legendary) from an
in-game debug panel that lists all your starred gear. Keeps the item's stars; only
the substats below the tooltip divider change.

## Install
1. Copy **`ReforgeCheatGui.as`** into your game's mods folder:
   `…\Steam\steamapps\common\Witchspire\Hercules\Script\Mods\`
2. **Fully restart the game** (quit to desktop and relaunch) — mods compile at launch.

> Only run one Reforge edition at a time. Don't keep `ReforgeAltar.as` or
> `ReforgeGear.as` in the Mods folder alongside this one.

## How to make the Cheat GUI appear
- This edition **auto-enables Developer Mode** on startup.
- In **normal gameplay** (not in a menu), press **`F7`** to open the ImGui debug menu.
- In the menu, go to **`Cheats` → `Reforge Gear`**.
- Press **`F7`** again to close the menu.

## How to reforge
The panel shows your **coin balance** and every starred item in your **bag and
equipment**. For each item you'll see:
- Its current substats — each tagged **`[MAX]`** (green) when it's the best possible
  roll for that stat, otherwise a dimmed `(max: …)` hint with the ceiling.
- A collapsible **Best obtainable substats** list (the item's loot ceiling).
- A **Roll quality: N/M maxed** score (`*** PERFECT ***` when everything is maxed).
- A **`[Reroll]`** button — click it to reroll for **100 coins** (greyed out until
  you can afford it). Equipped gear updates your live stats immediately.

Need coins to test? Press **`F10`** for +1000 coins.

## Notes
- **Single-player / host only** (rerolling is server-authoritative). No save editing
  — it only changes a live item.
- Rarity (stars) is never changed, only the substats.
- Developer Mode stays on while you play (it also unlocks the game's other debug
  menus). To opt out of auto-enabling it, set `bAutoEnableDeveloperMode = false` in
  the `ReforgeGuiConfig` block at the top of the file, then restart.
