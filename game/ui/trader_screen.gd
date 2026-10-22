class_name TraderScreen
extends GridScreen
## The trader hub's screen, part of the HUD (see GridScreen), opened from the ship's trader terminal: the hub on the
## left half, what the player owns on the right. The hub's side is the sell crate, with the hub's offer for what is in
## it and a SELL button, and the shop: every item, at the hub's buy price. The player's side is the wallet and the
## ship's stash. Items are dragged from the stash into the crate and back, SELL sells the crate, and clicking an item
## in the shop buys one into the stash. After every deal the wallet ticks to its new amount, with the change fading
## beside it, and a status line says what happened (or why it couldn't). What is left in the crate goes back to the
## stash when the screen closes. The trades go through the GameSession, which keeps the hub, the crate, the stash and
## the wallet. The player opens and closes it.

## Seconds the wallet takes to tick to a new amount, and the change beside it to fade out after it.
const TICK_TIME := 0.45
const DELTA_FADE_TIME := 1.4
## A shop tile's size, in grid cells, so the shop is about as wide as the crate.
const TILE_CELLS := 1.4

## What the readouts say, for tests: e.g. "OFFER  ₿340", "Sold 4 items for ₿340." and "₿500" (the amount the
## wallet is ticking to).
var offer_text := ""
var status_text := ""
var bitcoin_text := ""

var _crate_view: ItemGridView
var _stash_view: ItemGridView
var _shop: ShopView
var _offer: Label
var _sell_button: PanelContainer
var _sell_style: StyleBoxFlat
var _sell_label: Label
var _sell_hovered := false
var _bitcoin: Label
var _delta: Label
var _stash_size: Label
var _status: Label
var _shown_bitcoin := 0
var _tick: Tween
var _delta_fade: Tween


func _build() -> void:
	_crate_view = ItemGridView.new()
	_stash_view = ItemGridView.new()
	_shop = ShopView.new()
	var crate_body := VBoxContainer.new()
	crate_body.add_theme_constant_override("separation", 10)
	crate_body.add_child(_crate_view)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	_offer = _label("", 13, DIM_TEXT_COLOR, true)
	_offer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_offer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(_offer)
	_sell_button = PanelContainer.new()
	_sell_style = StyleBoxFlat.new()
	_sell_style.set_border_width_all(1)
	_sell_style.set_corner_radius_all(2)
	_sell_style.content_margin_left = 18.0
	_sell_style.content_margin_right = 18.0
	_sell_style.content_margin_top = 4.0
	_sell_style.content_margin_bottom = 4.0
	_sell_button.add_theme_stylebox_override("panel", _sell_style)
	_sell_label = _label("SELL", 13, INK_COLOR, true)
	_sell_button.add_child(_sell_label)
	footer.add_child(_sell_button)
	crate_body.add_child(footer)
	_left_column.add_child(_placard("SELL CRATE", _label("Drag items in to sell them", 12, DIM_TEXT_COLOR, false),
		crate_body))
	_left_column.add_child(_placard("SHOP", _label("Delivered to the stash", 12, DIM_TEXT_COLOR, false), _shop))
	_bitcoin = _label("", 24, INK_COLOR, false)
	_delta = _label("", 13, LASER_COLOR, true)
	# Room for the change, so the placard doesn't widen when it shows.
	_delta.custom_minimum_size = Vector2(64.0, 0.0)
	_right_column.add_child(_placard("BITCOIN", _delta, _bitcoin))
	_stash_size = _label("", 12, DIM_TEXT_COLOR, true)
	_right_column.add_child(_placard("STASH", _stash_size, _stash_view))
	_status = _label("", 13, DIM_TEXT_COLOR, false)
	# It wraps within the column and keeps room for two lines, so a long message never moves the placards.
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(0.0, 36.0)
	_right_column.add_child(_status)


func _hints() -> Array:
	return [[&"inventory_drag", "Drag"], [&"inventory_rotate", "Rotate"], [&"inventory_mirror", "Mirror"],
		[&"", "Click an item in the shop to buy one"], [&"inventory", "Close"]]


## Opens the screen on the GameSession's hub, sell crate, stash and wallet.
func open() -> void:
	var cell_px := _cell_size()
	_crate_view.setup(GameSession.crate, cell_px)
	_stash_view.setup(GameSession.stash, cell_px)
	_shop.setup(GameSession.trader, Trader.shelf(ContentRegistry.get_all(ItemDefinition)),
		roundf(cell_px * TILE_CELLS), _font)
	_stash_size.text = "%d × %d" % [GameSession.stash.size.x, GameSession.stash.size.y]
	if not GameSession.crate.changed.is_connected(_update_offer):
		GameSession.crate.changed.connect(_update_offer)
	if not GameSession.bitcoin_changed.is_connected(_on_bitcoin_changed):
		GameSession.bitcoin_changed.connect(_on_bitcoin_changed)
	if _tick:
		_tick.kill()
	if _delta_fade:
		_delta_fade.kill()
	_delta.modulate.a = 0.0
	_show_bitcoin(GameSession.bitcoin)
	bitcoin_text = Bitcoin.format(GameSession.bitcoin)
	_shop.set_bitcoin(GameSession.bitcoin)
	_set_status("", DIM_TEXT_COLOR)
	_update_offer()
	_show_screen()
	Log.info("💰 Trader opened: hub=%s, bitcoin=%d, shelf=%d, crate_items=%d, stash_items=%d, cell=%.0f px" % [
		GameSession.trader.title, GameSession.bitcoin, _shop.definitions.size(), GameSession.crate.items.size(),
		GameSession.stash.items.size(), _cell_px])


## Closes the screen: an item still being dragged goes back where it came from, and what is left in the crate goes
## back to the stash (what doesn't fit waits in the crate for the next visit).
func close() -> void:
	if not is_open:
		Log.info("💰 Trader screen not closed, it isn't open")
		return
	_hide_screen()
	var left := GameSession.return_crate()
	if GameSession.crate.changed.is_connected(_update_offer):
		GameSession.crate.changed.disconnect(_update_offer)
	if GameSession.bitcoin_changed.is_connected(_on_bitcoin_changed):
		GameSession.bitcoin_changed.disconnect(_on_bitcoin_changed)
	Log.info("💰 Trader closed: bitcoin=%d, left_in_crate=%d, stash_items=%d" % [
		GameSession.bitcoin, left, GameSession.stash.items.size()])


## Sells what is in the crate. Returns the bitcoin earned (0 when the crate is empty).
func sell() -> int:
	var count := GameSession.crate.items.size()
	if count == 0:
		_play(bump_sound)
		_set_status("Drag items from the stash into the crate to sell them.", DIM_TEXT_COLOR)
		Log.info("💰 Nothing to sell, the crate is empty: bitcoin=%d" % GameSession.bitcoin)
		return 0
	var earned := GameSession.sell_crate()
	_play(place_sound)
	_set_status("Sold %d %s for %s." % [count, "item" if count == 1 else "items", Bitcoin.format(earned)],
		DIM_TEXT_COLOR)
	Log.info("💰 Sold the crate: items=%d, earned=%d, bitcoin=%d" % [count, earned, GameSession.bitcoin])
	return earned


## Buys one of an item into the stash, and selects it there so the player sees where it went. Returns the new item,
## or null when the wallet is short or the stash is full; the status line then says which.
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
		_set_status("No room in the stash for %s. Make space or sell something first." % definition.display_name,
			DANGER_COLOR)
		Log.info("💰 Buy refused, no room in the stash: item=%s, price=%d, stash_free=%d" % [
			definition.id, price, GameSession.stash.free_cells()])
		return null
	_play(place_sound)
	select(item)
	_set_status("%s bought for %s, delivered to the stash." % [definition.display_name, Bitcoin.format(price)],
		DIM_TEXT_COLOR)
	Log.info("💰 Bought: item=%s, price=%d, bitcoin=%d, stash_cell=%s" % [
		definition.id, price, GameSession.bitcoin, item.cell])
	return item


## The middle of an item's tile in the shop, in this control's pixels: where the pointer goes to buy it.
func shop_tile_center(definition: ItemDefinition) -> Vector2:
	var middle := _shop.get_global_transform() * _shop.tile_center(definition)
	return get_global_transform().affine_inverse() * middle


## The middle of the SELL button, in this control's pixels.
func sell_button_center() -> Vector2:
	return get_global_transform().affine_inverse() * _sell_button.get_global_rect().get_center()


## The shop's item under the pointer, or null.
func shop_item_at_pointer() -> ItemDefinition:
	if not _pointer_over(_shop):
		return null
	return _shop.definition_at(_shop.get_global_transform().affine_inverse() * (get_global_transform() * pointer))


func _on_pressed() -> bool:
	if _pointer_over(_sell_button):
		sell()
		return true
	var definition := shop_item_at_pointer()
	if definition:
		buy(definition)
		return true
	return false


func _on_refreshed() -> void:
	_shop.set_hovered(shop_item_at_pointer() if dragged == null else null)
	var over_sell := dragged == null and _pointer_over(_sell_button)
	if over_sell != _sell_hovered:
		_sell_hovered = over_sell
		_update_sell_button()


func _card_definition() -> ItemDefinition:
	if focused:
		return focused.definition
	return _shop.hovered


## A shop item's card shows what it costs and what it would sell back for; a crate or stash item's card shows what
## it sells for.
func _card_stats(definition: ItemDefinition) -> Array:
	var trader := GameSession.trader
	var cells := definition.get_cells().size()
	var size_stat := ["SIZE", "%d %s" % [cells, "CELL" if cells == 1 else "CELLS"]]
	if focused == null:
		var price := trader.buy_price(definition)
		return [["BUY", Bitcoin.format(price), INK_COLOR if price <= GameSession.bitcoin else DANGER_COLOR],
			["SELLS FOR", Bitcoin.format(trader.sell_price(definition))], size_stat]
	return [["SELLS FOR", Bitcoin.format(trader.sell_price(definition))], size_stat,
		["PER CELL", Bitcoin.format(roundi(float(trader.sell_price(definition)) / cells))]]


func _update_offer() -> void:
	var offer := GameSession.trader.offer(GameSession.crate.items)
	offer_text = "OFFER  %s" % Bitcoin.format(offer) if not GameSession.crate.items.is_empty() else "EMPTY"
	_offer.text = offer_text
	_offer.add_theme_color_override("font_color", LASER_COLOR if offer > 0 else DIM_TEXT_COLOR)
	_update_sell_button()


## The SELL button lights up in the laser's blue when there is something to sell, brighter under the pointer.
func _update_sell_button() -> void:
	var active := not GameSession.crate.items.is_empty()
	_sell_style.border_color = LASER_COLOR if active else Color(INK_COLOR, 0.25)
	_sell_style.bg_color = Color(LASER_COLOR, 0.28 if _sell_hovered else 0.12) if active \
		else Color(PLACARD_COLOR, 0.4)
	_sell_label.add_theme_color_override("font_color", INK_COLOR if active else Color(DIM_TEXT_COLOR, 0.6))


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
	return [_crate_view, _stash_view]


func _grid_name(grid: ItemGrid) -> String:
	if grid == GameSession.crate:
		return "crate"
	if grid == GameSession.stash:
		return "stash"
	return "grid"

