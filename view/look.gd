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

@export_group("Terrain")
## Terrain style for MapView (&"desert"; empty = placeholder tiles).
@export var terrain: StringName = &""
## Boulder models for rock cells (fitted into one cell).
@export var boulders: Array[PackedScene] = []

@export_group("Lighting")
@export var environment: Environment
@export var sun_color: Color = Color(1.0, 0.96, 0.9)
@export var sun_energy: float = 1.0
@export var sun_rotation_degrees: Vector3 = Vector3(-50.0, -65.0, 0.0)
