class_name GuardCommand
extends SimCommand
## Guard: hold the spot, fire at enemies in range, don't chase.

var unit_ids: Array[int] = []


func _init(issuing_team: SimUnit.Team, ids: Array[int]) -> void:
	team = issuing_team
	unit_ids = ids.duplicate()


func apply(world: SimWorld) -> void:
	world.order_guard(team, unit_ids)
