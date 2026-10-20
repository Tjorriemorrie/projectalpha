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
  DEBUG level. Every message starts with its module's emoji, used consistently (🏃 player, 🛗 elevators).
  Code that runs every frame logs only when something changes (a state change, a step), never every frame.

## 3. Project structure

Proposed layout (adjust as the project grows):

```text
projectalpha/
├── docs/                  # Design documents
├── art-source/            # Blender .blend files and other source art (not imported by Godot)
└── game/                  # Godot project root (project.godot lives here)
    ├── assets/
    │   ├── models/        # Exported .glb files from Blender
    │   ├── textures/
    │   ├── audio/
    │   └── fonts/
    ├── scenes/            # .tscn scenes, grouped by feature
    ├── scripts/           # Shared / standalone scripts
    ├── ui/
    ├── autoload/          # Global singletons
    ├── addons/            # Third-party plugins (GdUnit4)
    └── tests/             # GdUnit4 test suites, mirroring the folders they test
```

## 4. Architecture

### Scene organization

- Main scene: `res://scenes/test/player_test.tscn`, a greybox test level, until 002 provides a real wreck.
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
- Details (definition format, folder layout, IDs) are TBD, to be settled in the first feature that needs them.

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

Gamepad bindings are allocated in the Controls table in [game-design.md](game-design.md#controls), but are not in
the Input Map yet: gamepad support is wired after the MVP.

### Physics and collision layers

Physics engine: Jolt, at the default 60 ticks per second.

| Layer | Name | Used by |
|-------|------|---------|
| 1     | world  | Static level geometry, elevators |
| 2     | player | The player body (collides with `world`) |

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
  Settle the details in feature 003 and test them with GdUnit4.
- **Section assembly.** Sections must connect cleanly (sockets, alignment, no gaps), and navigation and lighting
  must work across the seams. Feature 002 proves this by hand before any generator is written.
- **Scripted art.** Hard-surface assets suit Blender scripting, but animated characters may need another source.
- **Free peek and hit exposure.** The peek/aim exposure model must feel fair. Settle it by playtesting feature 004.
- Minimum hardware is TBD (see [Performance targets](#7-performance-targets)).
