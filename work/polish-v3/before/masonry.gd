class_name OrdoMasonry
extends RefCounted

# Bevelled, slightly chipped blocks with continuous edges between faces.
static func block(size: Vector3, seed_value: float = 0.0) -> ArrayMesh:
	var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := size * 0.5
	var bevel := minf(size.x, minf(size.y, size.z)) * 0.15
	var core := half - Vector3.ONE * bevel
	for axis in 3:
		for sign_value in [-1.0, 1.0]:
			var normal := Vector3.ZERO; normal[axis] = sign_value
			var u := Vector3.ZERO; u[(axis + 1) % 3] = 1.0
			var v := Vector3.ZERO; v[(axis + 2) % 3] = 1.0
			var us := [-half[(axis + 1) % 3], -core[(axis + 1) % 3], core[(axis + 1) % 3], half[(axis + 1) % 3]]
			var vs := [-half[(axis + 2) % 3], -core[(axis + 2) % 3], core[(axis + 2) % 3], half[(axis + 2) % 3]]
			for x in 3:
				for y in 3:
					var corners := [Vector2i(x,y), Vector2i(x+1,y), Vector2i(x+1,y+1), Vector2i(x,y), Vector2i(x+1,y+1), Vector2i(x,y+1)]
					if sign_value > 0: corners.reverse()
					for corner in corners:
						var p: Vector3 = normal * half[axis] + u * us[corner.x] + v * vs[corner.y]
						var inner := p.clamp(-core, core)
						var n := (p - inner).normalized()
						p = inner + n * bevel
						p += n * sin(p.dot(Vector3(11.7, 8.1, 13.4)) + seed_value * 7.1) * bevel * 0.15
						surface.set_normal(n)
						surface.add_vertex(p)
	return surface.commit()

static func hearth(arena) -> void:
	var root := Node3D.new(); root.name = "Hearth"; arena.add_child(root)
	arena.cylinder(root, Vector3(0, 0.10, 0), 1.13, 0.19, arena.stone_material(Color("443d3b")))
	for course in 2:
		for i in 12:
			var a := TAU * (i + course * 0.5) / 12.0
			var radius := 0.87 if course == 0 else 0.80
			var color := Color("796f61").lightened(sin(i * 4.1 + course) * 0.12)
			var rock = arena.mesh_node(root, block(Vector3(0.45, 0.30, 0.34), i + course * 12), Vector3(cos(a) * radius, 0.20 + course * 0.25, sin(a) * radius), arena.stone_material(color))
			rock.rotation.y = -a - PI / 2
	# A dark bowl, coals and crossed charred logs give the flame a physical source.
	arena.cylinder(root, Vector3(0, 0.22, 0), 0.68, 0.18, arena.stone_material(Color("24222b")))
	for i in 5:
		var log_mesh = arena.mesh_node(root, block(Vector3(0.23, 0.16, 1.10), i), Vector3(sin(i * 5.0) * 0.21, 0.35 + i * 0.018, cos(i * 5.0) * 0.12), arena.wool(Color("382725")))
		log_mesh.rotation.y = i * 1.22
	for i in 19:
		var a := i * 2.39996; var r := 0.53 * sqrt((i + 1) / 20.0)
		var coal = arena.mesh_node(root, block(Vector3(0.11, 0.075, 0.10), i), Vector3(cos(a)*r, 0.43, sin(a)*r), arena.material(Color("eb6732"), 0.8))
		coal.rotation.y = a
	# Small radial foundation stones, with gaps and a weathered outer rim.
	for i in 16:
		var a := TAU * i / 16.0
		var foot = arena.mesh_node(root, block(Vector3(0.24, 0.12, 0.35), i), Vector3(cos(a)*1.05, 0.08, sin(a)*1.05), arena.stone_material(Color("68605b")))
		foot.rotation.y = -a - PI/2

static func wall(arena) -> void:
	var root := Node3D.new(); root.name = "Rampart"; arena.add_child(root)
	for course in 3:
		for i in 64:
			var a := TAU * (i + (0.5 if course % 2 else 0.0)) / 64.0
			var tint := Color("454852").lightened(sin(i * 3.41 + course * 1.8) * 0.12)
			var rock = arena.mesh_node(root, block(Vector3(0.63, 0.29, 0.48), i + course * 17), Vector3(cos(a)*6.48, -0.37 + course * 0.28, sin(a)*6.48), arena.stone_material(tint))
			rock.rotation.y = -a - PI/2
	# Higher crenels behind the arena, a low front parapet preserves the view.
	for i in 32:
		var a := TAU * i / 32.0
		var rear := sin(a) < 0.25
		var height := 0.53 if rear else 0.18
		var rock = arena.mesh_node(root, block(Vector3(0.69, height, 0.55), i), Vector3(cos(a)*6.48, 0.34 + height*0.5, sin(a)*6.48), arena.stone_material(Color("434650").lightened(sin(i*3.9)*0.1)))
		rock.rotation.y = -a - PI/2

static func lantern(arena, p: Vector3, index: int) -> void:
	var root := Node3D.new(); arena.add_child(root); root.position = p
	var base = arena.mesh_node(root, block(Vector3(0.83, 0.22, 0.72), index), Vector3(0, -0.10, 0), arena.stone_material(Color("65606a")))
	base.rotation.y = index * 0.8
	var bronze = arena.material(Color("6f4628"))
	arena.cylinder(root, Vector3(0, 0.05, 0), 0.28, 0.12, bronze)
	arena.ring(root, Vector3(0, 0.16, 0), 0.25, 0.035, bronze)
	arena.ring(root, Vector3(0, 0.58, 0), 0.21, 0.025, bronze)
	for i in 6:
		var a := TAU*i/6.0
		OrdoWoolMesh.thread_path(root, PackedVector3Array([Vector3(cos(a)*0.25,0.13,sin(a)*0.25), Vector3(cos(a)*0.21,0.58,sin(a)*0.21), Vector3(0,0.80,0)]), 0.019, bronze)
	arena.make_flame(p + Vector3(0, 0.12, 0), 0.40)
	var light := OmniLight3D.new(); light.position = p + Vector3(0, 0.4, 0)
	light.light_color = Color("ffb566"); light.light_energy = 1.7; light.omni_range = 3.1; arena.add_child(light)
