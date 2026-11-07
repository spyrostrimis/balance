class_name LowPoly
extends RefCounted
## Placeholder-art helpers: turns primitive meshes into jittered, flat-shaded
## low-poly meshes (rocks, cliffs, crystals). Deterministic for a given seed.


## Flat-shaded copy of `source` (surface 0). Vertices are displaced by up to
## `jitter` world units; vertices sharing a position move together, so there are no cracks.
## `keep_bottom_flat` stops vertices at or below `bottom_y` from moving vertically.
static func faceted(source: Mesh, jitter: float, seed_value: int, keep_bottom_flat: bool = true,
		bottom_y: float = -INF) -> ArrayMesh:
	var arrays: Array = source.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		indices.resize(verts.size())
		for i: int in verts.size():
			indices[i] = i

	var min_y: float = INF
	for v: Vector3 in verts:
		min_y = minf(min_y, v.y)
	var floor_y: float = bottom_y if bottom_y > -INF else min_y

	var moved: PackedVector3Array = PackedVector3Array()
	moved.resize(verts.size())
	for i: int in verts.size():
		var v: Vector3 = verts[i]
		var offset: Vector3 = _hash_offset(v, seed_value) * jitter
		if keep_bottom_flat and v.y <= floor_y + 0.001:
			offset.y = 0.0
		moved[i] = v + offset

	var out_verts: PackedVector3Array = PackedVector3Array()
	var out_normals: PackedVector3Array = PackedVector3Array()
	for t: int in range(0, indices.size() - 2, 3):
		var ia: int = indices[t]
		var ib: int = indices[t + 1]
		var ic: int = indices[t + 2]
		var a: Vector3 = moved[ia]
		var b: Vector3 = moved[ib]
		var c: Vector3 = moved[ic]
		var n: Vector3 = (b - a).cross(c - a)
		if n.length_squared() < 1e-12:
			continue  # degenerate (e.g. sphere poles)
		n = n.normalized()
		if not normals.is_empty() and n.dot(normals[ia] + normals[ib] + normals[ic]) < 0.0:
			n = -n
		out_verts.append_array(PackedVector3Array([a, b, c]))
		out_normals.append_array(PackedVector3Array([n, n, n]))

	var out: Array = []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = out_verts
	out[Mesh.ARRAY_NORMAL] = out_normals
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	return mesh


## Low-poly boulder: a squashed, jittered sphere resting on y = 0.
static func boulder(radius: float, height: float, seed_value: int) -> ArrayMesh:
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = radius
	sphere.height = height
	sphere.radial_segments = 7
	sphere.rings = 4
	var mesh: ArrayMesh = faceted(sphere, radius * 0.22, seed_value, false)
	return _translated(mesh, Vector3(0.0, height * 0.5 - height * 0.15, 0.0))


## Low-poly cliff block: a subdivided, jittered box whose base sits slightly below y = 0.
static func cliff_block(size: Vector3, seed_value: int) -> ArrayMesh:
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	box.subdivide_width = 1
	box.subdivide_depth = 1
	box.subdivide_height = 1
	var mesh: ArrayMesh = faceted(box, size.x * 0.12, seed_value, true)
	return _translated(mesh, Vector3(0.0, size.y * 0.5 - 0.3, 0.0))


## Pointed crystal (5-sided spike) with its base at y = 0.
static func crystal(radius: float, length: float, seed_value: int) -> ArrayMesh:
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 0.0
	cyl.bottom_radius = radius
	cyl.height = length
	cyl.radial_segments = 5
	cyl.rings = 1
	var mesh: ArrayMesh = faceted(cyl, radius * 0.15, seed_value, true)
	return _translated(mesh, Vector3(0.0, length * 0.5, 0.0))


static func _translated(mesh: ArrayMesh, offset: Vector3) -> ArrayMesh:
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i: int in verts.size():
		verts[i] += offset
	arrays[Mesh.ARRAY_VERTEX] = verts
	var out: ArrayMesh = ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out


## Deterministic pseudo-random vector in [-1, 1]^3 for a position + seed.
static func _hash_offset(v: Vector3, seed_value: int) -> Vector3:
	var key: Vector3i = Vector3i(roundi(v.x * 1000.0), roundi(v.y * 1000.0), roundi(v.z * 1000.0))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([key, seed_value])
	return Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
