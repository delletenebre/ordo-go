extends SceneTree
const Main = preload("res://tests/support/test_main.gd")
const Motion = preload("res://scripts/death_motion.gd")
var game

func _init() -> void: call_deferred("run")

func run() -> void:
	var output := "res://work/death-motion"
	var narrow := false
	var frames_dir := ""
	var capture_index := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg == "--narrow": narrow = true
		if arg.begins_with("--frames="): frames_dir = arg.trim_prefix("--frames=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.content_scale_size = Vector2i(540, 900) if narrow else Vector2i(1280, 800)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	game = Main.new(); root.add_child(game); await process_frame
	if not frames_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(frames_dir)
		RenderingServer.render_loop_enabled = false
	game.start_local(1, 1); game.set_process(false); game.arena.muted = true; game.hud.hide()
	var label := Label.new(); label.position = Vector2(24, 24)
	label.add_theme_font_size_override("font_size", 22); root.add_child(label)
	var cases := [
		{"kind": "coal", "style": "flight", "speed": 13.0, "point": Vector2(3.1, 3.6), "dir": Vector2.RIGHT, "label": "Уголёк — сильный удар наружу"},
		{"kind": "moth", "style": "flutter", "speed": 13.0, "point": Vector2(3.1, 3.6), "dir": Vector2.RIGHT, "label": "Моль — лёгкое тело"},
		{"kind": "frost", "style": "air_split", "speed": 12.0, "point": Vector2(3.1, 3.6), "dir": Vector2.RIGHT, "label": "Иней — направленный раскол"},
		{"kind": "brute", "speed": 13.0, "point": Vector2(3.1, 3.6), "dir": Vector2.RIGHT, "label": "Камнелоб — тяжёлый перекат"},
		{"kind": "hopper", "style": "skip", "speed": 12.0, "point": Vector2(-3.1, 3.6), "dir": Vector2.RIGHT, "label": "Прыгун — отскоки"},
		{"kind": "coal", "speed": 4.0, "point": Vector2(4.45, 3.6), "dir": Vector2.RIGHT, "label": "Слабый удар — бортик удерживает"},
		{"kind": "coal", "speed": 12.0, "point": Vector2(3.1, 3.6), "dir": Vector2.LEFT, "label": "Удар внутрь — падение на поле"},
		{"kind": "ram", "speed": 13.0, "point": Vector2(3.1, 3.6), "dir": Vector2.RIGHT, "label": "Босс — тяжёлое обрушение"},
		{"kind": "coal", "style": "air_split", "speed": 13.0, "point": Vector2(3.1, 3.6), "dir": Vector2.RIGHT, "label": "Уголёк — раскол в полёте"},
		{"kind": "coal", "speed": 0.0, "point": Vector2(3.1, 3.6), "dir": Vector2.RIGHT, "label": "Без толчка — осыпание на месте"},
	]
	for index in cases.size():
		var scenario: Dictionary = cases[index]
		if narrow:
			# Use the near edge so portrait captures show the fall below the wall.
			scenario.point = Vector2(scenario.point).rotated(PI * 0.5)
			scenario.dir = Vector2(scenario.dir).rotated(PI * 0.5)
		var sim = game.sim
		game.arena.reset_presentation(); sim.start(1, 1, 42 + index)
		sim.enemies.clear(); sim.pickups.clear(); sim.stones.clear(); sim.events.clear()
		sim.spawn(scenario.kind, 0)
		var enemy: Dictionary = sim.enemies[0]; enemy.hp = 1
		sim.place(enemy, scenario.point)
		var player: Dictionary = sim.players[0]
		sim.place(player, Vector2(scenario.point) - Vector2(scenario.dir) * (float(player.r) + float(enemy.r) + 0.20))
		label.text = scenario.label
		if not narrow:
			var camera: Camera3D = game.arena.camera
			camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.near = 0.1; camera.size = 12.0
			camera.position = Vector3(6.0, 9.0, 13.0); camera.look_at(Vector3(5.5, 0, 3.2))
			if scenario.kind == "hopper": camera.position.x -= 4; camera.look_at(Vector3(1.5, 0, 3.2))
		var styles: Dictionary = {}; var escaped := false; var pieces_outside := false
		var selected := false
		for frame in 165:
			if frame == 24:
				sim.velocity(player, Vector2(scenario.dir) * float(scenario.speed))
				if float(scenario.speed) == 0: sim.hit_enemy(enemy, 1, "capture", sim.pos(enemy))
			if frame >= 24:
				for substep in 2: sim.move_bodies(1.0 / 120.0, true)
			# Pick a reproducible visual seed to show each eligible variant in this
			# gallery. The actual collision, velocity and death still come from Sim.
			if not selected and scenario.has("style"):
				for event in sim.events:
					if event.kind != "death": continue
					for attempt in 100:
						if Motion.create(event).style == scenario.style: break
						event.id += 1
					sim.event_id = maxi(sim.event_id, int(event.id)); selected = true
			game.arena.render_state(sim, 1.0 / 60.0)
			for state in game.arena.death_motions.values():
				styles[state.style] = true
				if state.outside: escaped = true
			for piece in game.arena.debris.pieces:
				if float(piece.life) > 0 and Vector2(piece.body.position.x, piece.body.position.z).length() > 7.0: pieces_outside = true
			await process_frame
			if not frames_dir.is_empty():
				RenderingServer.force_draw(true, 1.0 / 60.0)
				root.get_texture().get_image().save_jpg(frames_dir + "/%05d.jpg" % capture_index, 0.94)
				capture_index += 1
			if frame in [31, 36, 40, 45, 65, 95]:
				# Read the completed previous frame. frame_post_draw can be suppressed
				# for an unfocused window while Movie Maker continues writing frames.
				root.get_texture().get_image().save_png(output + "/%02d-%s-%03d.png" % [index, scenario.kind, frame])
		print("DEATH CAPTURE ", scenario.kind, " speed=", scenario.speed, " styles=", styles.keys(), " body_outside=", escaped, " fragments_outside=", pieces_outside)
	game.queue_free(); await process_frame; quit()
