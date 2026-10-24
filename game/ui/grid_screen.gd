class_name GridScreen
extends MenuScreen
## The base of the full-screen item screens in the HUD (the inventory and the trader hub): grids of square slots on
## placards in two columns either side of the screen's centre (see MenuScreen), each slot holding a stack of one kind.
## A stack is dragged with the pointer (inventory_drag), or split, half of it taken into hand (inventory_split), and
## while one is in hand the wheel takes one more off its slot or puts one back (inventory_more, inventory_fewer). A
## stack in hand lands in a free slot, or tops up a stack of its kind with the rest going back; one that can't land
## goes back where it came from. Shift-clicking or double-clicking a stack moves it straight to the other side, which
## subclasses say (_quick_targets). Pressing on a stack selects it (a thick border), and the stack under the pointer
## shows its item card beside the pointer. The wheel scrolls a grid too tall to show whole. Subclasses build the
## columns (_build), say which grids they show (_views) and what happens around the moves (the _on_* hooks); the
## player opens and closes them.

const DRAG_OUTLINE := Color(0.62, 0.82, 1.0, 0.9)
## Slot size as a fraction of the screen height, and its limits in pixels.
const CELL_FRACTION := 0.065
const MIN_CELL := 44.0
const MAX_CELL := 80.0
## The item card: its width, inner margin, the largest the picture is drawn, and how far it sits from the pointer.
const CARD_WIDTH := 260.0
const CARD_MARGIN := 12.0
const CARD_PICTURE := 96.0
const CARD_OFFSET := Vector2(22.0, 18.0)

@export var pick_sound: AudioStream = preload("res://assets/audio/loot/item_pick.wav")
@export var place_sound: AudioStream = preload("res://assets/audio/loot/item_place.wav")

## The stack in hand, out of every grid until it lands, or null.
var dragged: Item
## The selected stack (pressed on last), or null.
var selected: Item
## The stack under the pointer, whose card shows, or null.
var focused: Item

var _cell_px := 52.0
## Where the stack in hand came from, to put it back when it can't land.
var _drag_view: ItemGridView
var _drag_cell := Vector2i.ZERO
## The stack the hand was taken from: the same as dragged while all of it is in hand, else still in its slot with
## the rest.
var _drag_source: Item


## The middle of a grid's slot, in this control's pixels: where the pointer goes to point at it. A grid that scrolls
## scrolls the slot into view first.
func cell_center(grid: ItemGrid, cell: Vector2i) -> Vector2:
	var view := _view_of(grid)
	view.scroll_to(cell)
	var middle := view.get_global_transform() * (view.cell_position(cell) + Vector2.ONE * view.cell_px / 2.0)
	return get_global_transform().affine_inverse() * middle


## Selects a stack (or nothing), shown with a thick border in its grid.
func select(item: Item) -> void:
	if item == selected:
		return
	selected = item
	for view in _views():
		view.set_selected(item)
	if item:
		Log.info("🎒 Item selected: item=%s, quantity=%d" % [item.definition.id, item.quantity])


## Picks up the whole stack in a slot of a grid to drag it, and selects it. Returns whether there was one.
func begin_drag(grid: ItemGrid, cell: Vector2i) -> bool:
	var item := grid.item_at(cell) if _view_of(grid) else null
	if item == null:
		return false
	return _pick_up(grid, item, item.quantity)


## Picks up half a stack in a slot (rounded up) to drag it, leaving the rest there; a stack of one is picked up
## whole. Returns whether there was one.
func begin_split(grid: ItemGrid, cell: Vector2i) -> bool:
	var item := grid.item_at(cell) if _view_of(grid) else null
	if item == null:
		return false
	return _pick_up(grid, item, ceili(item.quantity / 2.0))


## Takes one more off the slot the stack in hand came from (step 1), or puts one back (step -1): the hand holds
## between one and all of that stack. Returns whether the hand changed.
func adjust_drag(step: int) -> bool:
	if dragged == null:
		return false
	var grid := _drag_view.grid
	var left := _drag_source.quantity if dragged != _drag_source and grid.has(_drag_source) else 0
	var total := dragged.quantity + left
	var target := clampi(dragged.quantity + step, 1, total)
	if target == dragged.quantity:
		return false
	if target == total:
		# All of it in hand: the hand becomes the stack itself, and its slot empties.
		_drag_source.quantity = total
		grid.remove(_drag_source)
		dragged = _drag_source
		_drag_view.set_cutout(_drag_cell)
	elif dragged == _drag_source:
		# Putting one back from a whole stack: the stack goes back in its slot with what is left.
		dragged = Item.new(_drag_source.definition, target)
		_drag_source.quantity = total - target
		grid.place(_drag_source, _drag_cell)
		_drag_view.set_cutout(ItemGrid.NO_CELL)
	else:
		_drag_source.quantity = total - target
		dragged.quantity = target
	Log.info("🎒 Stack in hand adjusted: item=%s, in_hand=%d, left=%d" % [
		dragged.definition.id, dragged.quantity, total - dragged.quantity])
	_refresh()
	return true


## Puts the stack in hand down on a slot of grid: in a free slot it lands whole; on a stack of its kind it tops that
## up, and the rest goes back where it came from; anywhere else it all goes back. Returns whether any of it landed.
func drop_drag(grid: ItemGrid, cell: Vector2i) -> bool:
	if dragged == null:
		return false
	var item := dragged
	var from := _drag_view.grid
	var occupant := grid.item_at(cell)
	if occupant == null and grid.fits(item.definition, cell):
		grid.place(item, cell)
		_end_drag()
		_play(place_sound)
		Log.info("🎒 Stack moved: item=%s, quantity=%d, from=%s, to=%s, cell=%s" % [
			item.definition.id, item.quantity, _grid_name(from), _grid_name(grid), cell])
		_on_moved()
		return true
	var room := grid.room_at(item.definition, cell) if occupant else 0
	if room <= 0:
		_play(bump_sound)
		Log.info("🎒 Stack can't go there, back where it was: item=%s, grid=%s, cell=%s, occupant=%s" % [
			item.definition.id, _grid_name(grid), cell, occupant.definition.id if occupant else "none"])
		_return_drag()
		_on_moved()
		return false
	var amount := mini(room, item.quantity)
	occupant.quantity += amount
	item.quantity -= amount
	_play(place_sound)
	Log.info("🎒 Stack topped up: item=%s, moved=%d, from=%s, to=%s, cell=%s, now=%d, back=%d" % [
		item.definition.id, amount, _grid_name(from), _grid_name(grid), cell, occupant.quantity, item.quantity])
	if item.quantity > 0:
		_return_drag()
	else:
		_end_drag()
	_on_moved()
	return true


## Moves the stack in a slot straight to the other side (see _quick_targets): it tops up stacks of its kind there
## first, then takes a free slot; what doesn't fit stays where it was. Returns whether any of it moved.
func quick_move(grid: ItemGrid, cell: Vector2i) -> bool:
	var item := grid.item_at(cell) if _view_of(grid) else null
	if item == null or dragged:
		return false
	select(item)
	var targets := _quick_targets(item, grid)
	var before := item.quantity
	var moved := ItemGrid.stow(item, targets, grid) if not targets.is_empty() else 0
	if moved <= 0:
		_play(bump_sound)
		Log.info("🎒 Quick move found no room: item=%s, quantity=%d, from=%s, targets=%d" % [
			item.definition.id, before, _grid_name(grid), targets.size()])
		return false
	_play(place_sound)
	Log.info("🎒 Quick moved: item=%s, moved=%d, left=%d, from=%s, to=%s" % [
		item.definition.id, moved, before - moved, _grid_name(grid),
		"+".join(PackedStringArray(targets.map(func(target: ItemGrid) -> String: return _grid_name(target))))])
	_on_moved()
	_refresh()
	return true


## Shows the screen: sizes the slots for the window and resets the selection. Subclasses set up their views first.
func _show_screen() -> void:
	_cell_px = _cell_size()
	select(null)
	super()


## Hides the screen; a stack still in hand goes back where it came from.
func _hide_screen() -> void:
	if dragged:
		_return_drag()
		_on_moved()
	select(null)
	for view in _views():
		view.clear_preview()
		view.set_hovered(null)
	focused = null
	super()


## The slot size for the window's height now.
func _cell_size() -> float:
	return clampf(roundf(get_viewport_rect().size.y * CELL_FRACTION), MIN_CELL, MAX_CELL)


## A view for one grid, drawing its counts in the screen's font, which lays the screen out again when the rows it
## shows change.
func _make_view(max_rows: int = 0) -> ItemGridView:
	var view := ItemGridView.new()
	view.max_rows = max_rows
	view.font = _font
	view.rows_changed.connect(func() -> void: _layout.call_deferred())
	return view


func _handle_input(event: InputEvent) -> bool:
	var at := _grid_at_pointer()
	var button := event as InputEventMouseButton
	if event.is_action_pressed("inventory_drag"):
		var quick := button != null and (button.shift_pressed or button.double_click) and at.size() == 2 			and dragged == null and _can_quick_move(at[0], at[1])
		if quick:
			quick_move(at[0], at[1])
		elif at.size() == 2 and dragged == null and _on_slot_pressed(at[0], at[1]):
			pass
		elif not _on_pressed():
			select(null)
	elif event.is_action_released("inventory_drag"):
		if not _on_slot_released() and dragged:
			_release_drag(at)
	elif event.is_action_pressed("inventory_split"):
		if at.size() == 2 and dragged == null:
			begin_split(at[0], at[1])
	elif event.is_action_released("inventory_split") and dragged:
		_release_drag(at)
	elif event.is_action_pressed("inventory_more") and dragged:
		adjust_drag(1)
	elif event.is_action_pressed("inventory_fewer") and dragged:
		adjust_drag(-1)
	elif event.is_action_pressed("inventory_more") or event.is_action_pressed("inventory_fewer"):
		var view := _view_at_pointer()
		if view == null or not view.scroll_by(-1 if event.is_action_pressed("inventory_more") else 1):
			return false
	else:
		return false
	return true


## The button holding the stack in hand was let go: it lands on the slot under the pointer, goes back when let go on
## a placard but off the slots, and outside every placard the screen says (_on_released_outside()).
func _release_drag(at: Array) -> void:
	if at.size() == 2:
		drop_drag(at[0], at[1])
	elif _over_placard():
		_play(bump_sound)
		Log.info("🎒 Stack released on a placard, back where it was: item=%s" % dragged.definition.id)
		_return_drag()
		_on_moved()
	else:
		_on_released_outside()


## Whether the slot holds a stack a quick move has somewhere to send.
func _can_quick_move(grid: ItemGrid, cell: Vector2i) -> bool:
	var item := grid.item_at(cell)
	return item != null and not _quick_targets(item, grid).is_empty()


## A press on a slot: picks its stack up to drag it. Returns whether there was one; subclasses may do otherwise.
func _on_slot_pressed(grid: ItemGrid, cell: Vector2i) -> bool:
	return begin_drag(grid, cell)


## The drag button was let go. Returns whether the screen used the release itself (a click that wasn't a drag).
func _on_slot_released() -> bool:
	return false


## Puts the stack in hand back where it came from: onto what is left of its stack, or back into its slot, or (if
## that has gone meanwhile) wherever there is room in that grid.
func _return_drag() -> void:
	var item := dragged
	var grid := _drag_view.grid
	var source := _drag_source
	var cell := _drag_cell
	_end_drag()
	if item != source and grid.has(source) and source.room() >= item.quantity:
		source.quantity += item.quantity
		return
	if grid.place(item, cell) or grid.add(item):
		return
	# Only a reload's clip can land in a grid while a stack is in hand; if one took its slot, it isn't lost.
	Log.warning("🎒 Stack couldn't go back where it was: item=%s, quantity=%d, grid=%s, cell=%s" % [
		item.definition.id, item.quantity, _grid_name(grid), cell])
	_on_return_failed(item, grid)


func _pick_up(grid: ItemGrid, item: Item, amount: int) -> bool:
	if dragged:
		return false
	var view := _view_of(grid)
	select(item)
	_drag_view = view
	_drag_cell = item.cell
	_drag_source = item
	if amount >= item.quantity:
		dragged = item
		grid.remove(item)
		view.set_cutout(item.cell)
	else:
		dragged = grid.take(item, amount)
	_play(pick_sound)
	Log.info("🎒 Stack picked up: item=%s, in_hand=%d, left=%d, from=%s, cell=%s" % [
		item.definition.id, dragged.quantity, item.quantity if dragged != item else 0, _grid_name(grid), _drag_cell])
	_refresh()
	return true


func _end_drag() -> void:
	dragged = null
	_drag_source = null
	if _drag_view:
		_drag_view.set_cutout(ItemGrid.NO_CELL)
	for view in _views():
		view.clear_preview()
	_overlay.queue_redraw()


## Updates where the stack in hand would land, the stack under the pointer and the overlay. Runs on every pointer
## move.
func _refresh() -> void:
	var at := _grid_at_pointer()
	for view in _views():
		if dragged and at.size() == 2 and view.grid == at[0]:
			var cell: Vector2i = at[1]
			var occupant := view.grid.item_at(cell)
			var fits := view.grid.fits(dragged.definition, cell) if occupant == null \
				else view.grid.room_at(dragged.definition, cell) > 0
			view.set_preview(cell, fits)
		else:
			view.clear_preview()
	var hovered: Item = null
	if dragged == null and at.size() == 2:
		hovered = (at[0] as ItemGrid).item_at(at[1])
	if hovered != focused:
		focused = hovered
		for view in _views():
			view.set_hovered(hovered if hovered and view.grid.has(hovered) else null)
	_on_refreshed()
	super()


## The stack in hand under the pointer, or the card of what is under it.
func _draw_overlay() -> void:
	if dragged:
		var origin := pointer - Vector2.ONE * _cell_px / 2.0
		ItemGridView.draw_item(_overlay, dragged.definition, origin, _cell_px, DRAG_OUTLINE, 0.9, dragged.quantity,
			_font)
		return
	var definition := _card_definition()
	if definition:
		_draw_card(definition, _card_stats(definition))


## The item card beside the pointer: name, picture, three stats (label, value, colour) and description. It stays on
## the screen, moving to the other side of the pointer near an edge.
func _draw_card(definition: ItemDefinition, stats: Array) -> void:
	var inner := CARD_WIDTH - 2.0 * CARD_MARGIN
	var description_size := _body_font.get_multiline_string_size(definition.description, HORIZONTAL_ALIGNMENT_LEFT,
		inner, 13)
	var height := CARD_MARGIN + 22.0 + 8.0 + CARD_PICTURE + 12.0 + 34.0 + 8.0 + description_size.y + CARD_MARGIN
	var position := pointer + CARD_OFFSET
	var screen := _overlay.size
	if position.x + CARD_WIDTH > screen.x:
		position.x = pointer.x - CARD_OFFSET.x - CARD_WIDTH
	if position.y + height > screen.y:
		position.y = screen.y - height
	position = position.clamp(Vector2.ZERO, (screen - Vector2(CARD_WIDTH, height)).max(Vector2.ZERO))
	var box := Rect2(position, Vector2(CARD_WIDTH, height))
	_overlay.draw_rect(box, CARD_COLOR)
	_overlay.draw_rect(box, PLACARD_EDGE, false, 1.0)
	var y := position.y + CARD_MARGIN
	var left := position.x + CARD_MARGIN
	_overlay.draw_string(_font, Vector2(left, y + 17.0), definition.display_name, HORIZONTAL_ALIGNMENT_LEFT, inner,
		18, INK_COLOR)
	y += 22.0 + 8.0
	_overlay.draw_rect(Rect2(left, y, inner, CARD_PICTURE), Color(INK_COLOR, 0.04))
	ItemGridView.draw_item(_overlay, definition, Vector2(left + (inner - CARD_PICTURE) / 2.0, y), CARD_PICTURE,
		Color(INK_COLOR, 0.3))
	y += CARD_PICTURE + 12.0
	for i in stats.size():
		var x := left + inner / 3.0 * i
		var color: Color = stats[i][2] if stats[i].size() > 2 else INK_COLOR
		_overlay.draw_string(_label_font, Vector2(x, y + 9.0), stats[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
			DIM_TEXT_COLOR)
		_overlay.draw_string(_font, Vector2(x, y + 28.0), stats[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)
	y += 34.0 + 8.0
	_overlay.draw_line(Vector2(left, y - 4.0), Vector2(left + inner, y - 4.0), PLACARD_EDGE, 1.0)
	_overlay.draw_multiline_string(_body_font, Vector2(left, y + 13.0), definition.description,
		HORIZONTAL_ALIGNMENT_LEFT, inner, 13, -1, DIM_TEXT_COLOR)


## The grid and cell of the slot under the pointer, as [grid, cell], or [] when it isn't over a grid's slots.
func _grid_at_pointer() -> Array:
	var view := _view_at_pointer()
	if view == null:
		return []
	var cell := view.cell_at(view.get_global_transform().affine_inverse() * (get_global_transform() * pointer))
	return [view.grid, cell] if view.grid.has_cell(cell) else []


## The view under the pointer, or null.
func _view_at_pointer() -> ItemGridView:
	var at := get_global_transform() * pointer
	for view in _views():
		if not view.is_visible_in_tree():
			continue
		var local := view.get_global_transform().affine_inverse() * at
		if Rect2(Vector2.ZERO, view.custom_minimum_size).has_point(local):
			return view
	return null


func _grids() -> Array[ItemGrid]:
	var grids: Array[ItemGrid] = []
	for view in _views():
		grids.append(view.grid)
	return grids


func _view_of(grid: ItemGrid) -> ItemGridView:
	for view in _views():
		if view.grid == grid:
			return view
	return null


## The key hints: [action, what it does], or [&"", plain text].
func _hints() -> Array:
	return [[&"inventory_drag", "Drag"], [&"inventory_split", "Split"], [&"inventory_more", "One more or fewer"],
		[&"", "Shift-click to move across"], [&"inventory", "Close"]]


## The views of the grids the screen shows now.
func _views() -> Array[ItemGridView]:
	return []


## Where a quick move sends a stack from a grid, in order; none when it has nowhere to go.
func _quick_targets(_item: Item, _from: ItemGrid) -> Array[ItemGrid]:
	return []


## A grid's name for the log.
func _grid_name(_grid: ItemGrid) -> String:
	return "grid"


## Stacks moved: a stack in hand landed or went back, or a quick move moved one.
func _on_moved() -> void:
	pass


## The drag button was pressed where there is no stack to drag. Returns whether the screen used the press (a
## button); otherwise the selection clears.
func _on_pressed() -> bool:
	return false


## The stack in hand was let go outside every placard: it goes back where it came from.
func _on_released_outside() -> void:
	_play(bump_sound)
	Log.info("🎒 Stack released outside, back where it was: item=%s" % dragged.definition.id)
	_return_drag()
	_on_moved()


## The stack in hand couldn't go back where it came from, nor anywhere else in that grid.
func _on_return_failed(item: Item, grid: ItemGrid) -> void:
	Log.error("🎒 Stack couldn't go back, it is lost: item=%s, quantity=%d, grid=%s" % [
		item.definition.id, item.quantity, _grid_name(grid)])


## The pointer moved, after the grids updated what is under it.
func _on_refreshed() -> void:
	pass


## The item whose card shows: the one under the pointer.
func _card_definition() -> ItemDefinition:
	return focused.definition if focused else null


## The card's three stats: [label, value] or [label, value, colour]: what one is worth, the stack, and what the
## stack under the pointer is worth.
func _card_stats(definition: ItemDefinition) -> Array:
	var quantity := focused.quantity if focused else 1
	return [["VALUE", Bitcoin.format(definition.value)], ["STACK", "%d / %d" % [quantity, definition.stack_size]],
		["SLOT", Bitcoin.format(definition.value * quantity)]]
