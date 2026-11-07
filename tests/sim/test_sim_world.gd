extends GdUnitTestSuite
## SimWorld ticking, spawning and the move command.

const MISSION_PATH: String = "res://data/missions/mission_01.tres"

var _stats: UnitStats


func before_test() -> void:
	_stats = UnitStats.new()
	_stats.id = &"test"
	_stats.move_speed = 3.0  # 0.2 cells per tick at 15 ticks/s


func _world(rows: Array[String]) -> SimWorld:
	var world: SimWorld = SimWorld.new()
	assert_str(world.grid.load_rows(PackedStringArray(rows))).is_empty()
	return world


func _run(world: SimWorld, ticks: int) -> void:
	for i: int in ticks:
		world.step()


func _move(world: SimWorld, team: SimUnit.Team, ids: Array[int], cell: Vector2i) -> void:
	world.queue_command(MoveCommand.new(team, ids, cell))


func test_spawned_unit_starts_at_cell_centre() -> void:
	var world: SimWorld = _world(["...", "..."])
	var unit: SimUnit = world.spawn_unit(_stats, SimUnit.Team.BLUE, Vector2i(2, 1))
	assert_vector(unit.pos).is_equal(Vector2(2.5, 1.5))
	assert_that(unit.cell()).is_equal(Vector2i(2, 1))
	assert_object(world.get_unit(unit.id)).is_same(unit)


func test_command_applies_on_next_tick_not_immediately() -> void:
	var world: SimWorld = _world(["......"])
	var unit: SimUnit = world.spawn_unit(_stats, SimUnit.Team.BLUE, Vector2i(0, 0))
	_move(world, SimUnit.Team.BLUE, [unit.id], Vector2i(5, 0))
	assert_bool(unit.has_move_target).is_false()
	world.step()
	assert_bool(unit.has_move_target).is_true()
	assert_float(unit.pos.x).is_equal_approx(0.7, 0.0001)


func test_moves_at_stat_speed_and_stops_exactly_on_target() -> void:
	var world: SimWorld = _world(["......"])
	var unit: SimUnit = world.spawn_unit(_stats, SimUnit.Team.BLUE, Vector2i(0, 0))
	_move(world, SimUnit.Team.BLUE, [unit.id], Vector2i(3, 0))
	# 3 cells at 3 cells/s = 1 s = 15 ticks.
	_run(world, 14)
	assert_bool(unit.has_move_target).is_true()
	world.step()
	assert_vector(unit.pos).is_equal_approx(Vector2(3.5, 0.5), Vector2(0.0001, 0.0001))
	assert_bool(unit.has_move_target).is_false()
	_run(world, 5)
	assert_vector(unit.pos).is_equal_approx(Vector2(3.5, 0.5), Vector2(0.0001, 0.0001))


func test_prev_pos_tracks_last_tick_for_interpolation() -> void:
	var world: SimWorld = _world(["......"])
	var unit: SimUnit = world.spawn_unit(_stats, SimUnit.Team.BLUE, Vector2i(0, 0))
	_move(world, SimUnit.Team.BLUE, [unit.id], Vector2i(5, 0))
	_run(world, 3)
	assert_float(unit.pos.x - unit.prev_pos.x).is_equal_approx(0.2, 0.0001)


func test_moves_diagonally_in_a_straight_line() -> void:
	var world: SimWorld = _world(["....", "....", "....", "...."])
	var unit: SimUnit = world.spawn_unit(_stats, SimUnit.Team.BLUE, Vector2i(0, 0))
	_move(world, SimUnit.Team.BLUE, [unit.id], Vector2i(3, 3))
	_run(world, 40)
	assert_vector(unit.pos).is_equal_approx(Vector2(3.5, 3.5), Vector2(0.0001, 0.0001))


func test_impassable_target_is_ignored() -> void:
	var world: SimWorld = _world(["..#"])
	var unit: SimUnit = world.spawn_unit(_stats, SimUnit.Team.BLUE, Vector2i(0, 0))
	_move(world, SimUnit.Team.BLUE, [unit.id], Vector2i(2, 0))
	_move(world, SimUnit.Team.BLUE, [unit.id], Vector2i(9, 9))  # out of bounds
	_run(world, 10)
	assert_bool(unit.has_move_target).is_false()
	assert_vector(unit.pos).is_equal(Vector2(0.5, 0.5))


func test_blocked_unit_stops_before_obstacle() -> void:
	var world: SimWorld = _world([".#."])
	var unit: SimUnit = world.spawn_unit(_stats, SimUnit.Team.BLUE, Vector2i(0, 0))
	_move(world, SimUnit.Team.BLUE, [unit.id], Vector2i(2, 0))
	_run(world, 30)
	assert_bool(unit.has_move_target).is_false()
	assert_that(unit.cell()).is_equal(Vector2i(0, 0))
	assert_bool(world.grid.is_passable(unit.cell())).is_true()


func test_group_command_moves_every_listed_unit() -> void:
	var world: SimWorld = _world(["......", "......"])
	var a: SimUnit = world.spawn_unit(_stats, SimUnit.Team.BLUE, Vector2i(0, 0))
	var b: SimUnit = world.spawn_unit(_stats, SimUnit.Team.BLUE, Vector2i(0, 1))
	var c: SimUnit = world.spawn_unit(_stats, SimUnit.Team.BLUE, Vector2i(1, 1))
	_move(world, SimUnit.Team.BLUE, [a.id, b.id], Vector2i(5, 0))
	world.step()
	assert_bool(a.has_move_target).is_true()
	assert_bool(b.has_move_target).is_true()
	assert_bool(c.has_move_target).is_false()


func test_command_cannot_move_other_teams_units() -> void:
	var world: SimWorld = _world(["......"])
	var red: SimUnit = world.spawn_unit(_stats, SimUnit.Team.RED, Vector2i(0, 0))
	_move(world, SimUnit.Team.BLUE, [red.id, 999], Vector2i(5, 0))
	_run(world, 5)
	assert_bool(red.has_move_target).is_false()
	assert_vector(red.pos).is_equal(Vector2(0.5, 0.5))


func test_new_order_replaces_old_one() -> void:
	var world: SimWorld = _world(["......"])
	var unit: SimUnit = world.spawn_unit(_stats, SimUnit.Team.BLUE, Vector2i(2, 0))
	_move(world, SimUnit.Team.BLUE, [unit.id], Vector2i(5, 0))
	_run(world, 2)
	_move(world, SimUnit.Team.BLUE, [unit.id], Vector2i(0, 0))
	_run(world, 30)
	assert_vector(unit.pos).is_equal_approx(Vector2(0.5, 0.5), Vector2(0.0001, 0.0001))


func test_tick_counter_advances() -> void:
	var world: SimWorld = _world(["."])
	_run(world, 7)
	assert_int(world.tick).is_equal(7)


func test_mission_01_spawns_hero_and_three_troops_per_side() -> void:
	var world: SimWorld = SimWorld.new()
	var data: MissionData = load(MISSION_PATH) as MissionData
	assert_object(data).is_not_null()
	assert_str(world.setup_mission(data)).is_empty()
	assert_array(world.units).has_size(8)
	for team: SimUnit.Team in [SimUnit.Team.BLUE, SimUnit.Team.RED]:
		var heroes: int = 0
		var count: int = 0
		for unit: SimUnit in world.units:
			if unit.team != team:
				continue
			count += 1
			if unit.stats.is_hero:
				heroes += 1
			assert_bool(world.grid.is_passable(unit.cell())).is_true()
		assert_int(count).is_equal(4)
		assert_int(heroes).is_equal(1)


func test_setup_fails_cleanly_when_roster_exceeds_spawns() -> void:
	var layout: MapLayout = MapLayout.new()
	layout.rows = PackedStringArray(["B.R"])
	var data: MissionData = MissionData.new()
	data.map = layout
	data.blue_roster = [_stats, _stats]
	var world: SimWorld = SimWorld.new()
	assert_str(world.setup_mission(data)).contains("spawn cells")
