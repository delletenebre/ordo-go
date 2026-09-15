extends SceneTree
const Main=preload("res://tests/support/test_main.gd")
var game
func _init()->void:call_deferred("run")
func run()->void:
	DirAccess.make_dir_recursive_absolute("res://work/enemy-motion")
	root.content_scale_size=Vector2i(1440,960);root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	game=Main.new();root.add_child(game);await process_frame
	game.start_local(2,1);game.set_process(false);game.arena.muted=true;game.hud.hide()
	var sim=game.sim;sim.enemies.clear();sim.events.clear();sim.stones.clear();sim.pickups.clear()
	for i in 2:
		sim.spawn("weaver",0);var e:Dictionary=sim.enemies[-1];e.r=.74;sim.place(e,Vector2(-1.38+i*2.76,3.55))
	sim.begin_plan();sim.events.clear();game.arena.last_event=sim.event_id
	for p in sim.players:sim.place(p,Vector2(-9,9))
	var camera:Camera3D=game.arena.camera
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=5.65;camera.near=.1
	game.arena.camera_frame=Vector2.ZERO;game.arena.camera_pan=Vector2.ZERO
	var target:=Vector3(0,.80,3.55);camera.position=target+Vector3(0,1.6,6);camera.look_at(target)
	game.arena.render_state(sim,0)
	for stone in game.arena.rune_stones:stone.hide()
	var canvas:=CanvasLayer.new();root.add_child(canvas)
	var stage:=Label.new();stage.text="ВОЙЛОЧНЫЙ БОСС · КАДР ИЗ ИГРЫ";stage.position=Vector2(32,28);stage.add_theme_font_size_override("font_size",22);canvas.add_child(stage)
	var phase_label:=Label.new();phase_label.position=Vector2(800,765);phase_label.add_theme_font_size_override("font_size",22);canvas.add_child(phase_label)
	var label:=Label.new();label.text="ПЛОТНАЯ ШЕРСТЬ";label.position=Vector2(160,765);label.add_theme_font_size_override("font_size",22);canvas.add_child(label)
	DirAccess.make_dir_recursive_absolute("/tmp/ordo-boss-material-frames")
	RenderingServer.render_loop_enabled=false
	for frame in (180 if "--still" in OS.get_cmdline_user_args() else 360):
		if frame==30:sim.hit_enemy(sim.enemies[1],int(sim.enemies[1].hp)-int(sim.enemies[1].phase_hp),"ignite",sim.pos(sim.enemies[1]))
		if frame==90:sim.begin_plan()
		if frame==270:sim.Bosses.frost_strike(sim,sim.pos(sim.enemies[1]))
		phase_label.text="ТЛЕНИЕ" if frame<90 else ("ГОРЯЩАЯ ФАЗА" if frame<270 else "ПОСЛЕ МОРОЗНОГО УДАРА")
		sim.phase_time+=1.0/60;sim.rune_drops.clear();sim.pickups.clear()
		game.arena.render_state(sim,1.0/60)
		await process_frame;RenderingServer.force_draw(true,1.0/60)
		root.get_texture().get_image().save_jpg("/tmp/ordo-boss-material-frames/%05d.jpg"%frame,.95)
		if frame in [15,65,150,210,330]:root.get_texture().get_image().save_png("res://work/enemy-motion/felt-boss-%03d.png"%frame)
	game.queue_free();await process_frame;print("FELT BOSS CAPTURE COMPLETE");quit()
