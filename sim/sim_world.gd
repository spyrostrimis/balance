class_name SimWorld
extends RefCounted
## The whole simulation state, advanced in fixed ticks (independent of frame rate).

const TICKS_PER_SECOND: int = 15
const TICK_SECONDS: float = 1.0 / TICKS_PER_SECOND

var grid: MapGrid = MapGrid.new()
var units: Array[SimUnit] = []
var tick: int = 0

var _pending: Array[SimCommand] = []
var _next_id: int = 1
var _by_id: Dictionary[int, SimUnit] = {}


## Loads the mission's map and spawns both rosters. Returns "" or an error message.
func setup_mission(data: MissionData) -> String:
	if data == null:
		return "mission data is null"
	var err: String = grid.load_layout(data.map)
	if err != "":
		return err
	err = _spawn_roster(data.blue_roster, SimUnit.Team.BLUE, grid.blue_spawns)
	if err != "":
		return err
	return _spawn_roster(data.red_roster, SimUnit.Team.RED, grid.red_spawns)


func spawn_unit(stats: UnitStats, team: SimUnit.Team, cell: Vector2i) -> SimUnit:
	var unit: SimUnit = SimUnit.new(_next_id, team, stats, SimUnit.cell_center(cell))
	_next_id += 1
	units.append(unit)
	_by_id[unit.id] = unit
	return unit


func get_unit(unit_id: int) -> SimUnit:
	return _by_id.get(unit_id, null)


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


func _move(unit: SimUnit) -> void:
	if not unit.has_move_target:
		return
	var to_target: Vector2 = unit.move_target - unit.pos
	var step_length: float = unit.stats.move_speed * TICK_SECONDS
	var arrived: bool = to_target.length() <= step_length
	var next: Vector2 = unit.move_target if arrived else unit.pos + to_target.normalized() * step_length
	if not grid.is_passable(Vector2i(floori(next.x), floori(next.y))):
		unit.has_move_target = false  # blocked (no pathfinding until milestone 3)
		return
	unit.pos = next
	if arrived:
		unit.has_move_target = false


func _spawn_roster(roster: Array[UnitStats], team: SimUnit.Team, spawns: Array[Vector2i]) -> String:
	if roster.size() > spawns.size():
		return "%d units but only %d spawn cells for team %d" % [roster.size(), spawns.size(), team]
	for i: int in roster.size():
		if roster[i] == null:
			return "roster entry %d is null for team %d" % [i, team]
		spawn_unit(roster[i], team, spawns[i])
	return ""
