class_name OrdoCoalMesh
extends RefCounted

# A closed carbon shell; shape noise is sampled only during construction.
static func shell(radius: float, seed_value: int, segments: int = 48, rings: int = 28) -> ArrayMesh:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value; noise.frequency = 3.1
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
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

static func fragment(seed_value: int) -> ArrayMesh:
	var rng:=RandomNumberGenerator.new();rng.seed=seed_value
	var vertices:=PackedVector3Array()
	for point in [Vector3(-1,-1,-1),Vector3(1,-1,-1),Vector3(1,1,-1),Vector3(-1,1,-1),Vector3(-1,-1,1),Vector3(1,-1,1),Vector3(1,1,1),Vector3(-1,1,1)]:
		vertices.append(point*Vector3(rng.randf_range(.65,1.0),rng.randf_range(.35,.8),rng.randf_range(.60,1.0)))
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in [[0,1,2,3],[5,4,7,6],[4,0,3,7],[1,5,6,2],[3,2,6,7],[4,5,1,0]]:
		for index in [0,1,2,0,2,3]:
			surface.set_smooth_group(-1);surface.add_vertex(vertices[face[index]])
	surface.generate_normals();return surface.commit()
