# 005 — Weapon and player health

| Field     | Value |
|-----------|-------|
| Status    | done |
| Milestone | MVP |
| Depends on | 001, 003 |

## Goal

The player has one weapon, a semi-automatic laser pistol cooled by thermal clips (shoot, aim down sights,
reload), and health that takes about ten hits to run out, so the player can get through many fights in a run.

## Player experience

Combat that wears the player down over a run: a single fight rarely kills, but health doesn't come back until the
next clone, so the hits add up. Supports *Lose it all*.

## Requirements

### Laser pistol

- [x] The MVP weapon is a semi-automatic laser pistol: one shot per click, at most 3 shots a second.
      Lasers hit instantly along the line of fire.
- [x] Holding the trigger charges the shot, which fires on release. The longer it is held, the more damage it
      does, the more it kicks and the more heat it puts into the clip. A quick click fires an uncharged shot with
      minimal kick. Steady shots beat spamming.
- [x] Starting numbers (tuned in the playtest): an uncharged shot puts 5% heat into the clip
      (20 per clip) and kicks the view up 0.5°. The charge fills over 1 s; a full charge puts 15% heat into the
      clip, does 4× the damage and kicks 3°. A part charge scales in between. A full charge is the better deal per
      heat, so it rewards patience and punishes being rushed.
- [x] A charge can't put more heat into the clip than the clip has room for: it stops growing when the clip would
      be saturated. Holding a full charge keeps it ready until release.
- [x] The pistol is content: a weapon definition in the base pack, loaded through the content registry (003).
      Its numbers (heat, charge, damage, kick, spread, zoom, reload time) live on the definition, and its folder
      holds its model, viewmodel scene and sounds. Gameplay code never hard-codes the pistol.

### Thermal clips

- [x] Every shot heats the pistol, and the loaded thermal clip soaks up the heat. A clip's heat is a percentage,
      not a count of rounds; a fully charged shot uses at most 15% of a clip. When the clip is saturated the
      pistol can't fire until the player reloads, which swaps it for a fresh clip.
- [x] A spent clip goes back to the player's carried clips as salvage instead of being dropped.
- [x] The player can reload before the clip is saturated, but the clip is wasted: it goes back as spent, however
      much heat it had left. That punishes panic reloads.
- [x] The pistol and its clips are tracked as counts on the player until the grid inventory exists (007): the
      loaded clip's heat, fresh clips carried and spent clips carried.
- [x] Reloading is slow and tactical: it takes 3 s, and the clips are swapped at the end.
      While reloading the player can walk, crouch and peek, but can't shoot, aim down sights or sprint.
      Once started, a reload runs to the end. Reloading with no fresh clips, or with an unused clip loaded,
      does nothing.
- [x] The player starts with a fresh clip loaded and 4 spare (about 100 uncharged or 33 fully charged shots).
      The real loadout and where clips are found come with 007 and 008.

### Aim and accuracy

- [x] Shots spread randomly around the centre dot, enough that fights have misses and feel like a gun battle,
      even though every hit counts. Hip fire lands within about 5° of the centre dot; aiming down sights
      tightens that to about 1°.
- [x] Holding right click aims down sights: a slight zoom (about 1.3×), movement slowed to crouch speed
      (1.0 m/s), and no sprint. Aiming out of cover (004) aims down sights too.
- [x] The pistol is lowered while sprinting. Pulling the trigger ends the sprint and raises the pistol, and
      charging or firing starts once it is up (about 0.25 s). Sprint stays blocked while the trigger is held and
      for a moment after a shot.
- [x] A peek can't shoot (004): the trigger does nothing while peeking. A charge being held is kept through a peek
      and keeps building, so the player can charge behind cover, peek and aim out to fire; released while the
      player can shoot it fires, released during a peek it is dropped with no heat used. Dying drops it. (Changed
      in 007's playtest: a charge used to be cancelled the moment the player couldn't shoot, and pressing peek with
      aim held is a peek until the head moves, so pre-charging and aiming out lost the charge.)

### Player health

- [x] The player has 100 health. A hit does the shooter's damage (robots set theirs in 006: 10, so ten body hits
      kill) times a multiplier for where it lands: head 2×, body 1×, arm 0.5× (exported variables). The hitboxes
      from 004 decide where a hit lands. (Changed in 006's playtest from about 35, three body hits, so the player
      can survive the many fights of a run.)
- [x] Health doesn't regenerate during a run. A new clone starts at full health (008); healing items come later.
- [x] At 0 health the player dies: controls stop, the view slumps to the floor and fades to black, and the run
      ends. The player emits a `died` signal. Waking up as a new clone on the home ship is 008; until then the
      level reloads in its place.
- [x] Getting hit flashes the screen edges red, a red marker at the screen edge points towards where the shot
      came from, the view flinches slightly and a hit sound plays. While one more body hit could kill, the screen
      edges stay faintly red.

### Controls

- [x] Shoot is left click on keyboard and mouse, and right trigger on gamepad: tap to fire, hold to charge.
      Aim down sights is right click (hold) / left trigger (hold). Reload is R / X (Square). All of them are in
      the Controls table in [game-design.md](../game-design.md#controls); gamepad is wired after the MVP.

### HUD

- [x] Classic corner indicators, always visible. Bottom left: a health bar with the number. Bottom right: a heat
      gauge for the loaded clip, with the counts of fresh and spent clips. The gauge turns red when the clip has no
      room for a full charge, and it shows the reload's progress.
- [x] A thin ring around the centre dot fills while a shot charges.

### Look and sound

- [x] A low-poly pistol modelled by a Blender script in `art-source/`, with a glowing emitter and a clip that
      pops out. It is held at the bottom right of the view, comes to the centre when aiming down sights, dips for
      the reload while the old clip pops out and a fresh one slots in, and its emitter glows brighter while
      charging.
- [x] Player lasers are cold blue-white (robot lasers will be red, so the two are easy to tell apart). A shot is
      a brief beam from the muzzle to the hit point, with a muzzle light that lights up the corridor for a moment
      and so gives the player's position away, sparks at the impact and a scorch mark that stays for the rest of
      the run (on doors and elevators too, moving with them).
- [x] Placeholder sounds generated by Python scripts: shot, charged shot, charge hum, reload (clip out, clip in),
      dry click when the clip is saturated, and the hit on the player.

### Test level and tests

- [x] Shooting targets stand in the test level: each has health, flashes when hit, breaks at 0 and resets after a
      few seconds. What a shot can damage (targets now, robots in 006) is generic, not specific to targets.
- [x] The debug exposure watchers from 004 get an optional fire switch: when on, they shoot a red laser at a part
      of the player they can see every couple of seconds, with spread. They stand in for robots until 006, to test
      health, hit direction and death against exactly what the player exposes.
- [x] Unit tests cover the weapon rules (heat, damage and kick for a charge, how far a charge can grow, spread,
      saturation, reloads and wasted clips) and health (location multipliers, death once). Scene tests in the test
      level: shooting a target damages it, a charged shot does more, the fire rate is capped, a peek can't shoot,
      a reload takes its time and swaps the clips, the trigger ends a sprint, and a firing watcher damages and
      kills the player.

## Out of scope

- Other weapons, switching or holstering weapons, melee, and salvage tools as weapons (idea backlog).
- Thermal clips as inventory items: picking them up, finding them in containers, and re-cooling, breaking down or
  selling spent clips (007 and post-MVP).
- Robots, their health and their damage (006). Enemies noticing shots, muzzle light or noise (006 and the idea
  backlog).
- Waking up as a new clone on the ship, and the run's loot being lost (008).
- Healing items, armour, and health regeneration.
- Wiring the gamepad bindings (after the MVP).
- A visible player body or arms beyond the pistol, and hit markers on the crosshair.
- Ricochets, penetration and bullet drop: lasers stop at the first thing they hit.

## Technical notes

- **Files.** `game/scenes/weapons/`: `WeaponDefinition` (the weapon's numbers and its viewmodel scene),
  `WeaponRules` (node-free: what a charge costs and does, how far it can grow, spread and shot direction),
  `ThermalClips` (the loaded clip's heat and the fresh and spent counts), `Weapon` (the node under the player's
  camera that reads `shoot`, `aim` and `reload`, fires and reloads), `WeaponViewmodel` with `viewmodel.gdshader`,
  and `LaserEffects` (beam, sparks, impact flash, scorch decal). A scorch mark is a child of the surface it hit, so
  it moves with doors and goes when the level reloads; at most 256 are kept (the oldest goes) and they fade out
  beyond 25 m. Viewmodels draw on visual layer 20 (`viewmodel`), which decals leave out. `game/scenes/combat/`: `Health`, and `Hitbox`, moved
  from `scenes/player/` and made generic: each hitbox has a damage multiplier and the `Health` it damages.
- **Content.** `content/base/weapons/laser_pistol/` holds `laser_pistol.tres`, the viewmodel scene, the `.glb` and
  the sounds. The player looks the weapon up by `weapon_id` (`base:laser_pistol`).
- **Charging.** A pull starts the charge; the charge grows after `charge_delay` (0.15 s, so a quick click stays
  uncharged) over `charge_time`, capped by the clip's room, and fires on release. A pull waits up to 0.3 s for
  the weapon to be ready (raised after a sprint, or the fire rate allowing the next shot), and a click released in
  that time still fires, uncharged. Every shot adds bloom (1° per shot, settling at 2°/s, at most 3°), so steady
  shots beat spamming.
- **Shots** are rays from the camera along the view, spread evenly over a disc of the spread angle, against
  `world` and `hitbox` (areas), excluding the shooter's own hitboxes. The first hit wins; a `Hitbox` passes the
  damage on. The beam is drawn from the viewmodel's muzzle to the hit point.
- **Viewmodel.** The pistol's materials are swapped at load for a shader that pulls depth towards the near plane,
  so the pistol never pokes into walls but is still lit (and shadowed) by the world. Its origin is the rear sight,
  so the aim pose lines the sights up on the centre dot. Poses (hip, aim, lowered, reload) are exported on
  `WeaponViewmodel`; the clip slides along the grip's own axes from the model.
- **Model.** `art-source/models/laser_pistol.py` builds three objects (`Body`, `Emitter`, `Clip`) with the
  materials `Metal`, `Polymer`, `Emitter` and `ClipHeat`; the viewmodel finds the glowing ones by material name.
  The clip's heat band glows from blue to orange with the loaded clip's heat.
- **Sounds.** `art-source/audio/laser_pistol.py` (shot, charged shot, looping charge hum, clip out, clip in, dry
  click) and `combat_sounds.py` (player hit, watcher shot), sharing `synth.py`. The hum's import loops it.
- **Death.** `Health.died` makes the player drop the weapon and hitboxes, slump the camera, fade the HUD to black
  and emit `died`; after 4 s the level reloads (`reload_on_death`, off in tests).
- **HUD.** `game/ui/`: `HealthBar`, `HeatGauge` (one segment per uncharged shot, the charge's cost blinking in the
  laser's colour), `ChargeRing`, `HitMarkers` and `screen_edges.gdshader` for the red edges. `Hud.key_label()`
  now serves both the interact prompt and the reload hint.
- **Test level.** `scenes/test/shooting_target.tscn` (four targets north of the start), and the two cover-area
  watchers have `fire_enabled` on. Suites that don't want fire turn it off in `before_test`.
- **Tests.** `tests/weapons/weapon_rules_test.gd`, `tests/combat/health_test.gd`, `tests/weapons/weapon_test.gd`
  (scene tests), `tests/weapons/laser_effects_test.gd` (scorch marks stay, move and are capped), and the base pack
  check registers the pistol.

## Done when

- [x] All requirements are checked.
- [x] Playtested in the running game.
- [x] Roadmap status updated to `done`.
