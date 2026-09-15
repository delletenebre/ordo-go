class_name OrdoArena
extends Node3D

const Catalog = preload("res://scripts/catalog.gd")
const Felt = preload("res://shaders/felt.gdshader")
const WoolMesh = preload("res://scripts/wool_mesh.gd")
const GameAudio = preload("res://scripts/audio.gd")
const HearthFire = preload("res://scripts/hearth_fire.gd")
const HearthMend = preload("res://scripts/hearth_mend.gd")
var hearth_mends: Array = []
var audio_system
const CoalMesh = preload("res://scripts/coal_mesh.gd")
const EnemyFace = preload("res://scripts/enemy_face.gd")
const EnemyRig = preload("res://scripts/enemy_rig.gd")
const EnemyMotion = preload("res://scripts/enemy_motion.gd")
var rig_debris:Array=[]
const SpiritVisuals = preload("res://scripts/spirit_visuals.gd")
var spirit_visuals
const Masonry = preload("res://scripts/masonry.gd")
const Smoke = preload("res://scripts/smoke.gd")
var smoke
var steam
var element_visuals
var debris
const DeathMotion = preload("res://scripts/death_motion.gd")
var death_motions: Dictionary = {}
var previous_deaths: Dictionary = {}
var death_stones: Array = []
const CoalDebris=preload("res://scripts/coal_debris.gd")
var retiring: Dictionary = {}
var smoke_timers: Dictionary = {}
var combo_hits:=0
var combo_last:=-10.0
var camera: Camera3D
var camera_frame := Vector2.ZERO
var camera_pan := Vector2.ZERO
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
var rune_stones:Array=[]
var rune_visuals
const CarvedStone=preload("res://scripts/carved_stone.gd")
const RuneRules=preload("res://scripts/runestones.gd")
const RuneVisuals=preload("res://scripts/rune_visuals.gd")

func _ready() -> void:
	visual_rng.seed = 77381
	make_world()
	add_child(actor_root)
	make_coal_portrait()
	smoke = Smoke.new(); add_child(smoke)
	steam = preload("res://scripts/steam.gd").new(); add_child(steam)
	element_visuals = preload("res://scripts/element_visuals.gd").new(); add_child(element_visuals)
	spirit_visuals = SpiritVisuals.new(); add_child(spirit_visuals)
	rune_visuals=RuneVisuals.new();add_child(rune_visuals);rune_visuals.build(self)
	particle_mesh.radius = 0.065; particle_mesh.height = 0.13
	particle_mesh.radial_segments = 6; particle_mesh.rings = 3
	for i in 220:
		var mesh := MeshInstance3D.new(); mesh.mesh = particle_mesh
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh.material_override = material; mesh.visible = false;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mesh)
		particles.append({"node": mesh, "mat": material, "life": 0.0, "max": 1.0, "v": Vector3.ZERO, "size": 1.0})
	make_sounds()
	debris=CoalDebris.new();add_child(debris);debris.audio_system=audio_system

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
	var view:=Camera3D.new();viewport.add_child(view);view.projection=Camera3D.PROJECTION_ORTHOGONAL;view.size=2.6
	view.position=Vector3(0,2.6,4.5);view.look_at(Vector3(0,.95,0));view.current=true
	var head:=Node3D.new();viewport.add_child(head)
	var body:=mesh_node(head,CoalMesh.shell(1.0,31),Vector3(0,.94,0),CoalMesh.material_for("coal",31));body.name="Body"
	var face:=EnemyFace.new();face.name="Face";head.add_child(face);face.build(self,1.0,31)
	var reference=preload("res://scripts/enemy_reference.gd").new();head.add_child(reference)
	reference.build(self,head,body,"coal",1.0,[],view)
	face.react("surprise");face.step(.2,Vector2.ZERO);reference.step()
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
	# Concentric subdivisions let the applique lift off the underlying wool.
	for band in 32:
		for i in 160:
			for corner in [Vector2i(i,band),Vector2i(i+1,band+1),Vector2i(i+1,band),Vector2i(i,band),Vector2i(i,band+1),Vector2i(i+1,band+1)]:
				var angle: float = TAU*corner.x/160.0
				var point := Vector2(cos(angle),sin(angle))*float(corner.y)/32.0
				st.set_normal(Vector3.UP); st.set_uv(Vector2(0.5,0.5)+point*0.475)
				st.add_vertex(Vector3(point.x*6.2,0.04,point.y*6.2))
	return st.commit()

func frame_camera() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect := viewport_size.x/maxf(1.0,viewport_size.y)
	# A long lens keeps the far and near pieces close to the reference's scale.
	set_camera_width(60.0*tan(deg_to_rad(15.0))*maxf(1.0,aspect/(1540.0/1020.0)))

func set_camera_width(world_width:float)->void:
	var viewport_size:=get_viewport().get_visible_rect().size
	var aspect:=viewport_size.x/maxf(1.0,viewport_size.y)
	camera.fov=rad_to_deg(2.0*atan(world_width/60.0))
	camera_frame = Vector2(-world_width*0.065,world_width/aspect*0.035)
	camera.h_offset=camera_frame.x; camera.v_offset=camera_frame.y

func actor_frame_bounds(sim)->Rect2:
	var bounds:=Rect2();var first:=true
	for actor in sim.players+sim.enemies:
		if int(actor.hp)<=0:continue
		var point:=Vector2(float(actor.x),float(actor.z));var radius:=float(actor.r)*1.08
		var lift:=EnemyMotion.jump_height(actor)
		var height:=radius*2.0 if actor.has("kind") else .30
		for x in [-radius,radius]:
			for z in [-radius,radius]:
				for y in [lift,lift+height]:
					var projected:=screen_point(point+Vector2(x,z),y)
					if first:bounds=Rect2(projected,Vector2.ZERO);first=false
					else:bounds=bounds.expand(projected)
	return bounds

func keep_actors_in_frame(sim,dt:float)->void:
	if camera.projection!=Camera3D.PROJECTION_PERSPECTIVE:return
	# The reference crop stays the default; widen only when live actors need space.
	var previous_fov:=camera.fov
	var viewport_size:=get_viewport().get_visible_rect().size
	var safe:=Rect2(viewport_size*Vector2(.19,.14),viewport_size*Vector2(.795,.835))
	frame_camera()
	var width:=60.0*tan(deg_to_rad(camera.fov)*.5)
	var target_pan:=Vector2.ZERO
	for iteration in 4:
		var bounds:=actor_frame_bounds(sim)
		if bounds.size==Vector2.ZERO:break
		var expansion:=maxf(bounds.size.x/safe.size.x,bounds.size.y/safe.size.y)
		if expansion>1.0:
			width*=expansion*1.002;set_camera_width(width);target_pan=Vector2.ZERO
			bounds=actor_frame_bounds(sim)
		var shift:=Vector2.ZERO
		if bounds.position.x<safe.position.x:shift.x=safe.position.x-bounds.position.x
		elif bounds.end.x>safe.end.x:shift.x=safe.end.x-bounds.end.x
		if bounds.position.y<safe.position.y:shift.y=safe.position.y-bounds.position.y
		elif bounds.end.y>safe.end.y:shift.y=safe.end.y-bounds.end.y
		target_pan+=shift*Vector2(-1,1)*width/viewport_size.x
		camera.h_offset=camera_frame.x+target_pan.x;camera.v_offset=camera_frame.y+target_pan.y
	var blend:=1.0-exp(-12.0*dt)
	var next_fov:=lerpf(previous_fov,camera.fov,blend)
	set_camera_width(60.0*tan(deg_to_rad(next_fov)*.5))
	camera_pan=camera_pan.lerp(target_pan,blend)

func make_world() -> void:
	var env := WorldEnvironment.new(); var settings := Environment.new()
	settings.background_mode = Environment.BG_CANVAS; settings.background_canvas_max_layer = -1
	var background := CanvasLayer.new(); background.layer = -1; add_child(background)
	var backdrop := TextureRect.new(); backdrop.texture = load("res://assets/mountains.png")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED; backdrop.modulate = Color("a3adb9"); background.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("a3bbd4"); settings.ambient_light_energy = 0.26
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	settings.glow_enabled = true; settings.glow_intensity = 0.35; settings.glow_bloom = 0.02
	settings.ssao_enabled = true; settings.ssao_radius = 0.8; settings.ssao_intensity = 1.30
	env.environment = settings; add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_color = Color("ffdfb6"); sun.light_energy = 0.68; sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40; sun.light_angular_distance = 1.1; add_child(sun)
	var rim := DirectionalLight3D.new(); rim.rotation_degrees = Vector3(-30, 145, 0)
	rim.light_color = Color("83bfff"); rim.light_energy = 0.30; add_child(rim)
	camera = Camera3D.new(); camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.position = Vector3(0,22.294,20.074); add_child(camera); camera.look_at(Vector3.ZERO)
	frame_camera(); get_viewport().size_changed.connect(frame_camera)
	camera.current = true
	camera.near = 5.0; camera.far = 60.0
	cylinder(self, Vector3(0, -0.56, 0), 6.7, 0.75, wool(Color("312f37")))
	cylinder(self, Vector3(0, -0.15, 0), 6.38, 0.24, wool(Color("6b3234")))
	ring(self, Vector3(0, -0.03, 0), 6.29, 0.055, wool(Color("d2ad7c")))
	stitches(self, 6.33, 0.05, 240, Color("d8b78b"))
	var rug := ShaderMaterial.new(); rug.shader=preload("res://shaders/rug.gdshader")
	rug.set_shader_parameter("rug_map",preload("res://assets/shyrdak-reference-v3.png"))
	rug.set_shader_parameter("wool_map",preload("res://assets/wool-detail.png"))
	mesh_node(self,disk_texture(),Vector3.ZERO,rug).name="FeltRug"
	for state in RuneRules.layout():
		var stone:=Node3D.new();stone.position=Vector3(state.x,.24,state.z)
		stone.rotation.y=-atan2(state.z,state.x);add_child(stone)
		CarvedStone.build(self,stone,rune_stones.size());rune_stones.append(stone)
	Masonry.wall(self)
	for i in 6:
		var a:float=[-2.08,-1.04,.10,.78,2.32,2.94][i]
		Masonry.lantern(self, Vector3(cos(a)*6.62,0.32,sin(a)*6.62),i)
	Masonry.hearth(self)
	flame_root = HearthFire.new()
	flame_root.position = Vector3(0, 0.43, 0)
	add_child(flame_root)
	fire_light = OmniLight3D.new(); fire_light.position = Vector3(0, 0.95, 0); fire_light.omni_range = 2.8
	fire_light.light_color = Color("ffb353"); fire_light.light_energy = 1.8; add_child(fire_light)

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
	contact.name = "ContactShadow"
	contact.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if is_player:
		var body_color: Color = Catalog.TOKEN_COLORS[int(e.id)]
		var cap := ShaderMaterial.new(); cap.shader=preload("res://shaders/token.gdshader")
		cap.set_shader_parameter("caps",preload("res://assets/player-caps-v2.png"));cap.set_shader_parameter("wool",preload("res://assets/wool-detail.png"))
		cap.set_shader_parameter("side_color",body_color);cap.set_shader_parameter("slot",int(e.id));cap.set_shader_parameter("radius",r)
		mesh_node(root,WoolMesh.token(r),Vector3.ZERO,cap).name="Body"
		var binding_fibers := mesh_node(root,WoolMesh.token_fibers(r,int(e.id)),Vector3.ZERO,cap)
		binding_fibers.name = "BindingFibers"
		binding_fibers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var halo := ring(root, Vector3(0, 0.10, 0), r * 1.015, 0.004, material(color, 0.0)); halo.name = "Halo"
		var shield_mat := ShaderMaterial.new(); shield_mat.shader = preload("res://shaders/shield.gdshader")
		shield_mat.set_shader_parameter("shield_color", Color("ffcc74"))
		var shield := sphere(root, Vector3(0, 0.08, 0), Vector3(3.9, 2.1, 3.9) if int(e.id) == 1 else Vector3(1.3, 1.0, 1.3), shield_mat)
		shield.name = "Shield"; shield.visible = false; shield.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		var appearance:=EnemyRig.variant(str(e.kind),int(e.id))
		var coal_material := CoalMesh.material_for(e.kind,int(e.id))
		var body := mesh_node(root,CoalMesh.shell(r,int(e.id),64,40,.20 if appearance=="ceramic" else (.45 if appearance=="stone" else 1.0)),Vector3(0,r*.94,0),coal_material);body.name="Body"
		var fibers:=mesh_node(body,CoalMesh.fur(r,int(e.id)),Vector3.ZERO,wool(Color("30343d")))
		fibers.name="FeltFibers";fibers.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var binding_material:=wool(Color("62636a"))
		binding_material.set_shader_parameter("wool_detail",preload("res://assets/coal-felt-v2.png"))
		fibers.visible=appearance=="coal"
		if appearance=="coal":
			for path in CoalMesh.binding_paths(r,int(e.id)):
				WoolMesh.thread_path(body,path,r*.014,binding_material).name="FeltTie"

		var face:=EnemyFace.new();face.name="Face";root.add_child(face);face.build(self,r,int(e.id))
		if appearance.is_empty():
			for side in [-1,1]:
				sphere(root,Vector3(side*r*0.52,0.08,0.1),Vector3(r*0.46,r*0.28,r*0.57),coal_material)

		if e.kind == "eater":
			for side in [-1, 1]:
				var horn := ring(root, Vector3(side * r * 0.85, r * 1.3, 0.0), r * 0.32, r * 0.105, wool(Color("c6b8a1")))
				horn.rotation.x = PI * 0.5;horn.name="HornLeft" if side<0 else "HornRight"
		if e.kind=="moth":
			for side in [-1, 1]:
				var wing := sphere(root, Vector3(side * r * 0.85, r * 1.0, -0.2), Vector3(r * 1.2, 0.10, r * 1.6), wool(color.lightened(0.18)))
				wing.rotation.z = side * 0.35;wing.name="WingLeft" if side<0 else "WingRight"
		if e.kind == "eater":
			ring(root, Vector3(0, r * 1.65, 0), r * 0.6, 0.06, material(Color("ff7755"), 1.0))
		if not appearance.is_empty():
			var rig:=EnemyRig.new();rig.name="Rig";root.add_child(rig);rig.build(self,root,e)
		if e.kind=="weaver":
			var heat=preload("res://scripts/enemy_heat.gd").new();root.add_child(heat);heat.name="Heat";heat.build(self,r)
	root.position = Vector3(float(e.x), 0, float(e.z))
	return root

func render_state(sim, dt: float, remote: bool = false) -> void:
	clock += dt; trail_time += dt
	death_stones = sim.stones
	var live: Dictionary = {}
	for e in sim.players + sim.enemies:
		if e.has("kind") and int(e.hp) <= 0: continue
		var key := str(int(e.id)); live[key] = true
		retiring.erase(key)
		var is_player: bool = not e.has("kind")
		if not actors.has(key): actors[key] = create_actor(e, is_player)
		var root: Node3D = actors[key]
		var target := Vector3(float(e.x), 0.03, float(e.z))
		if e.has("jump") and float(e.jump) > 0: target.y += EnemyMotion.jump_height(e)
		var previous := root.position
		if not is_player:
			var speed := Vector2(float(e.vx), float(e.vz)).length()
			var interval := 0.10 if speed > 0.7 else 0.30
			smoke_timers[key] = float(smoke_timers.get(key, 0.0)) + dt
			if float(smoke_timers[key]) >= interval and (EnemyMotion.material_kind(str(e.kind))=="coal" or speed>.7):
				smoke_timers[key] = fmod(float(smoke_timers[key]), interval)
				var a := visual_rng.randf() * TAU
				var offset := Vector3(cos(a)*0.6,0,sin(a)*0.3-0.45) * float(e.r)
				var drift := Vector3(-float(e.vx) * 0.055, 0.32, -0.12-float(e.vz) * 0.055)
				smoke.emit_puff(previous + offset + Vector3(0, 0.25, 0), drift, float(e.r) * 1.35, 1.2, 0.24)
		root.position = root.position.lerp(target, 1.0 - exp(-28.0 * dt)) if remote else target
		if not is_player:
			root.rotation.y = lerp_angle(root.rotation.y, sin(float(e.angle)) * 0.18, 1.0 - exp(-8.0 * dt))
			var look:=Vector2.ZERO
			var nearest:=INF
			for player in sim.players:
				var delta:=Vector2(float(player.x)-float(e.x),float(player.z)-float(e.z))
				if int(player.hp)>0 and delta.length()<nearest:nearest=delta.length();look=delta.normalized()
			root.get_node("Face").step(dt,look)
			if root.has_node("Rig"):root.get_node("Rig").step(e,str(sim.phase),float(sim.phase_time),dt)
			root.scale=Vector3.ONE
			if root.has_node("Heat"):
				root.get_node("Heat").step((1.0 if sim.Bosses.hot(sim,e) else .4) if e.get("boss_phase","")=="burning" and sim.Bosses.living(sim)>1 else 0.0,dt)
			var shadow:=root.get_node("ContactShadow") as Node3D
			shadow.position.y=.047-root.position.y
			shadow.scale=Vector3.ONE*clampf(1-EnemyMotion.jump_height(e)*.22,.45,1)
		else:
			if sim.phase == "resolve" and sim.vel(e).length() > 0.1:
				root.rotation.y -= float(e.get("flight_spin", 0.0))*dt*9.0
			else: root.rotation.y = lerp_angle(root.rotation.y, 0.0, 1.0-exp(-8.0*dt))
			root.scale.y = lerpf(root.scale.y, 0.40 if int(e.hp) <= 0 else 1.0, 1.0 - exp(-12.0 * dt))
			root.get_node("Halo").visible = int(e.hp) > 0
			root.get_node("Shield").visible = int(e.hp) > 0 and int(e.shield) > 0
		if trail_time > 0.026 and Vector2(float(e.vx), float(e.vz)).length() > 1.3:
			var color: Color = Catalog.COLORS[int(e.id)] if is_player else Color("b0a18c")
			particle(previous + Vector3(0, 0.13, 0), Vector3(0, 0.2, 0), color, 0.36, 0.7)
	for key in actors.keys():
		if not live.has(key) and not retiring.has(key):
			retiring[key] = {"age": 0.0, "position": actors[key].position, "scale": actors[key].scale}
	for key in retiring.keys():
		if death_motions.has(key): continue
		var retirement: Dictionary = retiring[key]; retirement.age += dt
		var root: Node3D = actors[key]
		if root.has_node("Face"):root.get_node("Face").step(dt,Vector2.ZERO)
		var t := clampf(float(retirement.age) / 0.65, 0.0, 1.0)
		root.scale = retirement.scale * (1.0 - t * t * 0.92)
		root.position = retirement.position + Vector3(0, -t * 0.16, 0)
		if t >= 1.0:
			root.queue_free(); actors.erase(key); retiring.erase(key); smoke_timers.erase(key)
	if trail_time > 0.026: trail_time = 0.0
	for event in sim.events:
		if int(event.id) > last_event:
			last_event = int(event.id); play_event(event)
	step_deaths(dt)
	debris.muted=muted;debris.step(dt)
	for flame in flames:
		var t:float=clock+float(flame.offset)
		flame.root.scale=Vector3(1.0+sin(t*3.1)*.045,1.0+sin(t*4.7)*.08+sin(t*7.1)*.03,1.0+cos(t*3.7)*.035)
		for mat in flame.tongues:mat.set_shader_parameter("elapsed",clock)
		if visual_rng.randf()<dt*9.0:
			particle(flame.root.position+Vector3(0,float(flame.size)*.7,0),Vector3(visual_rng.randf_range(-.15,.15),1.6,visual_rng.randf_range(-.15,.15)),Color("ffd378"),.7,.11)
	for torch in torches:
		var t:float=clock+float(torch.phase)
		torch.light.light_energy=1.9+sin(t*5.3)*.09+sin(t*8.7)*.045
		torch.light.position=torch.origin+Vector3(sin(t*3.1)*.025,.28+sin(t*4.7)*.025,cos(t*3.7)*.02)
	for mend in hearth_mends:
		var previous_age: float = mend.age
		mend.age += dt
		if previous_age < HearthMend.CORE_TIME and mend.age >= HearthMend.CORE_TIME:
			flame_root.mend()
			sound("heal")
			for i in 12:
				var angle := i * TAU / 12.0
				particle(Vector3(cos(angle)*0.22, 0.45, sin(angle)*0.22), Vector3(cos(angle)*0.3, 0.8, sin(angle)*0.3), HearthMend.GOLD, 0.55, 0.16)
	hearth_mends = hearth_mends.filter(func(mend): return mend.age < HearthMend.CORE_TIME)
	flame_root.step(dt, float(sim.fire) / maxf(1.0, float(sim.max_fire)))
	fire_light.light_energy = flame_root.light_energy()
	shake = maxf(0.0, shake - dt * 1.6)
	keep_actors_in_frame(sim,dt)
	step_rig_debris(dt)
	camera.h_offset = camera_frame.x + camera_pan.x + sin(clock * 18.0) * shake * shake * 0.095
	camera.v_offset = camera_frame.y + camera_pan.y + cos(clock * 16.0) * shake * shake * 0.075
	smoke.step(dt, camera.global_basis)
	steam.step(dt, camera.global_basis)
	element_visuals.step(sim,self,dt)
	spirit_visuals.step(sim,self,dt)
	rune_visuals.step(sim,self,dt)
	for item in particles:
		if float(item.life) <= 0.0: continue
		item.life -= dt
		var mesh: MeshInstance3D = item.node
		if float(item.life) <= 0.0: mesh.visible = false; continue
		item.v.y -= dt * 1.5; mesh.position += item.v * dt
		var scale_value:=float(item.size)*maxf(.01,float(item.life)/float(item.max))
		if float(item.get("stretch",0))>0 and item.v.length_squared()>.001:
			var direction:Vector3=item.v.normalized();var helper:=Vector3.UP if absf(direction.y)<.95 else Vector3.RIGHT
			var right:=helper.cross(direction).normalized()
			mesh.basis=Basis(right,direction,right.cross(direction))
			mesh.scale=Vector3(.38,float(item.stretch),.38)*scale_value
		else:mesh.scale=Vector3.ONE*scale_value
		var color: Color = item.mat.albedo_color; color.a = minf(1.0, float(item.life) * 4.0); item.mat.albedo_color = color

func particle(p: Vector3, velocity_value: Vector3, color: Color, life: float, size: float, stretch:float=0.0) -> void:
	var slot := -1
	for offset in particles.size():
		var candidate := (particle_cursor + offset) % particles.size()
		if float(particles[candidate].life) <= 0.0: slot = candidate; break
	if slot < 0: return
	var item: Dictionary = particles[slot]; particle_cursor = (slot + 1) % particles.size()
	item.node.position = p; item.node.visible = true; item.mat.albedo_color = color
	item.life = life; item.max = life; item.v = velocity_value; item.size = size;item.stretch=stretch
	item.mat.emission_enabled=stretch>0;item.mat.emission=color;item.mat.emission_energy_multiplier=1.3
	item.node.scale = Vector3.ONE * size

func play_event(e: Dictionary) -> void:
	var kind: String = e.kind
	if kind == "steam":
		steam.quench(e); sound("steam")
		return
	if kind in ["impact","clash"] and e.get("quenched",false): return
	if kind == "element_pickup":
		sound("pickup")
		return
	if kind == "element_apply": return
	if kind == "hearth_mend":
		hearth_mends.append({"age": 0.0})
		return
	if kind == "kill_boost":
		var center := Vector3(float(e.x), .35, float(e.z))
		var direction := Vector3(float(e.vx), 0, float(e.vz)).normalized()
		var tint: Color = Catalog.COLORS[int(e.color)].lightened(.35)
		sound("launch", int(e.color)); shake = maxf(shake, .35)
		for i in 16:
			var scatter := Vector3(visual_rng.randf_range(-.6, .6), visual_rng.randf_range(.1, .8), visual_rng.randf_range(-.6, .6))
			particle(center - direction * .3, -direction * visual_rng.randf_range(2.0, 4.5) + scatter, tint, .4, .45, 3.0)
		return
	if kind == "ricochet_hit":
		var center := Vector3(float(e.x), .4, float(e.z))
		sound("heavy", int(e.color)); shake = maxf(shake, .3 + .1 * float(e.strength))
		for i in 12:
			var direction := Vector3(cos(i * TAU / 12), .35, sin(i * TAU / 12))
			particle(center, direction * 2.5, Color("ffd477"), .3, .35, 2.5)
		return
	if kind=="team_clash":
		shake=1.0;sound("heavy")
		var center:=Vector3(float(e.x),.30,float(e.z))
		smoke.burst(center,1.1)
		for i in 64:
			var angle:=i*TAU/64;var direction:=Vector3(cos(angle),visual_rng.randf_range(.2,1.0),sin(angle))
			var slot:int=e.participants[i%e.participants.size()]
			particle(center,direction*visual_rng.randf_range(2.0,4.8),Catalog.COLORS[slot].lightened(.28),.8,.70,3.0)
		var key:=str(int(e.target))
		if actors.has(key) and actors[key].has_node("Face"):actors[key].get_node("Face").react("fear",1.05)
		return
	if kind=="clash":
		shake=1.0;sound("heavy")
		var center:=Vector3(float(e.x),.23,float(e.z))
		smoke.burst(center,1.25)
		for i in 44:
			var angle:=i*TAU/44;var direction:=Vector3(cos(angle),visual_rng.randf_range(.12,.75),sin(angle))
			particle(center,direction*visual_rng.randf_range(2.4,5.0),Catalog.COLORS[int(e.a)] if i%2==0 else Catalog.COLORS[int(e.b)],.65,.70,3.0)
		for actor in actors.values():
			if actor.has_node("Face") and actor.position.distance_to(center)<2.7:actor.get_node("Face").react("fear",1.0)
		return
	if kind in ["soul_depart","soul_arrive","rune_ready","rune_boost","rune_gift"]:
		var sounds:={"soul_depart":"wind","soul_arrive":"pickup","rune_ready":"ability","rune_boost":"heavy","rune_gift":"pickup"}
		if not muted:audio_system.play_sound(sounds[kind],-24 if kind=="soul_depart" else -15)
		if kind=="rune_boost":
			shake=maxf(shake,.55)
			for i in 14:
				particle(Vector3(float(e.x),.50,float(e.z)),Vector3(float(e.vx),.5,float(e.vz))*.11+Vector3(visual_rng.randf_range(-.6,.6),visual_rng.randf(),visual_rng.randf_range(-.6,.6)),Color("8fe9ff"),.55,.55,3.2)
		return
	if kind=="boss_phase":
		sound("boss")
		var actor:=actors.get(str(int(e.get("actor",-1)))) as Node3D
		if actor!=null and actor.has_node("Face"):actor.get_node("Face").react("surprise",.6)
		return
	if kind=="enemy_mood":
		sound(e.text)
		var key:=str(int(e.get("actor",-1)))
		if actors.has(key) and actors[key].has_node("Face"):actors[key].get_node("Face").react(e.text,0.85)
		return
	if kind=="impact":
		for field in ["a","b"]:
			var actor_id:=str(int(e.get(field,-1)))
			if actors.has(actor_id) and actors[actor_id].has_node("Rig"):actors[actor_id].get_node("Rig").hit(float(e.strength))
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
		start_death(e)
		var actor_key:=str(int(e.get("target",-1)))
		if actors.has(actor_key) and actors[actor_key].has_node("Face"):actors[actor_key].get_node("Face").react("fear",.2)
		smoke.burst(Vector3(float(e.x), 0.18, float(e.z)), maxf(0.65, float(e.strength)))
	elif kind in ["impact", "blast", "hurt"]:
		for i in 5:
			smoke.emit_puff(Vector3(float(e.x), 0.12, float(e.z)), Vector3(visual_rng.randf_range(-0.5, 0.5), 0.22, visual_rng.randf_range(-0.5, 0.5)), 0.55, 1.15, 0.28)
	var sound_map:={"ready":"ready","cancel":"cancel","ability":"ability","launch":"launch","impact":"heavy" if float(e.strength)>1.3 else "impact","blast":"heavy","boss_attack":"boss","hurt":"hurt","fire_hurt":"hurt","death":"death","heal":"heal","shield":"shield","ice":"ice","wind":"wind","snare":"snare","spirit_pickup":"pickup","spirit_active":"ability","clear":"clear","victory":"victory","defeat":"lose"}
	if sound_map.has(kind):sound(sound_map[kind],int(e.get("color",-1)))
	if kind in ["damage","wave","ready","cancel","ability","spirit_spawn","spirit_fade","spirit_pickup","spirit_active"]:return
	var color: Color = Catalog.COLORS[int(e.color)] if int(e.color) >= 0 else Color("e6be83")
	if kind == "ice": color = Color("9bdaf1")
	if kind == "death": color = Color("ffc275")
	var count: int = 12 if kind == "launch" else 24
	if kind in ["blast", "clear", "victory"]: count = 32
	if kind == "death": count = 12
	for i in count:
		var dir := Vector3(visual_rng.randf_range(-1, 1), visual_rng.randf_range(0.2, 1.5), visual_rng.randf_range(-1, 1)).normalized()
		particle(Vector3(float(e.x), 0.35, float(e.z)), dir * visual_rng.randf_range(0.6, 2.8) * float(e.strength), color, visual_rng.randf_range(0.3, 1.0), visual_rng.randf_range(.35,.65) if kind == "death" else visual_rng.randf_range(0.6, 1.6),3.0 if kind=="death" else 0.0)
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

func start_death(event: Dictionary) -> void:
	var key := str(int(event.get("target", -1)))
	var kind := str(event.get("enemy_kind", "coal"))
	var state := DeathMotion.create(event, str(previous_deaths.get(kind, "")))
	previous_deaths[kind] = state.style
	state.combo = combo_hits if clock - combo_last < 0.8 else 0
	if not actors.has(key):
		# Remote snapshots can contain both a death and the already removed enemy.
		# Reconstruct its visual from the event, keeping the same animation path.
		if int(event.get("target", -1)) < 0:
			debris.shatter(event, int(state.combo)); return
		actors[key] = create_actor({"id": int(event.target), "kind": kind,
			"r": float(state.radius), "x": float(event.x), "z": float(event.z)}, false)
		actors[key].position.y = 0.03 + float(event.get("height", 0))
	var actor: Node3D = actors[key]
	var pivot := Node3D.new(); pivot.name = "DeathPivot"
	pivot.position.y = float(state.radius) * 0.94
	actor.add_child(pivot)
	for child in actor.get_children():
		if child == pivot or child.name == "ContactShadow": continue
		child.reparent(pivot)
	# Face.step animates its own local Y. Preserve its centre offset in a parent
	# so expressions remain attached to the shell while the corpse rotates.
	var face := pivot.get_node_or_null("Face") as Node3D
	if face != null:
		var anchor := Node3D.new(); anchor.name = "FaceAnchor"; pivot.add_child(anchor)
		anchor.transform = face.transform
		face.reparent(anchor)
	state.face = face
	state.rig = pivot.get_node_or_null("Rig")
	if state.rig!=null:state.rig.begin_death(state.v)
	# Keep authoritative trajectory coordinates. Ease out any remote interpolation
	# offset on the visual only, so a lagging actor cannot change wall clearance.
	state.origin_offset = actor.position + Vector3.UP * float(state.radius) * 0.94 - Vector3(state.p)
	state.pivot = pivot
	var body := pivot.get_node_or_null("Body") as MeshInstance3D
	state.material = body.material_override if body != null else null
	if face != null: face.react("fear", 0.45)
	death_motions[key] = state
	retiring[key] = {"age": 0.0, "position": actor.position, "scale": actor.scale}

func step_deaths(dt: float) -> void:
	for key in death_motions.keys():
		var state: Dictionary = death_motions[key]
		var actor: Node3D = actors[key]
		DeathMotion.advance(state, dt, death_stones)
		var radius := float(state.radius)
		actor.position = state.p - Vector3.UP * radius * 0.94 + Vector3(state.origin_offset) * maxf(0.0, 1.0 - float(state.age) / 0.12)
		var pivot: Node3D = state.pivot
		pivot.rotation = state.rotation
		var compression := sin(clampf(float(state.age) / 0.09, 0, 1) * PI) * float(EnemyMotion.profile(str(state.kind)).strain)
		pivot.scale = Vector3(1 + compression * 0.5, 1 - compression, 1 + compression * 0.5)
		if state.material != null:
			state.material.set_shader_parameter("death_fracture", clampf(float(state.age) / float(state.delay), 0, 1))
		if state.face != null: state.face.step(dt, Vector2.ZERO)
		if state.rig != null:state.rig.step_death(float(state.age),dt)
		var contact := actor.get_node_or_null("ContactShadow") as Node3D
		if contact != null:
			contact.position.y = 0.047 - actor.position.y
			contact.visible = not bool(state.outside) and actor.position.y < 1.8
			contact.scale = Vector3.ONE * clampf(1.0 - actor.position.y * 0.3, 0.25, 1.0)
		state.trail += dt
		if float(state.trail) >= 0.06 and Vector3(state.v).length() > 2.0:
			state.trail = 0.0
			smoke.emit_puff(state.p, -Vector3(state.v) * 0.05 + Vector3.UP * 0.2, radius * 0.8, 0.55, 0.17)
			particle(state.p, -Vector3(state.v) * 0.12, Color("8a7770"), 0.35, radius * 0.35)
		if not bool(state.done): continue
		if state.reason != "outside":
			if state.rig!=null:rig_debris.append_array(state.rig.release_parts(actor_root))
			if EnemyMotion.material_kind(str(state.kind))!="felt":debris.shatter(DeathMotion.fragment_event(state), int(state.combo))
			smoke.burst(state.p, maxf(0.35, radius * 1.4))
			if state.reason in ["wall", "stone", "land"]:
				sound("heavy" if float(state.mass) >= 2.0 else "impact")
				shake = maxf(shake, 0.20 if float(state.mass) < 2.0 else 0.45)
		actor.queue_free(); actors.erase(key); retiring.erase(key)
		smoke_timers.erase(key); death_motions.erase(key)

func step_rig_debris(dt:float)->void:
	for index in range(rig_debris.size()-1,-1,-1):
		var piece:Dictionary=rig_debris[index];piece.age+=dt
		if float(piece.age)>=float(piece.life):
			piece.node.queue_free();rig_debris.remove_at(index);continue
		piece.velocity.y-=9.8*dt
		piece.node.position+=Vector3(piece.velocity)*dt
		piece.node.rotation.z+=float(piece.spin)*dt
		if piece.node.position.y<.07 and Vector2(piece.node.position.x,piece.node.position.z).length()<6.1:
			piece.node.position.y=.07
			piece.velocity.y=absf(piece.velocity.y)*float(piece.get("bounce",.18))
			var drag:=float(piece.get("friction",.84))*10.0
			piece.velocity.x*=exp(-drag*dt);piece.velocity.z*=exp(-drag*dt)
		var settle:=1.0-smoothstep(float(piece.life)-.23,float(piece.life),float(piece.age))
		piece.node.scale=Vector3(piece.scale)*settle
		if piece.get("soft_loop",false):piece.node.scale.y*=lerpf(1.0,.14,smoothstep(.15,.8,float(piece.age)))

func stop_audio() -> void:
	muted=true
	if audio_system:audio_system.stop()

func _exit_tree() -> void:
	SpiritVisuals.icons.clear()
	stop_audio()

func reset_presentation() -> void:
	camera_pan=Vector2.ZERO
	for piece in rig_debris:piece.node.queue_free()
	rig_debris.clear()
	for actor in actors.values(): actor.queue_free()
	actors.clear(); retiring.clear(); smoke_timers.clear()
	last_event = 0; shake = 0.0;combo_hits=0;combo_last=-10.0
	hearth_mends.clear()
	flame_root.mend_age = 10.0
	death_motions.clear(); previous_deaths.clear(); death_stones = []
	if debris != null:debris.clear()
	if rune_visuals != null:rune_visuals.clear()
	if smoke != null: smoke.clear()
	if steam != null: steam.clear()
	if element_visuals != null: element_visuals.clear()
	if spirit_visuals != null:spirit_visuals.clear()
	for item in particles:
		item.life = 0.0; item.node.visible = false
