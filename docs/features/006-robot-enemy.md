# 006 — Robot enemy

| Field     | Value |
|-----------|-------|
| Status    | done |
| Milestone | MVP |
| Depends on | 002, 003, 005 |

## Goal

Robots, the wreck's automated defenses, detect, attack and can be destroyed by the player. There are two kinds,
sharing one brain: a stationary turret and a hovering security drone.

## Player experience

A threat the player can hear before seeing (see Look and sound), and that punishes careless movement. Supports
*Lose it all*: a single robot rarely kills, but every fight wears the player down over a run.

## Requirements

### Robot kinds

- [x] Two robots, sharing the same detection and fire logic: a **turret** mounted in place that never moves,
      and a **security drone** that hovers and moves around the wreck. Each is its own enemy definition in the
      base pack; what differs between them (movement, numbers, model, sounds) lives on the definition and its
      scene.

### Detection

Robots notice the player through sight, noise and contact. What a robot does once it notices something comes
under Behaviour.

- [x] **Sight.** A robot sees the parts of the player it has a line of sight to (the hitbox sample points from
      004, as the debug watchers check them) within its view cone and range: the turret about 20 m and 90°, the
      drone about 15 m and 120°. Exposure decides what a robot can see, and so what it can shoot.
- [x] **Darkness.** Robots see a lit part of the player at their full range, but an unlit part only within about
      5 m. A part is lit when enough light reaches it with nothing in between: from a lamp, a robot's searchlight,
      the player's flashlight or a muzzle flash. So the flashlight is a risk the player chooses, a robot's sweeping
      searchlight shows the player up when it passes over them, and every shot lights the shooter up for a moment.
      There is no HUD cue for it: the player judges it by the light they can see around them.
- [x] **Noise.** Noise is generic: anything can make a noise at a position with a loudness, the distance it
      carries. Robots within that distance hear it. Noises in the MVP:
      - player shots (a charged shot is louder);
      - player footsteps: sprinting is loud, walking quieter, crouching quietest (the cost of sprinting, instead
        of stamina);
      - the elevator's arrival ding (the `dinged` signal from 002);
      - robot shots, so a fight draws the robots nearby.
      Noise carries through walls but not between decks. New noise sources hook into the same system without
      changing the robots.
- [x] **Contact.** A robot that is hit, or that the player bumps into, notices the player at once, towards where
      the hit or touch came from.

### Behaviour

Both robots share the same states: **idle**, **investigating** (it noticed something but hasn't locked on to the
player), **attacking** (it has locked on) and **searching** (it lost sight of the player while attacking), and
finally **destroyed**. Each kind decides how it moves in each state.

- [x] **Turret.** Idle, it sweeps its arc. When it hears a noise it turns towards it and watches for a while.
      When it sees the player it tracks them and fires. When it loses them it holds its aim on where it last saw
      them for a few seconds, then goes back to sweeping. It can only turn within its arc.
- [x] **Drone.** Idle, it patrols a route in its area. When it hears a noise it flies to the spot to check it
      out. When it sees the player it keeps a fighting distance (about 6–10 m), strafes and fires. When it loses
      them it goes to where it last saw them, searches for a while, then returns to its patrol. Noise lures it,
      so the player can draw it into an ambush.
- [x] **Lock-on.** A robot doesn't fire the moment it sees the player: it first locks on, with a rising tone and
      its eye turning red. An idle robot takes about 0.8 s to lock on; one that is already investigating,
      attacking or searching takes about 0.4 s. When the lock completes it sounds the alarm, starts attacking and
      fires. Losing sight of the player drops the lock: before the lock completes the robot investigates where it
      saw them, and while attacking it starts searching, and has to lock on again when it sees them next. A quick
      peek is safe, lingering isn't, and catching a robot unaware is rewarded. (In 004 a player aiming out round a
      corner and a watcher saw each other at almost the same moment, so this delay decides who shoots first.)

### Fire

- [x] Robots fire red lasers (005's enemy colour) that hit instantly, like the player's. Each shot aims at a part
      of the player the robot can see. A hit does 10 damage times the multiplier of the part it lands on
      (head 2×, body 1×, arm 0.5×), so ten body hits kill: the player has to get through many fights in a run.
      (Changed in the playtest from about 35, three body hits.)
- [x] **Aim.** Right after locking on a robot's fire is wide (turret about 8°, drone about 6°), and it walks in
      the longer the robot keeps the player in sight, down to about 4° and 2.5° after 1.5 s; losing sight resets
      it. A robot also aims at where the player was 0.2 s ago, so moving draws misses and holding still gets you
      hit. Brief exposures and dashes between cover are survivable; lingering in the open isn't. (Added in the
      playtest: the first robots were far too accurate, and 12° to 4° over 2 s with a 0.3 s lag then felt too
      forgiving. At 5.5 m the turret now hits about 41% of shots at a still player and 36% at a walking one.)
- [x] **Overheat and vent.** Every shot heats the robot, and the heat cools off while it isn't firing. At full
      heat it has to vent for about 2 s: it can't fire, it hisses and its vents glow. Venting is the player's
      window to fight back.
- [x] The turret fires fast (about 3 shots a second) and has to vent after about 6 shots in a row. The drone fires
      slower single shots (about 1 a second) and rarely needs to vent. All of these numbers live on the enemy
      definitions.

### Health and weak spots

- [x] Robots take damage through hitboxes (005), and each has a sensor eye that takes 2× damage.
- [x] **Turret:** armoured, 200 health. The housing takes 0.5×, the eye 2×. A fully charged shot to the eye
      destroys it in one hit, so the player pre-charges behind cover, aims out and takes the shot before the
      turret locks on. Plinking the housing takes 16 uncharged shots.
- [x] **Drone:** fragile, 75 health. The body takes 1×, the eye 2×: three uncharged body hits, two to the eye,
      or one charged shot anywhere.
- [x] **Destroyed.** At 0 health a robot sparks and shuts down with a dying whine as its eye goes dark. The drone
      drops and crashes to the floor; the turret slumps on its mount. It smokes for a while, and the wreckage stays
      for the rest of the run. The crash is a noise that other robots hear.

### Placement and navigation

- [x] Enemy markers say what can go there: a **turret mount** (on the ceiling, facing the middle of the turret's
      arc) or a **drone post** (on the floor). Sections get turret mounts where a turret makes sense.
- [x] The small wreck picks which markers get which robot, by enemy ID through the content registry, so it plays
      the same way every run. It starts with about 2 turrets and 2 drones; the other markers stay empty. Filling
      markers by difficulty comes with missions, after the MVP.
- [x] Drones find their way with navigation built when the wreck loads, after assembly has opened the doorways,
      so it works across section seams. They stay on their own deck (no elevators) and don't enter vents, so vents
      are the player's escape route. Automatic doors open for drones as they do for the player.
- [x] A drone patrols through points around its post, within its patrol area (about 12 m). A noise it can't reach
      draws it to the nearest point it can.

### Look and sound

The player hears and sees a robot's tells before the robot itself.

- [x] **Idle sound.** The drone hums and the turret's servos whir as it turns. Both are positional and carry
      through walls.
- [x] **Voice lines.** Synthesised robot chirps, not speech: a questioning chirp when it starts investigating, an
      alarm when it spots the player, and a falling tone when it loses them, so the player can locate a robot and
      tell what it is doing.
- [x] **Searchlight.** Each robot's eye casts a spotlight that sweeps the dark with it, coloured by state: cold
      white idle, amber investigating or searching, red attacking. Its eye and a glowing band round its body take
      the same colour, so its state shows from every side. In a dark corridor the player sees its light round the
      corner before the robot.
- [x] **Combat music.** A simple music loop fades in when a robot starts attacking and fades out a few seconds
      after no robot is attacking any more. Investigating and searching don't start it. Exploring stays silent.
- [x] Low-poly models made by Blender scripts in `art-source/`: a turret hanging from the ceiling (mount, a ring
      that turns, a head that tilts, with the eye, the emitter and vents) and a hovering drone (body, thrusters,
      eye, emitter, vents).
- [x] Placeholder sounds generated by Python scripts: drone hum, turret servo, the three chirps, lock-on tone,
      robot shot, vent hiss, a hit on a robot, the destruction (whine and crash), player footsteps (walk, sprint,
      crouch) and the combat music loop.

### Test level and tests

- [x] A robot test level, `scenes/test/robot_test.tscn`: a small wreck built from kit sections on one deck, with
      lit and dark stretches, a turret mount and a drone post, filled through the wreck's enemy list like the small
      wreck. Robots in test levels show their state, lock and heat above them; the real wreck doesn't.
- [x] The debug exposure watchers stay in the player test level's cover area for the exposure tests of 004 and
      005; robots don't replace them there.
- [x] Unit tests cover the robot rules (state changes on sight, noise, contact, losing sight and timeouts; lock-on
      time by state; heat and venting; the turret's arc), hearing (distance and decks) and the light level (range,
      cone, shadow and threshold).
- [x] Scene tests in the robot test level: an idle turret takes longer to lock on than an alert one, a quick peek
      isn't shot but makes the robot investigate, a robot fires and damages the player once locked, the turret
      vents after about 6 shots, a charged shot to the eye destroys the turret, the drone patrols, flies to a
      noise, keeps its fighting distance and passes an automatic door, an unlit player is only seen up close and
      the flashlight shows them at full range, destroyed robots stay as wreckage, combat music starts and stops
      with attacking, and the base pack check registers both robots.

## Out of scope

- Other enemy types (humans, aliens) and other robots (maintenance machines): idea backlog and later features.
- Missions filling markers by difficulty, random placement and blueprints (after the MVP).
- Robots using elevators or vents, changing decks, taking cover, flanking or coordinating beyond hearing each
  other's shots. Alarms that call in more robots (escalation, after the MVP).
- Salvaging, looting or breaking down robot wreckage (007 and later).
- Robots noticing the flashlight's light on walls without seeing the player, and sound muffled by walls or doors.
- HUD cues for being seen, heard or lit, and hit markers on robots.
- Explosions and splash damage.
- New controls: 006 adds none, so the Controls table doesn't change.

## Technical notes

- **Files.** `game/scenes/enemies/`: `EnemyDefinition` (a `ContentDefinition`: the robot's scene, its mount and
  the brain's numbers: health, sight, lock-on, fire, heat, attention, loudness), `RobotMind` (node-free and
  stateful, like `ThermalClips`: the states, the lock-on with its sight memory, and the attention timers),
  `RobotRules` (node-free: the view cone and range, the dark sight range, how wide it fires, how a turret aims and
  turns), `AimTrail` (node-free: where the player was the aim lag ago), `RobotHeat` (node-free: heat, cooling and
  venting), `Robot` (the shared brain, a `CharacterBody3D`: senses, mind, fire,
  health, searchlight, eye and vent glow, voice lines, wreckage), `Turret` and `Drone` extending it for how each
  moves, and `CombatMusic`. `game/scenes/combat/`: `Hearing` (static: `make_noise()` reaches every Node3D in the
  `noise_listeners` group within the noise's loudness on the same deck, which reacts in `hear_noise()`; not called
  `Noise`, which is a Godot class) and `LightLevel` (static: the light reaching a point from the visible lights in
  the `sight_lights` group, mirroring Godot's omni and spot attenuation and spot cone and weighted by the colour's
  luminance, with a shadow ray against `world`; 0.15 or more counts as lit).
- **Content.** `content/base/enemies/turret/` and `content/base/enemies/drone/`, each with its definition, scene,
  `.glb` and its idle sound, registered as `base:turret` and `base:drone`. The sounds both robots share (chirps,
  lock-on, shot, vent, hit, destruction, crash) are in `game/assets/audio/robots/`. Movement numbers (the turret's
  arc, turn and sweep speeds and tilt; the drone's hover height, speeds, patrol radius and pause, fighting distance
  and strafing) are exports on the scene's root. Hitbox multipliers stay on the scene's hitboxes; the eye is a
  `HEAD` hitbox that sticks out of the housing or hull, so a shot at it hits it first.
- **Robot scenes.** The root is the `Turret` or `Drone`, with unique nodes `%Eye` (where it sees and fires from,
  facing −Z, with `%Searchlight` under it), `%Health`, `%Model`, `%Label` and the sounds. The turret's `%Ring` and
  `%Head` are pivots; at ready the model's `Ring` and `Head` meshes are moved under them, so turning a pivot turns
  its part. Each robot gets its own copies of the model's `Eye` and `Vents` materials, so its eye and the glowing
  bands (also `Eye`) show its state colour and its vents glow while venting.
- **Physics.** A new layer 5, `enemy`, for drone bodies. Shots and sight ignore it (they hit the robots' hitboxes),
  the player and drones collide with it, and door proximity and doorway areas mask it, so automatic doors open
  for drones. A turret is out of reach, so its body is on no layer while it works (on `enemy` it would hold a door
  below it open). A destroyed robot moves to `world`, so its wreckage blocks shots and sight and takes scorch
  marks; a fallen drone rests on a flat-topped box the player can step over.
- **Waking up.** CSG shapes rebuild at the end of the frame, so on a wreck's first frame the walls the sockets
  changed aren't there yet. Robots stay switched off until a physics frame after that, or they would see through
  the walls and floors.
- **Markers and placement.** `SectionMarker` gains a `mount` (`FLOOR` for drone posts, `CEILING` for turret
  mounts), and an `EnemyDefinition` says which mount it needs. The large and small rooms and the straight corridor
  get a `TurretMount` (the large room's is off-centre, clear of its pillar). The `Wreck` gets an `enemies` list
  (marker path to enemy ID) and places each robot on its marker after assembly, named after its kind and section
  (`Turret_Hold`). Markers that aren't enemy markers, unknown IDs and wrong mounts are assembly errors. Robots find
  the player through the `player` group.
- **Navigation.** The wreck bakes one navigation region per deck, deferred to the end of its first frame (after
  the CSG rebuild), from the collision faces of the navigable sections' CSG shapes (`Section.navigable` is off for
  vents and the elevator). Door panels and the elevator platform are bodies, not CSG, so they never block it. Each
  deck bakes only a slice from 0.5 m below its floor to 2.4 m above it, so ceiling tops never count as floor. The
  agent is 2 m tall (no navigation in vents) with a 0.375 m radius, and the navigation cell size is 0.125 m (a
  project setting, read directly because the map only takes it at its first update), so 1.2 m doorways stay open.
  A drone asks for paths with `NavigationServer3D.map_get_path` from the floor point below it (never from the top
  of something it hovers over), keeps its patrol and investigate points on its own deck, and holds its hover height
  with a spring.
- **Senses.** Every physics frame a robot checks the player's active hitbox sample points against its cone, range
  (full when the part is lit, the dark range when not) and line of sight. `Player.is_part_lit()` works out once per
  physics frame which parts are lit (all of them while the flashlight is on). A sight memory (0.25 s) keeps a point
  flickering at the edge of cover from dropping the lock. Health's `damaged` signal and the drone's `%Contact`
  area (mask `player`) feed contact. A robot fires only at points it sees this frame, shifted back by how far the
  player moved over the aim lag (`AimTrail`, recorded every physics frame in game time, so the lag holds at any
  tick rate), and only when its eye faces that point within the definition's aim tolerance, so the turret has to
  turn to track. Its spread (`RobotRules.aim_spread`) goes from `initial_spread` to `spread` over `settle_time`
  seconds of attacking, and resets when it stops.
- **Noise sources.** `Weapon` (`shot_loudness` and `full_charge_loudness` on `WeaponDefinition`), the player's
  footsteps (one per half stride, loudness per movement state, exported on the player), `Elevator` on arrival
  (`ding_loudness`), and robots (shots, crash). Starting loudness: shot 20 m, full charge 30 m, sprint step 10 m,
  walk step 4 m, crouch step 1.5 m, ding 20 m, robot shot 20 m, crash 12 m (turret) and 15 m (drone).
- **Lights.** Ceiling and emergency lamps, the pistol's muzzle light, robot searchlights, the elevator's platform
  light and the player test level's sun join `sight_lights` in their scenes. The flashlight doesn't need to: it
  shows the whole player.
- **Combat music** is an `AudioStreamPlayer` in the player scene that counts the attacking robots in the `robots`
  group every physics frame, holds on for 4 s after the last one and fades out over 3 s.
- **Models and sounds.** `art-source/models/turret.py` (objects `Mount`, `Ring` and `Head`; pivots at 0.12 m and
  0.30 m below the ceiling, matching the scene) and `drone.py` (one `Body`); materials `Eye` and `Vents` light up.
  `art-source/audio/robot_sounds.py`, `footsteps.py` and `combat_music.py` share `synth.py`; the hum, servo and
  music loop seamlessly and are imported looping.
- **Test level.** `scenes/test/robot_test.tscn` is a `Wreck`: a dark entrance stub, a lit corridor, an automatic
  door into a lit hall (room_large) with the turret and the drone, and a vent from the hall to a closet the drone
  can't reach. `debug_robots` shows each robot's state, lock and heat above it.
- **Tests.** Unit: `tests/enemies/robot_mind_test.gd`, `robot_rules_test.gd`, `robot_heat_test.gd`,
  `aim_trail_test.gd`,
  `tests/combat/hearing_test.gd`, `light_level_test.gd`. Scene: `tests/enemies/turret_test.gd` and
  `drone_test.gd` in the robot test level (each takes the other robot out), `wreck_test.gd` (placement and its
  errors), `small_wreck_test.gd` (the four robots and both decks' navigation; it then takes the robots out so they
  don't shoot the player during the movement tests), and the base pack check registers both robots.

## Done when

- [x] All requirements are checked.
- [x] Playtested in the running game.
- [x] Roadmap status updated to `done`.
