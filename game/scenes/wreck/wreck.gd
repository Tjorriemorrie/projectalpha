class_name Wreck
extends Node3D
## A wreck assembled from kit sections. On load it joins the sockets of its sections, opens up the walls they
## join, and reports everything that doesn't fit (see WreckAssembly).

var sections: Array[Section] = []
## Everything that didn't fit when the wreck assembled; empty when it assembled cleanly.
var assembly_errors := PackedStringArray()
var plan: WreckAssembly.Plan


func _ready() -> void:
	assemble()


func assemble() -> void:
	sections.clear()
	_collect(self, Section, sections)
	Log.info("🧩 Assembling wreck: wreck=%s, sections=%d" % [name, sections.size()])

	var sockets: Array[Socket] = []
	var infos: Array[WreckAssembly.SocketInfo] = []
	var cells := {}
	for section in sections:
		cells[section.name] = section.get_cells()
		for socket in section.get_sockets():
			sockets.append(socket)
			infos.append(WreckAssembly.SocketInfo.new("%s/%s" % [section.name, socket.name], socket.global_position,
					socket.get_outward(), socket.kind, socket.accepts_corridor, socket.required))
	plan = WreckAssembly.plan(infos, cells)
	Log.info("🧩 Planned socket joins: sockets=%d, joins=%d, doorways=%d, vent_mouths=%d, closed_walls=%d" % [
		sockets.size(), plan.joins, plan.count_openings(Socket.Opening.DOORWAY),
		plan.count_openings(Socket.Opening.VENT_MOUTH), plan.closed_walls])

	for index in sockets.size():
		if plan.partners[index] >= 0:
			sockets[index].join(sockets[plan.partners[index]], plan.openings[index])
	for section in sections:
		section.assembled()

	assembly_errors = plan.errors
	for error in assembly_errors:
		Log.error("🧩 Wreck assembly problem: wreck=%s, %s" % [name, error])
	var markers: Array[Node] = []
	_collect(self, SectionMarker, markers)
	var lamps: Array[Node] = []
	_collect(self, CeilingLamp, lamps)
	var enemy_markers := markers.filter(func(marker: SectionMarker) -> bool:
		return marker.kind == SectionMarker.Kind.ENEMY).size()
	var flickering := lamps.filter(func(lamp: CeilingLamp) -> bool: return lamp.flickering).size()
	var summary := "wreck=%s, sections=%d, joins=%d, errors=%d, enemy_markers=%d, loot_markers=%d, lamps=%d, flickering=%d" % [
		name, sections.size(), plan.joins, assembly_errors.size(), enemy_markers, markers.size() - enemy_markers,
		lamps.size(), flickering]
	if assembly_errors.is_empty():
		Log.info("🧩 Wreck assembled: " + summary)
	else:
		Log.error("🧩 Wreck assembled with problems: " + summary)


static func _collect(node: Node, type: Variant, found: Array) -> void:
	for child in node.get_children():
		if is_instance_of(child, type):
			found.append(child)
		_collect(child, type, found)
