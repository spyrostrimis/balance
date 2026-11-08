extends Node3D
## Mission 1 scene. Sets up the sim from mission data, builds the 3D view, runs
## the sim on its fixed tick, interpolates the view between ticks and turns sim
## events (shots, abilities, deaths, downed heroes) into effects. The player's
## hero gets the portrait + ability bar (HeroPanel).

const MISSION_PATH: String = "res://data/missions/mission_01.tres"
## The camera pivot stays this far (world units) inside the map edge.
const CAMERA_EDGE_INSET: float = 8.0
## Never run more than this many sim ticks in one frame (avoids a spiral after a hitch).
const MAX_TICKS_PER_FRAME: int = 5

@onready var map_view: MapView = $MapView
@onready var units_root: Node3D = $Units
@onready var rts_camera: RTSCamera = $RTSCamera
@onready var selection: SelectionController = $UI/Selection
@onready var fps_label: Label = $UI/FpsLabel
@onready var selection_label: Label = $UI/SelectionLabel
@onready var health_bars: HealthBars = $UI/HealthBars
@onready var effects: Node3D = $Effects

var world: SimWorld = SimWorld.new()
var unit_views: Array[UnitView] = []
var _views_by_id: Dictionary[int, UnitView] = {}
var _tick_accumulator: float = 0.0
var _fps_timer: float = 0.0
var hero_panel: HeroPanel
var _target_hint: Label
var _player_hero: UnitView
## Self-test: abilities used per team.
var _selftest_casts: Dictionary[SimUnit.Team, int] = {SimUnit.Team.BLUE: 0, SimUnit.Team.RED: 0}


func _ready() -> void:
	var data: MissionData = load(MISSION_PATH) as MissionData
	var err: String = world.setup_mission(data)
	if err != "":
		push_error("Failed to set up %s: %s" % [MISSION_PATH, err])
		return
	map_view.build(world.grid)
	for unit: SimUnit in world.units:
		var view: UnitView = UnitView.new()
		units_root.add_child(view)
		view.setup(unit, world)
		unit_views.append(view)
		_views_by_id[unit.id] = view

	rts_camera.bounds = GridSpace.map_rect(world.grid.size()).grow(-CAMERA_EDGE_INSET)
	rts_camera.snap_to(_spawn_center(world.grid.blue_spawns), rts_camera.start_distance)

	selection.world = world
	selection.camera = rts_camera.camera
	selection.marker_parent = effects
	selection.set_unit_views(unit_views.duplicate())
	health_bars.camera = rts_camera.camera
	health_bars.views = unit_views
	selection.selection_changed.connect(_on_selection_changed)
	_on_selection_changed(0)
	_build_hero_hud()

	if App.is_selftest:
		rts_camera.edge_pan_enabled = false
		App.selftest_shot.connect(_on_selftest_shot)
		_selftest_setup()


func _process(delta: float) -> void:
	if App.is_selftest:
		# Deterministic: exactly one sim tick per frame, whatever the frame rate.
		_tick_accumulator = SimWorld.TICK_SECONDS
		delta = SimWorld.TICK_SECONDS
	else:
		_tick_accumulator += delta
	var ticks: int = 0
	while _tick_accumulator >= SimWorld.TICK_SECONDS and ticks < MAX_TICKS_PER_FRAME:
		if App.is_selftest:
			_selftest_use_abilities()
		world.step()
		_handle_events()
		_tick_accumulator -= SimWorld.TICK_SECONDS
		ticks += 1
	if ticks == MAX_TICKS_PER_FRAME:
		_tick_accumulator = minf(_tick_accumulator, SimWorld.TICK_SECONDS)
	var alpha: float = clampf(_tick_accumulator / SimWorld.TICK_SECONDS, 0.0, 1.0)
	for view: UnitView in unit_views:
		view.sync(alpha, delta)

	_fps_timer -= delta
	if _fps_timer <= 0.0:
		_fps_timer = 0.5
		fps_label.text = "%d FPS" % Engine.get_frames_per_second()


func _handle_events() -> void:
	for event: CombatEvent in world.events:
		var view: UnitView = _views_by_id.get(event.unit_id, null)
		match event.kind:
			CombatEvent.Kind.SHOT:
				var target: UnitView = _views_by_id.get(event.other_id, null)
				if view != null and target != null:
					Effects.shot(effects, view.muzzle_point(), target.pick_center(), UnitView.TEAM_COLORS[view.unit.team])
			CombatEvent.Kind.ABILITY:
				var target_view: UnitView = _views_by_id.get(event.other_id, null)
				if view == null or target_view == null:
					continue
				_selftest_casts[view.unit.team] += 1
				var ability: AbilityStats = view.unit.ability(event.ability_index)
				if ability == null:
					continue
				match ability.effect:
					AbilityStats.Effect.HEAL:
						Effects.heal(effects, view.muzzle_point(), target_view.pick_center())
					AbilityStats.Effect.DAMAGE:
						Effects.cannon(effects, view.muzzle_point(), target_view.pick_center(),
								ability.splash_radius * GridSpace.CELL_SIZE)
			CombatEvent.Kind.DIED:
				if view != null:
					unit_views.erase(view)
					_views_by_id.erase(event.unit_id)
					selection.remove_view(view)
					view.die()
			CombatEvent.Kind.DOWNED:
				if view != null:
					view.set_downed()


## Portrait + ability bar for the player's hero, and the targeting prompt.
func _build_hero_hud() -> void:
	for view: UnitView in unit_views:
		if view.unit.team == selection.player_team and view.unit.stats.is_hero:
			_player_hero = view
			break
	if _player_hero == null:
		return
	selection.hero_view = _player_hero
	hero_panel = HeroPanel.new()
	$UI.add_child(hero_panel)
	hero_panel.setup(_player_hero.unit)
	hero_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 16)
	hero_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hero_panel.ability_pressed.connect(func(index: int) -> void: selection.begin_ability(index))
	hero_panel.portrait_clicked.connect(_on_portrait_clicked)
	selection.inspect_changed.connect(_on_inspect_changed)
	_target_hint = Label.new()
	_target_hint.add_theme_font_size_override("font_size", 24)
	_target_hint.add_theme_color_override("font_color", Color(0.6, 1.0, 0.65))
	_target_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	_target_hint.add_theme_constant_override("outline_size", 6)
	_target_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_target_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UI.add_child(_target_hint)
	_target_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_target_hint.offset_left = -700.0
	_target_hint.offset_right = 700.0
	_target_hint.offset_top = -300.0
	_target_hint.offset_bottom = -260.0
	selection.targeting_changed.connect(func(index: int, prompt: String) -> void:
		_target_hint.text = prompt
		hero_panel.set_armed(index))


## Clicking an enemy hero shows its portrait and abilities (read-only);
## anything else brings back the player's hero.
func _on_inspect_changed(view: UnitView) -> void:
	if view != null and view.unit.stats.is_hero:
		hero_panel.setup(view.unit, true)
	elif hero_panel.unit != _player_hero.unit:
		hero_panel.setup(_player_hero.unit, false)
		hero_panel.set_armed(selection.targeting_index())


func _on_portrait_clicked(double_click: bool) -> void:
	if not is_instance_valid(_player_hero):
		return
	if hero_panel.read_only:
		var shown: UnitView = _views_by_id.get(hero_panel.unit.id, null)
		if double_click and shown != null:
			rts_camera.snap_to(shown.global_position, rts_camera.get_distance())
		return
	if selection.is_targeting():
		selection.cast_on(_player_hero)  # e.g. Repair on the Leader itself
		return
	var only: Array[UnitView] = [_player_hero]
	selection.set_selection(only)
	if double_click:
		rts_camera.snap_to(_player_hero.global_position, rts_camera.get_distance())


func _on_selection_changed(count: int) -> void:
	selection_label.text = "Selected: %d" % count if count > 0 else ""


func _spawn_center(cells: Array[Vector2i]) -> Vector3:
	if cells.is_empty():
		return GridSpace.gridf_to_world(Vector2(world.grid.size()) * 0.5)
	var sum: Vector2 = Vector2.ZERO
	for cell: Vector2i in cells:
		sum += SimUnit.cell_center(cell)
	return GridSpace.gridf_to_world(sum / cells.size())


func _team_center(team: SimUnit.Team) -> Vector3:
	var sum: Vector3 = Vector3.ZERO
	var count: int = 0
	for view: UnitView in unit_views:
		if view.unit.team == team:
			sum += view.global_position
			count += 1
	return sum / maxi(count, 1)


## Self-test: select all Blue units through the same API the mouse uses, check
## picking/box-selection math, then order an attack on the Red Leader.
func _selftest_setup() -> void:
	var own: Array[UnitView] = []
	for view: UnitView in unit_views:
		if view.unit.team == SimUnit.Team.BLUE:
			own.append(view)
	# Picking round trip: clicking a unit's projected centre must hit that unit.
	await get_tree().process_frame
	var hits: int = 0
	for view: UnitView in own:
		if selection.unit_at(rts_camera.camera.unproject_position(view.pick_center())) == view:
			hits += 1
	App.selftest_note("pick round trip: %d/%d own units hit" % [hits, own.size()])
	selection.select_in_rect(get_viewport().get_visible_rect(), false)
	App.selftest_note("box select (whole screen): %d selected" % selection.selected_views().size())
	for view: UnitView in unit_views:
		if view.unit.team == SimUnit.Team.RED and view.unit.stats.is_hero:
			selection.order_attack(view)


## Self-test stand-in for the player and the (future) AI: each hero uses its
## active ability as soon as it's ready and there's a good target. Blue goes
## through the real targeting UI; Red queues the command directly.
func _selftest_use_abilities() -> void:
	for view: UnitView in unit_views:
		var hero: SimUnit = view.unit
		if not hero.stats.is_hero or not hero.can_act():
			continue
		for i: int in hero.stats.abilities.size():
			var ability: AbilityStats = hero.ability(i)
			if ability == null or not ability.is_active() or not hero.ability_ready(i) or hero.is_casting():
				continue
			var target: UnitView = _selftest_pick_target(hero, ability)
			if target == null:
				continue
			if view == _player_hero:
				if selection.begin_ability(i):
					selection.cast_on(target)
			else:
				world.queue_command(AbilityCommand.new(hero.team, hero.id, i, target.unit.id))


func _selftest_pick_target(hero: SimUnit, ability: AbilityStats) -> UnitView:
	var best: UnitView = null
	var best_score: float = INF
	for view: UnitView in unit_views:
		var other: SimUnit = view.unit
		if not world.is_valid_cast_target(hero, ability, other):
			continue
		var dist: float = hero.pos.distance_to(other.pos)
		if dist > ability.cast_range + 2.0:
			continue
		var score: float = dist
		if ability.target == AbilityStats.Target.ALLY:
			if other.hp_fraction() > 0.75:
				continue
			score = other.hp_fraction()  # most damaged first
		if score < best_score:
			best = view
			best_score = score
	return best


## Poses: Blue on the way, the fight (x2), whole map, aftermath close-up.
func _on_selftest_shot(index: int, _total: int) -> void:
	var map_center: Vector3 = GridSpace.gridf_to_world(Vector2(world.grid.size()) * 0.5)
	var fight: Vector3 = (_team_center(SimUnit.Team.BLUE) + _team_center(SimUnit.Team.RED)) * 0.5
	# Shot 2: look at the Red Leader (read-only panel). Shot 3: debug overlay on.
	App.debug_overlay = index == 3
	App.debug_overlay_changed.emit(App.debug_overlay)
	if index == 2:
		for view: UnitView in unit_views:
			if view.unit.team != selection.player_team and view.unit.stats.is_hero:
				selection.set_inspected(view)
		App.selftest_note("inspect: panel shows %s (read-only: %s)" % [hero_panel.unit.stats.display_name, hero_panel.read_only])
	elif index == 3:
		selection.set_inspected(null)
		App.selftest_note("inspect cleared: panel shows %s" % hero_panel.unit.stats.display_name)
	match (index - 1) % 5:
		0:
			rts_camera.snap_to(_team_center(SimUnit.Team.BLUE), rts_camera.start_distance)
		1, 2:
			rts_camera.snap_to(fight, rts_camera.min_distance + 6.0)
		3:
			rts_camera.snap_to(map_center, rts_camera.max_distance)
		4:
			rts_camera.snap_to(fight, rts_camera.min_distance + 4.0)
	var summary: PackedStringArray = PackedStringArray()
	for team: SimUnit.Team in [SimUnit.Team.BLUE, SimUnit.Team.RED]:
		var alive: int = 0
		var hp: int = 0
		var downed: int = 0
		for unit: SimUnit in world.units:
			if unit.team != team:
				continue
			if unit.downed:
				downed += 1
			else:
				alive += 1
				hp += unit.hp
		var buffed: int = 0
		for unit: SimUnit in world.units:
			if unit.team == team and unit.in_any_aura():
				buffed += 1
		summary.append("%s: %d up (%d hp), %d downed, %d in aura, %d abilities used" % [
				"blue" if team == SimUnit.Team.BLUE else "red", alive, hp, downed, buffed, _selftest_casts[team]])
	App.selftest_note("shot %d (tick %d): %s; views %d" % [index, world.tick, ", ".join(summary), unit_views.size()])
