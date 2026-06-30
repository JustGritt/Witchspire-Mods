# Reforge Gear (Full) — How to use

The **combined** edition: reroll the random **substats** on starred gear (Rare /
Epic / Legendary) using **either** a summoned altar **or** an in-game debug panel.
Keeps the item's stars; only the substats below the tooltip divider change.

## Install
1. Copy **`ReforgeGear.as`** into your game's mods folder:
   `…\Steam\steamapps\common\Witchspire\Hercules\Script\Mods\`
2. **Fully restart the game** (quit to desktop and relaunch) — mods compile at launch.

> Only run one Reforge edition at a time. Don't keep `ReforgeAltar.as` or
> `ReforgeCheatGui.as` in the Mods folder alongside this one.

## Hotkeys at a glance
| Key | Does |
|---|---|
| **`F9`** | Summon / dismiss the **Reforge Altar** in front of you |
| **`F7`** | Open / close the **Cheat GUI** panel (`Cheats → Reforge Gear`) |
| **`F10`** | Grant +1000 coins (for testing) |

## How to make the Reforge Altar appear
- In **normal gameplay** (not in a menu), press **`F9`** — a floating **REFORGE**
  altar spawns in front of you (press `F9` again to dismiss).
- Put the gear (or familiar) you want to reforge in a **hotbar slot** and **select
  it**. The altar shows its substats, cost, and your gold.
- **Hold** your normal **Interact** key on the altar (fill bar) to reroll it for
  **100 coins**. A quick tap does nothing.

## How to make the Cheat GUI appear
- This edition **auto-enables Developer Mode** on startup.
- Press **`F7`** in normal gameplay, then go to **`Cheats` → `Reforge Gear`**
  (press `F7` again to close).
- The panel lists every starred item in your **bag and equipment** with a
  **`[Reroll]`** button (100 coins each).

Both entry points show the best obtainable roll for each stat: a **`[MAX]`** tag on
maxed substats, a **Best obtainable substats** list, and an **N/M maxed** score.

## Notes
- **Single-player / host only** (rerolling is server-authoritative). No save editing
  — it only changes a live item.
- Rarity (stars) is never changed, only the substats.
- **Familiars** work too — their new substats apply on the familiar's next summon.
- Defaults (keys, cost, auto Developer Mode, altar look) live in the
  `ReforgeGearConfig` block at the top of the file; edit and restart to change them.
