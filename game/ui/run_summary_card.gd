class_name RunSummaryCard
extends Control
## The run summary, a placard in the HUD's style centred on the black screen after a run: the title (RUN COMPLETE,
## or SIGNAL LOST in red), the clone's lifeline, a heartbeat trace that keeps beating in the laser's blue after an
## extraction and goes flat in red after a death, then what was carried out and gained, or what was lost and which
## clone wakes up next, and the key to continue. It fades in and the trace draws itself once. It shows what the
## player passes it and takes no input: the player reads interact.

const INK_COLOR := Color(0.862745, 0.901961, 0.941176)
const DIM_COLOR := Color(0.721569, 0.768627, 0.815686)
const DANGER_COLOR := Color(1.0, 0.12, 0.08)
const LASER_COLOR := Color(0.62, 0.82, 1.0)
const PLACARD_COLOR := Color(0.0431373, 0.0588235, 0.0784314, 0.62)
const PLACARD_EDGE := Color(0.862745, 0.901961, 0.941176, 0.18)
const FONT_NAMES := ["Bahnschrift", "DIN Alternate", "Arial Narrow"]
const WIDTH := 440.0
const LIFELINE_HEIGHT := 46.0
const FADE_TIME := 0.35
## Seconds the lifeline takes to draw itself across.
const TRACE_TIME := 1.4
## The trace's beats, as fractions of its width; after a death it goes flat after the second.
const BEATS: Array[float] = [0.12, 0.34, 0.56, 0.78]
const FLATLINE_AFTER := 2

## What the card says, for tests: e.g. "RUN COMPLETE | Haul 9 items · ₿1,240 | Gained +₿1,050 | E Continue".
var text := ""

var _summary: RunSummary
var _panel: PanelContainer
var _title: Label
var _clone: Label
var _lifeline: Control
var _rows: VBoxContainer
var _key: Label
var _font: SystemFont
var _label_font: FontVariation
var _body_font: SystemFont
var _trace := 0.0
var _tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(FONT_NAMES)
	_font.font_weight = 600
	_body_font = SystemFont.new()
	_body_font.font_names = PackedStringArray(FONT_NAMES)
	_label_font = FontVariation.new()
	_label_font.base_font = _font
	_label_font.spacing_glyph = 3
	_build()


## Shows a run's summary; key is the key that continues, from the Input Map.
func show_summary(summary: RunSummary, key: String) -> void:
	_summary = summary
	var color := LASER_COLOR if summary.extracted else DANGER_COLOR
	_title.text = "RUN COMPLETE" if summary.extracted else "SIGNAL LOST"
	_title.add_theme_color_override("font_color", INK_COLOR if summary.extracted else DANGER_COLOR)
	var clone := summary.clone_number if summary.extracted else summary.clone_number - 1
	_clone.text = "CLONE %d" % clone
	for row in _rows.get_children():
		_rows.remove_child(row)
		row.queue_free()
	var lines: Array[String] = [_title.text]
	var carried := "%d %s  ·  %s" % [summary.items, "item" if summary.items == 1 else "items",
		Bitcoin.format(summary.value)]
	if summary.extracted:
		var gained := Bitcoin.format(summary.gained, true)
		_add_row("Haul", carried, INK_COLOR)
		_add_row("Gained", gained, LASER_COLOR if summary.gained > 0 else DIM_COLOR)
		lines.append_array(["Haul %s" % carried, "Gained %s" % gained])
	else:
		_add_row("Lost", carried, DANGER_COLOR if summary.items > 0 else DIM_COLOR)
		_add_row("Next", "Clone %d activated" % summary.clone_number, INK_COLOR)
		lines.append_array(["Lost %s" % carried, "Clone %d activated" % summary.clone_number])
	_key.text = key
	lines.append("%s Continue" % key)
	text = " | ".join(lines)
	_lifeline.set_meta(&"color", color)
	_layout()
	# Labels settle their sizes during the frame; centre the placard again once they have.
	_layout.call_deferred()
	visible = true
	modulate.a = 0.0
	_trace = 0.0
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, FADE_TIME)
	_tween.parallel().tween_method(_set_trace, 0.0, 1.0, TRACE_TIME).set_ease(Tween.EASE_OUT)
	Log.info("🏃 Run summary card shown: %s" % text)


func hide_summary() -> void:
	if _tween:
		_tween.kill()
	visible = false
	text = ""
	Log.info("🏃 Run summary card hidden")


func _build() -> void:
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PLACARD_COLOR
	style.border_color = PLACARD_EDGE
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.content_margin_left = 22.0
	style.content_margin_right = 22.0
	style.content_margin_top = 16.0
	style.content_margin_bottom = 18.0
	_panel.add_theme_stylebox_override("panel", style)
	_panel.custom_minimum_size = Vector2(WIDTH, 0.0)
	add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_panel.add_child(column)
	var header := HBoxContainer.new()
	_title = _label("", _label_font, 15, INK_COLOR)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	_clone = _label("", _label_font, 11, DIM_COLOR)
	_clone.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_clone)
	column.add_child(header)
	_lifeline = Control.new()
	_lifeline.custom_minimum_size = Vector2(0.0, LIFELINE_HEIGHT)
	_lifeline.draw.connect(_draw_lifeline)
	column.add_child(_lifeline)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 6)
	column.add_child(_rows)
	var rule := ColorRect.new()
	rule.color = PLACARD_EDGE
	rule.custom_minimum_size = Vector2(0.0, 1.0)
	column.add_child(rule)
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 10)
	var cap := PanelContainer.new()
	var cap_style := StyleBoxFlat.new()
	cap_style.bg_color = Color(0.0431373, 0.0588235, 0.0784314, 0.55)
	cap_style.border_color = Color(INK_COLOR, 0.85)
	cap_style.set_border_width_all(1)
	cap_style.set_corner_radius_all(2)
	cap_style.content_margin_left = 7.0
	cap_style.content_margin_right = 7.0
	cap_style.content_margin_top = 1.0
	cap_style.content_margin_bottom = 1.0
	cap.add_theme_stylebox_override("panel", cap_style)
	_key = _label("E", _font, 16, INK_COLOR)
	_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.add_child(_key)
	footer.add_child(cap)
	footer.add_child(_label("Continue", _body_font, 17, DIM_COLOR))
	column.add_child(footer)
	for node in find_children("*", "Control", true, false):
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE


## One line of the summary: a spaced label on the left and its value on the right.
func _add_row(label: String, value: String, color: Color) -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_label := _label(label.to_upper(), _label_font, 11, DIM_COLOR)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_label)
	row.add_child(_label(value, _font, 20, color))
	_rows.add_child(row)


func _label(content: String, font: Font, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = content
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _layout() -> void:
	_panel.reset_size()
	var panel_size := _panel.get_combined_minimum_size()
	_panel.size = panel_size
	_panel.position = (get_viewport_rect().size - panel_size) / 2.0


func _set_trace(progress: float) -> void:
	_trace = progress
	_lifeline.queue_redraw()


## The lifeline drawn as far as the trace has got: a faint baseline, beats as sharp spikes, a death going flat after
## FLATLINE_AFTER beats, and a bright dot at the head of the trace.
func _draw_lifeline() -> void:
	if _summary == null:
		return
	var color: Color = _lifeline.get_meta(&"color", LASER_COLOR)
	var width := _lifeline.size.x
	var middle := _lifeline.size.y / 2.0
	_lifeline.draw_line(Vector2(0.0, middle), Vector2(width, middle), Color(color, 0.12), 1.0)
	var points := PackedVector2Array([Vector2(0.0, middle)])
	for i in BEATS.size():
		if not _summary.extracted and i >= FLATLINE_AFTER:
			break
		var x := BEATS[i] * width
		var height := middle * 0.9
		for spike: Vector2 in [Vector2(-10.0, 0.0), Vector2(-6.0, 0.18), Vector2(-3.0, 0.0), Vector2(0.0, -1.0),
				Vector2(3.0, 0.75), Vector2(6.0, 0.0), Vector2(12.0, -0.12), Vector2(17.0, 0.0)]:
			points.append(Vector2(x + spike.x, middle + spike.y * height))
	points.append(Vector2(width, middle))
	var limit := _trace * width
	var shown := PackedVector2Array()
	for i in points.size():
		if points[i].x <= limit:
			shown.append(points[i])
			continue
		if i > 0:
			var previous := points[i - 1]
			var t := (limit - previous.x) / maxf(points[i].x - previous.x, 0.001)
			shown.append(previous.lerp(points[i], clampf(t, 0.0, 1.0)))
		break
	if shown.size() >= 2:
		_lifeline.draw_polyline(shown, Color(color, 0.25), 5.0, true)
		_lifeline.draw_polyline(shown, color, 1.6, true)
		_lifeline.draw_circle(shown[shown.size() - 1], 2.5, color.lightened(0.4))

