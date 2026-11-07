class_name SimUnit
extends RefCounted
## One unit in the simulation. Positions are in cell units (continuous):
## the centre of cell (x, y) is (x + 0.5, y + 0.5).

enum Team { BLUE, RED }

var id: int = 0
var team: Team = Team.BLUE
var stats: UnitStats
var pos: Vector2 = Vector2.ZERO
## Position at the start of the last tick (the view interpolates prev_pos → pos).
var prev_pos: Vector2 = Vector2.ZERO
var move_target: Vector2 = Vector2.ZERO
var has_move_target: bool = false


func _init(unit_id: int, unit_team: Team, unit_stats: UnitStats, start: Vector2) -> void:
	id = unit_id
	team = unit_team
	stats = unit_stats
	pos = start
	prev_pos = start


func cell() -> Vector2i:
	return Vector2i(floori(pos.x), floori(pos.y))


static func cell_center(c: Vector2i) -> Vector2:
	return Vector2(c) + Vector2(0.5, 0.5)
