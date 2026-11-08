class_name ModelFit
extends RefCounted
## Fits an imported model into the game's scale: measures its meshes in its own
## space (works before it is in the scene tree), then scales, turns and moves it
## so it has the wanted height (or length), stands on y = 0 and is centred.


## Returns the fitted size (world units) after applying the transform to `model`.
static func fit(model: Node3D, size: float, by_length: bool, yaw: float) -> Vector3:
	var box: AABB = local_bounds(model)
	if box.size == Vector3.ZERO:
		return Vector3.ONE
	var measure: float = maxf(box.size.x, box.size.z) if by_length else box.size.y
	var s: float = size / maxf(measure, 0.0001)
	var basis: Basis = Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s)
	var center: Vector3 = box.get_center()
	var offset: Vector3 = -(basis * Vector3(center.x, box.position.y, center.z))
	model.transform = Transform3D(basis, offset)
	return box.size * s


## Union of all mesh AABBs under `root`, in `root`'s own space (its transform ignored).
static func local_bounds(root: Node3D) -> AABB:
	var result: AABB = AABB()
	var first: bool = true
	for node: Node in root.find_children("*", "VisualInstance3D", true, false):
		var vi: VisualInstance3D = node as VisualInstance3D
		var xf: Transform3D = Transform3D.IDENTITY
		var walk: Node = vi
		while walk != null and walk != root:
			var n3: Node3D = walk as Node3D
			if n3 != null:
				xf = n3.transform * xf
			walk = walk.get_parent()
		var box: AABB = xf * vi.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result
