extends GdUnitTestSuite
## Mission objective and outcomes: strict-hold capture of the rock, hero-down
## defeat, enemy-routed victory.

const BLUE: SimUnit.Team = SimUnit.Team.BLUE
const RED: SimUnit.Team = SimUnit.Team.RED
const TPS: int = SimWorld.TICKS_PER_SECOND

var _dummy: UnitStats
var _hero: UnitStats


func before_test() -> void:
	_dummy = UnitStats.new()
	_dummy.id = &"test_dummy"
	_dummy.max_hp = 100
	_dummy.attack_range = 0.0  # harmless: these tests are about standing in the zone
	_dummy.attack_damage = 0
	_hero = _dummy.duplicate() as UnitStats
	_hero.is_hero = true


## 12x12, rock at (5..6, 5..6), zone radius 1 → x/y 4..7. Capture 2 s, hold 4 s.
func _world() -> SimWorld:
	var world: SimWorld = SimWorld.new()
	assert_str(world.load_map_rows(PackedStringArray([
		"..........RR",
		"..........RR",
		"............",
		"............",
		"............",
		".....OO.....",
		".....OO.....",
		"............",
		"............",
		"............",
		"BB..........",
		"BB..........",
	]))).is_empty()
	var rules: ObjectiveRules = ObjectiveRules.new()
	rules.zone_radius = 1
	rules.capture_seconds = 2.0
	rules.hold_seconds = 4.0
	world.objective = CaptureObjective.new(world.grid, world.grid.deposits[0], rules)
	# Keep a hero per side far away so nobody is "routed".
	world.spawn_unit(_hero, BLUE, Vector2i(0, 11))
	world.spawn_unit(_hero, RED, Vector2i(11, 0))
	return world


func _run(world: SimWorld, ticks: int) -> Array[CombatEvent]:
	var seen: Array[CombatEvent] = []
	for i: int in ticks:
		world.step()
		seen.append_array(world.events)
	return seen


func _count(events: Array[CombatEvent], kind: CombatEvent.Kind) -> int:
	var n: int = 0
	for event: CombatEvent in events:
		if event.kind == kind:
			n += 1
	return n


func test_zone_is_the_open_ring_around_the_rock() -> void:
	var world: SimWorld = _world()
	assert_int(world.objective.zone.size()).is_equal(16 - 4)  # 4x4 minus the 2x2 rock
	assert_bool(world.objective.is_in_zone(Vector2i(4, 4))).is_true()
	assert_bool(world.objective.is_in_zone(Vector2i(5, 5))).is_false()  # the rock itself
	assert_bool(world.objective.is_in_zone(Vector2i(3, 4))).is_false()


func test_mission_01_zone_is_within_two_cells_of_the_rock() -> void:
	var world: SimWorld = SimWorld.new()
	assert_str(world.setup_mission(load("res://data/missions/mission_01.tres") as MissionData)).is_empty()
	var obj: CaptureObjective = world.objective
	assert_object(obj).is_not_null()
	assert_int(obj.rules.zone_radius).is_equal(2)
	assert_float(obj.rules.capture_seconds).is_equal_approx(10.0, 0.001)
	assert_float(obj.rules.hold_seconds).is_equal_approx(60.0, 0.001)
	for cell: Vector2i in obj.zone:
		assert_bool(world.grid.is_passable(cell)).is_true()
		var dx: int = maxi(obj.rock.position.x - cell.x, cell.x - (obj.rock.end.x - 1))
		var dy: int = maxi(obj.rock.position.y - cell.y, cell.y - (obj.rock.end.y - 1))
		assert_int(maxi(dx, dy)).is_less_equal(2)
	assert_int(world.ai.size()).is_equal(1)
	assert_int(world.ai[0].team).is_equal(RED)


func test_alone_in_the_zone_captures_after_capture_time() -> void:
	var world: SimWorld = _world()
	world.spawn_unit(_dummy, BLUE, Vector2i(4, 4))
	var events: Array[CombatEvent] = _run(world, 2 * TPS - 1)
	assert_int(world.objective.owner_team).is_equal(CaptureObjective.NO_TEAM)
	events.append_array(_run(world, 1))
	assert_int(world.objective.owner_team).is_equal(BLUE)
	assert_int(_count(events, CombatEvent.Kind.ROCK_CAPTURED)).is_equal(1)


func test_contested_zone_pauses_capture() -> void:
	var world: SimWorld = _world()
	world.spawn_unit(_dummy, BLUE, Vector2i(4, 4))
	_run(world, TPS)  # half way
	var red: SimUnit = world.spawn_unit(_dummy, RED, Vector2i(7, 7))
	_run(world, 3 * TPS)
	assert_int(world.objective.owner_team).is_equal(CaptureObjective.NO_TEAM)
	assert_int(world.objective.capture_ticks).is_equal(TPS)  # paused, not lost
	assert_bool(world.objective.contested()).is_true()
	world.call("_remove", red)
	_run(world, TPS)
	assert_int(world.objective.owner_team).is_equal(BLUE)


func test_leaving_the_zone_loses_capture_progress() -> void:
	var world: SimWorld = _world()
	var blue: SimUnit = world.spawn_unit(_dummy, BLUE, Vector2i(4, 4))
	_run(world, TPS)
	world.queue_command(MoveCommand.new(BLUE, [blue.id], Vector2i(1, 4)))
	_run(world, TPS)
	assert_int(world.objective.capture_ticks).is_equal(0)


func test_holding_without_enemies_wins() -> void:
	var world: SimWorld = _world()
	world.spawn_unit(_dummy, BLUE, Vector2i(4, 4))
	_run(world, 2 * TPS)
	assert_int(world.objective.owner_team).is_equal(BLUE)
	var events: Array[CombatEvent] = _run(world, 4 * TPS)
	assert_int(world.outcome).is_equal(SimWorld.Outcome.VICTORY)
	assert_int(world.outcome_reason).is_equal(SimWorld.Reason.ROCK_HELD)
	assert_int(_count(events, CombatEvent.Kind.MISSION_WON)).is_equal(1)


func test_owner_need_not_stay_in_the_zone() -> void:
	var world: SimWorld = _world()
	var blue: SimUnit = world.spawn_unit(_dummy, BLUE, Vector2i(4, 4))
	_run(world, 2 * TPS)
	world.queue_command(MoveCommand.new(BLUE, [blue.id], Vector2i(1, 4)))
	_run(world, 4 * TPS)
	assert_int(world.outcome).is_equal(SimWorld.Outcome.VICTORY)


func test_any_enemy_in_the_zone_resets_the_hold() -> void:
	var world: SimWorld = _world()
	world.spawn_unit(_dummy, BLUE, Vector2i(4, 4))
	_run(world, 2 * TPS + 3 * TPS)  # captured, then 3 of 4 s held
	assert_int(world.objective.hold_ticks).is_equal(3 * TPS)
	var red: SimUnit = world.spawn_unit(_dummy, RED, Vector2i(7, 7))
	_run(world, 1)
	assert_int(world.objective.hold_ticks).is_equal(0)
	world.call("_remove", red)
	_run(world, 3 * TPS)
	assert_int(world.outcome).is_equal(SimWorld.Outcome.NONE)  # had to start over
	_run(world, TPS)
	assert_int(world.outcome).is_equal(SimWorld.Outcome.VICTORY)


func test_enemy_holding_the_rock_is_a_defeat() -> void:
	var world: SimWorld = _world()
	world.spawn_unit(_dummy, RED, Vector2i(7, 7))
	_run(world, 6 * TPS)
	assert_int(world.objective.owner_team).is_equal(RED)
	assert_int(world.outcome).is_equal(SimWorld.Outcome.DEFEAT)
	assert_int(world.outcome_reason).is_equal(SimWorld.Reason.ROCK_HELD)


func test_enemy_can_take_the_rock_over() -> void:
	var world: SimWorld = _world()
	var blue: SimUnit = world.spawn_unit(_dummy, BLUE, Vector2i(4, 4))
	_run(world, 2 * TPS)
	world.call("_remove", blue)
	world.spawn_unit(_dummy, RED, Vector2i(7, 7))
	_run(world, 2 * TPS)
	assert_int(world.objective.owner_team).is_equal(RED)
	assert_int(world.objective.hold_ticks).is_less(TPS)


func test_downed_units_do_not_hold_or_contest() -> void:
	var world: SimWorld = _world()
	world.spawn_unit(_dummy, BLUE, Vector2i(4, 4))
	var red_hero: SimUnit = world.spawn_unit(_hero, RED, Vector2i(7, 7))
	red_hero.hp = 0
	red_hero.downed = true
	_run(world, 2 * TPS)
	assert_int(world.objective.owner_team).is_equal(BLUE)


func test_routing_the_enemy_wins() -> void:
	var world: SimWorld = SimWorld.new()
	assert_str(world.load_map_rows(PackedStringArray(["........"]))).is_empty()
	world.spawn_unit(_hero, BLUE, Vector2i(0, 0))
	var red_hero: SimUnit = world.spawn_unit(_hero, RED, Vector2i(7, 0))
	var red_troop: SimUnit = world.spawn_unit(_dummy, RED, Vector2i(5, 0))
	red_hero.hp = 0
	red_hero.downed = true
	_run(world, 2)
	assert_int(world.outcome).is_equal(SimWorld.Outcome.NONE)  # a troop still stands
	world.call("_remove", red_troop)
	var events: Array[CombatEvent] = _run(world, 1)
	assert_int(world.outcome).is_equal(SimWorld.Outcome.VICTORY)
	assert_int(world.outcome_reason).is_equal(SimWorld.Reason.ENEMY_ROUTED)
	assert_int(_count(events, CombatEvent.Kind.MISSION_WON)).is_equal(1)


func test_losing_all_troops_is_not_a_defeat() -> void:
	var world: SimWorld = SimWorld.new()
	assert_str(world.load_map_rows(PackedStringArray(["........"]))).is_empty()
	world.spawn_unit(_hero, BLUE, Vector2i(0, 0))
	world.spawn_unit(_hero, RED, Vector2i(7, 0))
	_run(world, 5)
	assert_int(world.outcome).is_equal(SimWorld.Outcome.NONE)


func test_player_hero_down_is_a_defeat_with_reason() -> void:
	var world: SimWorld = _world()
	var blue_hero: SimUnit = world.units[0]
	world.call("_down", blue_hero)
	world.call("_on_hero_downed", blue_hero)
	assert_int(world.outcome).is_equal(SimWorld.Outcome.DEFEAT)
	assert_int(world.outcome_reason).is_equal(SimWorld.Reason.HERO_DOWN)
	# Later results don't change it.
	world.call("_end", SimWorld.Outcome.VICTORY, SimWorld.Reason.ROCK_HELD, -1)
	assert_int(world.outcome).is_equal(SimWorld.Outcome.DEFEAT)
