extends SceneTree
const Main = preload("res://tests/support/test_main.gd")
var game

func _init() -> void: call_deferred("run")

func run() -> void:
	var narrow := "--narrow" in OS.get_cmdline_user_args()
	var field := "--field" in OS.get_cmdline_user_args()
	var linger := "--linger" in OS.get_cmdline_user_args()
	var move_frame := 120 if linger else 45
	var out := "res://work/field-effects"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	DirAccess.make_dir_recursive_absolute("/tmp/ordo-steam-frames")
	root.size=Vector2i(900,1000) if narrow else Vector2i(1440,900)
	root.content_scale_size=root.size; root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	game=Main.new(); root.add_child(game); await process_frame
	game.start_local(2,1); game.set_process(false); game.arena.muted=true; game.hud.hide()
	var sim=game.sim; sim.stones.clear(); sim.enemies.clear(); sim.pickups.clear(); sim.events.clear()
	sim.place(sim.players[0],Vector2(-1.3,3)); sim.place(sim.players[1],Vector2(1.3,3))
	sim.players[0].statuses={"frost":1}; sim.players[1].statuses={"burn":1}
	sim.phase="resolve"
	var camera: Camera3D=game.arena.camera
	camera.near=.1; camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=5.8 if not narrow else 5.0
	var target:=Vector3(0,.35,3)
	camera.position=target+Vector3(0,3.8,6.0); camera.look_at(target)
	game.arena.camera_frame=Vector2.ZERO; game.arena.camera_pan=Vector2.ZERO
	game.arena.last_event=sim.event_id
	for stone in game.arena.rune_stones: stone.hide()
	if field:
		sim.players[0].statuses.clear(); sim.players[1].statuses.clear()
		sim.pickups=[{"id":998,"kind":"element","element":"fire","x":-.6,"z":3.0},{"id":999,"kind":"element","element":"frost","x":.6,"z":3.0}]
	var reaction_frame := -1
	var peak := 0
	var peak_haze := 0
	RenderingServer.render_loop_enabled=false
	for frame in (140 if field else (360 if linger else 250)):
		if frame==move_frame and not field:
			sim.velocity(sim.players[0],Vector2(3.8,0)); sim.velocity(sim.players[1],Vector2(-3.8,0))
		if frame>=move_frame and not field:
			sim.move_bodies(1.0/120,true); sim.move_bodies(1.0/120,true)
		if reaction_frame<0 and sim.events.any(func(event):return event.kind=="steam"): reaction_frame=frame
		game.arena.render_state(sim,1.0/60); await process_frame
		peak=maxi(peak,game.arena.steam.active_count())
		peak_haze=maxi(peak_haze,game.arena.element_visuals.haze.active_count())
		RenderingServer.force_draw(true,1.0/60)
		if not narrow and not field: root.get_texture().get_image().save_jpg("/tmp/ordo-steam-frames/%05d.jpg"%frame,.94)
		if frame==35 or (linger and frame==105) or (reaction_frame>=0 and frame in [reaction_frame+8,reaction_frame+24,reaction_frame+60]) or (field and frame in [79,139]):
			root.get_texture().get_image().save_png(out+"/%s-%03d.png"%["sources" if field else ("narrow" if narrow else "steam"),frame])
	assert(peak_haze>0,"Active elements emit atmospheric wisps")
	assert(game.arena.element_visuals.haze.dropped==0,"Atmospheric pool stays within capacity")
	if not field:
		assert(game.arena.element_visuals.haze.active_count()==0,"Cold vapor and warm smoke finish after quenching")
		assert(reaction_frame>=0,"Capture must exercise a real elemental collision")
		assert(sim.events.filter(func(event):return event.kind=="steam").size()==1,"One collision produces one steam reaction")
		assert(not sim.Effects.cold(sim.players[0]) and not sim.Effects.burning(sim,sim.players[1]))
		assert(game.arena.steam.active_count()==0 and game.arena.steam.bursts.is_empty(),"Steam dissipates and returns to its pool")
	print("ELEMENT CAPTURE: field=",field," narrow=",narrow," reaction_frame=",reaction_frame," peak_haze=",peak_haze," peak_steam=",peak," dropped=",game.arena.steam.dropped)
	preload("res://scripts/audio.gd").steam_sound().save_to_wav("/tmp/ordo-steam-hiss.wav")
	game.queue_free(); await process_frame; quit()
