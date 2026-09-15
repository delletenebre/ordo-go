extends SceneTree
const Main=preload("res://tests/support/test_main.gd")
func _init()->void:call_deferred("run")
func capture(game,filename:String)->void:
	for i in 6:
		game.arena.render_state(game.sim,1.0/60);await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://work/aim-refine/"+filename+".png")
func run()->void:
	var game=Main.new();root.add_child(game);await process_frame
	game.start_local(2,1);game.set_process(false);game.arena.stop_audio()
	game.sim.start(2,1,77381)
	game.sim.place(game.sim.players[0],Vector2(-2.25,2.8));game.sim.players[0].angle=-2.0
	for i in 30:game.arena.render_state(game.sim,1.0/60);await process_frame
	await capture(game,"direction")
	game.sim.players[0].angle=-.6;game.adjust_spin(0,1.0)
	await capture(game,"curve-idle")
	game.begin_charge(-1,0);game.read_continuous_input(.6)
	await capture(game,"curve-half")
	game.read_continuous_input(.6)
	await capture(game,"curve-full")
	root.size=Vector2i(1000,760)
	await capture(game,"curve-narrow")
	game.arena.stop_audio();game.queue_free();await process_frame;quit()
