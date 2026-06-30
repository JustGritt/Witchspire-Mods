# Witchspire — Skip Intro Movies

A tiny config tweak that boots **Witchspire** straight to the main menu by
skipping the startup movies — the **Unreal logo**, the **Envar studio logo**, and
the **Witchspire startup-loading** video. Handy when you relaunch the game a lot.

![type: QoL](https://img.shields.io/badge/type-QoL-blue) ![kind: config override](https://img.shields.io/badge/kind-config%20override-orange)

## Why this isn't a script mod

The startup logos are played by Unreal's engine **MoviePlayer** during launch —
*before* the AngelScript mod framework (Hercules) is even loaded. No `.as` mod can
run early enough to stop them. So instead this ships a small **config override**.

Unreal builds its settings from a layered hierarchy of `.ini` files, and the
**user layer** (`%LOCALAPPDATA%\Hercules\Saved\Config\Windows\Game.ini`) is applied
*last*, so it overrides the movie list baked into the packaged `DefaultGame.ini`:

```ini
[/Script/MoviePlayer.MoviePlayerSettings]
bWaitForMoviesToComplete=False
bMoviesAreSkippable=True
!StartupMovies=ClearArray
```

- `!StartupMovies=ClearArray` empties the startup-movie list the game set.
- `bWaitForMoviesToComplete=False` keeps boot from blocking on a movie.
- `bMoviesAreSkippable=True` lets you click through anything that still plays.

## Install

Run the apply script (it creates / merges the user `Game.ini` for you):

```powershell
./scripts/skip-intro.ps1
```

Then launch the game — it should go straight to the menu. Edit `$ConfigDir` at the
top of the script if your Steam library lives somewhere other than the default
`Z:\Program Files (x86)\Steam\...` path.

## Revert

```powershell
./scripts/skip-intro.ps1 -Revert
```

This removes **only** our managed block (it's written between clearly marked
`>>> ... <<<` lines). If you'd added other settings to that `Game.ini` yourself,
they're left intact; if the file held nothing but our override, it's deleted.

## Notes & limitations

- **Reversible & non-destructive.** It touches *only* a user-layer config file and
  never deletes or alters the game's movie assets, so a Steam **"Verify integrity
  of game files"** won't undo it (that check ignores the `Saved` folder).
- **Idempotent.** Re-running apply replaces our block rather than stacking copies.
- **Re-applying after a wipe:** if the game ever regenerates `Game.ini` and drops
  our section, just run the apply script again.
- **Config location:** the game's writable Saved dir is `%LOCALAPPDATA%\Hercules\Saved`
  (that's where `GameUserSettings.ini` lives), so the override goes in
  `%LOCALAPPDATA%\Hercules\Saved\Config\Windows\Game.ini`. The *install's*
  `Hercules\Saved` holds only SaveGames and is **not** read for config — putting a
  `Game.ini` there does nothing. If a future build relocates user config, point
  `$ConfigDir` (top of the script) at the folder that contains `GameUserSettings.ini`.
- **First-load screen:** clearing *all* startup movies also drops the Witchspire
  loading video, so the very first load may show a brief plain/black screen instead.
  Want to keep that one as load feedback? The alternative is renaming just the two
  logo `.mp4`s in `Hercules\Content\Movies\` — ask and I'll add that variant.
