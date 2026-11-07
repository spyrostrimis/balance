class_name MoveCommand
extends SimCommand
## Move the given units to a cell. Ignored if the cell is impassable.
## (Milestone 2: straight-line movement; pathfinding and spreading come in milestone 3.)

var unit_ids: Array[int] = []
var target_cell: Vector2i = Vector2i.ZERO


func _init(issuing_team: SimUnit.Team, ids: Array[int], cell: Vector2i) -> void:
	team = issuing_team
	unit_ids = ids.duplicate()
	target_cell = cell


func apply(world: SimWorld) -> void:
	if not world.grid.is_passable(target_cell):
		return
	for unit_id: int in unit_ids:
		var unit: SimUnit = world.get_unit(unit_id)
		if unit == null or unit.team != team:
			continue
		unit.move_target = SimUnit.cell_center(target_cell)
		unit.has_move_target = true
