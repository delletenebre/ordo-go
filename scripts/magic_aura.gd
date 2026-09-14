extends Node3D
## Persistent local magic: a surface halo, three mist sheets and twelve rising motes.
## All geometry/materials are allocated once; the effect travels with its source.
const SHADER = preload("res://shaders/magic_aura.gdshader")
var materials: Array[ShaderMaterial] = []
var motes: MultiMesh
var phase := 0.0
var strength := 1.0

func setup(color: Color, radius: float, is_curse: bool, seed_value: float) -> void:
	phase = seed_value * 1.731
	scale = Vector3.ONE * radius / 0.36
	for layer in 3:
		var mat := ShaderMaterial.new(); mat.shader = SHADER
		mat.set_shader_parameter("tint", color)
		mat.set_shader_parameter("cursed", 1.0 if is_curse and layer != 2 else 0.0)
		mat.set_shader_parameter("layer", layer)
		materials.append(mat)
	var floor_mesh := QuadMesh.new(); floor_mesh.size = Vector2(1.6, 1.6)
	var floor_node := sheet(floor_mesh, materials[0])
	floor_node.rotation.x = -PI / 2; floor_node.position.y = 0.015
	var mist := QuadMesh.new(); mist.size = Vector2(0.85, 1.0)
	for i in 3:
		var veil := sheet(mist, materials[1])
		var angle := i * TAU / 3 + 0.3
		veil.position = Vector3(sin(angle) * 0.43, 0.49, cos(angle) * 0.43)
		veil.rotation.y = angle
	var spark := QuadMesh.new(); spark.size = Vector2(0.075, 0.075)
	motes = MultiMesh.new(); motes.transform_format = MultiMesh.TRANSFORM_3D
	motes.mesh = spark; motes.instance_count = 12
	var sparks := MultiMeshInstance3D.new(); sparks.multimesh = motes
	sparks.material_override = materials[2]
	sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sparks)

func sheet(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new(); node.mesh = mesh; node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node

func step(time: float, opacity: float, camera_basis: Basis) -> void:
	var t := time + phase
	for mat in materials:
		mat.set_shader_parameter("clock", t)
		mat.set_shader_parameter("opacity", opacity * strength)
	for i in 12:
		var life := fposmod(t * 0.24 + i / 12.0, 1.0)
		var angle := i * 2.39996 + t * 0.7
		var radius := 0.39 + life * 0.16
		var size := sin(life * PI) * (0.65 + 0.35 * sin(i * 7.0 + t * 2.0))
		var point := Vector3(cos(angle) * radius, 0.08 + life * 0.95, sin(angle) * radius)
		motes.set_instance_transform(i, Transform3D(camera_basis.scaled(Vector3.ONE * size), point))
