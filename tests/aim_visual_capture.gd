extends SceneTree

# Deterministic real-render check: four team colors, enemy intent, contacts and a bounce.
const Main = preload("res://scripts/main.gd")

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var output := "res://work/aim-reference/aim-colors.png"
	var scenario := "colors"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--case="): scenario = arg.trim_prefix("--case=")
	var game := Main.new()
	root.add_child(game)
	await process_frame
	game.start_local(4,1)
	game.set_process(false)
	game.sim.enemies.clear(); game.sim.events.clear()
	var starts := [Vector2(-2.5,2.8),Vector2(2.8,2.5),Vector2(2.5,-2.8),Vector2(-2.8,-2.5)]
	var targets := [Vector2(1.4,2.8),Vector2(2.8,-1.4),Vector2(-1.4,-2.8),Vector2(-2.8,1.4)]
	for i in 4:
		var p: Dictionary = game.sim.players[i]
		game.sim.place(p,starts[i]); p.angle = (targets[i]-starts[i]).angle(); p.power = 0.8
		game.sim.spawn("coal",0)
		var e: Dictionary = game.sim.enemies[-1]
		game.sim.place(e,targets[i]); e.tx=0.0; e.tz=0.0
	if scenario == "bounce":
		game.sim.place(game.sim.players[0],Vector2(-2.5,3.8))
		game.sim.players[0].angle = -1.0
	elif scenario == "close":
		game.sim.place(game.sim.enemies[0],starts[0]+Vector2(0.78,0))
	elif scenario == "stop":
		game.sim.enemies.clear()
		for p in game.sim.players: p.power=0.15
	game.hud.seen = game.sim.event_id; game.hud.pulse_events.clear()
	for i in 24:
		game.arena.render_state(game.sim,1.0/60.0)
		await process_frame
	game.hud.set_process(false); game.hud.clock=0.25; game.hud.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output)
	print("AIM CAPTURE: ",scenario," ",output)
	game.arena.stop_audio(); game.queue_free()
	await process_frame
	quit()
