# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Client-side mods for **Witchspire**, an Unreal Engine 5 game that exposes the
in-game **"Hercules" AngelScript framework**. Each mod is a single self-contained
`.as` file (occasionally a few) that the game compiles at launch. Mods are written
in AngelScript against UE types and the game's own classes — there is **no build
system, no compiler, and no test suite in this repo**. The game itself is the
compiler and the only way to verify a change.

## Layout

```
Witchspire-Mods/
  <ModName>/
    Mods/<ModName>.as     # the AngelScript source the game loads
    scripts/deploy.ps1    # copies the source into the game's Mods folder
    README.md             # per-mod, user-facing documentation
  deploy-all.bat          # auto-discovers and runs every mod's deploy.ps1
```

`ReforgeGear/` is the exception (see below): multiple `.as` editions, several
deploy scripts, a `docs/` folder of HOWTOs, and a non-mod `SkipIntroMovies/`
config override.

## Deploying / "running"

There is no compile-and-run loop you can do from here. Deploying = copying the
`.as` file into the game's AngelScript mods folder and **fully restarting the
game** (AngelScript only recompiles on launch). Errors surface in the game's
`Hercules.log`, not in this repo.

- **All mods:** `deploy-all.bat` — auto-discovers every `*/scripts/deploy.ps1`
  plus ReforgeGear's GodForge edition.
- **One mod:** `./<ModName>/scripts/deploy.ps1`
- **Skip intro movies (not a mod):** `./ReforgeGear/scripts/skip-intro.ps1`
  (`-Revert` to undo).

The destination path is **hard-coded** as `$GameModsDir` near the top of each
deploy script (and in `ReforgeGear/scripts/_deploy-common.ps1`), defaulting to a
`Z:` Steam library:
`...\Witchspire\Hercules\Script\Mods`. If a deploy fails with "Game mods folder
not found", that path needs editing — it is not auto-detected.

## How a mod is structured (the recurring pattern)

Reading any one mod reveals the shape they all share. A typical mod is a handful
of `UCLASS()` types wired together:

- **Config namespace** — `namespace <Mod>Config { const ... }` at the top holds
  every user-tunable (hotkeys, multipliers, toggles). All knobs live here; the
  rest of the file references them. This is where to change behaviour.
- **Store** (`UScriptGameInstanceSubsystem`) — a singleton, reached via
  `U<Mod>Store::Get()`, holding shared on/off state and selections. Lives on the
  GameInstance so it **survives map/level reloads within a play session** but
  resets on a full quit. Holds data only, never spawned actors.
- **World subsystem / driver** (`UScriptWorldSubsystem`) — the engine. Overrides
  `ShouldCreateSubsystem` (gate to `EWorldType::Game || PIE`) and `Tick`. The
  Tick loop auto-enables Developer Mode, spawns the input actor, and does the
  per-frame work (refill bars, sweep for familiars, reconcile appearance, ...).
  Per-world runtime state (spawned actors) lives here, not in the Store.
- **ImGui panel** — a `UImGuiDebugMenuWindow` (implements `DrawContents`) plus a
  `UImGuiPersistentMenuSubsystem` that registers it via
  `default MenuPath = "Cheats|<Name>";`. This panel lives behind the game's
  **Developer Mode** (`CVar::Cheats::DeveloperMode`), which the driver
  auto-enables.
- **Input actor** (`AActor` with a `UInputComponent`) — spawned by the driver,
  binds the mod's hotkey with a **non-consuming** `BindKey(...)` so it coexists
  with the game's own controls, and toggles the ImGui menu.

### The "no Developer Mode" path: world interactables

Several mods also offer a way to act **without** the ImGui/Developer-Mode panel,
because the inventory UI freezes script input. The pattern: summon an `AActor`
carrying a `UInteractableComponent`, attach a `UInteraction` subclass
(`OnInteractServer`), and operate on the **item the player has selected in their
hotbar** (a script mod can't ship a clickable item picker outside Developer
Mode). Examples: ReforgeGear's Altar, VanityWardrobe's Wardrobe object. Labels
use `UTextRenderComponent` (works in the Shipping build — no UMG asset needed).

## Hard constraints of the AngelScript environment

These shape almost every design decision and explain a lot of the "why" in the
code:

- **Server-authoritative gameplay.** Attribute writes, rerolls, spawns, etc. only
  take effect on the host. Mods gate this logic behind `System::IsServer()` /
  `HasAuthority()` — they are single-player / listen-server (host) tools.
- **No custom assets or items.** Items are cooked, C++-backed assets; you cannot
  create one from script. Mods that need an "item" **borrow an existing one**
  (e.g. LegendaryTracker repurposes "Vesper's Locket"). New visuals reuse
  existing meshes/actors.
- **Can't hook arbitrary game functions.** You can't intercept a one-shot roll
  buried in the game's `BeginPlay`. Mods instead **poll on a timer** in the
  world subsystem's `Tick`, tracking what they've already processed (e.g.
  CelestialBoost sweeps for newly-spawned familiars and gives each one top-up
  roll). Reconcilers are written to be **idempotent** so they're safe to re-run
  every interval.
- **No save tampering.** Mods modify live runtime state only.
- **Shipping-build performance matters.** Per-frame label work is throttled (e.g.
  recompute at a fixed Hz, only call the expensive `UTextRenderComponent::SetText`
  when the text actually changed). See LingerChanceIndicator for the canonical
  example.

## Conventions

- **AngelScript-flavored syntax** you'll see throughout: `f"{x}"` string
  interpolation, `n"Name"` name literals, `UPROPERTY`/`UFUNCTION(BlueprintOverride)`
  macros, `TArray`/`TMap`/`FGameplayTag`, `Cast<T>(...)`, `Log(n"Tag", "msg")`
  (writes to `Hercules.log`).
- **ImGui input sharing.** While the menu is open, drivers call
  `ImGuiModule::SetKeyboardInputShared(!ImGui::IsKeyboardCaptured())` each Tick so
  gameplay keys still flow except when ImGui has focus (e.g. a search field).
- **Hotkey allocation is shared across mods** so they coexist; defaults in use:
  `F6` wardrobe summon, `F7` ImGui menu toggle, `F8` endurance / GodForge,
  `F9` reforge altar, `F10` debug gold, `K` legendary detector, `H` quick deposit.
  When adding a mod, pick a free key and note it in its Config namespace.
- **Naming.** Per-mod prefix on every type (`UVanityStore`, `AVanityInput`,
  `UVanityController`) so distinct mods never collide when installed together.
- Each `.as` file opens with a **long header comment** explaining the mechanism
  and *why* it works that way (which game systems it leans on). Preserve and
  extend these when editing — they are the primary design documentation.

## ReforgeGear specifics

ReforgeGear ships **multiple editions** that must not be installed simultaneously
(they'd define the same classes twice). `_deploy-common.ps1` enforces this:
installing one edition **removes the others** from the game folder. The editions:

- `ReforgeGear.as` — full (altar F9 + ImGui panel F7) — `deploy.ps1`
- `ReforgeAltar.as` — altar only (summon F9, reforge via Interact) — `deploy-altar.ps1`
- `ReforgeCheatGui.as` — ImGui panel only (F7) — `deploy-gui.ps1`

`GodForge.as` is a **separate mod** with entirely distinct class names and the F8
hotkey, so it installs **alongside** any Reforge edition — `deploy-godforge.ps1`
(also run by `deploy-all.bat`).

`SkipIntroMovies/Game.ini` is **not an AngelScript mod**: the startup movies play
via Unreal's MoviePlayer *before* mods load, so this is a user-layer config
override written to `%LOCALAPPDATA%\Hercules\Saved\Config\Windows` by
`skip-intro.ps1` (idempotent, written between managed markers so `-Revert` strips
only our block).
