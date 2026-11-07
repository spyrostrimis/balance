class_name SimWorld
extends RefCounted
## The whole simulation state, advanced in fixed ticks (independent of frame rate).
##
## Movement rules (design/GDD.md → Movement):
## - One unit per cell. Ground units can't enter rocks/cliffs or cells held by
##   other ground units. Air units fly over terrain and ground units, but not
##   through other air units.
## - Every unit stops only on a free ground cell: passable terrain with no other
##   unit (ground or air) on it or heading to it.
## - A move order picks one stop cell per unit: the clicked cell if free, else the
##   nearest free reachable cells (ties broken towards the group), then paths there.

const TICKS_PER_SECOND: int = 15
const TICK_SECONDS: float = 1.0 / TICKS_PER_SECOND
## Blocked this many ticks by another unit → look for a path around units.
const REPATH_AFTER_TICKS: int = 6
## Still blocked after this many ticks → pick a new stop cell once, then give up.
const GIVE_UP_AFTER_TICKS: int = 45
const EPSILON: float = 0.000001

var grid: MapGrid = MapGrid.new()
var pathfinder: Pathfinder = Pathfinder.new()
var units: Array[SimUnit] = []
var tick: int = 0

var _pending: Array[SimCommand] = []
var _next_id: int = 1
var _by_id: Dictionary[int, SimUnit] = {}
## Cell → unit id, per layer (occupied cells and cells being stepped into).
var _ground_res: Dictionary[Vector2i, int] = {}
var _air_res: Dictionary[Vector2i, int] = {}
## Stop cell → unit id heading there.
var _dest_res: Dictionary[Vector2i, int] = {}


## Loads a map from rows (see MapLayout). Returns "" or an error message.
func load_map_rows(rows: PackedStringArray) -> String:
	var err: String = grid.load_rows(rows)
	if err == "":
		pathfinder.build(grid)
	return err


func load_map(layout: MapLayout) -> String:
	if layout == null:
		return "map layout is null"
	return load_map_rows(layout.rows)


## Loads the mission's map and spawns both rosters. Returns "" or an error message.
func setup_mission(data: MissionData) -> String:
	if data == null:
		return "mission data is null"
	var err: String = load_map(data.map)
	if err != "":
		return err
	err = _spawn_roster(data.blue_roster, SimUnit.Team.BLUE, grid.blue_spawns)
	if err != "":
		return err
	return _spawn_roster(data.red_roster, SimUnit.Team.RED, grid.red_spawns)


## Spawns a unit on a free cell. Returns null if the cell isn't free.
func spawn_unit(stats: UnitStats, team: SimUnit.Team, cell: Vector2i) -> SimUnit:
	if not is_cell_free(cell):
		return null
	var unit: SimUnit = SimUnit.new(_next_id, team, stats, cell)
	_next_id += 1
	units.append(unit)
	_by_id[unit.id] = unit
	_layer(unit)[cell] = unit.id
	return unit


func get_unit(unit_id: int) -> SimUnit:
	return _by_id.get(unit_id, null)


## True if a unit could stop here: passable, and no unit on it or heading to it.
func is_cell_free(cell: Vector2i) -> bool:
	return grid.is_passable(cell) and not _ground_res.has(cell) and not _air_res.has(cell) \
			and not _dest_res.has(cell)


## Queues a command; it takes effect at the start of the next tick.
func queue_command(command: SimCommand) -> void:
	_pending.append(command)


func step() -> void:
	tick += 1
	for unit: SimUnit in units:
		unit.prev_pos = unit.pos
	var commands: Array[SimCommand] = _pending
	_pending = []
	for command: SimCommand in commands:
		command.apply(self)
	for unit: SimUnit in units:
		_move(unit)


## Orders units of `team` towards `target` (called by MoveCommand on a tick).
func order_move(team: SimUnit.Team, unit_ids: Array[int], target: Vector2i) -> void:
	var group: Array[SimUnit] = []
	for unit_id: int in unit_ids:
		var unit: SimUnit = get_unit(unit_id)
		if unit != null and unit.team == team and not group.has(unit):
			group.append(unit)
	if group.is_empty() or grid.width == 0:
		return
	target = Vector2i(clampi(target.x, 0, grid.width - 1), clampi(target.y, 0, grid.height - 1))
	for unit: SimUnit in group:
		_clear_destination(unit)
		unit.order_target = target
		unit.retargeted = false
	var stops: Dictionary[int, Vector2i] = _assign_stops(group, target)
	for unit: SimUnit in group:
		unit.path.clear()
		unit.blocked_ticks = 0
		if stops.has(unit.id):
			_set_destination(unit, stops[unit.id])


func _set_destination(unit: SimUnit, stop: Vector2i) -> void:
	var start: Vector2i = unit.step_cell if unit.stepping else unit.occupied_cell
	unit.path = pathfinder.find_path(start, stop, unit.is_air())
	if unit.path.is_empty() and start != stop:
		return  # unreachable after all; stay
	unit.destination = stop
	unit.has_destination = true
	_dest_res[stop] = unit.id


func _clear_destination(unit: SimUnit) -> void:
	if unit.has_destination and _dest_res.get(unit.destination, -1) == unit.id:
		_dest_res.erase(unit.destination)
	unit.has_destination = false


## Picks a distinct stop cell for each unit, nearest to `target` first.
func _assign_stops(group: Array[SimUnit], target: Vector2i) -> Dictionary[int, Vector2i]:
	var ids: Dictionary[int, bool] = {}
	var centroid: Vector2 = Vector2.ZERO
	for unit: SimUnit in group:
		ids[unit.id] = true
		centroid += unit.pos
	centroid /= group.size()

	# Collect free cells ring by ring around the target until there are enough,
	# plus one more ring so near-ties can be broken towards the group.
	var candidates: Array[Vector2i] = []
	var enough_at: int = -1
	var max_radius: int = maxi(grid.width, grid.height)
	for r: int in range(0, max_radius + 1):
		for y: int in range(target.y - r, target.y + r + 1):
			for x: int in range(target.x - r, target.x + r + 1):
				if maxi(absi(x - target.x), absi(y - target.y)) != r:
					continue
				var cell: Vector2i = Vector2i(x, y)
				if _is_stop_for_group(cell, ids) and _reachable_by_any(group, cell):
					candidates.append(cell)
		if enough_at < 0 and candidates.size() >= group.size():
			enough_at = r
		if enough_at >= 0 and r >= enough_at + 1:
			break

	var target_center: Vector2 = SimUnit.cell_center(target)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da: int = roundi(SimUnit.cell_center(a).distance_to(target_center) * 100.0)
		var db: int = roundi(SimUnit.cell_center(b).distance_to(target_center) * 100.0)
		if da != db:
			return da < db
		return SimUnit.cell_center(a).distance_to(centroid) < SimUnit.cell_center(b).distance_to(centroid))

	var result: Dictionary[int, Vector2i] = {}
	var unassigned: Array[SimUnit] = group.duplicate()
	for cell: Vector2i in candidates:
		if unassigned.is_empty():
			break
		var best: SimUnit = null
		var best_dist: float = INF
		for unit: SimUnit in unassigned:
			var d: float = unit.pos.distance_to(SimUnit.cell_center(cell))
			if d < best_dist and _reachable(unit, cell):
				best = unit
				best_dist = d
		if best != null:
			result[best.id] = cell
			unassigned.erase(best)
	return result


## Free for this group: passable, and any unit on it or heading to it is in the group.
func _is_stop_for_group(cell: Vector2i, group_ids: Dictionary[int, bool]) -> bool:
	if not grid.is_passable(cell):
		return false
	for layer: Dictionary[Vector2i, int] in [_ground_res, _air_res, _dest_res]:
		if layer.has(cell) and not group_ids.has(layer[cell]):
			return false
	return true


func _reachable(unit: SimUnit, cell: Vector2i) -> bool:
	if unit.is_air():
		return true
	var start: Vector2i = unit.step_cell if unit.stepping else unit.occupied_cell
	var region: int = pathfinder.region_of(start)
	return region != -1 and region == pathfinder.region_of(cell)


func _reachable_by_any(group: Array[SimUnit], cell: Vector2i) -> bool:
	for unit: SimUnit in group:
		if _reachable(unit, cell):
			return true
	return false


func _layer(unit: SimUnit) -> Dictionary[Vector2i, int]:
	return _air_res if unit.is_air() else _ground_res


func _can_enter(unit: SimUnit, cell: Vector2i) -> bool:
	if not unit.is_air() and not grid.is_passable(cell):
		return false
	var holder: int = _layer(unit).get(cell, -1)
	return holder == -1 or holder == unit.id


func _move(unit: SimUnit) -> void:
	var budget: float = unit.stats.move_speed * TICK_SECONDS
	while budget > EPSILON:
		if not unit.stepping:
			if unit.path.is_empty():
				break
			var next: Vector2i = unit.path[0]
			if not _can_enter(unit, next):
				_on_blocked(unit)
				return
			unit.blocked_ticks = 0
			unit.path.remove_at(0)
			unit.step_cell = next
			unit.stepping = true
			_layer(unit)[next] = unit.id
		var goal: Vector2 = SimUnit.cell_center(unit.step_cell)
		var dist: float = unit.pos.distance_to(goal)
		if dist <= budget + EPSILON:
			unit.pos = goal
			budget -= dist
			var layer: Dictionary[Vector2i, int] = _layer(unit)
			if layer.get(unit.occupied_cell, -1) == unit.id:
				layer.erase(unit.occupied_cell)
			unit.occupied_cell = unit.step_cell
			unit.stepping = false
		else:
			unit.pos += (goal - unit.pos) / dist * budget
			budget = 0.0
	if not unit.stepping and unit.path.is_empty() and unit.has_destination:
		_clear_destination(unit)


func _on_blocked(unit: SimUnit) -> void:
	unit.blocked_ticks += 1
	if unit.blocked_ticks % REPATH_AFTER_TICKS == 0 and unit.has_destination:
		var others: Array[Vector2i] = []
		var layer: Dictionary[Vector2i, int] = _layer(unit)
		for cell: Vector2i in layer:
			if layer[cell] != unit.id:
				others.append(cell)
		var detour: Array[Vector2i] = pathfinder.find_path(unit.occupied_cell, unit.destination, unit.is_air(), others)
		if not detour.is_empty():
			unit.path = detour
	if unit.blocked_ticks >= GIVE_UP_AFTER_TICKS:
		unit.blocked_ticks = 0
		_clear_destination(unit)
		unit.path.clear()
		if not unit.retargeted:
			# The spot may have been taken: choose the nearest free cell again.
			unit.retargeted = true
			var group: Array[SimUnit] = [unit]
			var stops: Dictionary[int, Vector2i] = _assign_stops(group, unit.order_target)
			if stops.has(unit.id) and stops[unit.id] != unit.occupied_cell:
				_set_destination(unit, stops[unit.id])


func _spawn_roster(roster: Array[UnitStats], team: SimUnit.Team, spawns: Array[Vector2i]) -> String:
	if roster.size() > spawns.size():
		return "%d units but only %d spawn cells for team %d" % [roster.size(), spawns.size(), team]
	for i: int in roster.size():
		if roster[i] == null:
			return "roster entry %d is null for team %d" % [i, team]
		if spawn_unit(roster[i], team, spawns[i]) == null:
			return "spawn cell %s is not free" % spawns[i]
	return ""
