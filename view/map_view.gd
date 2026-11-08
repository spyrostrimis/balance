class_name MapView
extends Node3D
## Renders a MapGrid in 3D: GridMaps aligned 1:1 with the sim grid (ground layer +
## obstacle layer), the Orichalcum deposits and the land outside the map.
## Without a look: placeholder tiles. With the desert look: one seamless sand
## shader over all ground tiles (dunes, ripples, rock plateaus near cliffs and
## start areas, a copper Orichalcum field around the rock), sandstone cliffs and
## the look's boulder models.

const GROUND_COLORS: Array[Color] = [
	Color(0.85, 0.60, 0.30), Color(0.83, 0.58, 0.29), Color(0.87, 0.62, 0.32),
]
const OUTSIDE_COLOR: Color = Color(0.74, 0.50, 0.26)
const ROCK_COLOR: Color = Color(0.50, 0.42, 0.38)
const CLIFF_COLOR: Color = Color(0.66, 0.30, 0.17)
const DEPOSIT_ROCK_COLOR: Color = Color(0.28, 0.22, 0.28)
const ORICHALCUM_COLOR: Color = Color(1.0, 0.42, 0.08)
const GROUND_THICKNESS: float = 0.4
const ROCK_VARIANTS: int = 3
const CLIFF_VARIANTS: int = 3
const DESERT_GROUND_SHADER: Shader = preload("res://view/shaders/desert_ground.gdshader")
const DESERT_CLIFF_SHADER: Shader = preload("res://view/shaders/desert_cliff.gdshader")
## Desert mask: rock plateau around start areas (cells) and next to cliffs.
const START_ROCK_RADIUS: float = 3.6
## Desert mask: Orichalcum field radius around a deposit (cells from its edge).
const ORE_FIELD_RADIUS: float = 3.5

var ground_map: GridMap
var obstacle_map: GridMap

var _ground_items: Array[int] = []
var _rock_items: Array[int] = []
var _cliff_items: Array[int] = []
var _look: Look
var _desert: bool = false


func build(grid: MapGrid, look: Look = null) -> void:
	for child: Node in get_children():
		child.queue_free()
	_look = look
	_desert = look != null and look.terrain == &"desert"
	var library: MeshLibrary = _build_library(grid)
	ground_map = _make_gridmap("GroundMap", library)
	obstacle_map = _make_gridmap("ObstacleMap", library)
	var rotations: Array[int] = []
	for quarter: int in 4:
		rotations.append(obstacle_map.get_orthogonal_index_from_basis(Basis(Vector3.UP, quarter * PI * 0.5)))

	for y: int in grid.height:
		for x: int in grid.width:
			var cell: Vector2i = Vector2i(x, y)
			var h: int = _cell_hash(cell)
			var map_pos: Vector3i = Vector3i(x, 0, y)
			ground_map.set_cell_item(map_pos, _ground_items[h % _ground_items.size()])
			match grid.terrain_at(cell):
				MapGrid.Terrain.ROCK:
					obstacle_map.set_cell_item(map_pos, _rock_items[h % _rock_items.size()], rotations[(h >> 4) % 4])
				MapGrid.Terrain.CLIFF:
					obstacle_map.set_cell_item(map_pos, _cliff_items[h % _cliff_items.size()], rotations[(h >> 4) % 4])
				_:
					pass

	for i: int in grid.deposits.size():
		add_child(_build_deposit(grid.deposits[i], i))
	add_child(_build_outside(grid.size()))


func _make_gridmap(node_name: String, library: MeshLibrary) -> GridMap:
	var map: GridMap = GridMap.new()
	map.name = node_name
	map.mesh_library = library
	map.cell_size = Vector3(GridSpace.CELL_SIZE, 1.0, GridSpace.CELL_SIZE)
	map.cell_center_x = true
	map.cell_center_z = true
	map.cell_center_y = false  # item origin = ground level (y = 0)
	add_child(map)
	return map


func _build_library(grid: MapGrid) -> MeshLibrary:
	var lib: MeshLibrary = MeshLibrary.new()
	var next_id: int = 0
	var cs: float = GridSpace.CELL_SIZE
	_ground_items.clear()
	_rock_items.clear()
	_cliff_items.clear()

	if _desert:
		# Flat tiles (no sides): one seamless surface for the world-space shader.
		var tile: PlaneMesh = PlaneMesh.new()
		tile.size = Vector2(cs, cs)
		tile.material = _desert_ground(grid, true)
		lib.create_item(next_id)
		lib.set_item_name(next_id, "sand")
		lib.set_item_mesh(next_id, tile)
		_ground_items.append(next_id)
		next_id += 1
	var ground_colors: Array[Color] = []
	if not _desert:
		ground_colors = GROUND_COLORS
	for color: Color in ground_colors:
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(cs, GROUND_THICKNESS, cs)
		box.material = _material(color)
		lib.create_item(next_id)
		lib.set_item_name(next_id, "ground_%d" % next_id)
		lib.set_item_mesh(next_id, box)
		lib.set_item_mesh_transform(next_id, Transform3D(Basis.IDENTITY, Vector3(0.0, -GROUND_THICKNESS * 0.5, 0.0)))
		_ground_items.append(next_id)
		next_id += 1

	if _desert and not _look.boulders.is_empty():
		next_id = _add_boulder_items(lib, next_id)
	for v: int in (0 if not _rock_items.is_empty() else ROCK_VARIANTS):
		var rock: ArrayMesh = LowPoly.clamped_xz(
				LowPoly.boulder(cs * (0.52 + 0.04 * v), cs * (0.75 + 0.15 * v), 100 + v), cs * 0.5)
		rock.surface_set_material(0, _material(ROCK_COLOR))
		lib.create_item(next_id)
		lib.set_item_name(next_id, "rock_%d" % v)
		lib.set_item_mesh(next_id, rock)
		_rock_items.append(next_id)
		next_id += 1

	for v: int in CLIFF_VARIANTS:
		# Kept inside its own cell so cliffs never cover units standing next to them.
		var cliff: ArrayMesh = LowPoly.clamped_xz(
				LowPoly.cliff_block(Vector3(cs * 1.04, cs * (1.15 + 0.15 * v), cs * 1.04), 200 + v), cs * 0.5)
		if _desert:
			var sandstone: ShaderMaterial = ShaderMaterial.new()
			sandstone.shader = DESERT_CLIFF_SHADER
			cliff.surface_set_material(0, sandstone)
		else:
			cliff.surface_set_material(0, _material(CLIFF_COLOR))
		lib.create_item(next_id)
		lib.set_item_name(next_id, "cliff_%d" % v)
		lib.set_item_mesh(next_id, cliff)
		_cliff_items.append(next_id)
		next_id += 1
	return lib


func _build_deposit(rect: Rect2i, index: int) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Deposit%d" % index
	var cs: float = GridSpace.CELL_SIZE
	root.position = GridSpace.gridf_to_world(Vector2(rect.position) + Vector2(rect.size) * 0.5)
	var footprint: float = minf(rect.size.x, rect.size.y) * cs

	var base_height: float = footprint * 0.7
	var base: MeshInstance3D = MeshInstance3D.new()
	base.mesh = LowPoly.clamped_xz(LowPoly.boulder(footprint * 0.5, base_height, 300 + index), footprint * 0.5)
	base.material_override = _material(DEPOSIT_ROCK_COLOR)
	root.add_child(base)

	var crystal_mat: StandardMaterial3D = _material(ORICHALCUM_COLOR)
	crystal_mat.emission_enabled = true
	crystal_mat.emission = ORICHALCUM_COLOR
	crystal_mat.emission_energy_multiplier = 1.0
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4242 + index
	# A central cluster on top plus crystals breaking out of the sides.
	var count: int = 12
	for i: int in count:
		var crystal: MeshInstance3D = MeshInstance3D.new()
		var on_top: bool = i < 5
		var length: float = footprint * (rng.randf_range(0.45, 0.8) if on_top else rng.randf_range(0.3, 0.5))
		crystal.mesh = LowPoly.crystal(footprint * (0.1 if on_top else 0.08), length, 400 + i)
		crystal.material_override = crystal_mat
		var angle: float = TAU * float(i) / (5.0 if on_top else float(count - 5)) + rng.randf_range(-0.3, 0.3)
		var dist: float = footprint * (rng.randf_range(0.0, 0.12) if on_top else rng.randf_range(0.22, 0.3))
		var y: float = base_height * (0.5 if on_top else rng.randf_range(0.1, 0.35))
		crystal.position = Vector3(cos(angle) * dist, y, sin(angle) * dist)
		var tilt_axis: Vector3 = Vector3(-sin(angle), 0.0, cos(angle))
		# Negative angle tilts the tip away from the deposit centre.
		crystal.basis = Basis(tilt_axis, -(rng.randf_range(0.1, 0.4) if on_top else rng.randf_range(0.5, 0.8)))
		root.add_child(crystal)

	var glow: OmniLight3D = OmniLight3D.new()
	glow.light_color = ORICHALCUM_COLOR
	glow.light_energy = 2.0
	glow.omni_range = footprint * 2.2
	glow.position = Vector3(0.0, footprint * 0.6, 0.0)
	root.add_child(glow)
	return root


## Land beyond the map edge so the camera never shows a void.
func _build_outside(map_size: Vector2i) -> MeshInstance3D:
	var rect: Rect2 = GridSpace.map_rect(map_size)
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = rect.size + Vector2(400.0, 400.0)
	var outside: MeshInstance3D = MeshInstance3D.new()
	outside.name = "Outside"
	outside.mesh = plane
	outside.material_override = _desert_ground(null, false) if _desert else _material(OUTSIDE_COLOR)
	outside.position = Vector3(rect.get_center().x, -0.05, rect.get_center().y)
	return outside


## The look's boulder models as GridMap items, each fitted inside one cell.
func _add_boulder_items(lib: MeshLibrary, first_id: int) -> int:
	var next_id: int = first_id
	var cs: float = GridSpace.CELL_SIZE
	for scene: PackedScene in _look.boulders:
		var inst: Node3D = scene.instantiate() as Node3D
		var meshes: Array[Node] = inst.find_children("*", "MeshInstance3D", true, false)
		if meshes.is_empty():
			inst.free()
			continue
		var mi: MeshInstance3D = meshes[0] as MeshInstance3D
		var box: AABB = mi.get_aabb()
		var s: float = cs * 0.92 / maxf(box.size.x, box.size.z)
		var basis: Basis = Basis.IDENTITY.scaled(Vector3.ONE * s)
		var center: Vector3 = box.get_center()
		var offset: Vector3 = -(basis * Vector3(center.x, box.position.y, center.z))
		var mesh: Mesh = mi.mesh.duplicate() as Mesh
		for surface: int in mesh.get_surface_count():
			var mat: Material = mi.get_active_material(surface)
			if mat != null:
				mesh.surface_set_material(surface, mat)
		lib.create_item(next_id)
		lib.set_item_name(next_id, "boulder_%d" % next_id)
		lib.set_item_mesh(next_id, mesh)
		lib.set_item_mesh_transform(next_id, Transform3D(basis, offset))
		_rock_items.append(next_id)
		next_id += 1
		inst.free()
	return next_id


## Desert ground material. With a grid: per-cell mask (R = rock, G = Orichalcum).
func _desert_ground(grid: MapGrid, with_mask: bool) -> ShaderMaterial:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = DESERT_GROUND_SHADER
	mat.set_shader_parameter("use_mask", with_mask and grid != null)
	if with_mask and grid != null:
		mat.set_shader_parameter("mask", ImageTexture.create_from_image(desert_mask(grid)))
		mat.set_shader_parameter("map_size_world", Vector2(grid.size()) * GridSpace.CELL_SIZE)
	return mat


## One pixel per cell: R = rock plateau (start areas, next to cliffs),
## G = Orichalcum field strength around deposits.
static func desert_mask(grid: MapGrid) -> Image:
	var img: Image = Image.create(grid.width, grid.height, false, Image.FORMAT_RGBA8)
	var starts: Array[Vector2] = []
	for spawns: Array[Vector2i] in [grid.blue_spawns, grid.red_spawns]:
		if spawns.is_empty():
			continue
		var sum: Vector2 = Vector2.ZERO
		for c: Vector2i in spawns:
			sum += Vector2(c) + Vector2(0.5, 0.5)
		starts.append(sum / spawns.size())
	for y: int in grid.height:
		for x: int in grid.width:
			var cell: Vector2i = Vector2i(x, y)
			var center: Vector2 = Vector2(cell) + Vector2(0.5, 0.5)
			var rock: float = 0.0
			for s: Vector2 in starts:
				rock = maxf(rock, 1.0 - smoothstep(START_ROCK_RADIUS - 1.0, START_ROCK_RADIUS + 0.5, center.distance_to(s)))
			for dy: int in range(-1, 2):
				for dx: int in range(-1, 2):
					if grid.terrain_at(cell + Vector2i(dx, dy)) == MapGrid.Terrain.CLIFF:
						rock = maxf(rock, 0.8)
			var ore: float = 0.0
			for d: Rect2i in grid.deposits:
				var nearest: Vector2 = Vector2(clampf(center.x, d.position.x, d.end.x), clampf(center.y, d.position.y, d.end.y))
				ore = maxf(ore, 1.0 - clampf(center.distance_to(nearest) / ORE_FIELD_RADIUS, 0.0, 1.0))
			img.set_pixel(x, y, Color(rock, ore, 0.0, 1.0))
	return img


func _material(color: Color) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	return mat


static func _cell_hash(cell: Vector2i) -> int:
	return absi(hash(cell))
