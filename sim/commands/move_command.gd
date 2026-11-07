class_name MoveCommand
extends SimCommand
## Move the given units towards a cell. If the cell can't be stood on (rock,
## cliff, another unit) or the group needs more room, units stop on the nearest
## free reachable cells instead (see SimWorld.order_move).

var unit_ids: Array[int] = []
var target_cell: Vector2i = Vector2i.ZERO


func _init(issuing_team: SimUnit.Team, ids: Array[int], cell: Vector2i) -> void:
	team = issuing_team
	unit_ids = ids.duplicate()
	target_cell = cell


func apply(world: SimWorld) -> void:
	world.order_move(team, unit_ids, target_cell)
