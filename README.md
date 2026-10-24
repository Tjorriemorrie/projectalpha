# projectalpha

Learning to write a game: an offline, single-player, first-person sci-fi extraction shooter in Godot. You are a
salvager who sends mind-controlled androids aboard derelict wrecks to fight their robot defenses from cover, loot what
is worth a slot and get out alive, or lose the android and everything it carried, all to find the cure for your wife
in time ([story](docs/game-design.md#3-world-and-story)). The build still has you as a clone waking up on your ship.

## Status

Features 001–013 in [docs/roadmap.md](docs/roadmap.md) are built: the MVP's loot-and-extract loop, the trader hub,
wreck variety, the system and star maps, and the inventory revamp (slots and stacks, quick moves, selling by click,
unloading). Greybox art throughout; nothing is saved yet.

## The loop

1. Wake up in the clone pod on your ship at the trader hub of a star system on the galaxy's outer ring, day 0 (the
   bar at the top shows bitcoin, hydrogen, antimatter and the day). Every item takes a square slot, stacked up to its
   stack size (data drives 5, gyroscopes 2, guns 1). Move loot between the **stash** (safe, no size limit) and your
   weapon slot (holstered on the ship, but it reloads), 2 ammo slots (clips only; reloads take from here), 2 pockets
   and a 6-slot backpack.
2. At the hub only, trade at the **trader terminal** beside the stash (**E**): click a stash stack to sell one (hold
   it to sell the stack), buy from the shop (twice an item's value, ±5%), FILL UP hydrogen (24 units, ₿5 each) or
   ORDER a full tank of antimatter (₿100 a unit, to COLLECT a day later). You start with ₿500 and 2 antimatter.
3. At the **cockpit console** (**E**) open the system map: point at a wreck for its type, place, robots and course,
   click it and FLY (a unit of hydrogen per map unit, keeping enough to get back; no time passes). Hold **E** on the
   airlock's outer door to board (a day; the wreck is gone after). **Q** switches to the star map: buy intel on a
   system within 10 ly (₿200), and from the hub hold JUMP for a second to jump there (a unit of antimatter a light
   year, a day, then a day's recharge). Systems keep what you left; easy wrecks turn up when you'd be stuck.
4. Fight the turrets and drones, pry open containers (3, 6 or 9 slots) and robot wreckage, and keep what is worth a
   slot (a spent clip with no room clatters onto the floor). Hold **E** on the airlock door for 3 s to return to the
   ship with everything carried; cycling is loud. On the summary **Q** unloads pockets and backpack into the stash.
5. Die and you lose everything carried, gun included. Only the first clone gets the basic kit (pistol, 2 clips);
   later ones wake empty-handed: arm from the stash, buy a gun, or board unarmed: the easiest wrecks always hold a
   gun. A run summary shows either way; press **E** to continue.

## Controls (keyboard and mouse)

| Action | Key | Action | Key |
|--------|-----|--------|-----|
| Move | WASD | Interact (trade, map; hold to pry, board, extract) | E |
| Sprint | Shift | Inventory | Tab |
| Crouch | Ctrl (hold) / C (toggle) | Reload | R |
| Peek (look only; lean standing, rise crouched) | Alt (hold) + mouse | Flashlight | F |
| Aim / aim out of cover | Right mouse | Shoot (hold to charge) | Left mouse |

In the inventory and the hub: drag a stack (left button), take half (right; the wheel takes one more or fewer), move
it across (shift-click or double-click); at the hub click a stash stack to sell one (hold: all of it), and click shop
items, FILL UP and ORDER or COLLECT. On the maps Q switches tabs, a click selects, FLY flies, BUY INTEL buys intel,
holding JUMP jumps. Tab, Esc or E close every screen. Gamepad: see [game-design.md](docs/game-design.md#controls).

## Tech stack, setup and run

- Godot 4.7.2 (GDScript, Jolt physics), GdUnit4 6.2.2 for tests (in `game/addons/`); Blender 5.2 for models
  (Python scripts in `art-source/models/`); placeholder sounds by Python in `art-source/audio/`.
- Godot must be callable as `godot` (here `godot.cmd` in `C:\Users\jacoj\godot\`, from PowerShell, not Git Bash). Run
  `godot --path game`: the main scene is the ship; the wreck layouts in `res://content/base/wrecks/` (rolling their
  own level) and the test levels in `res://scenes/test/` also run on their own, with the basic kit.

## Common commands (from the repository root, PowerShell)

| What | Command |
|------|---------|
| All tests | `godot --headless --path game -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -c -a res://tests` |
| One suite | same, with `-a res://tests/ship/ship_test.gd` |
| Re-import assets | `godot --headless --path game --import` |
| Build a model | `& "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --python art-source/models/<script>.py -- [--only <name>] [--preview <png>]` |
| Make sounds; check and draw the galaxy map; write the star systems | `$env:PYTHONIOENCODING="utf-8"; python art-source/audio/<script>.py`, `art-source/galaxy/galaxy_map.py [generate]` or `art-source/galaxy/systems.py` |

Reports go to `game/reports/` (ignored). No env vars or secrets. The system map's hydrogen-per-unit test is flaky.

## Project structure

| Path | What |
|------|------|
| `docs/` | Game design, galaxy and characters lore, technical design, roadmap and one spec per feature (`docs/features/NNN-name.md`) |
| `art-source/` | Model, sound and galaxy-map generating scripts (not imported by Godot) |
| `game/autoload/` | `ContentRegistry`, `ItemIcons`, `GameSession` (stash, wallet, fuel and antimatter order, day, star systems revealed and the route, the ship's place, hubs, clone number, docked wreck, kit, travel) |
| `game/content/base/` | The base content pack: sections, weapons, enemies, items, containers (with loot tables), wreck layouts, the 50 star systems, one folder each |
| `game/scenes/` | Framework code and scenes by feature: player, combat, weapons, enemies, loot, sections, wreck, ship, run, trade, galaxy, test |
| `game/ui/` | HUD, the inventory, trader hub, system map and star map screens (on a shared `MenuScreen` base), run summary card |
| `game/tests/` | GdUnit4 suites mirroring the folders they test |

Content is data-driven: definitions register by ID (`base:<name>`) from `content/<pack>/<kind>/<name>/`, as a mod's
would. Conventions: [docs/technical-design.md](docs/technical-design.md); workflow: [CLAUDE.md](CLAUDE.md).

## Gotchas

- Changing the scene (`change_scene_to_file`) takes the old scene out of the tree at once; code that triggers it
  must not touch the tree for the rest of that frame.
- Headless runs: windows are 64×64 (UI suites set 1280×720 and push real mouse events), the mouse can't be captured
  (tests check the player instead), and "ObjectDB instances were leaked" at exit while audio plays is harmless.
- `-s` scratch scripts compile before autoloads exist (keep autoload-dependent types untyped) and start before the
  content loads (set state up a few frames in). A new `class_name` needs `--import` before tests see it. The HUD's
  screens only get mouse events: the player reads the keys that work them (close, switch map tabs, unload).

## Known limitations and next steps

- The journey has no goal yet: no triangulation, her messages or countdown. A broke player at the hub with an empty
  hydrogen tank is stuck. No breakdown, crafting, saving, menus, gamepad, auto-sort or gear slots; prices, stacks,
  loot, robots and fuel are untuned. All are in [docs/roadmap.md](docs/roadmap.md).
