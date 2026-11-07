extends GdUnitTestSuite
## Checks the Mission 1 map data against the spec in design/GDD.md.

const LAYOUT_PATH: String = "res://data/maps/mission_01.tres"

var _grid: MapGrid


func before_test() -> void:
	_grid = MapGrid.new()
	var layout: MapLayout = load(LAYOUT_PATH) as MapLayout
	assert_object(layout).is_not_null()
	assert_str(_grid.load_layout(layout)).is_empty()


func test_is_32_by_32() -> void:
	assert_that(_grid.size()).is_equal(Vector2i(32, 32))


func test_border_is_impassable() -> void:
	for i: int in 32:
		for cell: Vector2i in [Vector2i(i, 0), Vector2i(i, 31), Vector2i(0, i), Vector2i(31, i)]:
			assert_bool(_grid.is_passable(cell)).override_failure_message("border cell %s is passable" % cell).is_false()


func test_single_orichalcum_rock_in_the_middle() -> void:
	assert_array(_grid.deposits).has_size(1)
	var rect: Rect2i = _grid.deposits[0]
	var center: Vector2 = Vector2(rect.position) + Vector2(rect.size) * 0.5
	assert_vector(center).is_equal(Vector2(16.0, 16.0))


func test_each_side_has_four_spawn_cells() -> void:
	assert_array(_grid.blue_spawns).has_size(4)
	assert_array(_grid.red_spawns).has_size(4)
	for cell: Vector2i in _grid.blue_spawns + _grid.red_spawns:
		assert_bool(_grid.is_passable(cell)).is_true()


func test_is_point_symmetric_for_fairness() -> void:
	for y: int in 32:
		for x: int in 32:
			var cell: Vector2i = Vector2i(x, y)
			var mirror: Vector2i = Vector2i(31 - x, 31 - y)
			assert_int(_grid.terrain_at(cell)).is_equal(_grid.terrain_at(mirror))
	for cell: Vector2i in _grid.blue_spawns:
		assert_bool(_grid.red_spawns.has(Vector2i(31 - cell.x, 31 - cell.y))).is_true()


func test_every_open_cell_is_reachable_from_blue_spawn() -> void:
	var reached: Dictionary[Vector2i, bool] = {}
	var stack: Array[Vector2i] = [_grid.blue_spawns[0]]
	reached[_grid.blue_spawns[0]] = true
	while not stack.is_empty():
		var cell: Vector2i = stack.pop_back()
		for dir: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + dir
			if not reached.has(next) and _grid.is_passable(next):
				reached[next] = true
				stack.append(next)
	var open_cells: int = 0
	for y: int in 32:
		for x: int in 32:
			if _grid.is_passable(Vector2i(x, y)):
				open_cells += 1
	assert_int(reached.size()).is_equal(open_cells)
	for cell: Vector2i in _grid.red_spawns:
		assert_bool(reached.has(cell)).is_true()
