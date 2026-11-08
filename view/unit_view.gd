class_name UnitView
extends Node3D
## The 3D model for one SimUnit: the current Look's model for its type (team
## coloured, animated: idle / walk / attack / death), or team-coloured primitives
## if the look has none. Selection ring, smooth interpolation between sim ticks,
## turning to face movement or the attack target, death and "downed" poses.
## Auras are invisible in the game; the debug overlay (F3) shows their radius as
## a ground ring. Model forward is -Z.
## setup_display() builds the model alone (no sim unit), e.g. for the portrait.

const TEAM_COLORS: Dictionary[SimUnit.Team, Color] = {
	SimUnit.Team.BLUE: Color(0.15, 0.42, 1.0),
	SimUnit.Team.RED: Color(0.92, 0.14, 0.10),
}
const HERO_TRIM_COLOR: Color = Color(1.0, 0.82, 0.25)
const DARK_COLOR: Color = Color(0.18, 0.18, 0.2)
const RING_COLOR: Color = Color(0.3, 1.0, 0.35)
## Ring of an enemy unit the player clicked to look at (not commandable).
const INSPECT_RING_COLOR: Color = Color(1.0, 0.3, 0.25)
const TURN_SPEED: float = 12.0
const SILHOUETTE_SHADER: Shader = preload("res://view/shaders/occluded_silhouette.gdshader")
const SILHOUETTE_ALPHA: float = 0.6
const DEATH_SECONDS: float = 0.45
const DOWNED_DARKEN: float = 0.45
const AURA_RING_WIDTH: float = 0.14
const AURA_RING_ALPHA: float = 0.55
const AURA_FILL_ALPHA: float = 0.07
const TEAM_TINT_SHADER: Shader = preload("res://view/shaders/team_tint.gdshader")
const ANIM_BLEND: float = 0.15
## Seconds a death animation plays before the troop sinks away.
const MODEL_DEATH_SECONDS: float = 1.2

## The art look of the current mission (set by the mission scene before units are built).
static var current_look: Look

var unit: SimUnit
## Read-only access to the sim (to face the attack target).
var world: SimWorld
## Picking volume (world units): a sphere of this radius around the model's middle.
var pick_radius: float = 0.8
var pick_height: float = 1.4
var selected: bool = false:
	set(value):
		selected = value
		_refresh_ring()
## Shown with a red ring: the player is looking at this (enemy) unit.
var inspected: bool = false:
	set(value):
		inspected = value
		_refresh_ring()

var _ring: MeshInstance3D
var _ring_radius: float = 0.8
var _silhouette: ShaderMaterial
## Holds the model parts (not the ring), so the model can fall over on its own.
var _model: Node3D
var _materials: Array[StandardMaterial3D] = []
var _base_colors: Array[Color] = []
var _dying: bool = false
var _aura_rings: Array[Node3D] = []
## Model from the look (null = placeholder primitives).
var _visual: UnitVisual
var _tint_materials: Array[ShaderMaterial] = []
var _anim: AnimationPlayer
var _anim_names: Dictionary[String, StringName] = {}
var _current_anim: StringName = &""
## Seconds left of a one-shot action animation (attack).
var _action_left: float = 0.0
## Death / downed pose: no more idle or walk.
var _posed: bool = false


func setup(sim_unit: SimUnit, sim_world: SimWorld) -> void:
	unit = sim_unit
	world = sim_world
	name = "Unit%d_%s" % [unit.id, unit.stats.id]
	_build_model(unit.stats, unit.team, true)
	_build_ring()
	_build_aura_rings()
	App.debug_overlay_changed.connect(func(_on: bool) -> void: _refresh_aura_rings())
	_refresh_aura_rings()
	# Face the middle of the map at start. Yaw θ faces world direction (-sin θ, -cos θ) in XZ.
	var to_center: Vector2 = Vector2(sim_world.grid.size()) * 0.5 - unit.pos
	if to_center.length_squared() > 0.01:
		rotation.y = atan2(-to_center.x, -to_center.y)
	sync(1.0, 0.0)


## Model only (no sim unit, ring or silhouette): for portraits.
func setup_display(stats: UnitStats, team: SimUnit.Team) -> void:
	name = "Display_%s" % stats.id
	_build_model(stats, team, false)


func _build_model(stats: UnitStats, team: SimUnit.Team, with_silhouette: bool) -> void:
	_model = Node3D.new()
	_model.name = "Model"
	add_child(_model)
	var color: Color = TEAM_COLORS[team]
	if with_silhouette:
		_silhouette = ShaderMaterial.new()
		_silhouette.shader = SILHOUETTE_SHADER
		var sil_color: Color = color.lightened(0.25)
		sil_color.a = SILHOUETTE_ALPHA
		_silhouette.set_shader_parameter("silhouette_color", sil_color)
	if current_look != null and current_look.units.has(stats.id):
		_visual = current_look.units[stats.id]
		_build_from_visual(_visual, color)
	elif stats.is_hero:
		_build_hero(color)
	elif stats.id == &"light_vehicle":
		_build_vehicle(color)
	else:
		_build_infantry(color)


## Instances the look's model: team colours, fitted to its size, animations found.
func _build_from_visual(visual: UnitVisual, color: Color) -> void:
	var inst: Node3D = visual.scene.instantiate() as Node3D
	_model.add_child(inst)
	for node: Node in inst.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for s: int in mi.mesh.get_surface_count():
			var source: BaseMaterial3D = mi.get_active_material(s) as BaseMaterial3D
			if source == null:
				continue
			mi.set_surface_override_material(s, _team_material(source, visual, color))
	var fitted: Vector3 = ModelFit.fit(inst, visual.size, visual.size_is_length, deg_to_rad(visual.yaw_offset_degrees))
	if _silhouette != null:
		# Only count as hidden when covered by something at least the model's own
		# depth in front of it, so its arms and legs don't "hide" its body.
		_silhouette.set_shader_parameter("margin", maxf(1.0, maxf(fitted.x, fitted.z) * 0.9))
	pick_height = maxf(fitted.y, 0.6)
	pick_radius = clampf(maxf(fitted.x, fitted.z) * 0.5, 0.6, 1.6)
	_ring_radius = clampf(maxf(fitted.x, fitted.z) * 0.55, 0.55, 1.6)
	var players: Array[Node] = inst.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		_anim = players[0] as AnimationPlayer
		for key: String in ["idle", "walk", "attack", "hit", "death"]:
			var wanted: String = visual.get("anim_" + key) as String
			if wanted == "":
				continue
			for anim_name: StringName in _anim.get_animation_list():
				if String(anim_name).ends_with(wanted):
					_anim_names[key] = anim_name
					break
		for key: String in ["idle", "walk"]:
			if _anim_names.has(key):
				_anim.get_animation(_anim_names[key]).loop_mode = Animation.LOOP_LINEAR
		_play("idle")


## Textured materials → team-tint shader; plain ones → repainted copy if listed.
func _team_material(source: BaseMaterial3D, visual: UnitVisual, color: Color) -> Material:
	var result: Material
	if source.albedo_texture != null:
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = TEAM_TINT_SHADER
		mat.set_shader_parameter("albedo_tex", source.albedo_texture)
		mat.set_shader_parameter("albedo_color", source.albedo_color)
		mat.set_shader_parameter("roughness", source.roughness)
		mat.set_shader_parameter("metallic", source.metallic)
		if source.normal_enabled and source.normal_texture != null:
			mat.set_shader_parameter("normal_tex", source.normal_texture)
			mat.set_shader_parameter("has_normal", true)
		var orm: ORMMaterial3D = source as ORMMaterial3D
		if orm != null and orm.orm_texture != null:
			mat.set_shader_parameter("orm_tex", orm.orm_texture)
			mat.set_shader_parameter("has_orm", true)
		mat.set_shader_parameter("team_color", Vector3(color.r, color.g, color.b))
		mat.set_shader_parameter("hue_strength", visual.hue_strength)
		mat.set_shader_parameter("sat_min", visual.sat_min)
		mat.set_shader_parameter("paint_greys", visual.paint_greys)
		_tint_materials.append(mat)
		result = mat
	else:
		var copy: BaseMaterial3D = source.duplicate() as BaseMaterial3D
		if visual.paint_materials.has(source.resource_name):
			var k: float = visual.paint_materials[source.resource_name]
			copy.albedo_color = source.albedo_color.lerp(Color(color.r * k, color.g * k, color.b * k), visual.paint_mix)
		var standard: StandardMaterial3D = copy as StandardMaterial3D
		if standard != null:
			_materials.append(standard)
			_base_colors.append(standard.albedo_color)
		result = copy
	result.next_pass = _silhouette
	return result


func _play(key: String, blend: float = ANIM_BLEND) -> void:
	if _anim == null or not _anim_names.has(key):
		return
	var anim_name: StringName = _anim_names[key]
	if anim_name == _current_anim and _anim.is_playing():
		return
	_current_anim = anim_name
	_anim.play(anim_name, blend)


## One-shot attack animation (the unit just fired).
func play_attack() -> void:
	if _anim == null or not _anim_names.has("attack") or _posed:
		return
	_current_anim = &""
	_anim.speed_scale = 1.0
	_play("attack", 0.05)
	_action_left = minf(_anim.get_animation(_anim_names["attack"]).length, 0.7)


## Idle or walk, depending on whether the unit moved this tick.
func _update_animation(delta: float) -> void:
	if _anim == null or _posed:
		return
	if _action_left > 0.0:
		_action_left -= delta
		return
	var moving: bool = unit.stepping or (unit.pos - unit.prev_pos).length_squared() > 1e-8
	if moving and _anim_names.has("walk"):
		_play("walk")
		_anim.speed_scale = _visual.walk_speed_scale * unit.stats.move_speed
	elif _anim_names.has("idle"):
		_play("idle")
		_anim.speed_scale = 1.0
	elif _anim.is_playing():
		_anim.pause()  # no idle animation (e.g. tanks): hold still
		_current_anim = &""


## Places the model between the last two sim positions (alpha 0..1).
func sync(alpha: float, delta: float) -> void:
	if _dying:
		return
	visible = not unit.away
	if unit.away or unit.carried:
		return  # off the map, or hanging under a recovery dropship (placed by the scene)
	var p: Vector2 = unit.prev_pos.lerp(unit.pos, alpha)
	position = GridSpace.gridf_to_world(p)
	if unit.downed or delta <= 0.0:
		return
	_update_animation(delta)
	var facing: Vector2 = unit.pos - unit.prev_pos
	if facing.length_squared() <= 1e-8 and unit.attack_target_id != -1 and world != null:
		var target: SimUnit = world.get_unit(unit.attack_target_id)
		if target != null:
			facing = target.pos - unit.pos
	if facing.length_squared() > 1e-8:
		var target_yaw: float = atan2(-facing.x, -facing.y)
		rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-TURN_SPEED * delta))


## Where shots start: chest height, a little in front of the model.
func muzzle_point() -> Vector3:
	var forward: Vector3 = -global_basis.z
	return global_position + Vector3(0.0, pick_height * 0.55, 0.0) + forward * 0.6


## Height above the ground for the health bar (world units).
func bar_height() -> float:
	return pick_height + 0.45


## Troop died: death animation (or sink and shrink), then free.
func die() -> void:
	_dying = true
	selected = false
	if _anim != null and _anim_names.has("death"):
		_posed = true
		_anim.speed_scale = 1.0
		_play("death", 0.05)
		var sink: Tween = create_tween()
		sink.tween_interval(MODEL_DEATH_SECONDS)
		sink.tween_property(_model, "position:y", -1.5, 1.0)
		sink.tween_callback(queue_free)
		return
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_model, "scale", Vector3(1.0, 0.1, 1.0), DEATH_SECONDS)
	tween.tween_property(_model, "rotation:z", 0.6, DEATH_SECONDS)
	tween.chain().tween_callback(queue_free)


## Hero at 0 HP: falls over and greys out, stays on the map.
func set_downed() -> void:
	_refresh_aura_rings()  # a downed hero has no aura
	for mat: StandardMaterial3D in _materials:
		mat.albedo_color = mat.albedo_color.darkened(DOWNED_DARKEN)
	for mat: ShaderMaterial in _tint_materials:
		mat.set_shader_parameter("darken", DOWNED_DARKEN)
	if _anim != null and _anim_names.has("death"):
		_posed = true  # the death animation ends lying down and holds its last frame
		_anim.speed_scale = 1.0
		_play("death", 0.05)
		return
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_model, "rotation:x", -PI * 0.47, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_model, "position:y", 0.45, 0.5)


## Hero back from recovery: upright, full colour, visible again.
func set_revived() -> void:
	for i: int in _materials.size():
		_materials[i].albedo_color = _base_colors[i]
	for mat: ShaderMaterial in _tint_materials:
		mat.set_shader_parameter("darken", 0.0)
	_posed = false
	_current_anim = &""
	_play("idle", 0.0)
	_model.rotation = Vector3.ZERO
	_model.position = Vector3.ZERO
	visible = true
	_refresh_aura_rings()
	sync(1.0, 0.0)


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
	add_child(_ring)
	_refresh_ring()


func _refresh_ring() -> void:
	if _ring == null:
		return
	_ring.visible = selected or inspected
	(_ring.material_override as StandardMaterial3D).albedo_color = RING_COLOR if selected else INSPECT_RING_COLOR


## Aura rings only with the debug overlay on, and only while the hero is up.
func _refresh_aura_rings() -> void:
	for ring: Node3D in _aura_rings:
		ring.visible = App.debug_overlay and unit != null and unit.can_act()


## Debug overlay only: a faint ground ring (and fill) per aura, sized to its radius.
func _build_aura_rings() -> void:
	for ability: AbilityStats in unit.stats.abilities:
		if ability == null or ability.kind != AbilityStats.Kind.AURA:
			continue
		var radius: float = ability.aura_radius * GridSpace.CELL_SIZE
		var color: Color = TEAM_COLORS[unit.team].lightened(0.3)
		var root: Node3D = Node3D.new()
		root.name = "Aura_%s" % ability.id
		root.position = Vector3(0.0, 0.04, 0.0)
		add_child(root)
		var torus: TorusMesh = TorusMesh.new()
		torus.inner_radius = radius - AURA_RING_WIDTH
		torus.outer_radius = radius
		torus.rings = 96
		torus.ring_segments = 4
		color.a = AURA_RING_ALPHA
		var ring: MeshInstance3D = _flat_mesh(torus, color)
		ring.scale = Vector3(1.0, 0.15, 1.0)
		root.add_child(ring)
		var disc: CylinderMesh = CylinderMesh.new()
		disc.top_radius = radius
		disc.bottom_radius = radius
		disc.height = 0.01
		disc.radial_segments = 96
		disc.rings = 1
		color.a = AURA_FILL_ALPHA
		root.add_child(_flat_mesh(disc, color))
		_aura_rings.append(root)


func _flat_mesh(mesh: Mesh, color: Color) -> MeshInstance3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


func _add_part(mesh: Mesh, color: Color, offset: Vector3) -> void:
	var part: MeshInstance3D = MeshInstance3D.new()
	part.mesh = mesh
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.6
	mat.next_pass = _silhouette
	part.material_override = mat
	part.position = offset
	_materials.append(mat)
	_base_colors.append(color)
	_model.add_child(part)
