class_name OrdoEnemyMaterials
extends RefCounted
const Motion=preload("res://scripts/enemy_motion.gd")
const Coal=preload("res://scripts/coal_mesh.gd")
static func surface(kind:String,seed_value:int=77)->ShaderMaterial:
	var family:=Motion.material_kind(kind)
	if family=="coal":return Coal.material_for(kind,seed_value)
	if family=="felt":
		var wool:=ShaderMaterial.new();wool.shader=preload("res://shaders/felt.gdshader")
		wool.set_shader_parameter("wool_color",Color("665c51"))
		wool.set_shader_parameter("wool_detail",preload("res://assets/enemy-felt-v1.png"))
		wool.set_shader_parameter("fiber_scale",1.15)
		return wool
	var mat:=ShaderMaterial.new();mat.shader=preload("res://shaders/enemy_surface.gdshader")
	mat.set_shader_parameter("detail_map",preload("res://assets/enemy-celadon-v1.png") if family=="ceramic" else preload("res://assets/coal-soft-v3.png"))
	mat.set_shader_parameter("base_color",Color("4b5260") if family=="stone" else Color("9dac9d"))
	mat.set_shader_parameter("ceramic",1.0 if family=="ceramic" else 0.0)
	mat.set_shader_parameter("map_scale",1.25 if family=="ceramic" else 1.7)
	return mat
