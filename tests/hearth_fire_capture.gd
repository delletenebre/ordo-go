extends SceneTree
const Main = preload("res://scripts/main.gd")

func _init() -> void:
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://work/hearth-fire")
	var portrait := "--portrait" in OS.get_cmdline_user_args()
	if portrait:
		root.size = Vector2i(540, 900)
		root.content_scale_size = Vector2i(540, 900)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	var game = Main.new()
	root.add_child(game)
	await process_frame
	game.start_local(4, 1)
	game.set_process(false)
	game.arena.stop_audio()
	var camera: Camera3D = game.arena.camera
	var camera_transform := camera.transform
	for frame in 300:
		game.arena.render_state(game.sim, 1.0 / 60.0)
		if frame < 240 and not portrait:
			game.hud.hide()
			camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			camera.near = 0.1
			camera.size = 4.5
			camera.position = Vector3(0, 3.7, 5.0)
			camera.look_at(Vector3(0, 0.9, 0))
			camera.h_offset = 0
			camera.v_offset = 0
		else:
			game.hud.show()
			camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			camera.transform = camera_transform
		await process_frame
		if frame in [60, 120, 200, 299]:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://work/hearth-fire/%s-%d.png" % ["portrait" if portrait else "flame", frame])
	game.sim.fire = 0
	game.arena.render_state(game.sim, 1.0 / 60.0)
	assert(not game.arena.flame_root.visible)
	assert(game.arena.fire_light.light_energy == 0.0)
	game.sim.fire = 1
	for frame in 120:
		game.arena.flame_root.step(1.0 / 60.0, 1.0 / float(game.sim.max_fire))
	assert(game.arena.flame_root.visible)
	assert(game.arena.flame_root.scale.y < 0.75)
	print("HEARTH FIRE: animation captured; extinguish, recovery and low-fire scale passed")
	game.arena.stop_audio()
	game.queue_free()
	await process_frame
	quit()
