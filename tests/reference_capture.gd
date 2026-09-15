extends SceneTree
const Main=preload("res://tests/support/test_main.gd")
var game
func _init()->void:call_deferred("run")
func run()->void:
	var output:="res://work/arena-reference/reference.png"
	var scenario:="reference"
	var capture_size:=Vector2i(1540,1020)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
		if arg.begins_with("--case="):scenario=arg.trim_prefix("--case=")
		if arg=="--wide":capture_size=Vector2i(1920,1080)
	root.content_scale_size=capture_size
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	game=Main.new();root.add_child(game);await process_frame
	game.start_local(4,1);game.set_process(false);game.arena.muted=true
	game.sim.start(4,1,77381)
	if scenario=="reference":
		game.sim.enemies.clear();game.sim.pickups.clear()
		var starts:=[Vector2(-2.25,-2.6),Vector2(3.4,.2),Vector2(2.9,3.35),Vector2(-2.35,3.5)]
		var headings:=[-.35,-.75,-.62,-2.2]
		for i in 4:
			game.sim.place(game.sim.players[i],starts[i]);game.sim.players[i].angle=headings[i]
			game.sim.players[i].power=.5
		for point in [Vector2(-3.8,-2.6),Vector2(1.2,-3.35),Vector2(2.15,-4.15),Vector2(2.6,-1.8),Vector2(4.7,-2.5),Vector2(-4.0,.35),Vector2(-1.8,2.0),Vector2(1.1,3.5),Vector2(4.2,3.4),Vector2(5.1,1.0),Vector2(-4.3,3.0)]:
			game.sim.spawn("coal",0);game.sim.place(game.sim.enemies[-1],point)
		game.sim.players[1].shield=1
	if scenario in ["enemy","stone","emotions"]:
		game.hud.hide();game.arena.camera_frame=Vector2.ZERO
		var camera:Camera3D=game.arena.camera
		camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.near=.1;camera.size=2.1
		var target:=Vector3.ZERO
		if scenario in ["enemy","emotions"]:
			game.sim.players.clear();game.sim.enemies.clear();game.sim.pickups.clear()
			game.sim.spawn("coal",0);game.sim.place(game.sim.enemies[0],Vector2(0,3.1))
			target=Vector3(0,.34,3.1)
			if scenario=="emotions":
				game.sim.enemies.clear();camera.size=4.0
				for index in 4:
					game.sim.spawn("coal",0);game.sim.place(game.sim.enemies[-1],Vector2((index-1.5)*.91,3.1))
		else:
			var stone:Dictionary=game.sim.stones[0]
			game.sim.players.clear();game.sim.enemies.clear();game.sim.pickups.clear()
			stone.collector=true;stone.souls=2;stone.effect="guard"
			target=Vector3(stone.x,.4,stone.z)
		camera.position=target+Vector3(0,2.7,3.1);camera.look_at(target)
	game.sim.events.clear();game.hud.seen=game.sim.event_id;game.hud.pulse_events.clear()
	if scenario=="emotions":
		game.arena.render_state(game.sim,0.0)
		for index in 4:
			game.arena.actors[str(int(game.sim.enemies[index].id))].get_node("Face").react(["neutral","fear","joy","anger"][index],10.0)
	for i in 75:
		game.arena.render_state(game.sim,1.0/60.0);await process_frame
	game.hud.set_process(false);game.hud.clock=.25;game.hud.queue_redraw()
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output)
	for i in game.sim.players.size():
		var p:Dictionary=game.sim.players[i];var center:Vector2=game.sim.pos(p)
		print("TOKEN ",i,": center=",game.arena.screen_point(center,.2)," width=",game.arena.screen_point(center+Vector2(p.r,0),.2).distance_to(game.arena.screen_point(center-Vector2(p.r,0),.2)))
	print("REFERENCE CAPTURE: ",scenario," ",root.get_texture().get_size()," ",output)
	game.arena.stop_audio();game.queue_free();await process_frame;quit()
