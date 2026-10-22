class_name Wreck
extends Node3D
## A wreck assembled from kit sections. On load it joins the sockets of its sections, opens up the walls they
## join, and reports everything that doesn't fit (see WreckAssembly). A wreck that is a registered layout
## (WreckDefinition) then fills its enemy and loot lists from a roll (WreckRoll): the one the session hands over when
## the player boards it, or its own at a random level when the scene runs on its own. Then it places the robots of its
## enemy list and the containers of its loot list on their markers, and, when it has robots, bakes the navigation
## drones fly by, one region per deck. Its airlock is where the player's ship is docked: cycling it extracts the
## player.

## The drones' navigation agent: its radius keeps paths off the walls, and its height keeps them out of vents.
const AGENT_RADIUS := 0.375
const AGENT_HEIGHT := 2.0
const AGENT_MAX_CLIMB := 0.25
## Metres below and above a deck's floor that its navigation is baked from: high enough for doorways, but below
## the ceilings, so their tops never count as floor.
const NAVIGATION_BELOW := 0.5
const NAVIGATION_ABOVE := 2.4
## Metres around an airlock's inner door where no robot is rolled: boarding is done in secret, so nothing waits at
## the airlock.
const AIRLOCK_CLEARANCE := 5.0

## The robots to place: the path of an enemy marker (from the wreck) and the ID of the enemy that goes there.
## A registered layout fills it from its roll; the ship and the test levels list their own.
@export var enemies: Dictionary[String, String] = {}
## The containers to place on loot markers and exactly what is inside each. A registered layout fills it from its
## roll; the ship and the test levels list their own.
@export var loot: Array[LootPlacement] = []
## Show the robots' state above them, for test levels.
@export var debug_robots := false

var sections: Array[Section] = []
## Everything that didn't fit when the wreck assembled; empty when it assembled cleanly.
var assembly_errors := PackedStringArray()
var plan: WreckAssembly.Plan
## The robots the wreck placed, in the order of its enemy list.
var robots: Array[Robot] = []
## The containers the wreck placed, in the order of its loot list.
var containers: Array[LootContainer] = []
var navigation_regions: Array[NavigationRegion3D] = []
## The airlocks among its sections, where a ship can be docked.
var airlocks: Array[Airlock] = []
## The roll its enemy and loot lists came from, or null when it is no registered layout (the ship, the test levels).
var roll: WreckRoll


func _ready() -> void:
	assemble()
	_connect_airlocks()
	_roll_lists()
	place_enemies()
	place_loot()
	if robots.is_empty():
		Log.info("🧩 No robots, so no navigation to bake: wreck=%s" % name)
		return
	# CSG shapes rebuild at the end of the frame, so the walls the sockets changed are only there to bake from then.
	# Drones wait for the navigation.
	bake_navigation.call_deferred()
	Log.info("🧩 Wreck ready, navigation baking at the end of the frame: wreck=%s, robots=%d" % [name, robots.size()])


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
## navigable. The containers' footprints are cut out, so drones fly round them rather than into a locker.
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
	for container in containers:
		var footprint := container.get_footprint()
		source.add_projected_obstruction(footprint, footprint[0].y, container.get_height(), false)
	Log.info("🧩 Baking navigation: wreck=%s, decks=%d, shapes=%d, faces=%d, container_footprints=%d" % [
		name, decks.size(), shapes, source.get_vertices().size() / 3, containers.size()])
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


## Fills the enemy and loot lists from a roll, replacing what they held: its robots on random enemy markers clear of
## the airlocks, its containers on random loot markers, and what is inside them. Call it before the lists are placed.
func apply_roll(wreck_roll: WreckRoll) -> void:
	roll = wreck_roll
	var rng := roll.new_rng()
	var markers: Array[Node] = []
	_collect(self, SectionMarker, markers)
	var enemy_markers := {}
	var loot_markers := {}
	var near_airlock := 0
	for marker: SectionMarker in markers:
		var path := str(get_path_to(marker))
		if marker.kind == SectionMarker.Kind.LOOT:
			loot_markers[path] = marker.space
		elif _near_airlock(marker.global_position):
			near_airlock += 1
		else:
			enemy_markers[path] = marker.mount
	Log.info("🧩 Rolling the wreck: wreck=%s, layout=%s, level=%d, seed=%d, enemy_markers=%d, near_airlock=%d, loot_markers=%d" % [
		name, roll.definition.id, roll.level, roll.roll_seed, enemy_markers.size(), near_airlock, loot_markers.size()])

	enemies = roll.roll_enemies(enemy_markers, ContentRegistry.get_all(EnemyDefinition), rng)
	if enemies.size() < roll.robots:
		Log.warning("🧩 Too few enemy markers for the robots rolled: wreck=%s, robots=%d, placed=%d, enemy_markers=%d" % [
			name, roll.robots, enemies.size(), enemy_markers.size()])
	var gun := _spare_gun() if roll.level == 1 else null
	loot = roll.roll_loot(loot_markers, ContentRegistry.get_all(ContainerDefinition), gun, rng)
	for problem in roll.problems:
		Log.warning("🧩 Loot roll problem: wreck=%s, %s" % [name, problem])
	if loot.size() < roll.definition.containers:
		Log.warning("🧩 Too few loot markers for the containers: wreck=%s, containers=%d, placed=%d, loot_markers=%d" % [
			name, roll.definition.containers, loot.size(), loot_markers.size()])
	var items := 0
	for placement in loot:
		items += placement.items.size()
	Log.info("🧩 Wreck rolled: wreck=%s, layout=%s, level=%d, robots=%d, expected=%d, containers=%d, items=%d, loot_value=%d, gun=%s" % [
		name, roll.definition.id, roll.level, enemies.size(), roll.expected_robots(), loot.size(), items,
		roll.loot_value, gun.id if gun else "none"])


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


## Places a container on every marker of the loot list and packs its items into it in order. Markers that aren't
## loot markers, unknown containers and items, containers too big for a tight marker, and items that don't fit are
## assembly errors; those containers (or items) are left out.
func place_loot() -> void:
	if loot.is_empty():
		Log.info("🧩 No loot to place: wreck=%s" % name)
		return
	var parent := Node3D.new()
	parent.name = "Loot"
	add_child(parent)
	var problems := PackedStringArray()
	var items_packed := 0
	for placement in loot:
		if placement == null:
			problems.append("Empty loot placement")
			continue
		var marker := get_node_or_null(NodePath(placement.marker)) as SectionMarker
		if marker == null or marker.kind != SectionMarker.Kind.LOOT:
			problems.append("Not a loot marker: marker=%s, container=%s" % [placement.marker, placement.container])
			continue
		var definition := ContentRegistry.get_definition(placement.container) as ContainerDefinition
		if definition == null:
			problems.append("Not a registered container: marker=%s, container=%s" % [
				placement.marker, placement.container])
			continue
		if marker.space == SectionMarker.Space.TIGHT and not definition.fits_tight:
			problems.append("Container doesn't fit its marker: marker=%s, container=%s, space=TIGHT" % [
				placement.marker, placement.container])
			continue
		var items: Array[ItemDefinition] = []
		for id in placement.items:
			var item := ContentRegistry.get_definition(id) as ItemDefinition
			if item == null:
				problems.append("Not a registered item: marker=%s, item=%s" % [placement.marker, id])
				continue
			items.append(item)
		var container := (load(definition.get_scene_path()) as PackedScene).instantiate() as LootContainer
		if container == null:
			problems.append("Container scene root is not a LootContainer: marker=%s, container=%s" % [
				placement.marker, placement.container])
			continue
		container.name = "%s_%s" % [definition.id.get_slice(":", 1).to_pascal_case(), marker.get_parent().name]
		container.definition = definition
		container.transform = parent.global_transform.affine_inverse() * marker.global_transform
		parent.add_child(container, true)
		var left_out := container.fill(items)
		for item in left_out:
			problems.append("Item doesn't fit its container: marker=%s, container=%s, item=%s" % [
				placement.marker, placement.container, item.id])
		items_packed += items.size() - left_out.size()
		containers.append(container)
	for problem in problems:
		Log.error("🧩 Wreck assembly problem: wreck=%s, %s" % [name, problem])
	assembly_errors.append_array(problems)
	Log.info("🧩 Loot placed: wreck=%s, containers=%d, listed=%d, items=%d, problems=%d" % [
		name, containers.size(), loot.size(), items_packed, problems.size()])


## Listens to every airlock: cycling one is how the player leaves.
func _connect_airlocks() -> void:
	airlocks.clear()
	for section in sections:
		var airlock := section as Airlock
		if airlock:
			airlocks.append(airlock)
			airlock.cycled.connect(_on_airlock_cycled.bind(airlock))
	if airlocks.is_empty():
		Log.warning("🧩 Wreck has no airlock, the player can't leave it: wreck=%s" % name)
		return
	Log.info("🧩 Airlocks connected: wreck=%s, airlocks=%d" % [name, airlocks.size()])


## The player cycled an airlock. On a wreck that is the way back to their ship: they extract.
func _on_airlock_cycled(airlock: Airlock) -> void:
	var player := get_tree().get_first_node_in_group(Player.GROUP) as Player
	if player == null:
		Log.error("🧩 Airlock cycled with no player to extract: wreck=%s, airlock=%s" % [name, airlock.name])
		return
	Log.info("🧩 Player extracting: wreck=%s, airlock=%s" % [name, airlock.name])
	player.extract()


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


## A registered layout fills its lists from a roll: the one handed over when boarding, or its own at a random level.
## Anything else keeps its fixed lists.
func _roll_lists() -> void:
	var layout := _find_layout()
	if layout == null:
		Log.info("🧩 Not a registered layout, keeping its own lists: wreck=%s, enemies=%d, loot=%d" % [
			name, enemies.size(), loot.size()])
		return
	var handed := GameSession.take_boarding(layout)
	if handed == null:
		handed = WreckRoll.at_random_level(layout, RandomNumberGenerator.new())
		Log.info("🧩 Layout running on its own, rolled at random: wreck=%s, layout=%s, level=%d, seed=%d" % [
			name, layout.id, handed.level, handed.roll_seed])
	apply_roll(handed)


## The registered layout whose scene this is, or null.
func _find_layout() -> WreckDefinition:
	if scene_file_path.is_empty():
		return null
	for layout: WreckDefinition in ContentRegistry.get_all(WreckDefinition):
		if layout.get_scene_path() == scene_file_path:
			return layout
	return null


## The gun every level-1 wreck holds, so an empty-handed android can always re-arm: the cheapest registered gun.
func _spare_gun() -> WeaponDefinition:
	var cheapest: WeaponDefinition = null
	for gun: WeaponDefinition in ContentRegistry.get_all(WeaponDefinition):
		if cheapest == null or gun.value < cheapest.value:
			cheapest = gun
	if cheapest == null:
		Log.warning("🧩 No registered gun for a level-1 wreck: wreck=%s" % name)
		return null
	return cheapest


## Whether a point is too close to an airlock's inner door for a robot to wait there.
func _near_airlock(point: Vector3) -> bool:
	for airlock in airlocks:
		for socket in airlock.get_sockets():
			if socket.global_position.distance_to(point) < AIRLOCK_CLEARANCE:
				return true
	return false


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
