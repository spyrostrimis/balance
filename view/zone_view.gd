class_name ZoneView
extends Node3D
## The capture zone on the ground: a faint fill on every zone cell and a border
## line around it, tinted by the rock's owner (neutral = gold, orange pulse
## while contested).

const NEUTRAL_COLOR: Color = Color(1.0, 0.85, 0.35)
const CONTESTED_COLOR: Color = Color(1.0, 0.55, 0.15)
const LINE_WIDTH: float = 0.16
const HEIGHT: float = 0.05
const FILL_ALPHA: float = 0.1
const LINE_ALPHA: float = 0.85

var objective: CaptureObjective

var _fill_mat: StandardMaterial3D
var _line_mat: StandardMaterial3D
var _time: float = 0.0


func setup(capture: CaptureObjective) -> void:
	objective = capture
	name = "CaptureZone"
	_fill_mat = _material()
	_line_mat = _material()
	var cs: float = GridSpace.CELL_SIZE
	var fill: SurfaceTool = SurfaceTool.new()
	fill.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lines: SurfaceTool = SurfaceTool.new()
	lines.begin(Mesh.PRIMITIVE_TRIANGLES)
	for cell: Vector2i in objective.zone:
		var x0: float = cell.x * cs
		var z0: float = cell.y * cs
		_quad(fill, x0, z0, x0 + cs, z0 + cs)
		# Border edges: sides that touch a non-zone cell.
		if not objective.is_in_zone(cell + Vector2i(0, -1)):
			_quad(lines, x0, z0, x0 + cs, z0 + LINE_WIDTH)
		if not objective.is_in_zone(cell + Vector2i(0, 1)):
			_quad(lines, x0, z0 + cs - LINE_WIDTH, x0 + cs, z0 + cs)
		if not objective.is_in_zone(cell + Vector2i(-1, 0)):
			_quad(lines, x0, z0, x0 + LINE_WIDTH, z0 + cs)
		if not objective.is_in_zone(cell + Vector2i(1, 0)):
			_quad(lines, x0 + cs - LINE_WIDTH, z0, x0 + cs, z0 + cs)
	add_child(_mesh(fill.commit(), _fill_mat))
	add_child(_mesh(lines.commit(), _line_mat))
	_refresh(0.0)


func _process(delta: float) -> void:
	_time += delta
	_refresh(_time)


func _refresh(t: float) -> void:
	if objective == null:
		return
	var color: Color = NEUTRAL_COLOR
	if objective.contested():
		color = CONTESTED_COLOR.lerp(Color.WHITE, 0.3 * (0.5 + 0.5 * sin(t * 8.0)))
	elif objective.owner_team != CaptureObjective.NO_TEAM:
		color = UnitView.TEAM_COLORS[objective.owner_team as SimUnit.Team].lightened(0.2)
	_fill_mat.albedo_color = Color(color, FILL_ALPHA)
	_line_mat.albedo_color = Color(color, LINE_ALPHA)


func _quad(st: SurfaceTool, x0: float, z0: float, x1: float, z1: float) -> void:
	var a: Vector3 = Vector3(x0, HEIGHT, z0)
	var b: Vector3 = Vector3(x1, HEIGHT, z0)
	var c: Vector3 = Vector3(x1, HEIGHT, z1)
	var d: Vector3 = Vector3(x0, HEIGHT, z1)
	for v: Vector3 in [a, b, c, a, c, d]:
		st.set_normal(Vector3.UP)
		st.add_vertex(v)


func _mesh(mesh: ArrayMesh, mat: StandardMaterial3D) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


func _material() -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat
