# 007 — Loot containers and grid inventory

| Field     | Value |
|-----------|-------|
| Status    | done |
| Milestone | MVP |
| Depends on | 003, 005, 006 |

## Goal

The player can pry open containers and robot wreckage and move the loot into a grid inventory, a backpack and
pockets, in which items have tetris shapes. Thermal clips become items in it.

## Player experience

Every container is a small decision about what is worth the space, made in real time while the wreck's robots are
still about. Supports *Everything is salvage* and *Choose your risk*.

## Requirements

### Grid inventory

- [x] The player carries two grids: a **backpack** of 6×5 cells and **pockets**, a strip of 4×1 cells for things
      they need at hand. Reloads take fresh thermal clips from the pockets only, so the player chooses how many
      to keep ready; clips in the backpack have to be moved to the pockets first.
- [x] Loot only ever moves by being dragged: nothing is sorted into a grid by itself, and there is no shift-click,
      double-click or other quick move.
- [x] Every item can be selected: pressing on it selects it (a thick border), and it stays selected wherever it is
      dragged to; pressing empty space clears the selection. The gamepad's cursor will move the same selection.
- [x] The item under the pointer shows its **item card** beside the pointer: its name, a picture, its value, size
      in cells, value per cell and description.
- [x] Items take up shapes of cells in the grid: rectangles (1×1, 1×2, 2×2...) and also tetris shapes (L, T, S
      and the like), so packing the grid well is a small puzzle.
- [x] While holding an item the player can rotate it in 90° steps and mirror it, so an L also fits as a J: up to
      eight orientations.
- [x] The inventory screen (and a container's) works in real time: the game keeps running and robots can find the
      player, but the player can't move, look, shoot or peek until it is closed. Sorting loot in the open is a
      real risk. Only the player closes it; getting hit doesn't, so being caught costs a moment more.

### Items

- [x] Every item is its own content definition in the base pack with its name, shape, bitcoin value and a short
      description, all shown on its item card. There is no trader yet, but the value is what makes "is this worth
      the space" a real choice (and 008 can total the haul).
- [x] Eight salvage items, covering the shapes (starting values, tuned in the playtest):

      | Item | Shape | Cells | Value |
      |------|-------|-------|-------|
      | Data drive | 1×1 | 1 | 150 |
      | Circuit board | 1×2 | 2 | 60 |
      | Conduit | 1×3 bar | 3 | 30 |
      | Servo motor | L of 3 | 3 | 70 |
      | Gyroscope | 2×2 | 4 | 160 |
      | Hull plating | S of 4 | 4 | 40 |
      | Plasma coil | T of 4 | 4 | 180 |
      | Power cell | L of 4 | 4 | 120 |

- [x] Thermal clips are items too: a fresh clip (value 25) and a spent clip (value 10), both 1×1. They replace
      005's clip counts: the clips the player carries are the clip items in their grids, and the HUD counts them.
- [x] A reload takes a fresh clip from the pockets, and the spent clip that comes out of the pistol takes the cell
      the fresh one left, so a reload always works and never needs space. Spent clips pile up in the pockets until
      the player moves them to the backpack or leaves them behind to make room.
- [x] During a reload the inventory can stay open or be opened: the fresh clip leaves its pocket cell when the
      reload starts, and that cell stays reserved for the spent clip until the reload ends.
- [x] The player starts a run with a fresh clip loaded, 2 fresh clips in the pockets and 2 in the backpack, so
      from the start they decide when to move clips to the pockets and what loot to give up for them. A few
      containers in the wreck hold fresh clips, so ammo is loot too. The real loadout comes with 008.
- [x] The inventory screen always shows the **floor**: every dropped item within reach (and in sight) in a grid
      of its own, which grows so it always has two empty rows below whatever lies there, enough for any item
      turned to lie flat. Dragging an item onto the floor, or releasing it anywhere outside the inventory's
      placards, drops it: it lands at the player's feet as a small physical object, which stays for the run, and
      shows in the floor grid. Dragging an item off the floor into a grid picks it up.
- [x] Looking at a dropped item and pressing interact opens the inventory with the floor, so the item can be
      dragged into a grid; other dropped items within reach are on the floor too.

### Containers

- [x] Three containers, each its own content definition with its model and grid size, so a container's size hints
      at the haul before the player spends time opening it:
      - a **supply crate**, waist high, with a 4×3 grid, in rooms (it is cover too);
      - a **locker** standing against a room wall, with a 4×5 grid, the big haul;
      - a **small case** with a 3×2 grid, tucked into vents and dead ends.
- [x] The player holds interact on a closed container for about 1.5 s to pry it open; looking away or letting go
      cancels it. Once open, everything inside shows at once, in the container's own grid next to the player's.
      An opened container stays open, so going back to it opens it straight away.
- [x] A destroyed robot's wreckage is a container too: the player pries it open the same way and takes its parts.
      Its grid and its salvage are fixed on the enemy definition: the turret holds a plasma coil and a circuit
      board, the drone a servo motor and a power cell (starting contents, tuned in the playtest). Fighting pays.

### Placement

- [x] Everything is fixed, like the robots in 006: the wreck lists which container stands on which loot marker
      and exactly which items are inside, by ID through the content registry, so every run plays the same. The
      items are packed into the container's grid in the order listed. Unknown IDs, markers that aren't loot
      markers and contents that don't fit are assembly errors. Loot tables and filling markers by difficulty come
      with missions, after the MVP.
- [x] Loot markers say what fits there: a spot in a room, against a wall, takes any container; a tight spot (vents,
      dead ends) only takes the small case.
- [x] The small wreck's loot (starting contents, tuned in the playtest), about 57 cells in containers and 26 in the
      robots' wreckage against the player's 30 or so free cells:

      | Where | Container | Contents |
      |-------|-----------|----------|
      | Deck 1, store room | Locker | Gyroscope, power cell, conduit, circuit board, 2 fresh clips |
      | Deck 1, store room | Supply crate | Hull plating, servo motor, circuit board |
      | Deck 1, dead end | Small case | Data drive, fresh clip, circuit board |
      | Deck 2, hold | Locker | Plasma coil, gyroscope, data drive, hull plating, conduit |
      | Deck 2, hold | Supply crate | Power cell, servo motor, 2 fresh clips |
      | Deck 2, vent | Small case | Plasma coil |

      The other loot markers stay empty.

### Controls

- [x] Items are dragged with the mouse, and turned while dragging. Gamepad bindings go into the Controls table in
      [game-design.md](../game-design.md#controls) now and are wired after the MVP:

      | Action | Keyboard / mouse | Gamepad |
      |--------|------------------|---------|
      | Open / close the inventory | Tab (Esc and E also close it) | View / Select (B also closes it) |
      | Pry a container open, open the floor at a dropped item | E (hold to pry open) | A / Cross (hold to pry open) |
      | Move the cursor | Mouse | Left stick / D-pad |
      | Drag an item | Left click (hold), release to put it down | A / Cross (hold) |
      | Rotate the dragged item 90° | Right click | Right bumper |
      | Mirror the dragged item | Middle click or mouse wheel | Left bumper |
      | Drop an item on the floor | Drag it onto the floor grid, or release it outside the inventory | Y / Triangle |

### HUD

- [x] Looking at a closed container shows "hold E" and what it is ("Pry open supply crate"), and the ring round
      the centre dot fills while prying; an open one shows "Search supply crate", a dropped item "Pick up
      servo motor" (which opens the floor).
- [x] The heat placard counts the fresh clips in the pockets, the ones a reload can use, and the spent clips
      carried. When the pockets have no fresh clip left but the backpack does, it says so.

### Look and sound

- [x] The inventory screen is a set of placards in the HUD's style over the running game, which stays visible and
      slightly dimmed around them, so the player can see a searchlight sweeping in while they sort: an open
      container's grid and the floor under it on the left half, their pockets and backpack on the right half,
      keeping the middle clear, and the item card of the item under the pointer. Under the player's grids, what they
      carry is totalled (bitcoin and free cells), and the keys are listed along the bottom. The health and heat
      placards stay on screen. Items are outlined as one silhouette of their shape; while one is dragged, the cells
      it would take show whether it fits (the laser's blue or red), and where it came from stays as a dark
      cut-out.
- [x] Low-poly models made by Blender scripts in `art-source/`: every item, built to its grid shape (an L-shaped
      servo motor, a T-shaped plasma coil), and the three containers, which open (lid, door) when pried open.
- [x] Item icons are rendered from their models when the game loads (top-down, fitted to the item's shape), so
      the grid shows the same object that lies on the floor. Rotating and mirroring turn the icon with the item.
- [x] Looting makes noise robots hear (006): prying a container open is about as loud as a walking step (about
      4 m), and an item dropped on the floor clatters (about 3 m). Moving items in the grid is silent.
- [x] Placeholder sounds generated by Python scripts: prying (a scrape while held, a clunk when it opens), opening
      and closing the inventory, picking an item up and putting it down in the grid, a dull bump when it doesn't
      fit, and an item dropping onto the floor.

### Test level and tests

- [x] A loot test level, `scenes/test/loot_test.tscn`: a small one-deck wreck with no robots, with a room holding a
      supply crate and a locker, a dead end with a small case and a vent with a small case, filled through the
      wreck's loot list like the small wreck.
- [x] Unit tests cover the shapes (rotating and mirroring, all eight orientations), the grid (placing, overlaps,
      edges, removing, finding space in any orientation, reserved cells, counting), the inventory (where picked-up
      items go first, and where they go when the first choice is full) and the clips (a reload takes a fresh clip
      from the pockets only and puts the spent one in its cell).
- [x] Scene tests in the loot test level: holding interact pries a container open after its time and letting go
      cancels it, prying is a noise, the screen opens with the container's contents, items move between grids and
      are sent to the other side, the player can't move or shoot while the screen is open, a reload takes clips
      from the pockets, dropping an item (onto the floor grid or outside the inventory) puts it in the world and on
      the floor grid, interact on a dropped item opens the floor, dragging it off the floor picks it up, the floor
      only shows items within reach and in sight, and it grows to keep two empty rows. In the robot test level: a destroyed robot's wreckage can be pried open and holds its
      salvage. The wreck's loot placement and its errors, the small wreck's containers, and the base pack check
      registering the items and containers.

## Out of scope

- Loot tables, random or rarity-based contents, and missions filling loot markers by difficulty (after the MVP).
- Searching that reveals items one by one, locked containers, keys and hacking.
- Trading, selling, breaking down and crafting (after the MVP). Totalling the haul is for 008.
- Keeping the loot between runs, and losing it on death (008).
- Weight and encumbrance, stacking, equipment slots (weapons, armour, bigger backpacks) and using items (healing).
- Re-cooling spent clips.
- Loose items placed around the wreck: all loot starts in containers or wreckage; only what the player drops lies
  loose.
- Robots reacting to opened containers or dropped items other than through their noise.
- Wiring the gamepad bindings (after the MVP).

## Technical notes

- **Files.** `game/scenes/loot/`: `ItemDefinition` and `ContainerDefinition` (`ContentDefinition`s), `ItemShape`
  (node-free and static: a shape's cells from its rows, and its eight orientations), `Item` (an item: its definition,
  its orientation and the cell it sits at), `ItemGrid` (node-free: a grid of items with placing, removing, finding
  space, reserved cells and counts), `Inventory` (the pockets and the backpack, and where picked-up items go),
  `Lootable` (an `Interactable` holding an `ItemGrid`, pried open by holding interact), `LootContainer` (the root of
  a container scene) and `DroppedItem` (an item lying in the world). `game/autoload/item_icons.gd` renders the icons.
  `game/ui/`: `InventoryScreen` and `ItemGridView` (draws one grid and takes the drags).
- **Content.** `content/base/items/<name>/` for the eight salvage items and the two clips (`thermal_clip` and
  `spent_thermal_clip`), each with its definition and `.glb`; `content/base/containers/supply_crate/`, `locker/`
  and `small_case/`, each with its definition, scene and `.glb`. Loot sounds shared by every container and item are
  in `game/assets/audio/loot/`.
- **Item definitions.** An item's shape is a list of rows (`["###", ".#."]` is the T), readable in the inspector
  and in a mod's `.tres`. It also has its `value`, its `description` (an item without one is a problem the registry
  reports) and its `model` (`@export_file`). Orientations 0–3 are quarter
  turns clockwise and 4–7
  the same mirrored; shapes are normalised to start at cell (0, 0). A cell is 0.15 m in the item models, so a
  model's footprint matches its shape.
- **Clips.** `WeaponDefinition` names the items it loads and unloads (`clip_item`, `spent_clip_item`), so no code
  hard-codes the clips. `ThermalClips` keeps the loaded clip's heat but reads the fresh and spent clips from the
  player's `Inventory`: a reload takes the first fresh clip from the pockets at its start and reserves the cell,
  and the swap at its end puts the spent clip there. The player's `starting_spare_clips` becomes
  `starting_pocket_clips` and `starting_backpack_clips`.
- **Interaction.** `Interactable` gains a `hold_time` (0 is a press) and `set_held()`, which the player calls when
  a hold starts or stops (`held_changed`). The player starts a hold only on a fresh press while looking at the
  target, fills it while interact stays held on the same target, and calls `interact()` when it is full; letting
  go or looking away ends it. The HUD's prompt shows "HOLD" before the key cap and a second ring, in the placards'
  ink, fills round the centre dot (`ChargeRing` with exported colours).
- **Lootables.** A `Lootable` holds its loot in an `ItemGrid` and owns its sounds (a looping scrape while held, a
  clunk when it opens), so robot wreckage needs no scene of its own. Closed, its hold time is its pry time and its
  prompt "Pry open <title>"; open, it is used on the press ("Search <title>"). Opening makes a `pry` noise
  (`Hearing.make_noise`, 4 m), and the player then opens the inventory screen with it. Its area is a little bigger
  than the body it sits on, so the interact ray finds it before the body (on `world`).
- **Containers.** A container scene's root is a `LootContainer` (a `StaticBody3D` on `world`, so the crate is
  cover), with `%Lootable` and `%Model`. The model's `Lid` node (the locker's door) has its origin on the hinge and
  is swung open by `open_rotation`, exported on the root (the crate −100° and the case −95° about X, the locker
  −110° about Y). Like the robots, a container faces −Z (its model is turned 180° in the scene) and its origin is
  the middle of its back on the floor. Sizes: crate 1.0 × 1.0 × 0.6 m, locker 0.8 × 1.9 × 0.5 m, case
  0.5 × 0.16 × 0.32 m (width, height, depth).
- **Markers and placement.** `SectionMarker` gains a `space` for loot markers (`ROOM` or `TIGHT`), and a
  `ContainerDefinition` says whether it `fits_tight`. Loot markers stand at the foot of a wall, facing away from
  it, clear of every socket's possible doorway or vent mouth: the small room's two against its north wall at
  x = ±1.25, the large room's four in the middle of each wall (`LootSpotNorth`, `South`, `East`, `West`), the
  dead end's on its east wall near the open end, and the vent's along one side of the duct, leaving 0.88 m to
  crawl past. The `Wreck` gets a `loot` list of `LootPlacement` resources (marker path, container ID, item IDs)
  and places each container after the robots, named after its kind and section (`SupplyCrate_StoreRoom`), packing
  its items in order with `ItemGrid.add()`. The containers' footprints are cut out of the drones' navigation
  (`add_projected_obstruction`), so drones fly round lockers instead of into them.
- **Robot wreckage.** `EnemyDefinition` gains `salvage_grid` and `salvage` (item IDs). When a robot is destroyed it
  adds a `Lootable` named `Salvage` (`Robot.get_salvage()`), titled "<display name> wreckage", with a box set by
  the robot scene's `salvage_box` and `salvage_offset` (the turret's hangs 0.3 m below its mount). The drone's
  moves with its body as it falls.
- **Dropped items.** A `DroppedItem` is a `RigidBody3D` built in code (`DroppedItem.create()`), on a new layer 6,
  `item`, that collides with `world` and other items only, so the player walks through it and shots and sight
  ignore it. Its collision is one box per cell of the item's shape, as tall as the model, and its `PickUp`
  interactable is a little bigger. It lands 0.5 m in front of the player's feet (at their feet when a wall is in
  the way), up to 0.2 m to either side so drops don't stack, makes an `item_drop` noise (3 m, `drop_loudness` on
  the player) and clatters on its first contact. Dropped items are in the `dropped_items` group. Its prompt is
  "Pick up <name>", which opens the inventory with the floor.
- **The floor.** When the inventory opens, the player gathers the dropped items within `floor_reach` (1.5 m) of the
  feet on the same deck and in sight of the eyes (plus the one looked at, if any), nearest first, into an
  `ItemGrid` `InventoryScreen.FLOOR_COLUMNS` (6) wide, and the screen grows it (`ItemGrid.grow_to()`) to keep
  `FLOOR_SPARE_ROWS` (2) empty rows. The floor grid is only a layout of what lies there: an item landing on it from
  another grid emits `dropped_on_floor` (the player makes a `DroppedItem`), and an item leaving it for another grid
  emits `taken_from_floor` (the player frees that item's body). Items laid on the floor by being released outside
  take its first free spot. The placard is in the left column, under the container's.
- **Icons.** `ItemIcons` (an autoload, after `ContentRegistry`) renders each registered item's model once at
  startup, in a `SubViewport` of its own world with a top-down orthographic camera fitted to the shape (64 px a
  cell, transparent background), a key light, a fill light with little specular (flat metal tops burn white
  otherwise), and glowing parts capped at an emission of 0.6 so they keep their colour. Without a renderer
  (headless runs and tests) there are no icons, and the grid tints the item's cells instead. `ItemGridView` maps the
  icon onto the item's orientation with the same turns and mirroring as its cells (`icon_transform()`).
- **Clips and the weapon.** `Weapon.physics_update()` takes `has_input`: while the inventory is open the player
  passes false, which drops a charge, stops aiming and ignores the trigger until it is released, and lowers the
  weapon; a reload under way still finishes. The heat placard reads "2 fresh · 2 packed · 0 spent", and says
  "Move a clip to your pockets" when it is saturated with fresh clips only in the backpack.
- **The screen.** The `InventoryScreen` is part of the HUD, built in code (placards, `ItemGridView`s, key hints
  read from the Input Map once), and sizes its cells from the screen height (5%, 40–72 px). It takes every mouse
  event itself: everything it holds has `mouse_filter` set to ignore (a `PanelContainer` otherwise swallows clicks),
  and it keeps the pointer's position from the events (`pointer`, `move_pointer()`), so headless tests can push real
  mouse events and a gamepad can drive the same pointer later. `cell_center()` gives where a cell is on screen.
  `select()` and `focused` (the item under the pointer) drive the selection border and the item card, which is
  drawn on the overlay beside the pointer and kept on screen. While it is open the mouse
  is free and the player stands still in their stance: no movement, look, peek or weapon input. It takes all mouse
  input, so a release outside every placard drops the item onto the floor (one dragged off the floor goes back),
  and a release on a placard but off the cells puts it back. The inventory actions are in the Input Map:
  `inventory` (Tab), `inventory_drag` (left click), `inventory_rotate` (right click) and `inventory_mirror` (middle
  click and the wheel). Tab, Esc and E close it, read in `_physics_process` so tests can press them. Its calls
  (`begin_drag`, `rotate_drag`, `mirror_drag`, `drop_drag`, `drop_drag_outside`) are what the mouse input makes
  and what the tests call.
- **Models and sounds.** `art-source/models/items.py` builds all ten items (one object each, named after the
  item; its `SHAPES` must match the definitions) and `containers.py` the three containers (`Body` and `Lid`), each
  with `--only <name>` and `--preview <png>`. `art-source/audio/loot_sounds.py` writes the pry loop (imported
  looping), the clunk, inventory open and close, pick, place, bump and the drop.
- **Logging.** Inventory, containers and items log with 🎒.
- **Tests.** Unit: `tests/loot/item_shape_test.gd`, `item_grid_test.gd`, `inventory_test.gd`, and the clip tests
  in `tests/weapons/weapon_rules_test.gd`. Scene: `tests/loot/loot_test.gd` and `inventory_screen_test.gd` in the
  loot test level (with `noise_ear.gd`, a listener that remembers what it hears), the wreckage salvage in
  `tests/enemies/turret_test.gd` and `drone_test.gd`, the placement and its errors in `tests/sections/wreck_test.gd`
  (the screen suite also pushes mouse events through the viewport, at 1280×720 since headless windows are tiny),
  the small wreck's loot in `small_wreck_test.gd`, and the base pack check (items built to their shapes, container
  scenes with a lid, the pistol's clips, the robots' salvage fitting). The loot and small wreck suites check that
  every container stands clear of the walls and faces open floor.

## Done when

- [x] All requirements are checked.
- [x] Playtested in the running game.
- [x] Roadmap status updated to `done`.
