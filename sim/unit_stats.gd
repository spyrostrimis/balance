class_name UnitStats
extends Resource
## Stats for one unit type (data file in data/units/). Values are design
## proposals until decided in design/GDD.md.

## Stable identifier, also used by the view to pick a placeholder model.
@export var id: StringName = &""
@export var display_name: String = ""
@export var is_hero: bool = false
## Movement speed in cells per second.
@export var move_speed: float = 2.0
## Footprint radius in cells (for collision/spacing later).
@export var radius: float = 0.25
