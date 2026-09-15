extends SceneTree
const Main=preload("res://tests/support/test_main.gd")
var game
func _init()->void:call_deferred("run")
func run()->void:
	DirAccess.make_dir_recursive_absolute("res://work/enemy-motion")
	root.content_scale_size=Vector2i(1440,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	game=Main.new();root.add_child(game);await process_frame
	game.start_local(2,1);game.set_process(false);game.arena.muted=true;game.hud.hide()
	var sim=game.sim;sim.enemies.clear();sim.events.clear();sim.stones.clear();sim.pickups.clear()
	for i in 2:
		sim.spawn("coal" if i==0 else "brute",0);var e:Dictionary=sim.enemies[-1];e.r=.72;sim.place(e,Vector2(-1.3+i*2.6,3.7))
	sim.players.clear();sim.events.clear();game.arena.last_event=sim.event_id
	var camera:Camera3D=game.arena.camera
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=5.3;camera.near=.1
	game.arena.camera_frame=Vector2.ZERO;game.arena.camera_pan=Vector2.ZERO
	var target:=Vector3(0,.70,3.7);camera.position=target+Vector3(0,1.8,6);camera.look_at(target)
	game.arena.render_state(sim,0)
	for stone in game.arena.rune_stones:stone.hide()
	var canvas:=CanvasLayer.new();root.add_child(canvas)
	var stage:=Label.new();stage.text="УГОЛЁК И БРОНЗОВЫЙ ЩИТ · КАДР ИЗ ИГРЫ";stage.position=Vector2(32,28);stage.add_theme_font_size_override("font_size",22);canvas.add_child(stage)
	DirAccess.make_dir_recursive_absolute("/tmp/ordo-coal-shield-frames")
	RenderingServer.render_loop_enabled=false
	for frame in (55 if "--still" in OS.get_cmdline_user_args() else 330):
		if frame>=70 and frame<145:
			sim.phase="enemy";sim.phase_time=float(frame-70)/60
			for e in sim.enemies:e.attack="slam";e.fired=frame>=125
		if frame==155:
			for actor in game.arena.actors.values():actor.get_node("Rig").hit(1.5);actor.get_node("Face").react("surprise",.5)
		if frame==220:
			for e in sim.enemies:
				e.vx=2.6;e.vz=0.0;sim.hit_enemy(e,100,"capture-%d"%int(e.id),sim.pos(e))
			sim.enemies.clear()
		game.arena.render_state(sim,1.0/60)
		await process_frame;RenderingServer.force_draw(true,1.0/60)
		root.get_texture().get_image().save_jpg("/tmp/ordo-coal-shield-frames/%05d.jpg"%frame,.95)
		if frame in [35,110,165,236]:root.get_texture().get_image().save_png("res://work/enemy-motion/coal-shield-v3-%03d.png"%frame)
	game.queue_free();await process_frame;print("COAL AND SHIELD CAPTURE COMPLETE");quit()
