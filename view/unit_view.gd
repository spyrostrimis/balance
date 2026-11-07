class_name UnitView
extends Node3D
## Placeholder 3D model for one SimUnit: team-coloured primitives, a selection
## ring, smooth interpolation between sim ticks and turning to face movement.
## Model forward is -Z.

const TEAM_COLORS: Dictionary[SimUnit.Team, Color] = {
	SimUnit.Team.BLUE: Color(0.15, 0.42, 1.0),
	SimUnit.Team.RED: Color(0.92, 0.14, 0.10),
}
const HERO_TRIM_COLOR: Color = Color(1.0, 0.82, 0.25)
const DARK_COLOR: Color = Color(0.18, 0.18, 0.2)
const RING_COLOR: Color = Color(0.3, 1.0, 0.35)
const TURN_SPEED: float = 12.0
const SILHOUETTE_SHADER: Shader = preload("res://view/shaders/occluded_silhouette.gdshader")
const SILHOUETTE_ALPHA: float = 0.6

var unit: SimUnit
## Picking volume (world units): a sphere of this radius around the model's middle.
var pick_radius: float = 0.8
var pick_height: float = 1.4
var selected: bool = false:
	set(value):
		selected = value
		if _ring != null:
			_ring.visible = value

var _ring: MeshInstance3D
var _ring_radius: float = 0.8
var _silhouette: ShaderMaterial


func setup(sim_unit: SimUnit) -> void:
	unit = sim_unit
	name = "Unit%d_%s" % [unit.id, unit.stats.id]
	var color: Color = TEAM_COLORS[unit.team]
	_silhouette = ShaderMaterial.new()
	_silhouette.shader = SILHOUETTE_SHADER
	var sil_color: Color = color.lightened(0.25)
	sil_color.a = SILHOUETTE_ALPHA
	_silhouette.set_shader_parameter("silhouette_color", sil_color)
	if unit.stats.is_hero:
		_build_hero(color)
	elif unit.stats.id == &"light_vehicle":
		_build_vehicle(color)
	else:
		_build_infantry(color)
	_build_ring()
	# Face the enemy side at start: Blue (south-west) looks north-east, Red looks south-west.
	# Yaw θ faces world direction (-sin θ, -cos θ) in XZ.
	rotation.y = -PI * 0.25 if unit.team == SimUnit.Team.BLUE else PI * 0.75
	sync(1.0, 0.0)


## Places the model between the last two sim positions (alpha 0..1).
func sync(alpha: float, delta: float) -> void:
	var p: Vector2 = unit.prev_pos.lerp(unit.pos, alpha)
	position = GridSpace.gridf_to_world(p)
	var moved: Vector2 = unit.pos - unit.prev_pos
	if moved.length_squared() > 1e-8 and delta > 0.0:
		var target_yaw: float = atan2(-moved.x, -moved.y)
		rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-TURN_SPEED * delta))


func pick_center() -> Vector3:
	return global_position + Vector3(0.0, pick_height * 0.5, 0.0)


func _build_hero(color: Color) -> void:
	var body: CapsuleMesh = CapsuleMesh.new()
	body.radius = 0.5
	body.height = 2.1
	_add_part(body, color, Vector3(0.0, 1.05, 0.0))
	var crest: CylinderMesh = CylinderMesh.new()
	crest.top_radius = 0.0
	crest.bottom_radius = 0.32
	crest.height = 0.6
	crest.radial_segments = 6
	_add_part(crest, HERO_TRIM_COLOR, Vector3(0.0, 2.35, 0.0))
	var visor: BoxMesh = BoxMesh.new()
	visor.size = Vector3(0.6, 0.18, 0.2)
	_add_part(visor, HERO_TRIM_COLOR, Vector3(0.0, 1.6, -0.42))
	var cannon: BoxMesh = BoxMesh.new()
	cannon.size = Vector3(0.22, 0.22, 0.9)
	_add_part(cannon, DARK_COLOR, Vector3(0.5, 1.15, -0.4))
	pick_radius = 1.0
	pick_height = 2.4
	_ring_radius = 0.95


func _build_infantry(color: Color) -> void:
	var body: CapsuleMesh = CapsuleMesh.new()
	body.radius = 0.32
	body.height = 1.3
	_add_part(body, color, Vector3(0.0, 0.65, 0.0))
	var gun: BoxMesh = BoxMesh.new()
	gun.size = Vector3(0.12, 0.12, 0.7)
	_add_part(gun, DARK_COLOR, Vector3(0.3, 0.75, -0.3))
	pick_radius = 0.75
	pick_height = 1.4
	_ring_radius = 0.6


func _build_vehicle(color: Color) -> void:
	var hull: BoxMesh = BoxMesh.new()
	hull.size = Vector3(1.3, 0.55, 1.9)
	_add_part(hull, color, Vector3(0.0, 0.5, 0.0))
	for side: float in [-0.7, 0.7]:
		var track: BoxMesh = BoxMesh.new()
		track.size = Vector3(0.25, 0.45, 1.95)
		_add_part(track, DARK_COLOR, Vector3(side, 0.25, 0.0))
	var turret: BoxMesh = BoxMesh.new()
	turret.size = Vector3(0.75, 0.35, 0.8)
	_add_part(turret, color.lightened(0.15), Vector3(0.0, 0.95, 0.1))
	var barrel: BoxMesh = BoxMesh.new()
	barrel.size = Vector3(0.14, 0.14, 0.9)
	_add_part(barrel, DARK_COLOR, Vector3(0.0, 0.95, -0.7))
	pick_radius = 1.15
	pick_height = 1.2
	_ring_radius = 1.25


func _build_ring() -> void:
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = _ring_radius - 0.1
	torus.outer_radius = _ring_radius
	torus.rings = 32
	torus.ring_segments = 4
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = RING_COLOR
	# Drawn on top of everything so the ring stays visible behind cliffs.
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.render_priority = 1
	_ring = MeshInstance3D.new()
	_ring.name = "SelectionRing"
	_ring.mesh = torus
	_ring.material_override = mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.position = Vector3(0.0, 0.05, 0.0)
	_ring.scale = Vector3(1.0, 0.3, 1.0)
	_ring.visible = selected
	add_child(_ring)


func _add_part(mesh: Mesh, color: Color, offset: Vector3) -> void:
	var part: MeshInstance3D = MeshInstance3D.new()
	part.mesh = mesh
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.6
	mat.next_pass = _silhouette
	part.material_override = mat
	part.position = offset
	add_child(part)
