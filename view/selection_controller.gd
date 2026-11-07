class_name SelectionController
extends Control
## Player selection and orders. Full-screen overlay (ignores the mouse itself;
## reads unhandled input) that draws the drag box.
##   Left click unit: select it (Shift: add/remove).  Left click ground: clear.
##   Left drag: box-select own units (Shift: add).  Right click: move order (units
##   stop on the nearest free cells; red marker = the clicked cell itself is blocked).
##   Esc: clear selection.
## Orders go to the sim as commands; this node never changes sim state directly.

signal selection_changed(count: int)

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
			order_move_at(mb.position)
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


func _draw() -> void:
	if not _dragging:
		return
	var rect: Rect2 = Rect2(_press_pos, _drag_end - _press_pos).abs()
	draw_rect(rect, BOX_FILL, true)
	draw_rect(rect, BOX_LINE, false, 2.0)


func click_select(screen_pos: Vector2, additive: bool) -> void:
	var hit: UnitView = unit_at(screen_pos)
	if hit == null:
		if not additive:
			clear_selection()
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


func set_selection(views: Array[UnitView]) -> void:
	for view: UnitView in _selected:
		view.selected = false
	_selected = views.duplicate()
	for view: UnitView in _selected:
		view.selected = true
	selection_changed.emit(_selected.size())


## Closest own unit under the cursor (ray vs. a sphere around each model), or null.
func unit_at(screen_pos: Vector2) -> UnitView:
	var origin: Vector3 = camera.project_ray_origin(screen_pos)
	var dir: Vector3 = camera.project_ray_normal(screen_pos)
	var best: UnitView = null
	var best_t: float = INF
	for view: UnitView in _views:
		if view.unit.team != player_team:
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
