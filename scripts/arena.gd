class_name OrdoArena
extends Node3D

const Catalog = preload("res://scripts/catalog.gd")
const Felt = preload("res://shaders/felt.gdshader")
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
var sounds: Dictionary = {}
var audio_voices: Array = []
var voice_cursor := 0
var torches: Array = []

func _ready() -> void:
	visual_rng.seed = 77381
	make_world()
	add_child(actor_root)
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

func wool(color: Color) -> ShaderMaterial:
	var key := color.to_html()
	if cloth.has(key): return cloth[key]
	var mat := ShaderMaterial.new(); mat.shader = Felt
	mat.set_shader_parameter("wool_color", color)
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
	settings.ambient_light_color = Color("a3bbd4"); settings.ambient_light_energy = 0.32
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	settings.glow_enabled = true; settings.glow_intensity = 0.65; settings.glow_bloom = 0.12
	settings.ssao_enabled = true; settings.ssao_radius = 0.8; settings.ssao_intensity = 1.4
	env.environment = settings; add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_color = Color("ffdfb6"); sun.light_energy = 1.0; sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40; add_child(sun)
	var rim := DirectionalLight3D.new(); rim.rotation_degrees = Vector3(-30, 145, 0)
	rim.light_color = Color("83bfff"); rim.light_energy = 0.4; add_child(rim)
	camera = Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH; camera.size = 19.2
	camera.position = Vector3(0, 17, 15.5); add_child(camera); camera.look_at(Vector3(0, 0, -0.2))
	camera.current = true
	cylinder(self, Vector3(0, -0.56, 0), 6.7, 0.75, wool(Color("312f37")))
	cylinder(self, Vector3(0, -0.15, 0), 6.38, 0.24, wool(Color("6b3234")))
	ring(self, Vector3(0, -0.03, 0), 6.29, 0.055, wool(Color("d2ad7c")))
	stitches(self, 6.33, 0.05, 240, Color("d8b78b"))
	var rug := StandardMaterial3D.new(); rug.albedo_texture = load("res://assets/shyrdak.png"); rug.roughness = 1.0
	mesh_node(self, disk_texture(), Vector3.ZERO, rug)
	for a in [0.3, 1.85, 3.4, 4.95]:
		var stone := Node3D.new(); stone.position = Vector3(cos(a) * 4.6, 0.18, sin(a) * 4.6); stone.rotation.y = -a; add_child(stone)
		sphere(stone, Vector3.ZERO, Vector3(1.0, 0.5, 0.85), wool(Color("a39785")))
		ring(stone, Vector3(0, 0.235, 0), 0.22, 0.045, wool(Color("514b4c")))
		ring(stone, Vector3(0, 0.245, 0), 0.085, 0.025, wool(Color("514b4c")))
	for i in 64:
		var a := TAU * i / 64.0
		var block := sphere(self, Vector3(cos(a) * 6.55, 0.12 + 0.07 * sin(i * 4.7), sin(a) * 6.55), Vector3(0.69, 0.57, 0.52), wool(Color("56545c").lightened(visual_rng.randf_range(-0.12, 0.12))))
		block.rotation.y = -a - PI / 2
		block.rotation.z = visual_rng.randf_range(-0.06, 0.06)
	for i in 6:
		var a := TAU * i / 6.0 + 0.3
		var p := Vector3(cos(a) * 6.45, 0.3, sin(a) * 6.45)
		cylinder(self, p + Vector3(0, 0.14, 0), 0.32, 0.35, wool(Color("7f634d")))
		cylinder(self, p + Vector3(0, 0.4, 0), 0.25, 0.16, material(Color("d89448")))
		var flame := make_flame(p + Vector3(0, 0.5, 0), 0.47); torches.append(flame)
		var light := OmniLight3D.new(); light.position = p + Vector3(0, 0.7, 0); light.light_color = Color("ffb653"); light.light_energy = 1.2; light.omni_range = 2.8; add_child(light)
	cylinder(self, Vector3(0, 0.18, 0), 1.04, 0.36, wool(Color("5c4544")))
	for i in 12:
		var a := TAU * i / 12
		var block := box(self, Vector3(cos(a) * 0.85, 0.35, sin(a) * 0.85), Vector3(0.43, 0.26, 0.33), wool(Color("b59167")))
		block.rotation.y = -a
	ring(self, Vector3(0, 0.52, 0), 0.63, 0.07, material(Color("f2aa4f"), 0.3))
	flame_root = make_flame(Vector3(0, 0.5, 0), 1.3)
	fire_light = OmniLight3D.new(); fire_light.position = Vector3(0, 1.6, 0); fire_light.omni_range = 8.0
	fire_light.light_color = Color("ffb353"); fire_light.light_energy = 3.0; add_child(fire_light)

func flame_shape(size: float) -> ArrayMesh:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in 18:
		for i in 24:
			for corner in [Vector2(i, j), Vector2(i + 1, j), Vector2(i + 1, j + 1), Vector2(i, j), Vector2(i + 1, j + 1), Vector2(i, j + 1)]:
				var t: float = corner.y / 18.0; var a: float = corner.x * TAU / 24.0
				var r: float = pow(maxf(0.0, sin(PI * pow(t, 0.7))), 0.8) * size * 0.3
				st.set_uv(Vector2(corner.x / 24.0, t))
				st.add_vertex(Vector3(cos(a) * r + sin(t * PI) * t * size * 0.13, t * size * 1.4, sin(a) * r))
	st.generate_normals(); return st.commit()

func make_flame(p: Vector3, size: float) -> Node3D:
	var root := Node3D.new(); add_child(root); root.position = p
	var mat := ShaderMaterial.new(); mat.shader = preload("res://shaders/flame.gdshader")
	mat.set_shader_parameter("tint", Color("ff791e")); mat.set_shader_parameter("heat", 1.5)
	var outer := mesh_node(root, flame_shape(size), Vector3.ZERO, mat)
	var inside := ShaderMaterial.new(); inside.shader = preload("res://shaders/flame.gdshader")
	inside.set_shader_parameter("tint", Color("ffe4a0")); inside.set_shader_parameter("heat", 2.0)
	var inner := mesh_node(root, flame_shape(size * 0.7), Vector3(0, 0.0, size * 0.14), inside)
	var tip := mesh_node(root, flame_shape(size * 0.62), Vector3(size * 0.17, 0, 0), mat)
	tip.rotation.z = -0.25
	flames.append({"root": root, "outer": outer, "inner": inner, "tip": tip, "size": size, "offset": visual_rng.randf() * TAU})
	return root

func create_actor(e: Dictionary, is_player: bool) -> Node3D:
	var root := Node3D.new(); actor_root.add_child(root)
	var color: Color = Catalog.COLORS[int(e.id)] if is_player else Color(Catalog.ENEMIES[e.kind].color)
	var r := float(e.r)
	sphere(root, Vector3(0.02, 0.035, 0.05), Vector3(r * 2.25, 0.045, r * 2.1), material(Color(0.025, 0.02, 0.025, 0.3)))
	if is_player:
		var body_color: Color = [Color("185bb5"), Color("bc842b"), Color("227c47"), Color("ad2f40")][int(e.id)]
		cylinder(root, Vector3(0, 0.19, 0), r, 0.27, wool(body_color.darkened(0.2)))
		sphere(root, Vector3(0, 0.29, 0), Vector3(r * 1.86, 0.38, r * 1.86), wool(body_color))
		ring(root, Vector3(0, 0.41, 0), r * 0.83, 0.024, wool(color.lightened(0.4)))
		stitches(root, r * 0.9, 0.375, 28, color.lightened(0.7))
		var symbol := Label3D.new(); symbol.text = ["△", "⬡", "◇", "○"][int(e.id)]
		symbol.font_size = 96; symbol.pixel_size = 0.0064; symbol.position = Vector3(0, 0.505, 0)
		symbol.rotation_degrees.x = -90; symbol.modulate = Color("fff3d9"); symbol.outline_size = 2; symbol.outline_modulate = color.darkened(0.65)
		root.add_child(symbol)
		var halo := ring(root, Vector3(0, 0.07, 0), r * 1.13, 0.018, material(color, 1.0)); halo.name = "Halo"
		var shield_mat := ShaderMaterial.new(); shield_mat.shader = preload("res://shaders/shield.gdshader")
		shield_mat.set_shader_parameter("shield_color", Color("ffcc74"))
		var shield := sphere(root, Vector3(0, 0.08, 0), Vector3(3.9, 2.1, 3.9) if int(e.id) == 1 else Vector3(1.3, 1.0, 1.3), shield_mat)
		shield.name = "Shield"; shield.visible = false; shield.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		var body := sphere(root, Vector3(0, r * 0.9, 0), Vector3(r * 1.95, r * 1.8, r * 1.85), wool(color.darkened(0.12))); body.name = "Body"
		var fiber_mesh := CapsuleMesh.new(); fiber_mesh.radius = 0.004; fiber_mesh.height = r * 0.16; fiber_mesh.radial_segments = 3; fiber_mesh.rings = 1
		var fibers := MultiMesh.new(); fibers.transform_format = MultiMesh.TRANSFORM_3D; fibers.mesh = fiber_mesh; fibers.instance_count = 150
		for fi in 150:
			var direction := Vector3(visual_rng.randf_range(-1, 1), visual_rng.randf_range(-0.4, 1), visual_rng.randf_range(-1, 1)).normalized()
			var up := Vector3.FORWARD if absf(direction.dot(Vector3.UP)) > 0.95 else Vector3.UP
			var x := up.cross(direction).normalized(); var basis := Basis(x, direction, x.cross(direction))
			fibers.set_instance_transform(fi, Transform3D(basis, Vector3(0, r * 0.9, 0) + direction * r * 0.94))
		var fuzz := MultiMeshInstance3D.new(); fuzz.multimesh = fibers; fuzz.material_override = wool(color.lightened(0.16)); root.add_child(fuzz)
		for x in [-0.32, 0.32]:
			sphere(root, Vector3(x * r, r * 1.05, r * 0.78), Vector3(r * 0.40, r * 0.43, r * 0.2), wool(Color("171a27")))
			sphere(root, Vector3(x * r, r * 1.08, r * 0.87), Vector3(r * 0.16, r * 0.19, r * 0.08), material(Color("ffc96a"), 1.5))
			sphere(root, Vector3(x * r * 1.7, 0.08, 0.1), Vector3(r * 0.55, r * 0.3, r * 0.7), wool(color.darkened(0.12)))
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
		stitches(root, r * 0.77, r * 1.2, 18, color.lightened(0.3), 0.3)
	root.position = Vector3(float(e.x), 0, float(e.z))
	return root

func render_state(sim, dt: float, remote: bool = false) -> void:
	clock += dt; trail_time += dt
	var live: Dictionary = {}
	for e in sim.players + sim.enemies:
		var key := str(e.id); live[key] = true
		var is_player: bool = not e.has("kind")
		if not actors.has(key): actors[key] = create_actor(e, is_player)
		var root: Node3D = actors[key]
		var target := Vector3(float(e.x), 0.03, float(e.z))
		if e.has("jump") and float(e.jump) > 0: target.y += sin(float(e.jump) * PI) * 2.4
		var previous := root.position
		root.position = root.position.lerp(target, 1.0 - exp(-28.0 * dt)) if remote else target
		if not is_player:
			root.rotation.y = lerp_angle(root.rotation.y, sin(float(e.angle)) * 0.18, dt * 8.0)
			var breathing := sin(clock * 3.0 + int(e.id)) * 0.025
			root.scale = Vector3(1.0 + breathing, 1.0 - breathing, 1.0 + breathing)
		else:
			root.scale.y = 0.3 if int(e.hp) <= 0 else 1.0
			root.get_node("Halo").visible = int(e.hp) > 0
			root.get_node("Shield").visible = int(e.hp) > 0 and int(e.shield) > 0
			if e.statuses.has("burn") and visual_rng.randf() < dt * 16:
				particle(root.position + Vector3(0, 0.45, 0), Vector3(0, 1.1, 0), Color("ff8c51"), 0.7, 0.45)
		if trail_time > 0.026 and Vector2(float(e.vx), float(e.vz)).length() > 1.3:
			var color: Color = Catalog.COLORS[int(e.id)] if is_player else Color("b0a18c")
			particle(previous + Vector3(0, 0.13, 0), Vector3(0, 0.2, 0), color, 0.36, 0.7)
	for key in actors.keys():
		if not live.has(key): actors[key].queue_free(); actors.erase(key)
	if trail_time > 0.026: trail_time = 0.0
	for event in sim.events:
		if int(event.id) > last_event:
			last_event = int(event.id); play_event(event)
	for flame in flames:
		var t: float = clock * 7.0 + float(flame.offset)
		flame.root.scale = Vector3(1.0 + sin(t) * 0.045, 1.0 + cos(t * 1.3) * 0.075, 1.0 + sin(t + 1.0) * 0.045)
		flame.tip.rotation.z = sin(t * 0.7) * 0.11
		if visual_rng.randf() < dt * 18.0:
			particle(flame.root.position + Vector3(0, float(flame.size) * 0.7, 0), Vector3(visual_rng.randf_range(-0.2, 0.2), 0.9, visual_rng.randf_range(-0.2, 0.2)), Color("ffd378"), 1.1, 0.3)
	flame_root.visible = sim.fire > 0
	fire_light.light_energy = (2.7 + sin(clock * 11) * 0.2) * maxf(0.1, float(sim.fire) / maxf(1.0, float(sim.max_fire)))
	shake = maxf(0.0, shake - dt * 2.0)
	camera.h_offset = sin(clock * 79.0) * shake * 0.08
	camera.v_offset = cos(clock * 93.0) * shake * 0.065
	for item in particles:
		if float(item.life) <= 0.0: continue
		item.life -= dt
		var mesh: MeshInstance3D = item.node
		if float(item.life) <= 0.0: mesh.visible = false; continue
		item.v.y -= dt * 1.5; mesh.position += item.v * dt
		mesh.scale = Vector3.ONE * float(item.size) * maxf(0.01, float(item.life) / float(item.max))
		var color: Color = item.mat.albedo_color; color.a = minf(1.0, float(item.life) * 4.0); item.mat.albedo_color = color

func particle(p: Vector3, velocity_value: Vector3, color: Color, life: float, size: float) -> void:
	var item: Dictionary = particles[particle_cursor]; particle_cursor = (particle_cursor + 1) % particles.size()
	item.node.position = p; item.node.visible = true; item.mat.albedo_color = color
	item.life = life; item.max = life; item.v = velocity_value; item.size = size

func play_event(e: Dictionary) -> void:
	var kind: String = e.kind
	if kind in ["damage", "wave"]: return
	var color: Color = Catalog.COLORS[int(e.color)] if int(e.color) >= 0 else Color("e6be83")
	if kind == "ice": color = Color("9bdaf1")
	if kind == "death": color = Color("817784")
	var count: int = 12 if kind == "launch" else 24
	if kind in ["blast", "clear", "victory"]: count = 48
	for i in count:
		var dir := Vector3(visual_rng.randf_range(-1, 1), visual_rng.randf_range(0.2, 1.5), visual_rng.randf_range(-1, 1)).normalized()
		particle(Vector3(float(e.x), 0.35, float(e.z)), dir * visual_rng.randf_range(0.6, 2.8) * float(e.strength), color, visual_rng.randf_range(0.3, 1.0), visual_rng.randf_range(1.2, 3.2) if kind == "death" else visual_rng.randf_range(0.6, 1.6))
	if kind in ["impact", "blast", "hurt", "fire_hurt", "death"]: shake = maxf(shake, 0.35 * float(e.strength))
	if not muted: sound("launch" if kind == "launch" else ("chime" if kind in ["heal", "clear", "shield", "victory"] else "impact"))
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
	for name_value in ["impact", "launch", "chime"]:
		var stream := AudioStreamWAV.new(); stream.format = AudioStreamWAV.FORMAT_16_BITS; stream.mix_rate = 22050
		var data := PackedByteArray(); var length := 0.26 if name_value != "chime" else 0.65
		var samples := int(length * 22050); data.resize(samples * 2)
		for i in samples:
			var t := float(i) / 22050.0; var envelope := pow(1.0 - t / length, 2)
			var value := 0.0
			if name_value == "impact": value = sin(TAU * (95 * t - 85 * t * t)) * 0.7 + visual_rng.randf_range(-0.2, 0.2)
			elif name_value == "launch": value = visual_rng.randf_range(-0.5, 0.5) * sin(t * PI / length)
			else: value = (sin(TAU * 660 * t) + sin(TAU * 990 * t) * 0.4) * 0.35
			data.encode_s16(i * 2, int(clampf(value * envelope, -1, 1) * 12000))
		stream.data = data; sounds[name_value] = stream
	for i in 8:
		var voice := AudioStreamPlayer.new(); voice.volume_db = -10; add_child(voice); audio_voices.append(voice)

func sound(name_value: String) -> void:
	var voice: AudioStreamPlayer = audio_voices[voice_cursor]; voice_cursor = (voice_cursor + 1) % audio_voices.size()
	voice.stream = sounds[name_value]; voice.pitch_scale = visual_rng.randf_range(0.92, 1.08); voice.play()

func stop_audio() -> void:
	muted = true
	for voice in audio_voices:
		if is_instance_valid(voice):
			voice.stop()
			voice.stream = null

func _exit_tree() -> void:
	stop_audio()
	sounds.clear()
