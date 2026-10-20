class_name SectionMarker
extends Marker3D
## A spot in a section where a mission may place an enemy or loot. Markers stay empty until enemies (006) and
## loot (007) fill them.

enum Kind { ENEMY, LOOT }

@export var kind: Kind = Kind.LOOT
