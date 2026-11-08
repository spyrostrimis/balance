class_name Effects
extends RefCounted
## Short-lived placeholder combat effects (tracers, hit flashes, ability effects).

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


## Repair: a green beam from the caster and a green glow rising from the target.
static func heal(parent: Node3D, from: Vector3, to: Vector3) -> void:
	var green: Color = Color(0.4, 1.0, 0.5)
	if from.distance_to(to) > 0.3:
		_beam(parent, from, to, 0.16, green, 0.45)
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.7
	sphere.height = 1.4
	var glow: MeshInstance3D = _glowing(sphere, Color(green, 0.55))
	parent.add_child(glow)
	glow.global_position = to
	var tween: Tween = glow.create_tween().set_parallel(true)
	tween.tween_property(glow, "position:y", to.y + 1.4, 0.8)
	tween.tween_property(glow, "scale", Vector3(0.3, 1.6, 0.3), 0.8)
	tween.tween_property(glow.material_override, "albedo_color:a", 0.0, 0.8)
	tween.chain().tween_callback(glow.queue_free)


## Heavy Cannon: a thick shell trail, a big blast at the target and a ground
## ring showing the splash radius (world units).
static func cannon(parent: Node3D, from: Vector3, to: Vector3, splash_radius: float) -> void:
	_beam(parent, from, to, 0.28, Color(1.0, 0.75, 0.35), 0.25)
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.6
	sphere.height = 1.2
	var blast: MeshInstance3D = _glowing(sphere, Color(1.0, 0.6, 0.2, 0.9))
	parent.add_child(blast)
	blast.global_position = to
	var tween: Tween = blast.create_tween().set_parallel(true)
	tween.tween_property(blast, "scale", Vector3.ONE * 2.6, 0.5).set_ease(Tween.EASE_OUT)
	tween.tween_property(blast.material_override, "albedo_color:a", 0.0, 0.5)
	tween.chain().tween_callback(blast.queue_free)
	if splash_radius > 0.0:
		var torus: TorusMesh = TorusMesh.new()
		torus.inner_radius = splash_radius - 0.15
		torus.outer_radius = splash_radius
		torus.rings = 48
		torus.ring_segments = 4
		var ring: MeshInstance3D = _glowing(torus, Color(1.0, 0.55, 0.2, 0.8))
		parent.add_child(ring)
		ring.global_position = Vector3(to.x, 0.08, to.z)
		ring.scale = Vector3(0.3, 0.2, 0.3)
		var rt: Tween = ring.create_tween().set_parallel(true)
		rt.tween_property(ring, "scale", Vector3(1.0, 0.2, 1.0), 0.35).set_ease(Tween.EASE_OUT)
		rt.tween_property(ring.material_override, "albedo_color:a", 0.0, 0.6)
		rt.chain().tween_callback(ring.queue_free)


static func _beam(parent: Node3D, from: Vector3, to: Vector3, thickness: float, color: Color, seconds: float) -> void:
	var length: float = from.distance_to(to)
	if length < 0.01:
		return
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(thickness, thickness, length)
	var beam: MeshInstance3D = _glowing(box, color)
	parent.add_child(beam)
	var dir: Vector3 = (to - from) / length
	var up: Vector3 = Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	beam.global_transform = Transform3D(Basis.looking_at(dir, up), (from + to) * 0.5)
	_fade_and_free(beam, seconds)


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
