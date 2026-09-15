extends SceneTree

const Main = preload("res://tests/support/test_main.gd")

func _init() -> void: call_deferred("run")

func run() -> void:
	var label := "after"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--label="): label = arg.trim_prefix("--label=")
	var game := Main.new()
	root.add_child(game)
	await process_frame
	game.start_local(1,1); game.set_process(false); game.arena.stop_audio()
	game.sim.enemies.clear(); game.sim.stones.clear(); game.sim.events.clear(); game.sim.pickups.clear()
	var player: Dictionary = game.sim.players[0]
	game.sim.place(player,Vector2(-3.45,3.8)); player.angle = PI; player.spin = 0.0
	game.hud.seen = game.sim.event_id; game.hud.pulse_events.clear()
	DirAccess.make_dir_recursive_absolute("res://work/aim-corner")
	for scenario in ["rim", "curl", "near", "narrow", "full"]:
		player.spin = .8 if scenario == "curl" else 0.0
		if scenario == "near": game.sim.place(player,Vector2(-4.15,3.8))
		if scenario == "narrow": root.size = Vector2i(1000,760)
		for i in 12:
			if scenario == "full":
				game.begin_charge(-1,0)
				game.shot_charges[-1].elapsed = game.CHARGE_SECONDS
				game.update_charges(0.0)
			game.arena.render_state(game.sim,1.0/60)
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://work/aim-corner/%s-%s.png" % [label,scenario])
	game.queue_free(); await process_frame; quit()
