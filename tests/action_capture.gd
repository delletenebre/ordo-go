extends SceneTree
const Main=preload("res://tests/support/test_main.gd")
var game
func _init()->void:call_deferred("run")
func run()->void:
	var scene:="clash";var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):scene=arg.trim_prefix("--scene=")
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	game=Main.new();root.add_child(game);await process_frame
	game.start_local(2,1);game.set_process(false)
	game.sim.pickups.clear();game.sim.enemies.clear()
	var sim=game.sim
	if scene in ["clash","team"]:
		sim.place(sim.players[0],Vector2(-1.45,2.8));sim.place(sim.players[1],Vector2(1.45,2.8))
		sim.players[0].angle=0;sim.players[1].angle=PI
		sim.spawn("brute",0);sim.place(sim.enemies[0],Vector2(0,2.8 if scene=="team" else 1.7))
	elif scene=="death":
		sim.players.resize(1);sim.place(sim.players[0],Vector2(0,4.8));sim.players[0].angle=-PI/2
		sim.spawn("coal",0);sim.place(sim.enemies[0],Vector2(0,3.6))
		game.hud.hide();var camera:Camera3D=game.arena.camera
		camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.near=.1;camera.size=5.8
		camera.position=Vector3(0,5.0,8.0);camera.look_at(Vector3(0,.35,2.8))
	elif scene in ["runes","class"]:
		sim.players.resize(1)
		var stone:Dictionary={}
		for candidate in sim.stones:
			if candidate.collector:stone=candidate;break
		stone.souls=2;stone.effect="class" if scene=="class" else "surge"
		var target:Vector2=sim.pos(stone)
		var start:=target*.63
		sim.place(sim.players[0],start);sim.players[0].angle=(target-start).angle()
		for i in 2:
			sim.spawn("coal",0);sim.place(sim.enemies[-1],start+Vector2(1.6,i*.9-1.5))
	for p in sim.players:p.ready=true;p.power=1.0
	var peak:=0;var events:Dictionary={};var recorded:=false
	for i in 180:
		if i==30:sim.launch()
		if i>=30:
			for substep in 4:sim.tick(1.0/120.0)
		game.arena.render_state(sim,1.0/30.0);game.arena.update_audio(1.0/30.0,false,sim)
		peak=maxi(peak,game.arena.debris.active_count())
		for event in sim.events:events[event.kind]=true
		await process_frame
		if not recorded and output!="" and ((scene=="death" and game.arena.debris.active_count()>0 and i>38) or (scene in ["clash","team"] and i==39) or (scene in ["runes","class"] and i==38)):
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output);recorded=true
	print("ACTION ",scene,": events=",events.keys()," peak_debris=",peak," dropped=",game.arena.debris.dropped)
	game.arena.stop_audio();await create_timer(.25).timeout
	game.queue_free();await process_frame;quit()
