class_name MapGrid
extends RefCounted
## The simulation's 2D terrain grid. Pure logic: no nodes, no rendering.

enum Terrain { GROUND, CLIFF, ROCK, ORICHALCUM }

const SYMBOLS: Dictionary[String, Terrain] = {
	".": Terrain.GROUND,
	"^": Terrain.CLIFF,
	"#": Terrain.ROCK,
	"O": Terrain.ORICHALCUM,
	"B": Terrain.GROUND,
	"R": Terrain.GROUND,
}

var width: int = 0
var height: int = 0
var blue_spawns: Array[Vector2i] = []
var red_spawns: Array[Vector2i] = []
## Bounding rects of each connected group of Orichalcum cells.
var deposits: Array[Rect2i] = []

var _cells: PackedByteArray = PackedByteArray()


## Loads a layout. Returns "" on success, otherwise an error message
## (the grid is left empty).
func load_rows(rows: PackedStringArray) -> String:
	_reset()
	if rows.is_empty():
		return "layout has no rows"
	var w: int = rows[0].length()
	if w == 0:
		return "layout row 0 is empty"
	var cells: PackedByteArray = PackedByteArray()
	cells.resize(w * rows.size())
	var blue: Array[Vector2i] = []
	var red: Array[Vector2i] = []
	for y: int in rows.size():
		var row: String = rows[y]
		if row.length() != w:
			return "row %d has length %d, expected %d" % [y, row.length(), w]
		for x: int in w:
			var ch: String = row[x]
			if not SYMBOLS.has(ch):
				return "unknown symbol '%s' at (%d, %d)" % [ch, x, y]
			cells[y * w + x] = SYMBOLS[ch]
			if ch == "B":
				blue.append(Vector2i(x, y))
			elif ch == "R":
				red.append(Vector2i(x, y))
	width = w
	height = rows.size()
	_cells = cells
	blue_spawns = blue
	red_spawns = red
	deposits = _find_deposits()
	return ""


func load_layout(layout: MapLayout) -> String:
	if layout == null:
		_reset()
		return "layout is null"
	return load_rows(layout.rows)


func size() -> Vector2i:
	return Vector2i(width, height)


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


## Terrain at a cell. Out-of-bounds cells count as cliff.
func terrain_at(cell: Vector2i) -> Terrain:
	if not in_bounds(cell):
		return Terrain.CLIFF
	return _cells[cell.y * width + cell.x] as Terrain


func is_passable(cell: Vector2i) -> bool:
	return terrain_at(cell) == Terrain.GROUND


## Rocks, cliffs and the Orichalcum rock block shots and sight (outside the map too).
func blocks_sight(cell: Vector2i) -> bool:
	return terrain_at(cell) != Terrain.GROUND


func _reset() -> void:
	width = 0
	height = 0
	_cells = PackedByteArray()
	blue_spawns = []
	red_spawns = []
	deposits = []


func _find_deposits() -> Array[Rect2i]:
	var result: Array[Rect2i] = []
	var seen: Dictionary[Vector2i, bool] = {}
	for y: int in height:
		for x: int in width:
			var start: Vector2i = Vector2i(x, y)
			if seen.has(start) or terrain_at(start) != Terrain.ORICHALCUM:
				continue
			var rect: Rect2i = Rect2i(start, Vector2i.ONE)
			var stack: Array[Vector2i] = [start]
			seen[start] = true
			while not stack.is_empty():
				var cell: Vector2i = stack.pop_back()
				rect = rect.expand(cell).expand(cell + Vector2i.ONE)
				for dir: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var next: Vector2i = cell + dir
					if not seen.has(next) and terrain_at(next) == Terrain.ORICHALCUM:
						seen[next] = true
						stack.append(next)
			result.append(rect)
	return result
