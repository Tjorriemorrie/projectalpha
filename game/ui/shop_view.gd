class_name ShopView
extends Control
## Draws the trader hub's shelf for the trader screen: a tile for every item on sale, COLUMNS to a row, each a
## recessed well with the item's icon fitted into it (or tinted, without an icon) and its buy price under it,
## in red with the icon dimmed when the wallet can't cover it. The tile under the pointer is outlined brighter. It only
## draws and finds the tile under a point; the TraderScreen does the buying. It redraws when what it shows changes.

const COLUMNS := 4
## Pixels between tiles, the padding round an icon in its tile, and the height of the price under it.
const GAP := 6.0
const PADDING := 6.0
const PRICE_HEIGHT := 18.0
const WELL_COLOR := Color(0.862745, 0.901961, 0.941176, 0.05)
const EDGE_COLOR := Color(0.862745, 0.901961, 0.941176, 0.1)
const HOVER_COLOR := Color(0.862745, 0.901961, 0.941176, 0.85)
const OUTLINE_COLOR := Color(0.862745, 0.901961, 0.941176, 0.42)
const PRICE_COLOR := Color(0.862745, 0.901961, 0.941176)
const DANGER_COLOR := Color(1.0, 0.12, 0.08)
## How strongly an unaffordable item's icon shows.
const UNAFFORDABLE_ALPHA := 0.4

var trader: Trader
## What is on sale, in shelf order.
var definitions: Array[ItemDefinition] = []
## The bitcoin in the wallet, to show what can't be afforded.
var bitcoin := 0
## The item under the pointer, outlined brighter, or null.
var hovered: ItemDefinition
var tile_px := 56.0

var _font: Font


func setup(hub: Trader, shelf: Array[ItemDefinition], tile_size: float, font: Font) -> void:
	trader = hub
	definitions = shelf
	tile_px = tile_size
	_font = font
	var rows := ceili(float(definitions.size()) / COLUMNS)
	custom_minimum_size = Vector2(COLUMNS * tile_px + (COLUMNS - 1) * GAP,
		rows * (tile_px + PRICE_HEIGHT) + maxi(rows - 1, 0) * GAP)
	hovered = null
	queue_redraw()


func set_bitcoin(amount: int) -> void:
	if amount == bitcoin:
		return
	bitcoin = amount
	queue_redraw()


func set_hovered(definition: ItemDefinition) -> void:
	if definition == hovered:
		return
	hovered = definition
	queue_redraw()


## The item whose tile is under a point in this control's pixels, or null.
func definition_at(local_position: Vector2) -> ItemDefinition:
	for i in definitions.size():
		if tile_rect(i).has_point(local_position):
			return definitions[i]
	return null


## The rectangle of the i-th tile, its price included, in this control's pixels.
func tile_rect(index: int) -> Rect2:
	var column := index % COLUMNS
	var row := floori(index / float(COLUMNS))
	return Rect2(column * (tile_px + GAP), row * (tile_px + PRICE_HEIGHT + GAP), tile_px, tile_px + PRICE_HEIGHT)


## The middle of an item's tile, in this control's pixels; the far corner when it isn't on the shelf.
func tile_center(definition: ItemDefinition) -> Vector2:
	var index := definitions.find(definition)
	return tile_rect(index).get_center() if index >= 0 else size


func _draw() -> void:
	if trader == null:
		return
	for i in definitions.size():
		var definition := definitions[i]
		var rect := tile_rect(i)
		var well := Rect2(rect.position, Vector2.ONE * tile_px)
		var price := trader.buy_price(definition)
		var affordable := price <= bitcoin
		draw_rect(well, WELL_COLOR)
		draw_rect(well, HOVER_COLOR if definition == hovered else EDGE_COLOR, false, 1.0)
		ItemGridView.draw_item(self, definition, well.position + Vector2.ONE * PADDING, tile_px - 2.0 * PADDING,
			HOVER_COLOR if definition == hovered else OUTLINE_COLOR, 1.0 if affordable else UNAFFORDABLE_ALPHA)
		draw_string(_font, Vector2(rect.position.x, rect.end.y - 4.0), Bitcoin.format(price),
			HORIZONTAL_ALIGNMENT_CENTER, tile_px, 12, PRICE_COLOR if affordable else DANGER_COLOR)
