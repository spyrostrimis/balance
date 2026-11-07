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

var hp: int = 0
## Heroes never die: at 0 HP they are downed (inactive, untargetable).
var downed: bool = false
var dead: bool = false
## Enemy this unit is attacking (-1 = none).
var attack_target_id: int = -1
## True when the target came from an order or from being shot; false when the
## unit picked it itself (then it gives up if the target gets too far away).
var target_forced: bool = false
## Ticks until the next shot.
var cooldown_left: int = 0
## Chasing: the target cell the current route was planned for, and a replan timer.
var chase_cell: Vector2i = Vector2i(-1, -1)
var chase_timer: int = 0


func _init(unit_id: int, unit_team: Team, unit_stats: UnitStats, start_cell: Vector2i) -> void:
	id = unit_id
	team = unit_team
	stats = unit_stats
	occupied_cell = start_cell
	pos = cell_center(start_cell)
	prev_pos = pos
	hp = stats.max_hp


func cell() -> Vector2i:
	return occupied_cell


func is_air() -> bool:
	return stats.is_air


func is_moving() -> bool:
	return has_destination or stepping


## Alive and not downed: can move, attack and take orders.
func can_act() -> bool:
	return not dead and not downed


## Has a weapon (range and damage above zero). Unarmed units never pick targets.
func can_attack() -> bool:
	return stats.attack_range > 0.0 and stats.attack_damage > 0


func hp_fraction() -> float:
	return clampf(float(hp) / float(maxi(stats.max_hp, 1)), 0.0, 1.0)


static func cell_center(c: Vector2i) -> Vector2:
	return Vector2(c) + Vector2(0.5, 0.5)
