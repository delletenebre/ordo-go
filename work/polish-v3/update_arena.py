from pathlib import Path
p=Path('scripts/arena.gd');s=p.read_text()
s=s.replace('const EnemyFace =','const CoalMesh = preload("res://scripts/coal_mesh.gd")\nconst EnemyFace =')
s=s.replace('settings.ambient_light_energy = 0.30','settings.ambient_light_energy = 0.23')
s=s.replace('settings.ssao_intensity = 1.4','settings.ssao_intensity = 1.75')
s=s.replace('camera.position = Vector3(0, 15.5, 14.0); add_child(camera); camera.look_at(Vector3(0, 0, 0.6))','camera.position = Vector3(0, 21.0, 11.2); add_child(camera); camera.look_at(Vector3(0, 0, 0.45))')
s=s.replace('Vector3(cos(a)*6.48,0.48,sin(a)*6.48)','Vector3(cos(a)*6.62,0.32,sin(a)*6.62)')
a=s.index('func flame_shape');b=s.index('func create_actor',a)
s=s[:a]+'''func flame_shape(size: float) -> ArrayMesh:
	var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Curved ribbons, with enough height segments for flowing tongues, not rigid cones.
	for y in 24:
		for x in 4:
			for corner in [Vector2i(x,y),Vector2i(x+1,y),Vector2i(x+1,y+1),Vector2i(x,y),Vector2i(x+1,y+1),Vector2i(x,y+1)]:
				var h:=float(corner.y)/24;var u:=float(corner.x)/4
				var width:=pow(sin(PI*h),.62)*(.42-h*.24)
				surface.set_uv(Vector2(u,h))
				surface.add_vertex(Vector3((u-.5)*width*size*2.0+sin(h*3.5)*h*.07*size,h*size*1.46,sin(u*PI)*.06*size))
	surface.generate_normals();return surface.commit()

func make_flame(p: Vector3, size: float) -> Node3D:
	var root:=Node3D.new();add_child(root);root.position=p
	var tongues:Array=[]
	for i in 7:
		var mat:=ShaderMaterial.new();mat.shader=preload("res://shaders/flame.gdshader")
		mat.set_shader_parameter("tint",Color("ff8221") if i<4 else Color("ffd273"))
		mat.set_shader_parameter("heat",1.5 if i<4 else 1.8)
		mat.set_shader_parameter("phase",visual_rng.randf()*TAU)
		var length:=size*(1.0-float(i%4)*.14)
		var angle:=i*2.39996
		var tongue:=mesh_node(root,flame_shape(length),Vector3(cos(angle),0,sin(angle))*size*.11,mat)
		ongue.rotation.y=angle;tongue.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tongues.append(mat)
	flames.append({"root":root,"tongues":tongues,"size":size,"offset":visual_rng.randf()*TAU})
	return root

'''+s[b:]
s=s.replace('var body := sphere(root, Vector3(0, r * 0.9, 0), Vector3(r * 1.95, r * 1.8, r * 1.85), wool(color.darkened(0.12))); body.name = "Body"','var coal_material := CoalMesh.material_for(e.kind,int(e.id))\n\t\tvar body := mesh_node(root,CoalMesh.shell(r,int(e.id)),Vector3(0,r*.94,0),coal_material);body.name="Body"')
s=s.replace('Vector3(r*0.55,r*0.3,r*0.7),wool(color.darkened(0.12))','Vector3(r*0.46,r*0.28,r*0.57),coal_material')
s=s.replace('\n\t\tstitches(root, r * 0.77, r * 1.2, 18, color.lightened(0.12), 0.3)','')
a=s.index('\tfor flame in flames:\n');b=s.index('\tflame_root.visible',a)
s=s[:a]+'''	for flame in flames:
		var t:float=clock+float(flame.offset)
		flame.root.scale=Vector3(1.0+sin(t*3.1)*.045,1.0+sin(t*4.7)*.08+sin(t*7.1)*.03,1.0+cos(t*3.7)*.035)
		for mat in flame.tongues:mat.set_shader_parameter("elapsed",clock)
		if visual_rng.randf()<dt*9.0:
			particle(flame.root.position+Vector3(0,float(flame.size)*.7,0),Vector3(visual_rng.randf_range(-.15,.15),1.6,visual_rng.randf_range(-.15,.15)),Color("ffd378"),.9,.24)
	for torch in torches:
		var t:float=clock+float(torch.phase)
		torch.light.light_energy=2.8+sin(t*5.3)*.13+sin(t*8.7)*.065
		torch.light.position=torch.origin+Vector3(sin(t*3.1)*.025,.28+sin(t*4.7)*.025,cos(t*3.7)*.02)
'''+s[b:]
s=s.replace('(2.7 + sin(clock * 2.6) * 0.055)','(2.7 + sin(clock * 5.1) * 0.12 + sin(clock * 7.3) * 0.05)')
p.write_text(s)
p=Path('scripts/enemy_face.gd');s=p.read_text()
s=s.replace('var dark=arena.wool(Color("171522"))','var dark=arena.material(Color("080a0e"))')
s=s.replace('var mouth_size:=Vector2(0.33,0.07)','var mouth_size:=Vector2(0.33,0.16)')
# Tilt all facial geometry together toward the elevated tabletop camera.
s=s.replace('\nfunc react(','''\n	var pivot:=Vector3(0,r*.92,0)
	var tilt:=Basis(Vector3.RIGHT,-.52)
	for part in get_children():
		part.position=pivot+tilt*(part.position-pivot)
		part.basis=tilt*part.basis

func react(''')
# Animated brows previously overwrote world y after tilt. Save their base positions.
s=s.replace('var brows: Array=[]','var brows: Array=[]\nvar brow_origins:Array=[]')
s=s.replace('\nfunc react(', '\n\tfor brow in brows:brow_origins.append(brow.position)\n\nfunc react(')
s=s.replace('radius*(1.39+brow_raise)','brow_origins[i].y+radius*brow_raise')
p.write_text(s)
