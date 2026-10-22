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
  🧩 wreck assembly and navigation, 🚪 doors, 🖐️ interactables, 📦 content registry, 👁️ debug exposure watchers,
  🔫 weapons, 🩸 health and damage, 🎯 shooting targets, 🤖 robots, 🔊 noise and hearing, 🎵 combat music, 🎒 inventory, loot and items,
  🧬 the game session, travel and the wallet, 🚀 the ship, 💡 lamps, 💰 the trader hub's screen).
  Code that runs every frame logs only when something changes (a state change, a step), never every frame.

## 3. Project structure

Proposed layout (adjust as the project grows):

```text
projectalpha/
├── docs/                  # Design documents
├── art-source/            # Asset-generating scripts (models/, audio/) and other source art (not imported by Godot)
└── game/                  # Godot project root (project.godot lives here)
    ├── assets/            # Shared assets that belong to no single piece of content
    │   ├── models/        # Exported .glb files from Blender
    │   ├── textures/
    │   ├── shaders/       # Shared shaders (the greybox grid)
    │   ├── audio/
    │   └── fonts/
    ├── content/           # Content packs; base/ is the base game (see Content and modding)
    │   └── base/
    │       ├── sections/  # One self-contained folder per kit section
    │       ├── weapons/   # One self-contained folder per weapon (definition, viewmodel, model, sounds)
    │       ├── enemies/   # One self-contained folder per enemy (definition, scene, model, own sounds)
    │       ├── items/     # One self-contained folder per item (definition, model)
    │       └── containers/ # One self-contained folder per loot container (definition, scene, model)
    ├── scenes/            # .tscn scenes and framework code, grouped by feature (player, combat, weapons,
    │                      # enemies, loot, sections, wreck, ship, run, trade, test)
    ├── scripts/           # Shared / standalone scripts
    ├── ui/
    ├── autoload/          # Global singletons
    ├── addons/            # Third-party plugins (GdUnit4)
    └── tests/             # GdUnit4 test suites, mirroring the folders they test
```

## 4. Architecture

### Scene organization

- Main scene: `res://scenes/ship/ship.tscn`, the player's ship (008), where the game starts with the first clone
  waking up. `res://scenes/wreck/small_wreck.tscn` is the wreck built by hand in 002, with two turrets and two
  drones since 006 and six loot containers since 007; every run boards it. Either can be run on its own: the player
  then starts with the basic kit.
- `res://scenes/test/player_test.tscn` stays as the greybox test level for the player controller's tests. Its
  south-east corner is a cover area (a 1 m crate, a pillar, a doorframe) with debug exposure watchers (004), which
  also shoot at the player (005). Four shooting targets stand north of the start (005).
- `res://scenes/test/loot_test.tscn` is the loot test level (007): a small one-deck wreck with no robots, a locker
  and a supply crate in a room, and a small case in the entrance stub and in a vent.
- `res://scenes/test/robot_test.tscn` is the robots' test level (006): a small one-deck wreck with a turret and a
  drone that show their state above them.
- Levels change with `SceneTree.change_scene_to_file()`, through `GameSession` only. The ship and the wreck are
  separate scenes, each with its own player instance; what the player carries goes across in the session (008).
  Changing the scene takes the old one out of the tree at once, so code that triggers it must stop for that frame.

### Global singletons (autoloads)

| Autoload | Responsibility |
|----------|----------------|
| ContentRegistry | Discovers and registers all content definitions by ID (see [Content and modding](#content-and-modding)) |
| ItemIcons | Renders every registered item's grid icon from its model at startup (see [Loot and inventory](#loot-and-inventory)) |
| GameSession | The session between scenes: the stash, the wallet, the system's trader hub and its sell crate, the clone number, the kit handed over, run summaries and travel (see [Runs, the ship and the session](#runs-the-ship-and-the-session) and [Trading](#trading)) |

### Communication between nodes

- Prefer signals for child-to-parent and decoupled communication ("call down, signal up").
- TBD: event bus or not.

### Game state and saving

The session lives in memory in `GameSession` (008): the stash, the clone number, the runs boarded and the kit
handed between scenes, and since 009 the wallet, the hub's price seed and the sell crate. Nothing is saved yet, so
quitting starts a new game. TBD: what is saved, file format, where
(`user://`).

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
- **Kinds so far.** `SectionDefinition` (003), `WeaponDefinition` (005), `EnemyDefinition` (006), and
  `ItemDefinition` and `ContainerDefinition` (007). A weapon definition holds all its numbers (damage, heat, charge,
  kick, spread, zoom, reload and raise times) and the items it loads and unloads, so a new weapon is a new folder.
  Since 009 `WeaponDefinition` extends `ItemDefinition`: a gun is an item (shape, value, a model lying flat), so it
  registers once and `get_all(ItemDefinition)` lists it with the other items.
  An enemy definition holds its scene, the marker mount it needs, the robot brain's numbers and the salvage in its
  wreckage; how a kind moves is exported on its scene. An item definition holds its shape (rows of text), value and
  model, so a new item is a folder with a `.tres` and a `.glb` and no icon to draw. None needed a change to the
  registry.
- **Content referring to content** does it by ID (`"base:thermal_clip"`), looked up through the registry when it is
  used, never when it registers, so the order packs and kinds load in doesn't matter.

### Player controller

Built in [001](features/001-player-controller.md). A `CharacterBody3D` with its origin at the feet and a
cylinder collision shape. Its sizes are constraints for every section and prop:

| Measure | Value | Consequence for level design |
|---------|-------|------------------------------|
| Standing height | 1.8 m (eyes at 1.65 m) | Doorways at least 1.9 m high |
| Crouched height | 1.0 m (eyes at 0.85 m) | Vents and crawl spaces at least 1.1 m high |
| Width | 0.6 m (radius 0.3 m) | Doorways and vents at least 0.7 m wide |
| Step height | 0.35 m | Anything up to 0.35 m is stepped onto; taller blocks and can be cover |
| Peek reach | 0.4 m sideways, 0.35 m up, 0.15 m down; aiming out 0.6 m sideways, 0.5 m up | Waist-high cover is 1 m: it hides a crouched player (eyes 0.85 m), who peeks over it with eyes at 1.2 m |

- Decks are flat and connected only by elevators (no stairs, ramps or ladders). Elevators are
  `AnimatableBody3D`s moved in `_physics_process`, which the player rides automatically. A descending elevator
  pushes a player standing beneath it through the floor, so elevator sections must keep the shaft closed
  (doors) whenever the platform isn't there; the controller doesn't guard against it.
- Anything meant to be stepped onto (bodies, broken robots) needs flat-topped collision, such as a box proxy.
- Step-up and step-down are done by the controller itself with `test_move`, because Godot's floor snap fails
  while the body still touches the edge it just walked off.

### Peek, aim out and hitboxes

Built in [004](features/004-free-peek-and-cover.md). There is no cover system: cover is level geometry, and the
player peeks from wherever they stand.

- The head offset lives in the body's yaw frame (x right, y up). A sphere (radius 0.15 m) swept out from the
  normal eye position against `world` stops the head at walls. The camera interpolates the head between physics
  frames like the body, and a sideways lean rolls the view (up to 8°).
- `Player.peek_state` (`PeekRules.State`: `NONE`, `PEEK`, `AIM_OUT`) and `peek_state_changed` tell other systems
  what the player is doing. A peek can't shoot, so weapons (005) must not fire while `peek_state` is `PEEK`.
  Holding `peek` and `aim` together aims out, in either order, as soon as the head is off-centre, and stays out
  until either is released; with the head still centred it is a peek.
- Hitboxes are `Hitbox` areas on the `hitbox` layer under `Player/Hitboxes`, moved by the player every physics
  frame: a head sphere (radius 0.12 m) at the eyes, a body cylinder (radius 0.25 m) from the feet to 0.1 m below
  the eyes, and an arm box (0.14 × 0.14 × 0.6 m) reaching forward along the view from 0.2 m below the eyes, which
  is only active while aiming out. `Player.get_hitboxes()` lists them; `Hitbox.sample_points()` gives each one's
  centre and a point towards each side.
- Exposure is physical: an enemy can only hit what it can see. Enemies decide what they see by casting rays
  against `world` to the sample points (as the debug `ExposureWatcher` does), and shots hit by casting against
  `hitbox` (006). Because the camera sits at the centre of the head hitbox, a peek that shows the player an enemy
  also shows that enemy the player's head.

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
| `interact` | E: uses what the player looks at (hold to pry open, board or extract), and continues past the run summary |
| `flashlight` | F |
| `peek` | Alt (hold) |
| `aim` | Right mouse button (hold): aims down sights, and aims out of cover while peeking |
| `shoot` | Left mouse button: a click fires, holding charges and releasing fires |
| `reload` | R |
| `inventory` | Tab: opens and closes the inventory (Esc and `interact` also close it) |
| `inventory_drag` | Left mouse button (hold): drags an item in the inventory |
| `inventory_rotate` | Right mouse button: turns the dragged item a quarter turn |
| `inventory_mirror` | Middle mouse button and the wheel: mirrors the dragged item |

The inventory actions share buttons with `shoot` and `aim`; while the inventory is open the weapon takes no input.

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
| 4     | hitbox | `Hitbox` areas of anything that can be damaged: the player (head, body, arm), shooting targets, robots (eye, body). They collide with nothing; shots cast rays against `world` and `hitbox` |
| 5     | enemy  | Drone bodies (006). The player and drones collide with it; shots and sight ignore it. Turrets, out of reach, are on no layer; destroyed robots move to `world` |
| 6     | item   | Dropped items (007). They collide with `world` and each other only, so the player walks through them and shots and sight ignore them; their `PickUp` interactable is on `interactable`. Loot containers are on `world` |

Render layers: 2 `exterior` is the wreck's hull outside the ship's window (008), lit only by its own light; 20
`viewmodel` is the weapon in view (005).

Trigger areas sit on no layer: door proximity and doorway areas mask `player` and `enemy` (so doors open for
drones), the elevator's "aboard" area and a drone's contact area mask `player`.

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
- **Markers.** `SectionMarker`s (enemy or loot) mark where a mission may place things. An enemy marker's `mount`
  says what fits: a drone post on the floor, or a turret mount on the ceiling, facing the middle of the turret's
  arc. The wreck's `enemies` list (marker path to enemy ID) fills enemy markers (006); missions will fill it by
  difficulty later. A loot marker stands on the floor at the foot of a wall, facing (−Z) away from it, and its
  `space` says what fits: `ROOM` takes any container, `TIGHT` (vents, dead ends) only containers that
  `fits_tight`. The wreck's `loot` list of `LootPlacement`s (marker, container ID, item IDs) fills them (007).
  Markers are placed clear of every socket's possible doorway or vent mouth (1.2 m wide, centred on the socket, plus
  its trim), since a section doesn't know which sockets a wreck will open.
- **Transforms in scene files.** A `.tscn` writes `Transform3D(...)` row by row: the x axis is the 1st, 4th and
  7th numbers and the z axis the 3rd, 6th and 9th, so `Transform3D(0, 0, 1, 0, 1, 0, -1, 0, 0, ...)` has its −Z
  pointing −X. Scripts that write scenes must write rows.
- **Navigation.** After assembly the wreck bakes the drones' navigation, one region per deck (see
  [Robots](#robots-senses-and-navigation)). `Section.navigable` is off for sections drones can't use (vents, the
  elevator).
- **Adding a section:** create `content/base/sections/<name>/` with the scene and a `SectionDefinition`
  (`<name>.tres`) pointing at it. Fill whole cells, put a socket at the centre of every edge that can connect,
  and keep geometry inside the footprint (wall sockets build the walls on their edges). Static parts go under one
  `CSGCombiner3D` with collision. Shared parts (doors, lamps, buttons) and materials stay in `scenes/sections/`.
  Add a turret mount where a turret could cover the space, clear of pillars, loot markers at the foot of walls
  clear of the openings, and turn `navigable` off if drones can't use the section.

### Doors and elevators

- `SlidingDoor`: an `AnimatableBody3D` panel that slides sideways into the wall. A doorway area holds a closing
  door open while the player stands in it, but never opens a closed one. Automatic doors also have a proximity
  area (1.5 m either side) and close 2 s after the player leaves. Drones open and hold doors the same way.
- `Elevator` (a `Section` spanning two decks): call buttons on each deck, a send button on the platform, doors
  driven by the elevator that only open at the deck where the platform is, and a `dinged(deck, sound_position)`
  signal on arrival. The ding is also a noise robots hear (006).

### Weapons, health and damage

Built in [005](features/005-weapon-and-health.md).

- **Health and hitboxes.** `Health` (`scenes/combat/`) is a node with `max_health`, `take_damage()`, and the
  signals `damaged` and `died` (once). Anything damageable has a `Health` and one or more `Hitbox` areas on the
  `hitbox` layer; each hitbox has a `part`, a `damage_multiplier` (the player's head 2×, body 1×, arm 0.5×) and
  the `Health` it damages. A shot that hits a hitbox calls `Hitbox.take_hit(damage, source_position)`.
- **Shots** are hitscan rays (lasers) from the shooter's eye, against `world` and `hitbox` with areas on,
  excluding the shooter's own hitboxes. The first thing hit takes the damage; walls stop shots. `LaserEffects`
  draws the beam, sparks, impact flash and scorch for any shooter, in its own colour (the player blue-white,
  enemies red). Scorch marks are permanent for the run: each is a `Decal` child of the surface it hit (so it moves
  with doors and elevators), at most 256 at once with the oldest removed first, fading out beyond 25 m.
- **Weapons and thermal clips.** `Weapon` (under the player's camera) runs the gun in the inventory's weapon slot
  with the clips the player carries (`ThermalClips`: the loaded clip's heat as a fraction, kept on the gun item as
  `Item.clip_heat` since 009 so it goes wherever the gun goes; the fresh and spent clips are items in the player's
  inventory since 007, and a reload takes a fresh one from the pockets). The player re-arms whenever the slot changes
  (`Player._arm()`): `Weapon.equip()` the new gun, or `unequip()` and stay unarmed, which calls off a reload under
  way (`ThermalClips.cancel_swap()` puts the fresh clip back). `WeaponRules` holds the decisions. `Weapon.blocks_sprint()` and `Weapon.is_aiming` feed the player's sprint block and speed cap; the
  player passes in whether it can shoot (not while peeking), whether it is lowered (sprinting or sorting the
  inventory) and whether it takes input (not while the inventory is open).
- **Viewmodels.** A weapon's viewmodel scene has a `WeaponViewmodel` root whose origin is the rear sight. Its
  materials are swapped for `viewmodel.gdshader`, which pulls depth towards the near plane so weapons never poke
  into walls while still being lit by the world; viewmodels cast no shadows. They draw on visual layer 20
  (`viewmodel`), which decals leave out so scorch marks never land on the weapon in view.
- **Death.** The player's `died` signal ends the run: everything carried is lost, and once the screen is black the
  run summary shows (008).

### Robots, senses and navigation

Built in [006](features/006-robot-enemy.md). Robots are the first enemies; later enemy types reuse the senses.

- **Brain and bodies.** `Robot` (`scenes/enemies/`) is the brain every robot shares: each physics frame it senses
  the player, lets its `RobotMind` (node-free) decide its state (idle, investigating, attacking, searching,
  destroyed) and lock-on, and fires once locked; `RobotHeat` makes it vent. Its fire starts wide and walks in the
  longer it keeps the player in sight (`RobotRules.aim_spread`), and it aims where the player was a moment ago
  (`AimTrail`), so moving draws misses. `Turret` and `Drone` extend it for how
  they move. A robot scene's root is the robot, with unique nodes `%Eye` (faces −Z; it sees and fires from there),
  `%Searchlight`, `%Health`, `%Model` and its sounds. Robots join the `robots` group and find the player through the
  `player` group. They wake a physics frame after the end of their first frame, once the wreck's CSG walls have
  rebuilt; before that they would see through walls.
- **Sight.** Exposure stays physical: a robot sees the player's active hitbox sample points inside its view cone and
  range with nothing on `world` in between, and only shoots at points it sees. In the dark its range drops (5 m):
  `Player.is_part_lit()` asks `LightLevel` (`scenes/combat/`) once per physics frame whether light from the visible
  lights in the `sight_lights` group reaches each hitbox (Godot's attenuation and spot cone, weighted by the
  colour's luminance, shadowed by `world`). The flashlight lights the whole player. A light that should show the
  player up joins `sight_lights` in its scene.
- **Hearing.** `Hearing.make_noise(source, position, loudness, kind)` is the one way to make a noise: it reaches
  every Node3D in the `noise_listeners` group within `loudness` metres on the same deck (through walls, never
  between decks), which reacts in `hear_noise()`. Sources so far: shots (loudness on the weapon definition),
  footsteps (per movement state, on the player), the elevator's ding, robot shots and crashes.
- **Navigation.** Navigation is baked per wreck at load, deferred to the end of its first frame (after the CSG
  rebuild), one region per deck from a slice around that deck's floor, from the collision faces of the navigable
  sections' CSG shapes. Doors and platforms are bodies, so they never block it. The agent (2 m tall, 0.375 m radius)
  can't fit vents. The navigation cell size is 0.125 m (project setting), so doorways stay open. Flying enemies ask
  for paths from the floor point below them and hold their height themselves.
- **Combat music.** `CombatMusic`, in the player scene, plays while any robot is attacking and fades out a few
  seconds after the last one stops.

### Interaction and HUD

- `Interactable` is an `Area3D` on the `interactable` layer with a `prompt`, an `interacted` signal and a
  `hold_time` (0 for a press). The player casts a 2 m ray from the camera every physics frame against `world` and
  `interactable`, so walls block it, and calls `interact()` when `interact` is pressed, or, for one with a hold
  time, once it has been held that long since a press on it (`set_held()` tells it when a hold starts or stops).
  An interactable sitting on a solid body needs an area a little bigger than the body, or the ray hits the body.
- The HUD (`game/ui/hud.tscn`, owned by the player scene) shows a centre dot and the prompt as a key cap plus
  action. It uses the Windows system font Bahnschrift (DIN-style signage), falling back to Godot's default font.
  Corner placards (005): health bottom left, the loaded clip's heat bottom right as one segment per uncharged
  shot. Red (`#FF1F14`) means danger everywhere, the laser's blue (`#9ED1FF`) means charging, and heat orange
  matches the clip's glowing band. Custom readouts are small `Control`s that draw themselves and only redraw when
  their state changes. A screen that handles the mouse itself sets everything it holds to ignore the mouse (a
  `PanelContainer` stops clicks by default) and reads the pointer from its events, not from the window, so headless
  tests can push real mouse events. `Hud.key_label(action)` gives the bound key for any prompt; a held action shows "HOLD"
  before the key cap and fills a second ring, in the placards' ink, round the centre dot. The clip readout hides
  while the player is unarmed (`Hud.hide_clips()`). The inventory screen (007) and the trader hub's screen (009) are
  part of the HUD; both extend `GridScreen`. So is the run summary (008), a placard drawn on the black screen after a run (`RunSummaryCard`,
  with the clone's lifeline traced in the laser's blue, or flatlining in red after a death); `Hud.fade_in()` lifts the
  black on arrival.

### Loot and inventory

Built in [007](features/007-loot-and-grid-inventory.md).

- **Grids and shapes.** Items take up shapes of cells (`ItemShape`: rows of text, eight orientations: quarter turns
  clockwise, then the same mirrored). `ItemGrid` (node-free) holds `Item`s (definition, orientation, cell) with no
  overlaps, finds space in reading order and any orientation, and can reserve cells. The player's `Inventory` is
  the weapon slot (`WeaponSlot`, 3×2, which only takes one weapon: the gun in hand, since 009), the pockets (4×1)
  and the backpack (6×5). Loot only moves by being dragged: nothing is ever sorted into a grid
  by itself (only level set-up packs containers, and a reload puts its spent clip in the fresh clip's cell).
  Node-free classes don't log; the nodes that change them log the outcome.
- **Loot.** A `Lootable` (`Interactable` with an `ItemGrid`) is anything the player pries open by holding interact
  and then searches: container scenes (`LootContainer` root on `world`, its model's `Lid` node swung open on its
  hinge) and destroyed robots' wreckage (`Robot.get_salvage()`, from `EnemyDefinition.salvage`). Prying open is a
  noise (4 m).
- **The screen.** The `InventoryScreen` overlays the running game, which keeps going while it is open; the player
  stands still and the weapon takes no input. The container and the floor are on the left half, the player's
  grids (weapon slot, pockets, backpack) on the right. What it shares with the hub's screen (dragging, previews, the
  item card, placards, key hints, the two-column layout) lives in its base, `GridScreen`, with hooks for the rest. Items are dragged, turned and mirrored with the mouse; pressing one selects it, and the one
  under the pointer shows its item card. The screen always shows the floor: the dropped items within reach and in sight, in a grid that grows to keep two empty rows.
  Dragging an item onto it, or releasing one outside the placards, makes a `DroppedItem` (a rigid body on the
  `item` layer, one box per cell) that clatters as a 3 m noise; dragging one off it frees the body. Its calls
  (`begin_drag`, `drop_drag` and so on) are what its mouse input makes, so tests call them directly.
- **Icons.** `ItemIcons` renders each item's model from straight above at startup, fitted to its shape at 64 px a
  cell, with glow capped so colours read. Item models are built to their shapes (0.15 m a cell, origin in the
  middle of the footprint, rows along +Z). Headless runs have no renderer, so no icons: the grid tints the cells
  instead.

### Runs, the ship and the session

Built in [008](features/008-extraction-and-clone-loop.md).

- **Session.** `GameSession` keeps the stash (`ItemGrid` 10×8), the clone number (one more per death), the runs
  boarded, how the player arrives on the ship (`NEW_CLONE` in the clone pod, `EXTRACTED` in the airlock) and the kit
  (the `Inventory`, whose gun carries its clip's heat) while it crosses to the next scene. `board()`, `extract()` and
  `die()` record the run (`RunSummary`) and hand the kit over (a death hands none); `board()` and
  `continue_to_ship()` travel. A player takes the kit in `_setup_combat()` (`take_carried()`, once). With none, it
  builds the basic kit only while `basic_kit_next` is on (a new game, or a level started on its own): the gun from
  `starting_weapon_id` in the weapon slot, `starting_pocket_clips` (2) and `starting_backpack_clips` (0; the test
  levels set 2). After a death `basic_kit_next` is off and the next clone wakes empty-handed (009). Travel sounds play on the
  session, so they carry on through the scene change; every arrival fades in from black (`fade_in_next`).
- **Airlocks.** The airlock section (`Airlock`) has an outer door (`%OuterDoor`, an `Interactable` with a hold time)
  and a sign above it. While interact is held on it, it loops a cycling sound and makes an `airlock` noise (10 m)
  every second; a full hold emits `cycled`. Every `Wreck` connects its airlocks (`Wreck.airlocks`): on a wreck
  cycling extracts ("Return to ship", 3 s), and the `Ship` sets "Board the wreck", 1 s.
- **Leaving.** `Player.extract()` and `Player.board()` stop the player without the death's slump: a reload under way
  finishes, the weapon and hitboxes go (nothing can see or hit them), and the screen fades to black over the docking
  sound (`leave_fade_time`). Boarding then travels; extracting and dying show the run summary, and interact (read in
  `_physics_process`) continues to the ship.
- **The ship.** `Ship` is a `Wreck` with no robots or loot (a wreck bakes navigation only when it has robots). It
  turns its lamps warm and steady (`CeilingLamp.set_steady()`) with a warm fill light under each, and places the
  player in the clone pod (`ClonePod`) or the airlock. Its player instance has `holstered` on (`Weapon.holstered`:
  lowered, no aim or trigger, reloads work) and `has_floor` off (the inventory screen has no floor and returns items
  released outside). The `Stash` binds a `Lootable` to the session's grid (`Lootable.bind()`), already open.
- **Trader terminal.** `TraderTerminal` stands beside the stash; its `Interactable` ("Trade") opens the hub's
  screen through `Player.open_trader()` (009).
- **Outside.** The space beyond the cockpit window is the ship environment's star sky shader
  (`scenes/ship/starfield.gdshader`) and the wreck's dark hull as CSG on render layer 2 (`exterior`), lit only by a
  directional light whose cull mask is that layer, so it never lights the ship's inside.

### Trading

Built in [009](features/009-trader-hub.md).

- **Prices.** `Trader` (`scenes/trade/`, node-free) is a hub: a title and a price seed. Selling pays an item's value
  and buying costs twice it (`SELL_RATE`, `BUY_RATE`), both times the same per-item factor within ±5%
  (`PRICE_VARIANCE`), seeded from the hub's seed and the item's ID so a hub always quotes the same price.
  `Trader.shelf()` is every registered item, weapons first, then the cheapest up; stock is unlimited, and a mod adds
  stock by adding items. The rates are a first guess for the tuning pass (roadmap backlog).
- **Wallet and trades.** `GameSession` keeps `bitcoin` (₿500 at the start, never lost; `bitcoin_changed`), the
  system's `trader` (rolled in `new_game()`; one system until 012) and the sell `crate` (6×4). `sell_crate()` pays
  the hub's offer for everything in the crate, `buy()` puts one item in the stash's first free spot and is refused
  when the wallet is short or the stash full, and `return_crate()` puts what is left back in the stash (what doesn't
  fit stays in the crate for the next visit).
- **The screen.** `TraderScreen` (a `GridScreen`): the crate with the offer and a SELL button and the shop
  (`ShopView`: icon tiles with buy prices, red and dimmed when unaffordable) on the left, the wallet and the stash on
  the right. Items drag between the stash and the crate only; clicking a shop tile buys one and selects it in the
  stash. The wallet ticks to its new amount with the change fading beside it, and a status line explains every deal
  or refusal. Selling is from the stash only, so carried loot goes into the stash first.
- **Bitcoin.** The only currency is bitcoin: every amount the player sees goes through `Bitcoin.format()`
  (`scripts/bitcoin.gd`): the ₿ symbol, commas between thousands, and a sign for changes (`₿1,240`, `−₿50`,
  `+₿154`). At home the HUD shows the wallet in the top left: the ship's player has `shows_wallet` on, calls
  `Hud.show_wallet()` and feeds it `GameSession.bitcoin_changed`; the readout hides while the hub's screen is open.

### Lighting

- The wreck's `Environment` has a black background, a very low blue-grey ambient light, filmic tonemapping and a
  little glow. There is no sun.
- Lamps are shadow-casting `SpotLight3D`s pointing down, so walls stop their light and nothing leaks between
  sections. Ceiling lamps are cold white; emergency lamps (same `CeilingLamp` script) are red. Whether a lamp
  flickers is seeded from its position, so it is the same on every run. Lamps are in the `sight_lights` group,
  so what they light, robots see from afar (006).
- The flashlight is a shadow-casting `SpotLight3D` on the player camera, toggled by `flashlight`.
- The ship (008) uses the same lamps, made warm (about 3800 K), steady and 1.6 times as strong, plus a warm fill
  `OmniLight3D` under each, with a brighter warm ambient light, so it reads as safe next to the wreck.

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

- Export format: glTF binary (`.glb`). A model that belongs to one piece of content goes into that content's
  folder (e.g. `content/base/weapons/laser_pistol/`); shared models go into `game/assets/models/`.
- Units: 1 Blender unit = 1 metre; apply scale and rotation before export.
- Orientation: models face -Y in Blender (toward the Front view camera). This arrives as +Z in Godot, which is Godot's model front (`Vector3.MODEL_FRONT`).
- Naming: a content model is named after its content folder (`laser_pistol.glb`). A weapon's item model (its icon
  and how it lies on the floor) is `<name>_item.glb`: the same mesh laid flat to its shape by the weapon's script. The ship's props are shared
  models in `game/assets/models/ship/`, built by `art-source/models/ship_props.py`, one object each named after the
  prop. Objects and materials that
  code looks up get fixed names in the script (the pistol's `Clip`, `Emitter` and `ClipHeat`; the turret's `Ring`
  and `Head`; every robot's `Eye` and `Vents` materials; every container's `Lid`). Otherwise TBD.
- One script may build many pieces of content of one kind when they share their helpers (`items.py` and
  `containers.py` build every item and container, each with `--only <name>`).
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
  - Suites that end runs turn `GameSession.travel_enabled` off (it still emits `travelled`) and call
    `GameSession.new_game()` before and after each test, so no kit, clone count or bitcoin leak into another suite.
  - Headless runs can't capture the mouse: `Input.mouse_mode` never reads `MOUSE_MODE_CAPTURED`, so tests check the
    player's state instead.
  - Keep decisions in node-free classes (like `MovementRules`) so they can be unit tested. Behaviour that needs
    physics is tested by loading a scene with `scene_runner` and pressing actions with `Input.action_press`.
    `Input.action_press` changes action state without sending input events, so gameplay input that tests
    drive is read with `Input` queries in `_physics_process`, not from `_unhandled_input`.
  - `scene_runner(...).set_time_factor(5.0)` runs five times as many physics frames per second, so one physics
    frame is still 1/60 s of game time. A press can take one physics frame to register, so wait two frames
    before checking its effect.
- **Manual playtests:** feel, visuals and audio. Each feature's "Done when" includes a playtest in the running game.

## 10. Technical risks and open questions

- **Scope.** One developer working on an extraction shooter with crafting, a star map and procedural ships. Mitigate by
  sticking to the MVP cut in the roadmap and the one-feature-at-a-time rule.
- **Content architecture.** If the registry and definition format are wrong, every later system pays for it.
  Items and containers (007) fitted without a change to the registry either.
  003 settled and tested the registry with sections only. 005's weapon and 006's robots fitted without changes to
  the registry; items (007) are the next test.
- **Section assembly.** Sections must connect cleanly (sockets, alignment, no gaps), and navigation and lighting
  must work across the seams. 002 proved the sockets, alignment and lighting by hand; 006 bakes navigation across
  the seams at load. Wrecks assembled from blueprints will need the same bake to stay fast as they grow.
- **Scripted art.** Hard-surface assets suit Blender scripting, but animated characters may need another source.
- **Free peek and hit exposure.** 004 made exposure physical (hitboxes plus line of sight to their sample
  points) and checks it with debug watchers. The robots (006) see and shoot by the same rules, with a lock-on delay
  that decides who shoots first; whether it feels fair is for the playtests to tune.
- Minimum hardware is TBD (see [Performance targets](#7-performance-targets)).
