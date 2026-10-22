# 011 — System map

| Field     | Value |
|-----------|-------|
| Status    | planned |
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

- [ ] A system map shows the system's trader hub and its ships and stations, at its planets, moons, asteroids,
      anomalies and battlefields.
- [ ] Inspecting a ship or station shows its details, never a difficulty level: its wreck type, the expected number
      of robots still active in its security system (010) and the gear it requires; later kinds add human enemies,
      how quickly it escalates, and so on. The player judges the risk from them.
- [ ] Hydrogen, bought at the hub and always on the shelf, flies the ship between locations. Flying takes no time.
- [ ] The day counter: boarding a ship or station takes a day, whether the android extracts or dies, and days only
      pass by boarding (and jumping, in 012).
- [ ] A ship the android died on is gone for good.
- [ ] TBD: where the player opens the system map (the cockpit console that reads "Star map offline" since 008?).
- [ ] TBD: how many ships and stations a system has, and how they are rolled from the wreck variety of 010.
- [ ] TBD: job-board leads at the hub.
- [ ] TBD: keyboard/mouse and gamepad controls for the system map, decided together and added to the Controls table.
- [ ] Tests cover flying, hydrogen use, the day counter and ships disappearing after a death.

## Out of scope

- Jumping to other systems and antimatter (012).
- Triangulation, her messages, the countdown and the hidden pacing.
- The company's ships and their encrypted drives.
- Location requirements (e.g. oxygen for breached wrecks).

## Technical notes

- The ship's cockpit (008) has a pilot seat and a console whose screen reads "Star map offline", put there for this.
- `GameSession` already handles travel between the ship and the wreck; the system map adds which wreck to board.

## Done when

- [ ] All requirements are checked.
- [ ] Playtested in the running game.
- [ ] Roadmap status updated to `done`.
