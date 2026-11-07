class_name AttackCommand
extends SimCommand
## Attack a specific enemy unit: chase it until in range, then fire until it dies.

var unit_ids: Array[int] = []
var target_id: int = -1


func _init(issuing_team: SimUnit.Team, ids: Array[int], target: int) -> void:
	team = issuing_team
	unit_ids = ids.duplicate()
	target_id = target


func apply(world: SimWorld) -> void:
	world.order_attack(team, unit_ids, target_id)
