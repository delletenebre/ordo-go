extends Node3D
## A fixed faceted crystal contains the moving flame above the altar bowl.

const FlameShader = preload("res://shaders/hearth_fire.gdshader")
var flame_material := ShaderMaterial.new()
var core_material := ShaderMaterial.new()
var core_surface: MeshInstance3D
var elapsed := 0.0
var strength := 1.0
var mend_age := 10.0

func mend() -> void:
	mend_age = 0.0

func _ready() -> void:
	name = "HearthFire"
	flame_material.shader = FlameShader
	core_material.shader = preload("res://shaders/crystal_inner_fire.gdshader")
	core_surface = MeshInstance3D.new()
	var sheet := QuadMesh.new()
	sheet.size = Vector2(0.44, 1.10)
	core_surface.mesh = sheet
	core_surface.material_override = core_material
	core_surface.position.y = 0.65
	core_surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(core_surface)
	var shell := MeshInstance3D.new()
	shell.mesh = ember_mesh()
	shell.material_override = flame_material
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shell)
	var edge_material := StandardMaterial3D.new()
	edge_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	edge_material.albedo_color = Color("ffe7a4")
	edge_material.emission_enabled = true
	edge_material.emission = Color("ffd176")
	edge_material.emission_energy_multiplier = 3.0
	for side in 6:
		var angle := float(side) / 6.0 * TAU + PI / 6.0
		var shoulder := Vector3(cos(angle)*0.255,0.45,sin(angle)*0.255)
		for tip in [Vector3(0,0.07,0),Vector3(0,1.24,0)]:
			var edge := MeshInstance3D.new()
			var tube := CylinderMesh.new()
			tube.top_radius = 0.004
			tube.bottom_radius = 0.004
			tube.height = shoulder.distance_to(tip)
			tube.radial_segments = 6
			edge.mesh = tube
			edge.material_override = edge_material
			edge.position = (shoulder+tip)*0.5
			var direction: Vector3 = (tip-shoulder).normalized()
			var right := Vector3.UP.cross(direction).normalized()
			edge.basis = Basis(right,direction,right.cross(direction))
			edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(edge)
	step(0.0, 1.0)

func ember_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in 6:
		var a := float(side)/6.0*TAU+PI/6.0
		var b := float(side+1)/6.0*TAU+PI/6.0
		var left := Vector3(cos(a)*0.255,0.45,sin(a)*0.255)
		var right := Vector3(cos(b)*0.255,0.45,sin(b)*0.255)
		for point in [Vector3(0,0.07,0),right,left,left,right,Vector3(0,1.24,0)]:
			surface.add_vertex(point)
	surface.generate_normals()
	return surface.commit()

func step(dt: float, fire_ratio: float) -> void:
	elapsed += dt
	mend_age += dt
	var warmth := sin(clampf(mend_age / 0.65, 0, 1) * PI)
	strength = lerpf(strength, clampf(fire_ratio, 0.0, 1.0), 1.0 - exp(-dt * 4.0))
	visible = fire_ratio > 0.0
	scale = Vector3.ONE * lerpf(0.58, 1.0, strength) * (1 + warmth * 0.12)
	flame_material.set_shader_parameter("mend_glow", warmth)
	flame_material.set_shader_parameter("elapsed", elapsed)
	core_material.set_shader_parameter("elapsed", elapsed)
	var camera := get_viewport().get_camera_3d()
	if camera:
		var to_camera := camera.global_position-global_position
		core_surface.rotation.y = atan2(to_camera.x,to_camera.z)

func light_energy() -> float:
	if not visible:
		return 0.0
	return (2.25 + sin(elapsed*2.8)*0.09 + sin(elapsed*5.1)*0.035) * lerpf(0.25, 1.0, strength) + sin(clampf(mend_age / 0.65, 0, 1) * PI) * 1.8
