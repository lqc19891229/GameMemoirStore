@tool
extends Node3D
## Modern oak desktop with a restrained matte-metal frame.

func _ready() -> void:
	if not has_node("Model"):
		_build()

func _material(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material

func _box(parent: Node, node_name: String, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = at
	instance.material_override = material
	parent.add_child(instance)
	return instance

func _build() -> void:
	var model := Node3D.new()
	model.name = "Model"
	add_child(model)
	var oak := _material(Color("b98e61"), 0.58)
	var edge := _material(Color("8a6648"), 0.64)
	var metal := _material(Color("4b5358"), 0.38, 0.78)
	var rubber := _material(Color("252b2e"), 0.86)
	_box(model, "OakDesktop", Vector3(4.8, 0.12, 2.3), Vector3(0, 0.72, 0), oak)
	_box(model, "FrontEdge", Vector3(4.78, 0.035, 0.035), Vector3(0, 0.665, 1.13), edge)
	_box(model, "RearEdge", Vector3(4.78, 0.035, 0.035), Vector3(0, 0.665, -1.13), edge)
	for x in [-2.18, 2.18]:
		for z in [-0.96, 0.96]:
			_box(model, "MetalLeg", Vector3(0.075, 0.64, 0.075), Vector3(x, 0.32, z), metal)
			_box(model, "FootPad", Vector3(0.12, 0.035, 0.12), Vector3(x, 0.025, z), rubber)
	_box(model, "FrontApron", Vector3(4.18, 0.34, 0.055), Vector3(0, 0.47, 0.98), metal)
	_box(model, "CableTray", Vector3(3.6, 0.055, 0.34), Vector3(0, 0.58, -0.68), rubber)
	_box(model, "LeftCrossbar", Vector3(0.055, 0.055, 1.75), Vector3(-2.18, 0.40, 0), metal)
	_box(model, "RightCrossbar", Vector3(0.055, 0.055, 1.75), Vector3(2.18, 0.40, 0), metal)
