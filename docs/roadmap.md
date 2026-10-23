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
| 009 | [Trader hub](features/009-trader-hub.md) | done |
| 010 | [Wreck variety](features/010-wreck-variety.md) | done |
| 011 | [System map](features/011-system-map.md) | done |
| 012 | [Star map and travel](features/012-star-map-and-travel.md) | done |

Later, roughly in this order: triangulation, her messages and the rescue clock's countdown, the company's ships and
the cure, and the android stock (together with swapping the clone fiction for the android link). Saving has to land
before the 90 to 100-day campaign can be played end to end.

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
- Unlimited stash: no size limit, since the player has to sell to survive and we control the prices. It grows to
  fit (like the inventory screen's floor), so storing or buying never has to check for room; 009 refuses a buy
  when the 10×8 stash is full.
- Armor and gear (e.g. body armor, helmets), found on wrecks and sold at the hubs like everything else.
- Tuning pass, once a full playthrough is possible: tweak all the control variables together. So far: the hubs'
  sell and buy rates and per-hub price variance (009), item values, starting bitcoin (009), container budgets, loot
  tables, container weights and the expected robots per level of each layout (010), which ships and stations spawn
  in a system when it is revealed (how many, now 6 to 8, which kinds, how risky and how many in open space; 011,
  012), the hydrogen tank (24), what a flight burns and hydrogen's price (₿5 a unit; 011), intel's price (012),
  the antimatter tank and what a jump burns (10 units, one a light year; 012), antimatter's price (₿100 a unit; 012),
  the antimatter a new game starts with (2 of 10; more if antimatter gets dearer; 012), the days antimatter takes to
  arrive (fixed at 1 for now; the design has them grow through the game; 012), the drive's recharge (a day; 012), the
  ships that turn up when a player would be stranded (012), ingredient and android prices, decryption delay, how
  quickly the pings narrow, the countdown's length, and run difficulty (aiming at about half of all runs extracting).
- Blueprint-based wreck generation: a blueprint per ship class and a generator that snaps sections together on the
  grid every run; 010 builds its layouts by hand.
- The ship's window shows the docked wreck's own hull (010 keeps one dark hull for every layout).
- Missions that need the man himself to board instead of an android (nice to have).
- Why a ship can only be looted once: the in-world reasons and story (011 takes every boarded ship off the system
  map, whether the android extracted or died).
- A way out for a broke player: at the hub with an empty tank, no bitcoin and nothing to sell, he can't fly to any
  wreck (011).
- A way through (nice to have, much later; it needs a cutscene): the last stretch to her is cut off by a nebula,
  minefield, anomaly or blockade, and charts, codes or a drive upgrade get the player past it.
- Job-board leads at the hubs (nice to have, much later): tips about particular ships or stations in the system.
- Maybe let a jump reach any system the tank can reach, not just the neighbours on the jump network (012 limits a
  jump to the systems within 10 ly, the lanes on the star map).
- Ships the player can survive: 012's rule against being stranded counts the wrecks left, not whether he can handle
  them, so an early system that rolls one courier among haulers and freighters pushes a weak player onto a harder
  ship. The hidden pacing should pick a mix that suits him (enough couriers early on).
