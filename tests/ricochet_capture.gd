extends SceneTree
const Main = preload("res://tests/support/test_main.gd")
var game

func _init() -> void: call_deferred("run")

func run() -> void:
	var narrow := "--narrow" in OS.get_cmdline_user_args()
	var output := "res://work/ricochet"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.content_scale_size = Vector2i(540, 900) if narrow else Vector2i(1280, 800)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	game = Main.new(); root.add_child(game); await process_frame
	game.start_local(1, 1); game.set_process(false); game.arena.muted = true
	for scene in ["chain", "bank"]:
		var sim = game.sim
		game.arena.reset_presentation(); sim.start(1, 1, 42)
		sim.enemies.clear(); sim.stones.clear(); sim.pickups.clear(); sim.events.clear()
		var p: Dictionary = sim.players[0]
		if scene == "chain":
			sim.place(p, Vector2(-3.6, 2.5)); p.angle = 0; p.power = .15
			for x in [-1.8, 0.0, 1.8]:
				sim.spawn("coal", 0); sim.place(sim.enemies[-1], Vector2(x, 2.5))
		else:
			# The upper-right bank directs the shot back toward a two-HP enemy.
			var lane := Vector2(1, 1).normalized()
			sim.place(p, lane * 5.4); p.angle = lane.angle(); p.power = 1
			sim.spawn("frost", 0); sim.place(sim.enemies[-1], lane * 3.5)
		p.ready = true
		var saved := false
		for frame in 150:
			if frame == 30: sim.launch()
			if frame >= 30:
				for substep in 2: sim.tick(1.0 / 120.0)
			game.arena.render_state(sim, 1.0 / 60.0)
			await process_frame
			if not saved and sim.events.any(func(e): return e.kind == "kill_boost"):
				# Wait several rendered frames so the directed burst has spread.
				for extra in 4:
					for substep in 2: sim.tick(1.0 / 120.0)
					game.arena.render_state(sim, 1.0 / 60.0)
					await process_frame
				root.get_texture().get_image().save_png(output + "/" + scene + ("-narrow" if narrow else "") + ".png")
				saved = true
		print("RICOCHET CAPTURE ", scene, " kills=", sim.kills, " boosts=", sim.events.filter(func(e): return e.kind == "kill_boost").size(), " saved=", saved)
	game.queue_free(); await process_frame; quit()
