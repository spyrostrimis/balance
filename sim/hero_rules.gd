class_name HeroRules
extends Resource
## The hero rule's numbers (design/GDD.md → Heroes): low-HP warning, recovery of
## downed AI heroes, and their return. Data file: data/rules/hero_rules.tres.

## The player's hero warns below this fraction of max HP.
@export var low_hp_warning_fraction: float = 0.3

@export_group("Recovery")
## Recovery dropship / truck speed, cells per second.
@export var recovery_speed: float = 6.0
## Seconds spent loading the downed hero.
@export var recovery_load_seconds: float = 2.0
## The recovery unit enters and leaves this many cells beyond the map edge.
@export var recovery_offmap_margin: float = 4.0

@export_group("Return")
## Seconds after leaving the map until the hero is back at its start area.
@export var return_seconds: float = 60.0
## HP on return, as a fraction of max HP.
@export var return_hp_fraction: float = 1.0
