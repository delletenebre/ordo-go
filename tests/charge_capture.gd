extends SceneTree
const Main = preload("res://tests/support/test_main.gd")
func _init() -> void: call_deferred("run")
func run() -> void:
	var prefix := "charge"
	if "--narrow" in OS.get_cmdline_user_args():
		root.size = Vector2i(1000,760); prefix = "narrow"
	var game = Main.new(); root.add_child(game); await process_frame
	game.start_local(2,1); game.set_process(false); game.arena.stop_audio()
	game.sim.start(2,1,77381)
	game.sim.place(game.sim.players[0],Vector2(-2.25,2.8)); game.sim.players[0].angle = -.6
	for i in 30:
		game.arena.render_state(game.sim,1.0/60); await process_frame
	game.begin_charge(-1,0)
	game.adjust_spin(0,1.0)
	for frame in 73:
		if frame > 0: game.read_continuous_input(1.0/60.0)
		game.arena.render_state(game.sim,1.0/60); await process_frame
		if frame in [0,36,72]:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://work/charge-shot/%s-%d.png" % [prefix,frame/36])
	game.release_charge(-1)
	game.sim.launch()
	for i in 90:
		game.sim.move_bodies(1.0/120.0,true)
		game.sim.move_bodies(1.0/120.0,true)
		game.arena.render_state(game.sim,1.0/60.0); await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://work/charge-shot/%s-flight.png" % prefix)
	game.arena.stop_audio(); game.queue_free(); await process_frame; quit()
