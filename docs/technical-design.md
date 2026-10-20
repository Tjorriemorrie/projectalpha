# Technical Design Document

> How the game is built: conventions, architecture and decisions that apply across features.
> Fill sections in when a feature first needs them, not up front. Feature-specific technical
> notes belong in that feature's file in [features/](features/).
> Mark undecided items as **TBD**. Git history is the changelog.

## 1. Tools and versions

| Tool    | Version | Purpose |
|---------|---------|---------|
| Godot   | 4.7.2 (standard build, not .NET) | Game engine |
| GdUnit4 | 6.2.2 (needs Godot 4.5 or later), in `game/addons/gdUnit4/` | Automated tests |
| Blender | 5.2.2 LTS | 3D modelling, rigging, animation |
| Git     | | Version control |

Pin the Godot version and only upgrade deliberately, between features.

## 2. Language and coding conventions

- Scripting language: GDScript (best editor integration, and the simplest option for script mods).
  Edited in Godot's editor or in VS Code with the godot-tools extension.
- Style: follow the official Godot GDScript style guide (snake_case files, functions and variables; PascalCase class and node names).
- Use static typing in GDScript (`var speed: float = 5.0`).
- Logging goes through `Log` (`game/scripts/log.gd`): `Log.info`, `Log.warning` and `Log.error` only, never a
  DEBUG level. Every message starts with its module's emoji, used consistently (🏃 player, 🛗 elevators,
  🧩 wreck assembly, 🚪 doors, 🖐️ interactables, 📦 content registry).
  Code that runs every frame logs only when something changes (a state change, a step), never every frame.

## 3. Project structure

Proposed layout (adjust as the project grows):

```text
projectalpha/
├── docs/                  # Design documents
├── art-source/            # Blender .blend files, asset-generating scripts and other source art (not imported by Godot)
└── game/                  # Godot project root (project.godot lives here)
    ├── assets/            # Shared assets that belong to no single piece of content
    │   ├── models/        # Exported .glb files from Blender
    │   ├── textures/
    │   ├── shaders/       # Shared shaders (the greybox grid)
    │   ├── audio/
    │   └── fonts/
    ├── content/           # Content packs; base/ is the base game (see Content and modding)
    │   └── base/
    │       └── sections/  # One self-contained folder per kit section
    ├── scenes/            # .tscn scenes and framework code, grouped by feature (player, sections, wreck, test)
    ├── scripts/           # Shared / standalone scripts
    ├── ui/
    ├── autoload/          # Global singletons
    ├── addons/            # Third-party plugins (GdUnit4)
    └── tests/             # GdUnit4 test suites, mirroring the folders they test
```

## 4. Architecture

### Scene organization

- Main scene: `res://scenes/wreck/small_wreck.tscn`, the wreck built by hand in 002.
- `res://scenes/test/player_test.tscn` stays as the greybox test level for the player controller's tests.
- TBD: how levels are loaded, scene transitions.

### Global singletons (autoloads)

| Autoload | Responsibility |
|----------|----------------|
| ContentRegistry | Discovers and registers all content definitions by ID (see [Content and modding](#content-and-modding)) |

### Communication between nodes

- Prefer signals for child-to-parent and decoupled communication ("call down, signal up").
- TBD: event bus or not.

### Game state and saving

TBD. What is saved, file format, where (`user://`).

## 5. Systems

One subsection per system as it is designed.

### Content and modding

Decided up front, because adding it later would mean rewriting every content system.

- **Data-driven content.** Items, weapons, enemies, ship sections and blueprints are self-contained definitions
  (Godot `Resource`s and scenes). Each one references its own model, scripts and sounds, and declares its
  breakdown components and crafting recipe. Gameplay code never hard-codes a specific piece of content.
- **Content registry (autoload).** At startup it scans the content folders and registers every definition by ID.
  All systems look content up through the registry.
- **The base game is the first mod.** Built-in content lives in a content folder and loads through exactly
  the same path that external mods will use.
- **Ship assembly.** Sections are scenes with connection points (sockets), plus enemy-spawn and loot markers.
  A blueprint describes how a ship class assembles sections. A mission populates the markers according to difficulty.
- **External mods (later).** Load content packs at runtime (`ProjectSettings.load_resource_pack`, or the
  community Godot Mod Loader) and register them in the same registry. Steam Workshop via GodotSteam after that.
  Script mods run arbitrary code, which is acceptable for an offline single-player game.

Settled in [003](features/003-content-registry.md):

- **Packs and folders.** Each folder in `game/content/` is a pack; the base game is `base`. Inside a pack,
  content is grouped by kind, and each piece of content is self-contained in its own folder,
  `content/<pack>/<kind>/<name>/`, holding exactly one definition (`<name>.tres`) next to its own scene,
  scripts, model and sounds. Framework code and parts shared by many pieces stay outside `content/`.
- **IDs.** A definition registers as `<pack>:<name>`, taken from its path (`content/base/sections/airlock/` is
  `base:airlock`). IDs are never typed into a definition. The kind folder is not part of the ID, so names are
  unique within a pack across all kinds.
- **Definitions.** Every definition extends `ContentDefinition` (`id` and `pack`, filled in by the registry, and
  `display_name`). Each kind of content is a subclass, such as `SectionDefinition`; a new kind needs no change
  to the registry. Definitions are small and load at startup; the scenes, models and sounds they use are
  referenced by path (`@export_file`) and only load when used. `ContentDefinition.get_problems()` checks a
  definition cheaply (files exist, without loading them), and subclasses add their own checks.
- **Registry.** The `ContentRegistry` autoload scans `res://content` before the first scene loads, with
  `ResourceLoader.list_directory`, which also sees the remapped resources of an exported build.
  `get_definition(id)` looks one up (an unknown ID logs an error and returns null), and `get_all(kind)` lists
  one kind sorted by ID. Duplicate IDs, content folders with zero or several definitions, and definitions with
  problems are logged as errors, kept in `ContentRegistry.errors` and skipped; the rest still loads.
  `load_content(root)` takes the folder of packs, so tests run a fresh registry on fixture packs.

### Player controller

Built in [001](features/001-player-controller.md). A `CharacterBody3D` with its origin at the feet and a
cylinder collision shape. Its sizes are constraints for every section and prop:

| Measure | Value | Consequence for level design |
|---------|-------|------------------------------|
| Standing height | 1.8 m (eyes at 1.65 m) | Doorways at least 1.9 m high |
| Crouched height | 1.0 m (eyes at 0.85 m) | Vents and crawl spaces at least 1.1 m high |
| Width | 0.6 m (radius 0.3 m) | Doorways and vents at least 0.7 m wide |
| Step height | 0.35 m | Anything up to 0.35 m is stepped onto; taller blocks and can be cover |

- Decks are flat and connected only by elevators (no stairs, ramps or ladders). Elevators are
  `AnimatableBody3D`s moved in `_physics_process`, which the player rides automatically. A descending elevator
  pushes a player standing beneath it through the floor, so elevator sections must keep the shaft closed
  (doors) whenever the platform isn't there; the controller doesn't guard against it.
- Anything meant to be stepped onto (bodies, broken robots) needs flat-topped collision, such as a box proxy.
- Step-up and step-down are done by the controller itself with `test_move`, because Godot's floor snap fails
  while the body still touches the edge it just walked off.

### Camera

- Physics interpolation is on, so movement is smooth on screens faster than the 60 Hz physics tick.
- The player camera is a top-level `Camera3D` placed every rendered frame on the interpolated body
  (`get_global_transform_interpolated()`), while its look direction comes straight from the latest mouse input,
  so aiming has no interpolation delay. Sudden height changes (steps) call `reset_physics_interpolation()` and are
  smoothed by the camera instead.
- Field of view: 90° horizontal at 16:9, stored as the matching vertical FOV with `KEEP_HEIGHT`, so wider screens
  see more at the sides.

### Input

Define all actions in the Godot Input Map; never hard-code keys in scripts. Keys are bound by physical key code,
so WASD keeps its position on other keyboard layouts.

| Action | Keyboard / mouse |
|--------|------------------|
| `move_forward`, `move_back`, `move_left`, `move_right` | W, S, A, D |
| `sprint` | Shift |
| `crouch_hold` | Ctrl |
| `crouch_toggle` | C |
| `pause` | Esc (releases the mouse until there is a pause menu) |
| `interact` | E |
| `flashlight` | F |

Prompts show the bound key by reading the Input Map (`as_text_physical_keycode()`), never a hard-coded letter.

Gamepad bindings are allocated in the Controls table in [game-design.md](game-design.md#controls), but are not in
the Input Map yet: gamepad support is wired after the MVP.

### Physics and collision layers

Physics engine: Jolt, at the default 60 ticks per second.

| Layer | Name | Used by |
|-------|------|---------|
| 1     | world  | Static level geometry, door panels, elevator platforms. Blocks movement, sight and the interact ray |
| 2     | player | The player body (collides with `world`) |
| 3     | interactable | `Interactable` areas (buttons), found by the player's interact ray |

Trigger areas (door proximity and doorways, the elevator's "aboard" area) sit on no layer and mask `player`.

### Wreck sections and assembly

Built in [002](features/002-wreck-section-kit.md). Wrecks are assembled from section scenes on a grid.

- **Grid.** Cells are 4 × 4 m with their centres on multiples of 4 m in x and z; deck *n* has its floor at
  y = 4n. A section's origin is the centre of its footprint at the floor of its lowest deck, and `Section.size`
  is its footprint in cells (x, decks, z). Kit sizes: corridors 2 m wide and 2.5 m tall inside, rooms 3 m tall,
  doorways 1.2 × 2.2 m, vents 1.2 × 1.2 m, walls and slabs 0.2 m thick.
- **Sockets** (`Socket`, a `Marker3D`) sit at the centre of a cell edge at floor level and face out of the
  section along their local −Z. Their kind decides what they join:

  | Kind | What it is | Joins | Not joined |
  |------|------------|-------|------------|
  | `CORRIDOR` | An open corridor end | `CORRIDOR` (open), `WALL` (doorway) | Error |
  | `VENT` | An open duct end | `VENT` (open), `WALL` (vent mouth) | Error |
  | `WALL` | A wall that can open up; `accepts_corridor` off means vents only | `CORRIDOR` or `VENT` | Solid wall, or an error when `required` |

- A wall socket builds its own wall in code (`CSGBox3D`s), so its opening can change at load. It is a `@tool`
  script, so sections show solid walls in the editor. A doorway gets a `SlidingDoor`; a wall set back from its
  socket (`wall_inset`, as on corridor sides) gets a short duct to the cell edge when a vent joins it.
- **Assembly.** `Wreck._ready()` collects its sections' sockets, joins every pair at the same position that
  face each other, applies the openings, and then calls `Section.assembled()`. The rules and checks live in the
  node-free `WreckAssembly`: loose ends, mismatched kinds, sockets off the grid and overlapping sections are
  logged as errors and kept in `Wreck.assembly_errors`. A section whose scene is not a registered
  `SectionDefinition` is an assembly error too.
- **Markers.** `SectionMarker`s (enemy or loot) mark where a mission may place things (006, 007).
- **Adding a section:** create `content/base/sections/<name>/` with the scene and a `SectionDefinition`
  (`<name>.tres`) pointing at it. Fill whole cells, put a socket at the centre of every edge that can connect,
  and keep geometry inside the footprint (wall sockets build the walls on their edges). Static parts go under one
  `CSGCombiner3D` with collision. Shared parts (doors, lamps, buttons) and materials stay in `scenes/sections/`.

### Doors and elevators

- `SlidingDoor`: an `AnimatableBody3D` panel that slides sideways into the wall. A doorway area holds a closing
  door open while the player stands in it, but never opens a closed one. Automatic doors also have a proximity
  area (1.5 m either side) and close 2 s after the player leaves.
- `Elevator` (a `Section` spanning two decks): call buttons on each deck, a send button on the platform, doors
  driven by the elevator that only open at the deck where the platform is, and a `dinged(deck, sound_position)`
  signal on arrival for enemy hearing later.

### Interaction and HUD

- `Interactable` is an `Area3D` on the `interactable` layer with a `prompt` and an `interacted` signal.
  The player casts a 2 m ray from the camera every physics frame against `world` and `interactable`, so walls
  block it, and calls `interact()` when `interact` is pressed.
- The HUD (`game/ui/hud.tscn`, owned by the player scene) shows a centre dot and the prompt as a key cap plus
  action. It uses the Windows system font Bahnschrift (DIN-style signage), falling back to Godot's default font.

### Lighting

- The wreck's `Environment` has a black background, a very low blue-grey ambient light, filmic tonemapping and a
  little glow. There is no sun.
- Lamps are shadow-casting `SpotLight3D`s pointing down, so walls stop their light and nothing leaks between
  sections. Ceiling lamps are cold white; emergency lamps (same `CeilingLamp` script) are red. Whether a lamp
  flickers is seeded from its position, so it is the same on every run.
- The flashlight is a shadow-casting `SpotLight3D` on the player camera, toggled by `flashlight`.

## 6. Asset pipeline (Blender → Godot)

- **Who makes the assets:** mostly Claude, by writing Blender Python scripts that build low-poly models
  procedurally. The scripts are the source of truth and live in `art-source/`. Each one generates and exports a `.glb`.
  Run them headless: `blender --background --python <script>`. Blender must be on the PATH.
- **Checking the results:** each script can also render a preview PNG for Claude to inspect. The developer
  reviews the models in-game.
- **What this works well for:** hard-surface sci-fi such as ship sections, props, containers, weapons, turrets
  and drones. Rigged, animated organic characters (humans and later enemy types) are much harder to script.
  Revisit asset packs or other sources for those when they come up.
- **Live editing (optional, later):** a Blender MCP server (e.g. blender-mcp by ahujasid) can be added in the art
  phase if headless scripts aren't enough.

- Export format: glTF binary (`.glb`) into `game/assets/models/`.
- Units: 1 Blender unit = 1 metre; apply scale and rotation before export.
- Orientation: models face -Y in Blender (toward the Front view camera). This arrives as +Z in Godot, which is Godot's model front (`Vector3.MODEL_FRONT`).
- Naming: TBD (e.g. `prop_crate.glb`, `char_player.glb`).
- Animations: TBD (actions naming, NLA usage, root motion or not).
- Collision: TBD (Godot import hints such as `-col` / `-colonly` suffixes, or collision built in Godot).
- Textures: TBD (resolution budget, PBR or not).
- Placeholder sounds are generated the same way, by Python scripts using only the standard library in
  `art-source/audio/`, which write `.wav` files into the content folder of the piece of content they belong to
  (or `game/assets/audio/` for shared sounds). Run them from the repository root, e.g.
  `python art-source/audio/elevator_ding.py`.

## 7. Performance targets

| Metric | Target |
|--------|--------|
| Frame rate | 60 FPS |
| Minimum hardware | TBD (decide later, once there is something to profile) |
| Triangle budget per character / scene | TBD |

## 8. Build and release

- Export presets: TBD
- Versioning scheme: TBD

## 9. Testing

- **Automated tests:** GdUnit4, for game logic that can be checked without playing (e.g. inventory fitting,
  crafting and breakdown recipes, the content registry). Run headless from the command line.
  - Run all tests from the repository root (PowerShell, `godot` on the PATH):
    `godot --headless --path game -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -c -a res://tests`
  - Reports are written to `game/reports/` (ignored by git).
  - Keep decisions in node-free classes (like `MovementRules`) so they can be unit tested. Behaviour that needs
    physics is tested by loading a scene with `scene_runner` and pressing actions with `Input.action_press`.
    `Input.action_press` changes action state without sending input events, so gameplay input that tests
    drive is read with `Input` queries in `_physics_process`, not from `_unhandled_input`.
- **Manual playtests:** feel, visuals and audio. Each feature's "Done when" includes a playtest in the running game.

## 10. Technical risks and open questions

- **Scope.** One developer working on an extraction shooter with crafting, a star map and procedural ships. Mitigate by
  sticking to the MVP cut in the roadmap and the one-feature-at-a-time rule.
- **Content architecture.** If the registry and definition format are wrong, every later system pays for it.
  003 settled and tested the registry with sections only; the first kinds with gameplay data (weapon, robot,
  items in 005–007) are the real test of the definition format.
- **Section assembly.** Sections must connect cleanly (sockets, alignment, no gaps), and navigation and lighting
  must work across the seams. 002 proved the sockets, alignment and lighting by hand; navigation across seams is
  still open and gets settled with the first enemy that moves (006).
- **Scripted art.** Hard-surface assets suit Blender scripting, but animated characters may need another source.
- **Free peek and hit exposure.** The peek/aim exposure model must feel fair. Settle it by playtesting feature 004.
- Minimum hardware is TBD (see [Performance targets](#7-performance-targets)).
