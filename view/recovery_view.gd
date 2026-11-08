class_name RecoveryView
extends Node3D
## Placeholder dropship for a SimRecovery: flies in high, comes down to hover
## over the downed hero, shows a tractor beam while loading, climbs away with
## the hero hanging below. Team-coloured. Model forward is -Z.

const CRUISE_HEIGHT: float = 7.0
const HOVER_HEIGHT: float = 3.2
## Below this distance (world units) to the pickup point it descends / climbs.
const DESCENT_DISTANCE: float = 10.0
## The carried hero hangs this far below the ship.
const CARRY_DROP: float = 2.4
const TURN_SPEED: float = 6.0

var recovery: SimRecovery
## Where it picks the hero up (world, ground level).
var pickup: Vector3 = Vector3.ZERO

var _beam: MeshInstance3D


func setup(sim_recovery: SimRecovery, pickup_point: Vector3) -> void:
	recovery = sim_recovery
	pickup = pickup_point
	name = "Recovery%d" % recovery.id
	var color: Color = UnitView.TEAM_COLORS[recovery.team]
	var look: Look = UnitView.current_look
	if look != null and look.dropship != null:
		_build_model(look.dropship, color)
	else:
		_build_placeholder(color)
	var beam_mesh: CylinderMesh = CylinderMesh.new()
	beam_mesh.top_radius = 0.5
	beam_mesh.bottom_radius = 1.0
	beam_mesh.height = HOVER_HEIGHT
	var beam_mat: StandardMaterial3D = StandardMaterial3D.new()
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.albedo_color = Color(0.5, 0.9, 1.0, 0.3)
	beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_beam = MeshInstance3D.new()
	_beam.mesh = beam_mesh
	_beam.material_override = beam_mat
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.position = Vector3(0.0, -HOVER_HEIGHT * 0.5, 0.0)
	_beam.visible = false
	add_child(_beam)
	sync(1.0, 0.0)


## The look's dropship model, team-tinted like units.
func _build_model(visual: UnitVisual, color: Color) -> void:
	var inst: Node3D = visual.scene.instantiate() as Node3D
	add_child(inst)
	for node: Node in inst.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node as MeshInstance3D
		for s: int in mi.mesh.get_surface_count():
			var source: BaseMaterial3D = mi.get_active_material(s) as BaseMaterial3D
			if source == null or source.albedo_texture == null:
				continue
			var mat: ShaderMaterial = ShaderMaterial.new()
			mat.shader = UnitView.TEAM_TINT_SHADER
			mat.set_shader_parameter("albedo_tex", source.albedo_texture)
			mat.set_shader_parameter("team_color", Vector3(color.r, color.g, color.b))
			mat.set_shader_parameter("hue_strength", visual.hue_strength)
			mat.set_shader_parameter("sat_min", visual.sat_min)
			mat.set_shader_parameter("roughness", source.roughness)
			mat.set_shader_parameter("metallic", source.metallic)
			mi.set_surface_override_material(s, mat)
	ModelFit.fit(inst, visual.size, visual.size_is_length, deg_to_rad(visual.yaw_offset_degrees))
	inst.position.y -= 0.6  # roughly centred on the hover point


func _build_placeholder(color: Color) -> void:
	var hull: BoxMesh = BoxMesh.new()
	hull.size = Vector3(1.6, 0.8, 3.2)
	_part(hull, color, Vector3.ZERO, Vector3.ZERO)
	var cockpit: BoxMesh = BoxMesh.new()
	cockpit.size = Vector3(1.0, 0.5, 1.0)
	_part(cockpit, Color(0.75, 0.9, 1.0), Vector3(0.0, 0.45, -1.1), Vector3.ZERO)
	for side: float in [-1.0, 1.0]:
		var wing: BoxMesh = BoxMesh.new()
		wing.size = Vector3(1.8, 0.15, 1.4)
		_part(wing, color.darkened(0.25), Vector3(side * 1.6, 0.1, 0.3), Vector3(0.0, 0.0, side * -0.12))
		var engine: CylinderMesh = CylinderMesh.new()
		engine.top_radius = 0.35
		engine.bottom_radius = 0.35
		engine.height = 1.2
		_part(engine, UnitView.DARK_COLOR, Vector3(side * 2.3, 0.1, 0.6), Vector3(PI * 0.5, 0.0, 0.0))
		var glow: SphereMesh = SphereMesh.new()
		glow.radius = 0.3
		glow.height = 0.6
		var flame: MeshInstance3D = _part(glow, Color(0.5, 0.85, 1.0), Vector3(side * 2.3, 0.1, 1.25), Vector3.ZERO)
		var mat: StandardMaterial3D = flame.material_override as StandardMaterial3D
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED


## Places the ship between the last two sim positions (alpha 0..1).
func sync(alpha: float, delta: float) -> void:
	var flat: Vector3 = GridSpace.gridf_to_world(recovery.prev_pos.lerp(recovery.pos, alpha))
	var dist: float = Vector2(flat.x - pickup.x, flat.z - pickup.z).length()
	var height: float = lerpf(HOVER_HEIGHT, CRUISE_HEIGHT, clampf(dist / DESCENT_DISTANCE, 0.0, 1.0))
	position = Vector3(flat.x, height, flat.z)
	_beam.visible = recovery.state == SimRecovery.State.LOADING
	var move: Vector2 = recovery.pos - recovery.prev_pos
	if move.length_squared() > 1e-8 and delta > 0.0:
		var target_yaw: float = atan2(-move.x, -move.y)
		rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-TURN_SPEED * delta))


## Where the carried hero hangs (world).
func carry_point() -> Vector3:
	return position - Vector3(0.0, CARRY_DROP, 0.0)


func _part(mesh: Mesh, color: Color, offset: Vector3, rot: Vector3) -> MeshInstance3D:
	var part: MeshInstance3D = MeshInstance3D.new()
	part.mesh = mesh
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.5
	part.material_override = mat
	part.position = offset
	part.rotation = rot
	add_child(part)
	return part
