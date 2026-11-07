extends GdUnitTestSuite
## Pathfinder: A* over terrain and region labels.


func _pf(rows: Array[String]) -> Pathfinder:
	var grid: MapGrid = MapGrid.new()
	assert_str(grid.load_rows(PackedStringArray(rows))).is_empty()
	var pf: Pathfinder = Pathfinder.new()
	pf.build(grid)
	return pf


func test_path_excludes_start_and_includes_goal() -> void:
	var pf: Pathfinder = _pf(["...."])
	var path: Array[Vector2i] = pf.find_path(Vector2i(0, 0), Vector2i(3, 0), false)
	assert_array(path).contains_exactly([Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)])


func test_same_cell_gives_empty_path() -> void:
	var pf: Pathfinder = _pf(["..."])
	assert_array(pf.find_path(Vector2i(1, 0), Vector2i(1, 0), false)).is_empty()


func test_ground_path_avoids_obstacles() -> void:
	var pf: Pathfinder = _pf([
		"...",
		".#.",
		"...",
	])
	var path: Array[Vector2i] = pf.find_path(Vector2i(0, 1), Vector2i(2, 1), false)
	assert_array(path).is_not_empty()
	assert_bool(path.has(Vector2i(1, 1))).is_false()


func test_no_ground_path_into_enclosed_cell_but_air_path_exists() -> void:
	var pf: Pathfinder = _pf([
		".....",
		".###.",
		".#.#.",
		".###.",
		".....",
	])
	assert_array(pf.find_path(Vector2i(0, 0), Vector2i(2, 2), false)).is_empty()
	assert_array(pf.find_path(Vector2i(0, 0), Vector2i(2, 2), true)).is_not_empty()
	assert_int(pf.region_of(Vector2i(0, 0))).is_not_equal(pf.region_of(Vector2i(2, 2)))
	assert_int(pf.region_of(Vector2i(1, 1))).is_equal(-1)


func test_extra_solid_cells_are_avoided_for_one_query_only() -> void:
	var pf: Pathfinder = _pf([
		"...",
		"...",
	])
	var blocked: Array[Vector2i] = [Vector2i(1, 0)]
	var detour: Array[Vector2i] = pf.find_path(Vector2i(0, 0), Vector2i(2, 0), false, blocked)
	assert_bool(detour.has(Vector2i(1, 0))).is_false()
	assert_array(detour).is_not_empty()
	var direct: Array[Vector2i] = pf.find_path(Vector2i(0, 0), Vector2i(2, 0), false)
	assert_array(direct).contains_exactly([Vector2i(1, 0), Vector2i(2, 0)])


func test_mission_01_open_ground_is_one_region() -> void:
	var grid: MapGrid = MapGrid.new()
	var layout: MapLayout = load("res://data/maps/mission_01.tres") as MapLayout
	assert_str(grid.load_layout(layout)).is_empty()
	var pf: Pathfinder = Pathfinder.new()
	pf.build(grid)
	var region: int = pf.region_of(grid.blue_spawns[0])
	assert_int(region).is_not_equal(-1)
	assert_int(pf.region_of(grid.red_spawns[0])).is_equal(region)
