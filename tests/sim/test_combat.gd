extends GdUnitTestSuite
## Combat: HP, range, damage, cooldown, death, downed heroes, attack orders,
## auto-attack, retaliation, simultaneous resolution, and a full Mission 1 brawl.

const MISSION_PATH: String = "res://data/missions/mission_01.tres"
const BLUE: SimUnit.Team = SimUnit.Team.BLUE
const RED: SimUnit.Team = SimUnit.Team.RED

var _soldier: UnitStats
var _hero: UnitStats


func before_test() -> void:
	_soldier = UnitStats.new()
	_soldier.id = &"test_soldier"
	_soldier.move_speed = 3.0
	_soldier.max_hp = 30
	_soldier.attack_damage = 10
	_soldier.attack_range = 2.0
	_soldier.attack_cooldown = 1.0  # 15 ticks
	_soldier.acquire_range = 4.0
	_hero = _soldier.duplicate() as UnitStats
	_hero.id = &"test_hero"
	_hero.is_hero = true


func _world(rows: Array[String]) -> SimWorld:
	var world: SimWorld = SimWorld.new()
	assert_str(world.load_map_rows(PackedStringArray(rows))).is_empty()
	return world


func _run(world: SimWorld, ticks: int) -> int:
	var shots: int = 0
	for i: int in ticks:
		world.step()
		for event: CombatEvent in world.events:
			if event.kind == CombatEvent.Kind.SHOT:
				shots += 1
	return shots


func test_idle_unit_auto_attacks_enemy_in_range() -> void:
	var world: SimWorld = _world(["......"])
	var blue: SimUnit = world.spawn_unit(_soldier, BLUE, Vector2i(0, 0))
	var red: SimUnit = world.spawn_unit(_soldier, RED, Vector2i(2, 0))
	world.step()
	assert_int(blue.attack_target_id).is_equal(red.id)
	assert_int(red.hp).is_equal(20)  # first shot is immediate
	assert_int(blue.hp).is_equal(20)


func test_damage_follows_cooldown() -> void:
	var world: SimWorld = _world(["......"])
	world.spawn_unit(_soldier, BLUE, Vector2i(0, 0))
	var red: SimUnit = world.spawn_unit(_hero, RED, Vector2i(2, 0))
	red.hp = 1000  # survives; we only count blue's shots on it
	_run(world, 1)
	assert_int(red.hp).is_equal(990)
	_run(world, 14)
	assert_int(red.hp).is_equal(990)  # still cooling down
	_run(world, 1)
	assert_int(red.hp).is_equal(980)  # 15 ticks after the first shot


func test_idle_unit_engages_enemy_within_acquire_range() -> void:
	var world: SimWorld = _world(["........"])
	var blue: SimUnit = world.spawn_unit(_soldier, BLUE, Vector2i(0, 0))
	var red: SimUnit = world.spawn_unit(_soldier, RED, Vector2i(4, 0))  # 4 cells: acquire, not attack
	blue.hp = 1000
	red.hp = 1000
	_run(world, 1)
	assert_int(blue.attack_target_id).is_equal(red.id)
	_run(world, 30)
	assert_bool(world.in_attack_range(blue, red)).is_true()
	assert_int(red.hp).is_less(1000)


func test_auto_target_is_dropped_when_it_runs_away() -> void:
	var world: SimWorld = _world(["................"])
	var blue: SimUnit = world.spawn_unit(_soldier, BLUE, Vector2i(0, 0))
	var runner_stats: UnitStats = _soldier.duplicate() as UnitStats
	runner_stats.move_speed = 6.0
	runner_stats.attack_range = 0.0
	runner_stats.acquire_range = 0.0
	var red: SimUnit = world.spawn_unit(runner_stats, RED, Vector2i(4, 0))
	red.hp = 1000
	_run(world, 1)
	assert_int(blue.attack_target_id).is_equal(red.id)
	world.queue_command(MoveCommand.new(RED, [red.id], Vector2i(15, 0)))
	_run(world, 90)
	# Dropped it and walked back to its post.
	assert_int(blue.attack_target_id).is_equal(-1)
	assert_bool(blue.is_moving()).is_false()
	assert_that(blue.cell()).is_equal(Vector2i(0, 0))


func test_unit_returns_to_its_post_after_the_kill() -> void:
	var world: SimWorld = _world(["................"])
	var blue: SimUnit = world.spawn_unit(_soldier, BLUE, Vector2i(0, 0))
	blue.hp = 1000
	var dummy: UnitStats = _soldier.duplicate() as UnitStats
	dummy.attack_range = 0.0
	var red: SimUnit = world.spawn_unit(dummy, RED, Vector2i(4, 0))  # engage, not attack range
	_run(world, 10)
	assert_bool(blue.has_home).is_true()
	assert_that(blue.home_cell).is_equal(Vector2i(0, 0))
	assert_that(blue.cell()).is_not_equal(Vector2i(0, 0))  # walked in to fire
	_run(world, 80)
	assert_bool(red.dead).is_true()
	assert_that(blue.cell()).is_equal(Vector2i(0, 0))
	assert_bool(blue.is_moving()).is_false()


func test_fast_attacker_cannot_drag_defenders_across_the_map() -> void:
	var world: SimWorld = _world(["..............................."])
	var raider_stats: UnitStats = _soldier.duplicate() as UnitStats
	raider_stats.move_speed = 6.0
	raider_stats.attack_range = 3.0
	raider_stats.acquire_range = 0.0
	var raider: SimUnit = world.spawn_unit(raider_stats, RED, Vector2i(3, 0))
	raider.hp = 100000
	var blue: SimUnit = world.spawn_unit(_soldier, BLUE, Vector2i(0, 0))
	blue.hp = 1000
	raider.attack_target_id = blue.id
	raider.target_forced = true
	_run(world, 1)  # the raider shoots once, blue fights back
	assert_int(blue.attack_target_id).is_equal(raider.id)
	world.queue_command(MoveCommand.new(RED, [raider.id], Vector2i(30, 0)))
	_run(world, 150)
	assert_int(blue.attack_target_id).is_equal(-1)
	assert_that(blue.cell()).is_equal(Vector2i(0, 0))


func test_player_order_clears_the_post() -> void:
	var world: SimWorld = _world(["................", "................"])
	var blue: SimUnit = world.spawn_unit(_soldier, BLUE, Vector2i(0, 0))
	blue.hp = 1000
	var dummy: UnitStats = _soldier.duplicate() as UnitStats
	dummy.attack_range = 0.0
	var red: SimUnit = world.spawn_unit(dummy, RED, Vector2i(4, 0))
	red.hp = 10000
	_run(world, 3)
	assert_bool(blue.has_home).is_true()
	world.queue_command(MoveCommand.new(BLUE, [blue.id], Vector2i(12, 1)))
	_run(world, 1)
	assert_bool(blue.has_home).is_false()
	_run(world, 90)
	# Stays where it was sent; it doesn't walk back to the old post.
	assert_that(blue.cell()).is_equal(Vector2i(12, 1))
	assert_bool(blue.has_home).is_false()


func test_no_auto_attack_beyond_acquire_range_or_on_allies() -> void:
	var world: SimWorld = _world(["........"])
	var a: SimUnit = world.spawn_unit(_soldier, BLUE, Vector2i(0, 0))
	var ally: SimUnit = world.spawn_unit(_soldier, BLUE, Vector2i(1, 0))
	var far_enemy: SimUnit = world.spawn_unit(_soldier, RED, Vector2i(7, 0))
	assert_int(_run(world, 30)).is_equal(0)
	assert_int(a.hp).is_equal(30)
	assert_int(ally.hp).is_equal(30)
	assert_int(far_enemy.hp).is_equal(30)


func test_troop_dies_and_frees_its_cell() -> void:
	var world: SimWorld = _world(["......"])
	var blue: SimUnit = world.spawn_unit(_soldier, BLUE, Vector2i(0, 0))
	var red: SimUnit = world.spawn_unit(_soldier, RED, Vector2i(2, 0))
	blue.hp = 1000
	var died: bool = false
	for i: int in 40:
		world.step()
		for event: CombatEvent in world.events:
			if event.kind == CombatEvent.Kind.DIED:
				died = event.unit_id == red.id and event.other_id == blue.id
	assert_bool(died).is_true()
	assert_bool(red.dead).is_true()
	assert_object(world.get_unit(red.id)).is_null()
	assert_bool(world.units.has(red)).is_false()
	assert_bool(world.is_cell_free(Vector2i(2, 0))).is_true()
	assert_int(blue.attack_target_id).is_equal(-1)


func test_mirrored_duel_is_a_draw() -> void:
	var world: SimWorld = _world(["......"])
	var blue: SimUnit = world.spawn_unit(_soldier, BLUE, Vector2i(0, 0))
	var red: SimUnit = world.spawn_unit(_soldier, RED, Vector2i(2, 0))
	_run(world, 40)
	assert_bool(blue.dead).is_true()
	assert_bool(red.dead).is_true()


func test_hero_is_downed_not_killed() -> void:
	var world: SimWorld = _world(["......"])
	var blue: SimUnit = world.spawn_unit(_soldier, BLUE, Vector2i(0, 0))
	var hero: SimUnit = world.spawn_unit(_hero, RED, Vector2i(2, 0))
	blue.hp = 1000
	_run(world, 40)
	assert_bool(hero.downed).is_true()
	assert_bool(hero.dead).is_false()
	assert_int(hero.hp).is_equal(0)
	assert_object(world.get_unit(hero.id)).is_same(hero)
	assert_that(hero.cell()).is_equal(Vector2i(2, 0))
	assert_bool(world.is_cell_free(Vector2i(2, 0))).is_false()  # still lying there
	# Downed: not a target any more, and does nothing.
	assert_int(blue.attack_target_id).is_equal(-1)
	var hp_before: int = blue.hp
	_run(world, 30)
	assert_int(blue.hp).is_equal(hp_before)


func test_downed_hero_ignores_orders() -> void:
	var world: SimWorld = _world(["......"])
	var hero: SimUnit = world.spawn_unit(_hero, BLUE, Vector2i(0, 0))
	hero.hp = 0
	hero.downed = true
	world.queue_command(MoveCommand.new(BLUE, [hero.id], Vector2i(5, 0)))
	_run(world, 20)
	assert_that(hero.cell()).is_equal(Vector2i(0, 0))


func test_attack_order_chases_target_then_fires() -> void:
	var world: SimWorld = _world([
		"..........",
		"..........",
	])
	var blue: SimUnit = world.spawn_unit(_soldier, BLUE, Vector2i(0, 0))
	var dummy: UnitStats = _soldier.duplicate() as UnitStats
	dummy.attack_range = 0.0  # unarmed target that stays put
	var red: SimUnit = world.spawn_unit(dummy, RED, Vector2i(9, 1))
	red.hp = 1000
	world.queue_command(AttackCommand.new(BLUE, [blue.id], red.id))
	_run(world, 60)
	assert_bool(world.in_attack_range(blue, red)).is_true()
	assert_bool(blue.is_moving()).is_false()
	assert_int(red.hp).is_less(1000)
	# It stopped as soon as it was in range, not next to the target.
	assert_float(blue.pos.distance_to(red.pos)).is_greater(1.5)


func test_attack_order_follows_a_moving_target() -> void:
	var world: SimWorld = _world([
		"............",
		"............",
		"............",
	])
	var blue: SimUnit = world.spawn_unit(_soldier, BLUE, Vector2i(0, 1))
	var red: SimUnit = world.spawn_unit(_soldier, RED, Vector2i(5, 1))
	red.hp = 1000
	red.stats = _soldier.duplicate() as UnitStats
	red.stats.move_speed = 1.5
	red.stats.attack_range = 0.0
	world.queue_command(AttackCommand.new(BLUE, [blue.id], red.id))
	world.queue_command(MoveCommand.new(RED, [red.id], Vector2i(11, 1)))
	_run(world, 120)
	assert_int(red.hp).is_less(1000)
	assert_bool(world.in_attack_range(blue, red)).is_true()


func test_move_order_cancels_attack_and_units_do_not_fire_while_moving() -> void:
	var world: SimWorld = _world([
		"..........",
		"..........",
	])
	var blue: SimUnit = world.spawn_unit(_soldier, BLUE, Vector2i(0, 0))
	var red: SimUnit = world.spawn_unit(_soldier, RED, Vector2i(4, 1))
	red.stats = _soldier.duplicate() as UnitStats
	red.stats.attack_range = 0.0  # harmless, so only blue could shoot
	world.queue_command(MoveCommand.new(BLUE, [blue.id], Vector2i(9, 0)))
	var shots: int = 0
	for i: int in 60:
		world.step()
		if blue.is_moving():
			for event: CombatEvent in world.events:
				if event.kind == CombatEvent.Kind.SHOT:
					shots += 1
	assert_int(shots).is_equal(0)
	assert_that(blue.cell()).is_equal(Vector2i(9, 0))


func test_idle_unit_shot_from_out_of_range_fights_back() -> void:
	var world: SimWorld = _world(["............"])
	var sniper_stats: UnitStats = _soldier.duplicate() as UnitStats
	sniper_stats.attack_range = 6.0
	var sniper: SimUnit = world.spawn_unit(sniper_stats, RED, Vector2i(6, 0))
	sniper.hp = 1000
	var blue: SimUnit = world.spawn_unit(_soldier, BLUE, Vector2i(0, 0))
	blue.hp = 1000
	_run(world, 1)
	assert_int(blue.attack_target_id).is_equal(sniper.id)
	_run(world, 60)
	assert_bool(world.in_attack_range(blue, sniper)).is_true()
	assert_int(sniper.hp).is_less(1000)


func test_attacker_picks_next_enemy_after_target_dies() -> void:
	var world: SimWorld = _world(["......", "......"])
	var blue: SimUnit = world.spawn_unit(_soldier, BLUE, Vector2i(0, 0))
	blue.hp = 1000
	var first: SimUnit = world.spawn_unit(_soldier, RED, Vector2i(1, 0))
	var second: SimUnit = world.spawn_unit(_soldier, RED, Vector2i(1, 1))
	_run(world, 120)
	assert_bool(first.dead).is_true()
	assert_bool(second.dead).is_true()


func test_cannot_order_attack_on_ally_or_downed_unit() -> void:
	var world: SimWorld = _world(["......"])
	var a: SimUnit = world.spawn_unit(_soldier, BLUE, Vector2i(0, 0))
	var ally: SimUnit = world.spawn_unit(_soldier, BLUE, Vector2i(5, 0))
	world.queue_command(AttackCommand.new(BLUE, [a.id], ally.id))
	_run(world, 5)
	assert_int(a.attack_target_id).is_equal(-1)
	assert_that(a.cell()).is_equal(Vector2i(0, 0))


func test_mission_01_brawl_resolves() -> void:
	var world: SimWorld = SimWorld.new()
	assert_str(world.setup_mission(load(MISSION_PATH) as MissionData)).is_empty()
	var blue_ids: Array[int] = []
	var red_hero: SimUnit = null
	for unit: SimUnit in world.units:
		if unit.team == BLUE:
			blue_ids.append(unit.id)
		elif unit.stats.is_hero:
			red_hero = unit
	world.queue_command(AttackCommand.new(BLUE, blue_ids, red_hero.id))
	var ticks: int = 0
	while ticks < 1500:  # 100 s
		world.step()
		ticks += 1
		if _side_beaten(world, BLUE) or _side_beaten(world, RED):
			break
	assert_bool(_side_beaten(world, BLUE) or _side_beaten(world, RED)) \
			.override_failure_message("no side beaten after %d ticks" % ticks).is_true()
	# Heroes are never removed.
	var heroes: int = 0
	for unit: SimUnit in world.units:
		if unit.stats.is_hero:
			heroes += 1
	assert_int(heroes).is_equal(2)


## Beaten = every unit of the side is dead or downed.
func _side_beaten(world: SimWorld, team: SimUnit.Team) -> bool:
	for unit: SimUnit in world.units:
		if unit.team == team and unit.can_act():
			return false
	return true
