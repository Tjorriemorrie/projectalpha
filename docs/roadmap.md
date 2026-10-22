# Roadmap

> The build order. Work on exactly one feature at a time: the first one in the list that is not done.
> Each row links to its spec in [features/](features/). Status values: `idea`, `planned`, `in progress`, `done`, `cut`.

## MVP

**Goal:** prove that one tense run is fun: board a small, quiet wreck, fight automated robot defenses from cover,
loot into a grid inventory, and extract alive or lose everything.
Placeholder art (Godot primitives / grey boxes) is fine; no menus, saving or polish unless the core loop needs them.

**In scope:**
- First-person movement with sprint, crouch and free peek; keyboard and mouse only.
- One weapon and player health that lasts through several fights (about ten hits kill).
- One enemy type: robots (automated defenses).
- One small, quiet wreck built from modular sections.
- Loot containers, grid inventory and an extraction point.
- Death loses everything; you wake up as a clone on the ship. Simple ship-to-wreck travel, with no star map.
- All content (weapon, enemy, items, sections) loaded through the data-driven content registry.

**Out of scope:** trader hubs, breakdown and crafting, the star map, fuel, timer, oxygen, escalation, gamepad,
external mod loading, and blueprint-driven procedural assembly.

**Done when:** a player can start a run on the ship, board the wreck, fight robots, loot, and either extract with
the loot kept, or die, lose it all and wake up as a new clone. All of this without restarting the game.

| #   | Feature | Status |
|-----|---------|--------|
| 001 | [Player controller](features/001-player-controller.md) | done |
| 002 | [Wreck section kit](features/002-wreck-section-kit.md) | done |
| 003 | [Content registry and definitions](features/003-content-registry.md) | done |
| 004 | [Free peek and cover](features/004-free-peek-and-cover.md) | done |
| 005 | [Weapon and player health](features/005-weapon-and-health.md) | done |
| 006 | [Robot enemy](features/006-robot-enemy.md) | done |
| 007 | [Loot containers and grid inventory](features/007-loot-and-grid-inventory.md) | done |
| 008 | [Extraction, death and clone loop](features/008-extraction-and-clone-loop.md) | done |

## After MVP

Ordered, but only roughly. Re-order freely once the MVP is played.

| #   | Feature | Status |
|-----|---------|--------|
|     |         |        |

## Idea backlog

New ideas go here first, as one line each, so they don't interrupt the current feature.
Promote an idea by giving it a number and a file in `features/`, and linking it from the Feature column in
[game-design.md](game-design.md).

- Ship base building / customizing the home ship (explicitly not for now).
- Human enemies (the second enemy type after robots).
- More enemy types after humans and robots: aliens, monsters, infected.
- External mod loading (content packs) and later Steam Workshop support.
- More wreck moods after dark horror: gritty industrial, clean sci-fi (varying by wreck type).
- Gamepad support: wire the bindings from the Controls table in game-design.md (right-stick look with
  sensitivity and dead zone, click-to-sprint, tap/hold crouch).
- Salvage tools as weapons (Dead Space style: plasma cutter, rivet gun, arc welder), much later and only if it
  fits next to the lasers.
- Saving the game to disk (the stash, what the player carries, the clone number), with a main menu and a new game;
  008 keeps the session in memory only.
- Swap the clone fiction in the game for the android link (008 built clones: the clone pod, `NEW_CLONE`,
  "Clone 3 activated"): the clone pod becomes the android's charging cradle, with the man's body in a link chair.
  Update the README, technical design and 008 spec that describe it.
- Loot tables: container contents rolled each run (bigger containers rolling better loot), with missions filling
  loot markers by difficulty; 007 keeps every wreck's loot fixed.
- Missions that need the man himself to board instead of an android (nice to have).
- A way through (nice to have, much later; it needs a cutscene): the last stretch to her is cut off by a nebula,
  minefield, anomaly or blockade, and charts, codes or a drive upgrade get the player past it.
