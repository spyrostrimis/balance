class_name Effects
extends RefCounted
## Short-lived combat effects: muzzle flashes, tracers, impact sparks,
## explosions (fireball, smoke, light flash, scorch mark), ability effects and
## vehicle dust. Particles use a shared soft round texture.

const TRACER_SECONDS: float = 0.12
const TRACER_THICKNESS: float = 0.08
const HIT_SECONDS: float = 0.15
const HIT_RADIUS: float = 0.3
const SMOKE_COLOR: Color = Color(0.32, 0.28, 0.25, 0.75)
const DUST_COLOR: Color = Color(0.86, 0.66, 0.42, 0.55)
const FIRE_COLOR: Color = Color(1.0, 0.62, 0.22)

static var _soft_dot: GradientTexture2D
static var _scorch: GradientTexture2D


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
	_flash(parent, from, team_color.lightened(0.6), 0.22, 0.08)
	burst(parent, to, Color(1.0, 0.8, 0.4, 1.0), 6, 0.35, 2.5, 0.25)

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
	smoke(parent, to, 1.4, 1.5)
	scorch(parent, to, splash_radius * 0.8)
	burst(parent, to, Color(1.0, 0.7, 0.3, 1.0), 14, 0.5, 6.0, 0.25)
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


## A unit blows up: fireball, smoke column, light flash, sparks, scorch mark.
## `size` ≈ the unit's footprint in world units.
static func explosion(parent: Node3D, at: Vector3, size: float) -> void:
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	var ball: MeshInstance3D = _glowing(sphere, Color(FIRE_COLOR, 0.95))
	parent.add_child(ball)
	ball.global_position = at + Vector3(0.0, size * 0.3, 0.0)
	ball.scale = Vector3.ONE * size * 0.4
	var t: Tween = ball.create_tween().set_parallel(true)
	t.tween_property(ball, "scale", Vector3.ONE * size * 1.6, 0.35).set_ease(Tween.EASE_OUT)
	t.tween_property(ball.material_override, "albedo_color", Color(0.6, 0.2, 0.05, 0.0), 0.45)
	t.chain().tween_callback(ball.queue_free)
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = FIRE_COLOR
	light.light_energy = 3.0
	light.omni_range = size * 4.0
	parent.add_child(light)
	light.global_position = at + Vector3(0.0, size * 0.6, 0.0)
	var lt: Tween = light.create_tween()
	lt.tween_property(light, "light_energy", 0.0, 0.5)
	lt.tween_callback(light.queue_free)
	burst(parent, at + Vector3(0.0, size * 0.3, 0.0), Color(1.0, 0.75, 0.3, 1.0), 18, 0.6, size * 4.0, 0.2)
	smoke(parent, at, size, 2.2)
	scorch(parent, at, size * 1.3)


## Rising, spreading smoke puffs.
static func smoke(parent: Node3D, at: Vector3, size: float, seconds: float) -> void:
	var p: GPUParticles3D = _particles(SMOKE_COLOR, 14, seconds, 0.7 * size, 1.8 * size)
	var mat: ParticleProcessMaterial = p.process_material as ParticleProcessMaterial
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = size * 0.3
	mat.direction = Vector3.UP
	mat.spread = 25.0
	mat.initial_velocity_min = 1.2
	mat.initial_velocity_max = 2.4
	mat.gravity = Vector3(0.6, 0.4, 0.0)
	mat.damping_min = 1.0
	mat.damping_max = 1.5
	p.explosiveness = 0.6
	_play_once(parent, p, at + Vector3(0.0, size * 0.2, 0.0), seconds)


## A quick spray of bright sparks.
static func burst(parent: Node3D, at: Vector3, color: Color, amount: int, seconds: float, speed: float, dot_size: float) -> void:
	var p: GPUParticles3D = _particles(color, amount, seconds, dot_size, dot_size * 0.3)
	var mat: ParticleProcessMaterial = p.process_material as ParticleProcessMaterial
	mat.direction = Vector3.UP
	mat.spread = 80.0
	mat.initial_velocity_min = speed * 0.5
	mat.initial_velocity_max = speed
	mat.gravity = Vector3(0.0, -9.0, 0.0)
	p.explosiveness = 1.0
	(p.draw_pass_1.surface_get_material(0) as StandardMaterial3D).shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_play_once(parent, p, at, seconds)


## A dark burn mark on the ground that fades out slowly.
static func scorch(parent: Node3D, at: Vector3, radius: float) -> void:
	if _scorch == null:
		var g: Gradient = Gradient.new()
		g.set_color(0, Color(0.08, 0.06, 0.05, 0.85))
		g.set_color(1, Color(0.1, 0.08, 0.06, 0.0))
		_scorch = GradientTexture2D.new()
		_scorch.gradient = g
		_scorch.fill = GradientTexture2D.FILL_RADIAL
		_scorch.fill_from = Vector2(0.5, 0.5)
		_scorch.fill_to = Vector2(1.0, 0.5)
		_scorch.width = 128
		_scorch.height = 128
	var decal: Decal = Decal.new()
	decal.texture_albedo = _scorch
	decal.size = Vector3(radius * 2.0, 2.0, radius * 2.0)
	decal.upper_fade = 0.5
	decal.lower_fade = 0.5
	parent.add_child(decal)
	decal.global_position = Vector3(at.x, 0.0, at.z)
	decal.rotation.y = randf() * TAU
	var t: Tween = decal.create_tween()
	t.tween_interval(8.0)
	t.tween_property(decal, "modulate:a", 0.0, 4.0)
	t.tween_callback(decal.queue_free)


## Continuous sand dust for a moving vehicle (toggle `emitting`).
static func dust_trail() -> GPUParticles3D:
	var p: GPUParticles3D = _particles(DUST_COLOR, 24, 1.1, 0.6, 1.4)
	var mat: ParticleProcessMaterial = p.process_material as ParticleProcessMaterial
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(0.5, 0.05, 0.3)
	mat.direction = Vector3(0.0, 1.0, 0.0)
	mat.spread = 40.0
	mat.initial_velocity_min = 0.3
	mat.initial_velocity_max = 0.8
	mat.gravity = Vector3(0.0, 0.2, 0.0)
	p.emitting = false
	p.name = "DustTrail"
	return p


## Billboard particles with a soft round sprite, growing and fading out.
static func _particles(color: Color, amount: int, lifetime: float, start_size: float, end_size: float) -> GPUParticles3D:
	if _soft_dot == null:
		var g: Gradient = Gradient.new()
		g.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
		g.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
		_soft_dot = GradientTexture2D.new()
		_soft_dot.gradient = g
		_soft_dot.fill = GradientTexture2D.FILL_RADIAL
		_soft_dot.fill_from = Vector2(0.5, 0.5)
		_soft_dot.fill_to = Vector2(1.0, 0.5)
		_soft_dot.width = 64
		_soft_dot.height = 64
	var p: GPUParticles3D = GPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false
	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	var scale_curve: Curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 1.0))
	scale_curve.add_point(Vector2(1.0, end_size / maxf(start_size, 0.001)))
	scale_curve.max_value = maxf(1.0, end_size / maxf(start_size, 0.001))
	var curve_tex: CurveTexture = CurveTexture.new()
	curve_tex.curve = scale_curve
	mat.scale_curve = curve_tex
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, color)
	ramp.set_color(1, Color(color, 0.0))
	var ramp_tex: GradientTexture1D = GradientTexture1D.new()
	ramp_tex.gradient = ramp
	mat.color_ramp = ramp_tex
	p.process_material = mat
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2.ONE * start_size
	var draw: StandardMaterial3D = StandardMaterial3D.new()
	draw.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	draw.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw.vertex_color_use_as_albedo = true
	draw.albedo_texture = _soft_dot
	draw.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad.material = draw
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


static func _play_once(parent: Node3D, p: GPUParticles3D, at: Vector3, seconds: float) -> void:
	p.one_shot = true
	parent.add_child(p)
	p.global_position = at
	p.emitting = true
	var t: Tween = p.create_tween()
	t.tween_interval(seconds + p.lifetime)
	t.tween_callback(p.queue_free)


## Brief bright sphere (muzzle flash).
static func _flash(parent: Node3D, at: Vector3, color: Color, radius: float, seconds: float) -> void:
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 8
	sphere.rings = 4
	var flash: MeshInstance3D = _glowing(sphere, color)
	parent.add_child(flash)
	flash.global_position = at
	_fade_and_free(flash, seconds)


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
