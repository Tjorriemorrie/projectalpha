# 008 — Extraction, death and clone loop

| Field     | Value |
|-----------|-------|
| Status    | done |
| Milestone | MVP |
| Depends on | 002, 005, 007 |

## Goal

The player travels from a minimal ship scene to the wreck and back. Extracting keeps the loot; dying loses everything, and the player wakes up as a new clone on the ship.

## Player experience

Closes the core loop, so it supports *Lose it all*: what the player carries onto the wreck is at risk, what they
leave in the stash is safe, and getting out alive is the only way to keep a haul. Holding the airlock at the end is
the last tense moment of a run. Completing this feature completes the MVP.

## Requirements

### The ship

- [x] The ship is a small place the player walks around in first person, a greybox built from the wreck section
      kit like the wreck, on one deck. It has no robots and no music, only the ship's hum. Its rooms:
      - the **airlock**, docked to the wreck, which the player boards it through;
      - the **clone bay**, with the clone pod where a new clone wakes up;
      - the **stash** room, with the stash locker;
      - the **cockpit**, with a window onto space and the wreck's dark hull, a pilot seat and a console whose
        screen reads "Star map offline" (the star map plugs in there later);
      - the **bedroom**, with a bunk and a wall locker.

      The cockpit and the bedroom are set dressing that makes the ship feel like home: nothing in them can be used
      yet.
- [x] On the ship the pistol is holstered: lowered, it can't aim or fire. Reloading still works, so a player who
      extracted with a hot clip can swap in a fresh one from the pockets before boarding. The health and heat
      placards stay on screen, and the inventory opens as anywhere else.
- [x] Every run starts at full health: the ship patches the player up, whether they extracted or woke as a new
      clone.

### Boarding

- [x] The ship is already docked at the wreck. The player holds interact on the ship's airlock door ("Board the
      wreck", about 1 s, so it never happens by accident); the screen fades to black over the docking sounds
      (clunks, a hiss), and they stand in the wreck's airlock with its outer door behind them. The ship and the
      wreck are separate scenes, so every run loads a fresh wreck.

### Extraction

- [x] The player extracts at the airlock they came in by, where the ship is docked: they hold interact on its
      outer door ("Return to ship") for about 3 s while the ring round the centre dot fills. The door cycling is
      loud, a noise robots hear (about 10 m, as loud as sprinting, again every second it is held), so nearby robots
      come to look. Letting go or looking away cancels it, so a fight at the exit is a real risk. Then the player
      can't be hit any more, the screen fades to black and the player is back on the ship, standing in its airlock.
      (Starting values, tuned in the playtest.)

### The stash

- [x] Extracting keeps everything the player carries: it stays in their pockets and backpack, just as it was, and
      the loaded clip keeps its heat. A reload under way when the run ends finishes.
- [x] The ship has a storage locker, the **stash** (a 10×8 grid to start with). Interact ("Open stash") opens it in
      the inventory screen, in the container's place, and items move between it and the player's grids by
      dragging, like any container: nothing moves by itself. The stash is safe; whatever the player still carries
      when they board the wreck is at risk.
- [x] There is no floor on the ship: the inventory screen hides the floor placard there, and an item released
      outside the placards goes back where it came from. The stash is the only place to put things on the ship, so
      junk such as spent clips has to be left on the wreck.

### Death and the new clone

- [x] Dying on the wreck loses everything the player carries: the pockets, the backpack and the loaded clip. The
      stash on the ship is untouched. The wreck is gone: there is no going back for the body.
- [x] After the death screen, the player wakes up as a new clone in the ship's clone pod with the basic kit: the
      pistol with a fresh clip loaded and 2 fresh clips in the pockets; the backpack is empty. Anything more comes
      from the stash, so a run is never impossible, but a death still costs every clip and item carried. A new game
      starts the same way, with an empty stash.

### Run summary

- [x] When a run ends, a placard in the HUD's style sums it up on the black screen of the fade:
      - extracted ("RUN COMPLETE"): the haul, the items and bitcoin carried out, and what the run gained, the
        value carried out minus the value carried in when boarding;
      - died ("SIGNAL LOST"): what was lost, the items and bitcoin carried, and which clone wakes up next
        ("Clone 3 activated"). Clones are numbered from 1, one more for every death.
- [x] The player presses interact to continue, and the ship fades in.

### The game session

- [x] The game starts on the ship, with the first clone waking in the clone pod. The stash, what the player
      carries and the clone number live in memory for the session, with no saving: quitting and starting again is a
      new game. The whole loop (ship, wreck, extract or die, ship again) runs any number of times without
      restarting the game. Every run boards the same small wreck, fresh, with its fixed robots and loot.

### Controls and HUD

- [x] No new controls: everything new uses interact, E on the keyboard and A / Cross on the gamepad (wired after
      the MVP), and the Controls table in [game-design.md](../game-design.md#controls) says so:

      | Action | Keyboard / mouse | Gamepad |
      |--------|------------------|---------|
      | Board the wreck (ship's airlock door) | E (hold) | A / Cross (hold) |
      | Return to ship (wreck's airlock door) | E (hold) | A / Cross (hold) |
      | Open the stash | E | A / Cross |
      | Continue past the run summary | E | A / Cross |

- [x] Prompts: "HOLD [E] Board the wreck", "HOLD [E] Return to ship" and "[E] Open stash"; the summary placard
      ends with "[E] Continue". Keys are read from the Input Map.

### Look and sound

- [x] The ship feels safe the moment the fade lifts: the same greybox kit, but warm white lamps (about 3800 K) that
      never flicker, more ambient light than the wreck, and a low engine hum. There is no music on the ship. Next to
      it the cold, flickering wreck feels worse.
- [x] Low-poly models made by a Blender script in `art-source/`: the clone pod, the stash locker, the pilot seat,
      the cockpit console and the bunk. The bedroom's wall locker is the loot locker's model.
- [x] Placeholder sounds generated by Python scripts: the ship's hum, the airlock cycling (a loop while interact is
      held), docking (clunks and a hiss, playing through the fade) and the clone pod's hiss on waking.

### Test level and tests

- [x] Unit tests cover the session: handing the kit over between scenes, the basic kit after a death, clone numbers,
      the stash surviving runs, and the summaries' values.
- [x] Scene tests on the ship: it assembles cleanly, the player wakes in the clone pod or arrives in the airlock,
      the stash opens with the session's grid and items drag between it and the backpack (through real mouse
      events), there is no floor, the pistol can't fire but reloads, and holding interact on the airlock door
      boards the wreck with the kit handed over. On the small wreck: holding the outer door extracts after its
      time, letting go cancels, cycling is a noise, and the summary continues to the ship on a real key press; a
      death shows the summary and wakes a new clone with the basic kit.

## Out of scope

- Saving the game to disk, and menus (main menu, pause menu, new game): quitting starts a new game.
- Choosing where to go: one wreck, always the small wreck with its fixed robots and loot, and no star map, travel
  or fuel. The cockpit's console is only set dressing.
- Selling, bitcoin as the currency, a trader, breakdown and crafting: values are only totalled.
- A floor on the ship, ship customization and base building, more stash room or stash upgrades.
- Healing during a run, med bays and healing items.
- An animated wake-up (lying in the pod, its doors opening) beyond a fade and a hiss.
- Wiring the gamepad bindings (after the MVP).

## Technical notes

- **Files.** `game/autoload/game_session.gd` (`GameSession`, an autoload after `ItemIcons`) holds the session and
  moves between the ship and the wreck. `game/scenes/run/run_summary.gd` (`RunSummary`, node-free) is one run's
  outcome. `game/scenes/ship/`: `ship.tscn` (the main scene) and `ship.gd` (`Ship`, a `Wreck`), `stash.tscn`
  (`Stash`), `clone_pod.tscn` and the set dressing's scenes, the ship's environment and its star sky shader.
  `content/base/sections/airlock/airlock.gd` (`Airlock`, a `Section`) runs the outer door, and a new section,
  `content/base/sections/cockpit/`, has the window (a CSG cut with a glass pane, `materials/glass.tres`) and wall
  sockets on its other three sides. `game/ui/run_summary_card.gd` draws the summary placard in the
  HUD.
- **Session.** `GameSession` keeps the stash (`ItemGrid` 10×8), the clone number, the run count, the value carried
  in at boarding, how the player arrives on the ship (`NEW_CLONE` or `EXTRACTED`), and the carried kit (the
  `Inventory` and the loaded clip's heat) while it travels between scenes. `board()`, `extract()` and `die()` record
  the run and hand the kit over (a death hands none, and counts a clone); `continue_to_ship()` and `board()` travel
  with `change_scene_to_file()`. The player takes the kit in `_setup_combat()` (`take_carried()`, once); with none
  it builds the basic kit from `starting_pocket_clips` (2) and `starting_backpack_clips` (0; the test levels set 2).
  Travel sounds play on the session, so they carry on through the scene change. Tests turn `travel_enabled` off and
  read `travelled`; `new_game()` resets everything.
- **Airlock.** The airlock section's outer door has an `Interactable` (`%OuterDoor`) with a hold time and a sign
  above it ("SHIP DOCKED", "WRECK DOCKED"), a looping cycling sound while held and, while held, a noise (`airlock`,
  10 m) every second; when the hold completes the
  airlock emits `cycled`. Its exports default to extraction ("Return to ship", 3 s); the ship sets "Board the
  wreck" and 1 s. The wreck (and the ship) connect every airlock's `cycled` to the player's `extract()` (or
  `board()`).
- **Leaving.** `Player.extract()` and `Player.board()` freeze the player like death but without the slump: no input,
  hitboxes off (so nothing can hit them any more), the inventory closed, a reload under way finished. The HUD fades
  to black over the docking sound; then boarding travels to the wreck, and extracting shows the summary. After a
  death the summary shows once the fade is done (`death_summary_delay`). While the summary shows, interact (read in
  `_physics_process`) calls `GameSession.continue_to_ship()`. Every arrival fades in from black
  (`GameSession.fade_in_next`).
- **Ship.** `Ship` assembles like a wreck; with no robots no navigation is baked (a wreck now bakes only when it
  placed robots). It turns every `CeilingLamp` warm, steady and 1.6 times as strong (`set_steady()`) with a warm
  fill `OmniLight3D` under each, sets its airlock to boarding, and
  puts the player in the clone pod or in the airlock by `GameSession.arrival`. Its player instance has `holstered`
  on (`Weapon.holstered`: lowered, no aim or trigger, reload works) and `has_floor` off (`InventoryScreen.open()`
  without a floor: no floor placard, and a release outside returns the item). Its environment has a star sky
  (`starfield.gdshader`) and more, warmer ambient light. The wreck's hull outside the cockpit window is dark CSG with
  a docking tube to the airlock, a few dim red beacons and portholes, on render layer 2 (`exterior`), lit only by a
  directional light whose cull mask is that layer.
- **Stash.** A `StaticBody3D` with a `Lootable` bound to `GameSession.stash` (`Lootable.bind()`), already open, so
  interact opens it straight away ("Open stash").
- **Models and sounds.** `art-source/models/ship_props.py` builds the clone pod, the stash locker, the pilot seat,
  the console and the bunk into `game/assets/models/ship/` (with `--only <name>` and `--preview <png>`).
  `art-source/audio/ship_sounds.py` writes the hum (looping), the airlock cycle (looping), docking and the pod's
  hiss into `game/assets/audio/ship/`.
- **Logging.** The session logs with 🧬, the ship (stash and clone pod too) with 🚀, the airlock with 🚪 (doors) and
  lamps with 💡; the summary card logs with the player's 🏃.
- **Tests.** Unit: `tests/run/game_session_test.gd`. Scene: `tests/ship/ship_test.gd` (the ship) and
  `tests/run/extraction_test.gd` (extracting and dying on the small wreck, with its robots taken out).

## Done when

- [x] All requirements are checked.
- [x] Playtested in the running game.
- [x] Roadmap status updated to `done`.
