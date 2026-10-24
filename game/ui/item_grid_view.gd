class_name ItemGridView
extends Control
## Draws one ItemGrid for the item screens: its slots as recessed wells, each stack as its item's icon fitted into its
## slot (or, without an icon, the slot tinted) with its count in the corner once there is more than one, the stack
## under the pointer outlined brighter and the selected stack with a thick border, the slot a stack in hand left, and
## the slot a stack in hand would land in, in the laser's blue when it can and red when it can't. A grid taller than
## max_rows shows that many rows and scrolls. It only draws and converts between pixels and slots; the screen does
## the dragging. It redraws when its grid changes and fits its size to the grid's rows, emitting rows_changed so the
## screen lays out again.

## Emitted when the rows it shows change, after the grid grew or shrank.
signal rows_changed

const WELL_COLOR := Color(0.862745, 0.901961, 0.941176, 0.05)
const LINE_COLOR := Color(0.862745, 0.901961, 0.941176, 0.1)
const ITEM_COLOR := Color(0.862745, 0.901961, 0.941176, 0.1)
const OUTLINE_COLOR := Color(0.862745, 0.901961, 0.941176, 0.42)
const HOVER_COLOR := Color(0.862745, 0.901961, 0.941176, 0.85)
const SELECTED_COLOR := Color(0.862745, 0.901961, 0.941176, 1.0)
const SELECTED_FILL := Color(0.862745, 0.901961, 0.941176, 0.1)
const SELECTED_WIDTH := 3.0
const CUTOUT_COLOR := Color(0.0, 0.0, 0.0, 0.45)
const CUTOUT_EDGE := Color(0.862745, 0.901961, 0.941176, 0.22)
const FIT_COLOR := Color(0.62, 0.82, 1.0)
const DANGER_COLOR := Color(1.0, 0.12, 0.08)
const COUNT_COLOR := Color(0.862745, 0.901961, 0.941176)
const COUNT_SHADOW := Color(0.0, 0.0, 0.0, 0.8)
const SCROLL_COLOR := Color(0.862745, 0.901961, 0.941176, 0.35)
## The tint of a slot's stack when its item has no icon (headless runs), so it still reads.
const SCHEMATIC_COLOR := Color(0.36, 0.42, 0.5, 0.9)
## Pixels between a slot's edge and its icon.
const ICON_PADDING := 4.0

var grid: ItemGrid
var cell_px := 52.0
## The most rows it shows; a taller grid scrolls. 0 shows every row.
var max_rows := 0
## The first row it shows.
var scroll := 0
## The font the counts are drawn in.
var font: Font
## The stack under the pointer, outlined brighter.
var hovered: Item
## The selected stack, with a thick border.
var selected: Item

var _preview := ItemGrid.NO_CELL
var _preview_fits := false
var _cutout := ItemGrid.NO_CELL
var _shown_rows := 0


func setup(item_grid: ItemGrid, cell_size: float) -> void:
	if grid and grid.changed.is_connected(_on_grid_changed):
		grid.changed.disconnect(_on_grid_changed)
	grid = item_grid
	cell_px = cell_size
	scroll = 0
	grid.changed.connect(_on_grid_changed)
	_preview = ItemGrid.NO_CELL
	_cutout = ItemGrid.NO_CELL
	fit_size()
	queue_redraw()


## How many rows it shows now.
func visible_rows() -> int:
	return grid.size.y if max_rows <= 0 else mini(grid.size.y, max_rows)


## Fits its size to the rows it shows, and keeps the scroll within the grid.
func fit_size() -> void:
	scroll = clampi(scroll, 0, maxi(grid.size.y - visible_rows(), 0))
	custom_minimum_size = Vector2(grid.size.x, visible_rows()) * cell_px
	if visible_rows() != _shown_rows:
		_shown_rows = visible_rows()
		rows_changed.emit()


## Scrolls by rows (down for more than 0). Returns whether it moved.
func scroll_by(rows: int) -> bool:
	var target := clampi(scroll + rows, 0, maxi(grid.size.y - visible_rows(), 0))
	if target == scroll:
		return false
	scroll = target
	queue_redraw()
	return true


## Scrolls so a cell's row shows.
func scroll_to(cell: Vector2i) -> void:
	if cell.y < scroll:
		scroll_by(cell.y - scroll)
	elif cell.y >= scroll + visible_rows():
		scroll_by(cell.y - scroll - visible_rows() + 1)


## The cell of the slot under a point in this control's pixels; NO_CELL off the rows it shows.
func cell_at(local_position: Vector2) -> Vector2i:
	if local_position.x < 0.0 or local_position.y < 0.0 or local_position.y >= visible_rows() * cell_px:
		return ItemGrid.NO_CELL
	return Vector2i((local_position / cell_px).floor()) + Vector2i(0, scroll)


## The top left corner of a slot, in this control's pixels.
func cell_position(cell: Vector2i) -> Vector2:
	return Vector2(cell.x, cell.y - scroll) * cell_px


## Shows the slot a stack in hand would land in, and whether it can.
func set_preview(cell: Vector2i, fits: bool) -> void:
	if cell == _preview and fits == _preview_fits:
		return
	_preview = cell
	_preview_fits = fits
	queue_redraw()


func clear_preview() -> void:
	set_preview(ItemGrid.NO_CELL, false)


## Shows the empty slot a stack in hand left, until it lands somewhere.
func set_cutout(cell: Vector2i) -> void:
	_cutout = cell
	queue_redraw()


func set_hovered(item: Item) -> void:
	if item == hovered:
		return
	hovered = item
	queue_redraw()


func set_selected(item: Item) -> void:
	if item == selected:
		return
	selected = item
	queue_redraw()


## Draws a stack with its slot's top left at origin, size_px square: its tint, its icon fitted inside and its outline,
## and its count in the bottom right corner once there is more than one. Also used for the stack in hand, the item
## card's picture and the shop's tiles.
static func draw_item(canvas: CanvasItem, definition: ItemDefinition, origin: Vector2, size_px: float,
		outline: Color, alpha: float = 1.0, quantity: int = 1, count_font: Font = null) -> void:
	var rect := Rect2(origin, Vector2.ONE * size_px)
	var icon := ItemIcons.get_icon(definition)
	canvas.draw_rect(rect, (ITEM_COLOR if icon else SCHEMATIC_COLOR) * Color(1, 1, 1, alpha))
	if icon:
		var padding := minf(ICON_PADDING, size_px / 8.0)
		canvas.draw_texture_rect(icon, rect.grow(-padding), false, Color(1, 1, 1, alpha))
	canvas.draw_rect(rect, outline * Color(1, 1, 1, alpha), false, 1.5)
	if quantity <= 1:
		return
	var label_font := count_font if count_font else ThemeDB.fallback_font
	var font_size := maxi(roundi(size_px * 0.3), 11)
	var text := str(quantity)
	var corner := origin + Vector2(size_px - 4.0, size_px - 5.0)
	var width := label_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var at := Vector2(corner.x - width, corner.y)
	canvas.draw_string(label_font, at + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
		COUNT_SHADOW * Color(1, 1, 1, alpha))
	canvas.draw_string(label_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
		COUNT_COLOR * Color(1, 1, 1, alpha))


func _draw() -> void:
	if grid == null:
		return
	var inset := 1.0
	var rows := visible_rows()
	for row in range(scroll, scroll + rows):
		for column in grid.size.x:
			var cell := Vector2i(column, row)
			draw_rect(Rect2(cell_position(cell) + Vector2.ONE * inset, Vector2.ONE * (cell_px - 2.0 * inset)),
				WELL_COLOR)
	draw_rect(Rect2(Vector2.ZERO, Vector2(grid.size.x, rows) * cell_px), LINE_COLOR, false, 1.0)
	if _shows(_cutout):
		var cutout := Rect2(cell_position(_cutout), Vector2.ONE * cell_px)
		draw_rect(cutout, CUTOUT_COLOR)
		draw_rect(cutout, CUTOUT_EDGE, false, 1.0)
	for item in grid.items:
		if _shows(item.cell):
			draw_item(self, item.definition, cell_position(item.cell), cell_px,
				HOVER_COLOR if item == hovered else OUTLINE_COLOR, 1.0, item.quantity, font)
	if selected and grid.has(selected) and _shows(selected.cell):
		var box := Rect2(cell_position(selected.cell), Vector2.ONE * cell_px)
		draw_rect(box, SELECTED_FILL)
		draw_rect(box.grow(-SELECTED_WIDTH / 2.0), SELECTED_COLOR, false, SELECTED_WIDTH)
	if _shows(_preview):
		var color := FIT_COLOR if _preview_fits else DANGER_COLOR
		var box := Rect2(cell_position(_preview), Vector2.ONE * cell_px)
		draw_rect(box, color * Color(1, 1, 1, 0.2))
		draw_rect(box.grow(-1.0), color, false, 2.0)
	if grid.size.y > rows:
		_draw_scroll_bar(rows)


## A thin bar down the right edge showing which rows show of how many.
func _draw_scroll_bar(rows: int) -> void:
	var height := rows * cell_px
	var bar := Rect2(grid.size.x * cell_px + 3.0, height * scroll / grid.size.y, 3.0,
		height * rows / grid.size.y)
	draw_rect(bar, SCROLL_COLOR)


func _shows(cell: Vector2i) -> bool:
	return grid.has_cell(cell) and cell.y >= scroll and cell.y < scroll + visible_rows()


func _on_grid_changed() -> void:
	fit_size()
	queue_redraw()
