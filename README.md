# Witchspire Mods

A collection of client-side mods for **Witchspire** (Unreal Engine + AngelScript /
the in-game "Hercules" script framework). Each mod is self-contained in its own
folder with its source, deploy script, and README.

## Mods

| Mod | Type | What it does |
| --- | --- | --- |
| [CelestialBoost](CelestialBoost/) | Cheat | Raises the spawn odds of rare wild-familiar variants (Celestial / Shifty / Legendary), with a live cheat-menu panel to tune each one. |
| [FamiliarCompendium](FamiliarCompendium/) | QoL | A read-only "pokedex": a floating panel listing every familiar species by element, marking which you've captured and how many remain. |
| [InfiniteEndurance](InfiniteEndurance/) | Cheat | A Cheats-menu toggle so on-foot stamina **and** broom boost power never run out. |
| [LegendaryTracker](LegendaryTracker/) | QoL | Detects nearby wild **Legendary (3-star)** familiars and surfaces them (orb / label / beam) while you carry the detector trinket. |
| [LingerChanceIndicator](LingerChanceIndicator/) | QoL | Shows your odds of capturing the monster you're currently looking at. |
| [PhotoMode](PhotoMode/) | QoL | A Cheats → Photo Mode panel: freeze creatures, hold the time-of-day, and clear the sky/HUD for clean screenshots. |
| [QuickDeposit](QuickDeposit/) | QoL | One hotkey deposits everything in your backpack that your base chests already store — a base-wide "quick stack to chests." |
| [ReforgeGear](ReforgeGear/) | QoL | Rerolls the random substats on starred gear (Rare / Epic / Legendary) without changing rarity, and highlights the best obtainable roll. Ships as three editions, plus the separate **GodForge** mod. |
| [VanityWardrobe](VanityWardrobe/) | Cosmetic | Transmog / vanity armor — change how your gear **looks** without changing what it **does**. |

## Installing

Each mod is deployed by copying its `.as` file(s) into the game's AngelScript
mods folder (`...\Witchspire\Hercules\Script\Mods`), then fully restarting the
game so AngelScript recompiles.

- **All at once:** double-click [`deploy-all.bat`](deploy-all.bat) (or run it from
  a terminal). It auto-discovers every mod's `scripts\deploy.ps1` and also deploys
  ReforgeGear's GodForge edition.
- **One mod:** run that mod's `scripts\deploy.ps1`, e.g.
  `./LegendaryTracker/scripts/deploy.ps1`.

> The game-folder path is hard-coded near the top of each deploy script
> (`$GameModsDir`, or `scripts/_deploy-common.ps1` for ReforgeGear). Edit it if
> your Steam library lives somewhere other than the `Z:` drive.

After deploying, **fully restart Witchspire** — AngelScript only recompiles mods
on launch.

## Layout

```
Witchspire-Mods/
  <ModName>/
    Mods/<ModName>.as     # the AngelScript source the game loads
    scripts/deploy.ps1    # copies the source into the game folder
    README.md             # per-mod documentation
  deploy-all.bat          # deploy every mod at once
  LICENSE                 # MIT, applies to all mods
```

## License

MIT — see [LICENSE](LICENSE).
