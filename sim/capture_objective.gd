class_name CaptureObjective
extends RefCounted
## Strict-hold capture of the Orichalcum rock (design/GDD.md → Mission 1):
## - A side alone in the zone (units that are up) for capture time takes the rock.
##   Both sides in the zone pause the capture; a side with nobody there loses
##   its progress.
## - The owner wins after hold time with no enemy in the zone; any enemy in the
##   zone resets the hold timer. The owner doesn't have to stand in the zone.

const NO_TEAM: int = -1

var rules: ObjectiveRules
var rock: Rect2i
## Open cells of the zone.
var zone: Dictionary[Vector2i, bool] = {}
## Team that owns the rock (SimUnit.Team as int), or NO_TEAM.
var owner_team: int = NO_TEAM
## Team currently capturing, and its progress (ticks).
var capture_team: int = NO_TEAM
var capture_ticks: int = 0
## Owner's hold progress (ticks).
var hold_ticks: int = 0
## Units up in the zone last tick, per team.
var present: Dictionary[int, int] = {}


func _init(grid: MapGrid, rock_rect: Rect2i, objective_rules: ObjectiveRules) -> void:
	rules = objective_rules
	rock = rock_rect
	var r: int = rules.zone_radius
	for y: int in range(rock.position.y - r, rock.end.y + r):
		for x: int in range(rock.position.x - r, rock.end.x + r):
			var cell: Vector2i = Vector2i(x, y)
			if grid.is_passable(cell):
				zone[cell] = true


func is_in_zone(cell: Vector2i) -> bool:
	return zone.has(cell)


## Centre of the rock in cell units.
func center() -> Vector2:
	return Vector2(rock.position) + Vector2(rock.size) * 0.5


func capture_ticks_needed() -> int:
	return maxi(1, roundi(rules.capture_seconds * SimWorld.TICKS_PER_SECOND))


func hold_ticks_needed() -> int:
	return maxi(1, roundi(rules.hold_seconds * SimWorld.TICKS_PER_SECOND))


func contested() -> bool:
	return present.get(SimUnit.Team.BLUE, 0) > 0 and present.get(SimUnit.Team.RED, 0) > 0


## The owner if it has held long enough, else NO_TEAM.
func winner() -> int:
	return owner_team if owner_team != NO_TEAM and hold_ticks >= hold_ticks_needed() else NO_TEAM


## Advances one tick. Returns the team that took the rock this tick, or NO_TEAM.
func update(units: Array[SimUnit]) -> int:
	present.clear()
	for unit: SimUnit in units:
		if unit.can_act() and zone.has(unit.occupied_cell):
			present[unit.team] = present.get(unit.team, 0) + 1
	var teams_in: Array[int] = []
	for team: int in present:
		teams_in.append(team)
	if owner_team != NO_TEAM:
		var enemy_in: bool = false
		for team: int in teams_in:
			if team != owner_team:
				enemy_in = true
		hold_ticks = 0 if enemy_in else hold_ticks + 1
	var captured: int = NO_TEAM
	if teams_in.size() == 1 and teams_in[0] != owner_team:
		var alone: int = teams_in[0]
		if capture_team != alone:
			capture_team = alone
			capture_ticks = 0
		capture_ticks += 1
		if capture_ticks >= capture_ticks_needed():
			owner_team = alone
			hold_ticks = 0
			capture_team = NO_TEAM
			capture_ticks = 0
			captured = alone
	elif teams_in.size() > 1 and teams_in.has(capture_team):
		pass  # contested: capture paused
	else:
		capture_team = NO_TEAM
		capture_ticks = 0
	return captured
