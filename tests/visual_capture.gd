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
		game.start_local(4,1);game.set_process(false)
		if shot!="arena":game.hud.hide()
		var camera:Camera3D=game.arena.camera;camera.near=0.1
		if shot!="arena":camera.projection=Camera3D.PROJECTION_ORTHOGONAL
		var target:=Vector3.ZERO
		if shot=="face":
			var e:Dictionary=game.sim.enemies[0];target=Vector3(float(e.x),0.4,float(e.z));camera.size=2.2
		elif shot=="token":target=Vector3(0,0.25,3.5);camera.size=2.2
		elif shot=="spirit":
			game.sim.players.clear();game.sim.enemies.clear();game.sim.pickups.clear()
			game.sim.pickups.append({"id":900,"kind":"spirit","spirit":"wind","x":0.0,"z":3.5,"expires":4})
			target=Vector3(0,0.35,3.5);camera.size=2.4
		elif shot=="curse":
			game.sim.players.resize(1);game.sim.enemies.clear();game.sim.pickups.clear()
			game.sim.players[0].x=0.0;game.sim.players[0].z=3.5
			game.sim.players[0].statuses={"snare":2}
			target=Vector3(0,0.35,3.5);camera.size=2.8
		elif shot=="magic":
			game.sim.enemies.clear();game.sim.pickups.clear()
			var kinds: Array = game.arena.spirit_visuals.Spirits.TYPES.keys()
			for i in kinds.size():
				game.sim.pickups.append({"id":900+i,"kind":"spirit","spirit":kinds[i],"x":(i-3)*1.3,"z":1.0,"expires":4})
			for i in 4:
				game.sim.players[i].x=(i-1.5)*1.9;game.sim.players[i].z=3.0
				game.sim.players[i].statuses={ ["burn","frost","snare","weak"][i]:2 }
			game.sim.pickups.append({"id":920,"kind":"heart","x":-1.2,"z":-2.1})
			game.sim.pickups.append({"id":921,"kind":"charge","x":1.2,"z":-2.1})
			game.sim.add_hazard(Vector2(3.4,-2.0),0.8,"ice")
			target=Vector3(0,0.3,0.2);camera.size=11.8
		elif shot=="wall":target=Vector3(-5.4,0.35,-3.5);camera.size=4.6
		elif shot=="lantern":target=Vector3(6.62,1.0,0);camera.size=2.6
		else:target=Vector3(0,0.4,0);camera.size=4.3
		if shot!="arena":camera.position=target+Vector3(0,4,5);camera.look_at(target)
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
