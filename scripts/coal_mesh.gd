class_name OrdoCoalMesh
extends RefCounted

# A carbon body with a few small felt ties; all geometry is built once per actor.
const TIE_DIRECTIONS=[Vector3(-.70,.43,.57),Vector3(.69,.53,.48),Vector3(-.13,.88,-.46)]
static func shape_noise(seed_value:int)->FastNoiseLite:
	var noise:=FastNoiseLite.new();noise.seed=seed_value;noise.frequency=1.8
	noise.noise_type=FastNoiseLite.TYPE_SIMPLEX_SMOOTH;return noise

static func pits(seed_value:int)->Array:
	var rng:=RandomNumberGenerator.new();rng.seed=seed_value+913
	var result:Array=[]
	for i in 7:
		var direction:=Vector3(rng.randf_range(-1,1),rng.randf_range(-.4,1),rng.randf_range(-1,1)).normalized()
		result.append({"direction":direction,"width":rng.randf_range(.15,.23),"depth":rng.randf_range(.045,.095)})
	return result

static func shell_point(direction:Vector3,radius:float,noise:FastNoiseLite,hollows:Array)->Vector3:
	var shape:=1.0+noise.get_noise_3dv(direction)*.085+noise.get_noise_3dv(direction*3.7)*.009
	for hollow in hollows:
		shape-=exp(-direction.distance_squared_to(hollow.direction)/(hollow.width*hollow.width))*hollow.depth
	return direction*radius*shape*Vector3(1,.96,.96)

static func shell(radius:float,seed_value:int,segments:int=64,rings:int=40,irregularity:float=1.0)->ArrayMesh:
	var noise:=shape_noise(seed_value);var hollows:=pits(seed_value)
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES);surface.set_smooth_group(0)
	for y in rings:
		for x in segments:
			for corner in [Vector2i(x,y),Vector2i(x+1,y+1),Vector2i(x+1,y),Vector2i(x,y),Vector2i(x,y+1),Vector2i(x+1,y+1)]:
				var a:float=TAU*corner.x/segments;var b:float=PI*corner.y/rings
				var direction:=Vector3(sin(b)*cos(a),cos(b),sin(b)*sin(a))
				surface.set_uv(Vector2(float(corner.x)/segments,float(corner.y)/rings))
				surface.add_vertex((direction*radius*Vector3(1,.96,.96)).lerp(shell_point(direction,radius,noise,hollows),irregularity))
	surface.index();surface.generate_normals();return surface.commit()

static func fur(radius:float,seed_value:int)->ArrayMesh:
	var noise:=shape_noise(seed_value);var hollows:=pits(seed_value)
	var rng:=RandomNumberGenerator.new();rng.seed=seed_value+61
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 54:
		var center:Vector3=TIE_DIRECTIONS[i%TIE_DIRECTIONS.size()].normalized()
		var tangent:=center.cross(Vector3.UP).normalized()
		var direction:Vector3=(center+tangent*rng.randf_range(-.18,.18)+Vector3.UP*rng.randf_range(-.035,.035)).normalized()
		var p:=shell_point(direction,radius,noise,hollows)+direction*radius*.028
		var length:=radius*rng.randf_range(.02,.045)
		var tip:=p+direction*length+tangent*length*.45
		var side:=tangent*radius*.0045
		for point in [p-side,p+side,tip]:
			surface.set_normal(direction);surface.add_vertex(point)
	return surface.commit()

static func binding_paths(radius:float,seed_value:int)->Array:
	var noise:=shape_noise(seed_value);var hollows:=pits(seed_value)
	var result:Array=[]
	for center_point in TIE_DIRECTIONS:
		var center:Vector3=center_point.normalized()
		var across:=center.cross(Vector3.UP).normalized()
		for strand in 3:
			var points:=PackedVector3Array()
			for i in 9:
				var t:=float(i)/8.0
				var direction:Vector3=(center+across*(t-.5)*.42+Vector3.UP*((strand-1)*.022+sin(t*PI)*.025)).normalized()
				points.append(shell_point(direction,radius,noise,hollows)+direction*radius*.025)
			result.append(points)
	return result

static func material_for(kind: String, seed_value: int) -> ShaderMaterial:
	var mat := ShaderMaterial.new(); mat.shader = preload("res://shaders/coal.gdshader")
	mat.set_shader_parameter("soot_map",preload("res://assets/coal-soft-v3.png"))
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
