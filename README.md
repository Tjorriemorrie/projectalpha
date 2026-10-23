# projectalpha

Learning to write a game: an offline, single-player, first-person sci-fi extraction shooter in Godot. You are a
salvager who sends mind-controlled androids aboard derelict wrecks to fight their robot defenses from cover, loot into
a grid inventory and get out alive, or lose the android and everything it carried, all to find the cure for your wife
in time ([story](docs/game-design.md#3-world-and-story)). The build still has you as a clone waking up on your ship.

## Status

The MVP (features 001–008 in [docs/roadmap.md](docs/roadmap.md)) is built: player controller, wreck section kit,
content registry, free peek and cover, laser pistol and health, robot turrets and drones, loot containers and the grid
inventory, and the extraction, death and clone loop. So are 009, the trader hub (bitcoin wallet, trading, guns in a
weapon slot), 010, wreck variety (three layouts, robots and loot rolled to a hidden difficulty), and 011, the system
map (a star system's wrecks, flying on hydrogen, the day counter). Placeholder (greybox) art throughout. Nothing is
saved yet: quitting starts a new game.

## The loop

1. Wake up in the clone pod on your ship, at the trader hub of a random star system on day 0; the HUD shows your
   bitcoin, hydrogen and the day. Move loot between the **stash** (safe, 10×8) and your weapon slot (the gun in
   hand; holstered on the ship, but it reloads), pockets and backpack (at risk).
2. At the hub only, trade at the **trader terminal** beside the stash (**E**): drag loot into the sell crate and press
   SELL, click a shop item to buy one, or FILL UP the hydrogen tank (24 units, ₿5 each). You start with ₿500 and a
   full tank. Selling pays an item's value and buying costs twice it, give or take 5% per hub.
3. At the **cockpit console** (**E**) open the system map: point at a wreck for its type, place, robots and course,
   click it and FLY (a unit of hydrogen per map unit; the tank must also get you back to the hub). Flying takes no
   time. Then hold **E** on the airlock's outer door to board it. Boarding takes a day, and the wreck is gone after.
4. Fight the turrets and drones, pry open containers and robot wreckage, and pack what is worth the space.
5. Hold **E** on the wreck's airlock door for 3 s to return to the ship: you keep everything carried. Cycling is
   loud, so robots come to look.
6. Die and you lose everything carried, gun included. Only the first clone gets the basic kit (pistol, 2 clips in
   the pockets); later ones wake empty-handed: arm from the stash, buy a gun, or board unarmed: the easiest wrecks
   always hold a gun. A run summary shows either way; press **E** to continue.

## Controls (keyboard and mouse)

| Action | Key | Action | Key |
|--------|-----|--------|-----|
| Move | WASD | Interact (trade, map; hold to pry, board, extract) | E |
| Sprint | Shift | Inventory | Tab |
| Crouch | Ctrl (hold) / C (toggle) | Reload | R |
| Peek (look only) | Alt (hold) + mouse | Flashlight | F |
| Aim / aim out of cover | Right mouse | Shoot (hold to charge) | Left mouse |

In the inventory and the hub, drag with the left button, rotate with the right, mirror with the middle button or
wheel; in the hub, a left click on a shop item buys one, on SELL sells the crate and on FILL UP refuels; on the map,
a left click selects a wreck or the hub and on FLY flies there. Tab, Esc or E close every screen. Gamepad
bindings are planned in [docs/game-design.md](docs/game-design.md#controls) but not wired yet.

## Tech stack, setup and run

- Godot 4.7.2 (standard build, GDScript, Jolt physics), GdUnit4 6.2.2 for tests (in `game/addons/`).
- Blender 5.2 for models (Python scripts in `art-source/models/`); placeholder sounds by Python in `art-source/audio/`.
- Godot must be callable as `godot` (on this machine `godot.cmd` in `C:\Users\jacoj\godot\`, which works from
  PowerShell but not Git Bash). Open `game/project.godot` in the editor, or run `godot --path game`.
- The main scene is the ship (`res://scenes/ship/ship.tscn`); the wreck layouts in `res://content/base/wrecks/`
  (rolling their own level) and the test levels in `res://scenes/test/` also run on their own, with the basic kit.

## Common commands (from the repository root, PowerShell)

| What | Command |
|------|---------|
| All tests | `godot --headless --path game -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -c -a res://tests` |
| One suite | same, with `-a res://tests/ship/ship_test.gd` |
| Re-import assets | `godot --headless --path game --import` |
| Build a model | `& "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --python art-source/models/<script>.py -- [--only <name>] [--preview <png>]` |
| Make sounds; check and draw the galaxy map; write the star systems | `$env:PYTHONIOENCODING="utf-8"; python art-source/audio/<script>.py`, `art-source/galaxy/galaxy_map.py [generate]` or `art-source/galaxy/systems.py` |

Test reports go to `game/reports/` (ignored by git). No environment variables or secrets are needed.

## Project structure

| Path | What |
|------|------|
| `docs/` | Game design, galaxy and characters lore, technical design, roadmap and one spec per feature (`docs/features/NNN-name.md`) |
| `art-source/` | Model, sound and galaxy-map generating scripts (not imported by Godot) |
| `game/autoload/` | `ContentRegistry`, `ItemIcons`, `GameSession` (stash, wallet, hydrogen, day, star system and ship's place in it, trader hub, clone number, docked wreck, kit, travel) |
| `game/content/base/` | The base content pack: sections, weapons, enemies, items, containers (with loot tables), wreck layouts, the 50 star systems, one folder each |
| `game/scenes/` | Framework code and scenes by feature: player, combat, weapons, enemies, loot, sections, wreck, ship, run, trade, galaxy, test |
| `game/ui/` | HUD, the inventory, trader hub and system map screens (on a shared `MenuScreen` base), run summary card |
| `game/tests/` | GdUnit4 suites mirroring the folders they test |

All content is data-driven: definitions register by ID (`base:<name>`) from `content/<pack>/<kind>/<name>/`, and the
base game loads exactly like a future mod. Conventions and architecture are in
[docs/technical-design.md](docs/technical-design.md); the workflow for features is in [CLAUDE.md](CLAUDE.md).

## Gotchas

- Changing the scene (`change_scene_to_file`) takes the old scene out of the tree at once; code that triggers it
  must not touch the tree for the rest of that frame.
- Headless runs: windows are 64×64 (UI suites set 1280×720 and push real mouse events), the mouse can't be captured
  (tests check the player instead), and "ObjectDB instances were leaked" at exit while audio plays is harmless.
- `-s` scratch scripts compile before autoloads exist: keep variables of autoload-dependent types untyped.

## Known limitations and next steps

- One star system per game (no star map or jumping until 012): once its 6–8 wrecks are boarded nothing is left, and a
  broke player at the hub with an empty tank is stuck. No breakdown, crafting, saving, menus or gamepad; the 10×8 stash
  refuses buys when full; prices, loot, robots and hydrogen are untuned. All are in [docs/roadmap.md](docs/roadmap.md).
