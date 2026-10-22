# 010 — Wreck variety

| Field     | Value |
|-----------|-------|
| Status    | done |
| Milestone | post-MVP |
| Depends on | 002, 003, 006, 007 |

## Goal

Ships differ: there are three wreck layouts, and their robots and loot are rolled every run to suit a hidden
difficulty, so choosing which ship to board (011) means something.

## Player experience

Supports *Choose your risk, against the clock*: the system map will offer several ships, and that choice only
matters if they differ in layout, size, robots and loot. Until now there was one wreck with fixed robots and fixed
loot, so every run played the same. The player never sees a difficulty level, only what makes a wreck dangerous
(for now, about how many robots are still active), and judges what he can handle.

## Requirements

- [x] Difficulty has five levels (1–5), used only behind the scenes to roll a wreck's robots and loot. The player
      never sees a level: instead every wreck exposes the details that make it dangerous, for the system map (011)
      to show, and the player decides what he can handle. For a wreck, that is the expected number of robots still
      active in its security system (later kinds add human enemies, how quickly it escalates, and so on).
- [x] Three wreck layouts, each built by hand from the section kit and registered as content (`base:<name>`), like
      sections and items. Each rolls its level evenly within its own range, so bigger ships are harder and richer
      (size scales with difficulty, as in the design); levels 4–5 wait for large stations. Robots and loot are
      rolled onto a layout's markers every run, so the same layout plays differently each time. Blueprint-based
      generation (see Levels / content in [game-design.md](../game-design.md#4-levels--content)) waits in the idea
      backlog.

      | Layout | Decks | Sections | Levels | Expected robots per level | Containers |
      |--------|-------|----------|--------|---------------------------|------------|
      | Courier | 1 | 7 | 1–2 | 1 / 2 | 3 |
      | Hauler | 2 | 14 (the small wreck) | 1–3 | 3 / 4 / 6 | 6 |
      | Freighter | 2 | 25, with the cargo bay | 2–3 | 6 / 8 | 9 |
- [x] Two new sections, so the new layouts look different: a 4-way corridor crossing, and a cargo bay (2×3 cells)
      for the freighter, with loot markers, drone posts and turret mounts, and cover to fight from.
- [x] Robots placed to suit each wreck's difficulty. The expected count for its level is what the system map shows
      ("about 4 robots active"), but a scan of a derelict's security network is never certain: the wreck actually
      holds the expected count ±1, rolled with the rest. Every run they go on random enemy markers, never within 5 m
      of the airlock's inner door (boarding is done in secret, so nothing waits there), and the marker decides the
      kind: a ceiling mount gets a turret, a floor post a drone. A destroyed robot's salvage stays fixed
      per kind (turret: plasma coil and circuit board; drone: power cell and servo motor), so the player knows what
      a fight pays.
- [x] Containers are rolled: each layout has a number of containers (see the table), which go on random loot
      markers every run, each of a kind rolled from those that fit its marker, weighted locker 1 : supply crate 2 :
      small case 1 (a tight marker, in a vent or a dead end, only takes a small case). The level only scales what is
      inside.
- [x] Loot tables: container contents are rolled each run, with bigger containers rolling better loot, filled to
      suit the wreck's difficulty (promoted from the idea backlog; 007 kept every wreck's loot fixed). Each container
      has a loot table (items with weights) and a bitcoin budget, which the wreck's level multiplies: ×1, ×1.5, ×2
      at levels 1, 2, 3 (half a budget more per level). Items are drawn by weight from those whose value fits the
      remaining budget and that still fit in the container, until none does, so pricier items only turn up in bigger
      containers or at higher levels. Starting values, all for the tuning pass:

      | Container | Budget at level 1 | Loot table (weights) |
      |-----------|-------------------|----------------------|
      | Small case | ₿100 | thermal clip 3, spent thermal clip 2, circuit board 2, servo motor 1, data drive 1 |
      | Supply crate | ₿200 | thermal clip 3, conduit 3, hull plating 3, circuit board 2, servo motor 2, power cell 1 |
      | Locker | ₿350 | thermal clip 2, circuit board 2, servo motor 2, power cell 2, data drive 1, gyroscope 1, plasma coil 1, laser pistol 0.25 |
- [x] Every level-1 wreck has a gun in one of its containers, on top of its budget, so an easy wreck is always the
      way back for an empty-handed android (replacing 009's pistol in the small wreck's locker). Elsewhere guns roll
      from the loot tables like any item (in lockers, rarely).
- [x] Until the system map (011), the session rolls the docked wreck (layout, level, and a seed for its robots and
      loot) when the game starts and after every run, and the airlock's prompt shows its details, e.g. "Board the
      hauler · about 4 robots active". Boarding takes the wreck offered; 011 replaces the roll with a choice. No new
      controls: interact on the airlock's outer door boards, as before.
- [x] Tests cover rolling loot and robots, the docked wreck, and building each layout.

## Out of scope

- The system map and choosing a ship (011).
- Doomed, breached and contested wrecks (timer, oxygen, escalation).
- The company's ships and their encrypted drives.
- Large stations, and difficulty levels 4–5.
- Blueprint-based generation (idea backlog).
- Rolled robot salvage: it stays fixed per robot kind.
- The ship's window keeps showing the same dark hull, whichever wreck is docked.

## Technical notes

- **Layouts as content.** `WreckDefinition` (`scenes/wreck/`), a new content kind in
  `content/base/wrecks/<name>/`: the layout scene (root `Wreck`: its sections, and the player in the airlock), the
  level range (`levels`), the expected robots per level (`expected_robots`) and the number of containers
  (`containers`). The small wreck moves to `content/base/wrecks/hauler/` with its fixed lists emptied.
- **The roll.** `WreckRoll` (node-free, `scenes/wreck/`) is a definition, a level and a seed; the actual robot count
  (the expected ±1) comes from the seed, so a wreck rolled ahead (011) holds what was shown. A wreck that is a
  registered layout fills its `enemies` and `loot` lists from a roll in `_ready()`, before placing them, so
  placement and its checks stay as they are: the roll handed over by `GameSession` when boarding, or its own (a
  random level in its range) when the scene runs on its own. Wrecks that are no registered layout (the ship and the
  test levels) keep their fixed lists. Robots take random enemy markers clear of the airlocks
  (`Wreck.AIRLOCK_CLEARANCE`), of a registered enemy kind whose mount fits;
  containers take random loot markers, of a kind that fits, weighted by `ContainerDefinition.weight`. At level 1 the
  cheapest registered gun goes into a random container it fits, before the budgets are rolled.
- **Random picks.** `Dice` (`scripts/`) picks without repeats and by weight from a given generator; a roll seeds one
  generator for its robot count and another (`WreckRoll.new_rng()`) for its markers and loot.
- **Loot tables.** `ContainerDefinition` gains `budget` (bitcoin at level 1), `loot` (item ID to weight) and
  `weight`. `LootRoll` (node-free, `scenes/loot/`) scales a budget by level and draws a container's items, packing
  them into a scratch `ItemGrid` the way `Lootable.fill()` will, so everything drawn fits. Item IDs are looked up when
  rolled, never when registered; an unknown one is skipped with a warning.
- **Session.** `GameSession.docked` (a `WreckRoll`) is rolled in `new_game()` and whenever a run ends (`extract()`,
  `die()`): a random layout, a level in its range and a seed. `board()` travels to its scene and hands it over
  (`take_boarding()`); the `WRECK_SCENE` constant goes. The ship's airlock prompt and sign come from it ("Board the
  hauler · about 4 robots active", "HAULER DOCKED").
- **New sections.** `corridor_cross` (one cell, four corridor sockets, a drone post) and `cargo_bay` (2×3 cells,
  one deck: ten wall sockets, eight loot markers, three drone posts, two turret mounts, and two tall cargo stacks
  and two rows of waist-high crates as cover), in the same greybox CSG as the rest of the kit.
- **Tests.** `tests/wreck/wreck_roll_test.gd`, `tests/loot/loot_roll_test.gd` and `tests/scripts/dice_test.gd` test
  the rolls; `tests/sections/layouts_test.gd` loads every layout (assembly, markers, every loot marker's biggest
  container clear of the walls, navigation, the level-1 gun); `hauler_test.gd` (the old small wreck suite) plays the
  hauler from a fixed roll; the session, ship and content suites cover the docked wreck and the new content.
- Blueprints are described in the Modding section of [game-design.md](../game-design.md#modding): a blueprint says
  how a ship class assembles the sections, and missions populate it.

## Done when

- [x] All requirements are checked.
- [x] Playtested in the running game.
- [x] Roadmap status updated to `done`.
