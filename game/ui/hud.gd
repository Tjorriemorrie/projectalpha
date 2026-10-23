class_name Hud
extends CanvasLayer
## The player's heads-up display, styled like equipment placards: a centre dot that shows where the player is
## looking, with a ring that fills while a shot charges and a wider one that fills while interact is held (prying
## a container open); under it the prompt for the interactable they are looking at ("[E]  Call elevator", or
## "HOLD [E]  Pry open supply crate"); health in the bottom left and the loaded clip's heat in the bottom right (hidden
## while unarmed); at home on the ship, a bar across the top with the bitcoin in the wallet, the hydrogen and
## antimatter in the tanks (with the antimatter on order) and the day, which stays over every screen, so the wallet
## shows while buying intel on the star map; and the inventory, trader hub, system map and star map screens, which
## leave room for the bar, the two maps switching tabs in each other's place. Hits flash the screen edges red and point to where they came from, the edges stay faintly red while
## health is critical, and death fades to black. A run ends on black with the run summary placard, and an arrival
## fades in from black. The player calls it; it decides nothing.

## Seconds the prompt takes to fade in.
const FADE_TIME := 0.12
## Strength of the red screen edges just after a hit, and how fast it fades (per second).
const HIT_FLASH := 0.8
const HIT_FLASH_FADE := 2.0
## Strength of the red edges while health is critical, and how much and how fast they pulse.
const CRITICAL_EDGES := 0.3
const CRITICAL_PULSE := 0.08
const CRITICAL_PULSE_RATE := 0.8
const DANGER_COLOR := Color(1.0, 0.12, 0.08)
const INK_COLOR := Color(0.862745, 0.901961, 0.941176)
const DIM_COLOR := Color(0.721569, 0.768627, 0.815686)

var prompt_text := ""
## What the corner readouts say, for tests: e.g. "100" and "35% 2 fresh · 2 packed · 1 spent".
var health_text := ""
var clips_text := ""
## What the ship's bar says, for tests: e.g. "₿500", "24/24" and "3", or "" while it isn't shown (on a wreck).
var wallet_text := ""
var hydrogen_text := ""
var day_text := ""
## What the bar's antimatter says, for tests: e.g. "6/10", "2/10 8 ARRIVING DAY 7", "2/10 8 READY AT THE HUB", or
## "" while it isn't shown.
var antimatter_text := ""

var _fade: Tween
var _death_fade: Tween
var _hit_flash := 0.0
var _critical := false
var _pulse := 0.0
var _edges_material: ShaderMaterial
var _edge_intensity := 0.0
## What the clip readout last showed, so it is only restyled when that changes.
var _shown_clips := []
## Whether the ship's bar shows: at home on the ship, over every screen.
var _wallet_wanted := false

@onready var _prompt: Control = $Root/Prompt
@onready var _hold: Label = $Root/Prompt/Hold
@onready var _hold_ring: ChargeRing = $Root/HoldRing
@onready var _inventory_screen: InventoryScreen = $Root/InventoryScreen
@onready var _trader_screen: TraderScreen = $Root/TraderScreen
@onready var _system_map_screen: SystemMapScreen = $Root/SystemMapScreen
@onready var _star_map_screen: StarMapScreen = $Root/StarMapScreen
@onready var _key: Label = $Root/Prompt/KeyCap/Key
@onready var _action: Label = $Root/Prompt/Action
@onready var _screen_edges: ColorRect = $Root/ScreenEdges
@onready var _charge_ring: ChargeRing = $Root/ChargeRing
@onready var _hit_markers: HitMarkers = $Root/HitMarkers
@onready var _health_bar: HealthBar = $Root/Health/Rows/Bar/HealthBar
@onready var _health_number: Label = $Root/Health/Rows/Bar/Number
@onready var _health_label: Label = $Root/Health/Rows/Label
@onready var _clips: Control = $Root/Clips
@onready var _heat_label: Label = $Root/Clips/Rows/Header/Label
@onready var _heat_value: Label = $Root/Clips/Rows/Header/Value
@onready var _heat_gauge: HeatGauge = $Root/Clips/Rows/HeatGauge
@onready var _clip_count: Label = $Root/Clips/Rows/Count
@onready var _wallet: Control = $Root/Wallet
@onready var _wallet_value: Label = $Root/Wallet/Columns/Bitcoin/Value
@onready var _hydrogen_value: Label = $Root/Wallet/Columns/Hydrogen/Value
@onready var _antimatter_value: Label = $Root/Wallet/Columns/Antimatter/Value
@onready var _antimatter_note: Label = $Root/Wallet/Columns/Antimatter/Note
@onready var _day_value: Label = $Root/Wallet/Columns/Day/Value
@onready var _death_screen: ColorRect = $Root/DeathFade
@onready var _summary: RunSummaryCard = $Root/RunSummary


func _ready() -> void:
	_prompt.visible = false
	_clips.visible = false
	_wallet.visible = false
	# While collected antimatter fills the hub screen's gauge, the bar fills with it, and burns hydrogen with a flight on
	# the system map.
	_trader_screen.antimatter_shown.connect(set_antimatter)
	_system_map_screen.hydrogen_shown.connect(set_hydrogen)
	_system_map_screen.tab_requested.connect(_show_star_map)
	_star_map_screen.tab_requested.connect(_show_system_map)
	_edges_material = _screen_edges.material as ShaderMaterial
	_edges_material.set_shader_parameter("intensity", 0.0)
	_death_screen.color.a = 0.0


## The key bound to an action, for prompts (e.g. "E"), so prompts follow the Input Map.
static func key_label(action: StringName) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return (event as InputEventKey).as_text_physical_keycode()
	return "?"


func get_inventory_screen() -> InventoryScreen:
	return _inventory_screen


func get_trader_screen() -> TraderScreen:
	return _trader_screen


func get_system_map_screen() -> SystemMapScreen:
	return _system_map_screen


func get_star_map_screen() -> StarMapScreen:
	return _star_map_screen


## After a jump, under the black: whichever map is open makes way for the system map of the system the ship is in now,
## which says where it arrived.
func show_arrival(text: String) -> void:
	if _star_map_screen.is_open:
		_star_map_screen.close(true)
	if _system_map_screen.is_open:
		_system_map_screen.close(true)
	_system_map_screen.open(null, true)
	_system_map_screen.say(text)
	Log.info("🏃 HUD shows the arrival on the system map: system=%s" % (
		GameSession.system.definition.id if GameSession.system else "none"))


## Shows the key and what it does, or hides the prompt when action is empty. hold marks an action that is used by
## holding the key.
func set_prompt(key: String, action: String, hold: bool = false) -> void:
	prompt_text = "" if action.is_empty() else "%s%s %s" % ["Hold " if hold else "", key, action]
	_hold.visible = hold
	if _fade:
		_fade.kill()
	if action.is_empty():
		_prompt.visible = false
		return
	var was_visible := _prompt.visible
	_key.text = key
	_action.text = action
	_prompt.visible = true
	if not was_visible:
		_prompt.modulate.a = 0.0
		_fade = create_tween()
		_fade.tween_property(_prompt, "modulate:a", 1.0, FADE_TIME)


## critical: one more body hit could kill, so the readout turns red and the screen edges stay faintly red.
func set_health(health: float, max_health: float, critical: bool) -> void:
	health_text = "%d" % ceili(health)
	_health_number.text = health_text
	_health_bar.set_state(health / maxf(max_health, 1.0), critical)
	var color := DANGER_COLOR if critical else INK_COLOR
	_health_number.add_theme_color_override("font_color", color)
	_health_label.add_theme_color_override("font_color", DANGER_COLOR if critical else DIM_COLOR)
	_critical = critical and health > 0.0


## The loaded clip's heat (0 to 1), the heat the shot being charged would add, the clips carried (fresh ones in the
## pockets, which a reload uses, fresh ones packed in the backpack, and spent ones), whether the clip has no room left
## for a full charge (low) or for any shot (saturated), and the reload's progress (-1 when not reloading). Called
## every frame; the gauge only redraws when something changes.
func set_clips(heat: float, charge_heat: float, fresh: int, packed: int, spent: int, low: bool, saturated: bool,
		reload_progress: float) -> void:
	_clips.visible = true
	_heat_gauge.set_state(heat, charge_heat, low, reload_progress)
	var label := "HEAT"
	var value := "%d%%" % roundi(heat * 100.0)
	var count := "%d fresh  ·  %d spent" % [fresh, spent]
	if packed > 0:
		count = "%d fresh  ·  %d packed  ·  %d spent" % [fresh, packed, spent]
	if reload_progress >= 0.0:
		label = "RELOADING"
		value = ""
	elif saturated:
		label = "SATURATED"
		if fresh > 0:
			count = "Reload  %s  ·  %d fresh" % [key_label(&"reload"), fresh]
		elif packed > 0:
			count = "Move a clip to your pockets"
		else:
			count = "No fresh clips"
	var warn := (low or saturated) and reload_progress < 0.0
	var shown := [label, value, count, warn, fresh == 0]
	if shown == _shown_clips:
		return
	_shown_clips = shown
	_heat_label.text = label
	_heat_label.add_theme_color_override("font_color", DANGER_COLOR if warn else DIM_COLOR)
	_heat_value.text = value
	_heat_value.add_theme_color_override("font_color", DANGER_COLOR if warn else INK_COLOR)
	_clip_count.text = count
	_clip_count.add_theme_color_override("font_color", DANGER_COLOR if fresh == 0 else DIM_COLOR)
	clips_text = "%s %s" % [value, count] if not value.is_empty() else "%s %s" % [label, count]


## Shows the bitcoin in the wallet, the hydrogen and antimatter in the tanks and the day in the top left, at home on
## the ship.
func show_wallet(bitcoin: int, hydrogen: int, day: int) -> void:
	_wallet_wanted = true
	var bar_height := _wallet.get_combined_minimum_size().y
	for screen: MenuScreen in [_inventory_screen, _trader_screen, _system_map_screen, _star_map_screen]:
		screen.top_inset = bar_height
	Log.info("🏃 HUD shows the ship's bar: height=%.0f px, bitcoin=%d, hydrogen=%d, antimatter=%d, day=%d" % [
		bar_height, bitcoin, hydrogen, GameSession.antimatter, day])
	set_day(day)
	set_hydrogen(hydrogen)
	set_antimatter(GameSession.antimatter)
	set_wallet(bitcoin)


## The bitcoin in the wallet changed.
func set_wallet(bitcoin: int) -> void:
	_wallet_value.text = Bitcoin.format(bitcoin)
	_update_wallet_visibility()


## The hydrogen in the tank changed.
func set_hydrogen(hydrogen: int) -> void:
	_hydrogen_value.text = "%d/%d" % [hydrogen, GameSession.HYDROGEN_TANK]
	_update_wallet_visibility()


## The antimatter in the tank changed, or the antimatter on order: beside the tank, the day an order arrives, or that
## it is waiting at the hub to be collected.
func set_antimatter(antimatter: int) -> void:
	_antimatter_value.text = "%d/%d" % [antimatter, GameSession.ANTIMATTER_TANK]
	_antimatter_note.visible = GameSession.order_units > 0
	if GameSession.order_arrived():
		_antimatter_note.text = "%d READY AT THE HUB" % GameSession.order_units
	elif GameSession.order_units > 0:
		_antimatter_note.text = "%d ARRIVING DAY %d" % [GameSession.order_units, GameSession.order_day]
	_update_wallet_visibility()


## A day passed.
func set_day(day: int) -> void:
	_day_value.text = "%d" % day
	_update_wallet_visibility()


func _update_wallet_visibility() -> void:
	_wallet.visible = _wallet_wanted
	wallet_text = _wallet_value.text if _wallet.visible else ""
	hydrogen_text = _hydrogen_value.text if _wallet.visible else ""
	day_text = _day_value.text if _wallet.visible else ""
	antimatter_text = ""
	if _wallet.visible:
		antimatter_text = _antimatter_value.text
		if _antimatter_note.visible:
			antimatter_text += " " + _antimatter_note.text


## The system map asks for the star map: it opens in the system map's place.
func _show_star_map(_viewing: StarSystem) -> void:
	_system_map_screen.close(true)
	_star_map_screen.open(true)
	Log.info("🏃 HUD switched to the star map tab")


## The star map asks for the system map: it opens in the star map's place, on the system selected there if that one
## is known and not where the ship is.
func _show_system_map(viewing: StarSystem) -> void:
	_star_map_screen.close(true)
	_system_map_screen.open(viewing, true)
	Log.info("🏃 HUD switched to the system map tab: viewing=%s" % (viewing.definition.id if viewing else "here"))


## Hides the clip readout while the player is unarmed; the next set_clips() shows it again.
func hide_clips() -> void:
	_clips.visible = false
	_shown_clips = []
	clips_text = ""


func set_charge(charge: float) -> void:
	_charge_ring.set_charge(charge)


## How far a held interact has got, from 0 to 1, or -1 when nothing is being held.
func set_hold(progress: float) -> void:
	_hold_ring.set_charge(progress)


## Flashes the screen edges red and points a marker at where the hit came from.
func show_hit(source_position: Vector3) -> void:
	_hit_flash = HIT_FLASH
	_hit_markers.add(source_position)


## Starts black and fades the whole screen in over duration seconds: arriving on the ship or the wreck.
func fade_in(duration: float) -> void:
	if _death_fade:
		_death_fade.kill()
	_death_screen.color.a = 1.0
	_death_fade = create_tween()
	_death_fade.tween_property(_death_screen, "color:a", 0.0, duration).set_ease(Tween.EASE_OUT)
	Log.info("🏃 HUD fading in from black: duration=%.1f s" % duration)


## Shows how the run ended on the black screen, with the key that continues.
func show_summary(summary: RunSummary) -> void:
	_prompt.visible = false
	_summary.show_summary(summary, key_label(&"interact"))


func hide_summary() -> void:
	_summary.hide_summary()


## What the run summary says, or "" while it is hidden, for tests.
func summary_text() -> String:
	return _summary.text if _summary.visible else ""


## Fades the whole screen to black over duration seconds, after delay seconds.
func fade_out(duration: float, delay: float = 0.0) -> void:
	if _death_fade:
		_death_fade.kill()
	_death_fade = create_tween()
	_death_fade.tween_interval(delay)
	_death_fade.tween_property(_death_screen, "color:a", 1.0, duration).set_ease(Tween.EASE_IN)


func _process(delta: float) -> void:
	_hit_flash = maxf(_hit_flash - HIT_FLASH_FADE * delta, 0.0)
	var critical_edges := 0.0
	if _critical:
		_pulse += delta
		critical_edges = CRITICAL_EDGES + CRITICAL_PULSE * sin(_pulse * TAU * CRITICAL_PULSE_RATE)
	var intensity := clampf(maxf(_hit_flash, critical_edges), 0.0, 1.0)
	if not is_equal_approx(intensity, _edge_intensity):
		_edge_intensity = intensity
		_edges_material.set_shader_parameter("intensity", intensity)
