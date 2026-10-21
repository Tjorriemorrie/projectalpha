class_name SectionMarker
extends Marker3D
## A spot in a section where a mission may place an enemy or loot. Enemy markers say what fits there: a drone post
## sits on the floor, a turret mount on the ceiling, facing (along −Z) the middle of the turret's arc. The wreck's
## enemy list fills enemy markers (006); loot markers stay empty until 007.

enum Kind { ENEMY, LOOT }
## Where an enemy marker sits, and so which enemies fit it (see EnemyDefinition.mount).
enum Mount { FLOOR, CEILING }

@export var kind: Kind = Kind.LOOT
## For enemy markers: on the floor (drone posts) or on the ceiling (turret mounts).
@export var mount: Mount = Mount.FLOOR
