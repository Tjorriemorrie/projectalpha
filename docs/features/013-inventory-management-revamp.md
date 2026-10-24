# 013 — Inventory management revamp

| Field     | Value |
|-----------|-------|
| Status    | done |
| Milestone | post-MVP |
| Depends on | 007, 008, 009 |

## Goal

Managing loot gets quicker and simpler: items sit in square slots that each hold a stack of one kind, instead of
tetris shapes in a grid; the run summary can unload the haul into the stash in one go; selling takes a click, like
buying; and shortcuts move and split stacks.

## Player experience

Less fiddling with shapes, more deciding what is worth a slot, and quicker turnarounds between runs: unload, sell
and go. Supports *Everything is salvage*. Sorting on a wreck is quicker too, but still done standing still while
robots roam, so it stays part of *Choose your risk*.

## Requirements

### Slots instead of the grid

- [x] The tetris grid goes: every item takes one square slot, and a slot holds a quantity of one kind of item (a
      stack). Shapes, rotating and mirroring go with it.
- [x] Containers have slots by size, so the size still hints at the haul: the small case 3, the supply crate 6 and
      the locker 9 (today 3×2, 4×3 and 4×5 cells). Robot wreckage has 2, for its two parts. Rolled loot merges into
      stacks; budgets stay in bitcoin as in 010, and a roll also stops when the slots are full. The player can leave
      things in a container.
- [x] The floor becomes slots the same way: it grows to keep a spare row of empty slots below whatever lies there.
      It shows two rows and the stash four; taller ones scroll with the wheel, with a thin bar beside them.
- [x] The ship's stash has no size limit: it grows to fit, always keeping a spare row of empty slots after the
      last one in use, so storing loot, unloading a haul and buying at the hub never need room. 009's refused buy
      goes. Stacks keep their sizes in the stash.
- [x] Every item definition has a stack size, set by its bulk (roughly from its old shape): small things stack
      high and bulky ones low, so a slot is worth its item's value times the stack, and packing still matters.
      Starting sizes, tuned in the playtest:

      | Item | Value | Stack | Full slot |
      |------|-------|-------|-----------|
      | Data drive | 150 | 5 | 750 |
      | Circuit board | 60 | 4 | 240 |
      | Conduit | 30 | 3 | 90 |
      | Servo motor | 70 | 3 | 210 |
      | Gyroscope | 160 | 2 | 320 |
      | Hull plating | 40 | 2 | 80 |
      | Plasma coil | 180 | 2 | 360 |
      | Power cell | 120 | 2 | 240 |
      | Thermal clip | 25 | 5 | 125 |
      | Spent thermal clip | 10 | 5 | 50 |
      | Guns | — | 1 | — |
- [x] The player carries four sets of slots (starting sizes, tuned in the playtest):

      | Slots | Count | Holds |
      |-------|-------|-------|
      | Weapon | 1 | The gun in hand, as in 009 |
      | Ammo | 2 | Thermal clips only, fresh or spent; reloads take fresh clips from here |
      | Pockets | 2 | Anything; meant for things needed at hand later (meds, grenades) |
      | Backpack | 6 | Anything (halved from 12 after the first build: too much loot fitted) |

- [x] Each slot is a square showing the item's icon fitted into it (the models keep their shapes and are still
      rendered top-down), with the count in a corner once there is more than one.
- [x] Dropping a stack on a stack of the same kind tops it up to its size, and the rest goes back where it came
      from. Dropping it on a different item bumps, as before: nothing swaps.
- [x] A stack dropped on the floor lies there as one object ("Pick up 3 circuit boards") and clatters once.
- [x] The item card shows the name, the picture, the value of one, the stack ("3 / 4"), what the slot is worth and
      the description; size in cells and value per cell go. Under the player's slots the screen totals the bitcoin
      carried and the free slots.
- [x] The first clone's 2 spare fresh clips start as one stack in an ammo slot.

### Ammo and reloads

- [x] A reload takes a fresh clip off a stack in the ammo slots only; clips in the pockets or the backpack have to be
      moved to the ammo slots first, as with 007's pockets.
- [x] The spent clip that comes out goes onto a spent stack with room in the ammo slots, else into a free ammo slot,
      else onto a spent stack or a free slot in the pockets or the backpack, else it drops on the floor with its
      clatter (007's 3 m noise). A reload always works, but a full bag makes it loud. On the ship, which has no
      floor, it goes into the stash.
- [x] The heat placard keeps "2 fresh · 2 packed · 0 spent", where packed are the fresh clips outside the ammo
      slots, and says "Move a clip to your ammo slots" when the gun is saturated with fresh clips only elsewhere.

### Unloading after a run

- [x] The run summary after an extraction offers to unload everything salvaged into the stash in one go, except the
      gun in the weapon slot and the clips in the ammo slots: the pockets and the backpack are emptied (the stash
      always has room). After a death there is nothing to unload, so the offer shows only after an extraction, and
      only when the pockets or the backpack hold something.
- [x] The card shows "[Q] Unload haul into stash" above "[E] Continue" (gamepad X / Square and A / Cross). Pressing
      unload moves the haul, and the line changes to say what went into the stash; continue then goes on to the
      ship. Skipping it wakes the player up still carrying it all, to sort at the stash as before.

### Selling

- [x] Selling at the trader hub takes one click, like buying: a click on an item in the stash sells one from its
      stack, and holding the click on it for a second (like JUMP on the star map) sells the whole stack. The status
      line shows each deal. The sell crate and SELL go. Selling still comes from the stash only.
- [x] A bought item tops up a matching stack in the stash first, else takes its first free slot.
- [x] Pressing an item and moving the pointer still drags it, so the stash can be rearranged at the hub; only a
      press and release without moving sells, and only a hold that stays still fills up to sell the stack.

### Shortcuts

- [x] Shortcuts move an item straight to the other side and split a stack, replacing 007's rule that loot only
      moves by dragging. Selling has its own click and hold (above).
- [x] **Quick move** sends a stack straight to the other side in one action (container ↔ backpack, stash ↔
      backpack, floor → backpack): shift + left click or a double-click, X / Square on the gamepad. It works
      everywhere, on wrecks too: the screen still keeps the player standing still while robots roam, so the time
      spent sorting stays the risk.
- [x] Toward the player, quick move tops up matching stacks first, then takes a free slot: clips go to the ammo
      slots, a gun to an empty weapon slot, anything else to the backpack and then the pockets. What doesn't fit
      stays where it was. Away from the player, it goes into the open container or the stash, else onto the floor.
      The hub's screen shows only the stash, so there it has nowhere to go and a double-click sells two.
- [x] **Splitting** takes half a stack (rounded up) into hand, and while it is held each step moves one more item
      into hand or one back to the slot it came from, between one and the whole stack; it is put down in an empty
      slot (or on a stack of the same kind) like any drag. Keyboard and mouse: drag with the right button, and turn
      the wheel up for one more, down for one fewer. Gamepad: RB on a stack takes half, RB and LB take one more and
      one fewer, and A puts it down. In the inventory and at the hub alike.

### Sound

- [x] No new sounds: selling and unloading use the place sound, splitting the pick sound.

## Out of scope

All in the roadmap's idea backlog:

- Armor, helmet and bigger-backpack slots (the armor and gear idea).
- Auto-sort in the inventory and the stash.
- Selling from what the player carries.
- Wiring the gamepad bindings.

## Technical notes

- **Slots.** `ItemGrid` stays, as a grid of square slots: a slot is addressed by its cell, and each `Item` is a stack
  (definition, `quantity`, cell, and a gun's `clip_heat`) that emits `changed` when its quantity changes, which the
  grid holding it passes on. `ItemShape`, orientations and reserved cells are gone. The grid places and removes
  stacks, `top_up()`s stacks of a kind, `add()`s (top up, then the first free slot), `add_one()`s, `take()`s part
  of a stack, says the `room_for()` a kind and `room_at()` a slot, and `ItemGrid.stow()` moves a stack across grids
  in order (top-ups first, then a free slot), which quick moves, spent clips and unloading use. A growing grid
  (`spare_rows` ≥ 0: the stash and the floor) resizes itself after every change to keep that many empty rows,
  never below the rows it was made with. `accepts()` limits a grid to some kinds: `WeaponSlot` (1×1) takes weapons
  and the new `AmmoSlots` takes `ItemDefinition.ammo` items.
- **Definitions.** `ItemDefinition` loses `shape` (and `CELL_SIZE`) and gains `stack_size`, `ammo` and
  `plural_name` (`name_for(quantity)`: "3 circuit boards"; hull plating stays "hull plating"). Containers' and
  robots' `grid_size`/`salvage_grid` are their slots: 3×1, 3×2, 3×3 and 2×1.
- **Inventory.** `Inventory` is the weapon slot, `ammo` (2×1), `pockets` (2×1) and `backpack` (6×1);
  `stow_order()` is where a stack moved to the player goes and `haul()` is what unloading takes. The player's
  exports are `ammo_size`, `pocket_size`, `backpack_size`, `starting_ammo_clips` (2) and `starting_backpack_clips`.
- **Clips.** `ThermalClips.take_fresh()` takes one off the first fresh stack in the ammo slots; the spent clip (or
  a fresh one put back by `cancel_swap()`) is stowed by the rule above, and with no room it emits `overflowed`:
  the player drops it (onto the open screen's floor if the inventory is open), or on the ship puts it in the stash.
- **The screens.** `GridScreen` drags whole stacks (`begin_drag`), splits them (`begin_split`, `adjust_drag(±1)`),
  tops stacks up or bumps in `drop_drag`, and quick-moves (`quick_move`, to `_quick_targets()`), on shift or
  double-click presses. Every move ends in `_on_moved()`, where the `InventoryScreen` compares the floor with what
  lay there before and emits `dropped_on_floor`, `floor_topped_up` or `taken_from_floor`, so the world follows
  whole drops, top-ups and part pickups alike. `ItemGridView` draws square slots (icon, count), the hand's target
  slot, and scrolls (`max_rows`). Slots are 6.5% of the screen height (44–80 px). Weapon and ammo share a row.
- **Selling.** `TraderScreen` holds a press on a stash stack as pending: release sells one, `SELL_HOLD_TIME` (1 s)
  still sells the stack with a ring round the pointer, and moving more than `DRAG_THRESHOLD` (6 px) starts a drag.
  `GameSession.sell(item, amount)` takes them off the stack and pays `Trader.sell_price()` each; `buy()` uses
  `add_one()`. The crate, `sell_crate()`, `return_crate()`, `offer_text` and SELL are gone; `Trader.offer()` counts
  every item in the stacks.
- **Unloading.** `GameSession.extract()` records the haul on the `RunSummary` (`haul_items`, `haul_value`);
  `GameSession.unload()` moves it into the stash and records `unloaded_items` and `unloaded_value`. The player reads
  the new `unload_haul` action (Q) while the summary waits, and `RunSummaryCard.show_unloaded()` changes the line.
- **Icons and dropped stacks.** `ItemIcons` renders 128 px square icons with the camera fitted round the model's
  bounds (`DroppedItem.model_bounds()`), and a `DroppedItem` collides as one box round its model.
- **Input.** `inventory_rotate` and `inventory_mirror` are gone; `inventory_split` (right button),
  `inventory_more` (wheel up), `inventory_fewer` (wheel down) and `unload_haul` (Q) are new.
- **Tests.** `item_grid_test.gd` and `inventory_test.gd` cover slots, stacks, growing grids and stowing; the clip
  tests in `weapon_rules_test.gd` cover the new reload; the screen suite covers splits, top-ups, quick moves (with
  real shift and double-click events) and the floor; `trader_screen_test.gd` covers click, hold and drag at the hub;
  `game_session_test.gd` and `extraction_test.gd` cover selling, buying onto stacks and unloading; the loot and ship
  suites cover a spent clip with no room on a wreck and on the ship. `item_shape_test.gd` is gone.

## Done when

- [x] All requirements are checked.
- [x] Playtested in the running game.
- [x] Roadmap status updated to `done`.
