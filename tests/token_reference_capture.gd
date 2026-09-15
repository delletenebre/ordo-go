extends SceneTree
const Main=preload("res://tests/support/test_main.gd")
func _init()->void:call_deferred("run")
func run()->void:
	var game=Main.new();root.add_child(game);await process_frame
	game.start_local(4,1);game.set_process(false);game.arena.stop_audio();game.hud.hide()
	game.sim.enemies.clear();game.sim.pickups.clear()
	for i in 4:game.sim.place(game.sim.players[i],Vector2((i-1.5)*1.15,3.3))
	game.arena.camera_frame=Vector2.ZERO
	var target:=Vector3(0,.12,3.3)
	var camera:Camera3D=game.arena.camera
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.near=.1;camera.size=5.1
	camera.position=target+Vector3(0,4.4,3.1);camera.look_at(target)
	for i in 45:game.arena.render_state(game.sim,1.0/60);await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://work/token-medallions/lineup.png")
	game.arena.stop_audio();game.queue_free();await process_frame;quit()
