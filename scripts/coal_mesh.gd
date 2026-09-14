class_name OrdoCoalMesh
extends RefCounted

# A closed carbon shell; shape noise is sampled only during construction.
static func shell(radius: float, seed_value: int) -> ArrayMesh:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value; noise.frequency = 3.1
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 48; var rings := 28
	for y in rings:
		for x in segments:
			for corner in [Vector2i(x,y),Vector2i(x+1,y+1),Vector2i(x+1,y),Vector2i(x,y),Vector2i(x,y+1),Vector2i(x+1,y+1)]:
				var a: float = TAU * corner.x / segments; var b: float = PI * corner.y / rings
				var direction := Vector3(sin(b)*cos(a),cos(b),sin(b)*sin(a))
				var lump := noise.get_noise_3dv(direction) * 0.17
				var chip := noise.get_noise_3dv(direction * 3.7) * 0.038
				var p := direction * radius * (1.0+lump+chip)
				p.y *= 0.92; p.z *= 0.95
				surface.set_uv(Vector2(float(corner.x)/segments,float(corner.y)/rings))
				surface.add_vertex(p)
	surface.generate_normals(); return surface.commit()

static func material_for(kind: String, seed_value: int) -> ShaderMaterial:
	var mat := ShaderMaterial.new(); mat.shader = preload("res://shaders/coal.gdshader")
	mat.set_shader_parameter("soot_map",preload("res://assets/coal-detail.png"))
	mat.set_shader_parameter("map_offset",Vector3(seed_value*.131,seed_value*.371,seed_value*.217))
	var accent: Color = {"frost":Color("8bbdcf"),"hopper":Color("61557a"),"weaver":Color("7e8d98"),"eater":Color("a1452e")}.get(kind,Color("656673"))
	mat.set_shader_parameter("ash_tint",accent)
	return mat
