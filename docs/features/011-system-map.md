# 011 — System map

| Field     | Value |
|-----------|-------|
| Status    | done |
| Milestone | post-MVP |
| Depends on | 009, 010 |

## Goal

The player is in a star system with several ships and stations to choose from and a trader hub, flies between them
on hydrogen, and every boarding takes a day.

## Player experience

This is the heart of the loop in [game-design.md](../game-design.md#core-loop) and of *Choose your risk, against the
clock*: inspect each ship's risk, decide which are worth boarding, and fly a loop through them rather than back to
the hub after every one, to save hydrogen and bitcoin. Each boarding costs a day, whether the android extracts or
dies.

## Requirements

- [x] A system map shows the system's star, its places on their orbits (planets, moons, asteroid belts, stations,
      battlefields and anomalies, named as in [galaxy.md](../galaxy.md)), its trader hub, the ship, and the wrecks
      to board, each at a place or in open space. There are no station layouts yet, so all of them are ships.
- [x] Inspecting a wreck (pointing at it) shows its details, never a difficulty level: its wreck type, where it lies,
      the expected number of robots still active in its security system (010) and the gear it requires (none yet);
      later kinds add human enemies, how quickly it escalates, and so on. The player judges the risk from them.
- [x] Hydrogen flies the ship within the system. The tank holds 24 units and starts full; a flight burns a unit per
      map unit (orbits are a unit apart), rounded up, at least one. Pointing at a wreck plots the course there and
      on back to the hub, with the hydrogen each leg burns, on the map and on the hydrogen gauge. Flying takes no
      time. A flight is refused when the tank couldn't get the ship there and back to the hub, so it can never be
      stranded away from it.
- [x] Hydrogen is bought at the hub and always in stock: ₿5 a unit, give or take the hub's 5%; FILL UP on the hub's
      screen fills the tank as far as the wallet pays.
- [x] Trading and refuelling only happen at the hub: the ship starts there, and away from it the trader terminal
      reads "OUT OF RANGE" and can't be used, so a loop through several wrecks ends back at the hub.
- [x] The day counter: the game starts on day 0, boarding a ship takes a day, whether the android extracts or dies,
      and days only pass by boarding (and jumping, in 012). At home the HUD shows the bitcoin, the hydrogen and the
      day in the top left.
- [x] A ship once boarded is gone for good, whether the android extracted or died. The ship stays where it was, with
      nothing docked: the airlock reads "NOTHING DOCKED", its outer door is shut and the window shows only stars.
- [x] The system map opens from the cockpit console: interact on it (E / A) opens the map as a full-screen overlay,
      like the trader hub's screen, and the console's screen reads "SYSTEM MAP" and the system's name instead of
      "Star map offline". 012's star map can become a second tab on the same screen.
- [x] A system holds 6 to 8 wrecks, rolled when it is revealed (on arrival): each a random layout at a random level
      in its range (010), at a random place, or in open space one time in four. No new ones turn up while the player
      stays; what happens when he comes back to a system that is nearly empty belongs to 012.
- [x] Job-board leads at the hub: moved to the idea backlog, as a nice-to-have for much later.
- [x] Controls, with no new actions: interact on the console opens the map (E / A); the pointer moves as in the
      inventory (mouse / left stick); pointing at a wreck or the hub shows its details, a click selects it, and a
      click on FLY flies there (LMB / A); Tab, Esc or E close it (View or B). FILL UP on the hub's screen is a click
      too (LMB / A). In the Controls table in [game-design.md](../game-design.md#controls).
- [x] Tests cover flying, hydrogen use and refuelling, trading only at the hub, the day counter and ships
      disappearing after a run.

## Out of scope

- Jumping to other systems and antimatter (012).
- Triangulation, her messages, the countdown and the hidden pacing.
- The company's ships and their encrypted drives.
- Location requirements (e.g. oxygen for breached wrecks).
- Station layouts, and remembering a half-looted wreck.

## Technical notes

- **Systems as content.** `StarSystemDefinition` (`scenes/galaxy/`): map ID, star, owner, position on the star map
  and its places (`SystemPlace`: name, kind, habitable, note), from the star outwards. All 50 systems of
  [galaxy.md](../galaxy.md) are in `content/base/systems/`, written by `art-source/galaxy/systems.py` from galaxy.md's
  tables and `galaxy.json`; change those and rerun it rather than editing definitions. A new game starts in a random
  system (012 picks one on the outer ring).
- **The map.** `StarSystem` (node-free) lays a system out: one orbit per place, a map unit apart, moons beside their
  planet, the hub beside the first habitable world, angles seeded from the map ID so a system looks the same every
  time. `StarSystem.reveal()` rolls the wrecks (`SystemWreck`: roll, place, map position). `hydrogen_between()` is a
  flight's cost.
- **Session.** `GameSession` keeps `system`, `ship_position`, `at_hub`, `hydrogen` (`HYDROGEN_TANK` 24,
  `hydrogen_changed`), `day` and `docked` (the wreck flown to, until boarded). `fly_to_wreck()`, `fly_to_hub()`
  (`ship_moved`), `hydrogen_needed()` and `refuel()`; `sell_crate()` and `buy()` refuse away from the hub. `board()`
  passes a day and takes the wreck off the map; runs no longer roll a new wreck. `arrive_in()` reveals a system and
  rolls its hub's prices (`Trader` titled "<System> Hanse", with `hydrogen_price()`).
- **Ship.** `SystemConsole` (`scenes/ship/`) replaces the static console. `Ship` and `TraderTerminal` update on
  `ship_moved`: the airlock shuts with nothing docked (`Airlock.set_usable()`, `Interactable.set_enabled()`), the
  hull outside shows only while docked, and the terminal links up only at the hub.
- **Screens.** `MenuScreen` (`ui/`) is the new base of the HUD's full-screen screens (placards, columns, hints,
  pointer); `GridScreen` extends it with the dragging. `SystemMapScreen` holds the map (`SystemMapView`, drawn in
  code) and the side column; `FuelGauge` draws the tank like the heat gauge. Its logs use 🪐. The flight plays
  thrusters (`art-source/audio/ship_sounds.py`; since 012 an ignition, a loop as long as the flight and a stop).
- **Tests.** `tests/galaxy/star_system_test.gd`, `tests/galaxy/system_map_test.gd` (real mouse events through the
  console), and the session, trader, ship, extraction and content suites.

## Done when

- [x] All requirements are checked.
- [x] Playtested in the running game.
- [x] Roadmap status updated to `done`.
