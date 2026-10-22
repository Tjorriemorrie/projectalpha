# 010 — Wreck variety

| Field     | Value |
|-----------|-------|
| Status    | planned |
| Milestone | post-MVP |
| Depends on | 002, 003, 006, 007 |

## Goal

Ships differ: loot is rolled every run and there is more than one wreck layout, so choosing which ship to board
(011) means something.

## Player experience

Supports *Choose your risk, against the clock*: the system map will offer several ships, and that choice only
matters if they differ in layout, size, robots and loot. Today there is one wreck with fixed robots and fixed loot,
so every run plays the same.

## Requirements

- [ ] Loot tables: container contents are rolled each run, with bigger containers rolling better loot, filled to
      suit the wreck's difficulty (promoted from the idea backlog; 007 kept every wreck's loot fixed).
- [ ] More than one wreck layout. TBD: hand-assembled from the section kit for now, or blueprint-based generation
      (see Levels / content in [game-design.md](../game-design.md#4-levels--content)).
- [ ] Robots placed to suit each wreck's difficulty. TBD: how.
- [ ] TBD: how many layouts, their sizes and the difficulty levels.
- [ ] Tests cover rolling loot and building each layout.

## Out of scope

- The system map and choosing a ship (011).
- Doomed, breached and contested wrecks (timer, oxygen, escalation).
- The company's ships and their encrypted drives.
- Large stations.

## Technical notes

- Sections, robots and loot already load through the content registry (`base:<name>`), and containers fill loot
  markers; loot tables would replace the fixed contents.
- Blueprints are described in the Modding section of [game-design.md](../game-design.md#modding): a blueprint says
  how a ship class assembles the sections, and missions populate it.

## Done when

- [ ] All requirements are checked.
- [ ] Playtested in the running game.
- [ ] Roadmap status updated to `done`.
