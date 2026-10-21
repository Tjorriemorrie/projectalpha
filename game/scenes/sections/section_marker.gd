class_name SectionMarker
extends Marker3D
## A spot in a section where a mission may place an enemy or loot. Enemy markers say what fits there: a drone post
## sits on the floor, a turret mount on the ceiling, facing (along −Z) the middle of the turret's arc. Loot markers
## sit on the floor at the foot of a wall, facing (along −Z) away from it, and say how much room there is: a room's
## takes any container, a tight one (in a vent, a dead end) only small ones. The wreck's enemy list fills enemy
## markers (006) and its loot list loot markers (007).

enum Kind { ENEMY, LOOT }
## Where an enemy marker sits, and so which enemies fit it (see EnemyDefinition.mount).
enum Mount { FLOOR, CEILING }
## How much room a loot marker has, and so which containers fit it (see ContainerDefinition.fits_tight).
enum Space { ROOM, TIGHT }

@export var kind: Kind = Kind.LOOT
## For enemy markers: on the floor (drone posts) or on the ceiling (turret mounts).
@export var mount: Mount = Mount.FLOOR
## For loot markers: room for any container, or tight (small containers only).
@export var space: Space = Space.ROOM
