class_name RetreatCommand
extends SimCommand
## Retreat: walk back to the team's start area without fighting on the way.

var unit_ids: Array[int] = []


func _init(issuing_team: SimUnit.Team, ids: Array[int]) -> void:
	team = issuing_team
	unit_ids = ids.duplicate()


func apply(world: SimWorld) -> void:
	world.order_retreat(team, unit_ids)
