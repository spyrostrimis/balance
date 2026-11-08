class_name AbilityStats
extends Resource
## One hero ability (data file in data/abilities/). Numbers are design proposals
## until decided in design/GDD.md → Heroes.

enum Kind {
	## Used on a target unit by order (button / hotkey), then cools down.
	ACTIVE,
	## Always on while the hero is up: modifies own units within aura_radius
	## (the aura_* fields). Invisible in the game: the player learns about it
	## from the hero's ability tooltip.
	AURA,
}

## What an ACTIVE ability does (ignored for auras).
enum Effect {
	## Restore `amount` HP to the target (capped at max HP).
	HEAL,
	## Deal `amount` damage to the target, plus splash.
	DAMAGE,
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

@export_group("Active")
@export var effect: Effect = Effect.HEAL
## HP healed or damage dealt.
@export var amount: float = 0.0
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
## Fractions: 0.1 = +10% attack damage dealt.
@export var aura_damage_bonus: float = 0.0
## 0.15 = 15% less damage taken.
@export var aura_damage_reduction: float = 0.0
## 0.05 = 5% faster attacks (shorter time between shots).
@export var aura_attack_speed_bonus: float = 0.0
## 0.05 = 5% faster movement.
@export var aura_move_speed_bonus: float = 0.0


func is_active() -> bool:
	return kind == Kind.ACTIVE


func cooldown_ticks(ticks_per_second: int) -> int:
	return maxi(1, roundi(cooldown * ticks_per_second))
