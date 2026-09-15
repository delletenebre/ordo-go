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

# Bevelled voussoirs make the altar read as fitted masonry, even up close.
static func altar_segment(inner: float, outer: float, height: float, span: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bevel := minf(0.028, height * 0.18)
	var section := PackedVector2Array([
		Vector2(inner, bevel), Vector2(inner + bevel, 0),
		Vector2(outer - bevel, 0), Vector2(outer, bevel),
		Vector2(outer, height - bevel), Vector2(outer - bevel, height),
		Vector2(inner + bevel, height), Vector2(inner, height - bevel)])
	for step in 5:
		var a := -span * 0.5 + span * float(step) / 5.0
		var b := -span * 0.5 + span * float(step + 1) / 5.0
		for side in 8:
			var u := section[side]
			var v := section[(side + 1) % 8]
			var edge := v - u
			var normal := Vector3(cos((a+b)*0.5)*edge.y, -edge.x, sin((a+b)*0.5)*edge.y).normalized()
			altar_face(st, Vector3(cos(a)*u.x,u.y,sin(a)*u.x), Vector3(cos(b)*u.x,u.y,sin(b)*u.x), Vector3(cos(b)*v.x,v.y,sin(b)*v.x), Vector3(cos(a)*v.x,v.y,sin(a)*v.x), normal)
	for end in [-1.0, 1.0]:
		var angle: float = end * span * 0.5
		var normal: Vector3 = Vector3(-sin(angle),0,cos(angle)) * end
		var center := Vector3(cos(angle)*(inner+outer)*0.5,height*0.5,sin(angle)*(inner+outer)*0.5)
		for side in 8:
			var u := section[side]
			var v := section[(side+1)%8]
			altar_face(st, center, Vector3(cos(angle)*u.x,u.y,sin(angle)*u.x), Vector3(cos(angle)*v.x,v.y,sin(angle)*v.x), center, normal)
	return st.commit()

static func altar_face(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3) -> void:
	var points := [a,b,c,a,c,d]
	if (b-a).cross(c-a).dot(normal) > 0.0:
		points = [a,c,b,a,d,c]
	if d.is_equal_approx(a):
		points.resize(3)
	st.set_normal(normal)
	for point in points:
		st.add_vertex(point)

static func hearth(arena) -> void:
	var root := Node3D.new(); root.name = "Hearth"; arena.add_child(root)
	arena.cylinder(root, Vector3(0, 0.09, 0), 1.13, 0.16, arena.stone_material(Color("494143")))
	var courses := [Vector4(0.52,1.11,0.13,0.12), Vector4(0.62,0.98,0.23,0.24)]
	for course in courses.size():
		var dims: Vector4 = courses[course]
		var mesh := altar_segment(dims.x,dims.y,dims.z,TAU/16.0-0.016)
		for i in 16:
			var color := Color("82705b").lightened(sin(i*3.7+course)*0.065)
			var stone = arena.mesh_node(root,mesh,Vector3(0,dims.w,0),arena.stone_material(color))
			stone.rotation.y = TAU*(float(i)+course*0.5)/16.0
	# A recessed floor and a small raised offering bowl inside the broad stone step.
	arena.cylinder(root,Vector3(0,0.235,0),0.62,0.09,arena.stone_material(Color("56422e")))
	arena.cylinder(root,Vector3(0,0.29,0),0.44,0.12,arena.stone_material(Color("6f4e2e")),0.40)
	var bowl_mesh := altar_segment(0.29,0.43,0.115,TAU/12.0-0.026)
	for i in 12:
		var stone = arena.mesh_node(root,bowl_mesh,Vector3(0,0.34,0),arena.stone_material(Color("8c6036").lightened(sin(i*4.0)*0.06)))
		stone.rotation.y = i*TAU/12.0
	arena.cylinder(root,Vector3(0,0.36,0),0.29,0.035,arena.stone_material(Color("473326")))
	arena.cylinder(root,Vector3(0,0.39,0),0.095,0.025,arena.material(Color("ffc15d"),1.2))
	arena.ring(root,Vector3(0,0.385,0),0.17,0.009,arena.material(Color("dc913a"),0.6))
	arena.ring(root,Vector3(0,0.40,0),0.265,0.014,arena.material(Color("ffbd53"),1.5))
	# Four squat buttresses frame the flame without enclosing it in a tall wall.
	for i in 4:
		var angle := PI*0.25 + i*PI*0.5
		var foot := Node3D.new(); root.add_child(foot)
		foot.position = Vector3(cos(angle)*0.94,0,sin(angle)*0.94)
		foot.rotation.y = -angle-PI*0.5
		arena.mesh_node(foot,block(Vector3(0.40,0.14,0.46),100+i),Vector3(0,0.19,0.015),arena.stone_material(Color("5d5150")))
		for level in 2:
			arena.mesh_node(foot,block(Vector3(0.28,0.22,0.33),120+i*3+level),Vector3(0,0.35+level*0.20,0),arena.stone_material(Color("756454")))
		arena.mesh_node(foot,block(Vector3(0.35,0.13,0.40),140+i),Vector3(0,0.68,0),arena.stone_material(Color("635756")))
	var tablet = arena.mesh_node(root,block(Vector3(0.37,0.40,0.18),166),Vector3(0,0.59,-0.81),arena.stone_material(Color("82735f")))
	tablet.rotation.x = -0.10

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
			var r:=.35-.035*t+sin(t*PI)*.025
			points.append(Vector3(cos(a)*r,.40+t*.48,sin(a)*r))
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
	arena.sphere(root,Vector3(0,.32,0),Vector3(.065,.105,.065),bronze)
	var origin:=p+Vector3(0,.43,0)
	arena.make_flame(origin,.59)
	var light := OmniLight3D.new();light.name="Firelight%d"%index
	light.position=origin+Vector3(0,.28,0);light.light_color=Color("ffad57")
	light.light_energy=1.9;light.omni_range=2.5;light.omni_attenuation=1.3
	light.shadow_enabled=true;light.shadow_bias=.04;light.omni_shadow_mode=OmniLight3D.SHADOW_CUBE
	arena.add_child(light);arena.torches.append({"light":light,"phase":index*1.73,"origin":origin})
