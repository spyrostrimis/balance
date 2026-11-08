extends Node3D
## Mission 1 scene. Sets up the sim from mission data, builds the 3D view, runs
## the sim on its fixed tick, interpolates the view between ticks and turns sim
## events (shots, abilities, deaths, downed heroes) into effects. The player's
## hero gets the portrait + ability bar (HeroPanel). Mission flow: a start screen
## (the sim waits), the capture objective (zone on the map + panel), and an end
## screen on victory or defeat.

const MISSION_PATH: String = "res://data/missions/mission_01_desert.tres"
const TEAM_NAMES: Dictionary[SimUnit.Team, String] = {SimUnit.Team.BLUE: "Blue", SimUnit.Team.RED: "Red"}
## The camera pivot stays this far (world units) inside the map edge.
const CAMERA_EDGE_INSET: float = 8.0
## Never run more than this many sim ticks in one frame (avoids a spiral after a hitch).
const MAX_TICKS_PER_FRAME: int = 5

@onready var map_view: MapView = $MapView
@onready var units_root: Node3D = $Units
@onready var rts_camera: RTSCamera = $RTSCamera
@onready var selection: SelectionController = $UI/Selection
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
var _alerts: Alerts
var _warning: LowHpWarning
var _warning_sound: AudioStreamPlayer
var _recovery_views: Dictionary[int, RecoveryView] = {}
var _start_screen: StartScreen
var _end_screen: EndScreen
var _objective_panel: ObjectivePanel
var _top_bar: TopBar
var _sidebar: Sidebar
var _pause_menu: PauseMenu
var _paused: bool = false
var _mission_name: String = ""
## The sim only runs after Start.
var _started: bool = false
## Units that died per team (for the end screen).
var _deaths: Dictionary[SimUnit.Team, int] = {SimUnit.Team.BLUE: 0, SimUnit.Team.RED: 0}
var _enemy_hero_downs: int = 0
var _frame: int = 0
## Self-test: press Start at this frame (just after shot 1 captured the start screen).
var _selftest_start_frame: int = -1
## Self-test: when the low-HP warning fired and when the player's hero went down.
var _warning_tick: int = -1
var _player_down_tick: int = -1
## Self-test: abilities used per team.
var _selftest_casts: Dictionary[SimUnit.Team, int] = {SimUnit.Team.BLUE: 0, SimUnit.Team.RED: 0}


func _ready() -> void:
	var data: MissionData = load(MISSION_PATH) as MissionData
	var err: String = world.setup_mission(data)
	if err != "":
		push_error("Failed to set up %s: %s" % [MISSION_PATH, err])
		return
	var look_path: String = "res://data/looks/%s.tres" % data.look
	UnitView.current_look = load(look_path) as Look if ResourceLoader.exists(look_path) else null
	if UnitView.current_look != null:
		rts_camera.set_angle(UnitView.current_look.camera_pitch_degrees, UnitView.current_look.camera_fov_degrees)
	map_view.build(world.grid, UnitView.current_look)
	_apply_lighting(UnitView.current_look)
	for unit: SimUnit in world.units:
		var view: UnitView = UnitView.new()
		units_root.add_child(view)
		view.setup(unit, world)
		unit_views.append(view)
		_views_by_id[unit.id] = view

	rts_camera.bounds = GridSpace.map_rect(world.grid.size()).grow(-CAMERA_EDGE_INSET)
	rts_camera.snap_to(_spawn_center(_spawns(world.player_team)), rts_camera.start_distance)

	selection.world = world
	selection.player_team = world.player_team
	selection.camera = rts_camera.camera
	selection.marker_parent = effects
	selection.set_unit_views(unit_views.duplicate())
	health_bars.camera = rts_camera.camera
	health_bars.views = unit_views
	_mission_name = "Mission 1 — %s" % data.display_name
	HudTheme.accent = UnitView.TEAM_COLORS[world.player_team]
	_build_hud()
	selection.selection_changed.connect(_on_selection_changed)
	_build_hero_hud()
	_sidebar.hold_hero_panel(hero_panel)
	_on_selection_changed(0)
	_alerts = Alerts.new()
	$UI.add_child(_alerts)
	_alerts.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_alerts.offset_left = 24.0
	_alerts.offset_right = -Sidebar.WIDTH - 24.0
	_alerts.offset_top = 80.0
	_alerts.offset_bottom = 280.0
	_warning = LowHpWarning.new(world.rules.low_hp_warning_fraction)
	_warning_sound = AudioStreamPlayer.new()
	_warning_sound.stream = Sounds.warning()
	_warning_sound.volume_db = -6.0
	add_child(_warning_sound)
	if world.objective != null:
		var zone: ZoneView = ZoneView.new()
		map_view.add_child(zone)
		zone.setup(world.objective)
		_objective_panel = _sidebar.objective_panel
	_show_start_screen(data)

	if App.is_selftest:
		rts_camera.edge_pan_enabled = false
		App.selftest_shot.connect(_on_selftest_shot)
		_selftest_setup()


func _process(delta: float) -> void:
	_frame += 1
	if App.is_selftest and not _started and _selftest_start_frame != -1 and _frame >= _selftest_start_frame:
		_start_mission()
	if not _started or _paused:
		_tick_accumulator = 0.0
	elif App.is_selftest:
		# Deterministic: exactly one sim tick per frame, whatever the frame rate.
		_tick_accumulator = SimWorld.TICK_SECONDS
		delta = SimWorld.TICK_SECONDS
	else:
		_tick_accumulator += delta
	var ticks: int = 0
	if world.outcome != SimWorld.Outcome.NONE:
		_tick_accumulator = 0.0  # mission over: the sim stops
	while _started and _tick_accumulator >= SimWorld.TICK_SECONDS and ticks < MAX_TICKS_PER_FRAME \
			and world.outcome == SimWorld.Outcome.NONE:
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
	for recovery_view: RecoveryView in _recovery_views.values():
		recovery_view.sync(alpha, delta)
		var carried: UnitView = _views_by_id.get(recovery_view.recovery.hero_id, null)
		if carried != null and carried.unit.carried:
			carried.position = recovery_view.carry_point()
	_update_low_hp_warning()

	_fps_timer -= delta
	if _fps_timer <= 0.0:
		_fps_timer = 0.5
		_top_bar.set_fps(Engine.get_frames_per_second())
	_top_bar.set_time(world.tick / SimWorld.TICKS_PER_SECOND)


func _handle_events() -> void:
	for event: CombatEvent in world.events:
		var view: UnitView = _views_by_id.get(event.unit_id, null)
		match event.kind:
			CombatEvent.Kind.SHOT:
				var target: UnitView = _views_by_id.get(event.other_id, null)
				if view != null and target != null:
					view.play_attack()
					Effects.shot(effects, view.muzzle_point(), target.pick_center(), UnitView.TEAM_COLORS[view.unit.team])
			CombatEvent.Kind.ABILITY:
				var target_view: UnitView = _views_by_id.get(event.other_id, null)
				if view == null or target_view == null:
					continue
				_selftest_casts[view.unit.team] += 1
				view.play_attack()
				var ability: AbilityStats = view.unit.ability(event.ability_index)
				if ability == null:
					continue
				match ability.effect:
					AbilityStats.Effect.HEAL:
						Effects.heal(effects, view.muzzle_point(), target_view.pick_center())
					AbilityStats.Effect.DAMAGE:
						Effects.cannon(effects, view.muzzle_point(), target_view.pick_center(),
								ability.splash_radius * GridSpace.CELL_SIZE)
			CombatEvent.Kind.ROCK_CAPTURED:
				var mine: bool = event.other_id == selection.player_team
				_alerts.show_alert("You have taken the rock! Keep enemies out of the zone for %d s." % roundi(world.objective.rules.hold_seconds)
						if mine else "%s has taken the rock! Get into the zone to stop its clock." % TEAM_NAMES[_enemy_team()],
						Color(0.5, 0.75, 1.0) if mine else Color(1.0, 0.45, 0.35))
			CombatEvent.Kind.MISSION_WON:
				_show_end(true, event.amount as SimWorld.Reason)
			CombatEvent.Kind.DIED:
				if view != null:
					_deaths[view.unit.team] += 1
				if view != null:
					unit_views.erase(view)
					_views_by_id.erase(event.unit_id)
					selection.remove_view(view)
					if view.blast_size() > 0.0:
						Effects.explosion(effects, view.global_position, view.blast_size())
					view.die()
			CombatEvent.Kind.DOWNED:
				if view != null:
					view.set_downed()
					Effects.smoke(effects, view.global_position, 1.6, 3.0)
					Effects.burst(effects, view.pick_center(), Color(1.0, 0.75, 0.3, 1.0), 12, 0.5, 5.0, 0.22)
					if view.unit.team != selection.player_team:
						_enemy_hero_downs += 1
					if view == _player_hero:
						_player_down_tick = world.tick
						_alerts.show_alert("Your %s is down!" % view.unit.stats.display_name, Color(1.0, 0.35, 0.3))
			CombatEvent.Kind.RECOVERY_SENT:
				for recovery: SimRecovery in world.recoveries:
					if recovery.id == event.other_id and view != null:
						var ship: RecoveryView = RecoveryView.new()
						effects.add_child(ship)
						ship.setup(recovery, view.global_position)
						_recovery_views[recovery.id] = ship
						_alerts.show_alert("%s is down. A dropship is coming to recover it." % view.unit.stats.display_name,
								Color(1.0, 0.85, 0.4))
			CombatEvent.Kind.HERO_AWAY:
				var ship_gone: RecoveryView = _recovery_views.get(event.other_id, null)
				if ship_gone != null:
					_recovery_views.erase(event.other_id)
					ship_gone.queue_free()
				if view != null:
					view.visible = false
					_alerts.show_alert("%s has left the field. Back in %d s." % [view.unit.stats.display_name,
							ceili(event.amount / float(SimWorld.TICKS_PER_SECOND))], Color(1.0, 0.85, 0.4))
			CombatEvent.Kind.HERO_RETURNED:
				if view != null:
					view.set_revived()
					_alerts.show_alert("%s has returned." % view.unit.stats.display_name, Color(1.0, 0.6, 0.4))
			CombatEvent.Kind.MISSION_FAILED:
				_show_end(false, event.amount as SimWorld.Reason)


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
	_target_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_target_hint.offset_left = 24.0
	_target_hint.offset_right = -Sidebar.WIDTH - 24.0
	_target_hint.offset_top = -90.0
	_target_hint.offset_bottom = -50.0
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


## Low-HP warning for the player's hero: alert + sound once, portrait pulses.
func _update_low_hp_warning() -> void:
	if _player_hero == null or not is_instance_valid(_player_hero):
		return
	var hero: SimUnit = _player_hero.unit
	if _warning.update(hero.hp_fraction(), hero.can_act()):
		_warning_tick = world.tick
		_alerts.show_alert("Warning: your %s is badly damaged!" % hero.stats.display_name, Color(1.0, 0.3, 0.25))
		_warning_sound.play()
	if hero_panel != null:
		hero_panel.warning = _warning.active and hero_panel.unit == hero


func _show_start_screen(data: MissionData) -> void:
	_start_screen = StartScreen.new()
	$UI.add_child(_start_screen)
	var hold: int = 60
	var capture: int = 10
	if world.objective != null:
		hold = roundi(world.objective.rules.hold_seconds)
		capture = roundi(world.objective.rules.capture_seconds)
	var enemy: String = TEAM_NAMES[_enemy_team()]
	var mine: String = TEAM_NAMES[world.player_team]
	_start_screen.setup("Mission 1 — %s" % data.display_name, data.briefing,
			PackedStringArray([
				"Capture the rock: have only your units in the marked zone for %d s." % capture,
				"Hold it for %d s with no enemy in the zone. Any enemy in the zone resets the clock." % hold,
				"Or destroy every %s troop while the %s Leader is down." % [enemy, enemy],
				"Your Leader must not fall: if the %s Leader goes down, the mission fails." % mine,
				"%s wins if it holds the rock for %d s." % [enemy, hold],
			]))
	_start_screen.start_pressed.connect(_start_mission)


func _start_mission() -> void:
	if _started:
		return
	_started = true
	if _start_screen != null:
		_start_screen.queue_free()
		_start_screen = null


func _show_end(victory: bool, reason: SimWorld.Reason) -> void:
	if _end_screen != null:
		return
	selection.cancel_ability()
	var hero_name: String = _player_hero.unit.stats.display_name if _player_hero != null else "Leader"
	var why: String = ""
	match reason:
		SimWorld.Reason.HERO_DOWN:
			why = "Your %s is down." % hero_name
		SimWorld.Reason.ROCK_HELD:
			why = "You held the Orichalcum rock." if victory else "%s held the Orichalcum rock." % TEAM_NAMES[_enemy_team()]
		SimWorld.Reason.ENEMY_ROUTED:
			why = "%s's army is destroyed and its Leader is down." % TEAM_NAMES[_enemy_team()]
	var seconds: int = world.tick / SimWorld.TICKS_PER_SECOND
	var enemy: SimUnit.Team = _enemy_team()
	var details: PackedStringArray = PackedStringArray([
		"Time: %d:%02d" % [seconds / 60, seconds % 60],
		"Your units lost: %d   ·   Enemy units destroyed: %d   ·   Enemy Leader downed: %d" % [
				_deaths[selection.player_team], _deaths[enemy], _enemy_hero_downs],
	])
	_end_screen = EndScreen.new()
	$UI.add_child(_end_screen)
	_end_screen.setup(victory, why, details)
	_end_screen.restart_pressed.connect(func() -> void: get_tree().reload_current_scene())
	_end_screen.quit_pressed.connect(func() -> void: get_tree().quit())
	if App.is_selftest:
		App.selftest_note("end screen: %s; %s; %s" % ["VICTORY" if victory else "DEFEAT", why, " / ".join(details)])


## Dune II-style HUD: top bar, right sidebar (objective, hero, commands,
## minimap) and the Options menu.
func _build_hud() -> void:
	_top_bar = TopBar.new()
	$UI.add_child(_top_bar)
	_top_bar.setup(_mission_name)
	_top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE)
	_top_bar.options_pressed.connect(_toggle_pause)
	_sidebar = Sidebar.new()
	$UI.add_child(_sidebar)
	_sidebar.setup(world, rts_camera.camera)
	_sidebar.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE, Control.PRESET_MODE_MINSIZE)
	_sidebar.offset_top = _top_bar.get_combined_minimum_size().y
	_sidebar.offset_left = -Sidebar.WIDTH
	_sidebar.command_pressed.connect(_on_command)
	_sidebar.minimap.look_at_requested.connect(func(pos: Vector3) -> void:
		rts_camera.snap_to(pos, rts_camera.get_distance()))
	_sidebar.minimap.move_requested.connect(func(cell: Vector2i) -> void: selection.order_move(cell))
	selection.command_mode_changed.connect(func(_mode: int, prompt: String) -> void:
		_sidebar.set_prompt(prompt))


func _on_command(command: StringName) -> void:
	match command:
		&"attack":
			selection.begin_command(SelectionController.Mode.ATTACK)
		&"move":
			selection.begin_command(SelectionController.Mode.MOVE)
		&"retreat":
			selection.retreat_selected()
		&"guard":
			selection.guard_selected()


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F10 and _started and _end_screen == null:
		_toggle_pause()
		get_viewport().set_input_as_handled()


## Options menu: pauses the sim while open.
func _toggle_pause() -> void:
	if _pause_menu != null:
		_pause_menu.queue_free()
		_pause_menu = null
		_paused = false
		return
	if _end_screen != null:
		return
	_paused = true
	_pause_menu = PauseMenu.new()
	$UI.add_child(_pause_menu)
	_pause_menu.setup()
	_pause_menu.resume_pressed.connect(_toggle_pause)
	_pause_menu.restart_pressed.connect(func() -> void: get_tree().reload_current_scene())
	_pause_menu.quit_pressed.connect(func() -> void: get_tree().quit())


func _on_selection_changed(count: int) -> void:
	var names: Dictionary[String, int] = {}
	for view: UnitView in selection.selected_views():
		var n: String = view.unit.stats.display_name
		names[n] = names.get(n, 0) + 1
	var parts: PackedStringArray = PackedStringArray()
	for n: String in names:
		parts.append(n if names[n] == 1 else "%d× %s" % [names[n], n])
	if _sidebar != null:
		_sidebar.set_selection_text(count, ", ".join(parts))


## The look's environment (sky, fog, grading) and sun.
func _apply_lighting(look: Look) -> void:
	if look == null:
		return
	if look.environment != null:
		($WorldEnvironment as WorldEnvironment).environment = look.environment
	var sun: DirectionalLight3D = $Sun as DirectionalLight3D
	sun.light_color = look.sun_color
	sun.light_energy = look.sun_energy
	sun.rotation_degrees = look.sun_rotation_degrees


func _enemy_team() -> SimUnit.Team:
	return SimUnit.Team.RED if world.player_team == SimUnit.Team.BLUE else SimUnit.Team.BLUE


func _spawns(team: SimUnit.Team) -> Array[Vector2i]:
	return world.grid.blue_spawns if team == SimUnit.Team.BLUE else world.grid.red_spawns


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


## Self-test: select all the player's units through the same API the mouse uses,
## check picking/box-selection math, then send them to the rock (the AI plays
## the other side).
func _selftest_setup() -> void:
	var own: Array[UnitView] = []
	for view: UnitView in unit_views:
		if view.unit.team == world.player_team:
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
	if world.objective != null:
		var c: Vector2 = world.objective.center()
		# Approach from the player's side of the rock.
		var side: Vector2 = (SimUnit.cell_center(_spawns(world.player_team)[0]) - c).normalized()
		selection.order_move(Vector2i(floori(c.x + side.x * 2.5), floori(c.y + side.y * 2.5)))


## Self-test stand-in for the player: the Blue Leader uses its active ability
## (through the real targeting UI) as soon as it's ready and there's a good
## target. Red is played by its AI.
func _selftest_use_abilities() -> void:
	for view: UnitView in unit_views:
		var hero: SimUnit = view.unit
		if view != _player_hero or not hero.can_act():
			continue
		for i: int in hero.stats.abilities.size():
			var ability: AbilityStats = hero.ability(i)
			if ability == null or not ability.is_active() or not hero.ability_ready(i) or hero.is_casting():
				continue
			var target: UnitView = _selftest_pick_target(hero, ability)
			if target == null:
				continue
			if selection.begin_ability(i):
				selection.cast_on(target)


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
	if index == 1:
		_selftest_start_frame = _frame + 8  # shot 1 shows the start screen
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
	var ship_pose: bool = index == 2 and not _recovery_views.is_empty()
	match (index - 1) % 5 if not ship_pose else -1:
		-1:
			var ship: RecoveryView = _recovery_views.values()[0] as RecoveryView
			rts_camera.snap_to(Vector3(ship.position.x, 0.0, ship.position.z), rts_camera.min_distance + 8.0)
		0:
			rts_camera.snap_to(_team_center(world.player_team), rts_camera.start_distance)
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
	App.selftest_note("shot %d (tick %d): %s; views %d; recoveries %d; outcome %d" % [index, world.tick,
			", ".join(summary), unit_views.size(), world.recoveries.size(), world.outcome])
	App.selftest_note("  alerts so far: %s" % " | ".join(_alerts.history))
	if world.objective != null:
		App.selftest_note("  rock: %s (started %s)" % [ObjectivePanel.describe(world.objective)["text"], _started])
	App.selftest_note("  low-HP warning tick %d, player hero down tick %d" % [_warning_tick, _player_down_tick])
