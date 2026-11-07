class_name Effects
extends RefCounted
## Short-lived placeholder combat effects (tracers, hit flashes).

const TRACER_SECONDS: float = 0.12
const TRACER_THICKNESS: float = 0.08
const HIT_SECONDS: float = 0.15
const HIT_RADIUS: float = 0.3


## A shot: a bright tracer from muzzle to target plus a small flash at the target.
static func shot(parent: Node3D, from: Vector3, to: Vector3, team_color: Color) -> void:
	var length: float = from.distance_to(to)
	if length < 0.01:
		return
	var color: Color = team_color.lightened(0.55)
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(TRACER_THICKNESS, TRACER_THICKNESS, length)
	var tracer: MeshInstance3D = _glowing(box, color)
	parent.add_child(tracer)
	var dir: Vector3 = (to - from) / length
	var up: Vector3 = Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	tracer.global_transform = Transform3D(Basis.looking_at(dir, up), (from + to) * 0.5)
	_fade_and_free(tracer, TRACER_SECONDS)

	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = HIT_RADIUS
	sphere.height = HIT_RADIUS * 2.0
	sphere.radial_segments = 8
	sphere.rings = 4
	var flash: MeshInstance3D = _glowing(sphere, Color(1.0, 0.85, 0.4))
	parent.add_child(flash)
	flash.global_position = to
	_fade_and_free(flash, HIT_SECONDS)


static func _glowing(mesh: Mesh, color: Color) -> MeshInstance3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


static func _fade_and_free(node: MeshInstance3D, seconds: float) -> void:
	var mat: StandardMaterial3D = node.material_override as StandardMaterial3D
	var tween: Tween = node.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, seconds)
	tween.tween_callback(node.queue_free)
