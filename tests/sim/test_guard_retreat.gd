extends GdUnitTestSuite
## Guard (hold the spot, fire in range, never chase) and Retreat (back to the
## start area).

const BLUE: SimUnit.Team = SimUnit.Team.BLUE
const RED: SimUnit.Team = SimUnit.Team.RED

var _soldier: UnitStats


func before_test() -> void:
	_soldier = UnitStats.new()
	_soldier.id = &"test_soldier"
	_soldier.move_speed = 3.0
	_soldier.max_hp = 100
	_soldier.attack_damage = 10
	_soldier.attack_range = 2.0
	_soldier.attack_cooldown = 1.0
	_soldier.acquire_range = 5.0


func _world() -> SimWorld:
	var world: SimWorld = SimWorld.new()
	assert_str(world.load_map_rows(PackedStringArray([
		"BB............RR",
		"BB............RR",
		"................",
		"................",
	]))).is_empty()
	return world


func _run(world: SimWorld, ticks: int) -> void:
	for i: int in ticks:
		world.step()


func test_guard_does_not_chase_enemies_in_engage_range() -> void:
	var world: SimWorld = _world()
	var blue: SimUnit = world.spawn_unit(_soldier, BLUE, Vector2i(4, 2))
	world.queue_command(GuardCommand.new(BLUE, [blue.id]))
	_run(world, 1)
	var red: SimUnit = world.spawn_unit(_soldier, RED, Vector2i(8, 2))  # 4 cells: engage, not attack
	red.stats = _soldier.duplicate() as UnitStats
	red.stats.attack_range = 0.0
	_run(world, 30)
	assert_bool(blue.guarding).is_true()
	assert_that(blue.cell()).is_equal(Vector2i(4, 2))
	assert_int(red.hp).is_equal(100)


func test_guard_fires_at_enemies_in_range() -> void:
	var world: SimWorld = _world()
	var blue: SimUnit = world.spawn_unit(_soldier, BLUE, Vector2i(4, 2))
	world.queue_command(GuardCommand.new(BLUE, [blue.id]))
	_run(world, 1)
	var red: SimUnit = world.spawn_unit(_soldier, RED, Vector2i(6, 2))
	red.hp = 1000
	_run(world, 20)
	assert_int(red.hp).is_less(1000)
	assert_that(blue.cell()).is_equal(Vector2i(4, 2))


func test_guard_ignores_a_shooter_out_of_range() -> void:
	var world: SimWorld = _world()
	var blue: SimUnit = world.spawn_unit(_soldier, BLUE, Vector2i(4, 2))
	blue.hp = 1000
	world.queue_command(GuardCommand.new(BLUE, [blue.id]))
	_run(world, 1)
	var sniper_stats: UnitStats = _soldier.duplicate() as UnitStats
	sniper_stats.attack_range = 5.0
	sniper_stats.acquire_range = 5.0
	world.spawn_unit(sniper_stats, RED, Vector2i(9, 2))
	_run(world, 45)
	assert_int(blue.hp).is_less(1000)  # it was shot...
	assert_that(blue.cell()).is_equal(Vector2i(4, 2))  # ...and held its spot


func test_guard_stops_a_moving_unit_and_orders_clear_it() -> void:
	var world: SimWorld = _world()
	var blue: SimUnit = world.spawn_unit(_soldier, BLUE, Vector2i(2, 2))
	world.queue_command(MoveCommand.new(BLUE, [blue.id], Vector2i(13, 2)))
	_run(world, 5)
	world.queue_command(GuardCommand.new(BLUE, [blue.id]))
	_run(world, 10)
	assert_bool(blue.is_moving()).is_false()
	var stopped_at: Vector2i = blue.cell()
	assert_int(stopped_at.x).is_less(13)
	world.queue_command(MoveCommand.new(BLUE, [blue.id], Vector2i(13, 3)))
	_run(world, 1)
	assert_bool(blue.guarding).is_false()


func test_retreat_walks_back_to_the_start_area_without_fighting() -> void:
	var world: SimWorld = _world()
	var blue: SimUnit = world.spawn_unit(_soldier, BLUE, Vector2i(10, 2))
	blue.hp = 1000
	var red: SimUnit = world.spawn_unit(_soldier, RED, Vector2i(12, 2))
	red.hp = 1000
	_run(world, 5)  # fighting
	world.queue_command(RetreatCommand.new(BLUE, [blue.id]))
	var shots_while_moving: int = 0
	for i: int in 90:
		world.step()
		for event: CombatEvent in world.events:
			if event.kind == CombatEvent.Kind.SHOT and event.unit_id == blue.id and blue.is_moving():
				shots_while_moving += 1
	assert_int(shots_while_moving).is_equal(0)
	assert_float(blue.pos.distance_to(SimUnit.cell_center(world.grid.blue_spawns[0]))).is_less_equal(1.5)
