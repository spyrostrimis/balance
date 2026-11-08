class_name Minimap
extends Control
## Overview map: terrain, the rock's capture zone, units as team dots (Leaders
## bigger) and the camera's view. Left click / drag moves the camera there;
## right click sends the selection there.

signal look_at_requested(world_pos: Vector3)
signal move_requested(cell: Vector2i)

const SAND: Color = Color(0.82, 0.6, 0.34)
const ROCK_FLOOR: Color = Color(0.45, 0.36, 0.29)
const CLIFF: Color = Color(0.52, 0.27, 0.16)
const BOULDER: Color = Color(0.6, 0.45, 0.32)
const ORE: Color = Color(1.0, 0.45, 0.15)
const VIEW_RECT: Color = Color(1.0, 1.0, 1.0, 0.9)

var world: SimWorld
var camera: Camera3D
var _terrain: ImageTexture
var _dragging: bool = false


func setup(sim_world: SimWorld, cam: Camera3D) -> void:
	world = sim_world
	camera = cam
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # crisp cells
	clip_contents = true
	var grid: MapGrid = world.grid
	var mask: Image = MapView.desert_mask(grid)
	var img: Image = Image.create(grid.width, grid.height, false, Image.FORMAT_RGBA8)
	for y: int in grid.height:
		for x: int in grid.width:
			var cell: Vector2i = Vector2i(x, y)
			var m: Color = mask.get_pixel(x, y)
			var c: Color = SAND.lerp(ROCK_FLOOR, clampf(m.r, 0.0, 1.0)).lerp(ORE, m.g * 0.6)
			match grid.terrain_at(cell):
				MapGrid.Terrain.CLIFF:
					c = CLIFF
				MapGrid.Terrain.ROCK:
					c = BOULDER
				MapGrid.Terrain.ORICHALCUM:
					c = ORE
				_:
					pass
			img.set_pixel(x, y, c)
	_terrain = ImageTexture.create_from_image(img)


func _process(_delta: float) -> void:
	queue_redraw()


func _cell_size() -> Vector2:
	return size / Vector2(world.grid.size())


func _draw() -> void:
	if world == null:
		return
	var cs: Vector2 = _cell_size()
	draw_texture_rect(_terrain, Rect2(Vector2.ZERO, size), false)
	if world.objective != null:
		var zone_color: Color = Color(1.0, 0.85, 0.35, 0.8)
		if world.objective.owner_team != CaptureObjective.NO_TEAM:
			zone_color = UnitView.TEAM_COLORS[world.objective.owner_team as SimUnit.Team]
		var r: Rect2i = world.objective.rock.grow(world.objective.rules.zone_radius)
		draw_rect(Rect2(Vector2(r.position) * cs, Vector2(r.size) * cs), zone_color, false, 2.0)
	for unit: SimUnit in world.units:
		if unit.away or unit.dead:
			continue
		var p: Vector2 = unit.pos * cs
		var color: Color = UnitView.TEAM_COLORS[unit.team]
		if unit.downed:
			color = color.darkened(0.5)
		var radius: float = maxf(cs.x * (0.75 if unit.stats.is_hero else 0.5), 2.5)
		draw_circle(p, radius + 1.0, Color.BLACK)
		draw_circle(p, radius, color.lightened(0.15))
	for recovery: SimRecovery in world.recoveries:
		draw_circle(recovery.pos * cs, maxf(cs.x * 0.6, 3.0), Color(0.9, 0.9, 1.0))
	_draw_view(cs)
	draw_rect(Rect2(Vector2.ZERO, size), HudTheme.BRASS_DARK, false, 2.0)


## The camera's footprint on the ground (screen corners projected to y = 0).
func _draw_view(cs: Vector2) -> void:
	if camera == null:
		return
	var vp: Vector2 = camera.get_viewport().get_visible_rect().size
	var points: PackedVector2Array = PackedVector2Array()
	for corner: Vector2 in [Vector2.ZERO, Vector2(vp.x, 0.0), vp, Vector2(0.0, vp.y)]:
		var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(camera.project_ray_origin(corner), camera.project_ray_normal(corner))
		if hit == null:
			return
		var w: Vector3 = hit as Vector3
		points.append(Vector2(w.x, w.z) / GridSpace.CELL_SIZE * cs)
	points.append(points[0])
	draw_polyline(points, VIEW_RECT, 1.5)


func _gui_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null:
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
			if mb.pressed:
				_look_at(mb.position)
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			var cell: Vector2 = mb.position / _cell_size()
			move_requested.emit(Vector2i(floori(cell.x), floori(cell.y)))
		accept_event()
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and _dragging:
		_look_at(motion.position)
		accept_event()


func _look_at(local: Vector2) -> void:
	var cell: Vector2 = local / _cell_size()
	look_at_requested.emit(GridSpace.gridf_to_world(cell))
