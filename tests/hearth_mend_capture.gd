extends SceneTree
const Main = preload("res://tests/support/test_main.gd")
func _init() -> void: call_deferred("run")
func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://work/hearth-mend/" + label + ".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://work/hearth-mend")
	root.size = Vector2i(1440, 960)
	var game = Main.new(); root.add_child(game); await process_frame
	game.start_local(1, 1); game.set_process(false); game.arena.stop_audio()
	var sim = game.sim
	sim.enemies.clear(); sim.pickups.clear(); sim.stones.clear(); sim.events.clear()
	sim.fire = 3
	var player: Dictionary = sim.players[0]
	player.spirit = {"kind": "master", "turns": 2}
	sim.place(player, Vector2(2.2, 1.0))
	for i in 45:
		game.arena.render_state(sim, 1.0 / 60); await process_frame
	await shot("before")
	for narrow in [false, true]:
		if narrow: root.size = Vector2i(820, 1000)
		game.arena.reset_presentation(); game.hud.seen = sim.event_id; game.hud.pulse_events.clear()
		sim.events.clear(); sim.fire = 3; player.spirit.erase("mended_turn")
		sim.place(player, Vector2(2.2, 1.0)); sim.velocity(player, -sim.pos(player).normalized() * 4)
		var contact_frame := -1
		for i in 135:
			sim.move_bodies(sim.STEP, true); sim.move_bodies(sim.STEP, true)
			if sim.fire == 4 and contact_frame < 0: contact_frame = i
			game.arena.render_state(sim, 1.0 / 60); await process_frame
			if contact_frame >= 0 and i - contact_frame in [7, 23, 47, 95]:
				await shot(("narrow-" if narrow else "wide-") + str(i - contact_frame))
	root.size = Vector2i(1440, 960); game.hud.help_open = true
	for i in 10: game.arena.render_state(sim, 1.0 / 60); await process_frame
	await shot("spirit-names")
	game.queue_free(); await process_frame; quit()
