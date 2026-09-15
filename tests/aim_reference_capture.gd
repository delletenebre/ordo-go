extends SceneTree
const Main=preload("res://tests/support/test_main.gd")
func _init()->void:call_deferred("run")
# Re-apply the held-button fixture during capture so desktop focus changes
# cannot cancel the sampled pose. Real focus cancellation is tested separately.
func hold(game,elapsed:float)->void:
	for slot in 4:
		game.begin_charge(slot,slot)
		game.shot_charges[slot].elapsed=elapsed
	game.update_charges(0.0)
func snap(game,label:String,elapsed:float=-1.0)->void:
	for i in 12:
		if elapsed>=0:hold(game,elapsed)
		game.arena.render_state(game.sim,1.0/60);await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://work/aim-reference/"+label+".png")
func run()->void:
	DirAccess.make_dir_recursive_absolute("res://work/aim-reference")
	var game=Main.new();root.add_child(game);await process_frame
	game.start_local(4,1);game.set_process(false);game.arena.stop_audio();game.sim.start(4,1,77381)
	game.sim.enemies.clear();game.sim.pickups.clear()
	var starts:=[Vector2(-2.25,-2.6),Vector2(3.4,.2),Vector2(2.9,3.35),Vector2(-2.35,3.5)]
	var headings:=[-.35,-.75,-.9,-2.2]
	for i in 4:
		game.sim.place(game.sim.players[i],starts[i]);game.sim.players[i].angle=headings[i]
	for point in [Vector2(1.2,-3.35),Vector2(2.15,-4.15),Vector2(2.6,-1.8),Vector2(4.7,-2.5),Vector2(-4.0,.35),Vector2(-1.8,2.0),Vector2(5.1,1.0),Vector2(-4.3,3.0)]:
		game.sim.spawn("coal",0);game.sim.place(game.sim.enemies[-1],point)
	for i in 40:game.arena.render_state(game.sim,1.0/60);await process_frame
	await snap(game,"idle")
	for i in 4:game.begin_charge(i,i)
	game.adjust_spin(1,.8);game.adjust_spin(2,-.7);game.adjust_spin(3,.7)
	for frame in 73:
		hold(game,minf(1.2,(frame+1)/60.0));game.arena.render_state(game.sim,1.0/60);await process_frame
		if frame==35:await snap(game,"half",.6)
	for frame in 60:
		hold(game,1.2)
		game.arena.render_state(game.sim,1.0/60);await process_frame
	await snap(game,"full",1.2)
	root.size=Vector2i(1000,760);await snap(game,"narrow",1.2)
	game.arena.stop_audio();game.queue_free();await process_frame;quit()
