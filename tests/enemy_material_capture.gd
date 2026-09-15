extends SceneTree
const Main=preload("res://tests/support/test_main.gd")
var game
func _init()->void:call_deferred("run")
func run()->void:
	root.content_scale_size=Vector2i(1440,880);root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	game=Main.new();root.add_child(game);await process_frame
	game.start_local(2,1);game.set_process(false);game.arena.muted=true;game.hud.hide()
	var sim=game.sim
	sim.enemies.clear();sim.pickups.clear();sim.events.clear();sim.stones.clear()
	var kinds:=["coal","brute","frost","weaver"]
	var names:=["УГОЛЁК","КАМЕНЬ · БРОНЗА","КЕРАМИКА","ВОЙЛОЧНАЯ ПРЯХА"]
	var starts:Array[Vector2]=[]
	for i in 4:
		var point:=Vector2((i-1.5)*1.75,3.5)
		starts.append(point);sim.spawn(kinds[i],0)
		var e:Dictionary=sim.enemies[-1];e.r=.46 if i<3 else .60;sim.place(e,point)
	sim.players.clear();sim.events.clear();game.arena.last_event=sim.event_id
	var camera:Camera3D=game.arena.camera
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=8.0;camera.near=.1
	game.arena.camera_frame=Vector2.ZERO;game.arena.camera_pan=Vector2.ZERO
	var target:=Vector3(0,.55,3.5);camera.position=target+Vector3(0,2.1,6.0);camera.look_at(target)
	game.arena.render_state(sim,0)
	for stone in game.arena.rune_stones:stone.hide()
	var canvas:=CanvasLayer.new();root.add_child(canvas)
	var stage:=Label.new();stage.position=Vector2(28,22);stage.add_theme_font_size_override("font_size",24);canvas.add_child(stage)
	for i in 4:
		var label:=Label.new();label.text=names[i];label.add_theme_font_size_override("font_size",17)
		label.position=game.arena.screen_point(starts[i]+Vector2(0,.77),0)+Vector2(-150,0);label.size.x=300;label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		canvas.add_child(label)
	DirAccess.make_dir_recursive_absolute("/tmp/ordo-material-frames")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://work/enemy-motion"))
	RenderingServer.render_loop_enabled=false
	for frame in (70 if "--still" in OS.get_cmdline_user_args() else 450):
		var t:=float(frame)/60
		stage.text="МАТЕРИАЛЫ · ПОКОЙ" if t<1.0 else ("ДВИЖЕНИЕ" if t<2.8 else ("АТАКА" if t<4.6 else ("УДАР" if t<5.2 else "РАСПАД МАТЕРИАЛА")))
		for i in sim.enemies.size():
			var e:Dictionary=sim.enemies[i]
			if t<2.8:
				sim.phase="resolve";e.vx=.28 if t>1.0 else 0.0;e.vz=0.0
				sim.place(e,starts[i]+Vector2(clampf(t-1.0,0,1.8)*.28,0))
			elif t<4.6:
				sim.phase="enemy";sim.phase_time=t-2.8;e.vx=0.0;e.vz=0.0;e.fired=sim.phase_time>.95
				e.attack="rush" if i==0 else ("jump" if i==3 else ("frost" if i==2 else "slam"))
				if i==0 and sim.phase_time<.8:sim.place(e,sim.pos(e)+Vector2(-1.5/60,0));e.vx=-1.5
				if i==3:e.jump=sim.phase_time/.95 if sim.phase_time<.95 else 0.0
			else:sim.phase="plan"
		if frame==276:
			for actor in game.arena.actors.values():
				actor.get_node("Rig").hit(1.5);actor.get_node("Face").react("surprise",.5)
		if frame==312:
			for e in sim.enemies:
				e.vx=-1.3;e.vz=.2
				sim.hit_enemy(e,100,"demo-%d"%int(e.id),sim.pos(e))
			sim.enemies.clear()
		game.arena.render_state(sim,1.0/60);await process_frame
		RenderingServer.force_draw(true,1.0/60)
		root.get_texture().get_image().save_jpg("/tmp/ordo-material-frames/%05d.jpg"%frame,.93)
		if frame in [40,105,193,289,337]:root.get_texture().get_image().save_png("res://work/enemy-motion/materials-%03d.png"%frame)
	game.queue_free();await process_frame
	print("MATERIAL CAPTURE COMPLETE 450 frames")
	quit()
