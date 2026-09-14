class_name OrdoArena
extends Node3D

const Catalog = preload("res://scripts/catalog.gd")
const Felt = preload("res://shaders/felt.gdshader")
const WoolMesh = preload("res://scripts/wool_mesh.gd")
const GameAudio = preload("res://scripts/audio.gd")
var audio_system
const CoalMesh = preload("res://scripts/coal_mesh.gd")
const EnemyFace = preload("res://scripts/enemy_face.gd")
const SpiritVisuals = preload("res://scripts/spirit_visuals.gd")
var spirit_visuals
const Masonry = preload("res://scripts/masonry.gd")
const Smoke = preload("res://scripts/smoke.gd")
var smoke
var retiring: Dictionary = {}
var smoke_timers: Dictionary = {}
var combo_hits:=0
var combo_last:=-10.0
var camera: Camera3D
var actors: Dictionary = {}
var cloth: Dictionary = {}
var actor_root := Node3D.new()
var particles: Array = []
var particle_cursor := 0
var particle_mesh := SphereMesh.new()
var clock := 0.0
var flame_root: Node3D
var fire_light: OmniLight3D
var last_event := 0
var shake := 0.0
var visual_rng := RandomNumberGenerator.new()
var flames: Array = []
var trail_time := 0.0
var muted := false
var torches: Array = []
var coal_portrait: Texture2D

func _ready() -> void:
	visual_rng.seed = 77381
	make_world()
	add_child(actor_root)
	make_coal_portrait()
	smoke = Smoke.new(); add_child(smoke)
	spirit_visuals = SpiritVisuals.new(); add_child(spirit_visuals)
	particle_mesh.radius = 0.065; particle_mesh.height = 0.13
	particle_mesh.radial_segments = 6; particle_mesh.rings = 3
	for i in 220:
		var mesh := MeshInstance3D.new(); mesh.mesh = particle_mesh
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh.material_override = material; mesh.visible = false
		add_child(mesh)
		particles.append({"node": mesh, "mat": material, "life": 0.0, "max": 1.0, "v": Vector3.ZERO, "size": 1.0})
	make_sounds()

func make_coal_portrait() -> void:
	var viewport:=SubViewport.new();viewport.name="CoalPortrait"
	viewport.size=Vector2i(128,128);viewport.transparent_bg=true
	viewport.world_3d=World3D.new();viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	add_child(viewport)
	var environment:=Environment.new();environment.background_mode=Environment.BG_COLOR
	environment.background_color=Color(0,0,0,0);environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color=Color("b8c9e0");environment.ambient_light_energy=.7
	var portrait_environment:=WorldEnvironment.new();portrait_environment.environment=environment
	viewport.add_child(portrait_environment)
	var head:=Node3D.new();viewport.add_child(head)
	mesh_node(head,CoalMesh.shell(1.0,31),Vector3(0,.94,0),CoalMesh.material_for("coal",31))
	var face:=EnemyFace.new();head.add_child(face);face.build(self,1.0,31);face.react("surprise");face.step(.2,Vector2.ZERO)
	var lamp:=DirectionalLight3D.new();lamp.rotation_degrees=Vector3(-35,-30,0);lamp.light_energy=1.7;viewport.add_child(lamp)
	var view:=Camera3D.new();viewport.add_child(view);view.projection=Camera3D.PROJECTION_ORTHOGONAL;view.size=2.6
	view.position=Vector3(0,2.6,4.5);view.look_at(Vector3(0,.95,0));view.current=true
	coal_portrait=viewport.get_texture()

func wool(color: Color) -> ShaderMaterial:
	var key := color.to_html()
	if cloth.has(key): return cloth[key]
	var mat := ShaderMaterial.new(); mat.shader = Felt
	mat.set_shader_parameter("wool_color", color)
	mat.set_shader_parameter("wool_detail", preload("res://assets/wool-detail.png"))
	cloth[key] = mat
	return mat

func stone_material(color: Color) -> ShaderMaterial:
	var key := "stone:"+color.to_html()
	if cloth.has(key): return cloth[key]
	var mat := ShaderMaterial.new(); mat.shader = preload("res://shaders/stone.gdshader")
	mat.set_shader_parameter("rock_color",preload("res://assets/stone-detail.png"))
	mat.set_shader_parameter("stone_color",color)
	mat.set_shader_parameter("map_offset",Vector3(color.r*8.3,color.g*7.1,color.b*4.7))
	cloth[key] = mat
	return mat

func material(color: Color, glow: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new(); mat.albedo_color = color; mat.roughness = 0.88
	if glow > 0.0: mat.emission_enabled = true; mat.emission = color; mat.emission_energy_multiplier = glow
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat

func mesh_node(parent: Node3D, mesh: Mesh, p: Vector3, mat: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new(); n.mesh = mesh; n.position = p; n.material_override = mat; parent.add_child(n)
	return n

func sphere(parent: Node3D, p: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new(); mesh.radius = 0.5; mesh.height = 1.0; mesh.radial_segments = 24; mesh.rings = 12
	var n := mesh_node(parent, mesh, p, mat); n.scale = size; return n

func cylinder(parent: Node3D, p: Vector3, radius: float, height: float, mat: Material, top: float = -1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new(); mesh.bottom_radius = radius; mesh.top_radius = radius if top < 0 else top
	mesh.height = height; mesh.radial_segments = 48
	return mesh_node(parent, mesh, p, mat)

func ring(parent: Node3D, p: Vector3, radius: float, thickness: float, mat: Material) -> MeshInstance3D:
	var mesh := TorusMesh.new(); mesh.inner_radius = radius - thickness; mesh.outer_radius = radius + thickness
	mesh.rings = 64; mesh.ring_segments = 8
	return mesh_node(parent, mesh, p, mat)

func box(parent: Node3D, p: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new(); mesh.size = size
	return mesh_node(parent, mesh, p, mat)

func stitches(parent: Node3D, radius: float, y: float, count: int, color: Color, tilt: float = 0.0) -> void:
	var mesh := CapsuleMesh.new(); mesh.radius = 0.012; mesh.height = 0.09; mesh.radial_segments = 4; mesh.rings = 1
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.mesh = mesh; mm.instance_count = count
	for i in count:
		var a := TAU * i / float(count)
		var basis := Basis(Vector3.UP, -a).rotated(Vector3(cos(a), 0, sin(a)), PI / 2.0 + tilt)
		mm.set_instance_transform(i, Transform3D(basis, Vector3(cos(a) * radius, y, sin(a) * radius)))
	var node := MultiMeshInstance3D.new(); node.multimesh = mm; node.material_override = wool(color); parent.add_child(node)

func disk_texture() -> ArrayMesh:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 160:
		var a := TAU * i / 160.0; var b := TAU * (i + 1) / 160.0
		for point in [Vector2.ZERO, Vector2(cos(a), sin(a)), Vector2(cos(b), sin(b))]:
			st.set_normal(Vector3.UP); st.set_uv(Vector2(0.5, 0.5) + point * 0.482)
			st.add_vertex(Vector3(point.x * 6.2, 0.04, point.y * 6.2))
	return st.commit()

func make_world() -> void:
	var env := WorldEnvironment.new(); var settings := Environment.new()
	settings.background_mode = Environment.BG_CANVAS; settings.background_canvas_max_layer = -1
	var background := CanvasLayer.new(); background.layer = -1; add_child(background)
	var backdrop := TextureRect.new(); backdrop.texture = load("res://assets/mountains.png")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED; background.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("a3bbd4"); settings.ambient_light_energy = 0.23
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	settings.glow_enabled = true; settings.glow_intensity = 0.65; settings.glow_bloom = 0.12
	settings.ssao_enabled = true; settings.ssao_radius = 0.8; settings.ssao_intensity = 1.75
	env.environment = settings; add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_color = Color("ffdfb6"); sun.light_energy = 0.60; sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40; add_child(sun)
	var rim := DirectionalLight3D.new(); rim.rotation_degrees = Vector3(-30, 145, 0)
	rim.light_color = Color("83bfff"); rim.light_energy = 0.4; add_child(rim)
	camera = Camera3D.new(); camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.keep_aspect = Camera3D.KEEP_WIDTH; camera.fov = 55.5
	camera.position = Vector3(0, 21.0, 11.2); add_child(camera); camera.look_at(Vector3(0, 0, 0.45))
	camera.current = true
	camera.near = 5.0; camera.far = 45.0
	cylinder(self, Vector3(0, -0.56, 0), 6.7, 0.75, wool(Color("312f37")))
	cylinder(self, Vector3(0, -0.15, 0), 6.38, 0.24, wool(Color("6b3234")))
	ring(self, Vector3(0, -0.03, 0), 6.29, 0.055, wool(Color("d2ad7c")))
	stitches(self, 6.33, 0.05, 240, Color("d8b78b"))
	var rug := StandardMaterial3D.new(); rug.albedo_texture = load("res://assets/shyrdak-v2.png"); rug.roughness = 1.0
	mesh_node(self, disk_texture(), Vector3.ZERO, rug)
	for a in [0.3, 1.85, 3.4, 4.95]:
		var stone := Node3D.new(); stone.position = Vector3(cos(a)*4.6, 0.24, sin(a)*4.6); stone.rotation.y = -a; add_child(stone)
		mesh_node(stone, Masonry.block(Vector3(0.92, 0.42, 0.83), a), Vector3.ZERO, stone_material(Color("969084")))
		var rune := PackedVector3Array()
		for i in 65:
			var t := float(i)/64; var r := 0.22*(1-t*0.85); var angle := t*TAU*1.65
			rune.append(Vector3(cos(angle)*r,0.22,sin(angle)*r))
		WoolMesh.thread_path(stone,rune,0.025,wool(Color("41424b")))
	Masonry.wall(self)
	for i in 6:
		var a := TAU*i/6.0+0.3
		Masonry.lantern(self, Vector3(cos(a)*6.62,0.32,sin(a)*6.62),i)
	Masonry.hearth(self)
	flame_root = make_flame(Vector3(0, 0.40, 0), 0.97)
	fire_light = OmniLight3D.new(); fire_light.position = Vector3(0, 1.6, 0); fire_light.omni_range = 8.0
	fire_light.light_color = Color("ffb353"); fire_light.light_energy = 3.0; add_child(fire_light)

func flame_shape(size: float) -> ArrayMesh:
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
		tongue.rotation.y=angle;tongue.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tongues.append(mat)
	flames.append({"root":root,"tongues":tongues,"size":size,"offset":visual_rng.randf()*TAU})
	return root

func create_actor(e: Dictionary, is_player: bool) -> Node3D:
	var root := Node3D.new(); actor_root.add_child(root)
	var color: Color = Catalog.COLORS[int(e.id)] if is_player else Color(Catalog.ENEMIES[e.kind].color)
	var r := float(e.r)
	var shadow_mesh := PlaneMesh.new(); shadow_mesh.size = Vector2(r * 2.5, r * 2.5)
	var shadow_material := ShaderMaterial.new(); shadow_material.shader = preload("res://shaders/contact_shadow.gdshader")
	var contact := mesh_node(root, shadow_mesh, Vector3(0, 0.047, 0), shadow_material)
	contact.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if is_player:
		var body_color: Color = [Color("185bb5"), Color("bc842b"), Color("227c47"), Color("ad2f40")][int(e.id)]
		var cap := ShaderMaterial.new(); cap.shader=preload("res://shaders/token.gdshader")
		cap.set_shader_parameter("caps",preload("res://assets/player-caps-v2.png"));cap.set_shader_parameter("wool",preload("res://assets/wool-detail.png"))
		cap.set_shader_parameter("side_color",body_color);cap.set_shader_parameter("slot",int(e.id));cap.set_shader_parameter("radius",r)
		mesh_node(root,WoolMesh.token(r),Vector3.ZERO,cap).name="Body"
		var halo := ring(root, Vector3(0, 0.07, 0), r * 1.13, 0.010, material(color, 0.65)); halo.name = "Halo"
		var shield_mat := ShaderMaterial.new(); shield_mat.shader = preload("res://shaders/shield.gdshader")
		shield_mat.set_shader_parameter("shield_color", Color("ffcc74"))
		var shield := sphere(root, Vector3(0, 0.08, 0), Vector3(3.9, 2.1, 3.9) if int(e.id) == 1 else Vector3(1.3, 1.0, 1.3), shield_mat)
		shield.name = "Shield"; shield.visible = false; shield.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		var coal_material := CoalMesh.material_for(e.kind,int(e.id))
		var body := mesh_node(root,CoalMesh.shell(r,int(e.id)),Vector3(0,r*.94,0),coal_material);body.name="Body"

		var face:=EnemyFace.new();face.name="Face";root.add_child(face);face.build(self,r,int(e.id))
		for side in [-1,1]:
			sphere(root,Vector3(side*r*0.52,0.08,0.1),Vector3(r*0.46,r*0.28,r*0.57),coal_material)

		if e.kind in ["ram", "brute", "eater"]:
			for side in [-1, 1]:
				var horn := ring(root, Vector3(side * r * 0.85, r * 1.3, 0.0), r * 0.32, r * 0.105, wool(Color("c6b8a1")))
				horn.rotation.x = PI * 0.5
		if e.kind in ["moth", "hopper", "weaver"]:
			for side in [-1, 1]:
				var wing := sphere(root, Vector3(side * r * 0.85, r * 1.0, -0.2), Vector3(r * 1.2, 0.10, r * 1.6), wool(color.lightened(0.18)))
				wing.rotation.z = side * 0.35
		if e.kind == "eater":
			ring(root, Vector3(0, r * 1.65, 0), r * 0.6, 0.06, material(Color("ff7755"), 1.0))
	root.position = Vector3(float(e.x), 0, float(e.z))
	return root

func render_state(sim, dt: float, remote: bool = false) -> void:
	clock += dt; trail_time += dt
	var live: Dictionary = {}
	for e in sim.players + sim.enemies:
		var key := str(int(e.id)); live[key] = true
		retiring.erase(key)
		var is_player: bool = not e.has("kind")
		if not actors.has(key): actors[key] = create_actor(e, is_player)
		var root: Node3D = actors[key]
		var target := Vector3(float(e.x), 0.03, float(e.z))
		if e.has("jump") and float(e.jump) > 0: target.y += sin(float(e.jump) * PI) * 2.4
		var previous := root.position
		if not is_player:
			var speed := Vector2(float(e.vx), float(e.vz)).length()
			var interval := 0.10 if speed > 0.7 else 0.30
			smoke_timers[key] = float(smoke_timers.get(key, 0.0)) + dt
			if float(smoke_timers[key]) >= interval:
				smoke_timers[key] = fmod(float(smoke_timers[key]), interval)
				var a := visual_rng.randf() * TAU
				var offset := Vector3(cos(a)*0.6,0,sin(a)*0.3-0.45) * float(e.r)
				var drift := Vector3(-float(e.vx) * 0.055, 0.32, -0.12-float(e.vz) * 0.055)
				smoke.emit_puff(previous + offset + Vector3(0, 0.25, 0), drift, float(e.r) * 1.9, 2.1, 0.25)
		root.position = root.position.lerp(target, 1.0 - exp(-28.0 * dt)) if remote else target
		if not is_player:
			root.rotation.y = lerp_angle(root.rotation.y, sin(float(e.angle)) * 0.18, 1.0 - exp(-8.0 * dt))
			var look:=Vector2.ZERO
			var nearest:=INF
			for player in sim.players:
				var delta:=Vector2(float(player.x)-float(e.x),float(player.z)-float(e.z))
				if int(player.hp)>0 and delta.length()<nearest:nearest=delta.length();look=delta.normalized()
			root.get_node("Face").step(dt,look)
			var breathing := sin(clock * 3.0 + int(e.id)) * 0.025
			root.scale = Vector3(1.0 + breathing, 1.0 - breathing, 1.0 + breathing)
		else:
			root.scale.y = lerpf(root.scale.y, 0.40 if int(e.hp) <= 0 else 1.0, 1.0 - exp(-12.0 * dt))
			root.get_node("Halo").visible = int(e.hp) > 0
			root.get_node("Shield").visible = int(e.hp) > 0 and int(e.shield) > 0
			if e.statuses.has("burn") and visual_rng.randf() < dt * 16:
				particle(root.position + Vector3(0, 0.45, 0), Vector3(0, 1.1, 0), Color("ff8c51"), 0.7, 0.45)
		if trail_time > 0.026 and Vector2(float(e.vx), float(e.vz)).length() > 1.3:
			var color: Color = Catalog.COLORS[int(e.id)] if is_player else Color("b0a18c")
			particle(previous + Vector3(0, 0.13, 0), Vector3(0, 0.2, 0), color, 0.36, 0.7)
	for key in actors.keys():
		if not live.has(key) and not retiring.has(key):
			retiring[key] = {"age": 0.0, "position": actors[key].position, "scale": actors[key].scale}
	for key in retiring.keys():
		var retirement: Dictionary = retiring[key]; retirement.age += dt
		var root: Node3D = actors[key]
		var t := clampf(float(retirement.age) / 0.65, 0.0, 1.0)
		root.scale = retirement.scale * (1.0 - t * t * 0.92)
		root.position = retirement.position + Vector3(0, -t * 0.16, 0)
		if t >= 1.0:
			root.queue_free(); actors.erase(key); retiring.erase(key); smoke_timers.erase(key)
	if trail_time > 0.026: trail_time = 0.0
	for event in sim.events:
		if int(event.id) > last_event:
			last_event = int(event.id); play_event(event)
	for flame in flames:
		var t:float=clock+float(flame.offset)
		flame.root.scale=Vector3(1.0+sin(t*3.1)*.045,1.0+sin(t*4.7)*.08+sin(t*7.1)*.03,1.0+cos(t*3.7)*.035)
		for mat in flame.tongues:mat.set_shader_parameter("elapsed",clock)
		if visual_rng.randf()<dt*9.0:
			particle(flame.root.position+Vector3(0,float(flame.size)*.7,0),Vector3(visual_rng.randf_range(-.15,.15),1.6,visual_rng.randf_range(-.15,.15)),Color("ffd378"),.9,.24)
	for torch in torches:
		var t:float=clock+float(torch.phase)
		torch.light.light_energy=2.8+sin(t*5.3)*.13+sin(t*8.7)*.065
		torch.light.position=torch.origin+Vector3(sin(t*3.1)*.025,.28+sin(t*4.7)*.025,cos(t*3.7)*.02)
	flame_root.visible = sim.fire > 0
	fire_light.light_energy = (2.7 + sin(clock * 5.1) * 0.12 + sin(clock * 7.3) * 0.05) * maxf(0.1, float(sim.fire) / maxf(1.0, float(sim.max_fire)))
	shake = maxf(0.0, shake - dt * 1.6)
	camera.h_offset = sin(clock * 18.0) * shake * shake * 0.095
	camera.v_offset = cos(clock * 16.0) * shake * shake * 0.075
	smoke.step(dt, camera.global_basis)
	spirit_visuals.step(sim,self,dt)
	for item in particles:
		if float(item.life) <= 0.0: continue
		item.life -= dt
		var mesh: MeshInstance3D = item.node
		if float(item.life) <= 0.0: mesh.visible = false; continue
		item.v.y -= dt * 1.5; mesh.position += item.v * dt
		mesh.scale = Vector3.ONE * float(item.size) * maxf(0.01, float(item.life) / float(item.max))
		var color: Color = item.mat.albedo_color; color.a = minf(1.0, float(item.life) * 4.0); item.mat.albedo_color = color

func particle(p: Vector3, velocity_value: Vector3, color: Color, life: float, size: float) -> void:
	var slot := -1
	for offset in particles.size():
		var candidate := (particle_cursor + offset) % particles.size()
		if float(particles[candidate].life) <= 0.0: slot = candidate; break
	if slot < 0: return
	var item: Dictionary = particles[slot]; particle_cursor = (slot + 1) % particles.size()
	item.node.position = p; item.node.visible = true; item.mat.albedo_color = color
	item.life = life; item.max = life; item.v = velocity_value; item.size = size
	item.node.scale = Vector3.ONE * size

func play_event(e: Dictionary) -> void:
	var kind: String = e.kind
	if kind=="enemy_mood":
		sound(e.text)
		var key:=str(int(e.get("actor",-1)))
		if actors.has(key) and actors[key].has_node("Face"):actors[key].get_node("Face").react(e.text,0.85)
		return
	if kind=="impact":
		if e.get("attacking",true):
			combo_hits=combo_hits+1 if clock-combo_last<0.8 else 1;combo_last=clock
		var heavy:=float(e.strength)>=1.15 or (combo_hits>=3 and clock-combo_last<0.8)
		if heavy:
			sound("surprise")
			shake=maxf(shake,minf(1.0,0.5+float(e.strength)*0.20+combo_hits*0.035))
			for field in ["a","b"]:
				var key:=str(int(e.get(field,-1)))
				if actors.has(key) and actors[key].has_node("Face"):actors[key].get_node("Face").react("fear" if combo_hits>=3 else "surprise",0.80)
	if kind=="damage" and float(e.strength)>=3:
		shake=maxf(shake,0.8)
		var key:=str(int(e.get("target",-1)))
		if actors.has(key) and actors[key].has_node("Face"):actors[key].get_node("Face").react("fear",0.85)
	if kind=="boss_attack":shake=1.0
	if kind == "death":
		smoke.burst(Vector3(float(e.x), 0.18, float(e.z)), maxf(0.65, float(e.strength)))
	elif kind in ["impact", "blast", "hurt"]:
		for i in 5:
			smoke.emit_puff(Vector3(float(e.x), 0.12, float(e.z)), Vector3(visual_rng.randf_range(-0.5, 0.5), 0.22, visual_rng.randf_range(-0.5, 0.5)), 0.55, 1.15, 0.28)
	var sound_map:={"ready":"ready","cancel":"cancel","ability":"ability","launch":"launch","impact":"heavy" if float(e.strength)>1.3 else "impact","blast":"heavy","boss_attack":"boss","hurt":"hurt","fire_hurt":"hurt","death":"death","heal":"heal","shield":"shield","ice":"ice","wind":"wind","snare":"snare","spirit_pickup":"pickup","spirit_active":"ability","mend_thread":"heal","clear":"clear","victory":"victory","defeat":"lose"}
	if sound_map.has(kind):sound(sound_map[kind],int(e.get("color",-1)))
	if kind in ["damage","wave","ready","cancel","ability","spirit_spawn","spirit_fade","spirit_pickup","spirit_active","mend_thread"]:return
	var color: Color = Catalog.COLORS[int(e.color)] if int(e.color) >= 0 else Color("e6be83")
	if kind == "ice": color = Color("9bdaf1")
	if kind == "death": color = Color("817784")
	var count: int = 12 if kind == "launch" else 24
	if kind in ["blast", "clear", "victory"]: count = 32
	if kind == "death": count = 7
	for i in count:
		var dir := Vector3(visual_rng.randf_range(-1, 1), visual_rng.randf_range(0.2, 1.5), visual_rng.randf_range(-1, 1)).normalized()
		particle(Vector3(float(e.x), 0.35, float(e.z)), dir * visual_rng.randf_range(0.6, 2.8) * float(e.strength), color, visual_rng.randf_range(0.3, 1.0), visual_rng.randf_range(1.2, 3.2) if kind == "death" else visual_rng.randf_range(0.6, 1.6))
	if kind in ["blast", "fire_hurt"]: shake = maxf(shake,minf(0.85,0.35*float(e.strength)))
	if kind == "hurt" and int(e.color) < Input.get_connected_joypads().size() and int(e.color) >= 0:
		Input.start_joy_vibration(Input.get_connected_joypads()[int(e.color)], 0.3, 0.6, 0.18)

func screen_point(p: Vector2, height: float = 0.1) -> Vector2:
	return camera.unproject_position(Vector3(p.x, height, p.y))

func floor_point(screen: Vector2) -> Vector2:
	var origin := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen)
	var t := -origin.y / direction.y
	var point := origin + direction * t
	return Vector2(point.x, point.z)

func make_sounds() -> void:
	audio_system=GameAudio.new();add_child(audio_system)

func sound(name_value: String, player_id: int = -1) -> void:
	if not muted and audio_system:audio_system.play_sound(name_value,-12.0,player_id)

func update_audio(dt:float,menu:bool,sim) -> void:
	var motion:=0.0
	for player in sim.players:motion=maxf(motion,Vector2(float(player.vx),float(player.vz)).length())
	audio_system.step(dt,menu,sim.phase,sim.fire>0,motion,muted)

func stop_audio() -> void:
	muted=true
	if audio_system:audio_system.stop()

func _exit_tree() -> void:
	SpiritVisuals.icons.clear()
	stop_audio()

func reset_presentation() -> void:
	for actor in actors.values(): actor.queue_free()
	actors.clear(); retiring.clear(); smoke_timers.clear()
	last_event = 0; shake = 0.0;combo_hits=0;combo_last=-10.0
	if smoke != null: smoke.clear()
	if spirit_visuals != null:spirit_visuals.clear()
	for item in particles:
		item.life = 0.0; item.node.visible = false
