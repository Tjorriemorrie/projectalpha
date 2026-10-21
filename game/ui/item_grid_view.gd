class_name ItemGridView
extends Control
## Draws one ItemGrid for the inventory screen: its cells as recessed wells, each item as one outlined silhouette of
## its shape with its icon turned and mirrored the way it lies (or, without an icon, its cells tinted), the item
## under the pointer outlined brighter and the selected item with a thick border, cells reserved for a reload's
## spent clip, the cut-out a dragged item left, and where a dragged item would land, in the laser's blue when it fits
## and red when it doesn't. It only draws and converts between pixels and cells; the InventoryScreen does the
## dragging. It redraws when its grid changes.

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
const RESERVED_COLOR := Color(1.0, 0.55, 0.15, 0.35)
## The tint of an item's cells when it has no icon (headless runs), so its shape still reads.
const SCHEMATIC_COLOR := Color(0.36, 0.42, 0.5, 0.9)

var grid: ItemGrid
var cell_px := 52.0
## The item under the pointer, outlined brighter.
var hovered: Item
## The selected item, with a thick border.
var selected: Item

var _preview: Array[Vector2i] = []
var _preview_fits := false
var _cutout: Array[Vector2i] = []


func setup(item_grid: ItemGrid, cell_size: float) -> void:
	if grid and grid.changed.is_connected(queue_redraw):
		grid.changed.disconnect(queue_redraw)
	grid = item_grid
	cell_px = cell_size
	custom_minimum_size = Vector2(grid.size) * cell_px
	grid.changed.connect(queue_redraw)
	_preview.clear()
	_cutout.clear()
	queue_redraw()


## Fits its size to the grid's again, after the grid grew.
func fit_size() -> void:
	custom_minimum_size = Vector2(grid.size) * cell_px


## The cell under a point in this control's pixels; it may be outside the grid.
func cell_at(local_position: Vector2) -> Vector2i:
	return Vector2i((local_position / cell_px).floor())


## The top left corner of a cell, in this control's pixels.
func cell_position(cell: Vector2i) -> Vector2:
	return Vector2(cell) * cell_px


## Shows where a dragged item would land, and whether it fits there.
func set_preview(cells: Array[Vector2i], fits: bool) -> void:
	if cells == _preview and fits == _preview_fits:
		return
	_preview = cells
	_preview_fits = fits
	queue_redraw()


func clear_preview() -> void:
	set_preview([], false)


## Shows the cut-out a dragged item left where it came from, until it lands somewhere.
func set_cutout(cells: Array[Vector2i]) -> void:
	_cutout = cells
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


## How an item's icon (rendered in its first orientation, icon_size pixels) maps onto the item lying in an
## orientation, starting at (0, 0): the same turns and mirroring as ItemShape gives its cells.
static func icon_transform(orientation: int, icon_size: Vector2) -> Transform2D:
	var x_axis := Vector2(-1.0, 0.0) if orientation >= 4 else Vector2(1.0, 0.0)
	var y_axis := Vector2(0.0, 1.0)
	for turn in orientation % 4:
		x_axis = Vector2(-x_axis.y, x_axis.x)
		y_axis = Vector2(-y_axis.y, y_axis.x)
	var transform := Transform2D(x_axis, y_axis, Vector2.ZERO)
	var corner := Vector2(INF, INF)
	for point: Vector2 in [Vector2.ZERO, Vector2(icon_size.x, 0.0), Vector2(0.0, icon_size.y), icon_size]:
		corner = corner.min(transform * point)
	transform.origin = -corner
	return transform


## Draws an item lying in an orientation with its top left at origin: its tinted silhouette, its icon and its
## outline. Also used by the inventory screen for the item being dragged.
static func draw_item(canvas: CanvasItem, definition: ItemDefinition, orientation: int, origin: Vector2,
		size_px: float, outline: Color, alpha: float = 1.0) -> void:
	var cells := ItemShape.oriented(definition.get_cells(), orientation)
	var icon := ItemIcons.get_icon(definition)
	var fill := ITEM_COLOR if icon else SCHEMATIC_COLOR
	for cell in cells:
		canvas.draw_rect(Rect2(origin + Vector2(cell) * size_px, Vector2.ONE * size_px), fill * Color(1, 1, 1, alpha))
	if icon:
		var icon_size := Vector2(ItemShape.size_of(definition.get_cells())) * size_px
		canvas.draw_set_transform_matrix(Transform2D(0.0, origin) * icon_transform(orientation, icon_size))
		canvas.draw_texture_rect(icon, Rect2(Vector2.ZERO, icon_size), false, Color(1, 1, 1, alpha))
		canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
	draw_outline(canvas, cells, origin, size_px, outline * Color(1, 1, 1, alpha), 1.5)


## Traces the outside edge of a set of cells as one line, so a shape reads as one piece.
static func draw_outline(canvas: CanvasItem, cells: Array[Vector2i], origin: Vector2, size_px: float, color: Color,
		width: float) -> void:
	var inside := {}
	for cell in cells:
		inside[cell] = true
	for cell in cells:
		var corner := origin + Vector2(cell) * size_px
		var far := corner + Vector2.ONE * size_px
		if not inside.has(cell + Vector2i.UP):
			canvas.draw_line(corner, Vector2(far.x, corner.y), color, width)
		if not inside.has(cell + Vector2i.DOWN):
			canvas.draw_line(Vector2(corner.x, far.y), far, color, width)
		if not inside.has(cell + Vector2i.LEFT):
			canvas.draw_line(corner, Vector2(corner.x, far.y), color, width)
		if not inside.has(cell + Vector2i.RIGHT):
			canvas.draw_line(Vector2(far.x, corner.y), far, color, width)


func _draw() -> void:
	if grid == null:
		return
	var inset := 1.0
	for row in grid.size.y:
		for column in grid.size.x:
			var cell := Vector2i(column, row)
			var rect := Rect2(cell_position(cell) + Vector2.ONE * inset, Vector2.ONE * (cell_px - 2.0 * inset))
			draw_rect(rect, WELL_COLOR)
			if grid.is_reserved(cell):
				draw_rect(rect, RESERVED_COLOR, false, 1.0)
	draw_rect(Rect2(Vector2.ZERO, Vector2(grid.size) * cell_px), LINE_COLOR, false, 1.0)
	for cell in _cutout:
		draw_rect(Rect2(cell_position(cell), Vector2.ONE * cell_px), CUTOUT_COLOR)
	if not _cutout.is_empty():
		draw_outline(self, _cutout, Vector2.ZERO, cell_px, CUTOUT_EDGE, 1.0)
	for item in grid.items:
		draw_item(self, item.definition, item.orientation, cell_position(item.cell), cell_px,
			HOVER_COLOR if item == hovered else OUTLINE_COLOR)
	if selected and grid.has(selected):
		for cell in selected.cells():
			draw_rect(Rect2(cell_position(cell), Vector2.ONE * cell_px), SELECTED_FILL)
		draw_outline(self, selected.cells(), Vector2.ZERO, cell_px, SELECTED_COLOR, SELECTED_WIDTH)
	if not _preview.is_empty():
		var color := FIT_COLOR if _preview_fits else DANGER_COLOR
		for cell in _preview:
			if grid.has_cell(cell):
				draw_rect(Rect2(cell_position(cell), Vector2.ONE * cell_px), color * Color(1, 1, 1, 0.2))
		draw_outline(self, _preview, Vector2.ZERO, cell_px, color, 2.0)
