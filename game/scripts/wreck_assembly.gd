class_name WreckAssembly
extends RefCounted
## The wreck kit's joining rules and assembly checks, kept free of nodes so they can be unit tested.
## Sections fill 4 m grid cells with cell centres on multiples of CELL_SIZE, and deck n has its floor at
## y = n * DECK_HEIGHT. Sockets sit at the centre of a cell edge and face out of their section.

const CELL_SIZE := 4.0
const DECK_HEIGHT := 4.0
## Sockets closer together than this are at the same place.
const POSITION_TOLERANCE := 0.01
## Joined sockets must face each other at least this closely (dot product of their directions).
const FACING_TOLERANCE := -0.99


## One socket as the assembly sees it: where it is, which way it faces, and what it can join.
class SocketInfo:
	var label: String
	var position: Vector3
	var outward: Vector3
	var kind: Socket.Kind
	var accepts_corridor: bool
	var required: bool

	func _init(socket_label: String, socket_position: Vector3, socket_outward: Vector3, socket_kind: Socket.Kind,
			socket_accepts_corridor := true, socket_required := false) -> void:
		label = socket_label
		position = socket_position
		outward = socket_outward
		kind = socket_kind
		accepts_corridor = socket_accepts_corridor
		required = socket_required


## The outcome of assembling: each socket's partner (an index, or -1) and opening, plus everything that
## doesn't fit.
class Plan:
	var partners := PackedInt32Array()
	var openings: Array[Socket.Opening] = []
	var errors := PackedStringArray()
	var joins := 0
	var closed_walls := 0

	func count_openings(opening: Socket.Opening) -> int:
		return openings.count(opening)


## What two sockets build when they join, as [opening of a, opening of b], or an empty array when they can't
## join. Corridor and vent ends join their own kind or a wall; a wall opens up for whatever joins it.
static func openings_for(a: SocketInfo, b: SocketInfo) -> Array[Socket.Opening]:
	if a.kind == Socket.Kind.WALL and b.kind == Socket.Kind.WALL:
		return []
	if a.kind == Socket.Kind.WALL:
		var opening := _wall_opening(a, b.kind)
		if opening == Socket.Opening.NONE:
			return []
		return [opening, Socket.Opening.NONE]
	if b.kind == Socket.Kind.WALL:
		var reversed := openings_for(b, a)
		if reversed.is_empty():
			return []
		return [reversed[1], reversed[0]]
	if a.kind == b.kind:
		return [Socket.Opening.NONE, Socket.Opening.NONE]
	return []


## Joins every pair of sockets that share a place and face each other, decides their openings, and reports
## loose ends, mismatches, sockets off the grid and sections that overlap. section_cells maps each section's
## label to the grid cells it fills.
static func plan(sockets: Array[SocketInfo], section_cells: Dictionary) -> Plan:
	var result := Plan.new()
	result.partners.resize(sockets.size())
	result.partners.fill(-1)
	for socket in sockets:
		result.openings.append(Socket.Opening.NONE)
		if not is_on_grid(socket):
			result.errors.append("Socket off the grid: socket=%s, position=%s, outward=%s" % [
				socket.label, socket.position, socket.outward])

	var by_place := {}
	for index in sockets.size():
		var key := Vector3i((sockets[index].position / POSITION_TOLERANCE).round())
		if not by_place.has(key):
			by_place[key] = []
		by_place[key].append(index)
	for indices: Array in by_place.values():
		if indices.size() == 2:
			_join(sockets, indices[0], indices[1], result)
		elif indices.size() > 2:
			var labels := PackedStringArray(indices.map(func(i: int) -> String: return sockets[i].label))
			result.errors.append("More than two sockets in one place: sockets=%s, position=%s" % [
				", ".join(labels), sockets[indices[0]].position])

	for index in sockets.size():
		var socket := sockets[index]
		if result.partners[index] >= 0:
			continue
		if socket.kind != Socket.Kind.WALL or socket.required:
			result.errors.append("Loose socket, nothing joins it: socket=%s, kind=%s, position=%s" % [
				socket.label, Socket.Kind.keys()[socket.kind], socket.position])
		else:
			result.closed_walls += 1

	_check_overlaps(section_cells, result)
	return result


## Whether a socket sits at the centre of a cell edge, on a deck's floor, facing across that edge.
static func is_on_grid(socket: SocketInfo) -> bool:
	var grid := Vector3(socket.position.x / CELL_SIZE, socket.position.y / DECK_HEIGHT, socket.position.z / CELL_SIZE)
	var on_deck := absf(grid.y - roundf(grid.y)) * DECK_HEIGHT < POSITION_TOLERANCE
	var on_x_edge := _is_half(grid.x) and _is_whole(grid.z)
	var on_z_edge := _is_half(grid.z) and _is_whole(grid.x)
	var faces_x := absf(absf(socket.outward.x) - 1.0) < POSITION_TOLERANCE
	var faces_z := absf(absf(socket.outward.z) - 1.0) < POSITION_TOLERANCE
	return on_deck and ((on_x_edge and faces_x) or (on_z_edge and faces_z))


## The grid cell (x, deck, z) that contains a position.
static func to_cell(position: Vector3) -> Vector3i:
	return Vector3i(roundi(position.x / CELL_SIZE), floori(position.y / DECK_HEIGHT + POSITION_TOLERANCE),
			roundi(position.z / CELL_SIZE))


static func _join(sockets: Array[SocketInfo], a: int, b: int, result: Plan) -> void:
	var socket_a := sockets[a]
	var socket_b := sockets[b]
	if socket_a.outward.dot(socket_b.outward) > FACING_TOLERANCE:
		result.errors.append("Sockets in one place don't face each other: sockets=%s, %s, position=%s" % [
			socket_a.label, socket_b.label, socket_a.position])
		return
	var openings := openings_for(socket_a, socket_b)
	if openings.is_empty():
		result.errors.append("Sockets can't join: sockets=%s (%s), %s (%s), position=%s" % [
			socket_a.label, _describe_kind(socket_a), socket_b.label, _describe_kind(socket_b), socket_a.position])
		return
	result.partners[a] = b
	result.partners[b] = a
	result.openings[a] = openings[0]
	result.openings[b] = openings[1]
	result.joins += 1


static func _check_overlaps(section_cells: Dictionary, result: Plan) -> void:
	var owners := {}
	for label: String in section_cells:
		for cell: Vector3i in section_cells[label]:
			if owners.has(cell):
				result.errors.append("Sections overlap: sections=%s, %s, cell=%s" % [owners[cell], label, cell])
			else:
				owners[cell] = label


static func _wall_opening(wall: SocketInfo, other_kind: Socket.Kind) -> Socket.Opening:
	match other_kind:
		Socket.Kind.CORRIDOR:
			return Socket.Opening.DOORWAY if wall.accepts_corridor else Socket.Opening.NONE
		Socket.Kind.VENT:
			return Socket.Opening.VENT_MOUTH
		_:
			return Socket.Opening.NONE


static func _describe_kind(socket: SocketInfo) -> String:
	var kind_name: String = Socket.Kind.keys()[socket.kind]
	if socket.kind == Socket.Kind.WALL and not socket.accepts_corridor:
		return kind_name + ", vents only"
	return kind_name


static func _is_whole(value: float) -> bool:
	return absf(value - roundf(value)) * CELL_SIZE < POSITION_TOLERANCE


static func _is_half(value: float) -> bool:
	return _is_whole(value - 0.5)
