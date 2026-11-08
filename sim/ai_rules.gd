class_name AiRules
extends Resource
## Enemy AI tuning (design/GDD.md → Enemy AI).

## Seconds between decisions.
@export var think_seconds: float = 0.33
## Seconds before the army first moves.
@export var start_delay_seconds: float = 3.0
## The hero pulls back to its start area below this fraction of max HP.
@export var hero_retreat_fraction: float = 0.25
## Focus-fire candidates: enemies within this many cells of any AI fighter...
@export var focus_radius: float = 7.0
## ...or within this many cells of the rock's centre.
@export var guard_radius: float = 6.0
## Repair-type abilities are used on allies below this fraction of max HP.
@export var heal_below_fraction: float = 0.6
