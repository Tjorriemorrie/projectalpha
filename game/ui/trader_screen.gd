class_name TraderScreen
extends GridScreen
## The trader hub's screen, part of the HUD (see GridScreen), opened from the ship's trader terminal: the hub on the
## left half, what the player owns on the right. The hub's side is the shop: every item, at the hub's buy price. The
## player's side is the wallet, the ship's fuel (the hydrogen tank with a FILL UP button, and the antimatter tank with
## an ORDER button), and the ship's stash. Clicking a stack in the stash sells one of it, and holding the click on it
## still for SELL_HOLD_TIME sells the whole stack (a ring fills round the pointer); pressing it and moving the pointer
## drags it instead, to rearrange the stash. Clicking an item in the shop buys one into the stash, FILL UP fills the
## hydrogen tank as far as the wallet pays, and ORDER orders the antimatter the tank is missing (every empty unit, or
## nothing), which arrives at the hub days later; once it has, the button reads COLLECT, and collecting it fills the
## gauge a block at a time (the tank itself is full at once, so closing the screen cuts only the animation). After
## every deal the wallet ticks to its new amount, with the change fading beside it, and a status line says what
## happened (or why it couldn't). The trades go through the GameSession, which keeps the hub, the stash, the tanks and
## the wallet. The player opens and closes it, only while the ship is at the hub.

## The antimatter gauge shows a new amount while collected antimatter fills it, so the ship's bar can follow it.
signal antimatter_shown(antimatter: int)

## Seconds the wallet takes to tick to a new amount, and the change beside it to fade out after it.
const TICK_TIME := 0.45
const DELTA_FADE_TIME := 1.4
## A shop tile's size, in slots.
const TILE_CELLS := 1.4
## Seconds a click on a stash stack is held still to sell the whole stack, and the pixels the pointer may move while
## it is held before the press becomes a drag.
const SELL_HOLD_TIME := 1.0
const DRAG_THRESHOLD := 6.0
## The ring that fills round the pointer while a sale of a whole stack is held.
const RING_RADIUS := 15.0
## Seconds each unit of collected antimatter takes to fill on the gauge.
const FILL_STEP := 0.1

## What the readouts say, for tests: e.g. "Sold 3 circuit boards for ₿180." and "₿500" (the amount the wallet is
## ticking to).
var status_text := ""
var bitcoin_text := ""
## What the tank readouts and their buttons say, for tests: e.g. "18/24", "FILL UP  ₿30", "2/10" and
## "ORDER  ₿800" (or "ARRIVES DAY 7", "COLLECT  ·  8" and "FILLING").
var hydrogen_text := ""
var fill_text := ""
var antimatter_text := ""
var order_text := ""

var _stash_view: ItemGridView
var _shop: ShopView
var _bitcoin: Label
var _delta: Label
var _stash_size: Label
var _hydrogen: Label
var _fuel_gauge: FuelGauge
var _fill_button: PanelContainer
var _fill_style: StyleBoxFlat
var _fill_label: Label
var _fill_hovered := false
var _antimatter: Label
var _antimatter_gauge: FuelGauge
var _order_button: PanelContainer
var _order_style: StyleBoxFlat
var _order_label: Label
var _order_hovered := false
var _fuel_note: Label
var _status: Label
var _shown_bitcoin := 0
var _tick: Tween
var _delta_fade: Tween
## The antimatter the gauge shows, which lags behind the tank while collected antimatter fills it.
var _shown_antimatter := 0
var _filling := false
var _fill_tween: Tween
## The stash stack a click was pressed on, which sells on release, or whole once held long enough; null when none.
var _pending: Item
var _pending_at := Vector2.ZERO
var _pending_time := 0.0


func _build() -> void:
	_stash_view = _make_view(InventoryScreen.LOOT_ROWS_SHOWN)
	_shop = ShopView.new()
	_left_column.add_child(_placard("SHOP", _label("Delivered to the stash", 12, DIM_TEXT_COLOR, false), _shop))
	_bitcoin = _label("", 24, INK_COLOR, false)
	_delta = _label("", 13, LASER_COLOR, true)
	# Room for the change, so the placard doesn't widen when it shows.
	_delta.custom_minimum_size = Vector2(64.0, 0.0)
	_right_column.add_child(_placard("BITCOIN", _delta, _bitcoin))
	var fuel_body := VBoxContainer.new()
	fuel_body.add_theme_constant_override("separation", 6)
	_fuel_gauge = FuelGauge.new()
	_hydrogen = _label("", 13, INK_COLOR, true)
	_fill_style = _button_style()
	_fill_button = PanelContainer.new()
	_fill_button.add_theme_stylebox_override("panel", _fill_style)
	_fill_label = _label("FILL UP", 13, INK_COLOR, true)
	_fill_button.add_child(_fill_label)
	fuel_body.add_child(_fuel_row("HYDROGEN", _hydrogen, _fuel_gauge, _fill_button))
	_antimatter_gauge = FuelGauge.new()
	_antimatter = _label("", 13, INK_COLOR, true)
	_order_style = _button_style()
	_order_button = PanelContainer.new()
	_order_button.add_theme_stylebox_override("panel", _order_style)
	_order_label = _label("ORDER", 13, INK_COLOR, true)
	_order_button.add_child(_order_label)
	fuel_body.add_child(_fuel_row("ANTIMATTER", _antimatter, _antimatter_gauge, _order_button))
	_fuel_note = _label("", 12, DIM_TEXT_COLOR, false)
	fuel_body.add_child(_fuel_note)
	_right_column.add_child(_placard("FUEL", _label("Hydrogen flies, antimatter jumps", 12, DIM_TEXT_COLOR, false),
		fuel_body))
	_stash_size = _label("", 12, DIM_TEXT_COLOR, true)
	_right_column.add_child(_placard("STASH", _stash_size, _stash_view))
	_right_column.add_child(_label("Click a stack to sell one, hold to sell it all", 12, DIM_TEXT_COLOR, false))
	_status = _label("", 13, DIM_TEXT_COLOR, false)
	# It wraps within the column and keeps room for two lines, so a long message never moves the placards.
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(0.0, 36.0)
	_right_column.add_child(_status)


func _hints() -> Array:
	return [[&"inventory_drag", "Sell or buy one, drag"], [&"inventory_split", "Split"],
		[&"inventory_more", "One more or fewer"], [&"inventory", "Close"]]


## Opens the screen on the GameSession's hub, stash, tanks and wallet.
func open() -> void:
	var cell_px := _cell_size()
	_stash_view.setup(GameSession.stash, cell_px)
	_shop.setup(GameSession.trader, Trader.shelf(ContentRegistry.get_all(ItemDefinition)),
		roundf(cell_px * TILE_CELLS), _font)
	_fuel_gauge.custom_minimum_size = Vector2(cell_px * 3.0, 10.0)
	_antimatter_gauge.custom_minimum_size = Vector2(cell_px * 3.0, 10.0)
	_fuel_note.custom_minimum_size = Vector2(cell_px * GameSession.STASH_SIZE.x, 0.0)
	if not GameSession.stash.changed.is_connected(_update_stash):
		GameSession.stash.changed.connect(_update_stash)
	if not GameSession.bitcoin_changed.is_connected(_on_bitcoin_changed):
		GameSession.bitcoin_changed.connect(_on_bitcoin_changed)
	if not GameSession.hydrogen_changed.is_connected(_update_fuel):
		GameSession.hydrogen_changed.connect(_update_fuel)
	if not GameSession.antimatter_changed.is_connected(_update_fuel):
		GameSession.antimatter_changed.connect(_update_fuel)
	if _tick:
		_tick.kill()
	if _delta_fade:
		_delta_fade.kill()
	_stop_filling()
	_delta.modulate.a = 0.0
	_show_bitcoin(GameSession.bitcoin)
	bitcoin_text = Bitcoin.format(GameSession.bitcoin)
	_shop.set_bitcoin(GameSession.bitcoin)
	_set_status("", DIM_TEXT_COLOR)
	_pending = null
	_update_stash()
	_update_fuel(GameSession.hydrogen)
	_show_screen()
	Log.info("💰 Trader opened: hub=%s, bitcoin=%d, hydrogen=%d, antimatter=%d, order=%d, shelf=%d, stash_stacks=%d, stash_items=%d, slot=%.0f px" % [
		GameSession.trader.title, GameSession.bitcoin, GameSession.hydrogen, GameSession.antimatter,
		GameSession.order_units, _shop.definitions.size(), GameSession.stash.items.size(),
		GameSession.stash.item_count(), _cell_px])


## Closes the screen: a stack still being dragged goes back where it came from, and a click held on a stack sells
## nothing.
func close() -> void:
	if not is_open:
		Log.info("💰 Trader screen not closed, it isn't open")
		return
	_pending = null
	_hide_screen()
	# Collected antimatter is in the tank already; only its filling on the gauge stops.
	_stop_filling()
	if GameSession.stash.changed.is_connected(_update_stash):
		GameSession.stash.changed.disconnect(_update_stash)
	if GameSession.bitcoin_changed.is_connected(_on_bitcoin_changed):
		GameSession.bitcoin_changed.disconnect(_on_bitcoin_changed)
	if GameSession.hydrogen_changed.is_connected(_update_fuel):
		GameSession.hydrogen_changed.disconnect(_update_fuel)
	if GameSession.antimatter_changed.is_connected(_update_fuel):
		GameSession.antimatter_changed.disconnect(_update_fuel)
	Log.info("💰 Trader closed: bitcoin=%d, stash_stacks=%d, stash_items=%d" % [
		GameSession.bitcoin, GameSession.stash.items.size(), GameSession.stash.item_count()])


## Sells up to amount of a stack in the stash to the hub. Returns the bitcoin earned (0 when nothing was sold); the
## status line says what went for how much.
func sell(item: Item, amount: int) -> int:
	var definition := item.definition
	var count := mini(amount, item.quantity)
	var earned := GameSession.sell(item, count)
	if earned <= 0:
		_play(bump_sound)
		_set_status("%s can't be sold here." % definition.display_name, DANGER_COLOR)
		Log.info("💰 Sale refused: item=%s, amount=%d, quantity=%d" % [definition.id, amount, item.quantity])
		return 0
	_play(place_sound)
	_set_status("Sold %s for %s." % [definition.name_for(count), Bitcoin.format(earned)], DIM_TEXT_COLOR)
	Log.info("💰 Sold: item=%s, sold=%d, left=%d, earned=%d, bitcoin=%d" % [
		definition.id, count, item.quantity if GameSession.stash.has(item) else 0, earned, GameSession.bitcoin])
	return earned


## Buys one of an item into the stash, onto a stack of it or into a free slot, and selects that stack so the player
## sees where it went. Returns the stack, or null when the wallet is short; the status line then says so.
func buy(definition: ItemDefinition) -> Item:
	var price := GameSession.trader.buy_price(definition)
	if price > GameSession.bitcoin:
		_play(bump_sound)
		_set_status("Not enough bitcoin: %s costs %s." % [definition.display_name, Bitcoin.format(price)],
			DANGER_COLOR)
		Log.info("💰 Buy refused, not enough bitcoin: item=%s, price=%d, bitcoin=%d" % [
			definition.id, price, GameSession.bitcoin])
		return null
	var item := GameSession.buy(definition)
	if item == null:
		_play(bump_sound)
		_set_status("%s can't be bought here." % definition.display_name, DANGER_COLOR)
		Log.warning("💰 Buy refused by the session: item=%s, price=%d, bitcoin=%d" % [
			definition.id, price, GameSession.bitcoin])
		return null
	_play(place_sound)
	select(item)
	_set_status("%s bought for %s, delivered to the stash." % [definition.display_name, Bitcoin.format(price)],
		DIM_TEXT_COLOR)
	Log.info("💰 Bought: item=%s, price=%d, bitcoin=%d, stash_cell=%s, stack=%d" % [
		definition.id, price, GameSession.bitcoin, item.cell, item.quantity])
	return item


## Fills the ship's tank with as much hydrogen as it holds and the wallet pays for. Returns the units bought; when
## none, the status line says why.
func refuel() -> int:
	var missing := GameSession.HYDROGEN_TANK - GameSession.hydrogen
	if missing <= 0:
		_play(bump_sound)
		_set_status("The tank is already full.", DIM_TEXT_COLOR)
		Log.info("💰 Refuel refused, the tank is full: hydrogen=%d" % GameSession.hydrogen)
		return 0
	var bitcoin_before := GameSession.bitcoin
	var units := GameSession.refuel()
	if units <= 0:
		_play(bump_sound)
		_set_status("Not enough bitcoin for hydrogen: a unit costs %s." % Bitcoin.format(
			GameSession.trader.hydrogen_price(1)), DANGER_COLOR)
		Log.info("💰 Refuel refused, not enough bitcoin: hydrogen=%d, bitcoin=%d" % [
			GameSession.hydrogen, GameSession.bitcoin])
		return 0
	var price := bitcoin_before - GameSession.bitcoin
	_play(place_sound)
	var topped := "Filled the tank" if units == missing else "Bought what the wallet pays for"
	_set_status("%s: %d hydrogen for %s." % [topped, units, Bitcoin.format(price)], DIM_TEXT_COLOR)
	Log.info("💰 Refuelled: units=%d, price=%d, hydrogen=%d, bitcoin=%d" % [
		units, price, GameSession.hydrogen, GameSession.bitcoin])
	return units


## Orders the antimatter that fills the tank: every empty unit, or nothing when the wallet can't pay for them all.
## Returns the units ordered; when none, the status line says why.
func order() -> int:
	var missing := GameSession.ANTIMATTER_TANK - GameSession.antimatter
	if GameSession.order_units > 0:
		_play(bump_sound)
		_set_status("Antimatter is on order already: %d arriving at the hub on day %d." % [
			GameSession.order_units, GameSession.order_day], DIM_TEXT_COLOR)
		Log.info("💰 Order refused, antimatter on order already: units=%d, arrives_day=%d" % [
			GameSession.order_units, GameSession.order_day])
		return 0
	if missing <= 0:
		_play(bump_sound)
		_set_status("The antimatter tank is already full.", DIM_TEXT_COLOR)
		Log.info("💰 Order refused, the tank is full: antimatter=%d" % GameSession.antimatter)
		return 0
	var bitcoin_before := GameSession.bitcoin
	var units := GameSession.order_antimatter()
	if units <= 0:
		var price := GameSession.trader.antimatter_price(missing)
		_play(bump_sound)
		_set_status("Not enough bitcoin for antimatter: filling the tank takes %s, the wallet holds %s." % [
			Bitcoin.format(price), Bitcoin.format(GameSession.bitcoin)], DANGER_COLOR)
		Log.info("💰 Order refused, not enough bitcoin to fill the tank: missing=%d, price=%d, bitcoin=%d" % [
			missing, price, GameSession.bitcoin])
		return 0
	var price := bitcoin_before - GameSession.bitcoin
	_play(place_sound)
	_set_status("Ordered %d antimatter for %s. It arrives at the hub on day %d: board ships while you wait." % [
		units, Bitcoin.format(price), GameSession.order_day], DIM_TEXT_COLOR)
	Log.info("💰 Antimatter ordered: units=%d, price=%d, arrives_day=%d, bitcoin=%d" % [
		units, price, GameSession.order_day, GameSession.bitcoin])
	return units


## Collects the antimatter that has arrived at the hub: it is in the tank at once, and the gauge fills a block every
## FILL_STEP seconds while the screen is open. Returns the units collected; when none, the status line says why.
func collect() -> int:
	var before := GameSession.antimatter
	_filling = true
	var units := GameSession.collect_antimatter()
	if units <= 0:
		_filling = false
		_play(bump_sound)
		_set_status("No antimatter has arrived to collect.", DIM_TEXT_COLOR)
		Log.info("💰 Nothing to collect: order=%d, arrives_day=%d, day=%d" % [
			GameSession.order_units, GameSession.order_day, GameSession.day])
		return 0
	_play(place_sound)
	_set_status("Filling the antimatter tank...", DIM_TEXT_COLOR)
	if _fill_tween:
		_fill_tween.kill()
	_fill_tween = create_tween()
	_fill_tween.tween_method(_show_antimatter_fill, float(before), float(before + units), units * FILL_STEP)
	_fill_tween.tween_callback(_finish_filling.bind(units))
	_update_fuel(GameSession.hydrogen)
	antimatter_shown.emit(_shown_antimatter)
	Log.info("💰 Antimatter collected, filling the gauge: units=%d, from=%d, to=%d, fill=%.1f s" % [
		units, before, GameSession.antimatter, units * FILL_STEP])
	return units


## Whether collected antimatter is still filling the gauge.
func is_filling() -> bool:
	return _filling


## The middle of the ORDER (or COLLECT) button, in this control's pixels.
func order_button_center() -> Vector2:
	return get_global_transform().affine_inverse() * _order_button.get_global_rect().get_center()


## The middle of the FILL UP button, in this control's pixels.
func fill_button_center() -> Vector2:
	return get_global_transform().affine_inverse() * _fill_button.get_global_rect().get_center()


## The middle of an item's tile in the shop, in this control's pixels: where the pointer goes to buy it.
func shop_tile_center(definition: ItemDefinition) -> Vector2:
	var middle := _shop.get_global_transform() * _shop.tile_center(definition)
	return get_global_transform().affine_inverse() * middle


## The shop's item under the pointer, or null.
func shop_item_at_pointer() -> ItemDefinition:
	if not _pointer_over(_shop):
		return null
	return _shop.definition_at(_shop.get_global_transform().affine_inverse() * (get_global_transform() * pointer))


## Whether a click on a stash stack is held, to sell one when let go or the whole stack once held long enough.
func is_selling() -> bool:
	return _pending != null


## How far a held click has got to selling its whole stack, from 0 to 1; -1 when none is held.
func sell_hold_progress() -> float:
	return clampf(_pending_time / SELL_HOLD_TIME, 0.0, 1.0) if _pending else -1.0


func _process(delta: float) -> void:
	if not is_open or _pending == null:
		return
	_pending_time += delta
	if _pending_time >= SELL_HOLD_TIME:
		var item := _pending
		_pending = null
		Log.info("💰 Click held, selling the whole stack: item=%s, quantity=%d" % [item.definition.id, item.quantity])
		sell(item, item.quantity)
	_overlay.queue_redraw()


## A press on a stash stack waits to see what it is: let go, it sells one; held still, the whole stack; moved, a drag.
func _on_slot_pressed(grid: ItemGrid, cell: Vector2i) -> bool:
	if grid != GameSession.stash:
		return begin_drag(grid, cell)
	_pending = grid.item_at(cell)
	_pending_at = pointer
	_pending_time = 0.0
	select(_pending)
	return true


## Letting go of a click that is still waiting sells one of its stack.
func _on_slot_released() -> bool:
	if _pending == null:
		return false
	var item := _pending
	_pending = null
	_overlay.queue_redraw()
	if GameSession.stash.has(item):
		sell(item, 1)
	return true


func _on_pressed() -> bool:
	if _pointer_over(_fill_button):
		refuel()
		return true
	if _pointer_over(_order_button):
		if GameSession.order_arrived():
			collect()
		elif not _filling:
			order()
		return true
	var definition := shop_item_at_pointer()
	if definition:
		buy(definition)
		return true
	return false


func _on_refreshed() -> void:
	if _pending and pointer.distance_to(_pending_at) > DRAG_THRESHOLD:
		# The press moved: it is a drag, to rearrange the stash.
		var item := _pending
		_pending = null
		if GameSession.stash.has(item):
			begin_drag(GameSession.stash, item.cell)
	_shop.set_hovered(shop_item_at_pointer() if dragged == null else null)
	var over_fill := dragged == null and _pointer_over(_fill_button)
	var over_order := dragged == null and _pointer_over(_order_button)
	if over_fill != _fill_hovered or over_order != _order_hovered:
		_fill_hovered = over_fill
		_order_hovered = over_order
		_update_fuel(GameSession.hydrogen)


func _card_definition() -> ItemDefinition:
	if focused:
		return focused.definition
	return _shop.hovered


## A shop item's card shows what it costs, what it would sell back for and how many stack; a stash stack's card
## shows what one sells for, the stack, and what the whole stack sells for.
func _card_stats(definition: ItemDefinition) -> Array:
	var trader := GameSession.trader
	if focused == null:
		var price := trader.buy_price(definition)
		return [["BUY", Bitcoin.format(price), INK_COLOR if price <= GameSession.bitcoin else DANGER_COLOR],
			["SELLS FOR", Bitcoin.format(trader.sell_price(definition))], ["STACKS", "UP TO %d" % definition.stack_size]]
	return [["SELLS FOR", Bitcoin.format(trader.sell_price(definition))],
		["STACK", "%d / %d" % [focused.quantity, definition.stack_size]],
		["ALL FOR", Bitcoin.format(trader.sell_price(definition) * focused.quantity)]]


## The stack under the pointer while a click is held on it: the ring round the pointer fills as the hold nears
## selling the whole stack.
func _draw_overlay() -> void:
	super()
	if _pending == null:
		return
	var progress := sell_hold_progress()
	_overlay.draw_arc(pointer, RING_RADIUS, 0.0, TAU, 32, Color(INK_COLOR, 0.25), 2.0, true)
	if progress > 0.0:
		_overlay.draw_arc(pointer, RING_RADIUS, -PI / 2.0, -PI / 2.0 + TAU * progress, 32, LASER_COLOR, 3.0, true)


## The stash's readout: how many stacks it holds, and their worth at this hub.
func _update_stash() -> void:
	var stacks := GameSession.stash.items.size()
	_stash_size.text = "%d %s  ·  %s" % [stacks, "STACK" if stacks == 1 else "STACKS",
		Bitcoin.format(GameSession.trader.offer(GameSession.stash.items))]


## The tanks' readouts and gauges, FILL UP with what filling the hydrogen tank costs, and ORDER with what filling the
## antimatter tank costs, the day an order arrives, COLLECT once it has, or FILLING while it fills the gauge: FILL UP
## in the laser's blue when the wallet buys some hydrogen, ORDER when it pays for the whole fill, COLLECT always,
## brighter under the pointer.
func _update_fuel(_fuel_left: int) -> void:
	var missing := GameSession.HYDROGEN_TANK - GameSession.hydrogen
	var units := GameSession.trader.affordable_hydrogen(missing, GameSession.bitcoin)
	hydrogen_text = "%d/%d" % [GameSession.hydrogen, GameSession.HYDROGEN_TANK]
	_hydrogen.text = hydrogen_text
	_fuel_gauge.set_state(GameSession.HYDROGEN_TANK, GameSession.hydrogen, 0, 0)
	if missing <= 0:
		fill_text = "FULL"
	else:
		# What the wallet buys, or with an empty wallet what a full tank would cost.
		fill_text = "FILL UP  %s" % Bitcoin.format(GameSession.trader.hydrogen_price(units if units > 0 else missing))
	_fill_label.text = fill_text
	var active := units > 0
	_style_fuel_button(_fill_style, _fill_label, active, _fill_hovered)
	if not _filling:
		_shown_antimatter = GameSession.antimatter
	var missing_antimatter := GameSession.ANTIMATTER_TANK - GameSession.antimatter
	# An order always fills the tank.
	var fill_price := GameSession.trader.antimatter_price(missing_antimatter)
	antimatter_text = "%d/%d" % [_shown_antimatter, GameSession.ANTIMATTER_TANK]
	_antimatter.text = antimatter_text
	_antimatter_gauge.set_state(GameSession.ANTIMATTER_TANK, _shown_antimatter, 0, 0)
	var pending := GameSession.order_units > 0
	var arrived := GameSession.order_arrived()
	if _filling:
		order_text = "FILLING"
		_fuel_note.text = "Filling the antimatter tank: %d of %d." % [_shown_antimatter, GameSession.ANTIMATTER_TANK]
	elif arrived:
		order_text = "COLLECT  ·  %d" % GameSession.order_units
		_fuel_note.text = "%d antimatter has arrived at the hub. Collect it to fill the tank." % GameSession.order_units
	elif pending:
		order_text = "ARRIVES DAY %d" % GameSession.order_day
		_fuel_note.text = "%d antimatter on order, arriving here on day %d. Board ships while you wait." % [
			GameSession.order_units, GameSession.order_day]
	elif missing_antimatter <= 0:
		order_text = "FULL"
		_fuel_note.text = "The antimatter tank is full: a jump of up to %d light years." % GameSession.ANTIMATTER_TANK
	else:
		order_text = "ORDER  %s" % Bitcoin.format(fill_price)
		_fuel_note.text = "An order fills the tank %d %s later. A jump burns a unit a light year." % [
			Trader.DELIVERY_DAYS, "day" if Trader.DELIVERY_DAYS == 1 else "days"]
	_order_label.text = order_text
	var orderable := not pending and missing_antimatter > 0 and fill_price <= GameSession.bitcoin
	_style_fuel_button(_order_style, _order_label, (arrived and not _filling) or orderable, _order_hovered)


func _show_antimatter_fill(value: float) -> void:
	var blocks := floori(value + 0.0001)
	if blocks == _shown_antimatter:
		return
	_shown_antimatter = blocks
	_update_fuel(GameSession.hydrogen)
	antimatter_shown.emit(_shown_antimatter)


func _finish_filling(units: int) -> void:
	_filling = false
	_update_fuel(GameSession.hydrogen)
	var full := GameSession.antimatter >= GameSession.ANTIMATTER_TANK
	_set_status("Collected %d antimatter%s." % [units, ": the tank is full" if full else ""], DIM_TEXT_COLOR)
	Log.info("💰 Antimatter tank filled on the gauge: units=%d, antimatter=%d" % [units, GameSession.antimatter])


## Stops collected antimatter filling the gauge, which then shows the tank as it is.
func _stop_filling() -> void:
	if _fill_tween:
		_fill_tween.kill()
	var was_filling := _filling
	_filling = false
	_shown_antimatter = GameSession.antimatter
	if was_filling:
		antimatter_shown.emit(_shown_antimatter)


## A tank's row: its name and readout over its gauge, with its button beside them.
func _fuel_row(title: String, readout: Label, gauge: FuelGauge, button: PanelContainer) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var tank := VBoxContainer.new()
	tank.add_theme_constant_override("separation", 4)
	tank.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var header := HBoxContainer.new()
	var name_label := _label(title, 10, DIM_TEXT_COLOR, true)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_label)
	header.add_child(readout)
	tank.add_child(header)
	tank.add_child(gauge)
	row.add_child(tank)
	button.size_flags_vertical = Control.SIZE_SHRINK_END
	button.custom_minimum_size = Vector2(150.0, 0.0)
	row.add_child(button)
	return row


func _style_fuel_button(style: StyleBoxFlat, label: Label, active: bool, hovered: bool) -> void:
	style.border_color = LASER_COLOR if active else Color(INK_COLOR, 0.25)
	style.bg_color = Color(LASER_COLOR, 0.28 if hovered else 0.12) if active else Color(PLACARD_COLOR, 0.4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", INK_COLOR if active else Color(DIM_TEXT_COLOR, 0.6))


## A button's frame: FILL UP and ORDER.
func _button_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style


## The wallet changed: it ticks to the new amount, and the change shows beside it and fades.
func _on_bitcoin_changed(bitcoin: int) -> void:
	var change := bitcoin - _shown_bitcoin
	bitcoin_text = Bitcoin.format(bitcoin)
	_shop.set_bitcoin(bitcoin)
	if _tick:
		_tick.kill()
	_tick = create_tween()
	_tick.tween_method(_show_bitcoin, _shown_bitcoin, bitcoin, TICK_TIME)
	if change != 0:
		_delta.text = Bitcoin.format(change, true)
		_delta.add_theme_color_override("font_color", LASER_COLOR if change > 0 else DIM_TEXT_COLOR)
		if _delta_fade:
			_delta_fade.kill()
		_delta.modulate.a = 1.0
		_delta_fade = create_tween()
		_delta_fade.tween_interval(TICK_TIME)
		_delta_fade.tween_property(_delta, "modulate:a", 0.0, DELTA_FADE_TIME)


func _show_bitcoin(amount: int) -> void:
	_shown_bitcoin = amount
	_bitcoin.text = Bitcoin.format(amount)


func _set_status(text: String, color: Color) -> void:
	status_text = text
	_status.text = text
	_status.add_theme_color_override("font_color", color)


func _views() -> Array[ItemGridView]:
	return [_stash_view]


func _grid_name(grid: ItemGrid) -> String:
	if grid == GameSession.stash:
		return "stash"
	return "grid"

