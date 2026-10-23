# 012 — Star map and travel

| Field     | Value |
|-----------|-------|
| Status    | done |
| Milestone | post-MVP |
| Depends on | 011 |

## Goal

The player buys antimatter and jumps between the star systems of a fixed cluster, on a star map that shows all of
it, and buys intel to see what is in a system before jumping there.

## Player experience

Turns one system into a journey (see Travel and fuel and Finding her in
[game-design.md](../game-design.md#travel-and-fuel)). Antimatter is rare and takes time to arrive, so the player
boards ships in a system to afford it and to fill the wait, then jumps on. Early on, when he can only take on
couriers, filling the tank costs the loot of a run or two, so the first systems take a couple of runs. The delivery
wait is a day for now; the design has it grow through the game, which the tuning pass decides. The whole map is
visible, but not what is in each system: intel shows which ships are worth the jump.

## Requirements

- [x] Antimatter is bought at the hub and isn't on the shelf: it is ordered and paid for at once, and arrives at the
      hub after a delivery delay. A full tank costs about the loot of a courier run or two, since early on the player
      can only take on couriers. There is one order at a time and no cancelling it. Nothing stores antimatter but the
      ship's tank, and an order always fills it: every empty unit, or nothing when the wallet can't pay for them all.
      First numbers, for the tuning pass: ₿100 a unit (₿1,000 a full tank), give or take the hub's 5%, flat all game;
      the delay is fixed at a day for now, whatever the amount (whether it grows through the game is for the tuning
      pass). A new game starts with 2 of the 10 units, too little for any jump (the shortest burns 5), and ₿500, too
      little to fill the tank (about ₿800), so the first system already needs a run.
- [x] It is ordered at the trader terminal: hydrogen and antimatter share a FUEL placard, each a gauge with its
      button, ORDER showing the price of what the tank is missing and once ordered the day it arrives
      ("ARRIVES DAY 7").
- [x] The antimatter waits at the hub until the player collects it there: once it has arrived, ORDER reads
      "COLLECT · 8", and a click fills the tank at once while its gauge fills a block every 0.1 s (FILLING), the
      ship's bar with it; closing the screen cuts the animation short, not the antimatter. The ship jumps only from the
      hub: it has to fly back to the hub, on hydrogen, to jump. A docked wreck stays behind in its system, unboarded.
      A jump is refused while antimatter is on order or waiting to be collected, which it would leave behind, paid
      for.
- [x] A jump burns antimatter by distance, as a flight burns hydrogen: the tank holds 10 units and a jump burns a
      unit per light year, rounded up, so a full tank reaches any system within 10 light years and a short jump leaves
      some behind for the next. A jump takes a day. The galaxy's jumps run from 4.1 to 9.8 ly (5 to 10 units).
- [x] After a jump the drive recharges for a day, so even with antimatter left the player boards at least one ship in
      every system before jumping on.
- [x] The star map shows the whole cluster from the start, with about five systems in jump range of any system.
      There is no fog of war.
- [x] Intel: the hub sells intel on another system, which shows its ships and stations and their details, as the
      system map (011) does, before the player jumps there. Without it, a system's ships show only on arrival.
      The hub sells intel only on systems within jump range (10 ly) of its own that haven't been revealed yet, for
      ₿200 each, give or take its 5%: checking all five or so neighbours costs about a run's loot. Systems already
      visited need none: the star map remembers what the player left there. Intel is bought on the star map, where he
      chooses: BUY INTEL with its price on a selected system in range, only at the hub (away from it, it says to buy
      it at the hub). Pointing at a known system on the star map lists its ships in the side column, a row each (e.g.
      "Hauler · about 5 robots"); selecting it and switching to the system map tab shows its orbital map read-only:
      its places and wrecks, with their details on pointing, but no ship, course or FLY.
- [x] A system's ships and stations are rolled when they are revealed, on arrival or when intel on it is bought, and
      stay as rolled from then on: 6 to 8 of them, as in 011. Rolling at that moment lets the hidden pacing pick the
      mix later (out of scope here); the mix is a tuning lever (see the tuning pass in
      [roadmap.md](../roadmap.md#idea-backlog)).
- [x] Every system keeps what is left in it when the player jumps away, and its hub its prices: no new ships turn up
      while he is gone, nor just because it runs low. But a system never strands him: after every run, on arrival and
      on ordering, while the ship can't jump on yet, easy ships (level 1) turn up when
      - he is waiting for a delivery or for the drive to recharge and fewer ships are left than days still to wait:
        enough to cover the wait;
      - the tank holds too little for the shortest jump out of the system and he can't afford to fill it (the bitcoin
        in the wallet plus what the stash, and the kit carried home from a run, would sell for at the hub) and fewer
        than three are left: until it holds three or four.

      If he can afford the antimatter but hasn't ordered it, nothing turns up.
- [x] The galaxy is fixed and hand-made ([galaxy.md](../galaxy.md)): its star systems and their positions are
      content, loaded through the content registry like everything else. All 50 systems were built in 011. The start
      system is random, on the outer ring (011 starts in any system), picked by a random direction as
      [galaxy.md](../galaxy.md#4-the-map) says. Her location waits for triangulation, the first feature that uses it.
- [x] Every system has a trader hub, and no system is riskier or richer than another.
- [x] The star map is a second tab on the system map's screen, on the same dark scope, north (the core worlds) up and
      deep space down, with a 10 ly scale bar: all 50 systems as small star glyphs in their star's colour, the
      territories as faint tinted halos (in galaxy-map.svg's colours), and the ship as the laser-blue ring round the
      current system. Around it, a dashed 10 ly circle and a lane to each system in range with the antimatter that
      jump burns, red when the tank can't do it. Visited systems are filled, with the route so far as a faint trail.
      Names show for the systems that matter from here (in range, visited, known, and the one pointed at or
      selected), so the chart stays readable, and every known system shows how many ships it holds. Pointing at a
      system shows its name, star and owner, its distance and the jump's antimatter, and its ships if known (else that
      intel on it is sold at a hub in range); a click selects it, with BUY INTEL and JUMP in the side column.
- [x] Jumping: the screen fades to black over a jump sound and back in at the new system's hub, a day later, on the
      new system's map, which says where the ship arrived. The cockpit console and the trader terminal name the new
      system and its hub.
- [x] At home a bar across the top of the screen shows the bitcoin, the hydrogen, the antimatter (with an order's
      "8 ARRIVING DAY 7", or "8 READY AT THE HUB" once it has arrived) and the day. It stays over the trader hub, the
      maps and the inventory, which make room for it, so the wallet shows while buying intel on the star map, and the
      day ticks on with a jump. The maps add no fuel readouts of their own beyond the gauge of what a flight or a jump
      burns.
- [x] Controls, with one new action (switching tabs): interact on the cockpit console opens the map on the system
      map tab (E / A); Q switches tabs, as does a click on a tab's header (LB or RB, or A on a header); the pointer
      moves as in the inventory (mouse / left stick); pointing at a system shows its details and the jump there, and a
      click selects it (LMB / A); a click on BUY INTEL buys intel (LMB / A); holding JUMP for a second, while the
      button fills, jumps (LMB / A held), as holding interact on the airlock boards: both cost a day; Tab, Esc or E
      close it (View or B), but not during a jump. ORDER and COLLECT on the hub's screen are clicks (LMB / A). In the
      Controls
      table in [game-design.md](../game-design.md#controls); the gamepad bindings wait for gamepad support.
- [x] From playtesting: turrets turn all the way round (360°), not half a circle. On the system map a flight takes
      half a second a unit of hydrogen (at least a second), and the gauge and the ship's bar burn a unit at each share
      of the way (a 3-unit flight, one every third), while the thrusters roar for exactly as long (an ignition, a loop
      and a stop as the ship arrives; sounds now last as long as their animations, a rule in CLAUDE.md, so the jump's
      sound was cut to its 1.8 s fade); FLY waits for the flight. The rule that a flight must leave enough
      hydrogen to get back to the hub (011) stands, and away from the hub with no wreck in reach the map says so: "Low
      on hydrogen: ... Fly back to the hub to buy more."
- [x] Tests cover ordering, waiting for and collecting antimatter, jumping (its burn, range and the drive's
      recharge), buying intel, ships turning up when the player would be stranded, and the random start system.

## Out of scope

- Her location, triangulating her ping, her messages, the countdown and the hidden pacing.
- The cure's ingredients, the company's ships and the android stock.
- Saving the game.
- Jumping further than the neighbours on the jump network (in the idea backlog).

## Technical notes

- **Galaxy.** `Galaxy` (`scenes/galaxy/`, node-free) works on `StarSystemDefinition.map_position` (light years):
  `distance()`, `antimatter_between()` (a unit per light year, rounded up), `in_range()` (within `JUMP_RANGE`, 10 ly,
  nearest first), `outer_ring()` (`OUTER_RING`, 28 ly) and `pick_start()` (the ring system nearest a random
  direction; any system when none is on the ring).
- **Prices.** `Trader.antimatter_price()` and `intel_price()` (`ANTIMATTER_VALUE` ₿100, `INTEL_VALUE` ₿200, both
  within the hub's ±5%), and `Trader.DELIVERY_DAYS` (1). `GameSession.order_antimatter()` orders every empty unit or
  nothing; a new game starts with `GameSession.STARTING_ANTIMATTER` (2).
- **Session.** `GameSession` keeps `antimatter` (`ANTIMATTER_TANK` 10), the order (`order_units`, `order_day`),
  `drive_ready_day` (`RECHARGE_DAYS` 1), `revealed` (every system revealed, by ID, with what is left in it), `route`
  and each visited system's hub. `arrive_in()` reuses a known system and hub; `reveal()`, `known_system()`,
  `has_visited()`; `check_jump()`/`jump_to()` (`Jump` reasons), `order_antimatter()`, `collect_antimatter()`,
  `check_intel()`/`buy_intel()` (`Intel` reasons), `wait_days()` and `ship_worth()`.
  `_keep_from_stranding()` runs on arrival, on ordering and in `continue_to_ship()`, adding `EASY_LEVEL` wrecks with
  `StarSystem.add_wrecks(..., level)`. Signals `antimatter_changed` and `day_changed`; `ship_moved` also fires on a
  jump.
- **Screens.** `MapScreen` (`ui/`) is the new base of both map tabs: the tab headers, buttons, status line and
  centring, and `tab_requested`, which the `Hud` answers by closing one tab and opening the other quietly
  (`MenuScreen._switching`: no fade, no sound). `SystemMapScreen.open(viewing)` shows another known system read-only
  (`SystemMapView.show_ship` off). `StarMapScreen` and `StarMapView` are the star map; its logs use 🌌. Holding JUMP
  emits `jump_confirmed`, and `Player.jump_to()` fades out over `jump.wav` (`art-source/audio/ship_sounds.py`), calls
  `GameSession.jump_to()`, has the HUD show the arrival on the system map (`Hud.show_arrival()`) and fades in. The
  player reads Q (`map_tab`) like Tab and Esc, since the screens only get mouse events. The trader screen's FUEL
  placard holds both tanks; `TraderScreen.collect()` fills the gauge a block every `FILL_STEP` and emits
  `antimatter_shown`, which the bar follows. The HUD's `Wallet` is the ship's bar, full width at the top; every
  `MenuScreen` keeps `top_inset` clear for it.
- **Tests.** `tests/galaxy/galaxy_test.gd`, `travel_test.gd` (the session), `star_map_test.gd` (real mouse events
  and Q through the console), and the trader and trader screen suites.

## Done when

- [x] All requirements are checked.
- [x] Playtested in the running game.
- [x] Roadmap status updated to `done`.
