extends SceneTree
const Main = preload("res://tests/support/test_main.gd")
var game
func _init() -> void: call_deferred("run")
func run() -> void:
	var narrow := "--narrow" in OS.get_cmdline_user_args()
	var out := "res://work/fire-pickup"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	DirAccess.make_dir_recursive_absolute("/tmp/ordo-fire-frames")
	root.size=Vector2i(900,1000) if narrow else Vector2i(1440,900)
	root.content_scale_size=root.size; root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	game=Main.new(); root.add_child(game); await process_frame
	game.start_local(1,1); game.set_process(false); game.arena.muted=true; game.hud.hide()
	var sim=game.sim; sim.stones.clear(); sim.enemies.clear(); sim.pickups.clear(); sim.events.clear()
	sim.spawn("brute",0); sim.place(sim.enemies[0],Vector2(-4,-4))
	var player: Dictionary=sim.players[0]
	sim.place(player,Vector2(-1.7,3)); player.ready=true
	sim.pickups=[{"id":998,"kind":"element","element":"fire","x":-.5,"z":3.0}]
	sim.phase="resolve"
	var camera: Camera3D=game.arena.camera
	camera.near=.1; camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=5.8 if not narrow else 4.8
	var target:=Vector3(0,.35,3)
	camera.position=target+Vector3(0,3.8,6.0); camera.look_at(target)
	game.arena.camera_frame=Vector2.ZERO; game.arena.camera_pan=Vector2.ZERO
	game.arena.last_event=sim.event_id
	for stone in game.arena.rune_stones: stone.hide()
	RenderingServer.render_loop_enabled=false
	for frame in 300:
		if frame==40: sim.velocity(player,Vector2(4.5,0))
		if frame>=40 and frame<105 or frame>=170 and frame<240:
			sim.move_bodies(1.0/120,true); sim.move_bodies(1.0/120,true)
		if frame==110:
			assert(sim.Effects.burning(sim,player),"Real pickup lights player")
			sim.end_turn()
			assert(int(player.hp)==4 and sim.Effects.burning(sim,player),"No pickup-turn damage; next plan retains fire")
		if frame==170:
			player.ready=true; player.angle=PI; player.power=.28; sim.launch()
			assert(sim.Effects.burning(sim,player),"Next throw carries collected flame")
		if frame==240:
			sim.Effects.end_turn(sim)
			assert(int(player.hp)==3 and not sim.Effects.burning(sim,player),"One deferred tick after next throw")
		game.arena.render_state(sim,1.0/60); await process_frame
		RenderingServer.force_draw(true,1.0/60)
		if not narrow: root.get_texture().get_image().save_jpg("/tmp/ordo-fire-frames/%05d.jpg"%frame,.94)
		if frame in [30,56,90,145,200,285]:
			root.get_texture().get_image().save_png(out+"/%s-%03d.png"%["narrow" if narrow else "fire",frame])
	assert(game.arena.element_visuals.marks.get("actor:0")==null,"Expired flame releases its visual nodes")
	print("FIRE PICKUP CAPTURE: deferred damage, next throw, fade verified; narrow=",narrow)
	game.queue_free(); await process_frame; quit()
