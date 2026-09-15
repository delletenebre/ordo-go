extends SceneTree

# Isolated proposal: the shipping simulation and HUD are never modified.
const Arena = preload("res://scripts/arena.gd")
const Overlay = preload("res://tools/aim_energy/overlay.gd")
var demo_script: GDScript
var sim
var arena
var overlay
var traces: Dictionary = {}
var guide: Dictionary = {}
var elapsed := 0.0
var aiming := true
var chapter := 0
var result_events: Array = []
var output := "/tmp/ordo-aim-energy-frames"

func _init() -> void: call_deferred("run")

func build_model() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/simulation.gd")
	source = source.replace("class_name OrdoSimulation\n", "")
	source = source.replace("const DRAG := 1.4", "const DRAG := 0.95")
	source = source.replace("const WALL_BOUNCE := 0.84", "const WALL_BOUNCE := 0.94")
	source = source.replace("const STONE_BOUNCE := 0.86", "const STONE_BOUNCE := 0.94")
	source = source.replace("3.0 + float(p.power) * 10.0", "3.0 + float(p.power) * 15.0")
	demo_script = GDScript.new(); demo_script.source_code = source
	assert(demo_script.reload() == OK)

func fixture(count: int = 1):
	var model = demo_script.new(); model.start(count, 1, 73193)
	model.enemies.clear(); model.pickups.clear(); model.events.clear()
	for stone in model.stones: stone.collector = false
	var stone: Vector2 = model.pos(model.stones[2])
	var normal := Vector2(.96,.28).normalized()
	var contact := stone + normal * (.44+.43)
	var start := Vector2(-2.3,3.3)
	var incoming := (contact-start).normalized()
	var reflected := incoming.bounce(normal)
	model.place(model.players[0],start); model.players[0].angle = incoming.angle()-.02
	for d in [2.8,3.75,4.65]:
		model.spawn("hopper",0)
		model.place(model.enemies[-1],contact+reflected*d+Vector2(.3,0))
		model.enemies[-1].attack = "rest"
	if count == 4:
		var starts := [Vector2(3.7,2.8),Vector2(3.7,-2.7),Vector2(-3.4,-3.2)]
		var targets := [Vector2(1.8,2.2),Vector2(2.0,-1.8),Vector2(-1.8,-3.0)]
		for i in 3:
			model.place(model.players[i+1],starts[i])
			model.players[i+1].angle = (targets[i]-starts[i]).angle()
		for point in [Vector2(1.8,2.2),Vector2(.8,2.0),Vector2(-.2,2.2),Vector2(2.0,-1.8),Vector2(1.2,-2.25),Vector2(2.7,.1),Vector2(-2.0,1.0)]:
			model.spawn("hopper",0);model.place(model.enemies[-1],point)
			model.enemies[-1].attack = "rest"
	for p in model.players: p.power = 1.0; p.ready = true
	model.events.clear(); model.event_id = 0
	return model

func predict(model) -> Dictionary:
	var forecast = demo_script.new(); forecast.restore(model.snapshot())
	forecast.events.clear(); forecast.event_id = 0
	forecast.launch()
	var paths: Dictionary = {}
	var contacts: Array = []
	var cutoff: Dictionary = {}
	for p in forecast.players: paths[int(p.id)] = []
	for step in 600:
		var seen: int = forecast.event_id
		forecast.move_bodies(1.0/120.0,true)
		for event in forecast.events:
			if int(event.id) <= seen or event.kind != "impact": continue
			if int(event.a) < 4 or int(event.b) < 4:
				contacts.append(event.duplicate())
				cutoff[int(event.a)] = true;cutoff[int(event.b)] = true
		if step % 3 == 0:
			for p in forecast.players:
				if not cutoff.has(int(p.id)):
					paths[int(p.id)].append({"p":forecast.pos(p),"speed":forecast.vel(p).length()})
	return {"paths":paths,"contacts":contacts}

func report(model, label: String, verbose: bool=true) -> Dictionary:
	model.launch()
	var distance := 0.0
	var previous: Vector2 = model.pos(model.players[0])
	for step in 600:
		model.move_bodies(1.0/120.0,true)
		distance += previous.distance_to(model.pos(model.players[0]));previous=model.pos(model.players[0])
	var impacts := 0; var peak := 0.0
	for event in model.events:
		if event.kind == "impact":impacts+=1;peak=maxf(peak,float(event.speed))
	var result := {"distance":snappedf(distance,.01),"contacts":impacts,"peak":snappedf(peak,.01),"kills":model.kills}
	if verbose:print(label," ",result)
	return result

func run() -> void:
	build_model()
	if "--scan" in OS.get_cmdline_user_args():
		for shift in [-.3,-.2,-.1,0.0,.1,.2,.3]:
			for angle in [-.02,-.01,0.0,.01,.02]:
				var results: Array=[]
				for power in [.3,.7,1.0]:
					var model=fixture();model.players[0].power=power;model.players[0].angle+=angle
					for e in model.enemies:model.place(e,model.pos(e)+Vector2(shift,0))
					results.append(report(model,"",false))
				if results[2].kills>=3 and results[1].kills<results[2].kills:
					print("CANDIDATE ",shift," ",angle," ",results)
		quit();return
	if "--metrics" in OS.get_cmdline_user_args():
		for power in [.3,.7,1.0]:
			var model = fixture();model.players[0].power=power;report(model,str(power))
		report(fixture(4),"4 players")
		quit();return
	root.size = Vector2i(1280,800)
	root.content_scale_size = Vector2i(1280,800)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	arena = Arena.new();root.add_child(arena);arena.stop_audio()
	var layer := CanvasLayer.new();root.add_child(layer)
	overlay = Overlay.new();overlay.demo=self;layer.add_child(overlay)
	DirAccess.make_dir_recursive_absolute("res://work/aim-energy")
	DirAccess.make_dir_recursive_absolute(output)
	RenderingServer.render_loop_enabled=false
	var frame_id := 0
	for scene in 4:
		chapter=scene;sim=fixture(4 if scene==3 else 1)
		arena.reset_presentation()
		guide=predict(sim)
		var power: float = [.3,.7,1.0,1.0][scene]
		var last_power := -1.0
		for frame in 225:
			elapsed=float(frame)/30.0;aiming=frame<105
			if aiming:
				# Charge in place while the full-power guide stays stationary.
				var charge := lerpf(.15,power,smoothstep(.65,2.2,elapsed))
				for p in sim.players:p.power=charge
				var quantized := snappedf(charge,.02)
				if quantized != last_power:
					traces=predict(sim);last_power=quantized
			elif frame==105:
				for p in sim.players:p.power=power
				sim.launch()
			else:
				for step in 4:sim.move_bodies(1.0/120.0,true)
				sim.phase_time+=1.0/30.0
			arena.render_state(sim,1.0/30.0)
			overlay.queue_redraw()
			await process_frame
			RenderingServer.force_draw(true,1.0/30.0)
			root.get_texture().get_image().save_jpg(output+"/%05d.jpg"%frame_id,.94)
			if frame==98 or frame==122:
				root.get_texture().get_image().save_png("res://work/aim-energy/scene-%d-%d.png"%[scene,frame])
			frame_id+=1
		print("CHAPTER ",scene," DONE")
	arena.stop_audio();arena.queue_free();layer.queue_free();await process_frame
	quit()
