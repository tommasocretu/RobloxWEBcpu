class_name PartFactory
extends RefCounted
## Crea "Part" in stile Roblox: scatole con mesh a tinta unita e collisione box.
## Una Part ancorata è un StaticBody3D; una non ancorata è un RigidBody3D (fisica Jolt).


static func make_part(size: Vector3, color: Color, anchored: bool = true) -> Node3D:
	var body: CollisionObject3D
	if anchored:
		body = StaticBody3D.new()
	else:
		body = RigidBody3D.new()
	decorate(body, size, color)
	return body


static func decorate(body: CollisionObject3D, size: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	mesh.material_override = material
	body.add_child(mesh)

	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
