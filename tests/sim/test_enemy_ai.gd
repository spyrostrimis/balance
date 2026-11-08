extends GdUnitTestSuite
## Enemy AI: advances to the rock, focus-fires, uses the hero's ability, pulls the
## hero back at low HP, and plays Mission 1 to an end.

const BLUE: SimUnit.Team = SimUnit.Team.BLUE
const RED: SimUnit.Team = SimUnit.Team.RED
const TPS: int = SimWorld.TICKS_PER_SECOND
const MISSION_PATH: String = "res://data/missions/mission_01.tres"

var _soldier: UnitStats
var _rules: AiRules


func before_test() -> void:
	_soldier = UnitStats.new()
	_soldier.id = &"test_soldier"
	_soldier.move_speed = 3.0
	_soldier.max_hp = 100
	_soldier.attack_damage = 10
	_soldier.attack_range = 2.5
	_soldier.attack_cooldown = 1.0
	_soldier.acquire_range = 3.0
	_rules = AiRules.new()
	_rules.start_delay_seconds = 0.0
	_rules.think_seconds = 0.2


func _hero_stats(abilities: Array[AbilityStats]) -> UnitStats:
	var stats: UnitStats = _soldier.duplicate() as UnitStats
	stats.id = &"test_hero"
	stats.is_hero = true
	stats.max_hp = 400
	stats.abilities = abilities
	return stats


## 16x16, rock at (7..8, 7..8), zone radius 2; Red starts top-right.
func _world() -> SimWorld:
	var rows: Array[String] = []
	for y: int in 16:
		var row: String = ""
		for x: int in 16:
			if (x == 7 or x == 8) and (y == 7 or y == 8):
				row += "O"
			elif x >= 14 and y <= 1:
				row += "R"
			elif x <= 1 and y >= 14:
				row += "B"
			else:
				row += "."
		rows.append(row)
	var world: SimWorld = SimWorld.new()
	assert_str(world.load_map_rows(PackedStringArray(rows))).is_empty()
	var obj_rules: ObjectiveRules = ObjectiveRules.new()
	world.objective = CaptureObjective.new(world.grid, world.grid.deposits[0], obj_rules)
	world.ai.append(EnemyAi.new(RED, _rules))
	return world


func _run(world: SimWorld, ticks: int) -> Array[CombatEvent]:
	var seen: Array[CombatEvent] = []
	for i: int in ticks:
		world.step()
		seen.append_array(world.events)
	return seen


func test_waits_for_the_start_delay() -> void:
	var world: SimWorld = _world()
	_rules.start_delay_seconds = 2.0
	var red: SimUnit = world.spawn_unit(_soldier, RED, Vector2i(14, 0))
	_run(world, 2 * TPS - 2)
	assert_bool(red.is_moving()).is_false()
	_run(world, 3)
	assert_bool(red.is_moving()).is_true()


func test_army_advances_into_the_zone() -> void:
	var world: SimWorld = _world()
	var red: Array[SimUnit] = []
	for cell: Vector2i in world.grid.red_spawns:
		red.append(world.spawn_unit(_soldier, RED, cell))
	_run(world, 10 * TPS)
	for unit: SimUnit in red:
		assert_bool(world.objective.is_in_zone(unit.cell())).override_failure_message(
				"unit at %s not in the zone" % unit.cell()).is_true()


func test_focus_fire_on_the_weakest_enemy() -> void:
	var world: SimWorld = _world()
	var red: Array[SimUnit] = []
	for cell: Vector2i in [Vector2i(9, 5), Vector2i(10, 5), Vector2i(11, 5)]:
		red.append(world.spawn_unit(_soldier, RED, cell))
	var dummy: UnitStats = _soldier.duplicate() as UnitStats
	dummy.attack_range = 0.0
	dummy.attack_damage = 0
	var strong: SimUnit = world.spawn_unit(dummy, BLUE, Vector2i(9, 2))
	var weak: SimUnit = world.spawn_unit(dummy, BLUE, Vector2i(12, 2))
	strong.hp = 100000
	weak.hp = 40
	_run(world, 2)
	for unit: SimUnit in red:
		assert_int(unit.attack_target_id).is_equal(weak.id)
	_run(world, 6 * TPS)
	assert_bool(weak.dead).is_true()
	# Then it re-picks the next one.
	for unit: SimUnit in red:
		assert_int(unit.attack_target_id).is_equal(strong.id)


func test_focus_ignores_enemies_far_from_rock_and_army() -> void:
	var world: SimWorld = _world()
	var red: SimUnit = world.spawn_unit(_soldier, RED, Vector2i(14, 0))
	var far_blue: SimUnit = world.spawn_unit(_soldier, BLUE, Vector2i(0, 15))
	_run(world, 2)
	assert_int(red.attack_target_id).is_not_equal(far_blue.id)
	assert_bool(red.is_moving()).is_true()  # heading for the rock instead


func test_hero_uses_damage_ability_on_the_biggest_cluster() -> void:
	var world: SimWorld = _world()
	var cannon: AbilityStats = AbilityStats.new()
	cannon.kind = AbilityStats.Kind.ACTIVE
	cannon.effect = AbilityStats.Effect.DAMAGE
	cannon.target = AbilityStats.Target.ENEMY
	cannon.amount = 50.0
	cannon.cast_range = 6.0
	cannon.cooldown = 30.0
	cannon.splash_radius = 1.5
	cannon.splash_fraction = 0.5
	var abilities: Array[AbilityStats] = [cannon]
	var hero: SimUnit = world.spawn_unit(_hero_stats(abilities), RED, Vector2i(10, 2))
	var dummy: UnitStats = _soldier.duplicate() as UnitStats
	dummy.attack_range = 0.0
	dummy.attack_damage = 0
	var lone: SimUnit = world.spawn_unit(dummy, BLUE, Vector2i(12, 4))
	lone.hp = 10  # weakest, but alone
	var pack: Array[SimUnit] = []
	for cell: Vector2i in [Vector2i(6, 2), Vector2i(6, 3), Vector2i(5, 2)]:
		pack.append(world.spawn_unit(dummy, BLUE, cell))
	var events: Array[CombatEvent] = _run(world, 3)
	var cast_on: int = -1
	for event: CombatEvent in events:
		if event.kind == CombatEvent.Kind.ABILITY:
			cast_on = event.other_id
	assert_int(cast_on).is_equal(pack[0].id)  # the one with two neighbours in splash
	assert_bool(hero.ability_ready(0)).is_false()


func test_hero_pulls_back_below_retreat_hp_and_stays_back() -> void:
	var world: SimWorld = _world()
	var no_abilities: Array[AbilityStats] = []
	var hero: SimUnit = world.spawn_unit(_hero_stats(no_abilities), RED, Vector2i(8, 5))
	var troop: SimUnit = world.spawn_unit(_soldier, RED, Vector2i(9, 5))
	var dummy: UnitStats = _soldier.duplicate() as UnitStats
	dummy.attack_range = 0.0
	dummy.attack_damage = 0
	var enemy: SimUnit = world.spawn_unit(dummy, BLUE, Vector2i(8, 3))
	enemy.hp = 100000
	_run(world, 2)
	assert_int(hero.attack_target_id).is_equal(enemy.id)
	hero.hp = 99  # below 25% of 400
	_run(world, 4)
	assert_bool(world.ai[0].retreating.get(hero.id, false)).is_true()
	_run(world, 10 * TPS)
	assert_float(hero.pos.distance_to(SimUnit.cell_center(world.grid.red_spawns[0]))).is_less_equal(2.0)
	assert_int(troop.attack_target_id).is_equal(enemy.id)  # the troops keep fighting
	# Healthy again (e.g. back from recovery): rejoins.
	hero.hp = 400
	_run(world, 4)
	assert_bool(world.ai[0].retreating.get(hero.id, false)).is_false()


func test_ai_only_gives_orders_to_its_own_team() -> void:
	var world: SimWorld = _world()
	var blue: SimUnit = world.spawn_unit(_soldier, BLUE, Vector2i(0, 15))
	world.spawn_unit(_soldier, RED, Vector2i(14, 0))
	_run(world, 3 * TPS)
	assert_that(blue.cell()).is_equal(Vector2i(0, 15))


func test_mission_01_ai_takes_the_rock_from_a_passive_player() -> void:
	var world: SimWorld = SimWorld.new()
	assert_str(world.setup_mission(load(MISSION_PATH) as MissionData)).is_empty()
	var ticks: int = 0
	while world.outcome == SimWorld.Outcome.NONE and ticks < 120 * TPS:
		world.step()
		ticks += 1
	assert_int(world.outcome).is_equal(SimWorld.Outcome.DEFEAT)
	assert_int(world.outcome_reason).is_equal(SimWorld.Reason.ROCK_HELD)
	assert_int(world.objective.owner_team).is_equal(RED)


func test_mission_01_plays_to_an_end_when_blue_contests() -> void:
	var world: SimWorld = SimWorld.new()
	assert_str(world.setup_mission(load(MISSION_PATH) as MissionData)).is_empty()
	var blue_ids: Array[int] = []
	for unit: SimUnit in world.units:
		if unit.team == BLUE:
			blue_ids.append(unit.id)
	var c: Vector2 = world.objective.center()
	world.queue_command(MoveCommand.new(BLUE, blue_ids, Vector2i(floori(c.x) - 1, floori(c.y) + 2)))
	var ticks: int = 0
	while world.outcome == SimWorld.Outcome.NONE and ticks < 300 * TPS:
		world.step()
		ticks += 1
	assert_int(world.outcome).override_failure_message("no result after %d ticks" % ticks) \
			.is_not_equal(SimWorld.Outcome.NONE)


func test_desert_mission_you_play_red_against_blue_ai() -> void:
	var data: MissionData = load("res://data/missions/mission_01_desert.tres") as MissionData
	assert_int(data.player_team).is_equal(RED)
	assert_str(String(data.look)).is_equal("desert")
	var world: SimWorld = SimWorld.new()
	assert_str(world.setup_mission(data)).is_empty()
	assert_int(world.ai.size()).is_equal(1)
	assert_int(world.ai[0].team).is_equal(BLUE)
	# A passive Red player loses the rock to Blue's AI.
	var ticks: int = 0
	while world.outcome == SimWorld.Outcome.NONE and ticks < 120 * TPS:
		world.step()
		ticks += 1
	assert_int(world.outcome).is_equal(SimWorld.Outcome.DEFEAT)
	assert_int(world.objective.owner_team).is_equal(BLUE)


func test_blue_ai_hero_repairs_a_damaged_ally() -> void:
	var world: SimWorld = _world()
	world.ai.clear()
	world.ai.append(EnemyAi.new(BLUE, _rules))
	var repair: AbilityStats = load("res://data/abilities/repair.tres") as AbilityStats
	var abilities: Array[AbilityStats] = [repair]
	var hero: SimUnit = world.spawn_unit(_hero_stats(abilities), BLUE, Vector2i(2, 13))
	var hurt: SimUnit = world.spawn_unit(_soldier, BLUE, Vector2i(4, 13))
	hurt.hp = 20
	_run(world, 3)
	assert_int(hurt.hp).is_greater(20)
	assert_bool(hero.ability_ready(0)).is_false()
