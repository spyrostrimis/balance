class_name CombatEvent
extends RefCounted
## Something that happened during a tick, for the view to show (SimWorld.events).

enum Kind {
	## unit_id fired at other_id for `amount` damage (after aura bonuses).
	SHOT,
	DIED,
	DOWNED,
	## unit_id used ability `ability_index` on other_id. HEAL: `amount` = HP
	## restored. DAMAGE: `amount` = damage to the main target.
	ABILITY,
	## A recovery unit (other_id = recovery id) was sent for downed hero unit_id.
	RECOVERY_SENT,
	## The recovery unit other_id picked up hero unit_id.
	HERO_LOADED,
	## Hero unit_id left the map; back in `amount` ticks.
	HERO_AWAY,
	## Hero unit_id is back on the map at its start area.
	HERO_RETURNED,
	## The player's hero (unit_id) is down: the mission is lost.
	MISSION_FAILED,
}

var kind: Kind = Kind.SHOT
## The unit acting (shooter) or the unit that died / went down.
var unit_id: int = -1
## SHOT: the target. DIED/DOWNED: the unit that dealt the final blow.
var other_id: int = -1
var amount: int = 0
## ABILITY: index into the actor's stats.abilities.
var ability_index: int = -1


func _init(event_kind: Kind, actor_id: int, other: int, value: int = 0, ability: int = -1) -> void:
	kind = event_kind
	unit_id = actor_id
	other_id = other
	amount = value
	ability_index = ability
