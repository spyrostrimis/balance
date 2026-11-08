class_name UnitStats
extends Resource
## Stats for one unit type (data file in data/units/). Values are design
## proposals until decided in design/GDD.md.

## Stable identifier, also used by the view to pick a placeholder model.
@export var id: StringName = &""
@export var display_name: String = ""
@export var is_hero: bool = false
## Air units fly over terrain and ground units, but can only stop on free ground cells.
@export var is_air: bool = false
## Movement speed in cells per second.
@export var move_speed: float = 2.0
## Footprint radius in cells (for collision/spacing later).
@export var radius: float = 0.25

@export_group("Combat")
@export var max_hp: int = 100
## Damage per shot.
@export var attack_damage: int = 10
## Attack range in cells (centre to centre).
@export var attack_range: float = 3.5
## Seconds between shots.
@export var attack_cooldown: float = 1.0
## Idle units engage enemies within this many cells (moving in to attack range).
@export var acquire_range: float = 6.0

@export_group("Abilities")
## Hero abilities, in ability-bar order (actives and auras).
@export var abilities: Array[AbilityStats] = []
