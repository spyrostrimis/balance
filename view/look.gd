class_name Look
extends Resource
## One art look (design/GDD.md → Art direction): unit models, the recovery
## dropship and camera angle. Units without a visual keep their placeholder.

@export var id: StringName = &""
## UnitStats.id → visual.
@export var units: Dictionary[StringName, UnitVisual] = {}
@export var dropship: UnitVisual
@export var camera_pitch_degrees: float = 55.0
@export var camera_fov_degrees: float = 40.0
