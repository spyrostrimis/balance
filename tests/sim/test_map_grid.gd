extends GdUnitTestSuite
## MapGrid parsing and queries.


func _grid(rows: Array[String]) -> MapGrid:
	var grid: MapGrid = MapGrid.new()
	var err: String = grid.load_rows(PackedStringArray(rows))
	assert_str(err).is_empty()
	return grid


func test_parses_size_and_terrain() -> void:
	var grid: MapGrid = _grid([
		"^^^^",
		"^.#^",
		"^O.^",
		"^^^^",
	])
	assert_that(grid.size()).is_equal(Vector2i(4, 4))
	assert_int(grid.terrain_at(Vector2i(1, 1))).is_equal(MapGrid.Terrain.GROUND)
	assert_int(grid.terrain_at(Vector2i(2, 1))).is_equal(MapGrid.Terrain.ROCK)
	assert_int(grid.terrain_at(Vector2i(1, 2))).is_equal(MapGrid.Terrain.ORICHALCUM)
	assert_int(grid.terrain_at(Vector2i(0, 0))).is_equal(MapGrid.Terrain.CLIFF)


func test_only_ground_is_passable() -> void:
	var grid: MapGrid = _grid([".^#O", "BR.."])
	assert_bool(grid.is_passable(Vector2i(0, 0))).is_true()
	assert_bool(grid.is_passable(Vector2i(1, 0))).is_false()
	assert_bool(grid.is_passable(Vector2i(2, 0))).is_false()
	assert_bool(grid.is_passable(Vector2i(3, 0))).is_false()
	assert_bool(grid.is_passable(Vector2i(0, 1))).is_true()  # spawn cells are ground
	assert_bool(grid.is_passable(Vector2i(1, 1))).is_true()


func test_out_of_bounds_is_impassable_cliff() -> void:
	var grid: MapGrid = _grid(["..", ".."])
	for cell: Vector2i in [Vector2i(-1, 0), Vector2i(0, -1), Vector2i(2, 0), Vector2i(0, 2)]:
		assert_bool(grid.in_bounds(cell)).is_false()
		assert_bool(grid.is_passable(cell)).is_false()
		assert_int(grid.terrain_at(cell)).is_equal(MapGrid.Terrain.CLIFF)


func test_spawns_are_collected() -> void:
	var grid: MapGrid = _grid(["B..", "..R", "B.R"])
	assert_array(grid.blue_spawns).contains_exactly_in_any_order([Vector2i(0, 0), Vector2i(0, 2)])
	assert_array(grid.red_spawns).contains_exactly_in_any_order([Vector2i(2, 1), Vector2i(2, 2)])


func test_deposits_are_grouped_into_rects() -> void:
	var grid: MapGrid = _grid([
		"OO...",
		"OO...",
		"....O",
	])
	assert_array(grid.deposits).contains_exactly_in_any_order([
		Rect2i(0, 0, 2, 2),
		Rect2i(4, 2, 1, 1),
	])


func test_rejects_ragged_rows() -> void:
	var grid: MapGrid = MapGrid.new()
	assert_str(grid.load_rows(PackedStringArray(["...", ".."]))).contains("row 1")
	assert_that(grid.size()).is_equal(Vector2i.ZERO)


func test_rejects_unknown_symbol() -> void:
	var grid: MapGrid = MapGrid.new()
	assert_str(grid.load_rows(PackedStringArray(["..x"]))).contains("unknown symbol")


func test_rejects_empty_layout() -> void:
	var grid: MapGrid = MapGrid.new()
	assert_str(grid.load_rows(PackedStringArray())).is_not_empty()
	assert_str(grid.load_layout(null)).is_not_empty()
