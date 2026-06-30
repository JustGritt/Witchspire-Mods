# Reforge Altar — How to use

Reroll the random **substats** on starred gear (Rare / Epic / Legendary) at a
summoned altar. Keeps the item's stars; only the substats below the tooltip
divider change. **No Developer Mode needed.**

## Install
1. Copy **`ReforgeAltar.as`** into your game's mods folder:
   `…\Steam\steamapps\common\Witchspire\Hercules\Script\Mods\`
2. **Fully restart the game** (quit to desktop and relaunch) — mods compile at launch.

> Only run one Reforge edition at a time. Don't keep `ReforgeCheatGui.as` or
> `ReforgeGear.as` in the Mods folder alongside this one.

## How to make the Reforge Altar appear
- In **normal gameplay** (not in a menu), press **`F9`**.
- A floating **REFORGE** altar spawns in front of you.
- Press **`F9`** again to dismiss it.

## How to reforge
1. Put the gear (or familiar) you want to reforge in a **hotbar slot** and **select
   that slot** — that's how you target it (there's no clickable picker).
2. The altar shows the selected item's model, its **current substats**, the cost,
   and your gold. Each substat that's already the **best possible roll** for its
   stat is tagged **`[MAX]`**, with an `N/M maxed` summary.
3. **Hold** your normal **Interact** key on the altar (a fill bar appears). On
   release-after-fill it rerolls that item and charges **100 coins**. A quick tap
   does nothing (that's the anti-misclick confirmation).
4. Re-hold to chase a better roll. Select a different hotbar slot to target a
   different item.

- **Familiars** work too — their new substats apply the next time the familiar is
  summoned.
- Reforging costs **100 coins** per reroll — you pay with your own coins (this
  edition binds **only F9**, nothing else).

## Notes
- **Single-player / host only** (rerolling is server-authoritative). No save editing
  — it only changes a live item.
- Rarity (stars) is never changed, only the substats.
- Don't like a default? Edit the `ReforgeAltarConfig` block at the top of the file
  (summon key, cost, hold time, etc.), then restart.
