# projectalpha

Learning to write a game: an offline, single-player, first-person sci-fi extraction shooter in Godot. You are a
cloned salvager who boards derelict wrecks, fights their robot defenses from cover, loots into a grid inventory and
gets out alive, or dies, loses everything carried and wakes up as the next clone on your ship.

## Status

The MVP (features 001–008 in [docs/roadmap.md](docs/roadmap.md)) is built: player controller, wreck section kit,
content registry, free peek and cover, laser pistol and health, robot turrets and drones, loot containers and the grid
inventory, and the extraction, death and clone loop. Placeholder (greybox) art throughout.

## The loop

1. Wake up in the clone pod on your ship. Move loot between the **stash** (safe, 10×8) and your pockets and
   backpack (at risk). Your pistol is holstered on the ship, but you can reload.
2. Hold **E** on the airlock's outer door to board the small wreck (it loads fresh every run).
3. Fight the turrets and drones, pry open containers and robot wreckage, and pack what is worth the space.
4. Hold **E** on the wreck's airlock door for 3 s to return to the ship: you keep everything carried. Cycling is
   loud, so robots come to look.
5. Die and you lose everything carried; the next clone wakes with the basic kit (pistol, loaded clip, 2 clips in the
   pockets). A run summary shows either way; press **E** to continue.

Nothing is saved yet: quitting starts a new game.

## Controls (keyboard and mouse)

| Action | Key | Action | Key |
|--------|-----|--------|-----|
| Move | WASD | Interact (hold to pry, board, extract) | E |
| Sprint | Shift | Inventory | Tab |
| Crouch | Ctrl (hold) / C (toggle) | Reload | R |
| Peek (look only) | Alt (hold) + mouse | Flashlight | F |
| Aim / aim out of cover | Right mouse | Shoot (hold to charge) | Left mouse |

In the inventory, drag with the left button, rotate with the right, mirror with the middle button or wheel. Gamepad
bindings are planned in [docs/game-design.md](docs/game-design.md#controls) but not wired yet.

## Tech stack

- Godot 4.7.2 (standard build, GDScript, Jolt physics), GdUnit4 6.2.2 for tests (in `game/addons/`).
- Blender 5.2 for models, built by Python scripts in `art-source/models/`; placeholder sounds by standard-library
  Python scripts in `art-source/audio/`.

## Setup and run

- Godot must be callable as `godot` (on this machine `godot.cmd` in `C:\Users\jacoj\godot\`, which works from
  PowerShell but not Git Bash). Open `game/project.godot` in the editor, or run `godot --path game`.
- The main scene is the ship (`res://scenes/ship/ship.tscn`); `res://scenes/wreck/small_wreck.tscn` and the test
  levels in `res://scenes/test/` also run on their own, with the player holding the basic kit.

## Common commands (from the repository root, PowerShell)

| What | Command |
|------|---------|
| All tests | `godot --headless --path game -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -c -a res://tests` |
| One suite | same, with `-a res://tests/ship/ship_test.gd` |
| Re-import assets | `godot --headless --path game --import` |
| Build a model | `& "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --python art-source/models/<script>.py -- [--only <name>] [--preview <png>]` |
| Make sounds | `$env:PYTHONIOENCODING="utf-8"; python art-source/audio/<script>.py` |

Test reports go to `game/reports/` (ignored by git). No environment variables or secrets are needed.

## Project structure

| Path | What |
|------|------|
| `docs/` | Game design, technical design, roadmap and one spec per feature (`docs/features/NNN-name.md`) |
| `art-source/` | Model and sound generating scripts (not imported by Godot) |
| `game/autoload/` | `ContentRegistry`, `ItemIcons`, `GameSession` (stash, clone number, kit handover, travel) |
| `game/content/base/` | The base content pack: sections, weapons, enemies, items, containers, one folder each |
| `game/scenes/` | Framework code and scenes by feature: player, combat, weapons, enemies, loot, sections, wreck, ship, run, test |
| `game/ui/` | HUD, inventory screen, run summary card |
| `game/tests/` | GdUnit4 suites mirroring the folders they test |

All content is data-driven: definitions register by ID (`base:<name>`) from `content/<pack>/<kind>/<name>/`, and the
base game loads exactly like a future mod. Conventions and architecture are in
[docs/technical-design.md](docs/technical-design.md); the workflow for features is in [CLAUDE.md](CLAUDE.md).

## Gotchas

- Changing the scene (`change_scene_to_file`) takes the old scene out of the tree at once; code that triggers it
  must not touch the tree for the rest of that frame.
- Headless runs print "ObjectDB instances were leaked" at exit when audio is still playing; it is harmless.
- Headless test windows are 64×64: UI suites set the root to 1280×720 and push real mouse events through the
  viewport.
- `-s` scratch scripts compile before autoloads exist, so they must keep variables of autoload-dependent types
  untyped.

## Known limitations and next steps

- One wreck with fixed robots and loot; no star map, travel, trader, breakdown or crafting yet.
- No saving, menus or gamepad support; see the idea backlog in [docs/roadmap.md](docs/roadmap.md).
