# 012 — Star map and travel

| Field     | Value |
|-----------|-------|
| Status    | planned |
| Milestone | post-MVP |
| Depends on | 011 |

## Goal

The player buys antimatter and jumps between the star systems of a fixed cluster, on a star map that shows all of
it, and buys intel to see what is in a system before jumping there.

## Player experience

Turns one system into a journey (see Travel and fuel and Finding her in
[game-design.md](../game-design.md#travel-and-fuel)). Antimatter is rare and expensive and takes days to arrive, so
the player boards about five ships in a system to afford it and to fill the wait, then jumps on. The whole map is
visible, but not what is in each system: intel shows which ships are worth the jump.

## Requirements

- [ ] Antimatter is bought at the hub and isn't on the shelf: it arrives after a delivery delay of some days, which
      grows through the game. It costs about five runs' loot.
- [ ] A jump uses a tank of antimatter, reaches any system within 10 light years and takes a day.
- [ ] The star map shows the whole cluster from the start, with about five systems in jump range of any system.
      There is no fog of war.
- [ ] Intel: the hub sells intel on another system, which shows its ships and stations and their details, as the
      system map (011) does, before the player jumps there. Without it, a system's ships show only on arrival.
      TBD: which systems intel covers (those in jump range?), its price and how much it shows.
- [ ] A system's ships and stations are rolled when they are revealed, on arrival or when intel on it is bought, and
      stay as rolled from then on: 6 to 8 of them, as in 011. Rolling at that moment lets the hidden pacing pick the
      mix later (out of scope here); the mix is a tuning lever (see the tuning pass in
      [roadmap.md](../roadmap.md#idea-backlog)).
- [ ] Every system keeps what is left in it when the player jumps away: no new ships turn up while he is gone. When
      he comes back to a system with fewer than three ships left, easy ones (the lowest levels) turn up until it
      holds three or four, so he can always earn the antimatter to move on.
- [ ] The galaxy is fixed and hand-made ([galaxy.md](../galaxy.md)): its star systems and their positions are
      content, loaded through the content registry like everything else. All 50 systems were built in 011. The start
      system is random, on the outer ring (011 starts in any system), and her location (for triangulation, later) on
      the far half of the map.
- [ ] Every system has a trader hub, and no system is riskier or richer than another.
- [ ] TBD: the star map's look, and keyboard/mouse and gamepad controls, decided together and added to the Controls
      table.
- [ ] Tests cover buying and waiting for antimatter, jumping, buying intel and the random start system.

## Out of scope

- Triangulating her ping, her messages, the countdown and the hidden pacing.
- The cure's ingredients, the company's ships and the android stock.
- Saving the game.

## Technical notes

- Star systems as content follow the content and modding approach in
  [technical-design.md](../technical-design.md#content-and-modding). 011 built them (`StarSystemDefinition`, with
  `map_position` in light years) and the system map; `GameSession.arrive_in()` reveals a system and puts the ship at
  its hub, which a jump can reuse, keeping each visited system's `StarSystem` and hub.

## Done when

- [ ] All requirements are checked.
- [ ] Playtested in the running game.
- [ ] Roadmap status updated to `done`.
