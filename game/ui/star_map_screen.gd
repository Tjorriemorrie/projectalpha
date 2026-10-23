class_name StarMapScreen
extends MapScreen
## The star map, the second of the cockpit console's map tabs (see MapScreen): the whole cluster (StarMapView) on the
## left, and on the right the system the ship is in, the antimatter in the tank, what the pointer is on or was clicked
## last, BUY INTEL, JUMP and a status line. Pointing at a system shows its star and owner, how far it is and what the
## jump there burns, and its ships if they are known (visited, or with intel), each with what its scan expects aboard;
## clicking selects it. BUY INTEL buys intel on a selected system in range at the hub, revealing its ships; Q then shows
## the selected known system on the system map tab, read-only. Holding JUMP for JUMP_HOLD_TIME (the button fills)
## asks the player to jump there (jump_confirmed), when the ship can: from the hub, with the drive charged, no
## antimatter on order and enough in the tank. The purchases and the checks go through the GameSession.

## The player holds JUMP long enough on a system the ship can jump to: the player then jumps there.
signal jump_confirmed(to: StarSystemDefinition)

## Seconds JUMP is held to jump: like holding interact on the airlock to board, it costs a day.
const JUMP_HOLD_TIME := 1.0
## The most ships listed for a known system.
const MAX_SHIP_ROWS := 8

@export var intel_sound: AudioStream = preload("res://assets/audio/loot/item_place.wav")

## What the readouts say, for tests: e.g. "2/10", "MORI", "HOLD TO JUMP  ·  8", "BUY INTEL  ·  ₿200". The details are
## the label and value of each row, e.g. "DISTANCE 7.2 ly · JUMP 8 antimatter · SHIPS 7 known", and the ships one per
## line, e.g. "Hauler · about 5 robots".
var antimatter_text := ""
var target_text := ""
var details_text := ""
var ships_text := ""
var intel_text := ""
var jump_text := ""
## The system clicked last, and the one whose details show; null for none.
var selected: StarSystemDefinition
var shown: StarSystemDefinition
## Whether a jump is under way: it asked the player to jump and waits for the screen to change.
var jumping := false

var _map: StarMapView
var _map_detail: Label
var _system_name: Label
var _system_kind: Label
var _day: Label
var _gauge: FuelGauge
var _antimatter: Label
var _gauge_note: Label
var _target_title: Label
var _target_where: Label
var _details: GridContainer
var _ships: VBoxContainer
var _intel_button: PanelContainer
var _jump_button: PanelContainer
var _intel_hovered := false
var _jump_hovered := false
## How long JUMP has been held, or -1 while it isn't.
var _hold := -1.0


func _build() -> void:
	_centre_gap = 0.02
	_map = StarMapView.new()
	_map_detail = _label("", 12, DIM_TEXT_COLOR, true)
	_left_column.add_child(_build_tabs())
	_left_column.add_child(_placard("STAR MAP", _map_detail, _map))
	var system_body := VBoxContainer.new()
	system_body.add_theme_constant_override("separation", 2)
	_system_name = _label("", 24, INK_COLOR, false)
	_system_kind = _label("", 12, DIM_TEXT_COLOR, false)
	system_body.add_child(_system_name)
	system_body.add_child(_system_kind)
	_day = _label("", 12, DIM_TEXT_COLOR, true)
	_right_column.add_child(_sized(_placard("STAR SYSTEM", _day, system_body)))
	var fuel_body := VBoxContainer.new()
	fuel_body.add_theme_constant_override("separation", 6)
	_gauge = FuelGauge.new()
	_gauge.custom_minimum_size = Vector2(PANEL_WIDTH - 24.0, 12.0)
	_gauge_note = _label("", 12, DIM_TEXT_COLOR, false)
	fuel_body.add_child(_gauge)
	fuel_body.add_child(_gauge_note)
	_antimatter = _label("", 13, INK_COLOR, true)
	_right_column.add_child(_sized(_placard("ANTIMATTER", _antimatter, fuel_body)))
	var target_body := VBoxContainer.new()
	target_body.add_theme_constant_override("separation", 10)
	_target_where = _label("", 13, DIM_TEXT_COLOR, false)
	_target_where.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_target_where.custom_minimum_size = Vector2(PANEL_WIDTH - 24.0, 0.0)
	target_body.add_child(_target_where)
	_details = GridContainer.new()
	_details.columns = 2
	_details.add_theme_constant_override("h_separation", 14)
	_details.add_theme_constant_override("v_separation", 6)
	target_body.add_child(_details)
	_ships = VBoxContainer.new()
	_ships.add_theme_constant_override("separation", 3)
	target_body.add_child(_ships)
	_intel_button = _new_button()
	target_body.add_child(_intel_button)
	_jump_button = _new_button()
	target_body.add_child(_jump_button)
	_target_title = _label("", 11, DIM_TEXT_COLOR, true)
	_right_column.add_child(_sized(_placard("", _label("", 12, DIM_TEXT_COLOR, true), target_body, _target_title)))
	_build_status()


func _hints() -> Array:
	return [[&"inventory_drag", "Select"], [&"", "Hold JUMP to jump there"], [&"map_tab", "System map"],
		[&"inventory", "Close"]]


func _tab() -> Tab:
	return Tab.STAR


## Opens the star map on the GameSession's system and tanks. Opened from the console it starts with nothing selected;
## switching from the system map, it keeps what was selected and opens in its place, quietly.
func open(switching: bool = false) -> void:
	var screen := get_viewport_rect().size
	_map.setup(ContentRegistry.get_all(StarSystemDefinition), _map_side(), screen.x - PANEL_WIDTH - 140.0, _font,
		_label_font)
	if not switching:
		selected = null
	shown = null
	jumping = false
	_hold = -1.0
	var system := GameSession.system
	_system_name.text = system.definition.display_name if system else "No system"
	_system_kind.text = system.definition.describe() if system else ""
	_day.text = "DAY %d" % GameSession.day
	_map_detail.text = "%d IN RANGE" % _map.in_range.size()
	if not GameSession.antimatter_changed.is_connected(_on_antimatter_changed):
		GameSession.antimatter_changed.connect(_on_antimatter_changed)
	if not GameSession.bitcoin_changed.is_connected(_on_bitcoin_changed):
		GameSession.bitcoin_changed.connect(_on_bitcoin_changed)
	_set_status("", DIM_TEXT_COLOR)
	_update()
	_switching = switching
	_show_screen()
	_switching = false
	Log.info("🌌 Star map opened: system=%s, in_range=%d, antimatter=%d, order=%d, day=%d, at_hub=%s, switching=%s" % [
		system.definition.id if system else "none", _map.in_range.size(), GameSession.antimatter,
		GameSession.order_units, GameSession.day, GameSession.at_hub, switching])


## Closes the star map; switching closes it for the system map to open in its place, quietly.
func close(switching: bool = false) -> void:
	if not is_open:
		Log.info("🌌 Star map not closed, it isn't open")
		return
	_hold = -1.0
	jumping = false
	_switching = switching
	_hide_screen()
	_switching = false
	if GameSession.antimatter_changed.is_connected(_on_antimatter_changed):
		GameSession.antimatter_changed.disconnect(_on_antimatter_changed)
	if GameSession.bitcoin_changed.is_connected(_on_bitcoin_changed):
		GameSession.bitcoin_changed.disconnect(_on_bitcoin_changed)
	Log.info("🌌 Star map closed: selected=%s, switching=%s" % [selected.id if selected else "none", switching])


## Selects a system (or null): its details show and its lane lights up.
func select(system: StarSystemDefinition) -> void:
	selected = system
	_update()
	Log.info("🌌 System selected: system=%s, known=%s, in_range=%s" % [
		system.id if system else "none", GameSession.known_system(system) != null if system else false,
		_map.in_range.has(system)])


## Buys intel on the selected system. Returns whether it was bought; when it can't be, the status line says why.
func buy_intel() -> bool:
	var target := selected
	if target == null:
		_refuse("Select a system on the map first.")
		Log.info("🌌 No intel bought, nothing selected")
		return false
	var check := GameSession.check_intel(target)
	if check != GameSession.Intel.OK:
		_refuse(_intel_refusal(target, check))
		Log.info("🌌 No intel bought: system=%s, why=%s" % [target.id, GameSession.Intel.keys()[check]])
		return false
	var price := GameSession.trader.intel_price()
	var known := GameSession.buy_intel(target)
	if known == null:
		_refuse("The hub couldn't sell intel on %s." % target.display_name)
		Log.warning("🌌 Intel refused by the session: system=%s" % target.id)
		return false
	_play(intel_sound)
	_set_status("Intel on %s for %s: %d %s. Press %s to see where they lie." % [
		target.display_name, Bitcoin.format(price), known.wrecks.size(), "ship" if known.wrecks.size() == 1 else "ships",
		_binding_label(&"map_tab")], DIM_TEXT_COLOR)
	_update()
	Log.info("🌌 Intel bought: system=%s, price=%d, ships=%d, bitcoin=%d" % [
		target.id, price, known.wrecks.size(), GameSession.bitcoin])
	return true


## Asks the player to jump to the selected system, if the ship can. Returns whether it asked; when it can't, the
## status line says why.
func jump() -> bool:
	var target := selected
	if target == null:
		_refuse("Select a system on the map first.")
		Log.info("🌌 No jump, nothing selected")
		return false
	if jumping:
		Log.info("🌌 No jump, one is under way already: system=%s" % target.id)
		return false
	var check := GameSession.check_jump(target)
	if check != GameSession.Jump.OK:
		_refuse(_jump_refusal(target, check))
		Log.info("🌌 No jump: system=%s, why=%s" % [target.id, GameSession.Jump.keys()[check]])
		return false
	jumping = true
	_set_status("Jumping to %s..." % target.display_name, DIM_TEXT_COLOR)
	jump_confirmed.emit(target)
	Log.info("🌌 Jump confirmed: system=%s, cost=%d, antimatter=%d" % [
		target.id, GameSession.jump_cost(target), GameSession.antimatter])
	return true


## Says something in the status line, such as why a jump didn't happen.
func say(text: String, refused: bool = false) -> void:
	jumping = false
	_update()
	if refused:
		_refuse(text)
	else:
		_set_status(text, DIM_TEXT_COLOR)


## Where a system is on the screen, in this control's pixels: where the pointer goes to pick it.
func system_center(system: StarSystemDefinition) -> Vector2:
	return get_global_transform().affine_inverse() * (_map.get_global_transform() * _map.to_pixels(system))


## The middle of the BUY INTEL and JUMP buttons, in this control's pixels.
func intel_button_center() -> Vector2:
	return _center_of(_intel_button)


func jump_button_center() -> Vector2:
	return _center_of(_jump_button)


## Whether BUY INTEL shows: for an unknown system.
func is_intel_offered() -> bool:
	return _intel_button.visible


## How far JUMP has been held, from 0 to 1, or -1 while it isn't.
func jump_hold() -> float:
	return _hold / JUMP_HOLD_TIME if _hold >= 0.0 else -1.0


func _viewing_after_switch() -> StarSystem:
	if selected == null or GameSession.system and selected == GameSession.system.definition:
		return null
	return GameSession.known_system(selected)


func _handle_map_input(event: InputEvent) -> bool:
	if jumping:
		return true
	if event.is_action_released("inventory_drag"):
		if _hold >= 0.0:
			_hold = -1.0
			_set_status("Keep holding JUMP for a second to jump.", DIM_TEXT_COLOR)
			Log.info("🌌 Jump hold let go early: system=%s" % (selected.id if selected else "none"))
		return true
	if not event.is_action_pressed("inventory_drag"):
		return false
	if _pointer_over(_jump_button):
		if selected and GameSession.check_jump(selected) == GameSession.Jump.OK:
			_hold = 0.0
			Log.info("🌌 Holding JUMP: system=%s" % selected.id)
		else:
			jump()
	elif _intel_button.visible and _pointer_over(_intel_button):
		buy_intel()
	elif _pointer_over(_map):
		select(_map.system_at(_map_point()))
	return true


func _process(delta: float) -> void:
	if _hold < 0.0:
		return
	if not is_open or not _pointer_over(_jump_button):
		_hold = -1.0
		_overlay.queue_redraw()
		return
	_hold += delta
	_overlay.queue_redraw()
	if _hold >= JUMP_HOLD_TIME:
		_hold = -1.0
		jump()


## While JUMP is held, the button fills with the laser's blue from the left.
func _draw_overlay() -> void:
	if _hold < 0.0:
		return
	var rect := _jump_button.get_global_rect()
	var at := _overlay.get_global_transform().affine_inverse() * rect.position
	var fill := Rect2(at, Vector2(rect.size.x * clampf(_hold / JUMP_HOLD_TIME, 0.0, 1.0), rect.size.y))
	_overlay.draw_rect(fill, Color(LASER_COLOR, 0.35))


## What the pointer is on: the system under it on the map, and whether it is on a button.
func _refresh() -> void:
	var under := _map.system_at(_map_point()) if _pointer_over(_map) else null
	var over_intel := _intel_button.visible and _pointer_over(_intel_button)
	var over_jump := _pointer_over(_jump_button)
	var next := under if under else selected
	if next != shown or over_intel != _intel_hovered or over_jump != _jump_hovered:
		_intel_hovered = over_intel
		_jump_hovered = over_jump
		_update()
	super()


func _on_antimatter_changed(_antimatter_left: int) -> void:
	_update()


func _on_bitcoin_changed(_bitcoin: int) -> void:
	_update()


## Shows the system under the pointer (or else the selected one): its details, its lane on the map, the antimatter
## the jump burns on the gauge, and what BUY INTEL and JUMP would do.
func _update() -> void:
	var under := _map.system_at(_map_point()) if is_open and _pointer_over(_map) else null
	shown = under if under else selected
	_map.shown = shown
	_map.selected = selected
	_map.refresh()
	var here := GameSession.system != null and shown == GameSession.system.definition
	var cost := GameSession.jump_cost(shown) if shown and not here and _map.in_range.has(shown) else 0
	_show_antimatter(cost)
	_show_target(shown)
	_show_intel_button(shown)
	_show_jump_button(shown)


## The tank, with what the jump on show would burn; and under it what it is short of, or the antimatter on order.
func _show_antimatter(cost: int) -> void:
	var tank := GameSession.antimatter
	antimatter_text = "%d/%d" % [tank, GameSession.ANTIMATTER_TANK]
	_antimatter.text = antimatter_text
	_gauge.set_state(GameSession.ANTIMATTER_TANK, tank, cost, 0)
	var short := cost > tank
	if cost > 0 and not short:
		_gauge_note.text = "%d to jump there  ·  %d left after" % [cost, tank - cost]
	elif cost > 0:
		_gauge_note.text = "%d needed to jump there, %d short" % [cost, cost - tank]
	elif GameSession.order_arrived():
		_gauge_note.text = "%d at the hub: collect it at the trader terminal" % GameSession.order_units
	elif GameSession.order_units > 0:
		_gauge_note.text = "%d on order, arriving day %d" % [GameSession.order_units, GameSession.order_day]
	elif not GameSession.drive_charged():
		_gauge_note.text = "Drive recharging: board a ship first"
	elif tank >= GameSession.ANTIMATTER_TANK:
		_gauge_note.text = "Full: a jump of up to %d light years" % GameSession.ANTIMATTER_TANK
	else:
		_gauge_note.text = "Ordered at the hub's trader terminal"
	_gauge_note.add_theme_color_override("font_color", DANGER_COLOR if short else DIM_TEXT_COLOR)


## The target placard: a system's star and owner, how far it is and what the jump burns, and its ships when known.
func _show_target(target: StarSystemDefinition) -> void:
	_clear(_details)
	_clear(_ships)
	var lines: Array[String] = []
	var ship_lines: Array[String] = []
	if target == null:
		target_text = "NOTHING SELECTED"
		_target_where.text = "Point at a system to see what is known about it, and click to select it."
	else:
		target_text = target.display_name.to_upper()
		_target_where.text = target.describe()
		var here := GameSession.system != null and target == GameSession.system.definition
		var known := GameSession.known_system(target)
		var rows: Array = []
		if here:
			rows.append(["DISTANCE", "The ship is here"])
		else:
			var light_years := Galaxy.distance(GameSession.system.definition, target) if GameSession.system else 0.0
			rows.append(["DISTANCE", "%.1f ly" % light_years])
			if _map.in_range.has(target):
				rows.append(["JUMP", "%d antimatter" % GameSession.jump_cost(target)])
			else:
				rows.append(["JUMP", "Out of range"])
		if known:
			var how := "here" if here else "as left" if GameSession.has_visited(target) else "by intel"
			rows.append(["SHIPS", "%d known, %s" % [known.wrecks.size(), how]])
		else:
			rows.append(["SHIPS", "Unknown"])
		for row: Array in rows:
			var refused: bool = row[1] == "Out of range"
			_add_detail_row(_details, row[0], row[1], DIM_TEXT_COLOR if refused else INK_COLOR)
			lines.append("%s %s" % row)
		if known:
			for wreck in known.wrecks.slice(0, MAX_SHIP_ROWS):
				ship_lines.append("%s · about %d robots" % [wreck.title(), wreck.roll.expected_robots()])
			if known.wrecks.size() > MAX_SHIP_ROWS:
				ship_lines.append("and %d more" % (known.wrecks.size() - MAX_SHIP_ROWS))
			if known.wrecks.is_empty():
				ship_lines.append("Nothing left to board")
		for line in ship_lines:
			_ships.add_child(_label(line, 13, INK_COLOR, false))
		if not known:
			var unknown := "Its ships show on arrival, or with intel from a hub in range."
			_ships.add_child(_label(unknown, 12, DIM_TEXT_COLOR, false))
	_target_title.text = target_text
	details_text = " · ".join(lines)
	ships_text = "\n".join(ship_lines)
	for child in _details.get_children() + _ships.get_children():
		(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in _ships.get_children():
		var line := child as Label
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size = Vector2(PANEL_WIDTH - 24.0, 0.0)


## BUY INTEL shows for an unknown system: lit when the hub sells it now, otherwise saying why not.
func _show_intel_button(target: StarSystemDefinition) -> void:
	var check := GameSession.check_intel(target) if target else GameSession.Intel.KNOWN
	_intel_button.visible = check != GameSession.Intel.KNOWN
	var price := Bitcoin.format(GameSession.trader.intel_price()) if GameSession.trader else ""
	match check:
		GameSession.Intel.OUT_OF_RANGE:
			intel_text = "NO INTEL OUT OF RANGE"
		GameSession.Intel.AWAY_FROM_HUB:
			intel_text = "BUY INTEL AT THE HUB"
		GameSession.Intel.KNOWN:
			intel_text = ""
		_:
			intel_text = "BUY INTEL  ·  %s" % price
	_style_button(_intel_button, intel_text, check == GameSession.Intel.OK, _intel_hovered,
		check == GameSession.Intel.SHORT_OF_BITCOIN)


## JUMP lights up when the ship can jump to what shows, brighter under the pointer; it says why not when it can't.
func _show_jump_button(target: StarSystemDefinition) -> void:
	var check := GameSession.check_jump(target) if target else GameSession.Jump.OUT_OF_RANGE
	if target == null:
		jump_text = "JUMP"
	else:
		match check:
			GameSession.Jump.OK:
				jump_text = "HOLD TO JUMP  ·  %d" % GameSession.jump_cost(target)
			GameSession.Jump.HERE:
				jump_text = "THE SHIP IS HERE"
			GameSession.Jump.OUT_OF_RANGE:
				jump_text = "OUT OF RANGE"
			GameSession.Jump.AWAY_FROM_HUB:
				jump_text = "JUMP FROM THE HUB"
			GameSession.Jump.RECHARGING:
				jump_text = "DRIVE RECHARGING"
			GameSession.Jump.ORDER_PENDING:
				jump_text = "COLLECT ANTIMATTER FIRST" if GameSession.order_arrived() else "ANTIMATTER ON ORDER"
			GameSession.Jump.SHORT_OF_ANTIMATTER:
				jump_text = "NOT ENOUGH ANTIMATTER"
	var refused := target != null and check != GameSession.Jump.OK and check != GameSession.Jump.HERE
	_style_button(_jump_button, jump_text, target != null and check == GameSession.Jump.OK, _jump_hovered, refused)


func _intel_refusal(target: StarSystemDefinition, check: int) -> String:
	match check:
		GameSession.Intel.KNOWN:
			return "%s's ships are known already." % target.display_name
		GameSession.Intel.OUT_OF_RANGE:
			return "The hub only sells intel on systems within a jump of it."
		GameSession.Intel.AWAY_FROM_HUB:
			return "Intel is sold at the hub. Fly back to it on the system map first."
		_:
			return "Not enough bitcoin: intel on %s costs %s." % [
				target.display_name, Bitcoin.format(GameSession.trader.intel_price())]


func _jump_refusal(target: StarSystemDefinition, check: int) -> String:
	match check:
		GameSession.Jump.HERE:
			return "The ship is in %s already." % target.display_name
		GameSession.Jump.OUT_OF_RANGE:
			return "%s is %.1f light years away, and a jump reaches %d. Jump through the systems between." % [
				target.display_name, Galaxy.distance(GameSession.system.definition, target), Galaxy.JUMP_RANGE]
		GameSession.Jump.AWAY_FROM_HUB:
			return "The ship jumps only from the hub. Fly back to it on the system map first."
		GameSession.Jump.RECHARGING:
			return "The jump drive is recharging after the last jump. Board a ship first."
		GameSession.Jump.ORDER_PENDING:
			if GameSession.order_arrived():
				return "Your antimatter has arrived. Collect it at the trader terminal before jumping on."
			return "Antimatter is on order and arrives at the hub on day %d. Wait for it before jumping on." % \
				GameSession.order_day
		_:
			return "Not enough antimatter: the jump to %s burns %d, the tank holds %d. Order more at the trader terminal." % [
				target.display_name, GameSession.jump_cost(target), GameSession.antimatter]


## The pointer in the map's own pixels.
func _map_point() -> Vector2:
	return _map.get_global_transform().affine_inverse() * (get_global_transform() * pointer)
