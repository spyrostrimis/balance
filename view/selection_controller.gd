class_name SelectionController
extends Control
## Player selection and orders. Full-screen overlay (ignores the mouse itself;
## reads unhandled input) that draws the drag box.
##   Left click unit: select it (Shift: add/remove).  Left click ground: clear.
##   Left click enemy: look at it (red ring, can't be ordered; for heroes the
##   hero panel shows its abilities).
##   Left drag: box-select own units (Shift: add).
##   Right click enemy: attack it (red marker).  Right click elsewhere: move (units
##   stop on the nearest free cells; red marker = the clicked cell itself is blocked).
##   Esc: clear selection.
##   Q (action ability_1): target the player hero's first active ability, then
##   left click a valid unit to use it. Right click / Esc cancels.
##   Sidebar commands: Attack (then left click an enemy), Move (then left click
##   the ground), Retreat (R) and Guard (G) act on the selection at once.
## Orders go to the sim as commands; this node never changes sim state directly.

signal selection_changed(count: int)
## Ability targeting started (index, prompt text) or ended (-1, "").
signal targeting_changed(index: int, prompt: String)
## The enemy unit the player is looking at changed (null = none).
signal inspect_changed(view: UnitView)
## Attack / Move command waiting for a click started (mode, prompt) or ended (NONE, "").
signal command_mode_changed(mode: int, prompt: String)

enum Mode { NONE, ATTACK, MOVE }

const DRAG_THRESHOLD_PX: float = 6.0
const BOX_FILL: Color = Color(0.3, 1.0, 0.35, 0.12)
const BOX_LINE: Color = Color(0.3, 1.0, 0.35, 0.9)
const MARKER_COLOR: Color = Color(0.3, 1.0, 0.35)
const MARKER_BLOCKED_COLOR: Color = Color(1.0, 0.3, 0.25)
const MARKER_SECONDS: float = 0.6

var world: SimWorld
var camera: Camera3D
var player_team: SimUnit.Team = SimUnit.Team.BLUE
## Parent for move markers (3D).
var marker_parent: Node3D
## The player's hero (abilities, portrait).
var hero_view: UnitView

## Ability whose target is being chosen, or -1.
var _targeting: int = -1
## Enemy unit being looked at, or null.
var inspected: UnitView
## Attack / Move button pressed: the next left click picks the target.
var mode: Mode = Mode.NONE

var _views: Array[UnitView] = []
var _selected: Array[UnitView] = []
var _press_pos: Vector2 = Vector2.ZERO
var _pressing: bool = false
var _dragging: bool = false
var _drag_end: Vector2 = Vector2.ZERO


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_unit_views(views: Array[UnitView]) -> void:
	_views = views


func selected_views() -> Array[UnitView]:
	return _selected.duplicate()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ability_1", false, true):
		begin_ability(_nth_active(0))
		get_viewport().set_input_as_handled()
		return
	if _targeting != -1 and _targeting_input(event):
		get_viewport().set_input_as_handled()
		return
	if mode != Mode.NONE and _command_input(event):
		get_viewport().set_input_as_handled()
		return
	var hotkey: InputEventKey = event as InputEventKey
	if hotkey != null and hotkey.pressed and not hotkey.echo and not hotkey.ctrl_pressed and not hotkey.alt_pressed:
		if hotkey.physical_keycode == KEY_G:
			guard_selected()
			get_viewport().set_input_as_handled()
			return
		if hotkey.physical_keycode == KEY_R:
			retreat_selected()
			get_viewport().set_input_as_handled()
			return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null:
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_pressing = true
				_dragging = false
				_press_pos = mb.position
				_drag_end = mb.position
			elif _pressing:
				_pressing = false
				if _dragging:
					_dragging = false
					select_in_rect(Rect2(_press_pos, mb.position - _press_pos).abs(), mb.shift_pressed)
					queue_redraw()
				else:
					click_select(mb.position, mb.shift_pressed)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			order_at(mb.position)
			get_viewport().set_input_as_handled()
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and _pressing:
		_drag_end = motion.position
		if not _dragging and _press_pos.distance_to(_drag_end) >= DRAG_THRESHOLD_PX:
			_dragging = true
		if _dragging:
			queue_redraw()
		return
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		clear_selection()
		get_viewport().set_input_as_handled()


## While targeting: left click uses the ability, right click / Esc cancels.
## Returns true if the event was used.
func _targeting_input(event: InputEvent) -> bool:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.pressed:
		if mb.button_index == MOUSE_BUTTON_LEFT:
			var target: UnitView = unit_at(mb.position, false)
			if target == null:
				_show_marker_at_screen(mb.position)
			else:
				cast_on(target)
			return true
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			cancel_ability()
			return true
	if mb != null and not mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		return true
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		cancel_ability()
		return true
	return false


## Attack / Move mode: left click picks the target, right click / Esc cancels.
func _command_input(event: InputEvent) -> bool:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.pressed:
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mode == Mode.ATTACK:
				var enemy: UnitView = unit_at(mb.position, false)
				if enemy != null and enemy.unit.team != player_team and enemy.unit.can_act():
					order_attack(enemy)
					cancel_command()
				else:
					_show_marker_at_screen(mb.position)
			else:
				order_move_at(mb.position)
				cancel_command()
			return true
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			cancel_command()
			return true
	if mb != null and not mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		return true
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		cancel_command()
		return true
	return false


## Attack or Move button: wait for a click (needs a selection).
func begin_command(new_mode: Mode) -> bool:
	if _selected.is_empty() or new_mode == Mode.NONE:
		return false
	cancel_ability()
	mode = new_mode
	_pressing = false
	_dragging = false
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)
	var prompt: String = "Attack: left click an enemy unit." if mode == Mode.ATTACK else "Move: left click the ground."
	command_mode_changed.emit(mode, prompt + "   Right click / Esc: cancel")
	return true


func cancel_command() -> void:
	if mode == Mode.NONE:
		return
	mode = Mode.NONE
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	command_mode_changed.emit(Mode.NONE, "")


func selected_ids() -> Array[int]:
	var ids: Array[int] = []
	for view: UnitView in _selected:
		ids.append(view.unit.id)
	return ids


## Retreat button / R: the selection walks back to the start area.
func retreat_selected() -> void:
	if _selected.is_empty():
		return
	world.queue_command(RetreatCommand.new(player_team, selected_ids()))


## Guard button / G: the selection holds its ground.
func guard_selected() -> void:
	if _selected.is_empty():
		return
	for view: UnitView in _selected:
		_show_marker(view.unit.cell(), true)
	world.queue_command(GuardCommand.new(player_team, selected_ids()))


func is_targeting() -> bool:
	return _targeting != -1


func targeting_index() -> int:
	return _targeting


## Starts choosing a target for the hero's ability `index` (if it can be used now).
func begin_ability(index: int) -> bool:
	if hero_view == null or not is_instance_valid(hero_view) or not hero_view.unit.can_act():
		return false
	var ability: AbilityStats = hero_view.unit.ability(index)
	if ability == null or not ability.is_active() or not hero_view.unit.ability_ready(index):
		return false
	cancel_command()
	_targeting = index
	_pressing = false
	_dragging = false
	queue_redraw()
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)
	var who: String = "a friendly unit (or the portrait for the Leader)" 			if ability.target == AbilityStats.Target.ALLY else "an enemy unit"
	targeting_changed.emit(index, "%s: left click %s.   Right click / Esc: cancel" % [ability.display_name, who])
	return true


func cancel_ability() -> void:
	if _targeting == -1:
		return
	_targeting = -1
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	targeting_changed.emit(-1, "")


## Uses the ability being targeted on `target`. Returns false (red marker, keeps
## targeting) if the target isn't valid for it.
func cast_on(target: UnitView) -> bool:
	if _targeting == -1 or hero_view == null or not is_instance_valid(hero_view):
		return false
	var ability: AbilityStats = hero_view.unit.ability(_targeting)
	if ability == null or not world.is_valid_cast_target(hero_view.unit, ability, target.unit):
		_show_marker(target.unit.cell(), false)
		return false
	_show_marker(target.unit.cell(), true)
	world.queue_command(AbilityCommand.new(player_team, hero_view.unit.id, _targeting, target.unit.id))
	cancel_ability()
	return true


func _nth_active(n: int) -> int:
	if hero_view == null or not is_instance_valid(hero_view):
		return -1
	var seen: int = 0
	for i: int in hero_view.unit.stats.abilities.size():
		var ability: AbilityStats = hero_view.unit.ability(i)
		if ability != null and ability.is_active():
			if seen == n:
				return i
			seen += 1
	return -1


func _show_marker_at_screen(screen_pos: Vector2) -> void:
	var cell_v: Variant = ground_cell_at(screen_pos)
	if cell_v != null:
		_show_marker(cell_v as Vector2i, false)


func _draw() -> void:
	if not _dragging:
		return
	var rect: Rect2 = Rect2(_press_pos, _drag_end - _press_pos).abs()
	draw_rect(rect, BOX_FILL, true)
	draw_rect(rect, BOX_LINE, false, 2.0)


func click_select(screen_pos: Vector2, additive: bool) -> void:
	var hit: UnitView = unit_at(screen_pos)
	if hit == null:
		if additive:
			return
		var other: UnitView = unit_at(screen_pos, false)
		clear_selection()
		if other != null and other.unit.team != player_team:
			set_inspected(other)
		return
	if not additive:
		var only: Array[UnitView] = [hit]
		set_selection(only)
		return
	var next: Array[UnitView] = _selected.duplicate()
	if next.has(hit):
		next.erase(hit)
	else:
		next.append(hit)
	set_selection(next)


## Box selection: own units whose projected centre lies in the screen rect.
func select_in_rect(rect: Rect2, additive: bool) -> void:
	var next: Array[UnitView] = []
	if additive:
		next = _selected.duplicate()
	for view: UnitView in _views:
		if view.unit.team != player_team or next.has(view):
			continue
		var center: Vector3 = view.pick_center()
		if camera.is_position_behind(center):
			continue
		if rect.has_point(camera.unproject_position(center)):
			next.append(view)
	set_selection(next)


func clear_selection() -> void:
	var none: Array[UnitView] = []
	set_selection(none)


## Looks at an enemy unit (red ring). Selecting own units ends it.
func set_inspected(view: UnitView) -> void:
	if inspected == view:
		return
	if inspected != null and is_instance_valid(inspected):
		inspected.inspected = false
	inspected = view
	if inspected != null:
		inspected.inspected = true
	inspect_changed.emit(inspected)


func set_selection(views: Array[UnitView]) -> void:
	set_inspected(null)
	for view: UnitView in _selected:
		view.selected = false
	_selected = views.duplicate()
	for view: UnitView in _selected:
		view.selected = true
	selection_changed.emit(_selected.size())


## Removes a unit view (unit died): from picking and from the selection.
func remove_view(view: UnitView) -> void:
	_views.erase(view)
	if inspected == view:
		set_inspected(null)
	if _selected.has(view):
		_selected.erase(view)
		selection_changed.emit(_selected.size())


## Right click: on an enemy = attack it, anywhere else = move there.
func order_at(screen_pos: Vector2) -> void:
	if _selected.is_empty():
		return
	var enemy: UnitView = unit_at(screen_pos, false)
	if enemy != null and enemy.unit.team != player_team and enemy.unit.can_act():
		order_attack(enemy)
	else:
		order_move_at(screen_pos)


func order_attack(target: UnitView) -> void:
	if _selected.is_empty():
		return
	_show_marker(target.unit.cell(), false)
	var ids: Array[int] = []
	for view: UnitView in _selected:
		ids.append(view.unit.id)
	world.queue_command(AttackCommand.new(player_team, ids, target.unit.id))


## Closest unit under the cursor (ray vs. a sphere around each model), or null.
## `own_only`: only the player's units (selection); otherwise any unit (orders).
func unit_at(screen_pos: Vector2, own_only: bool = true) -> UnitView:
	var origin: Vector3 = camera.project_ray_origin(screen_pos)
	var dir: Vector3 = camera.project_ray_normal(screen_pos)
	var best: UnitView = null
	var best_t: float = INF
	for view: UnitView in _views:
		if own_only and view.unit.team != player_team:
			continue
		if not view.visible or view.unit.carried or view.unit.away:
			continue
		var center: Vector3 = view.pick_center()
		var t: float = (center - origin).dot(dir)
		if t <= 0.0 or t >= best_t:
			continue
		if (origin + dir * t).distance_to(center) <= view.pick_radius:
			best = view
			best_t = t
	return best


## Ground cell under the cursor, or null if the ray misses the ground plane.
func ground_cell_at(screen_pos: Vector2) -> Variant:
	var origin: Vector3 = camera.project_ray_origin(screen_pos)
	var dir: Vector3 = camera.project_ray_normal(screen_pos)
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(origin, dir)
	if hit == null:
		return null
	return GridSpace.world_to_grid(hit as Vector3)


func order_move_at(screen_pos: Vector2) -> void:
	var cell_v: Variant = ground_cell_at(screen_pos)
	if cell_v == null:
		return
	order_move(cell_v as Vector2i)


func order_move(cell: Vector2i) -> void:
	if _selected.is_empty():
		return
	# Red marker: the clicked cell itself can't be stood on; units stop nearby.
	_show_marker(cell, world.is_cell_free(cell) or _selected_unit_on(cell))
	var ids: Array[int] = []
	for view: UnitView in _selected:
		ids.append(view.unit.id)
	world.queue_command(MoveCommand.new(player_team, ids, cell))


func _selected_unit_on(cell: Vector2i) -> bool:
	for view: UnitView in _selected:
		if view.unit.cell() == cell and not view.unit.is_moving():
			return true
	return false


func _show_marker(cell: Vector2i, ok: bool) -> void:
	if marker_parent == null:
		return
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.55
	torus.outer_radius = 0.7
	torus.rings = 24
	torus.ring_segments = 4
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = MARKER_COLOR if ok else MARKER_BLOCKED_COLOR
	var marker: MeshInstance3D = MeshInstance3D.new()
	marker.mesh = torus
	marker.material_override = mat
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.position = GridSpace.grid_to_world(cell) + Vector3(0.0, 0.06, 0.0)
	marker.scale = Vector3(1.4, 0.3, 1.4)
	marker_parent.add_child(marker)
	var tween: Tween = marker.create_tween().set_parallel(true)
	tween.tween_property(marker, "scale", Vector3(0.3, 0.3, 0.3), MARKER_SECONDS)
	tween.tween_property(mat, "albedo_color:a", 0.0, MARKER_SECONDS)
	tween.chain().tween_callback(marker.queue_free)
