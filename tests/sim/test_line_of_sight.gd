extends GdUnitTestSuite
## Line of sight: rocks and cliffs block shots and sight, units don't.

const BLUE: SimUnit.Team = SimUnit.Team.BLUE
const RED: SimUnit.Team = SimUnit.Team.RED

var _soldier: UnitStats


func before_test() -> void:
	_soldier = UnitStats.new()
	_soldier.id = &"test_soldier"
	_soldier.move_speed = 3.0
	_soldier.max_hp = 30
	_soldier.attack_damage = 10
	_soldier.attack_range = 4.0
	_soldier.attack_cooldown = 1.0
	_soldier.acquire_range = 5.0


func _world(rows: Array[String]) -> SimWorld:
	var world: SimWorld = SimWorld.new()
	assert_str(world.load_map_rows(PackedStringArray(rows))).is_empty()
	return world


func _c(x: int, y: int) -> Vector2:
	return SimUnit.cell_center(Vector2i(x, y))


func test_rock_cliff_and_orichalcum_block_sight() -> void:
	var world: SimWorld = _world(["......", "......"])
	assert_bool(world.grid.blocks_sight(Vector2i(0, 0))).is_false()
	var blockers: SimWorld = _world(["^#O..."])
	for x: int in 3:
		assert_bool(blockers.grid.blocks_sight(Vector2i(x, 0))).is_true()
	assert_bool(blockers.grid.blocks_sight(Vector2i(-1, 0))).is_true()  # outside the map


func test_clear_and_blocked_lines() -> void:
	var world: SimWorld = _world([
		"......",
		"..#...",
		"......",
	])
	assert_bool(world.has_line_of_sight(_c(0, 0), _c(5, 0))).is_true()
	assert_bool(world.has_line_of_sight(_c(0, 1), _c(5, 1))).is_false()
	assert_bool(world.has_line_of_sight(_c(2, 0), _c(2, 2))).is_false()
	assert_bool(world.has_line_of_sight(_c(0, 0), _c(4, 2))).is_false()  # clips the rock
	assert_bool(world.has_line_of_sight(_c(0, 2), _c(5, 2))).is_true()
	# Symmetric.
	assert_bool(world.has_line_of_sight(_c(5, 1), _c(0, 1))).is_false()
	assert_bool(world.has_line_of_sight(_c(4, 2), _c(0, 0))).is_false()


func test_exact_corner_is_blocked_only_between_two_blockers() -> void:
	var one: SimWorld = _world([
		".#.",
		"...",
	])
	assert_bool(one.has_line_of_sight(_c(0, 0), _c(1, 1))).is_true()
	var two: SimWorld = _world([
		".#",
		"#.",
	])
	assert_bool(two.has_line_of_sight(_c(0, 0), _c(1, 1))).is_false()


func test_units_do_not_block_shots() -> void:
	var world: SimWorld = _world(["......"])
	var blue: SimUnit = world.spawn_unit(_soldier, BLUE, Vector2i(0, 0))
	var ally: SimUnit = world.spawn_unit(_soldier, BLUE, Vector2i(1, 0))
	ally.stats = _soldier.duplicate() as UnitStats
	ally.stats.attack_range = 0.0
	var red: SimUnit = world.spawn_unit(_soldier, RED, Vector2i(3, 0))
	red.hp = 1000
	world.step()
	assert_bool(world.can_hit(blue, red)).is_true()
	assert_int(red.hp).is_less(1000)


func test_no_auto_attack_through_a_rock() -> void:
	var world: SimWorld = _world([
		"...#...",
	])
	var blue: SimUnit = world.spawn_unit(_soldier, BLUE, Vector2i(1, 0))
	var red: SimUnit = world.spawn_unit(_soldier, RED, Vector2i(5, 0))
	for i: int in 30:
		world.step()
	assert_int(blue.attack_target_id).is_equal(-1)
	assert_int(red.attack_target_id).is_equal(-1)
	assert_int(blue.hp).is_equal(30)
	assert_int(red.hp).is_equal(30)


func test_attack_order_walks_round_a_rock_until_in_sight() -> void:
	var world: SimWorld = _world([
		".......",
		".......",
		"...#...",
		".......",
	])
	var blue: SimUnit = world.spawn_unit(_soldier, BLUE, Vector2i(1, 2))
	var dummy: UnitStats = _soldier.duplicate() as UnitStats
	dummy.attack_range = 0.0
	var red: SimUnit = world.spawn_unit(dummy, RED, Vector2i(5, 2))
	red.hp = 1000
	assert_bool(world.in_attack_range(blue, red)).is_true()
	assert_bool(world.can_hit(blue, red)).is_false()
	world.queue_command(AttackCommand.new(BLUE, [blue.id], red.id))
	var blind_shots: int = 0
	for i: int in 60:
		world.step()
		for event: CombatEvent in world.events:
			if event.kind == CombatEvent.Kind.SHOT and not world.has_line_of_sight(blue.pos, red.pos):
				blind_shots += 1
	assert_int(blind_shots).is_equal(0)
	assert_bool(world.can_hit(blue, red)).is_true()
	assert_int(red.hp).is_less(1000)
	assert_that(blue.cell()).is_not_equal(Vector2i(1, 2))


func test_air_units_shoot_over_terrain() -> void:
	var world: SimWorld = _world(["..^.."])
	var flyer: UnitStats = _soldier.duplicate() as UnitStats
	flyer.is_air = true
	var blue: SimUnit = world.spawn_unit(flyer, BLUE, Vector2i(0, 0))
	var red: SimUnit = world.spawn_unit(_soldier, RED, Vector2i(4, 0))
	assert_bool(world.can_hit(blue, red)).is_true()
	assert_bool(world.can_hit(red, blue)).is_true()
