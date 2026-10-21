class_name ChargeRing
extends Control
## A thin ring round the centre dot that fills clockwise from the top while a shot charges, in the laser's colour,
## and turns white when the charge is full. Hidden when nothing is charging. The HUD uses a second one, in the
## placards' ink, for holding interact (prying a container open).

const RADIUS := 11.0
const WIDTH := 2.0
const POINTS := 48

@export var track_color := Color(0.62, 0.82, 1.0, 0.22)
@export var fill_color := Color(0.62, 0.82, 1.0, 0.95)
@export var full_color := Color(0.95, 0.98, 1.0, 1.0)
@export var radius := RADIUS

## From 0 to 1; 0 or less hides the ring.
var charge := -1.0


func set_charge(new_charge: float) -> void:
	if is_equal_approx(new_charge, charge):
		return
	charge = new_charge
	queue_redraw()


func _draw() -> void:
	if charge <= 0.0:
		return
	var centre := size / 2.0
	draw_arc(centre, radius, 0.0, TAU, POINTS, track_color, WIDTH, true)
	var full := charge >= 1.0
	draw_arc(centre, radius, -PI / 2.0, -PI / 2.0 + TAU * minf(charge, 1.0), POINTS,
		full_color if full else fill_color, WIDTH + (1.0 if full else 0.0), true)
