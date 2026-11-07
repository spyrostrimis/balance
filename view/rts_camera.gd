class_name RTSCamera
extends Node3D
## Fixed-angle RTS camera. This node is the pivot on the ground (y = 0); the
## Camera3D child sits behind and above it. Pan: WASD / arrows / screen edges.
## Zoom: mouse wheel. The pivot is clamped to `bounds` (world XZ rect).

@export var pitch_degrees: float = 55.0
@export var fov_degrees: float = 40.0
@export var min_distance: float = 14.0
@export var max_distance: float = 72.0
@export var start_distance: float = 34.0
## Distance multiplier per wheel notch.
@export var zoom_step: float = 1.15
## Higher = snappier zoom.
@export var zoom_smoothing: float = 12.0
## Pan speed in world units per second, per world unit of camera distance.
@export var pan_speed: float = 0.9
## Pan starts when the mouse is within this many (base-resolution) pixels of an edge.
@export var edge_margin_px: float = 14.0

var edge_pan_enabled: bool = true
var bounds: Rect2 = Rect2(0.0, 0.0, 64.0, 64.0)

var camera: Camera3D
var _distance: float = 0.0
var _target_distance: float = 0.0


func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = fov_degrees
	camera.near = 0.5
	camera.far = 500.0
	add_child(camera)
	camera.make_current()
	_distance = clampf(start_distance, min_distance, max_distance)
	_target_distance = _distance
	_apply_distance()


func _unhandled_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
		_target_distance = clampf(_target_distance / zoom_step, min_distance, max_distance)
		get_viewport().set_input_as_handled()
	elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_target_distance = clampf(_target_distance * zoom_step, min_distance, max_distance)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	var dir: Vector2 = Input.get_vector("cam_left", "cam_right", "cam_up", "cam_down")
	if edge_pan_enabled:
		dir += _edge_direction()
	dir = dir.limit_length(1.0)
	if dir != Vector2.ZERO:
		position += Vector3(dir.x, 0.0, dir.y) * pan_speed * _distance * delta
	position = clamp_to_bounds(position, bounds)
	if not is_equal_approx(_distance, _target_distance):
		_distance = lerpf(_distance, _target_distance, 1.0 - exp(-zoom_smoothing * delta))
		if absf(_distance - _target_distance) < 0.01:
			_distance = _target_distance
		_apply_distance()


## Jumps instantly (no smoothing) to a pivot point and distance.
func snap_to(pivot: Vector3, distance: float) -> void:
	position = clamp_to_bounds(Vector3(pivot.x, 0.0, pivot.z), bounds)
	_distance = clampf(distance, min_distance, max_distance)
	_target_distance = _distance
	_apply_distance()


func get_distance() -> float:
	return _distance


static func clamp_to_bounds(pos: Vector3, rect: Rect2) -> Vector3:
	return Vector3(clampf(pos.x, rect.position.x, rect.end.x), pos.y,
			clampf(pos.z, rect.position.y, rect.end.y))


func _apply_distance() -> void:
	var pitch: float = deg_to_rad(pitch_degrees)
	camera.position = Vector3(0.0, sin(pitch) * _distance, cos(pitch) * _distance)
	camera.rotation = Vector3(-pitch, 0.0, 0.0)


func _edge_direction() -> Vector2:
	var window: Window = get_window()
	if not window.has_focus():
		return Vector2.ZERO
	var viewport: Viewport = get_viewport()
	var rect: Rect2 = viewport.get_visible_rect()
	var mouse: Vector2 = viewport.get_mouse_position()
	if not rect.has_point(mouse):
		return Vector2.ZERO
	var dir: Vector2 = Vector2.ZERO
	if mouse.x <= rect.position.x + edge_margin_px:
		dir.x -= 1.0
	elif mouse.x >= rect.end.x - edge_margin_px:
		dir.x += 1.0
	if mouse.y <= rect.position.y + edge_margin_px:
		dir.y -= 1.0
	elif mouse.y >= rect.end.y - edge_margin_px:
		dir.y += 1.0
	return dir
