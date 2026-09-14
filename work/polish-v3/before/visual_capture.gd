extends SceneTree
const Main=preload("res://scripts/main.gd")
var game
func _init()->void:call_deferred("run")
func run()->void:
	game=Main.new();root.add_child(game);await process_frame
	var shot:="";var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):shot=arg.trim_prefix("--shot=")
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	if shot!="":
		game.start_local(4,1);game.set_process(false);game.hud.hide()
		var camera:Camera3D=game.arena.camera;camera.near=0.1;camera.projection=Camera3D.PROJECTION_ORTHOGONAL
		var target:=Vector3.ZERO
		if shot=="face":
			var e:Dictionary=game.sim.enemies[0];target=Vector3(float(e.x),0.4,float(e.z));camera.size=2.2
		elif shot=="token":target=Vector3(0,0.25,3.5);camera.size=2.2
		elif shot=="wall":target=Vector3(-5.8,0.4,-2.0);camera.size=4.0
		else:target=Vector3(0,0.4,0);camera.size=4.3
		camera.position=target+Vector3(0,4,5);camera.look_at(target)
		for i in 60:
			game.arena.render_state(game.sim,1.0/30.0)
			if shot=="face":game.arena.actors[str(int(game.sim.enemies[0].id))].get_node("Face").react("fear",1.0)
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output)
	else:
		await create_timer(2.0).timeout
		game.start_local(4,1)
		for i in 90:
			game.sim.players[0].angle=-PI/2+sin(i/90.0*PI)*0.8
			await process_frame
		game.demo=true
		var phases:Dictionary={};var peak_smoke:=0;var peak_combo:=0;var deaths:=0;var seen:=0
		for i in 540:
			await process_frame
			phases[game.sim.phase]=true;peak_smoke=maxi(peak_smoke,game.arena.smoke.active_count());peak_combo=maxi(peak_combo,game.arena.combo_hits)
			for event in game.sim.events:
				if int(event.id)>seen:
					seen=int(event.id)
					if event.kind=="death":deaths+=1
		print("VISUAL: phases=",phases.keys()," max_smoke=",peak_smoke," max_combo=",peak_combo," deaths=",deaths," dropped_smoke=",game.arena.smoke.dropped)
	game.arena.stop_audio();await create_timer(0.15).timeout
	game.queue_free();await process_frame;quit()
