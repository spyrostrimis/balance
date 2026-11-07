extends GdUnitTestSuite
## Grid ↔ world conversion and camera clamping.


func test_grid_to_world_is_cell_centre_on_ground() -> void:
	var cs: float = GridSpace.CELL_SIZE
	assert_vector(GridSpace.grid_to_world(Vector2i(0, 0))).is_equal(Vector3(cs * 0.5, 0.0, cs * 0.5))
	assert_vector(GridSpace.grid_to_world(Vector2i(3, 7))).is_equal(Vector3(cs * 3.5, 0.0, cs * 7.5))


func test_world_to_grid_round_trips() -> void:
	for cell: Vector2i in [Vector2i(0, 0), Vector2i(5, 9), Vector2i(31, 31), Vector2i(-1, -2)]:
		assert_that(GridSpace.world_to_grid(GridSpace.grid_to_world(cell))).is_equal(cell)


func test_world_to_grid_floors_and_ignores_height() -> void:
	var cs: float = GridSpace.CELL_SIZE
	assert_that(GridSpace.world_to_grid(Vector3(cs * 0.99, 50.0, cs * 1.01))).is_equal(Vector2i(0, 1))
	assert_that(GridSpace.world_to_grid(Vector3(-0.01, 0.0, 0.0))).is_equal(Vector2i(-1, 0))


func test_map_rect_covers_all_cells() -> void:
	var rect: Rect2 = GridSpace.map_rect(Vector2i(32, 32))
	assert_vector(rect.size).is_equal(Vector2(32.0, 32.0) * GridSpace.CELL_SIZE)
	var last: Vector3 = GridSpace.grid_to_world(Vector2i(31, 31))
	assert_bool(rect.has_point(Vector2(last.x, last.z))).is_true()


func test_camera_clamp_keeps_pivot_inside_bounds() -> void:
	var bounds: Rect2 = Rect2(8.0, 8.0, 48.0, 48.0)
	assert_vector(RTSCamera.clamp_to_bounds(Vector3(-100.0, 0.0, 300.0), bounds)).is_equal(Vector3(8.0, 0.0, 56.0))
	assert_vector(RTSCamera.clamp_to_bounds(Vector3(20.0, 0.0, 30.0), bounds)).is_equal(Vector3(20.0, 0.0, 30.0))
