class_name Section
extends Node3D
## A piece of the wreck kit. It fills whole grid cells and joins other sections through its sockets.
## Its origin is the centre of its footprint, at the floor of its lowest deck.

## Footprint in grid cells: x, decks, z.
@export var size := Vector3i.ONE
## Whether drones can move through it. Vents and elevators can't, so they get no navigation.
@export var navigable := true


func get_sockets() -> Array[Socket]:
	var sockets: Array[Socket] = []
	_collect_sockets(self, sockets)
	return sockets


## The grid cells (x, deck, z) this section fills, wherever it has been placed.
func get_cells() -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	for x in size.x:
		for deck in size.y:
			for z in size.z:
				var local := Vector3(
					(x - (size.x - 1) / 2.0) * WreckAssembly.CELL_SIZE,
					deck * WreckAssembly.DECK_HEIGHT,
					(z - (size.z - 1) / 2.0) * WreckAssembly.CELL_SIZE)
				cells.append(WreckAssembly.to_cell(global_transform * local))
	return cells


## Called by the wreck once every socket has been joined and built, for sections that need what their sockets
## built (such as the elevator's doors).
func assembled() -> void:
	pass


static func _collect_sockets(node: Node, sockets: Array[Socket]) -> void:
	for child in node.get_children():
		if child is Socket:
			sockets.append(child)
		elif not child is Section:
			_collect_sockets(child, sockets)
