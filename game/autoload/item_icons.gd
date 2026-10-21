extends Node
## Renders the grid icon of every registered item from its model once, after the content registry has loaded:
## seen from straight above through an orthographic camera fitted to the item's shape (PIXELS_PER_CELL a cell, on a
## transparent background), so the icon covers exactly the item's cells in its first orientation. Without a renderer
## (headless runs and tests) there are no icons, and the grid draws the item's cells instead. Autoloaded as
## ItemIcons, after ContentRegistry. It has no class_name, which would clash with the autoload's name.

const PIXELS_PER_CELL := 64
## Metres above the item the camera looks down from.
const CAMERA_HEIGHT := 2.0
## Most a glowing part glows in an icon, so it keeps its colour instead of burning white.
const GLOW_ENERGY := 0.6

## Whether every item's icon has been rendered (or there is nothing to render with).
var is_done := false

var _icons := {}
var _viewport: SubViewport
var _camera: Camera3D


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		is_done = true
		Log.info("🎒 Item icons skipped, no renderer: display=%s" % DisplayServer.get_name())
		return
	_build_studio()
	_render_all.call_deferred()


## The icon of an item in its first orientation, or null while it isn't rendered (or never will be).
func get_icon(definition: ItemDefinition) -> Texture2D:
	return _icons.get(definition.id) if definition else null


func _render_all() -> void:
	var definitions := ContentRegistry.get_all(ItemDefinition)
	Log.info("🎒 Rendering item icons: items=%d, pixels_per_cell=%d" % [definitions.size(), PIXELS_PER_CELL])
	var rendered := 0
	for definition: ItemDefinition in definitions:
		if await _render(definition):
			rendered += 1
	_viewport.queue_free()
	is_done = true
	Log.info("🎒 Item icons rendered: rendered=%d, items=%d" % [rendered, definitions.size()])


func _render(definition: ItemDefinition) -> bool:
	var path := definition.get_model_path()
	var scene := load(path) as PackedScene if ResourceLoader.exists(path) else null
	if scene == null:
		Log.warning("🎒 Item icon not rendered, model missing: item=%s, model=%s" % [definition.id, path])
		return false
	var cells := ItemShape.size_of(definition.get_cells())
	var model := scene.instantiate() as Node3D
	_tame_glow(model)
	_viewport.add_child(model)
	_viewport.size = cells * PIXELS_PER_CELL
	_camera.size = cells.y * ItemDefinition.CELL_SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var image := _viewport.get_texture().get_image()
	model.queue_free()
	if image == null or image.is_empty():
		Log.warning("🎒 Item icon came out empty: item=%s, size=%s" % [definition.id, _viewport.size])
		return false
	image.generate_mipmaps()
	_icons[definition.id] = ImageTexture.create_from_image(image)
	return true


## Glowing parts are made to glow in the dark wreck; at full strength they burn white in an icon and lose their
## colour, so the icon's copy of the model glows at most GLOW_ENERGY.
func _tame_glow(model: Node3D) -> void:
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		for surface in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.get_active_material(surface) as StandardMaterial3D
			if source == null or not source.emission_enabled or source.emission_energy_multiplier <= GLOW_ENERGY:
				continue
			var material := source.duplicate() as StandardMaterial3D
			material.emission_energy_multiplier = GLOW_ENERGY
			mesh_instance.set_surface_override_material(surface, material)


## A little photo studio of its own: the viewport with its own world, a camera looking straight down (rows of the
## shape run down the image), a key light from the top left and a soft fill.
func _build_studio() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "IconStudio"
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.62, 0.68, 0.76)
	environment.ambient_light_energy = 0.35
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	_viewport.add_child(world)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.near = 0.05
	_camera.far = CAMERA_HEIGHT * 2.0
	_viewport.add_child(_camera)
	_camera.look_at_from_position(Vector3.UP * CAMERA_HEIGHT, Vector3.ZERO, Vector3.FORWARD)
	var key := DirectionalLight3D.new()
	key.light_energy = 0.9
	key.light_specular = 0.15
	_viewport.add_child(key)
	key.look_at_from_position(Vector3(-1.0, 2.0, -0.6), Vector3.ZERO, Vector3.UP)
	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.3
	fill.light_specular = 0.1
	fill.light_color = Color(0.7, 0.8, 1.0)
	_viewport.add_child(fill)
	fill.look_at_from_position(Vector3(1.0, 1.5, 1.0), Vector3.ZERO, Vector3.UP)
