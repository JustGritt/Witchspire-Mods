# Witchspire — Infinite Endurance

A simple toggleable cheat for Witchspire, in the in-game **Cheats menu**: tick a
box and your **endurance never runs out**. This covers **both** endurance bars:

- **On-foot stamina** — sprint and dodge endlessly, and never pick up the
  **Exhaustion** debuff.
- **Broom boost power** — hold the broom's boost/sprint forever without the
  power bar draining out and dropping you back to a glide.

While the cheat is on, both bars are topped back up to full every frame.
Abilities still spend stamina / drain power normally (so nothing in the game
breaks); the bars just refill instantly behind them.

> **Single-player / host only.** These are server-authoritative attributes, so
> the refill only takes effect when you're the host. On a multiplayer client
> where you aren't the host, the toggle does nothing.

## Controls

The toggle lives in the ImGui **Cheats** menu — no dedicated gameplay key:

1. Press **`F8`** to open the cheat menu (or use any other mod's opener — e.g.
   Vanity Wardrobe's `F7`; it's the same shared menu).
2. Open **Cheats → Infinite Endurance**.
3. Tick **Infinite Endurance**. The panel shows both bars sitting at full while
   it's on.

The mod auto-enables Developer Mode so the menu is available, and the toggle
resets to OFF every time you launch the game. The opener key (`F8`) is chosen to
avoid the other mods' keys (`F6` wardrobe, `F7` menu, `F9` altar) — you can
change or disable it in the config.

## Install

1. Copy `Mods/InfiniteEndurance.as` into your game's AngelScript mods folder:

   ```
   <Steam>\steamapps\common\Witchspire\Hercules\Script\Mods\
   ```

   On Windows you can just run the deploy script (edit the path at the top first
   if your Steam library isn't on `Z:`):

   ```powershell
   ./scripts/deploy.ps1
   ```

2. **Fully restart the game** (quit to desktop and relaunch). Witchspire only
   compiles AngelScript mods at launch — there is no hot reload.

3. In-game, press `F6` to toggle.

## Configuration

Open `Mods/InfiniteEndurance.as` and edit the values in the
`InfiniteEnduranceConfig` namespace at the top:

| Setting | Default | What it does |
| ------- | ------- | ------------ |
| `bStartEnabled` | `false` | Start with the cheat already on at launch. |
| `bAutoEnableDeveloperMode` | `true` | Auto-enable Developer Mode so the cheat menu is available. |
| `bBindOwnMenuKey` | `true` | Bind our own key to open the cheat menu (set `false` to rely only on another mod's opener). |
| `MenuKey` | `EKeys::F8` | The opener key. Any `EKeys::...` value works. |
| `bVerboseLog` | `true` | Log each toggle to `Hercules.log`. |

After any edit, re-deploy and fully restart the game.

## How it works

- Stamina lives on `UActionAttributeSet` (`Stamina` / `MaxStamina`); the broom's
  boost bar lives on `UBroomAttributeSet` (`Power` / `MaxPower`). A
  `UScriptWorldSubsystem` ticks each frame and, while enabled, calls
  `UHercAbilityComponent::SetAttributeBaseValue` to set each back to its max —
  the same attribute call the game uses internally. Writing the base value
  directly also bypasses the regen delay, the Exhaustion block, and the broom's
  post-boost power-regen suppression.
- The on/off flag lives on a `UScriptGameInstanceSubsystem` singleton
  (`UInfiniteEnduranceStore::Get()`), shared between the ImGui checkbox that sets
  it and the world subsystem that reads it — the same store pattern Vanity
  Wardrobe uses.
- The menu entry is registered with `UImGuiPersistentMenuSubsystem`
  (`MenuPath = "Cheats|Infinite Endurance"`), so it appears in the same ImGui
  debug menu as the other cheat mods. The optional opener key is bound on a
  dedicated input actor (`BindKey` doesn't consume input, so it co-exists with
  the game's own bindings).

No game files are modified and nothing is written to your save.

## License

MIT — see [LICENSE](LICENSE).
