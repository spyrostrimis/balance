extends GdUnitTestSuite
## Hero abilities: active abilities (walk into range, use, cooldown), auras,
## downed heroes losing them, and the Mission 1 leaders' data.

const BLUE: SimUnit.Team = SimUnit.Team.BLUE
const RED: SimUnit.Team = SimUnit.Team.RED
const TPS: int = SimWorld.TICKS_PER_SECOND

var _soldier: UnitStats
var _unarmed: UnitStats
var _heal: AbilityStats
var _cannon: AbilityStats
var _bonus_aura: AbilityStats
var _shield_aura: AbilityStats


func before_test() -> void:
	_soldier = UnitStats.new()
	_soldier.id = &"test_soldier"
	_soldier.move_speed = 3.0
	_soldier.max_hp = 100
	_soldier.attack_damage = 10
	_soldier.attack_range = 2.0
	_soldier.attack_cooldown = 1.0
	_soldier.acquire_range = 3.0
	_unarmed = _soldier.duplicate() as UnitStats
	_unarmed.attack_range = 0.0
	_unarmed.attack_damage = 0

	_heal = AbilityStats.new()
	_heal.id = &"test_heal"
	_heal.kind = AbilityStats.Kind.ACTIVE
	_heal.effect = AbilityStats.Effect.HEAL
	_heal.target = AbilityStats.Target.ALLY
	_heal.amount = 50.0
	_heal.cast_range = 3.0
	_heal.cooldown = 2.0  # 30 ticks

	_cannon = AbilityStats.new()
	_cannon.id = &"test_cannon"
	_cannon.kind = AbilityStats.Kind.ACTIVE
	_cannon.effect = AbilityStats.Effect.DAMAGE
	_cannon.target = AbilityStats.Target.ENEMY
	_cannon.amount = 40.0
	_cannon.cast_range = 4.0
	_cannon.cooldown = 2.0
	_cannon.splash_radius = 1.0
	_cannon.splash_fraction = 0.5

	_bonus_aura = AbilityStats.new()
	_bonus_aura.kind = AbilityStats.Kind.AURA
	_bonus_aura.effect = AbilityStats.Effect.DAMAGE_BONUS
	_bonus_aura.amount = 0.1
	_bonus_aura.aura_radius = 3.0

	_shield_aura = AbilityStats.new()
	_shield_aura.kind = AbilityStats.Kind.AURA
	_shield_aura.effect = AbilityStats.Effect.DAMAGE_REDUCTION
	_shield_aura.amount = 0.2
	_shield_aura.aura_radius = 3.0


func _hero_with(abilities: Array[AbilityStats], armed: bool = false) -> UnitStats:
	var stats: UnitStats = (_soldier if armed else _unarmed).duplicate() as UnitStats
	stats.id = &"test_hero"
	stats.is_hero = true
	stats.abilities = abilities
	return stats


func _world(rows: Array[String]) -> SimWorld:
	var world: SimWorld = SimWorld.new()
	assert_str(world.load_map_rows(PackedStringArray(rows))).is_empty()
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


func test_heal_restores_hp_capped_and_starts_cooldown() -> void:
	var world: SimWorld = _world(["......"])
	var heal_list: Array[AbilityStats] = [_heal]
	var hero: SimUnit = world.spawn_unit(_hero_with(heal_list), BLUE, Vector2i(0, 0))
	var ally: SimUnit = world.spawn_unit(_unarmed, BLUE, Vector2i(2, 0))
	ally.hp = 70
	world.queue_command(AbilityCommand.new(BLUE, hero.id, 0, ally.id))
	var events: Array[CombatEvent] = _run(world, 1)
	assert_int(ally.hp).is_equal(100)  # 70 + 50, capped at 100
	assert_int(_count(events, CombatEvent.Kind.ABILITY)).is_equal(1)
	assert_int(events[0].amount).is_equal(30)
	assert_bool(hero.ability_ready(0)).is_false()
	assert_float(hero.ability_cooldown_fraction(0, TPS)).is_greater(0.9)
	# On cooldown: ignored.
	ally.hp = 10
	world.queue_command(AbilityCommand.new(BLUE, hero.id, 0, ally.id))
	_run(world, 5)
	assert_int(ally.hp).is_equal(10)
	assert_bool(hero.is_casting()).is_false()
	# Usable again exactly 30 ticks after use (tick 1 -> tick 31).
	_run(world, 24)
	assert_bool(hero.ability_ready(0)).is_false()
	world.queue_command(AbilityCommand.new(BLUE, hero.id, 0, ally.id))
	_run(world, 1)
	assert_int(ally.hp).is_equal(60)


func test_hero_can_heal_itself() -> void:
	var world: SimWorld = _world(["...."])
	var heal_list: Array[AbilityStats] = [_heal]
	var hero: SimUnit = world.spawn_unit(_hero_with(heal_list), BLUE, Vector2i(0, 0))
	hero.hp = 20
	world.queue_command(AbilityCommand.new(BLUE, hero.id, 0, hero.id))
	_run(world, 1)
	assert_int(hero.hp).is_equal(70)


func test_hero_walks_into_range_then_casts() -> void:
	var world: SimWorld = _world(["..........", ".........."])
	var heal_list: Array[AbilityStats] = [_heal]
	var hero: SimUnit = world.spawn_unit(_hero_with(heal_list), BLUE, Vector2i(0, 0))
	var ally: SimUnit = world.spawn_unit(_unarmed, BLUE, Vector2i(9, 1))
	ally.hp = 10
	world.queue_command(AbilityCommand.new(BLUE, hero.id, 0, ally.id))
	_run(world, 2)
	assert_int(ally.hp).is_equal(10)
	assert_bool(hero.is_moving()).is_true()
	_run(world, 60)
	assert_int(ally.hp).is_equal(60)
	assert_bool(hero.is_casting()).is_false()
	assert_float(hero.pos.distance_to(ally.pos)).is_less_equal(_heal.cast_range + 0.001)
	assert_float(hero.pos.distance_to(ally.pos)).is_greater(1.5)  # stopped once in range


func test_move_order_cancels_a_pending_cast() -> void:
	var world: SimWorld = _world(["..........", ".........."])
	var heal_list: Array[AbilityStats] = [_heal]
	var hero: SimUnit = world.spawn_unit(_hero_with(heal_list), BLUE, Vector2i(0, 0))
	var ally: SimUnit = world.spawn_unit(_unarmed, BLUE, Vector2i(9, 1))
	ally.hp = 10
	world.queue_command(AbilityCommand.new(BLUE, hero.id, 0, ally.id))
	_run(world, 3)
	world.queue_command(MoveCommand.new(BLUE, [hero.id], Vector2i(0, 1)))
	_run(world, 60)
	assert_int(ally.hp).is_equal(10)
	assert_bool(hero.is_casting()).is_false()
	assert_bool(hero.ability_ready(0)).is_true()  # not used, so no cooldown


func test_targets_must_match_the_ability() -> void:
	var world: SimWorld = _world(["......"])
	var both: Array[AbilityStats] = [_heal, _cannon]
	var hero: SimUnit = world.spawn_unit(_hero_with(both), BLUE, Vector2i(0, 0))
	var ally: SimUnit = world.spawn_unit(_unarmed, BLUE, Vector2i(1, 0))
	var enemy: SimUnit = world.spawn_unit(_unarmed, RED, Vector2i(3, 0))
	ally.hp = 50
	enemy.hp = 50
	world.queue_command(AbilityCommand.new(BLUE, hero.id, 0, enemy.id))  # heal an enemy
	world.queue_command(AbilityCommand.new(BLUE, hero.id, 1, ally.id))  # cannon an ally
	world.queue_command(AbilityCommand.new(RED, hero.id, 0, ally.id))  # wrong team
	world.queue_command(AbilityCommand.new(BLUE, hero.id, 7, ally.id))  # no such ability
	var events: Array[CombatEvent] = _run(world, 3)
	assert_int(_count(events, CombatEvent.Kind.ABILITY)).is_equal(0)
	assert_int(ally.hp).is_equal(50)
	assert_int(enemy.hp).is_equal(50)


func test_auras_cannot_be_cast() -> void:
	var world: SimWorld = _world(["...."])
	var aura_list: Array[AbilityStats] = [_bonus_aura]
	var hero: SimUnit = world.spawn_unit(_hero_with(aura_list), BLUE, Vector2i(0, 0))
	world.queue_command(AbilityCommand.new(BLUE, hero.id, 0, hero.id))
	_run(world, 1)
	assert_bool(hero.is_casting()).is_false()


func test_cannon_hits_target_and_splashes_enemies_only() -> void:
	var world: SimWorld = _world(["........", "........"])
	var cannon_list: Array[AbilityStats] = [_cannon]
	var hero: SimUnit = world.spawn_unit(_hero_with(cannon_list), RED, Vector2i(0, 0))
	var target: SimUnit = world.spawn_unit(_unarmed, BLUE, Vector2i(4, 0))
	var near: SimUnit = world.spawn_unit(_unarmed, BLUE, Vector2i(4, 1))  # 1 cell from target
	var far: SimUnit = world.spawn_unit(_unarmed, BLUE, Vector2i(6, 1))  # beyond splash
	var red_ally: SimUnit = world.spawn_unit(_unarmed, RED, Vector2i(5, 0))  # next to target
	world.queue_command(AbilityCommand.new(RED, hero.id, 0, target.id))
	var events: Array[CombatEvent] = _run(world, 1)
	assert_int(_count(events, CombatEvent.Kind.ABILITY)).is_equal(1)
	assert_int(target.hp).is_equal(60)
	assert_int(near.hp).is_equal(80)
	assert_int(far.hp).is_equal(100)
	assert_int(red_ally.hp).is_equal(100)


func test_cannon_needs_line_of_sight() -> void:
	var world: SimWorld = _world([
		"..#..",
		".....",
	])
	var cannon_list: Array[AbilityStats] = [_cannon]
	var hero: SimUnit = world.spawn_unit(_hero_with(cannon_list), RED, Vector2i(0, 0))
	var target: SimUnit = world.spawn_unit(_unarmed, BLUE, Vector2i(4, 0))
	world.queue_command(AbilityCommand.new(RED, hero.id, 0, target.id))
	var events: Array[CombatEvent] = _run(world, 1)
	assert_int(_count(events, CombatEvent.Kind.ABILITY)).is_equal(0)  # walks first
	events = _run(world, 40)
	assert_int(_count(events, CombatEvent.Kind.ABILITY)).is_equal(1)
	assert_int(target.hp).is_equal(60)


func test_cannon_can_kill() -> void:
	var world: SimWorld = _world(["......"])
	var cannon_list: Array[AbilityStats] = [_cannon]
	var hero: SimUnit = world.spawn_unit(_hero_with(cannon_list), RED, Vector2i(0, 0))
	var target: SimUnit = world.spawn_unit(_unarmed, BLUE, Vector2i(3, 0))
	target.hp = 30
	world.queue_command(AbilityCommand.new(RED, hero.id, 0, target.id))
	var events: Array[CombatEvent] = _run(world, 1)
	assert_int(_count(events, CombatEvent.Kind.DIED)).is_equal(1)
	assert_bool(target.dead).is_true()


func test_damage_bonus_aura_buffs_nearby_allies_only() -> void:
	var world: SimWorld = _world(["..........", ".........."])
	var aura_list: Array[AbilityStats] = [_bonus_aura]
	var hero: SimUnit = world.spawn_unit(_hero_with(aura_list, true), RED, Vector2i(0, 0))
	var near: SimUnit = world.spawn_unit(_soldier, RED, Vector2i(2, 0))
	var far: SimUnit = world.spawn_unit(_soldier, RED, Vector2i(9, 1))
	world.step()
	assert_float(near.aura_damage_bonus).is_equal_approx(0.1, 0.0001)
	assert_float(far.aura_damage_bonus).is_equal(0.0)
	assert_float(hero.aura_damage_bonus).is_equal(0.0)  # not the hero itself
	assert_int(SimWorld.final_damage(near, far, 10.0)).is_equal(11)
	assert_int(SimWorld.final_damage(far, near, 10.0)).is_equal(10)
	assert_int(SimWorld.final_damage(near, far, 24.0)).is_equal(26)  # 26.4 rounds down


func test_buffed_unit_deals_more_damage_in_combat() -> void:
	var world: SimWorld = _world(["......"])
	var aura_list: Array[AbilityStats] = [_bonus_aura]
	world.spawn_unit(_hero_with(aura_list), RED, Vector2i(5, 0))
	var red: SimUnit = world.spawn_unit(_soldier, RED, Vector2i(3, 0))
	var blue: SimUnit = world.spawn_unit(_soldier, BLUE, Vector2i(1, 0))
	red.hp = 1000
	blue.hp = 1000
	var events: Array[CombatEvent] = _run(world, 1)
	assert_int(blue.hp).is_equal(989)
	assert_int(red.hp).is_equal(990)
	for event: CombatEvent in events:
		if event.kind == CombatEvent.Kind.SHOT and event.unit_id == red.id:
			assert_int(event.amount).is_equal(11)


func test_damage_reduction_aura_protects_nearby_allies() -> void:
	var world: SimWorld = _world(["......"])
	var aura_list: Array[AbilityStats] = [_shield_aura]
	world.spawn_unit(_hero_with(aura_list), BLUE, Vector2i(0, 0))
	var blue: SimUnit = world.spawn_unit(_unarmed, BLUE, Vector2i(1, 0))
	var red: SimUnit = world.spawn_unit(_soldier, RED, Vector2i(3, 0))
	red.attack_target_id = blue.id
	red.target_forced = true
	_run(world, 1)
	assert_int(blue.hp).is_equal(92)  # 10 x 0.8


func test_downed_hero_loses_aura_and_cannot_cast() -> void:
	var world: SimWorld = _world(["......"])
	var abilities: Array[AbilityStats] = [_heal, _bonus_aura]
	var hero: SimUnit = world.spawn_unit(_hero_with(abilities), RED, Vector2i(0, 0))
	var near: SimUnit = world.spawn_unit(_unarmed, RED, Vector2i(1, 0))
	near.hp = 10
	world.step()
	assert_float(near.aura_damage_bonus).is_greater(0.0)
	hero.hp = 0
	hero.downed = true
	world.queue_command(AbilityCommand.new(RED, hero.id, 0, near.id))
	_run(world, 2)
	assert_float(near.aura_damage_bonus).is_equal(0.0)
	assert_int(near.hp).is_equal(10)


func test_cast_is_dropped_when_target_dies() -> void:
	var world: SimWorld = _world(["..........", ".........."])
	var heal_list: Array[AbilityStats] = [_heal]
	var hero: SimUnit = world.spawn_unit(_hero_with(heal_list), BLUE, Vector2i(0, 0))
	var ally: SimUnit = world.spawn_unit(_unarmed, BLUE, Vector2i(9, 1))
	world.queue_command(AbilityCommand.new(BLUE, hero.id, 0, ally.id))
	_run(world, 2)
	assert_bool(hero.is_casting()).is_true()
	ally.hp = 0
	ally.downed = true  # stands in for "no longer a valid target"
	_run(world, 2)
	assert_bool(hero.is_casting()).is_false()
	assert_bool(hero.ability_ready(0)).is_true()


func test_mission_01_leaders_have_their_abilities() -> void:
	var blue: UnitStats = load("res://data/units/blue_leader.tres") as UnitStats
	var red: UnitStats = load("res://data/units/red_leader.tres") as UnitStats
	assert_int(blue.abilities.size()).is_equal(2)
	assert_int(red.abilities.size()).is_equal(2)
	assert_str(blue.abilities[0].display_name).is_equal("Repair")
	assert_int(blue.abilities[0].effect).is_equal(AbilityStats.Effect.HEAL)
	assert_int(blue.abilities[0].target).is_equal(AbilityStats.Target.ALLY)
	assert_int(blue.abilities[1].kind).is_equal(AbilityStats.Kind.AURA)
	assert_str(red.abilities[0].display_name).is_equal("Heavy Cannon")
	assert_int(red.abilities[0].target).is_equal(AbilityStats.Target.ENEMY)
	# Decided: Red's aura gives +10% attack damage within 5 cells.
	var dominion: AbilityStats = red.abilities[1]
	assert_int(dominion.kind).is_equal(AbilityStats.Kind.AURA)
	assert_int(dominion.effect).is_equal(AbilityStats.Effect.DAMAGE_BONUS)
	assert_float(dominion.amount).is_equal_approx(0.1, 0.0001)
	assert_float(dominion.aura_radius).is_equal_approx(5.0, 0.0001)
