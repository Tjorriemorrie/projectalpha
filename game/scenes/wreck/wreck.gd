class_name Wreck
extends Node3D
## A wreck assembled from kit sections. On load it joins the sockets of its sections, opens up the walls they
## join, and reports everything that doesn't fit (see WreckAssembly). Then it bakes the navigation drones fly by,
## one region per deck, and places the robots of its enemy list on their markers.

## The drones' navigation agent: its radius keeps paths off the walls, and its height keeps them out of vents.
const AGENT_RADIUS := 0.375
const AGENT_HEIGHT := 2.0
const AGENT_MAX_CLIMB := 0.25
## Metres below and above a deck's floor that its navigation is baked from: high enough for doorways, but below
## the ceilings, so their tops never count as floor.
const NAVIGATION_BELOW := 0.5
const NAVIGATION_ABOVE := 2.4

## The robots to place: the path of an enemy marker (from the wreck) and the ID of the enemy that goes there.
## Missions will fill markers by difficulty later; until then each wreck lists its own.
@export var enemies: Dictionary[String, String] = {}
## Show the robots' state above them, for test levels.
@export var debug_robots := false

var sections: Array[Section] = []
## Everything that didn't fit when the wreck assembled; empty when it assembled cleanly.
var assembly_errors := PackedStringArray()
var plan: WreckAssembly.Plan
## The robots the wreck placed, in the order of its enemy list.
var robots: Array[Robot] = []
var navigation_regions: Array[NavigationRegion3D] = []


func _ready() -> void:
	assemble()
	place_enemies()
	# CSG shapes rebuild at the end of the frame, so the walls the sockets changed are only there to bake from then.
	# Drones wait for the navigation.
	bake_navigation.call_deferred()


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
	assembly_errors.append_array(_find_unregistered_sections())
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


## Bakes one navigation region per deck from the static level geometry of the navigable sections: the collision
## faces of their CSG shapes, including the walls the sockets built, so doorways the assembly opened are open. Door
## panels and the elevator platform are bodies, not CSG, so they never block it; vents and elevators aren't
## navigable.
func bake_navigation() -> void:
	var decks := {}
	var source := NavigationMeshSourceGeometryData3D.new()
	var shapes := 0
	for section in sections:
		for cell in section.get_cells():
			decks[cell.y] = true
		if not section.navigable:
			continue
		for node in section.find_children("*", "CSGShape3D", true, false):
			var shape := node as CSGShape3D
			if not shape.is_root_shape() or not shape.use_collision or not shape.collision_layer & 1:
				continue
			var faces := shape.bake_collision_shape().get_faces()
			if faces.is_empty():
				Log.warning("🧩 Navigation geometry without faces skipped: wreck=%s, shape=%s" % [
					name, get_path_to(shape)])
				continue
			source.add_faces(faces, shape.global_transform)
			shapes += 1
	Log.info("🧩 Baking navigation: wreck=%s, decks=%d, shapes=%d, faces=%d" % [
		name, decks.size(), shapes, source.get_vertices().size() / 3])
	var deck_list := decks.keys()
	deck_list.sort()
	for deck: int in deck_list:
		var navigation_mesh := _new_navigation_mesh(deck, source.get_bounds())
		NavigationServer3D.bake_from_source_geometry_data(navigation_mesh, source)
		var region := NavigationRegion3D.new()
		region.name = "NavigationDeck%d" % deck
		region.navigation_mesh = navigation_mesh
		add_child(region)
		navigation_regions.append(region)
		Log.info("🧩 Baked deck navigation: wreck=%s, deck=%d, polygons=%d, vertices=%d" % [
			name, deck, navigation_mesh.get_polygon_count(), navigation_mesh.get_vertices().size()])
	Log.info("🧩 Navigation baked: wreck=%s, regions=%d" % [name, navigation_regions.size()])


## Places a robot on every marker of the enemy list. Markers that aren't enemy markers, unknown enemies, and
## enemies that don't fit their marker's mount are assembly errors, and those robots are left out.
func place_enemies() -> void:
	if enemies.is_empty():
		Log.info("🧩 No robots to place: wreck=%s" % name)
		return
	var parent := Node3D.new()
	parent.name = "Robots"
	add_child(parent)
	var problems := PackedStringArray()
	for marker_path in enemies:
		var id := enemies[marker_path]
		var marker := get_node_or_null(NodePath(marker_path)) as SectionMarker
		if marker == null or marker.kind != SectionMarker.Kind.ENEMY:
			problems.append("Not an enemy marker: marker=%s, enemy=%s" % [marker_path, id])
			continue
		var definition := ContentRegistry.get_definition(id) as EnemyDefinition
		if definition == null:
			problems.append("Not a registered enemy: marker=%s, enemy=%s" % [marker_path, id])
			continue
		if definition.mount != marker.mount:
			problems.append("Enemy doesn't fit its marker: marker=%s, enemy=%s, mount=%s, marker_mount=%s" % [
				marker_path, id, SectionMarker.Mount.keys()[definition.mount], SectionMarker.Mount.keys()[marker.mount]])
			continue
		var robot := (load(definition.get_scene_path()) as PackedScene).instantiate() as Robot
		if robot == null:
			problems.append("Enemy scene root is not a Robot: marker=%s, enemy=%s" % [marker_path, id])
			continue
		robot.name = "%s_%s" % [definition.id.get_slice(":", 1).to_pascal_case(), marker.get_parent().name]
		robot.definition = definition
		robot.debug_label = debug_robots
		robot.transform = parent.global_transform.affine_inverse() * marker.global_transform
		parent.add_child(robot, true)
		robots.append(robot)
	for problem in problems:
		Log.error("🧩 Wreck assembly problem: wreck=%s, %s" % [name, problem])
	assembly_errors.append_array(problems)
	Log.info("🧩 Robots placed: wreck=%s, robots=%d, listed=%d, problems=%d" % [
		name, robots.size(), enemies.size(), problems.size()])


## A navigation mesh for the drones on one deck, baked only from the slice of the wreck around that deck's floor.
func _new_navigation_mesh(deck: int, bounds: AABB) -> NavigationMesh:
	var navigation_mesh := NavigationMesh.new()
	# From the project settings: the map only takes its cell size at its first update, which may not have happened.
	navigation_mesh.cell_size = ProjectSettings.get_setting("navigation/3d/default_cell_size")
	navigation_mesh.cell_height = ProjectSettings.get_setting("navigation/3d/default_cell_height")
	navigation_mesh.agent_radius = AGENT_RADIUS
	navigation_mesh.agent_height = AGENT_HEIGHT
	navigation_mesh.agent_max_climb = AGENT_MAX_CLIMB
	var floor_height := deck * WreckAssembly.DECK_HEIGHT
	navigation_mesh.filter_baking_aabb = AABB(
			Vector3(bounds.position.x, floor_height - NAVIGATION_BELOW, bounds.position.z),
			Vector3(bounds.size.x, NAVIGATION_BELOW + NAVIGATION_ABOVE, bounds.size.z))
	return navigation_mesh


## Every section must be a section registered in the ContentRegistry, found by its scene.
func _find_unregistered_sections() -> PackedStringArray:
	var registered := {}
	for definition: SectionDefinition in ContentRegistry.get_all(SectionDefinition):
		registered[definition.get_scene_path()] = definition.id
	var problems := PackedStringArray()
	for section in sections:
		if not registered.has(section.scene_file_path):
			problems.append("Section is not a registered section: section=%s, scene=%s" % [
				section.name, section.scene_file_path])
	Log.info("🧩 Checked sections against the content registry: wreck=%s, sections=%d, registered_sections=%d, unregistered=%d" % [
		name, sections.size(), registered.size(), problems.size()])
	return problems


static func _collect(node: Node, type: Variant, found: Array) -> void:
	for child in node.get_children():
		if is_instance_of(child, type):
			found.append(child)
		_collect(child, type, found)
