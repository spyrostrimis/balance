class_name UnitVisual
extends Resource
## How one unit type looks in one art look (data/looks/<look>/): the model,
## its size in the world, which animations to play and how to team-colour it.

@export var scene: PackedScene
## Target size in world units, measured on the model's rest pose: its height,
## or its longest horizontal side if `size_is_length`.
@export var size: float = 2.0
@export var size_is_length: bool = false
## Added to the yaw so the model's front matches the view's forward (-Z).
@export var yaw_offset_degrees: float = 180.0

@export_group("Animations")
## Names are matched by suffix (imported names may carry an armature prefix).
@export var anim_idle: String = "Idle"
@export var anim_walk: String = "Walk"
@export var anim_attack: String = "Shoot"
@export var anim_hit: String = ""
@export var anim_death: String = "Death"
## Walk animation speed at a move speed of 1 cell/s.
@export var walk_speed_scale: float = 0.5

@export_group("Team colour")
## Textured models: recolour saturated texels to the team's hue (0..1).
@export var hue_strength: float = 1.0
## Saturation where recolouring starts.
@export var sat_min: float = 0.2
## Textured models: also paint light grey parts in the team colour (0..1).
@export var paint_greys: float = 0.0
## Untextured models: materials (by name) repainted in the team colour, with a
## brightness factor each...
@export var paint_materials: Dictionary[String, float] = {}
## ...mixed this much over the original colour (1 = pure team colour).
@export var paint_mix: float = 0.65
