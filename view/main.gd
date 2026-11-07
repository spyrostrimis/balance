extends Node3D
## Mission 1 scene (milestone 1: map & camera). Loads the map data into the sim
## grid, builds the 3D view and sets up the RTS camera.

const MAP_PATH: String = "res://data/maps/mission_01.tres"
## The camera pivot stays this far (world units) inside the map edge.
const CAMERA_EDGE_INSET: float = 8.0

@onready var map_view: MapView = $MapView
@onready var rts_camera: RTSCamera = $RTSCamera
@onready var fps_label: Label = $UI/FpsLabel

var grid: MapGrid = MapGrid.new()
var _fps_timer: float = 0.0


func _ready() -> void:
	var layout: MapLayout = load(MAP_PATH) as MapLayout
	var err: String = grid.load_layout(layout)
	if err != "":
		push_error("Failed to load %s: %s" % [MAP_PATH, err])
		return
	map_view.build(grid)
	rts_camera.bounds = GridSpace.map_rect(grid.size()).grow(-CAMERA_EDGE_INSET)
	rts_camera.snap_to(_spawn_center(grid.blue_spawns), rts_camera.start_distance)
	if App.is_selftest:
		rts_camera.edge_pan_enabled = false
		App.selftest_shot.connect(_on_selftest_shot)


func _process(delta: float) -> void:
	_fps_timer -= delta
	if _fps_timer <= 0.0:
		_fps_timer = 0.5
		fps_label.text = "%d FPS" % Engine.get_frames_per_second()


func _spawn_center(cells: Array[Vector2i]) -> Vector3:
	if cells.is_empty():
		return GridSpace.gridf_to_world(Vector2(grid.size()) * 0.5)
	var sum: Vector2 = Vector2.ZERO
	for cell: Vector2i in cells:
		sum += Vector2(cell) + Vector2(0.5, 0.5)
	return GridSpace.gridf_to_world(sum / cells.size())


## Self-test camera poses: start view, whole map, Orichalcum close-up, clamped corner.
func _on_selftest_shot(index: int, _total: int) -> void:
	var map_center: Vector3 = GridSpace.gridf_to_world(Vector2(grid.size()) * 0.5)
	match (index - 1) % 4:
		0:
			rts_camera.snap_to(_spawn_center(grid.blue_spawns), rts_camera.start_distance)
		1:
			rts_camera.snap_to(map_center, rts_camera.max_distance)
		2:
			rts_camera.snap_to(map_center, rts_camera.min_distance)
		3:
			rts_camera.snap_to(Vector3(1000.0, 0.0, -1000.0), rts_camera.start_distance)
