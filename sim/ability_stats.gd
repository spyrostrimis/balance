class_name AbilityStats
extends Resource
## One hero ability (data file in data/abilities/). Numbers are design proposals
## until decided in design/GDD.md → Heroes.

enum Kind {
	## Used on a target unit by order (button / hotkey), then cools down.
	ACTIVE,
	## Always on while the hero is up: affects own units within aura_radius.
	AURA,
}

enum Effect {
	## ACTIVE: restore `amount` HP to the target (capped at max HP).
	HEAL,
	## ACTIVE: deal `amount` damage to the target, plus splash.
	DAMAGE,
	## AURA: own units deal `amount` (fraction, 0.1 = +10%) more attack damage.
	DAMAGE_BONUS,
	## AURA: own units take `amount` (fraction, 0.15 = 15%) less damage.
	DAMAGE_REDUCTION,
}

enum Target {
	## An own unit (the hero itself included).
	ALLY,
	ENEMY,
}

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var kind: Kind = Kind.ACTIVE
@export var effect: Effect = Effect.HEAL
@export var amount: float = 0.0

@export_group("Active")
@export var target: Target = Target.ALLY
## Cells, centre to centre.
@export var cast_range: float = 5.0
## Seconds.
@export var cooldown: float = 10.0
## DAMAGE: other enemies within this many cells of the target also take damage...
@export var splash_radius: float = 0.0
## ...this fraction of `amount`.
@export var splash_fraction: float = 0.0

@export_group("Aura")
## Cells, centre to centre.
@export var aura_radius: float = 5.0
@export var aura_affects_self: bool = false


func is_active() -> bool:
	return kind == Kind.ACTIVE


func cooldown_ticks(ticks_per_second: int) -> int:
	return maxi(1, roundi(cooldown * ticks_per_second))
