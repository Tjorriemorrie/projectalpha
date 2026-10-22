# 009 — Trader hub

| Field     | Value |
|-----------|-------|
| Status    | done |
| Milestone | post-MVP |
| Depends on | 007, 008 |

## Goal

The player can sell loot for bitcoin and buy kit at a trader hub, so every extraction pays off.

## Player experience

Supports *Everything is salvage*: until now loot only piles up in the stash, with values that are just totalled.
After this feature the player extracts, sells what is worth selling, buys thermal clips and guns, and boards again.
The hub is a menu, not a place to walk around. It also sets the prices that fuel, androids and the cure's
ingredients will be measured against later.

## Requirements

- [x] A bitcoin wallet, kept in the session and never lost. The player starts with a little bitcoin, ₿500 (see
      Progression and difficulty in [game-design.md](../game-design.md#progression-and-difficulty)). Every amount is
      bitcoin, shown with the ₿ symbol.
- [x] At home on the ship the HUD shows the bitcoin in the wallet, top left; not on a wreck, and not while the hub's
      screen (which shows its own) is open.
- [x] Sell items for bitcoin, priced from each item's value.
- [x] Selling pays the item's value (1×) and buying costs twice its value (2×). Stock is unlimited.
- [x] Prices differ a little per hub: each item's price varies by up to ±5% at each hub, the same factor for
      selling and buying, from the hub's seed, so the same hub always quotes the same price. With one hub for now,
      the seed is rolled when the game starts. Real tuning waits for full playthroughs (see the idea backlog).
- [x] The hub sells everything in the game: every registered item, thermal clips and guns included.
- [x] The laser pistol becomes an item: carried in the inventory, lost on death like everything else, and bought
      at the hub to stock up.
- [x] A weapon slot: the inventory screen gets a WEAPON placard above the pockets that holds one gun, the one in
      hand. With the slot empty the player is unarmed (nothing in view, no shooting). Guns are swapped by dragging,
      on the ship from the stash, on a wreck from a container or the floor. A gun keeps its loaded clip's heat
      wherever it goes; a new gun (bought, looted or in the starting kit) comes with a fresh clip loaded.
- [x] No more free kit after a death: the game starts with the basic kit (the pistol and clips) in hand, but the
      next clone wakes empty-handed and arms from the stash. With no gun and no bitcoin he boards unarmed, picks an
      easy wreck and hopes to loot a gun and extract, so it solves itself. One of the small wreck's containers
      holds a laser pistol for that.
- [x] A trader terminal on the ship, next to the stash: interact opens the hub menu. In the fiction it is a comms
      link to the system's hub, and drones carry the cargo both ways (see Setting in
      [game-design.md](../game-design.md#setting)), which is why the player can sell from a console.
- [x] Sell from the stash only: the hub screen shows the trader and the stash. The player drags items from the
      stash into the trader's sell crate, sees the offer, and presses SELL to confirm. Loot carried back from a run
      goes into the stash first. Items left in the crate when the screen closes go back to the stash.
- [x] Bought items go to the first free spot in the stash. A buy is refused when there is no room (until the stash
      has no size limit; see the idea backlog in [roadmap.md](../roadmap.md)).
- [x] Controls as in the inventory, with no new actions: interact on the terminal opens the hub (E / A); the
      pointer moves and drags as in the inventory (mouse / left stick, LMB hold / A hold, rotate RMB / RB, mirror
      MMB or wheel / LB); clicking an item on the shelf buys one, and clicking SELL sells the crate (LMB / A); Tab,
      Esc or E close it (View or B). In the Controls table in [game-design.md](../game-design.md#controls).
- [x] Unit and UI tests cover the wallet, selling and buying.

## Out of scope

- Fuel: hydrogen comes with the system map (011), antimatter with the star map (012).
- Buying androids (the android stock comes later).
- Armor and other gear (idea backlog).
- Asking for the cure's ingredients, and the hub stills about her (story features).
- Breakdown, crafting and saving.

## Technical notes

- **Prices.** `Trader` (`scenes/trade/`, node-free) holds a hub's title and price seed: `sell_price()` is value × 1
  × the item's factor, `buy_price()` value × 2 × the same factor (never below 1), and `price_factor()` is seeded from
  the hub's seed and the item's ID, within ±5%. `Trader.shelf()` orders every registered item: weapons first, then
  the cheapest up. There is no hub definition in the registry: the shelf is every item, so a mod adds stock by adding
  items.
- **Session.** `GameSession` keeps the wallet (`bitcoin`, `STARTING_BITCOIN` 500, `bitcoin_changed`), the system's
  `trader` (rolled in `new_game()`), the sell `crate` (6×4) and `basic_kit_next`. `sell_crate()`, `buy()` and
  `return_crate()` do the trades, since the stash and wallet live there. The kit's heat parameter is gone from
  `board()` and `extract()`: the heat rides on the gun item.
- **Guns as items.** `WeaponDefinition` extends `ItemDefinition`, so the pistol registers once as both (shape
  `##`/`.#`, value 200) and its item model is `laser_pistol_item.glb`, the same mesh laid flat by
  `art-source/models/laser_pistol.py`. `Item.clip_heat` is a gun's loaded clip; `ThermalClips.heat` reads and writes
  it on its `gun`. `Inventory.weapon` is a `WeaponSlot` (3×2, one weapon only). The player re-arms whenever the slot
  changes (`_arm()`); `Weapon.unequip()` cancels a reload under way (`ThermalClips.cancel_swap()`) so swapping guns
  never speeds one up. The small wreck's store room locker holds a pistol.
- **Screens.** `GridScreen` (`ui/`) is the shared base of the inventory and hub screens (dragging, card, placards,
  hints, layout); `InventoryScreen` adds the WEAPON placard. `TraderScreen` shows the crate with its offer and SELL,
  the shop (`ShopView`, icon tiles with buy prices, red when unaffordable), the wallet (ticks to its new amount with
  the change fading beside it) and the stash, with a status line for each deal or refusal. Its logs use 💰.
- **Bitcoin.** Every amount shown goes through `Bitcoin.format()` (`scripts/bitcoin.gd`): `₿1,240`, `−₿50`,
  `+₿154`. The ship's player has `shows_wallet` on, so its HUD shows the wallet (`Hud.show_wallet()`, updated from
  `GameSession.bitcoin_changed`).
- **Terminal.** `TraderTerminal` (`scenes/ship/`, model `trader_terminal` from `ship_props.py`) stands beside the
  stash; its `Interactable` ("Trade") calls `Player.open_trader()`.
- **Tests.** `tests/trade/trader_test.gd` (prices) and `trader_screen_test.gd` (the terminal and the screen through
  real mouse events); the session, inventory, weapon, ship and extraction suites cover the wallet, the weapon slot
  and the kit rules.

## Done when

- [x] All requirements are checked.
- [x] Playtested in the running game.
- [x] Roadmap status updated to `done`.
