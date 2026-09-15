extends SceneTree
const Main=preload("res://tests/support/test_main.gd")
var game
func _init()->void:call_deferred("run")
func run()->void:
	DirAccess.make_dir_recursive_absolute("res://work/arena-reference")
	root.content_scale_size=Vector2i(1440,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	game=Main.new();root.add_child(game);await process_frame
	game.start_local(1,1);game.set_process(false);game.arena.muted=true;game.hud.hide()
	game.sim.enemies.clear();game.sim.players.clear();game.sim.pickups.clear();game.sim.events.clear()
	var ids:=[13,14,15,16,19,20]
	var kinds:=["coal","hopper","brute","frost","coal","weaver"]
	var names:=["УСИКИ","БЕГУН","ЩИТОНОСЕЦ","ШИПЫ","СШИТЫЙ","ПРЯХА"]
	var starts:Array[Vector2]=[]
	for i in 6:
		var point:=Vector2((i%3-1)*1.75,2.0+float(i/3)*1.8)
		starts.append(point);game.sim.spawn(kinds[i],0)
		var e:Dictionary=game.sim.enemies[-1];e.id=ids[i];e.r=.38;e.fired=false
		game.sim.place(e,point)
	game.sim.events.clear();game.arena.last_event=game.sim.event_id
	var camera:Camera3D=game.arena.camera
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=6.1;camera.near=.1
	game.arena.camera_frame=Vector2.ZERO
	var target:=Vector3(0,.25,2.9);camera.position=target+Vector3(0,3.2,4.2);camera.look_at(target)
	game.arena.render_state(game.sim,0.0)
	for stone in game.arena.rune_stones:stone.hide()
	var canvas:=CanvasLayer.new();root.add_child(canvas)
	var stage:=Label.new();stage.position=Vector2(36,28);stage.add_theme_font_size_override("font_size",28);canvas.add_child(stage)
	for i in 6:
		var label:=Label.new();label.text=names[i];label.add_theme_font_size_override("font_size",17)
		label.position=game.arena.screen_point(starts[i]+Vector2(0,.65),0)+Vector2(-80,0);label.size.x=160;label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		canvas.add_child(label)
	for frame in 480:
		var t:=float(frame)/60.0
		stage.text="ПОКОЙ" if t<1.2 else ("ДВИЖЕНИЕ" if t<3.0 else ("АТАКА" if t<4.8 else ("УДАР" if t<5.5 else "ГИБЕЛЬ")))
		for i in game.sim.enemies.size():
			var e:Dictionary=game.sim.enemies[i]
			if t<3:
				game.sim.phase="plan";e.vx=2.0 if t>1.2 else 0.0;e.vz=0.0
				game.sim.place(e,starts[i]+Vector2(sin((t-1.2)*3)*.12 if t>1.2 else 0,0))
			elif t<4.8:
				game.sim.phase="enemy";game.sim.phase_time=t-3.0;e.vx=0.0;e.vz=0.0
				e.attack="slam";e.fired=t>3.88
			else:game.sim.phase="plan"
		if frame==288:
			for actor in game.arena.actors.values():
				actor.get_node("Rig").hit(1.5);actor.get_node("Face").react("surprise",.65)
		if frame==330:
			for e in game.sim.enemies:
				e.vx=1.3;e.vz=.3
				game.sim.hit_enemy(e,100,"rig-demo-%d"%int(e.id),game.sim.pos(e))
			game.sim.enemies.clear()
		game.arena.render_state(game.sim,1.0/60.0);await process_frame
		if frame in [60,218,301,342]:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://work/arena-reference/variants-%d.png"%frame)
	game.arena.stop_audio();game.queue_free();await process_frame
	print("RIG CAPTURE COMPLETE: idle, movement, attack, hit, death; 480 frames")
	quit()
