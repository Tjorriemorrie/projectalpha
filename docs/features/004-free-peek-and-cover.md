# 004 — Free peek and cover

| Field     | Value |
|-----------|-------|
| Status    | done |
| Milestone | MVP |
| Depends on | 001, 002 |

## Goal

The player can hold Alt and move the mouse to peek out of cover in any direction, and hold right click to aim
out from behind cover to shoot.

Two levels of exposure:
- **Peek (Alt):** look only, can't shoot, and a small exposure makes the player hard to hit.
- **Aim out of cover (right click):** can shoot, but a bigger exposure makes the player easier to hit.

## Player experience

Cover-based combat where exposing yourself is a risk you control. Supports *Choose your risk*.

## Requirements

### Cover

- [x] There is no cover system and no snapping: cover is just level geometry. The player takes cover by moving
      behind something (crouching behind a crate, standing beside a doorframe or corner) and peeks from there.
      Peeking and aiming out work anywhere, in cover or not.

### Peek (Alt)

- [x] Holding Alt separates the head from the body (free-look leaning, as in Rogue Point's cover peeking):
      moving the mouse moves the head within a limited range instead of turning, so it can lean around a corner
      or rise over cover while the body stays behind it. The body and the view direction stay put. Releasing Alt
      returns the head to the body smoothly.
- [x] The head moves up to 0.4 m left or right, 0.35 m up and 0.15 m down from its normal position, the same
      standing or crouched. Rising from a crouch lifts the eyes from 0.85 m to 1.2 m, enough to see over
      waist-high (1 m) cover. All of these are exported tuning variables.
- [x] The head never passes through walls or cover: it stops where it would touch them.
- [x] Leaning sideways tilts the view slightly towards the lean, growing with how far the head is out: 0° when
      centred, up to 8° at the full 0.4 m (an exported variable, which can be set to 0).
- [x] The player can move while peeking, at crouch speed (1.0 m/s), and can't sprint: sprint does nothing until
      Alt is released.
- [x] Head bob is off while peeking or aiming out. The flashlight and the interact ray move with the head.
- [x] Peeking is look-only: the player can't shoot while peeking (enforced by 005, which reads the peek state).

### Aim out of cover (Alt + right click)

- [x] Holding right click while peeking pushes the head and shoulder further out in the direction of the peek,
      far enough for the weapon to clear the cover: up to 0.6 m sideways or 0.5 m up (exported variables).
      The player can shoot while aiming out.
- [x] While aiming out, the mouse turns the view as normal, so the player can aim; the head holds its aimed-out
      position. Releasing right click drops back to the peek (the mouse moves the head again), and releasing Alt
      returns the head to the body.
- [x] Holding Alt and right click together aims out whichever was pressed first: aiming and then peeking works
      the same as peeking and then aiming. Aiming out needs a direction to lean in, so while the head is still
      centred it is a peek (the mouse moves the head), and it aims out as soon as the head moves off-centre.
      (Changed in 006's playtest: aim held before Alt used to stay a peek, which couldn't shoot.)
- [x] Right click without Alt is plain aim down sights (005), with no extra exposure.
- [x] Aiming out allows the same movement as peeking: crouch speed, no sprint.

### Controls

- [x] Peek is Alt (hold) on keyboard and Left bumper (hold) on gamepad, where the right stick moves the head.
      Aim out is right click (hold) / Left trigger (hold) while peeking, the same button as aim down sights.
      Both are hold-only. Gamepad is wired after the MVP; both are in the Controls table in
      [game-design.md](../game-design.md#controls).

### Exposure

- [x] Exposure is physical, with no hidden hit-chance numbers: the player has hitboxes, and enemies (006) can
      only hit the parts they can see. A head hitbox follows the camera, a body hitbox covers the body, and a
      shoulder/arm hitbox only comes out while aiming out. A peek therefore exposes just the head, and aiming out
      exposes the head, shoulder and arm.
- [x] The player exposes its hitboxes and its peek state (none, peeking, aiming out), and signals when the peek
      state changes, so weapons (005) and robots (006) can use them without changing the controller.

### Test level and tests

- [x] The greybox test level gets a cover area: a waist-high (1 m) crate, a tall pillar and a doorframe corner.
- [x] Debug watchers stand in the cover area (test level only): each draws a red line to every part of the
      player's hitboxes it can see, glows red while it sees any part, and shows above itself which parts
      (head, body, arm) it sees. They stand in for robots until 006, to check that exposure is fair.
- [x] Unit tests cover the peek rules (range, aim-out direction, state changes, tilt); scene tests drive the
      player in the cover area: the head stops at walls, peeking slows movement and blocks sprint, a
      watcher sees only the head while peeking and the head and arm while aiming out, and slicing the pie round
      the doorframe while aiming out never lets the player see a watcher that can't see them.

## Out of scope

- A cover system: snapping to cover, cover detection or cover markers in sections.
- The weapon, shooting and aim down sights (sights, zoom): 005. Until then right click only matters while peeking.
- Damage, health and hit reactions (005), and robots seeing and shooting the player (006).
- Wiring the gamepad bindings (after the MVP).
- A visible player body, arms or weapon: the hitboxes have no visuals (the debug watchers show what they see).
- Sounds or noise for peeking.

## Technical notes

- `game/scenes/player/peek_rules.gd`: the node-free decisions (`PeekRules`): the elliptical head range (with
  separate up and down reach), when the head counts as centred, the aim-out offset, the peek state and the tilt.
  `MovementRules` gains the peek's crouch-speed cap and sprint block.
- The head offset lives in the body's yaw frame (x right, y up). Mouse motion while peeking feeds
  `Player.move_head()`, which the gamepad's right stick will call too. Each physics frame the head moves towards
  its target at `head_speed`, and a sphere `cast_motion` from the normal eye position against `world` stops it at
  walls. The camera interpolates the head between physics frames, like the body.
- `PeekRules.next_state()`: peek and aim held with the head off-centre aim out, in either order, and stay out
  until either is released.
- Hitboxes: `Hitbox` (`game/scenes/player/hitbox.gd`), an `Area3D` per part on a new `hitbox` physics layer (4),
  positioned by the player every physics frame. Each one offers sample points (its centre and a point towards each
  side) to check line of sight against; enemies (006) will aim at the points they can see.
- Input actions `peek` (Alt) and `aim` (right mouse button).
- `game/scenes/test/exposure_watcher.tscn` and `.gd`: the debug watcher, which casts rays against `world` from
  its eye to every sample point of the player's active hitboxes.
- The cover area is in the south-east corner of `game/scenes/test/player_test.tscn`, away from the 001 tests.

## Done when

- [x] All requirements are checked.
- [x] Playtested in the running game.
- [x] Roadmap status updated to `done`.
