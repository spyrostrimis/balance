extends GdUnitTestSuite
## The hero rule: player's hero downed = mission failed; a downed AI hero is
## fetched by an untargetable, unblockable recovery unit, carried off the map,
## and returns at its start area after a delay with full HP and abilities ready.

const BLUE: SimUnit.Team = SimUnit.Team.BLUE
const RED: SimUnit.Team = SimUnit.Team.RED
const TPS: int = SimWorld.TICKS_PER_SECOND

var _soldier: UnitStats
var _hero: UnitStats


func before_test() -> void:
	_soldier = UnitStats.new()
	_soldier.id = &"test_soldier"
	_soldier.move_speed = 3.0
	_soldier.max_hp = 100
	_soldier.attack_damage = 10
	_soldier.attack_range = 2.0
	_soldier.attack_cooldown = 1.0
	_soldier.acquire_range = 3.0
	_hero = _soldier.duplicate() as UnitStats
	_hero.id = &"test_hero"
	_hero.is_hero = true
	_hero.max_hp = 200
	var heal: AbilityStats = AbilityStats.new()
	heal.kind = AbilityStats.Kind.ACTIVE
	heal.effect = AbilityStats.Effect.HEAL
	heal.amount = 10.0
	heal.cooldown = 30.0
	var abilities: Array[AbilityStats] = [heal]
	_hero.abilities = abilities


## 12x8 open map, Red's start area top-right.
func _world() -> SimWorld:
	var world: SimWorld = SimWorld.new()
	assert_str(world.load_map_rows(PackedStringArray([
		"..........RR",
		"..........RR",
		"............",
		"............",
		"............",
		"............",
		"BB..........",
		"BB..........",
	]))).is_empty()
	world.rules = HeroRules.new()
	world.rules.recovery_speed = 6.0
	world.rules.recovery_load_seconds = 2.0
	world.rules.return_seconds = 4.0
	return world


func _run(world: SimWorld, ticks: int) -> Array[CombatEvent]:
	var seen: Array[CombatEvent] = []
	for i: int in ticks:
		world.step()
		seen.append_array(world.events)
	return seen


func _find(events: Array[CombatEvent], kind: CombatEvent.Kind) -> Array[CombatEvent]:
	var found: Array[CombatEvent] = []
	for event: CombatEvent in events:
		if event.kind == kind:
			found.append(event)
	return found


## Downs `hero` with one shot from a Blue soldier next to it.
func _down_by_shot(world: SimWorld, hero: SimUnit) -> SimUnit:
	hero.hp = 5
	var shooter: SimUnit = world.spawn_unit(_soldier, BLUE if hero.team == RED else RED,
			hero.cell() + Vector2i(-1, 0))
	shooter.hp = 100000
	return shooter


func test_player_hero_down_fails_the_mission() -> void:
	var world: SimWorld = _world()
	var hero: SimUnit = world.spawn_unit(_hero, BLUE, Vector2i(5, 4))
	_down_by_shot(world, hero)
	var events: Array[CombatEvent] = _run(world, 3)
	assert_bool(hero.downed).is_true()
	assert_int(world.outcome).is_equal(SimWorld.Outcome.DEFEAT)
	assert_int(_find(events, CombatEvent.Kind.MISSION_FAILED).size()).is_equal(1)
	assert_int(world.recoveries.size()).is_equal(0)  # the player's hero isn't recovered


func test_ai_hero_down_sends_a_recovery_unit_not_a_unit() -> void:
	var world: SimWorld = _world()
	var hero: SimUnit = world.spawn_unit(_hero, RED, Vector2i(5, 4))
	_down_by_shot(world, hero)
	var events: Array[CombatEvent] = _run(world, 1)
	assert_int(world.outcome).is_equal(SimWorld.Outcome.NONE)
	assert_int(_find(events, CombatEvent.Kind.RECOVERY_SENT).size()).is_equal(1)
	assert_int(world.recoveries.size()).is_equal(1)
	var recovery: SimRecovery = world.recoveries[0]
	# It comes from beyond the map edge on Red's side (north-east).
	assert_bool(Rect2(Vector2.ZERO, Vector2(world.grid.size())).has_point(recovery.pos)).is_false()
	assert_float(recovery.pos.x).is_greater(6.0)
	assert_float(recovery.pos.y).is_less(4.0)
	# Not a unit: nobody can target or block it.
	for unit: SimUnit in world.units:
		assert_bool(unit.pos.is_equal_approx(recovery.pos)).is_false()


func test_recovery_loads_carries_off_and_hero_returns_ready() -> void:
	var world: SimWorld = _world()
	var hero: SimUnit = world.spawn_unit(_hero, RED, Vector2i(5, 4))
	hero.ability_cooldowns[0] = 999
	var shooter: SimUnit = _down_by_shot(world, hero)
	_run(world, 1)
	assert_bool(hero.downed).is_true()
	var recovery: SimRecovery = world.recoveries[0]
	var all: Array[CombatEvent] = []
	var ticks: int = 0
	while recovery.state == SimRecovery.State.INBOUND and ticks < 200:
		all.append_array(_run(world, 1))
		ticks += 1
	assert_int(recovery.state).is_equal(SimRecovery.State.LOADING)
	assert_bool(recovery.pos.is_equal_approx(hero.pos)).is_true()
	assert_bool(world.is_cell_free(Vector2i(5, 4))).is_false()  # still lying there while loading
	all.append_array(_run(world, 2 * TPS))
	assert_int(_find(all, CombatEvent.Kind.HERO_LOADED).size()).is_equal(1)
	assert_bool(hero.carried).is_true()
	assert_bool(world.is_cell_free(Vector2i(5, 4))).is_true()  # picked up: cell free
	ticks = 0
	while not hero.away and ticks < 200:
		all.append_array(_run(world, 1))
		ticks += 1
	assert_bool(hero.away).is_true()
	assert_int(world.recoveries.size()).is_equal(0)
	var away: Array[CombatEvent] = _find(all, CombatEvent.Kind.HERO_AWAY)
	assert_int(away.size()).is_equal(1)
	assert_int(away[0].amount).is_equal(4 * TPS)
	# Nobody can hurt or order it while away.
	shooter.attack_target_id = hero.id
	all.append_array(_run(world, 4 * TPS - 1))
	assert_bool(hero.away).is_true()
	all.append_array(_run(world, 1))
	assert_int(_find(all, CombatEvent.Kind.HERO_RETURNED).size()).is_equal(1)
	assert_bool(hero.away).is_false()
	assert_bool(hero.downed).is_false()
	assert_bool(hero.can_act()).is_true()
	assert_int(hero.hp).is_equal(200)
	assert_bool(hero.ability_ready(0)).is_true()
	assert_that(hero.cell()).is_equal(world.grid.red_spawns[0])
	assert_bool(world.is_cell_free(hero.cell())).is_false()


func test_recovery_cannot_be_blocked() -> void:
	var world: SimWorld = _world()
	var hero: SimUnit = world.spawn_unit(_hero, RED, Vector2i(5, 4))
	hero.hp = 0
	hero.downed = true
	# Surround the hero with Blue units.
	for offset: Vector2i in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0),
			Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]:
		var guard: SimUnit = world.spawn_unit(_soldier, BLUE, hero.cell() + offset)
		guard.hp = 100000
	world.call("_on_hero_downed", hero)
	var events: Array[CombatEvent] = _run(world, 8 * TPS)
	assert_int(_find(events, CombatEvent.Kind.HERO_LOADED).size()).is_equal(1)
	assert_int(_find(events, CombatEvent.Kind.HERO_AWAY).size()).is_equal(1)


func test_returning_hero_takes_the_nearest_free_cell() -> void:
	var world: SimWorld = _world()
	var hero: SimUnit = world.spawn_unit(_hero, RED, Vector2i(5, 4))
	for cell: Vector2i in world.grid.red_spawns:
		world.spawn_unit(_soldier, RED, cell)
	hero.hp = 0
	hero.downed = true
	world.call("_on_hero_downed", hero)
	var events: Array[CombatEvent] = _run(world, 12 * TPS)
	assert_int(_find(events, CombatEvent.Kind.HERO_RETURNED).size()).is_equal(1)
	assert_bool(world.grid.red_spawns.has(hero.cell())).is_false()
	assert_float(Vector2(hero.cell() - world.grid.red_spawns[0]).length()).is_less_equal(2.0)


func test_mission_01_rules() -> void:
	var data: MissionData = load("res://data/missions/mission_01.tres") as MissionData
	assert_int(data.player_team).is_equal(BLUE)
	assert_object(data.hero_rules).is_not_null()
	assert_float(data.hero_rules.low_hp_warning_fraction).is_equal_approx(0.3, 0.0001)
	assert_float(data.hero_rules.return_seconds).is_equal_approx(60.0, 0.0001)
	assert_float(data.hero_rules.return_hp_fraction).is_equal_approx(1.0, 0.0001)
	var world: SimWorld = SimWorld.new()
	assert_str(world.setup_mission(data)).is_empty()
	assert_object(world.rules).is_same(data.hero_rules)
