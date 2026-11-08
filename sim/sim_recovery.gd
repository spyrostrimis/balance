class_name SimRecovery
extends RefCounted
## A recovery dropship / truck fetching a downed AI hero (design/GDD.md → Heroes).
## Not a SimUnit: it can't be targeted, damaged or blocked, holds no cell and
## flies in a straight line: in from beyond the map edge, load, back out.

enum State { INBOUND, LOADING, OUTBOUND }

var id: int = 0
var team: SimUnit.Team = SimUnit.Team.RED
var hero_id: int = -1
var state: State = State.INBOUND
## Position in cell units (may be outside the map), and last tick's (for the view).
var pos: Vector2 = Vector2.ZERO
var prev_pos: Vector2 = Vector2.ZERO
## Where it came from and leaves to (outside the map).
var exit_pos: Vector2 = Vector2.ZERO
var load_ticks_left: int = 0


func _init(recovery_id: int, recovery_team: SimUnit.Team, hero: int, start: Vector2) -> void:
	id = recovery_id
	team = recovery_team
	hero_id = hero
	pos = start
	prev_pos = start
	exit_pos = start
