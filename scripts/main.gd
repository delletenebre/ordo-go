extends Node3D
const Simulation = preload("res://scripts/simulation.gd")
const Arena = preload("res://scripts/arena.gd")
const Hud = preload("res://scripts/hud.gd")
const Network = preload("res://scripts/network.gd")
var sim = Simulation.new()
var arena
var hud
var net
var in_menu := true
var online := false
var local_slots: Array = [0]
var selected := 0
var relay_url := "ws://127.0.0.1:8787"
var accumulator := 0.0
var net_clock := 0.0
var aim_clock := 0.0
var reward_choices: Dictionary = {}
var demo := false
var capture_path := ""
var capture_phase := ""
var preview_wave := 0
var preview_reward := false
var capture_time := 0.0
var command_count := 0

func _ready() -> void:
	get_tree().auto_accept_quit = false
	load_settings()
	arena = Arena.new(); add_child(arena)
	net = Network.new(); add_child(net); net.message.connect(on_network); net.connection_error.connect(on_error)
	var layer := CanvasLayer.new(); add_child(layer)
	hud = Hud.new(); hud.game = self; layer.add_child(hud)
	sim.start(4, 1)
	for arg in OS.get_cmdline_user_args():
		if arg == "--demo": demo = true
		if arg == "--preview-reward": preview_reward = true
		if arg.begins_with("--capture-phase="): capture_phase = arg.trim_prefix("--capture-phase=")
		if arg.begins_with("--preview-wave="): preview_wave = int(arg.trim_prefix("--preview-wave="))
		if arg.begins_with("--capture="): capture_path = arg.trim_prefix("--capture=")
		if arg.begins_with("--relay="): relay_url = arg.trim_prefix("--relay="); hud.url_field.text = relay_url
	if demo: start_local(4, 1)
	if preview_wave > 0:
		sim.wave = clampi(preview_wave, 1, 9) - 1; sim.next_wave()
	if preview_reward: sim.begin_reward()
	get_window().title = "ORDO · Хранители очага"

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") == OK: relay_url = config.get_value("network", "relay_url", relay_url)

func save_settings() -> void:
	var config := ConfigFile.new(); config.set_value("network", "relay_url", relay_url); config.save("user://settings.cfg")

func start_local(count: int, mode: int) -> void:
	net.disconnect_room(); online = false; local_slots = []
	for i in count: local_slots.append(i)
	start_game(count, mode)

func start_game(count: int, mode: int) -> void:
	selected = int(local_slots[0]); sim.start(count, mode, int(Time.get_unix_time_from_system()))
	in_menu = false; accumulator = 0.0; net_clock = 0.0; reward_choices.clear()
	arena.last_event = 0; hud.seen = 0; hud.pulse_events.clear(); hud.trails.clear(); hud.help_open = false
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null: focus.release_focus()

func return_menu() -> void:
	net.disconnect_room(); online = false; in_menu = true
	hud.start_button.hide(); hud.room_label.text = ""; hud.message_label.text = ""
	hud.local_button.grab_focus()

func _process(dt: float) -> void:
	capture_time += dt
	if not in_menu:
		if not online or net.is_host:
			accumulator += minf(dt, 0.1)
			while accumulator >= Simulation.STEP:
				sim.tick(Simulation.STEP); accumulator -= Simulation.STEP
			if online:
				net_clock += dt
				if net_clock >= 0.05:
					net_clock = 0.0; net.send({"type": "snapshot", "state": sim.snapshot()})
		aim_clock += dt
		if aim_clock >= 0.05:
			read_continuous_input(aim_clock); aim_clock = 0.0
		if demo: demo_play()
	arena.render_state(sim, dt, online and not net.is_host)
	if capture_path != "" and capture_time > 2.0 and (capture_phase == "" or (sim.phase == capture_phase and sim.phase_time > 0.18)):
		var path := capture_path; capture_path = ""
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(path)
		print("CAPTURE ", path)
		arena.stop_audio()
		await get_tree().create_timer(0.15).timeout
		get_tree().quit()

func send_command(slot: int, data: Dictionary) -> void:
	if not local_slots.has(slot): return
	data.turn = sim.turn
	command_count += 1
	if online and not net.is_host:
		if data.action == "aim": sim.command(slot, data)
		net.send({"type": "command", "slot": slot, "data": data})
	else: sim.command(slot, data)

func read_continuous_input(dt: float) -> void:
	if sim.phase != "plan" or hud.help_open or selected >= sim.players.size(): return
	var p: Dictionary = sim.players[selected]
	var turn_axis := float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
	var power_axis := float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)) - float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))
	if absf(turn_axis) + absf(power_axis) > 0:
		send_command(selected, {"action": "aim", "angle": float(p.angle) + turn_axis * dt * 2.3, "power": float(p.power) + power_axis * dt * 0.7})
	for device in Input.get_connected_joypads():
		var slot := device_slot(device)
		if slot < 0 or slot >= sim.players.size(): continue
		var direction := Vector2(Input.get_joy_axis(device, JOY_AXIS_LEFT_X), Input.get_joy_axis(device, JOY_AXIS_LEFT_Y))
		var trigger := Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT)
		var player: Dictionary = sim.players[slot]
		if direction.length() > 0.2:
			selected = slot
			send_command(slot, {"action": "aim", "angle": direction.angle(), "power": clampf(trigger, 0.15, 1.0) if trigger > 0.05 else float(player.power)})
		elif trigger > 0.05: send_command(slot, {"action": "aim", "angle": float(player.angle), "power": trigger})

func device_slot(device: int) -> int:
	var devices := Input.get_connected_joypads()
	var index := devices.find(device)
	if index < 0: return -1
	# When pads are fewer than seats, keyboard takes the first seat.
	if devices.size() < local_slots.size(): index += 1
	return int(local_slots[index]) if index < local_slots.size() else -1

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
			get_viewport().set_input_as_handled(); return
		if in_menu: return
		match event.physical_keycode:
			KEY_H: hud.help_open = not hud.help_open
			KEY_M: arena.muted = not arena.muted
			KEY_ESCAPE:
				if hud.help_open: hud.help_open = false
				else: return_menu()
			KEY_TAB:
				selected = int(local_slots[(local_slots.find(selected) + 1) % local_slots.size()])
			KEY_SPACE: send_command(selected, {"action": "ready"})
			KEY_BACKSPACE: send_command(selected, {"action": "cancel"})
			KEY_Q: send_command(selected, {"action": "ability"})
			KEY_1, KEY_2, KEY_3: send_command(selected, {"action": "reward", "choice": event.physical_keycode - KEY_1})
			KEY_ENTER:
				if sim.phase in ["win", "lose"]: return_menu()
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed and not in_menu:
		var slot := device_slot(event.device)
		if slot < 0: return
		selected = slot
		if sim.phase in ["win", "lose"] and event.button_index == JOY_BUTTON_A: return_menu(); return
		if sim.phase == "reward":
			var choice: int = int(reward_choices.get(slot, 0))
			if event.button_index == JOY_BUTTON_DPAD_LEFT: choice = posmod(choice - 1, 3)
			if event.button_index == JOY_BUTTON_DPAD_RIGHT: choice = posmod(choice + 1, 3)
			reward_choices[slot] = choice; hud.reward_choice = choice
			if event.button_index == JOY_BUTTON_A: send_command(slot, {"action": "reward", "choice": choice})
		else:
			match event.button_index:
				JOY_BUTTON_A: send_command(slot, {"action": "ready"})
				JOY_BUTTON_B: send_command(slot, {"action": "cancel"})
				JOY_BUTTON_X: send_command(slot, {"action": "ability"})
				JOY_BUTTON_START: hud.help_open = not hud.help_open
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and not in_menu:
		if sim.phase == "reward" and event.button_index == MOUSE_BUTTON_LEFT:
			var point: Vector2 = event.position / hud.scale_factor
			for i in 3:
				if Rect2(290 + i * 350, 395, 320, 240).has_point(point): send_command(selected, {"action": "reward", "choice": i})
		elif sim.phase == "plan" and not hud.help_open:
			if event.button_index == MOUSE_BUTTON_LEFT:
				var offset: Vector2 = arena.floor_point(event.position) - sim.pos(sim.players[selected])
				send_command(selected, {"action": "aim", "angle": offset.angle(), "power": clampf(offset.length() / 4.0, 0.15, 1.0)})
			if event.button_index == MOUSE_BUTTON_RIGHT: send_command(selected, {"action": "ability"})

func on_network(data: Dictionary) -> void:
	match data.get("type", ""):
		"joined":
			local_slots = net.slots; selected = int(local_slots[0]); hud.update_lobby()
		"slots": local_slots = net.slots; selected = int(local_slots[0])
		"roster": hud.update_lobby()
		"start":
			online = true; start_game(int(data.count), int(data.difficulty))
		"command":
			if online and net.is_host: sim.command(int(data.slot), data.data)
		"snapshot":
			if online and not net.is_host: sim.restore(data.state)
		"ended":
			var reason: String = data.message
			return_menu(); hud.message_label.text = reason

func on_error(reason: String) -> void:
	if not in_menu and online:
		return_menu()
	hud.message_label.text = reason

func demo_play() -> void:
	if capture_path != "" and capture_phase == "": return
	if sim.phase == "plan" and sim.phase_time > 1.2:
		for p in sim.players:
			if p.hp <= 0 or p.ready: continue
			var nearest := Vector2.ZERO; var distance := 999.0
			for enemy in sim.enemies:
				var d: float = sim.pos(p).distance_to(sim.pos(enemy))
				if d < distance: distance = d; nearest = sim.pos(enemy)
			sim.command(p.id, {"action": "aim", "angle": (nearest - sim.pos(p)).angle(), "power": 0.9})
			if p.charges > 0 and not p.ability: sim.command(p.id, {"action": "ability"})
			sim.command(p.id, {"action": "ready"})
	elif sim.phase == "reward":
		for p in sim.players:
			if not p.reward: sim.choose_reward(p.id, 0)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if arena != null: arena.stop_audio()
		if net != null: net.disconnect_room()
		await get_tree().create_timer(0.15).timeout
		get_tree().quit()
