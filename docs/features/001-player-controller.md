# 001 — Player controller

| Field     | Value |
|-----------|-------|
| Status    | done |
| Milestone | MVP |
| Depends on | none |

## Goal

The player can move through a space in first person: walk, look, sprint and crouch.

## Player experience

Deliberate, grounded movement suited to tense, careful exploration. Sprint is for escaping to extraction; crouch is for vents and cover.

## Requirements

### Movement

- [x] WASD moves the player relative to where they are looking; diagonal movement is not faster.
- [x] Heavy, deliberate feel: walk 1.5 m/s, sprint 3.0 m/s, crouch 1.0 m/s (tuned in the playtest).
- [x] About 0.15 s to reach full speed, and a short slide to a stop when the keys are released.
- [x] All speeds and acceleration values are exported tuning variables.

### Sprint

- [x] Hold Shift to sprint, only while moving forward (forward diagonals count). Releasing Shift or stopping
      forward input ends the sprint.
- [x] No stamina: the cost of sprinting will be noise that enemies can hear (see the idea backlog), not a meter.
- [x] Sprinting while crouched stands the player up if there is room; otherwise they stay crouched and can't sprint.

### Crouch

- [x] Ctrl crouches while held; C toggles crouch on and off.
- [x] Standing body 1.8 m tall with eyes at 1.65 m; crouched body 1.0 m with eyes at 0.85 m. Vents therefore
      need at least 1.1 m of headroom.
- [x] The camera moves smoothly between standing and crouched heights in about 0.2 s.
- [x] The player can't stand up without room: they stay crouched until there is space, then stand up
      automatically if crouch is no longer held or toggled on.

### Floors, obstacles and elevators

- [x] Gravity always applies; there is no jump and no fall damage.
- [x] The player steps up onto low obstacles up to 0.35 m (an exported variable) without jumping, such as bodies
      and broken robots on the floor. Anything taller blocks.
- [x] Stepping back down off an obstacle keeps the player on the floor, without bouncing or a short fall.
- [x] The player rides moving platforms (elevators) up and down without sliding, jittering or being left behind.

### Camera

- [x] Mouse look: moving the mouse sideways turns the body, moving it up and down tilts the camera, which stops
      just short of straight up and straight down. Raw input, no smoothing; sensitivity is an exported variable.
- [x] 90° horizontal field of view at 16:9; wider screens see more at the sides, not less at the top and bottom.
- [x] Subtle head bob while walking, slightly stronger while sprinting, none while standing still or
      crouch-walking. An exported on/off switch, for players who get motion sick.
- [x] The mouse is captured when the game starts. Esc releases it (there is no pause menu yet) and clicking in
      the window captures it again.

### Movement state

- [x] The controller exposes its current movement state (idle, walk, sprint, crouched idle, crouch-walk) and
      emits a signal when it changes, so later systems (noise, footsteps) can hook in without changing the controller.

### Test scene and tests

- [x] A greybox test scene with a 1.1 m crawl space, obstacles from 0.15 m to 0.5 m tall, an upper deck and an
      elevator between them. It is the main scene until 002 provides a real wreck.
- [x] GdUnit4 is installed and runs headless. Unit tests cover the movement state, forward-only sprint and the
      crouch hold/toggle rules.

## Out of scope

- Gamepad. Its bindings are allocated in the Controls table in [game-design.md](../game-design.md#controls) and
  wired post-MVP.
- Jump, prone, slide and lean (none of these exist in the game; peeking is 004).
- Stairs, ramps and ladders: decks are flat and connected by elevators.
- Stamina, movement noise and footstep sounds.
- Fall damage.
- A settings menu for sensitivity, field of view and head bob: they are exported variables only.
- A visible player body or arms.

## Technical notes

- Creates the Godot project in `game/` (see [technical-design.md](../technical-design.md) for engine settings).
- `game/scenes/player/player.tscn` and `player.gd`: a `CharacterBody3D` with its origin at the feet and a
  cylinder collision shape (radius 0.3 m). A flat bottom lands cleanly on top of obstacles when stepping up,
  where a capsule's rounded bottom would rest on the edge.
- `game/scenes/player/movement_rules.gd`: the pure decisions (movement state, sprint and crouch wishes), kept
  free of nodes so GdUnit4 can test them.
- Step-up: before `move_and_slide`, if the move is blocked, test a move up by the step height, forward, then down
  again with `test_move`; if it lands on a floor no higher than the step height, move the body there.
- Step-down: Godot's floor snap fails while the body still touches the edge it walked off, so after leaving the
  floor the controller looks for floor 5 cm further along and drops onto it if it is no deeper than a step.
  The camera smooths out both height changes.
- Crouch: the collision shape changes height at once; the camera follows over 0.2 s. Standing up first checks
  headroom with `test_move` upward using the crouched shape.
- Camera: a top-level `Camera3D` that follows the physics-interpolated body every rendered frame, so movement
  stays smooth on high refresh rate screens while mouse look applies instantly.
- `game/scenes/test/player_test.tscn` with `test_elevator.gd`, an `AnimatableBody3D` moving between the decks.
- Tests in `game/tests/player/`: unit tests for `MovementRules`, and scene tests that drive the player through the
  test scene (speeds, stopping, steps, the crawl space, the elevator) with `Input.action_press`.

## Done when

- [x] All requirements are checked.
- [x] Playtested in the running game.
- [x] Roadmap status updated to `done`.
