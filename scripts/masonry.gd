class_name OrdoMasonry
extends RefCounted

# Shared corner positions keep each chipped block closed, including its bevels.
static func block(size: Vector3, seed_value: float = 0.0) -> ArrayMesh:
	var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := size * 0.5
	var bevel := minf(size.x, minf(size.y, size.z)) * 0.18
	var core := half - Vector3.ONE * bevel
	var noise := FastNoiseLite.new(); noise.seed = int(seed_value * 7919) + 171
	noise.frequency = 8.0; noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	for axis in 3:
		for sign_value in [-1.0, 1.0]:
			var normal := Vector3.ZERO; normal[axis] = sign_value
			var u := Vector3.ZERO; u[(axis + 1) % 3] = 1.0
			var v := Vector3.ZERO; v[(axis + 2) % 3] = 1.0
			var us := [-half[(axis+1)%3],-core[(axis+1)%3],-core[(axis+1)%3]*.42,0.0,core[(axis+1)%3]*.46,core[(axis+1)%3],half[(axis+1)%3]]
			var vs := [-half[(axis+2)%3],-core[(axis+2)%3],-core[(axis+2)%3]*.47,0.0,core[(axis+2)%3]*.39,core[(axis+2)%3],half[(axis+2)%3]]
			for x in 6:
				for y in 6:
					var corners := [Vector2i(x,y),Vector2i(x+1,y),Vector2i(x+1,y+1),Vector2i(x,y),Vector2i(x+1,y+1),Vector2i(x,y+1)]
					if sign_value > 0: corners.reverse()
					for corner in corners:
						var p: Vector3 = normal*half[axis]+u*us[corner.x]+v*vs[corner.y]
						var inner := p.clamp(-core,core)
						var n := (p-inner).normalized()
						var fracture := noise.get_noise_3dv(p)*bevel*.75
						p = inner+n*(bevel+fracture)
						surface.set_color(Color(1,1,1,1))
						surface.add_vertex(p)
	surface.generate_normals(); return surface.commit()

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
	var palette := [Color("47434a"),Color("55494a"),Color("514a45"),Color("5e5751"),Color("3b3a43"),Color("62584f")]
	# Wide offset stones with narrow dark joints; the top is a continuous parapet.
	for course in 3:
		var count: int = [47,53,49][course]
		for i in count:
			var a := TAU * (i + course*.47) / count
			var rear := 1.0-smoothstep(-.15,.70,sin(a))
			var h := .29 if course<2 else .22+rear*.17
			var y := -.35+course*.285 if course<2 else .08+h*.5
			var width := TAU*6.49/count-.023
			var rock = arena.mesh_node(root,block(Vector3(width,h,.68),i+course*73),Vector3(cos(a)*6.49,y,sin(a)*6.49),arena.stone_material(palette[(i*7+course*3)%palette.size()]))
			rock.rotation=Vector3(sin(i*6.1)*.018,-a-PI/2+sin(i*4.7)*.009,cos(i*3.2)*.018)
	# Broken shoulders between lantern towers, integrated into the top course.
	for i in 12:
		var a := TAU*(i+.40)/12.0+.3
		var rear := 1.0-smoothstep(-.15,.65,sin(a))
		if rear<.25:continue
		for j in 2:
			var angle := a+(j-.5)*.08
			var rock=arena.mesh_node(root,block(Vector3(.47,.20+rear*.16,.65),i*3+j+900),Vector3(cos(angle)*6.49,.50+rear*.05,sin(angle)*6.49),arena.stone_material(palette[(i+j)%palette.size()]))
			rock.rotation.y=-angle-PI/2
	# Loose weathered chips break the perfect circular foundation silhouette.
	for i in 46:
		var a := i*2.399963;var radius:=6.86+sin(i*3.4)*.08
		var rock=arena.mesh_node(root,block(Vector3(.16+fposmod(i*.13,.15),.12,.20),i+1700),Vector3(cos(a)*radius,-.36,sin(a)*radius),arena.stone_material(palette[i%palette.size()]))
		rock.rotation=Vector3(.2*sin(i),a,.18*cos(i))

static func lantern(arena, p: Vector3, index: int) -> void:
	var root := Node3D.new();root.name="Brazier%d"%index;arena.add_child(root);root.position=p
	root.rotation.y=-atan2(p.z,p.x)-PI/2
	var stone_colors := [Color("5d514c"),Color("4c4549"),Color("6d5b4b")]
	# Buttressed, layered stone plinth carrying a squat wrought-iron fire basket.
	for course in 3:
		for side in [-1.0,1.0]:
			var rock=arena.mesh_node(root,block(Vector3(.48,.25,.90),index*100+course*7+side),Vector3(side*.245,-.37+course*.24,0),arena.stone_material(stone_colors[course]))
			rock.rotation.y=course*.035
	arena.mesh_node(root,block(Vector3(1.10,.16,1.02),index+800),Vector3(0,.25,0),arena.stone_material(Color("76604b")))
	var iron: StandardMaterial3D = arena.material(Color("28201c"));iron.metallic=.72;iron.roughness=.58
	var bronze: StandardMaterial3D = arena.material(Color("81532d"));bronze.metallic=.75;bronze.roughness=.47
	arena.cylinder(root,Vector3(0,.36,0),.36,.12,iron,.32)
	arena.ring(root,Vector3(0,.32,0),.35,.032,bronze)
	arena.cylinder(root,Vector3(0,.405,0),.29,.035,arena.material(Color("ad3920"),.6))
	for i in 10:
		var a:=i*2.39996;var r:=.23*sqrt((i+1)/11.0)
		arena.mesh_node(root,block(Vector3(.10,.07,.09),i+index*10),Vector3(cos(a)*r,.45,sin(a)*r),arena.material(Color("e87924").darkened((i%3)*.12),.85))
	arena.ring(root,Vector3(0,.46,0),.36,.026,bronze)
	arena.ring(root,Vector3(0,.72,0),.34,.025,iron)
	arena.ring(root,Vector3(0,.84,0),.29,.025,bronze)
	for i in 8:
		var a:=TAU*i/8.0
		var points:=PackedVector3Array()
		for j in 17:
			var t:=float(j)/16
			var r:=.35*(1.0-pow(t,3.4))+.01
			points.append(Vector3(cos(a)*r,.40+t*.84,sin(a)*r))
		OrdoWoolMesh.thread_path(root,points,.022,iron)
		arena.sphere(root,Vector3(cos(a)*.364,.48,sin(a)*.364),Vector3.ONE*.047,bronze)
		# Paired forged scrolls around the bowl echo the ram-horn ornament.
		for side in [-1.0,1.0]:
			var scroll:=PackedVector3Array()
			for j in 21:
				var t:=float(j)/20;var angle:=t*TAU*1.05;var r:=.064*(1-t*.76)
				var along: float = side*(.06+cos(angle)*r)
				scroll.append(Vector3(cos(a)*.353-sin(a)*along,.58+sin(angle)*r,sin(a)*.353+cos(a)*along))
			OrdoWoolMesh.thread_path(root,scroll,.014,bronze)
	arena.sphere(root,Vector3(0,1.25,0),Vector3(.065,.105,.065),bronze)
	var origin:=p+Vector3(0,.43,0)
	arena.make_flame(origin,.59)
	var light := OmniLight3D.new();light.name="Firelight%d"%index
	light.position=origin+Vector3(0,.28,0);light.light_color=Color("ffad57")
	light.light_energy=2.8;light.omni_range=2.9;light.omni_attenuation=1.3
	light.shadow_enabled=true;light.shadow_bias=.04;light.omni_shadow_mode=OmniLight3D.SHADOW_CUBE
	arena.add_child(light);arena.torches.append({"light":light,"phase":index*1.73,"origin":origin})
