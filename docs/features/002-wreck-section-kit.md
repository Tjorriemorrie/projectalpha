# 002 — Wreck section kit

| Field     | Value |
|-----------|-------|
| Status    | done |
| Milestone | MVP |
| Depends on | 001 |

## Goal

A small kit of greybox sections (corridors, rooms, an airlock, a vent) with connection points, and one small quiet wreck assembled by hand from them.

## Player experience

Tight, dark corridors that build suspense (see Art direction). Proves the modular-section approach behind blueprints.

## Requirements

### Grid and dimensions

- [x] Sections fill whole 4×4 m grid cells. Connection points (sockets) sit at the centre of a cell edge, at
      floor level, facing out of the section.
- [x] Corridors are 2 m wide and 2.5 m tall inside. Doorways are 1.2 m wide and 2.2 m tall, vents 1.2 × 1.2 m
      inside, and decks are 4 m apart (floor to floor).

### Kit pieces

- [x] Corridors: straight, corner, T-junction and end cap.
- [x] Rooms: small (1 cell, 4×4 m) and large (2×2 cells, 8×8 m).
- [x] Airlock: 1 cell, whose outer hatch is the boarding point.
- [x] Vents: straight, corner, and a wall grate that joins a vent to a corridor or room.
- [x] Elevator: a 1-cell shaft spanning two decks, with doors on both decks.

### Sockets and assembly

- [x] Every socket has a kind: a **corridor** end, a **vent** end, or a **wall** that can open up. Corridor
      ends join corridor ends or walls, and vent ends join vent ends or walls. A wall joined to a corridor gets
      a doorway with its section's door; a wall joined to a vent gets a wall grate. Corridor side walls only
      take vents.
- [x] Walls that aren't joined stay solid. When the wreck loads, it reports as errors any loose corridor or vent
      end, sockets that face each other with kinds that can't join, sockets off the grid, and overlapping
      sections.
- [x] Sections carry enemy-spawn and loot markers, which stay empty until 006 and 007 fill them.

### Doors

- [x] Joins between corridors stay open. Rooms and the airlock's inner door have automatic sliding doors.
- [x] An automatic door opens when the player comes within about 1.5 m and closes about 2 s after they leave.
- [x] A closed door blocks movement and sight.
- [x] A door never closes on the player: it waits until its doorway is clear.

### Lighting

- [x] Almost no ambient light. Sparse, dim white ceiling lamps every 4–8 m leave it near pitch black between them,
      and some of them flicker.
- [x] Red emergency lights near the airlock and the elevator.
- [x] Lights work across section seams: no light leaks through walls into neighbouring sections.
- [x] Flashlight: a spot light from the camera. F toggles it on keyboard and D-pad up toggles it on gamepad (wired
      after the MVP). It has no battery and starts switched off.

### Interact

- [x] New `interact` action: press E (gamepad A / Cross is allocated and wired after the MVP).
- [x] Looking at an interactable within 2 m shows a prompt at screen centre (e.g. "E  Call elevator"), and
      pressing E uses it. A small centre dot shows where the player is looking. 007 reuses this for loot
      containers.

### Elevator

- [x] Each deck has a call button beside the elevator doors. Pressing it calls the platform; when the platform
      is already at that deck, the doors open.
- [x] A button on the platform closes the doors and sends it to the other deck.
- [x] On arrival the doors open automatically with a ding (a placeholder tone), and close a few seconds after
      the player leaves.
- [x] A deck's doors only open while the platform is at that deck, so the shaft is never open.
- [x] The elevator emits a signal when it dings, so enemies can later hear it and come to investigate.

### The small wreck

- [x] 14 sections over two decks, laid out as below (top view, one box per 4 m cell, north up). On each deck a
      vent gives a crouched back way in: into the small room on deck 1, and into the large room on deck 2,
      bypassing its door.

      ```text
      DECK 1 (board here)                      DECK 2
              x0     x1     x2     x3                  x0     x1     x2     x3
       z0          [SMALL]~[vent]~[vent]        z0   [  LARGE  ]d=[STR]==[CRN]
                     d                ~         z1   [  ROOM   ]~[vent]~~[STR]
       z1   [AIR]d=[ T ]==[ T ]==[CRN]                                     |
                            |       |           z2                       [ELV]
       z2                 [END]   [ELV]

      = open join   d sliding door   ~ vent (crouch)   ELV spans both decks
      ```

- [x] The player starts in the airlock, facing its inner door. The wreck replaces the greybox test level as
      the main scene.

### Tests

- [x] Unit tests cover the socket joining rules and the assembly checks.
- [x] Scene tests load the wreck and check that it assembles without errors, that an automatic door opens and
      closes, that the player can crouch through a vent but not walk through it standing, the elevator's
      call, ride and ding, the interact prompt and the flashlight.

## Out of scope

- Blueprints and procedural assembly: the wreck is placed by hand (post-MVP).
- Registering sections in the content registry: that is 003, which also settles the content folder layout.
- Enemies, loot and navigation meshes: the markers are placed, 006 and 007 fill them.
- Sounds other than the placeholder elevator ding (doors, ambience, footsteps).
- Real art: everything is greybox (Godot primitives with the grid material).
- Locked doors, keycards, hull breaches and damaged sections.
- Boarding from the ship and extraction through the airlock (008).
- Gamepad wiring, a flashlight battery, and robots noticing the beam (idea backlog).

## Technical notes

- **Coordinates.** Cell centres sit on multiples of 4 m in x and z; deck *n* has its floor at y = 4n. A section's
  origin is the centre of its footprint at floor level, and its `size` export gives its footprint in cells
  (x, decks, z). Sockets face outwards along their local −Z.
- **Files.** `game/scenes/sections/`: `section.gd` (`Section`), `socket.gd` (`Socket`, a `@tool` script so walls
  show in the editor), `section_marker.gd`, one `.tscn` per kit piece, and shared parts in `parts/` (sliding door,
  lamps, interactable button). `game/scenes/wreck/`: `wreck.gd` (`Wreck`) and `small_wreck.tscn`.
  `game/scripts/wreck_assembly.gd` (`WreckAssembly`) holds the node-free joining rules and checks.
- **Geometry.** Static parts of a section are `CSGBox3D`s under one `CSGCombiner3D` with collision. A wall
  socket builds its own wall in code: solid, with a doorway, or with a vent mouth (plus a short duct when the
  wall is inset, as on corridor sides). Before assembly every wall socket is solid.
- **Assembly.** On `_ready`, `Wreck` collects the sockets of its sections, pairs those at the same position that
  face each other, applies the openings and reports errors, then calls `Section.assembled()` so sections like
  the elevator can pick up the doors their sockets built.
- **Doors.** `SlidingDoor`: an `AnimatableBody3D` panel that slides sideways into the wall, a doorway area that
  holds it open while the player stands in it, and, for automatic doors, a proximity area. The elevator drives
  its doors itself.
- **Interaction.** `Interactable` is an `Area3D` on a new `interactable` physics layer, with a prompt and an
  `interacted` signal. The player casts a 2 m ray from the camera each physics frame; walls block it. The prompt
  and centre dot live in `game/ui/hud.tscn`, owned by the player scene.
- **Lights.** Ceiling and emergency lamps are shadow-casting spot lights pointing down, so walls stop them.
  Whether a lamp flickers is decided from its position, so the same lamps flicker on every run.
- **Ding.** `art-source/audio/elevator_ding.py` generates `game/assets/audio/elevator_ding.wav`.

## Done when

- [x] All requirements are checked.
- [x] Playtested in the running game.
- [x] Roadmap status updated to `done`.
