class_name EnemyAi
extends RefCounted
## Enemy AI for one team (design/GDD.md → Enemy AI). Uses only the commands the
## player has (move, attack, ability), queued on the world before each tick.
## - After a start delay the army advances to the rock to contest it.
## - Focus fire: every fighter attacks the same enemy (least HP among enemies near
##   the rock or near the army); it keeps that target until it dies or leaves.
## - Abilities: damage abilities on the enemy with the most other enemies around it
##   (then the weakest); heal abilities on the most damaged ally.
## - The hero pulls back to its start area below rules.hero_retreat_fraction and
##   stays there until it is healthy again (e.g. back from recovery).

var team: SimUnit.Team = SimUnit.Team.RED
var rules: AiRules
## Fighter focus target id, or -1.
var focus_id: int = -1
## Heroes currently pulled back (id → true).
var retreating: Dictionary[int, bool] = {}

var _ticks: int = 0


func _init(ai_team: SimUnit.Team, ai_rules: AiRules) -> void:
	team = ai_team
	rules = ai_rules


## Called by the world at the start of every tick, before commands apply.
func update(world: SimWorld) -> void:
	var t: int = _ticks
	_ticks += 1
	var delay: int = roundi(rules.start_delay_seconds * SimWorld.TICKS_PER_SECOND)
	if t < delay:
		return
	var interval: int = maxi(1, roundi(rules.think_seconds * SimWorld.TICKS_PER_SECOND))
	if (t - delay) % interval != 0:
		return
	think(world)  # first decision on the first tick after the delay


func think(world: SimWorld) -> void:
	var fighters: Array[SimUnit] = []
	for unit: SimUnit in world.units:
		if unit.team != team or not unit.can_act():
			continue
		if unit.stats.is_hero:
			var casting: bool = _hero(world, unit)
			if casting or retreating.get(unit.id, false):
				continue  # an attack order now would cancel the ability
		fighters.append(unit)
	if fighters.is_empty():
		focus_id = -1
		return
	var focus: SimUnit = _pick_focus(world, fighters)
	if focus != null:
		focus_id = focus.id
		var ids: Array[int] = []
		for fighter: SimUnit in fighters:
			if fighter.attack_target_id != focus.id and not fighter.is_casting() and fighter.can_attack():
				ids.append(fighter.id)
		if not ids.is_empty():
			world.queue_command(AttackCommand.new(team, ids, focus.id))
		return
	focus_id = -1
	if world.objective == null:
		return
	var idle: Array[int] = []
	for fighter: SimUnit in fighters:
		if world.objective.is_in_zone(fighter.occupied_cell) or fighter.is_moving() or fighter.is_casting():
			continue
		if fighter.attack_target_id != -1:
			continue
		idle.append(fighter.id)
	if not idle.is_empty():
		var c: Vector2 = world.objective.center()
		world.queue_command(MoveCommand.new(team, idle, Vector2i(floori(c.x), floori(c.y))))


## Keeps the current focus while it is still a candidate; otherwise the candidate
## with the least HP (ties: nearest to the army, then lowest id).
func _pick_focus(world: SimWorld, fighters: Array[SimUnit]) -> SimUnit:
	var current: SimUnit = world.get_unit(focus_id)
	if current != null and _is_candidate(world, current, fighters):
		return current
	var army: Vector2 = Vector2.ZERO
	for fighter: SimUnit in fighters:
		army += fighter.pos
	army /= fighters.size()
	var best: SimUnit = null
	for other: SimUnit in world.units:
		if not _is_candidate(world, other, fighters):
			continue
		if best == null or other.hp < best.hp \
				or (other.hp == best.hp and other.pos.distance_to(army) < best.pos.distance_to(army) - SimWorld.EPSILON):
			best = other
	return best


func _is_candidate(world: SimWorld, other: SimUnit, fighters: Array[SimUnit]) -> bool:
	if other.team == team or not other.can_act():
		return false
	if world.objective != null and other.pos.distance_to(world.objective.center()) <= rules.guard_radius:
		return true
	for fighter: SimUnit in fighters:
		if fighter.pos.distance_to(other.pos) <= rules.focus_radius:
			return true
	return false


## Retreat and abilities. Returns true if the hero is busy with an ability.
func _hero(world: SimWorld, hero: SimUnit) -> bool:
	var low: bool = hero.hp_fraction() < rules.hero_retreat_fraction
	if low and not retreating.get(hero.id, false):
		retreating[hero.id] = true
		world.queue_command(MoveCommand.new(team, [hero.id], _start_cell(world)))
		return false
	if not low and retreating.get(hero.id, false):
		retreating.erase(hero.id)  # healthy again (e.g. back from recovery)
	if retreating.get(hero.id, false) and hero.is_moving():
		return false  # don't cancel the walk home
	if hero.is_casting():
		return true
	for i: int in hero.stats.abilities.size():
		var ability: AbilityStats = hero.ability(i)
		if ability == null or not ability.is_active() or not hero.ability_ready(i):
			continue
		var target: SimUnit = _ability_target(world, hero, ability)
		if target != null:
			world.queue_command(AbilityCommand.new(team, hero.id, i, target.id))
			return true
	return false


## A target already in range and sight (the AI doesn't walk the hero to cast).
func _ability_target(world: SimWorld, hero: SimUnit, ability: AbilityStats) -> SimUnit:
	var best: SimUnit = null
	var best_score: float = -INF
	for other: SimUnit in world.units:
		if not world.is_valid_cast_target(hero, ability, other):
			continue
		if hero.pos.distance_to(other.pos) > ability.cast_range + SimWorld.EPSILON or not world.can_see(hero, other):
			continue
		var score: float = 0.0
		if ability.effect == AbilityStats.Effect.HEAL:
			if other.hp_fraction() >= rules.heal_below_fraction:
				continue
			score = 1.0 - other.hp_fraction()
		else:
			var around: int = 0
			for near: SimUnit in world.units:
				if near != other and near.team == other.team and near.can_act() \
						and near.pos.distance_to(other.pos) <= ability.splash_radius + SimWorld.EPSILON:
					around += 1
			score = around * 10000.0 - other.hp  # most splash, then weakest
		if best == null or score > best_score:
			best = other
			best_score = score
	return best


func _start_cell(world: SimWorld) -> Vector2i:
	var spawns: Array[Vector2i] = world.grid.blue_spawns if team == SimUnit.Team.BLUE else world.grid.red_spawns
	return spawns[0] if not spawns.is_empty() else world.grid.size() / 2
