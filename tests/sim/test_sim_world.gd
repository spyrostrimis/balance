extends GdUnitTestSuite
## SimWorld: ticking, spawning, move orders, pathfinding, one-unit-per-cell, air units.

const MISSION_PATH: String = "res://data/missions/mission_01.tres"
const BLUE: SimUnit.Team = SimUnit.Team.BLUE
const RED: SimUnit.Team = SimUnit.Team.RED

var _ground: UnitStats
var _air: UnitStats


func before_test() -> void:
	_ground = UnitStats.new()
	_ground.id = &"test_ground"
	_ground.move_speed = 3.0  # 0.2 cells per tick at 15 ticks/s
	_ground.attack_range = 0.0  # no fighting in movement tests (see test_combat.gd)
	_air = UnitStats.new()
	_air.id = &"test_air"
	_air.move_speed = 3.0
	_air.is_air = true
	_air.attack_range = 0.0


func _world(rows: Array[String]) -> SimWorld:
	var world: SimWorld = SimWorld.new()
	assert_str(world.load_map_rows(PackedStringArray(rows))).is_empty()
	return world


## Runs ticks, checking every tick that no two units share a cell in the same
## layer, that ground units never stand in impassable cells, and that no two
## idle units share a cell at all.
func _run(world: SimWorld, ticks: int) -> void:
	for i: int in ticks:
		world.step()
		var ground_cells: Dictionary[Vector2i, int] = {}
		var air_cells: Dictionary[Vector2i, int] = {}
		var idle_cells: Dictionary[Vector2i, int] = {}
		for unit: SimUnit in world.units:
			var layer: Dictionary[Vector2i, int] = air_cells if unit.is_air() else ground_cells
			var held: Array[Vector2i] = [unit.occupied_cell]
			if unit.stepping:
				held.append(unit.step_cell)
			for cell: Vector2i in held:
				assert_bool(layer.has(cell)).override_failure_message(
						"tick %d: units %d and %d share %s" % [world.tick, layer.get(cell, -1), unit.id, cell]).is_false()
				layer[cell] = unit.id
				if not unit.is_air():
					assert_bool(world.grid.is_passable(cell)).override_failure_message(
							"tick %d: unit %d in impassable %s" % [world.tick, unit.id, cell]).is_true()
			if not unit.is_moving():
				assert_bool(idle_cells.has(unit.occupied_cell)).override_failure_message(
						"tick %d: idle units stacked on %s" % [world.tick, unit.occupied_cell]).is_false()
				idle_cells[unit.occupied_cell] = unit.id


func _move(world: SimWorld, team: SimUnit.Team, ids: Array[int], cell: Vector2i) -> void:
	world.queue_command(MoveCommand.new(team, ids, cell))


func _ids(list: Array[SimUnit]) -> Array[int]:
	var result: Array[int] = []
	for unit: SimUnit in list:
		result.append(unit.id)
	return result


# --- basics ---

func test_spawned_unit_starts_at_cell_centre_and_holds_it() -> void:
	var world: SimWorld = _world(["...", "..."])
	var unit: SimUnit = world.spawn_unit(_ground, BLUE, Vector2i(2, 1))
	assert_vector(unit.pos).is_equal(Vector2(2.5, 1.5))
	assert_that(unit.cell()).is_equal(Vector2i(2, 1))
	assert_object(world.get_unit(unit.id)).is_same(unit)
	assert_bool(world.is_cell_free(Vector2i(2, 1))).is_false()


func test_cannot_spawn_on_occupied_or_impassable_cell() -> void:
	var world: SimWorld = _world(["..#"])
	world.spawn_unit(_ground, BLUE, Vector2i(0, 0))
	assert_object(world.spawn_unit(_ground, RED, Vector2i(0, 0))).is_null()
	assert_object(world.spawn_unit(_air, RED, Vector2i(0, 0))).is_null()
	assert_object(world.spawn_unit(_ground, RED, Vector2i(2, 0))).is_null()


func test_command_applies_on_next_tick_not_immediately() -> void:
	var world: SimWorld = _world(["......"])
	var unit: SimUnit = world.spawn_unit(_ground, BLUE, Vector2i(0, 0))
	_move(world, BLUE, [unit.id], Vector2i(5, 0))
	assert_bool(unit.is_moving()).is_false()
	world.step()
	assert_bool(unit.is_moving()).is_true()
	assert_float(unit.pos.x).is_equal_approx(0.7, 0.0001)


func test_moves_at_stat_speed_and_stops_exactly_on_target() -> void:
	var world: SimWorld = _world(["......"])
	var unit: SimUnit = world.spawn_unit(_ground, BLUE, Vector2i(0, 0))
	_move(world, BLUE, [unit.id], Vector2i(3, 0))
	# 3 cells at 3 cells/s = 1 s = 15 ticks.
	_run(world, 14)
	assert_bool(unit.is_moving()).is_true()
	_run(world, 1)
	assert_vector(unit.pos).is_equal_approx(Vector2(3.5, 0.5), Vector2(0.0001, 0.0001))
	assert_bool(unit.is_moving()).is_false()
	assert_that(unit.cell()).is_equal(Vector2i(3, 0))
	_run(world, 5)
	assert_vector(unit.pos).is_equal_approx(Vector2(3.5, 0.5), Vector2(0.0001, 0.0001))


func test_prev_pos_tracks_last_tick_for_interpolation() -> void:
	var world: SimWorld = _world(["......"])
	var unit: SimUnit = world.spawn_unit(_ground, BLUE, Vector2i(0, 0))
	_move(world, BLUE, [unit.id], Vector2i(5, 0))
	_run(world, 3)
	assert_float(unit.pos.x - unit.prev_pos.x).is_equal_approx(0.2, 0.0001)


func test_command_cannot_move_other_teams_units() -> void:
	var world: SimWorld = _world(["......"])
	var red: SimUnit = world.spawn_unit(_ground, RED, Vector2i(0, 0))
	_move(world, BLUE, [red.id, 999], Vector2i(5, 0))
	_run(world, 5)
	assert_bool(red.is_moving()).is_false()
	assert_vector(red.pos).is_equal(Vector2(0.5, 0.5))


func test_new_order_replaces_old_one() -> void:
	var world: SimWorld = _world(["......"])
	var unit: SimUnit = world.spawn_unit(_ground, BLUE, Vector2i(2, 0))
	_move(world, BLUE, [unit.id], Vector2i(5, 0))
	_run(world, 2)
	_move(world, BLUE, [unit.id], Vector2i(0, 0))
	_run(world, 40)
	assert_that(unit.cell()).is_equal(Vector2i(0, 0))
	assert_bool(unit.is_moving()).is_false()


func test_tick_counter_advances() -> void:
	var world: SimWorld = _world(["."])
	_run(world, 7)
	assert_int(world.tick).is_equal(7)


# --- pathfinding ---

func test_routes_around_a_wall_to_the_other_side() -> void:
	var world: SimWorld = _world([
		".....",
		".###.",
		".....",
	])
	var unit: SimUnit = world.spawn_unit(_ground, BLUE, Vector2i(2, 0))
	_move(world, BLUE, [unit.id], Vector2i(2, 2))
	_run(world, 80)
	assert_that(unit.cell()).is_equal(Vector2i(2, 2))
	assert_bool(unit.is_moving()).is_false()


func test_does_not_cut_corners_of_obstacles() -> void:
	var world: SimWorld = _world([
		"..",
		"#.",
	])
	var unit: SimUnit = world.spawn_unit(_ground, BLUE, Vector2i(0, 0))
	_move(world, BLUE, [unit.id], Vector2i(1, 1))
	world.step()
	# Diagonal (0,0)→(1,1) would clip the rock at (0,1): must go via (1,0).
	assert_that(unit.step_cell).is_equal(Vector2i(1, 0))


func test_clicking_a_rock_stops_in_front_of_it() -> void:
	var world: SimWorld = _world([
		".....",
		"..#..",
		".....",
	])
	var unit: SimUnit = world.spawn_unit(_ground, BLUE, Vector2i(0, 1))
	_move(world, BLUE, [unit.id], Vector2i(2, 1))
	_run(world, 40)
	assert_that(unit.cell()).is_equal(Vector2i(1, 1))


func test_clicking_unreachable_area_goes_to_nearest_reachable_cell() -> void:
	var world: SimWorld = _world([
		".....",
		".###.",
		".#.#.",
		".###.",
		".....",
	])
	var unit: SimUnit = world.spawn_unit(_ground, BLUE, Vector2i(0, 0))
	_move(world, BLUE, [unit.id], Vector2i(2, 2))  # walled-in cell
	_run(world, 80)
	assert_bool(unit.is_moving()).is_false()
	var dist: float = SimUnit.cell_center(unit.cell()).distance_to(SimUnit.cell_center(Vector2i(2, 2)))
	assert_float(dist).is_equal_approx(2.0, 0.001)


func test_clicking_outside_the_map_goes_to_nearest_edge_cell() -> void:
	var world: SimWorld = _world(["....", "...."])
	var unit: SimUnit = world.spawn_unit(_ground, BLUE, Vector2i(0, 0))
	_move(world, BLUE, [unit.id], Vector2i(50, -7))
	_run(world, 40)
	assert_that(unit.cell()).is_equal(Vector2i(3, 0))


# --- one unit per cell ---

func test_group_order_spreads_to_distinct_nearby_cells() -> void:
	var world: SimWorld = _world([
		".......",
		".......",
		".......",
		".......",
		".......",
		".......",
		".......",
	])
	var group: Array[SimUnit] = []
	for x: int in 4:
		group.append(world.spawn_unit(_ground, BLUE, Vector2i(x, 6)))
	_move(world, BLUE, _ids(group), Vector2i(3, 1))
	_run(world, 120)
	var cells: Dictionary[Vector2i, bool] = {}
	for unit: SimUnit in group:
		assert_bool(unit.is_moving()).is_false()
		cells[unit.cell()] = true
		var d: float = SimUnit.cell_center(unit.cell()).distance_to(SimUnit.cell_center(Vector2i(3, 1)))
		assert_float(d).is_less_equal(1.5)
	assert_int(cells.size()).is_equal(4)
	assert_bool(cells.has(Vector2i(3, 1))).is_true()


func test_clicking_an_occupied_cell_stops_next_to_the_unit() -> void:
	var world: SimWorld = _world(["......"])
	var mover: SimUnit = world.spawn_unit(_ground, BLUE, Vector2i(0, 0))
	world.spawn_unit(_ground, BLUE, Vector2i(4, 0))
	_move(world, BLUE, [mover.id], Vector2i(4, 0))
	_run(world, 40)
	assert_that(mover.cell()).is_equal(Vector2i(3, 0))


func test_walks_around_an_idle_unit_in_the_way() -> void:
	var world: SimWorld = _world([
		".....",
		".....",
	])
	var mover: SimUnit = world.spawn_unit(_ground, BLUE, Vector2i(0, 0))
	var blocker: SimUnit = world.spawn_unit(_ground, RED, Vector2i(2, 0))
	_move(world, BLUE, [mover.id], Vector2i(4, 0))
	_run(world, 80)
	assert_that(mover.cell()).is_equal(Vector2i(4, 0))
	assert_that(blocker.cell()).is_equal(Vector2i(2, 0))


func test_head_on_in_a_corridor_never_overlaps_and_settles() -> void:
	var world: SimWorld = _world(["......"])
	var a: SimUnit = world.spawn_unit(_ground, BLUE, Vector2i(0, 0))
	var b: SimUnit = world.spawn_unit(_ground, BLUE, Vector2i(5, 0))
	_move(world, BLUE, [a.id], Vector2i(5, 0))
	_move(world, BLUE, [b.id], Vector2i(0, 0))
	_run(world, 200)  # _run asserts no overlap every tick
	assert_bool(a.is_moving()).is_false()
	assert_bool(b.is_moving()).is_false()
	assert_that(a.cell()).is_not_equal(b.cell())


func test_two_groups_ordered_to_the_same_cell_do_not_stack() -> void:
	var world: SimWorld = _world([
		".....",
		".....",
		".....",
	])
	var a: SimUnit = world.spawn_unit(_ground, BLUE, Vector2i(0, 0))
	var b: SimUnit = world.spawn_unit(_ground, BLUE, Vector2i(4, 2))
	_move(world, BLUE, [a.id], Vector2i(2, 1))
	_move(world, BLUE, [b.id], Vector2i(2, 1))
	_run(world, 60)
	assert_that(a.cell()).is_not_equal(b.cell())


# --- air units ---

func test_air_unit_flies_over_rocks() -> void:
	var world: SimWorld = _world([".#."])
	var flyer: SimUnit = world.spawn_unit(_air, BLUE, Vector2i(0, 0))
	_move(world, BLUE, [flyer.id], Vector2i(2, 0))
	_run(world, 10)
	assert_that(flyer.cell()).is_equal(Vector2i(2, 0))


func test_air_unit_flies_over_ground_units_without_waiting() -> void:
	var world: SimWorld = _world(["..."])
	var flyer: SimUnit = world.spawn_unit(_air, BLUE, Vector2i(0, 0))
	world.spawn_unit(_ground, BLUE, Vector2i(1, 0))
	_move(world, BLUE, [flyer.id], Vector2i(2, 0))
	_run(world, 10)  # 2 cells at 0.2/tick = exactly 10 ticks
	assert_that(flyer.cell()).is_equal(Vector2i(2, 0))


func test_air_unit_cannot_stop_on_a_rock() -> void:
	var world: SimWorld = _world([".#.."])
	var flyer: SimUnit = world.spawn_unit(_air, BLUE, Vector2i(3, 0))
	_move(world, BLUE, [flyer.id], Vector2i(1, 0))
	_run(world, 30)
	assert_that(flyer.cell()).is_equal(Vector2i(2, 0))


func test_ground_unit_cannot_stop_under_a_landed_air_unit() -> void:
	var world: SimWorld = _world(["....."])
	world.spawn_unit(_air, BLUE, Vector2i(2, 0))
	var walker: SimUnit = world.spawn_unit(_ground, BLUE, Vector2i(0, 0))
	_move(world, BLUE, [walker.id], Vector2i(2, 0))
	_run(world, 30)
	assert_that(walker.cell()).is_equal(Vector2i(1, 0))


func test_ground_unit_walks_under_a_landed_air_unit() -> void:
	var world: SimWorld = _world(["....."])
	world.spawn_unit(_air, BLUE, Vector2i(2, 0))
	var walker: SimUnit = world.spawn_unit(_ground, BLUE, Vector2i(0, 0))
	_move(world, BLUE, [walker.id], Vector2i(4, 0))
	_run(world, 20)  # 4 cells, no waiting
	assert_that(walker.cell()).is_equal(Vector2i(4, 0))


# --- mission data ---

func test_mission_01_spawns_hero_and_three_troops_per_side() -> void:
	var world: SimWorld = SimWorld.new()
	var data: MissionData = load(MISSION_PATH) as MissionData
	assert_object(data).is_not_null()
	assert_str(world.setup_mission(data)).is_empty()
	assert_array(world.units).has_size(8)
	for team: SimUnit.Team in [BLUE, RED]:
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


func test_mission_01_whole_blue_team_crosses_the_map() -> void:
	var world: SimWorld = SimWorld.new()
	assert_str(world.setup_mission(load(MISSION_PATH) as MissionData)).is_empty()
	var blue: Array[SimUnit] = []
	for unit: SimUnit in world.units:
		if unit.team == BLUE:
			blue.append(unit)
	# North-west, behind the north cliff spur (out of Red's range).
	_move(world, BLUE, _ids(blue), Vector2i(12, 2))
	_run(world, 450)  # 30 s
	for unit: SimUnit in blue:
		assert_bool(unit.is_moving()).override_failure_message("unit %d still moving" % unit.id).is_false()
		var d: float = SimUnit.cell_center(unit.cell()).distance_to(SimUnit.cell_center(Vector2i(12, 2)))
		assert_float(d).is_less_equal(2.0)


func test_setup_fails_cleanly_when_roster_exceeds_spawns() -> void:
	var layout: MapLayout = MapLayout.new()
	layout.rows = PackedStringArray(["B.R"])
	var data: MissionData = MissionData.new()
	data.map = layout
	data.blue_roster = [_ground, _ground]
	var world: SimWorld = SimWorld.new()
	assert_str(world.setup_mission(data)).contains("spawn cells")
