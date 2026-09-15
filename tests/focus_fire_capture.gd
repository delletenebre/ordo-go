extends SceneTree
const Main=preload("res://tests/support/test_main.gd")
func _init() -> void:call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://work/rewards")
	var game=Main.new();root.add_child(game);await process_frame
	game.set_process(false);game.keyboard_seat=true
	game.arena.stop_audio()
	for i in 480:
		if i==120:game.hud.game_menu.network_button.grab_focus()
		if i==210:
			game.start_local(4,1);game.set_process(false);game.arena.stop_audio()
			game.sim.begin_reward();game.sim.reward_options=["stitch","spark","stride"]
		if i==260:game.sim.choose_reward(0,0)
		if i==370:game.sim.choose_reward(0,1)
		game.arena.render_state(game.sim,1.0/60)
		await process_frame
		if i in [100,245,320]:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://work/rewards/fire-%s.png"%("menu" if i==100 else ("reward-focus" if i==245 else "reward")))
	game.arena.stop_audio();game.queue_free();await process_frame;quit()
