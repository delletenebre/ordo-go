extends SceneTree
const Main=preload("res://tests/support/test_main.gd")
func _init()->void:call_deferred("run")
func capture(game,label:String,power:float)->void:
	for i in 18:
		game.begin_charge(-1,0)
		game.shot_charges[-1].elapsed=(power-.15)/.85*game.CHARGE_SECONDS
		game.update_charges(0.0)
		game.arena.render_state(game.sim,1.0/60)
		game.hud._process(1.0/60);game.hud.clock=.25;game.hud.queue_redraw()
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://work/fixed-aim/"+label+".png")
func run()->void:
	DirAccess.make_dir_recursive_absolute("res://work/fixed-aim")
	var game=Main.new();root.add_child(game);await process_frame
	game.start_local(1,1);game.set_process(false);game.hud.set_process(false);game.arena.stop_audio()
	game.sim.enemies.clear();game.sim.events.clear();game.sim.pickups.clear()
	var sim=game.sim;var player:Dictionary=sim.players[0]
	var origin:=Vector2(-2.6,2.0)
	var stone:Vector2=sim.pos(sim.stones[2])
	var contact:=stone+Vector2(.96,.28).normalized()*(.44+.43)
	sim.place(player,origin);player.angle=(contact-origin).angle()
	for power in [.15,.5,1.0]:await capture(game,"charge-%d"%roundi(power*100),power)
	player.spin=.8;await capture(game,"curl-low",.15);await capture(game,"curl-full",1.0)
	player.spin=0;root.size=Vector2i(1000,760);await capture(game,"narrow",1.0)
	game.arena.stop_audio();game.queue_free();await process_frame;quit()
