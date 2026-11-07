class_name GridSpace
extends RefCounted
## The ONE place that converts between sim grid cells and 3D world space.
## Grid x → world +X, grid y → world +Z, ground surface at world Y = 0.

const CELL_SIZE: float = 2.0


## Centre of a cell, on the ground.
static func grid_to_world(cell: Vector2i) -> Vector3:
	return Vector3((cell.x + 0.5) * CELL_SIZE, 0.0, (cell.y + 0.5) * CELL_SIZE)


## Fractional grid position (cell units, e.g. an interpolated unit position) → world.
static func gridf_to_world(pos: Vector2) -> Vector3:
	return Vector3(pos.x * CELL_SIZE, 0.0, pos.y * CELL_SIZE)


## The cell containing a world position (Y is ignored).
static func world_to_grid(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / CELL_SIZE), floori(pos.z / CELL_SIZE))


## World-space XZ rectangle covered by a map of the given size (x→X, y→Z).
static func map_rect(map_size: Vector2i) -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(map_size) * CELL_SIZE)
