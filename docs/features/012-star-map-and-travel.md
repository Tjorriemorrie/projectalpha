# 012 — Star map and travel

| Field     | Value |
|-----------|-------|
| Status    | planned |
| Milestone | post-MVP |
| Depends on | 011 |

## Goal

The player buys antimatter and jumps between star systems on a star map under fog of war, which grows with
pre-made systems as he travels.

## Player experience

Turns one system into a journey (see Travel and fuel and Finding her in
[game-design.md](../game-design.md#travel-and-fuel)). Antimatter is rare and expensive and takes days to arrive, so
the player boards about five ships in a system to afford it and to fill the wait, then jumps on. The fog of war
keeps the way ahead unknown.

## Requirements

- [ ] Antimatter is bought at the hub and isn't on the shelf: it arrives after a delivery delay of some days, which
      grows through the game. It costs about five runs' loot.
- [ ] A jump to a neighbouring system uses antimatter and takes a day.
- [ ] Fog of war: the player sees the star map up to about two jumps, with 5-6 systems in jump range.
- [ ] Pre-made star systems are content, loaded through the content registry like everything else, and are picked
      at random from a pool without repeats as the fog lifts. TBD: how many to build for now (the design aims at
      about 25).
- [ ] Every system has a trader hub, and no system is riskier or richer than another.
- [ ] TBD: the star map's look, and keyboard/mouse and gamepad controls, decided together and added to the Controls
      table.
- [ ] Tests cover buying and waiting for antimatter, jumping, the fog of war and picking systems from the pool.

## Out of scope

- Triangulating her ping, her messages, the countdown and the hidden pacing.
- The cure's ingredients, the company's ships and the android stock.
- Saving the game.

## Technical notes

- Star systems as content follow the content and modding approach in
  [technical-design.md](../technical-design.md#content-and-modding).

## Done when

- [ ] All requirements are checked.
- [ ] Playtested in the running game.
- [ ] Roadmap status updated to `done`.
