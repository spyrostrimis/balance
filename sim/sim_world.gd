class_name SimWorld
extends RefCounted
## The whole simulation state, advanced in fixed ticks (independent of frame rate).
##
## Movement rules (design/GDD.md → Movement):
## - One unit per cell. Ground units can't enter rocks/cliffs or cells held by
##   other ground units. Air units fly over terrain and ground units, but not
##   through other air units.
## - Every unit stops only on a free ground cell: passable terrain with no other
##   unit (ground or air) on it or heading to it.
## - A move order picks one stop cell per unit: the clicked cell if free, else the
##   nearest free reachable cells (ties broken towards the group), then paths there.
##
## Combat rules (design/GDD.md -> Combat), resolved simultaneously each tick:
## - Idle units engage the nearest enemy they can see within acquire range
##   (moving in to attack range). They remember their post and walk back to it
##   when the enemy gets more than LEASH cells beyond that (measured from the
##   post) or is gone.
## - Rocks and cliffs block shots and sight (line of sight); units don't.
## - Units with a move order don't attack until they arrive.
## - An attack order chases the target until in range and in sight, then fires
##   until it dies.
## - An idle unit that gets shot fights back (chasing the attacker if needed).
## - Units only fire while standing still (not between cells).
## - At 0 HP troops die; heroes are downed instead (stay on the map, inactive).
##
## Hero abilities (design/GDD.md -> Heroes): an active ability walks the hero into
## range and sight of its target, then fires and cools down. Auras modify own
## units nearby (damage dealt / taken, attack and move speed) while the hero is up.
##
## The hero rule: heroes are downed, never killed. The player's hero downed =
## mission failed (outcome DEFEAT). A downed AI hero is fetched by a recovery
## unit (SimRecovery: untargetable, unblockable), carried off the map, and
## returns at its start area after rules.return_seconds.
##
## Mission (design/GDD.md -> Mission 1): a CaptureObjective at the rock (hold it
## to win), plus: player's hero downed = DEFEAT; every enemy troop dead while
## the enemy hero is down = VICTORY. Non-player teams are run by EnemyAi, which
## queues commands at the start of each tick.

const TICKS_PER_SECOND: int = 15
const TICK_SECONDS: float = 1.0 / TICKS_PER_SECOND
## Blocked this many ticks by another unit → look for a path around units.
const REPATH_AFTER_TICKS: int = 6
## Still blocked after this many ticks → pick a new stop cell once, then give up.
const GIVE_UP_AFTER_TICKS: int = 45
const EPSILON: float = 0.000001
## While chasing, re-plan the route at most this often (ticks).
const CHASE_REPLAN_TICKS: int = 5
## An auto-picked target is dropped beyond acquire_range + this many cells.
const LEASH: float = 1.5

## From the player's point of view.
enum Outcome { NONE, VICTORY, DEFEAT }
enum Reason { NONE, HERO_DOWN, ROCK_HELD, ENEMY_ROUTED }

## The human player's team; every other team is AI.
var player_team: SimUnit.Team = SimUnit.Team.BLUE
var rules: HeroRules = HeroRules.new()
var outcome: Outcome = Outcome.NONE
var outcome_reason: Reason = Reason.NONE
## Capture-and-hold objective (null if the mission has none).
var objective: CaptureObjective
## AI players, run at the start of every tick.
var ai: Array[EnemyAi] = []
## Recovery units on their way (not units: never targeted or blocked).
var recoveries: Array[SimRecovery] = []
var grid: MapGrid = MapGrid.new()
var pathfinder: Pathfinder = Pathfinder.new()
var units: Array[SimUnit] = []
var tick: int = 0
## What happened during the last step (cleared at the start of each step).
var events: Array[CombatEvent] = []

var _pending: Array[SimCommand] = []
var _next_id: int = 1
var _next_recovery_id: int = 1
var _by_id: Dictionary[int, SimUnit] = {}
## Cell → unit id, per layer (occupied cells and cells being stepped into).
var _ground_res: Dictionary[Vector2i, int] = {}
var _air_res: Dictionary[Vector2i, int] = {}
## Stop cell → unit id heading there.
var _dest_res: Dictionary[Vector2i, int] = {}


## Loads a map from rows (see MapLayout). Returns "" or an error message.
func load_map_rows(rows: PackedStringArray) -> String:
	var err: String = grid.load_rows(rows)
	if err == "":
		pathfinder.build(grid)
	return err


func load_map(layout: MapLayout) -> String:
	if layout == null:
		return "map layout is null"
	return load_map_rows(layout.rows)


## Loads the mission's map and spawns both rosters. Returns "" or an error message.
func setup_mission(data: MissionData) -> String:
	if data == null:
		return "mission data is null"
	player_team = data.player_team
	if data.hero_rules != null:
		rules = data.hero_rules
	var err: String = load_map(data.map)
	if err != "":
		return err
	err = _spawn_roster(data.blue_roster, SimUnit.Team.BLUE, grid.blue_spawns)
	if err != "":
		return err
	err = _spawn_roster(data.red_roster, SimUnit.Team.RED, grid.red_spawns)
	if err != "":
		return err
	if data.objective != null and not grid.deposits.is_empty():
		objective = CaptureObjective.new(grid, grid.deposits[0], data.objective)
	if data.ai_rules != null:
		for team: SimUnit.Team in [SimUnit.Team.BLUE, SimUnit.Team.RED]:
			if team != player_team:
				ai.append(EnemyAi.new(team, data.ai_rules))
	return ""


## Spawns a unit on a free cell. Returns null if the cell isn't free.
func spawn_unit(stats: UnitStats, team: SimUnit.Team, cell: Vector2i) -> SimUnit:
	if not is_cell_free(cell):
		return null
	var unit: SimUnit = SimUnit.new(_next_id, team, stats, cell)
	_next_id += 1
	units.append(unit)
	_by_id[unit.id] = unit
	_layer(unit)[cell] = unit.id
	return unit


func get_unit(unit_id: int) -> SimUnit:
	return _by_id.get(unit_id, null)


## True if a unit could stop here: passable, and no unit on it or heading to it.
func is_cell_free(cell: Vector2i) -> bool:
	return grid.is_passable(cell) and not _ground_res.has(cell) and not _air_res.has(cell) \
			and not _dest_res.has(cell)


## Queues a command; it takes effect at the start of the next tick.
func queue_command(command: SimCommand) -> void:
	_pending.append(command)


func step() -> void:
	tick += 1
	events.clear()
	for recovery: SimRecovery in recoveries:
		recovery.prev_pos = recovery.pos
	for unit: SimUnit in units:
		unit.prev_pos = unit.pos
		for i: int in unit.ability_cooldowns.size():
			if unit.ability_cooldowns[i] > 0:
				unit.ability_cooldowns[i] -= 1
	for controller: EnemyAi in ai:
		controller.update(self)
	var commands: Array[SimCommand] = _pending
	_pending = []
	for command: SimCommand in commands:
		command.apply(self)
	for unit: SimUnit in units:
		if unit.can_act():
			_update_target(unit)
			_chase(unit)
	for unit: SimUnit in units:
		if unit.can_act():
			_move(unit)
	_update_auras()
	_resolve_combat()
	_update_away_heroes()  # before recoveries: a hero leaving this tick starts its full countdown
	_update_recoveries()
	_update_objective()
	_check_routed()


## Orders units of `team` towards `target` (called by MoveCommand on a tick).
func order_move(team: SimUnit.Team, unit_ids: Array[int], target: Vector2i) -> void:
	var group: Array[SimUnit] = []
	for unit_id: int in unit_ids:
		var unit: SimUnit = get_unit(unit_id)
		if unit != null and unit.team == team and unit.can_act() and not group.has(unit):
			group.append(unit)
	if group.is_empty() or grid.width == 0:
		return
	for unit: SimUnit in group:
		unit.attack_target_id = -1
		unit.target_forced = false
		unit.has_home = false
		_cancel_cast(unit)
	target = Vector2i(clampi(target.x, 0, grid.width - 1), clampi(target.y, 0, grid.height - 1))
	for unit: SimUnit in group:
		_clear_destination(unit)
		unit.order_target = target
		unit.retargeted = false
	var stops: Dictionary[int, Vector2i] = _assign_stops(group, target)
	for unit: SimUnit in group:
		unit.path.clear()
		unit.blocked_ticks = 0
		if stops.has(unit.id):
			_set_destination(unit, stops[unit.id])


## Orders units of `team` to attack an enemy unit (called by AttackCommand on a tick).
func order_attack(team: SimUnit.Team, unit_ids: Array[int], target_id: int) -> void:
	var target: SimUnit = get_unit(target_id)
	if target == null or target.team == team or not target.can_act():
		return
	for unit_id: int in unit_ids:
		var unit: SimUnit = get_unit(unit_id)
		if unit == null or unit.team != team or not unit.can_act() or not unit.can_attack():
			continue
		_cancel_cast(unit)
		unit.attack_target_id = target_id
		unit.target_forced = true
		unit.has_home = false
		unit.chase_timer = 0
		unit.chase_cell = Vector2i(-1, -1)


## Orders a hero to use an active ability on a unit (called by AbilityCommand).
## Ignored if the ability isn't ready or the target isn't valid for it.
func order_ability(team: SimUnit.Team, unit_id: int, index: int, target_id: int) -> void:
	var unit: SimUnit = get_unit(unit_id)
	if unit == null or unit.team != team or not unit.can_act():
		return
	var ability: AbilityStats = unit.ability(index)
	if ability == null or not ability.is_active() or not unit.ability_ready(index):
		return
	if not is_valid_cast_target(unit, ability, get_unit(target_id)):
		return
	_cancel_cast(unit)
	unit.attack_target_id = -1
	unit.target_forced = false
	unit.has_home = false
	unit.cast_index = index
	unit.cast_target_id = target_id
	unit.chase_timer = 0
	unit.chase_cell = Vector2i(-1, -1)
	_clear_destination(unit)
	unit.path.clear()


func is_valid_cast_target(unit: SimUnit, ability: AbilityStats, target: SimUnit) -> bool:
	if target == null or not target.can_act():
		return false
	if ability.target == AbilityStats.Target.ALLY:
		return target.team == unit.team
	return target.team != unit.team


## True if nothing blocks the straight line between two positions (cell units).
## Walks every cell the line touches (endpoints excluded). A line through an exact
## corner is blocked only if both cells beside the corner block.
func has_line_of_sight(from: Vector2, to: Vector2) -> bool:
	var cell: Vector2i = Vector2i(floori(from.x), floori(from.y))
	var end: Vector2i = Vector2i(floori(to.x), floori(to.y))
	var d: Vector2 = to - from
	var step_x: int = 1 if d.x > 0.0 else -1
	var step_y: int = 1 if d.y > 0.0 else -1
	var t_delta_x: float = absf(1.0 / d.x) if absf(d.x) > EPSILON else INF
	var t_delta_y: float = absf(1.0 / d.y) if absf(d.y) > EPSILON else INF
	var t_max_x: float = INF
	if absf(d.x) > EPSILON:
		t_max_x = ((cell.x + 1.0 - from.x) if d.x > 0.0 else (from.x - cell.x)) * t_delta_x
	var t_max_y: float = INF
	if absf(d.y) > EPSILON:
		t_max_y = ((cell.y + 1.0 - from.y) if d.y > 0.0 else (from.y - cell.y)) * t_delta_y
	var guard: int = absi(end.x - cell.x) + absi(end.y - cell.y) + 2
	while cell != end and guard > 0:
		guard -= 1
		if absf(t_max_x - t_max_y) <= 1e-9:
			if grid.blocks_sight(Vector2i(cell.x + step_x, cell.y)) \
					and grid.blocks_sight(Vector2i(cell.x, cell.y + step_y)):
				return false
			cell += Vector2i(step_x, step_y)
			t_max_x += t_delta_x
			t_max_y += t_delta_y
		elif t_max_x < t_max_y:
			cell.x += step_x
			t_max_x += t_delta_x
		else:
			cell.y += step_y
			t_max_y += t_delta_y
		if cell != end and grid.blocks_sight(cell):
			return false
	return true


## Sight between two units. Air units see and shoot over terrain.
func can_see(unit: SimUnit, other: SimUnit) -> bool:
	if unit.is_air() or other.is_air():
		return true
	return has_line_of_sight(unit.pos, other.pos)


## In attack range and in sight.
func can_hit(unit: SimUnit, target: SimUnit) -> bool:
	return in_attack_range(unit, target) and can_see(unit, target)


func in_attack_range(unit: SimUnit, target: SimUnit) -> bool:
	return unit.pos.distance_to(target.pos) <= unit.stats.attack_range + EPSILON


## Casting: the ability's target is in range and sight. Otherwise: the attack
## target can be hit.
func _target_in_range(unit: SimUnit) -> bool:
	var target: SimUnit = _engaged_target(unit)
	return target != null and _in_reach(unit, target)


## The unit the unit is walking to: its cast target, else its attack target.
func _engaged_target(unit: SimUnit) -> SimUnit:
	if unit.is_casting():
		var cast_target: SimUnit = get_unit(unit.cast_target_id)
		var ability: AbilityStats = unit.ability(unit.cast_index)
		return cast_target if is_valid_cast_target(unit, ability, cast_target) else null
	if unit.attack_target_id == -1:
		return null
	var target: SimUnit = get_unit(unit.attack_target_id)
	return target if _is_valid_target(unit, target) else null


func _in_reach(unit: SimUnit, target: SimUnit) -> bool:
	if unit.is_casting():
		var ability: AbilityStats = unit.ability(unit.cast_index)
		return unit.pos.distance_to(target.pos) <= ability.cast_range + EPSILON and can_see(unit, target)
	return can_hit(unit, target)


func _is_valid_target(unit: SimUnit, target: SimUnit) -> bool:
	return target != null and target.team != unit.team and target.can_act()


func _update_target(unit: SimUnit) -> void:
	if unit.is_casting():
		if _engaged_target(unit) == null:
			_cancel_cast(unit)  # target gone or downed
		else:
			return
	if unit.attack_target_id != -1:
		var target: SimUnit = get_unit(unit.attack_target_id)
		var lost: bool = not _is_valid_target(unit, target)
		if not lost and not unit.target_forced and unit.has_home:
			lost = SimUnit.cell_center(unit.home_cell).distance_to(target.pos) > unit.leash_radius + EPSILON
		if lost:
			unit.attack_target_id = -1
			unit.target_forced = false
			_clear_destination(unit)
			unit.path.clear()
	if unit.attack_target_id == -1 and not unit.is_moving() and unit.can_attack():
		var nearest: SimUnit = _nearest_enemy_within(unit, maxf(unit.stats.acquire_range, unit.stats.attack_range))
		if nearest != null:
			if not unit.has_home:
				_set_home(unit, unit.stats.acquire_range + LEASH)
			unit.attack_target_id = nearest.id
			unit.target_forced = false
			unit.chase_timer = 0
		elif unit.has_home:
			_return_home(unit)


func _set_home(unit: SimUnit, radius: float) -> void:
	unit.has_home = true
	unit.home_cell = unit.occupied_cell
	unit.leash_radius = radius


## Nothing left to fight: walk back to the post (a plain move; it fights again
## once it's there and idle).
func _return_home(unit: SimUnit) -> void:
	unit.has_home = false
	if unit.occupied_cell == unit.home_cell:
		return
	unit.order_target = unit.home_cell
	unit.retargeted = false
	unit.blocked_ticks = 0
	unit.path.clear()
	var group: Array[SimUnit] = [unit]
	var stops: Dictionary[int, Vector2i] = _assign_stops(group, unit.home_cell)
	if stops.has(unit.id) and stops[unit.id] != unit.occupied_cell:
		_set_destination(unit, stops[unit.id])


func _cancel_cast(unit: SimUnit) -> void:
	if not unit.is_casting():
		return
	unit.cast_index = -1
	unit.cast_target_id = -1
	_clear_destination(unit)
	unit.path.clear()


## Nearest enemy in sight within `max_dist` (and within the leash of the unit's
## post, if it has one). Ties go to the lower id.
func _nearest_enemy_within(unit: SimUnit, max_dist: float) -> SimUnit:
	var best: SimUnit = null
	var best_dist: float = INF
	var home: Vector2 = SimUnit.cell_center(unit.home_cell)
	for other: SimUnit in units:
		if not _is_valid_target(unit, other) or unit.pos.distance_to(other.pos) > max_dist + EPSILON:
			continue
		if unit.has_home and home.distance_to(other.pos) > unit.leash_radius + EPSILON:
			continue
		if not can_see(unit, other):
			continue
		var d: float = unit.pos.distance_to(other.pos)
		if best == null or d < best_dist - EPSILON or (absf(d - best_dist) <= EPSILON and other.id < best.id):
			best = other
			best_dist = d
	return best


## Walks towards the cast or attack target until it is in reach (range and
## sight), re-planning as it moves.
func _chase(unit: SimUnit) -> void:
	var target: SimUnit = _engaged_target(unit)
	if target == null:
		return
	if _in_reach(unit, target):
		if unit.has_destination or not unit.path.is_empty():
			unit.path.clear()  # finish the current step, then stop and fire
			_clear_destination(unit)
		return
	unit.chase_timer -= 1
	if unit.chase_timer > 0:
		return
	unit.chase_timer = CHASE_REPLAN_TICKS
	if unit.is_moving() and target.occupied_cell == unit.chase_cell:
		return
	unit.chase_cell = target.occupied_cell
	_clear_destination(unit)
	unit.path.clear()
	unit.blocked_ticks = 0
	unit.order_target = target.occupied_cell
	unit.retargeted = false
	var group: Array[SimUnit] = [unit]
	var stops: Dictionary[int, Vector2i] = _assign_stops(group, target.occupied_cell)
	if stops.has(unit.id):
		_set_destination(unit, stops[unit.id])


## Aura effects for this tick, from every hero that is up.
## The same effect from several auras doesn't stack (the strongest counts).
func _update_auras() -> void:
	for unit: SimUnit in units:
		unit.aura_damage_bonus = 0.0
		unit.aura_damage_reduction = 0.0
		unit.aura_attack_speed_bonus = 0.0
		unit.aura_move_speed_bonus = 0.0
	for source: SimUnit in units:
		if not source.can_act():
			continue
		for ability: AbilityStats in source.stats.abilities:
			if ability == null or ability.kind != AbilityStats.Kind.AURA:
				continue
			for unit: SimUnit in units:
				if unit.team != source.team or not unit.can_act():
					continue
				if unit == source and not ability.aura_affects_self:
					continue
				if source.pos.distance_to(unit.pos) > ability.aura_radius + EPSILON:
					continue
				unit.aura_damage_bonus = maxf(unit.aura_damage_bonus, ability.aura_damage_bonus)
				unit.aura_damage_reduction = maxf(unit.aura_damage_reduction, ability.aura_damage_reduction)
				unit.aura_attack_speed_bonus = maxf(unit.aura_attack_speed_bonus, ability.aura_attack_speed_bonus)
				unit.aura_move_speed_bonus = maxf(unit.aura_move_speed_bonus, ability.aura_move_speed_bonus)


## Damage after the attacker's and the target's aura effects, in whole HP.
static func final_damage(attacker: SimUnit, target: SimUnit, base: float) -> int:
	if base <= 0.0:
		return 0
	var scaled: float = base * (1.0 + attacker.aura_damage_bonus) * (1.0 - target.aura_damage_reduction)
	return maxi(1, roundi(scaled))


## Abilities, then shots, are all decided first; then damage lands; then deaths.
## So everything in a tick happens at once: a mirrored 1v1 is a draw, not decided
## by list order.
func _resolve_combat() -> void:
	var hit_from: Array[SimUnit] = []
	var hit_to: Array[SimUnit] = []
	var hit_base: Array[float] = []
	var hit_is_shot: Array[bool] = []

	for unit: SimUnit in units:
		if not unit.can_act() or not unit.is_casting() or unit.stepping:
			continue
		var target: SimUnit = _engaged_target(unit)
		if target == null or not _in_reach(unit, target):
			continue
		var index: int = unit.cast_index
		var ability: AbilityStats = unit.ability(index)
		match ability.effect:
			AbilityStats.Effect.HEAL:
				var healed: int = mini(roundi(ability.amount), target.stats.max_hp - target.hp)
				target.hp += maxi(healed, 0)
				events.append(CombatEvent.new(CombatEvent.Kind.ABILITY, unit.id, target.id, maxi(healed, 0), index))
			AbilityStats.Effect.DAMAGE:
				events.append(CombatEvent.new(CombatEvent.Kind.ABILITY, unit.id, target.id,
						final_damage(unit, target, ability.amount), index))
				hit_from.append(unit)
				hit_to.append(target)
				hit_base.append(ability.amount)
				hit_is_shot.append(false)
				for other: SimUnit in units:
					if other == target or not _is_valid_target(unit, other):
						continue
					if other.pos.distance_to(target.pos) <= ability.splash_radius + EPSILON:
						hit_from.append(unit)
						hit_to.append(other)
						hit_base.append(ability.amount * ability.splash_fraction)
						hit_is_shot.append(false)
		unit.ability_cooldowns[index] = ability.cooldown_ticks(TICKS_PER_SECOND)
		unit.cast_index = -1
		unit.cast_target_id = -1

	for unit: SimUnit in units:
		if not unit.can_act():
			continue
		# Attack-speed auras make the cooldown run faster. The leftover fraction
		# carries into the next cooldown so the average rate is exact.
		if unit.cooldown_left > 0.0:
			unit.cooldown_left -= 1.0 + unit.aura_attack_speed_bonus
		var target: SimUnit = get_unit(unit.attack_target_id)
		if unit.attack_target_id == -1 or unit.stepping or unit.cooldown_left > EPSILON 				or not _is_valid_target(unit, target) or not can_hit(unit, target):
			unit.cooldown_left = maxf(unit.cooldown_left, 0.0)  # no banking while not firing
			continue
		hit_from.append(unit)
		hit_to.append(target)
		hit_base.append(float(unit.stats.attack_damage))
		hit_is_shot.append(true)
		unit.cooldown_left += maxf(1.0, unit.stats.attack_cooldown * TICKS_PER_SECOND)

	var last_hit_by: Dictionary[int, int] = {}
	for i: int in hit_from.size():
		var attacker: SimUnit = hit_from[i]
		var target: SimUnit = hit_to[i]
		var damage: int = final_damage(attacker, target, hit_base[i])
		target.hp = maxi(target.hp - damage, 0)
		last_hit_by[target.id] = attacker.id
		if hit_is_shot[i]:
			events.append(CombatEvent.new(CombatEvent.Kind.SHOT, attacker.id, target.id, damage))
		_fight_back(target, attacker)

	for unit: SimUnit in units.duplicate():
		if unit.hp > 0 or not unit.can_act():
			continue
		var killer: int = last_hit_by.get(unit.id, -1)
		if unit.stats.is_hero:
			_down(unit)
			events.append(CombatEvent.new(CombatEvent.Kind.DOWNED, unit.id, killer))
			_on_hero_downed(unit)
		else:
			_remove(unit)
			events.append(CombatEvent.new(CombatEvent.Kind.DIED, unit.id, killer))


## An idle unit that gets hit targets its attacker. It keeps a post like an
## auto-engage, with the leash wide enough to reach the attacker.
func _fight_back(unit: SimUnit, attacker: SimUnit) -> void:
	if unit.attack_target_id != -1 or unit.is_moving() or unit.is_casting() or not unit.can_attack():
		return
	if not unit.can_act() or unit.hp <= 0:
		return
	var reach: float = maxf(unit.stats.acquire_range, unit.pos.distance_to(attacker.pos)) + LEASH
	if unit.has_home:
		var from_home: float = SimUnit.cell_center(unit.home_cell).distance_to(attacker.pos) + LEASH
		unit.leash_radius = maxf(unit.leash_radius, from_home)
	else:
		_set_home(unit, reach)
	unit.attack_target_id = attacker.id
	unit.target_forced = false
	unit.chase_timer = 0


## Hero at 0 HP: stays where it is (still holding its cell), does nothing.
func _down(unit: SimUnit) -> void:
	unit.downed = true
	unit.attack_target_id = -1
	unit.cast_index = -1
	unit.cast_target_id = -1
	unit.has_home = false
	unit.path.clear()
	_clear_destination(unit)
	if unit.stepping:
		# Settle on the cell it was entering so it holds exactly one cell.
		var layer: Dictionary[Vector2i, int] = _layer(unit)
		if layer.get(unit.occupied_cell, -1) == unit.id:
			layer.erase(unit.occupied_cell)
		unit.occupied_cell = unit.step_cell
		unit.pos = SimUnit.cell_center(unit.step_cell)
		unit.stepping = false


## The player's hero down = mission failed; an AI hero gets a recovery unit.
func _on_hero_downed(hero: SimUnit) -> void:
	if hero.team == player_team:
		_end(Outcome.DEFEAT, Reason.HERO_DOWN, hero.id)
		return
	var recovery: SimRecovery = SimRecovery.new(_next_recovery_id, hero.team, hero.id, recovery_entry(hero.team))
	_next_recovery_id += 1
	recoveries.append(recovery)
	events.append(CombatEvent.new(CombatEvent.Kind.RECOVERY_SENT, hero.id, recovery.id))


## Ends the mission once (later results are ignored).
func _end(result: Outcome, reason: Reason, unit_id: int = -1) -> void:
	if outcome != Outcome.NONE:
		return
	outcome = result
	outcome_reason = reason
	var kind: CombatEvent.Kind = CombatEvent.Kind.MISSION_WON if result == Outcome.VICTORY \
			else CombatEvent.Kind.MISSION_FAILED
	events.append(CombatEvent.new(kind, unit_id, -1, reason))


func _update_objective() -> void:
	if objective == null:
		return
	var captured: int = objective.update(units)
	if captured != CaptureObjective.NO_TEAM:
		events.append(CombatEvent.new(CombatEvent.Kind.ROCK_CAPTURED, -1, captured))
	var holder: int = objective.winner()
	if holder != CaptureObjective.NO_TEAM:
		_end(Outcome.VICTORY if holder == player_team else Outcome.DEFEAT, Reason.ROCK_HELD)


## Player wins when an enemy team has no troops left and its heroes are all down.
func _check_routed() -> void:
	for team: SimUnit.Team in [SimUnit.Team.BLUE, SimUnit.Team.RED]:
		if team == player_team:
			continue
		var standing: bool = false
		var seen: bool = false
		for unit: SimUnit in units:
			if unit.team != team:
				continue
			seen = true
			if not unit.stats.is_hero or not unit.downed:
				standing = true
				break
		if seen and not standing:
			_end(Outcome.VICTORY, Reason.ENEMY_ROUTED)


## Where a team's recovery units enter and leave: beyond the map edge, out
## from the map centre towards the team's start area.
func recovery_entry(team: SimUnit.Team) -> Vector2:
	var center: Vector2 = Vector2(grid.size()) * 0.5
	var spawns: Array[Vector2i] = grid.blue_spawns if team == SimUnit.Team.BLUE else grid.red_spawns
	var dir: Vector2 = Vector2(0.0, -1.0)
	if not spawns.is_empty():
		var sum: Vector2 = Vector2.ZERO
		for cell: Vector2i in spawns:
			sum += SimUnit.cell_center(cell)
		var away_from_center: Vector2 = sum / spawns.size() - center
		if away_from_center.length() > EPSILON:
			dir = away_from_center.normalized()
	return center + dir * (center.length() + rules.recovery_offmap_margin)


## Recovery units fly in a straight line: in to the hero, load, back out.
func _update_recoveries() -> void:
	var step_len: float = rules.recovery_speed * TICK_SECONDS
	for recovery: SimRecovery in recoveries.duplicate():
		recovery.prev_pos = recovery.pos
		var hero: SimUnit = get_unit(recovery.hero_id)
		if hero == null:
			recoveries.erase(recovery)
			continue
		match recovery.state:
			SimRecovery.State.INBOUND:
				if _fly(recovery, hero.pos, step_len):
					recovery.state = SimRecovery.State.LOADING
					recovery.load_ticks_left = maxi(1, roundi(rules.recovery_load_seconds * TICKS_PER_SECOND))
			SimRecovery.State.LOADING:
				recovery.load_ticks_left -= 1
				if recovery.load_ticks_left <= 0:
					_lift(hero)
					recovery.state = SimRecovery.State.OUTBOUND
					events.append(CombatEvent.new(CombatEvent.Kind.HERO_LOADED, hero.id, recovery.id))
			SimRecovery.State.OUTBOUND:
				var gone: bool = _fly(recovery, recovery.exit_pos, step_len)
				hero.pos = recovery.pos
				if gone:
					recoveries.erase(recovery)
					hero.carried = false
					hero.away = true
					hero.return_ticks_left = maxi(1, roundi(rules.return_seconds * TICKS_PER_SECOND))
					events.append(CombatEvent.new(CombatEvent.Kind.HERO_AWAY, hero.id, recovery.id, hero.return_ticks_left))


## Moves towards `target`; true once there.
func _fly(recovery: SimRecovery, target: Vector2, step_len: float) -> bool:
	var to_target: Vector2 = target - recovery.pos
	if to_target.length() <= step_len + EPSILON:
		recovery.pos = target
		return true
	recovery.pos += to_target.normalized() * step_len
	return false


## The recovery unit picks the hero up: it lets go of its cell.
func _lift(hero: SimUnit) -> void:
	var layer: Dictionary[Vector2i, int] = _layer(hero)
	for cell: Vector2i in [hero.occupied_cell, hero.step_cell]:
		if layer.get(cell, -1) == hero.id:
			layer.erase(cell)
	hero.stepping = false
	hero.carried = true


## Heroes off the map count down, then come back at their start area.
func _update_away_heroes() -> void:
	for unit: SimUnit in units:
		if not unit.away:
			continue
		unit.return_ticks_left -= 1
		if unit.return_ticks_left <= 0 and _return_hero(unit):
			events.append(CombatEvent.new(CombatEvent.Kind.HERO_RETURNED, unit.id, -1))


## Puts the hero back on the free cell nearest its team's first spawn cell, with
## rules.return_hp_fraction HP and every ability ready. False if no cell is free
## (it tries again next tick).
func _return_hero(hero: SimUnit) -> bool:
	var spawns: Array[Vector2i] = grid.blue_spawns if hero.team == SimUnit.Team.BLUE else grid.red_spawns
	var anchor: Vector2i = spawns[0] if not spawns.is_empty() else grid.size() / 2
	var cell: Vector2i = Vector2i(-1, -1)
	for r: int in range(0, maxi(grid.width, grid.height) + 1):
		var best_d: float = INF
		for y: int in range(anchor.y - r, anchor.y + r + 1):
			for x: int in range(anchor.x - r, anchor.x + r + 1):
				if maxi(absi(x - anchor.x), absi(y - anchor.y)) != r:
					continue
				var c: Vector2i = Vector2i(x, y)
				var d: float = Vector2(c - anchor).length()
				if is_cell_free(c) and d < best_d:
					cell = c
					best_d = d
		if cell != Vector2i(-1, -1):
			break
	if cell == Vector2i(-1, -1):
		return false
	hero.away = false
	hero.carried = false
	hero.downed = false
	hero.hp = maxi(1, roundi(hero.stats.max_hp * rules.return_hp_fraction))
	hero.occupied_cell = cell
	hero.step_cell = cell
	hero.stepping = false
	hero.pos = SimUnit.cell_center(cell)
	hero.prev_pos = hero.pos
	hero.path.clear()
	hero.has_destination = false
	hero.attack_target_id = -1
	hero.target_forced = false
	hero.has_home = false
	hero.cast_index = -1
	hero.cast_target_id = -1
	hero.cooldown_left = 0.0
	hero.ability_cooldowns.fill(0)
	_layer(hero)[cell] = hero.id
	return true


func _remove(unit: SimUnit) -> void:
	unit.dead = true
	var layer: Dictionary[Vector2i, int] = _layer(unit)
	for cell: Vector2i in [unit.occupied_cell, unit.step_cell]:
		if layer.get(cell, -1) == unit.id:
			layer.erase(cell)
	_clear_destination(unit)
	units.erase(unit)
	_by_id.erase(unit.id)


func _set_destination(unit: SimUnit, stop: Vector2i) -> void:
	var start: Vector2i = unit.step_cell if unit.stepping else unit.occupied_cell
	unit.path = pathfinder.find_path(start, stop, unit.is_air())
	if unit.path.is_empty() and start != stop:
		return  # unreachable after all; stay
	unit.destination = stop
	unit.has_destination = true
	_dest_res[stop] = unit.id


func _clear_destination(unit: SimUnit) -> void:
	if unit.has_destination and _dest_res.get(unit.destination, -1) == unit.id:
		_dest_res.erase(unit.destination)
	unit.has_destination = false


## Picks a distinct stop cell for each unit, nearest to `target` first.
func _assign_stops(group: Array[SimUnit], target: Vector2i) -> Dictionary[int, Vector2i]:
	var ids: Dictionary[int, bool] = {}
	var centroid: Vector2 = Vector2.ZERO
	for unit: SimUnit in group:
		ids[unit.id] = true
		centroid += unit.pos
	centroid /= group.size()

	# Collect free cells ring by ring around the target until there are enough,
	# plus one more ring so near-ties can be broken towards the group.
	var candidates: Array[Vector2i] = []
	var enough_at: int = -1
	var max_radius: int = maxi(grid.width, grid.height)
	for r: int in range(0, max_radius + 1):
		for y: int in range(target.y - r, target.y + r + 1):
			for x: int in range(target.x - r, target.x + r + 1):
				if maxi(absi(x - target.x), absi(y - target.y)) != r:
					continue
				var cell: Vector2i = Vector2i(x, y)
				if _is_stop_for_group(cell, ids) and _reachable_by_any(group, cell):
					candidates.append(cell)
		if enough_at < 0 and candidates.size() >= group.size():
			enough_at = r
		if enough_at >= 0 and r >= enough_at + 1:
			break

	var target_center: Vector2 = SimUnit.cell_center(target)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da: int = roundi(SimUnit.cell_center(a).distance_to(target_center) * 100.0)
		var db: int = roundi(SimUnit.cell_center(b).distance_to(target_center) * 100.0)
		if da != db:
			return da < db
		return SimUnit.cell_center(a).distance_to(centroid) < SimUnit.cell_center(b).distance_to(centroid))

	var result: Dictionary[int, Vector2i] = {}
	var unassigned: Array[SimUnit] = group.duplicate()
	for cell: Vector2i in candidates:
		if unassigned.is_empty():
			break
		var best: SimUnit = null
		var best_dist: float = INF
		for unit: SimUnit in unassigned:
			var d: float = unit.pos.distance_to(SimUnit.cell_center(cell))
			if d < best_dist and _reachable(unit, cell):
				best = unit
				best_dist = d
		if best != null:
			result[best.id] = cell
			unassigned.erase(best)
	return result


## Free for this group: passable, and any unit on it or heading to it is in the group.
func _is_stop_for_group(cell: Vector2i, group_ids: Dictionary[int, bool]) -> bool:
	if not grid.is_passable(cell):
		return false
	for layer: Dictionary[Vector2i, int] in [_ground_res, _air_res, _dest_res]:
		if layer.has(cell) and not group_ids.has(layer[cell]):
			return false
	return true


func _reachable(unit: SimUnit, cell: Vector2i) -> bool:
	if unit.is_air():
		return true
	var start: Vector2i = unit.step_cell if unit.stepping else unit.occupied_cell
	var region: int = pathfinder.region_of(start)
	return region != -1 and region == pathfinder.region_of(cell)


func _reachable_by_any(group: Array[SimUnit], cell: Vector2i) -> bool:
	for unit: SimUnit in group:
		if _reachable(unit, cell):
			return true
	return false


func _layer(unit: SimUnit) -> Dictionary[Vector2i, int]:
	return _air_res if unit.is_air() else _ground_res


func _can_enter(unit: SimUnit, cell: Vector2i) -> bool:
	if not unit.is_air() and not grid.is_passable(cell):
		return false
	var holder: int = _layer(unit).get(cell, -1)
	return holder == -1 or holder == unit.id


func _move(unit: SimUnit) -> void:
	var budget: float = unit.stats.move_speed * (1.0 + unit.aura_move_speed_bonus) * TICK_SECONDS
	while budget > EPSILON:
		if not unit.stepping:
			if unit.path.is_empty():
				break
			var next: Vector2i = unit.path[0]
			if not _can_enter(unit, next):
				_on_blocked(unit)
				return
			unit.blocked_ticks = 0
			unit.path.remove_at(0)
			unit.step_cell = next
			unit.stepping = true
			_layer(unit)[next] = unit.id
		var goal: Vector2 = SimUnit.cell_center(unit.step_cell)
		var dist: float = unit.pos.distance_to(goal)
		if dist <= budget + EPSILON:
			unit.pos = goal
			budget -= dist
			var layer: Dictionary[Vector2i, int] = _layer(unit)
			if layer.get(unit.occupied_cell, -1) == unit.id:
				layer.erase(unit.occupied_cell)
			unit.occupied_cell = unit.step_cell
			unit.stepping = false
			if _target_in_range(unit):
				unit.path.clear()  # chasing: stop on the first cell in range
				_clear_destination(unit)
				break
		else:
			unit.pos += (goal - unit.pos) / dist * budget
			budget = 0.0
	if not unit.stepping and unit.path.is_empty() and unit.has_destination:
		_clear_destination(unit)


func _on_blocked(unit: SimUnit) -> void:
	unit.blocked_ticks += 1
	if unit.blocked_ticks % REPATH_AFTER_TICKS == 0 and unit.has_destination:
		var others: Array[Vector2i] = []
		var layer: Dictionary[Vector2i, int] = _layer(unit)
		for cell: Vector2i in layer:
			if layer[cell] != unit.id:
				others.append(cell)
		var detour: Array[Vector2i] = pathfinder.find_path(unit.occupied_cell, unit.destination, unit.is_air(), others)
		if not detour.is_empty():
			unit.path = detour
	if unit.blocked_ticks >= GIVE_UP_AFTER_TICKS:
		unit.blocked_ticks = 0
		_clear_destination(unit)
		unit.path.clear()
		if not unit.retargeted:
			# The spot may have been taken: choose the nearest free cell again.
			unit.retargeted = true
			var group: Array[SimUnit] = [unit]
			var stops: Dictionary[int, Vector2i] = _assign_stops(group, unit.order_target)
			if stops.has(unit.id) and stops[unit.id] != unit.occupied_cell:
				_set_destination(unit, stops[unit.id])


func _spawn_roster(roster: Array[UnitStats], team: SimUnit.Team, spawns: Array[Vector2i]) -> String:
	if roster.size() > spawns.size():
		return "%d units but only %d spawn cells for team %d" % [roster.size(), spawns.size(), team]
	for i: int in roster.size():
		if roster[i] == null:
			return "roster entry %d is null for team %d" % [i, team]
		if spawn_unit(roster[i], team, spawns[i]) == null:
			return "spawn cell %s is not free" % spawns[i]
	return ""
