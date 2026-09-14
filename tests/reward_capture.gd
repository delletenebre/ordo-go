extends SceneTree
const Main = preload("res://scripts/main.gd")
func _init() -> void: call_deferred("run")
func run() -> void:
	var game = Main.new();root.add_child(game);await process_frame
	var mode := "reward"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="): mode=arg.trim_prefix("--mode=")
	if mode.begins_with("reward"):
		game.start_local(4,1);game.sim.begin_reward()
		game.sim.reward_options=["stitch","spark","stride"] if mode=="reward" else ["charge","guard","mend"]
		game.sim.choose_reward(0,0);game.sim.choose_reward(1,1);game.sim.choose_reward(2,0)
	else:
		game.keyboard_seat=true;game.register_pad(10);game.register_pad(11);game.register_pad(12)
	if mode=="network":
		game.hud.game_menu.show_network(true)
		game.hud.room_label.text="КОМНАТА ABC234 · 4 / 4"
		game.hud.message_label.text="Все хранители у очага. Можно начинать."
		game.hud.start_button.show();game.hud.start_button.grab_focus()
	game.set_process(false)
	for i in 60:game.arena.render_state(game.sim,1.0/60);await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://work/rewards/%s.png"%mode)
	game.arena.stop_audio();game.queue_free();await process_frame;quit()
