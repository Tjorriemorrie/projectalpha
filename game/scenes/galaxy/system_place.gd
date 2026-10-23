class_name SystemPlace
extends Resource
## One place in a star system (see galaxy.md): a planet, a moon, an asteroid belt, a station, a battlefield or an
## anomaly. A StarSystemDefinition lists its places from the star outwards, each moon right after its planet. Ships to
## board turn up at places, or out in open space.

enum Kind { PLANET, MOON, BELT, STATION, BATTLEFIELD, ANOMALY }

## What each kind is called on the system map.
const KIND_NAMES := {
	Kind.PLANET: "planet", Kind.MOON: "moon", Kind.BELT: "asteroid belt", Kind.STATION: "station",
	Kind.BATTLEFIELD: "battlefield", Kind.ANOMALY: "anomaly"}

## Its name on the map, e.g. "Praetor IV", "Hearth" or "the Long Fall".
@export var display_name := ""
@export var kind := Kind.PLANET
## A world people live on. The system's trader hub orbits the first one.
@export var habitable := false
## What galaxy.md says about it, e.g. "gas giant, harvesters".
@export var note := ""


## What kind of place it is, for the map: "habitable world", "moon", "battlefield" and so on.
func kind_name() -> String:
	if habitable:
		return "settled moon" if kind == Kind.MOON else "habitable world"
	return KIND_NAMES[kind]
