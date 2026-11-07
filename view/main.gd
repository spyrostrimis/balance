extends Node3D
## Placeholder main scene until milestone 1: a ground plane, a reference cube
## sitting on it (1 cell = 2 world units) and a tilted RTS-style camera.

const GROUND_SIZE: float = 16.0
const CUBE_SIZE: float = 2.0


func _ready() -> void:
	var ground: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(GROUND_SIZE, GROUND_SIZE)
	ground.mesh = plane
	ground.material_override = _material(Color(0.45, 0.72, 0.35))
	add_child(ground)

	var cube: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3.ONE * CUBE_SIZE
	cube.mesh = box
	cube.position = Vector3(0.0, CUBE_SIZE * 0.5, 0.0)  # bottom face on the ground
	cube.material_override = _material(Color(0.2, 0.45, 1.0))
	add_child(cube)


func _material(color: Color) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	return mat
