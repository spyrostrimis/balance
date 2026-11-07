class_name SimUnit
extends RefCounted
## One unit in the simulation. Positions are in cell units (continuous):
## the centre of cell (x, y) is (x + 0.5, y + 0.5).
## A unit always occupies one cell; while stepping to a neighbour it holds both.

enum Team { BLUE, RED }

var id: int = 0
var team: Team = Team.BLUE
var stats: UnitStats
var pos: Vector2 = Vector2.ZERO
## Position at the start of the last tick (the view interpolates prev_pos → pos).
var prev_pos: Vector2 = Vector2.ZERO

## The cell this unit occupies.
var occupied_cell: Vector2i = Vector2i.ZERO
## While stepping, the neighbour cell being entered (also reserved).
var step_cell: Vector2i = Vector2i.ZERO
var stepping: bool = false
## Remaining cells to walk through.
var path: Array[Vector2i] = []
## Where this unit will stop (reserved so no other unit picks it).
var destination: Vector2i = Vector2i.ZERO
var has_destination: bool = false
## The cell the player clicked (used to pick a new spot if the old one gets taken).
var order_target: Vector2i = Vector2i.ZERO
var blocked_ticks: int = 0
var retargeted: bool = false


func _init(unit_id: int, unit_team: Team, unit_stats: UnitStats, start_cell: Vector2i) -> void:
	id = unit_id
	team = unit_team
	stats = unit_stats
	occupied_cell = start_cell
	pos = cell_center(start_cell)
	prev_pos = pos


func cell() -> Vector2i:
	return occupied_cell


func is_air() -> bool:
	return stats.is_air


func is_moving() -> bool:
	return has_destination or stepping


static func cell_center(c: Vector2i) -> Vector2:
	return Vector2(c) + Vector2(0.5, 0.5)
