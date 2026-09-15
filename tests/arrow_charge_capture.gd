extends SceneTree
const Main=preload("res://tests/support/test_main.gd")
func _init()->void:call_deferred("run")
func run()->void:
	var game=Main.new();root.add_child(game);await process_frame
	game.start_local(1,1);game.set_process(false);game.hud.set_process(false);game.arena.stop_audio()
	game.sim.enemies.clear();game.sim.events.clear();game.sim.pickups.clear()
	var sim=game.sim;var player:Dictionary=sim.players[0]
	var origin:=Vector2(-2.6,2.0)
	var contact:Vector2=sim.pos(sim.stones[2])+Vector2(.96,.28).normalized()*(.44+.43)
	sim.place(player,origin);player.angle=(contact-origin).angle()
	DirAccess.make_dir_recursive_absolute("/tmp/ordo-arrow-charge-frames")
	RenderingServer.render_loop_enabled=false
	for frame in 78:
		if frame>=12 and frame<48:
			game.begin_charge(-1,0)
			game.shot_charges[-1].elapsed=minf((frame-12)/30.0,game.CHARGE_SECONDS)
			game.update_charges(0)
		elif frame==48:game.release_charge(-1)
		elif frame==63:game.cancel_charge(0)
		game.arena.render_state(sim,1.0/30)
		game.hud._process(1.0/30);game.hud.queue_redraw()
		await process_frame;RenderingServer.force_draw(true,1.0/30)
		root.get_texture().get_image().save_jpg("/tmp/ordo-arrow-charge-frames/%04d.jpg"%frame,.95)
	game.queue_free();await process_frame;quit()
