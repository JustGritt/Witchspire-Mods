# Witchspire — Linger Chance Indicator

A small client-side mod for **Witchspire** (Unreal Engine + AngelScript / the "Hercules"
script framework) that shows your odds of capturing the monster you're looking at.

![type: QoL](https://img.shields.io/badge/type-QoL-blue) ![scripting: AngelScript](https://img.shields.io/badge/scripting-AngelScript-green)

## What it does

When you look at a wild, capturable monster (familiar), a subtle floating label appears
above it reading **`Capture X.X%`**. That number is the **linger chance** — the probability
that defeating the monster spawns a capturable spirit at all. (It's labelled "Capture"
because the follow-up bond roll is ~100%, so linger chance ≈ your real capture odds.)

By default the label shows only that total. **Press `L` in-game** (the `ToggleDetailsKey`) to
cycle through three display modes — each press steps **compact → full breakdown → off → compact**:

1. **Compact** — just `Capture X.X%`.
2. **Full breakdown** — the headline plus the actual equation behind it (see below).
3. **Off** — the label is hidden entirely.

In the full-breakdown mode it reads as the actual equation, e.g.:

```
Capture 7.9%  =  2.0% x 3.00 x 1.31
```

where the leading `2.0%` is the familiar's **base** lingering chance, `×3.00` is the difficulty
multiplier, and `×1.31` is your gear/bond multiplier. If pity has built up it appears inside
parentheses, since it adds *before* the gear step: `(2.0% x 3.00 + 2.4% pity) x 1.31`. Default
factors (`×1.00`, `+0%`) are dropped to keep it tidy.

It's read-only and runs entirely on your client: it never modifies the server,
other players, or your save.

## How capture actually works

Capturing a defeated monster has two gates:

1. **Linger roll** (shown) — on death, does a capturable spirit appear?
   `LingerChance = (LingeringChance + SuccessiveFailBonus) × LingeringModifier`
   (mirrors `NPCBase.as → TryLingering()`). Default base is ~5%.
2. **Bond roll** (not shown) — interacting with that spirit; defaults to 100%, so it's
   rarely the bottleneck.

`SuccessiveFailBonus` is a pity value that climbs each time a linger roll fails, so the
displayed % ticks upward the more captures slip away.

`LingeringModifier` is **your** player-side multiplier (default `1.0`). This is where gear
lands: items granting **"+1% Spirit Lingering Chance"** (the `Lingering_Element` attribute,
e.g. the *Symbol of Om* trinket) raise it to `×1.01`, `×1.05`, … Because it's *multiplicative*,
a lone +1% trinket only adds ~0.03 points on a 3% monster — far below whole-percent display.
The breakdown equation surfaces this multiplier directly (the `×1.01` factor) so you can confirm
your gear is being counted even when the headline barely moves — shown as an explicit multiplier
rather than a percentage so it's never mistaken for percentage-**points**.

## Install

Copy `Mods/LingerChanceIndicator.as` into the game's script mods folder:

```
<Steam>/steamapps/common/Witchspire/Hercules/Script/Mods/
```

Or run the deploy script (edit the path inside if your install differs):

```powershell
./scripts/deploy.ps1
```

Then **fully restart the game** — AngelScript compiles mods once at launch, so any change
(install or edit) requires a restart to take effect.

## Configuration

Tunables live in the `LingerChanceConfig` namespace at the top of the `.as` file:

| Setting | Default | Meaning |
|---|---|---|
| `VerticalOffset` | `-10` | Offset from the nameplate, in cm (negative = below the healthbar) |
| `ScreenSizeFactor` | `0.022` | Label scales with distance to keep a constant on-screen size |
| `MinTextSize` / `MaxTextSize` | `10` / `90` | Clamp on the distance-scaled size (keep Max high so far text stays readable) |
| `ToggleDetailsKey` | `EKeys::L` | Key that cycles the display mode (compact → full breakdown → off) in-game (doesn't consume input, so it co-exists with the game's binds) |
| `StartMode` | `ELingerDisplayMode::Capture` | Display mode on load: `Capture` (compact), `Breakdown` (equation shown), or `None` (hidden) |

## Notes & limitations

- The game is a **Shipping** build, so engine debug draw (`DrawDebugString`) renders
  nothing. This mod uses a real `UTextRenderComponent` (world-space 3D text) instead.
- A label pinned *inside* the nameplate (true screen-space UI) would require a UMG/Blueprint
  asset, which a script-only mod can't ship — hence the world-space label.

## Credits

Built on the modding pattern established by `StackBoost.as` (OwNeRexe).
