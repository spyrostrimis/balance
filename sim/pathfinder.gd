class_name Pathfinder
extends RefCounted
## Grid pathfinding over the static terrain (AStarGrid2D). Ground units route
## around impassable cells without cutting corners; air units ignore terrain.
## Also labels connected ground regions so "can I reach that cell?" is O(1).

var _ground: AStarGrid2D = AStarGrid2D.new()
var _air: AStarGrid2D = AStarGrid2D.new()
var _regions: PackedInt32Array = PackedInt32Array()
var _size: Vector2i = Vector2i.ZERO


func build(grid: MapGrid) -> void:
	_size = grid.size()
	var rect: Rect2i = Rect2i(Vector2i.ZERO, _size)
	for astar: AStarGrid2D in [_ground, _air]:
		astar.region = rect
		astar.cell_size = Vector2.ONE
		astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_ground.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_air.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ALWAYS
	_ground.update()
	_air.update()
	for y: int in _size.y:
		for x: int in _size.x:
			var cell: Vector2i = Vector2i(x, y)
			if not grid.is_passable(cell):
				_ground.set_point_solid(cell, true)
	_label_regions(grid)


## Cells to walk through from `from` (excluded) to `to` (included).
## Empty if there is no path or from == to. `extra_solid` cells are treated as
## blocked for this query only (used to route around other units).
func find_path(from: Vector2i, to: Vector2i, air: bool, extra_solid: Array[Vector2i] = []) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if from == to or not _in_bounds(from) or not _in_bounds(to):
		return result
	var astar: AStarGrid2D = _air if air else _ground
	var toggled: Array[Vector2i] = []
	for cell: Vector2i in extra_solid:
		if cell != from and cell != to and _in_bounds(cell) and not astar.is_point_solid(cell):
			astar.set_point_solid(cell, true)
			toggled.append(cell)
	var ids: Array[Vector2i] = astar.get_id_path(from, to)
	for cell: Vector2i in toggled:
		astar.set_point_solid(cell, false)
	for i: int in range(1, ids.size()):
		result.append(ids[i])
	return result


## Connected ground region id of a cell, or -1 if impassable/out of bounds.
func region_of(cell: Vector2i) -> int:
	if not _in_bounds(cell):
		return -1
	return _regions[cell.y * _size.x + cell.x]


func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < _size.x and cell.y < _size.y


## 4-connected flood fill. Matches the ground A* (diagonals only when both
## orthogonal neighbours are open), so same region <=> a path exists.
func _label_regions(grid: MapGrid) -> void:
	_regions = PackedInt32Array()
	_regions.resize(_size.x * _size.y)
	_regions.fill(-1)
	var next_label: int = 0
	for y: int in _size.y:
		for x: int in _size.x:
			var start: Vector2i = Vector2i(x, y)
			if region_of(start) != -1 or not grid.is_passable(start):
				continue
			var stack: Array[Vector2i] = [start]
			_regions[y * _size.x + x] = next_label
			while not stack.is_empty():
				var cell: Vector2i = stack.pop_back()
				for dir: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var n: Vector2i = cell + dir
					if _in_bounds(n) and region_of(n) == -1 and grid.is_passable(n):
						_regions[n.y * _size.x + n.x] = next_label
						stack.append(n)
			next_label += 1
