extends Node3D
const Simulation = preload("res://scripts/simulation.gd")
const Arena = preload("res://scripts/arena.gd")
const Hud = preload("res://scripts/hud.gd")
const ControllerHub = preload("res://scripts/controller_hub.gd")
const Network = preload("res://scripts/network.gd")
const ServerAddress = preload("res://scripts/server_address.gd")
const Avatars = preload("res://scripts/avatar_catalog.gd")
var sim = Simulation.new()
var arena
var hud
var net
var controller_hub
var auto_local_server := true
var phone_slots: Dictionary = {}
var controller_clock := 0.0
var local_server_address_applied := false
var in_menu := true
var online := false
var local_slots: Array = [0]
var selected := 0
var relay_url := "purrsuit.iuk.edu.kg"
var accumulator := 0.0
var net_clock := 0.0
var aim_clock := 0.0
const CHARGE_SECONDS := 0.6
const MIN_POWER := 0.15
const PAD_DPAD_TURN_SPEED := 1.5 # Fine adjustment relative to the current aim.
const PAD_STICK_DEADZONE := 0.25
const PAD_STICK_TURN_SPEED := 3.0 # Radians per second at full deflection.
# Each held button owns its slot until release, independently of HUD selection.
var shot_charges: Dictionary = {}
var spin_buttons: Dictionary = {}
var pad_aim_axes: Dictionary = {}
var pad_aim_buttons: Dictionary = {}
var reward_choices: Dictionary = {}
var demo := false
var capture_path := ""
var capture_phase := ""
var preview_wave := 0
var preview_reward := false
var capture_time := 0.0
var command_count := 0
var pad_slots: Dictionary = {}
var keyboard_seat := false
var run_seats: Array = []
var roster_known: Dictionary = {}
var pad_notice := ""
var pad_notice_time := 0.0
var menu_axis_time := 0.0
var local_avatars: Array = ["manas","kanykei","ilbirs","bugu"]

func _ready() -> void:
	get_tree().auto_accept_quit = false
	Input.joy_connection_changed.connect(on_pad_connection)
	load_settings()
	arena = Arena.new(); add_child(arena)
	net = Network.new(); add_child(net); net.message.connect(on_network); net.connection_error.connect(on_error)
	var layer := CanvasLayer.new(); add_child(layer)
	hud = Hud.new(); hud.game = self; layer.add_child(hud)
	if auto_local_server:
		controller_hub = ControllerHub.new(); add_child(controller_hub)
		controller_hub.changed.connect(on_controller_roster)
		controller_hub.command_received.connect(on_phone_command)
		controller_hub.start()
	sim.start(4, 1)
	for arg in OS.get_cmdline_user_args():
		if arg == "--demo": demo = true
		if arg == "--preview-reward": preview_reward = true
		if arg.begins_with("--capture-phase="): capture_phase = arg.trim_prefix("--capture-phase=")
		if arg.begins_with("--preview-wave="): preview_wave = int(arg.trim_prefix("--preview-wave="))
		if arg.begins_with("--capture="): capture_path = arg.trim_prefix("--capture=")
		if arg.begins_with("--relay="): relay_url = ServerAddress.normalize(arg.trim_prefix("--relay=")); hud.url_field.text = relay_url
	if demo: start_local(4, 1)
	if preview_wave > 0:
		sim.wave = clampi(preview_wave, 1, 9) - 1; sim.next_wave()
	if preview_reward: sim.begin_reward()
	get_window().title = "ORDO · Хранители очага"

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		relay_url = ServerAddress.normalize(str(config.get_value("network", "relay_url", relay_url)))
		var saved = config.get_value("players","avatars",local_avatars)
		if saved is Array and saved.size()==4:
			for i in 4:
				if Avatars.IDS.has(saved[i]): local_avatars[i]=saved[i]

func save_settings() -> void:
	relay_url = ServerAddress.normalize(relay_url)
	var config := ConfigFile.new(); config.set_value("network", "relay_url", relay_url)
	config.set_value("players","avatars",local_avatars); config.save("user://settings.cfg")

func start_local(count: int, mode: int) -> void:
	net.disconnect_room(); online = false; local_slots = []
	for i in count: local_slots.append(i)
	start_game(count, mode)

func start_game(count: int, mode: int) -> void:
	clear_charges(); spin_buttons.clear(); pad_aim_axes.clear(); pad_aim_buttons.clear(); aim_clock = 0.0
	run_seats=active_local_seats().slice(0,local_slots.size())
	selected = int(local_slots[0]) if not local_slots.is_empty() else 0; sim.start(count, mode)
	for player in sim.players:
		var id: int=int(player.id)
		player.avatar = avatar_for_player(id) if net.room!="" else local_avatars[int(run_seats[id]) if id<run_seats.size() else id]
	in_menu = false
	if controller_hub != null: controller_hub.set_playing(true)
	accumulator = 0.0; net_clock = 0.0; reward_choices.clear()
	arena.reset_presentation(); hud.seen = 0; hud.pulse_events.clear(); hud.trails.clear(); hud.help_open = false
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null: focus.release_focus()

func return_menu() -> void:
	if net.connected and net.room != "":
		if net.is_host: net.send({"type":"lobby"})
		else:
			pad_notice = "ЖДЁМ ВЕДУЩЕГО · КОМНАТА СОХРАНЕНА"; pad_notice_time = 4.0
		return
	leave_room()

func enter_lobby() -> void:
	online = false; in_menu = true; run_seats.clear(); reward_choices.clear()
	clear_charges(); spin_buttons.clear(); pad_aim_axes.clear(); pad_aim_buttons.clear()
	if controller_hub != null: controller_hub.set_playing(false)
	hud.help_open = false
	hud.game_menu.show_screen("lobby"); hud.update_lobby()
	sync_lobby_seats()

func leave_room() -> void:
	clear_charges(); spin_buttons.clear(); pad_aim_axes.clear(); pad_aim_buttons.clear()
	net.disconnect_room(); online = false; in_menu = true; roster_known.clear()
	if controller_hub != null: controller_hub.set_playing(false)
	hud.start_button.hide(); hud.room_label.text = ""; hud.message_label.text = ""
	hud.game_menu.show_screen("home")
	hud.local_button.grab_focus()

func _process(dt: float) -> void:
	capture_time += dt
	pad_notice_time = maxf(0.0,pad_notice_time-dt)
	menu_axis_time = maxf(0.0,menu_axis_time-dt)
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
		if not online or aim_clock >= 0.05:
			read_continuous_input(aim_clock); aim_clock = 0.0
		if demo: demo_play()
		controller_clock += dt
		if controller_hub != null and controller_clock >= .05:
			controller_clock = 0.0
			var mapping: Dictionary = {}
			for slot in phone_slots:
				var index := run_seats.find(phone_slots[slot])
				if index >= 0 and index < local_slots.size(): mapping[str(slot)] = int(local_slots[index])
			controller_hub.publish(sim.snapshot(), mapping)
	arena.render_state(sim, dt, online and not net.is_host)
	arena.update_audio(dt,in_menu,sim)
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
	# Relay aim messages are complete, even when the local control changes one field.
	if data.action == "aim" and slot < sim.players.size():
		var player: Dictionary = sim.players[slot]
		data.angle = data.get("angle", player.angle)
		data.power = data.get("power", player.power)
		data.spin = data.get("spin", player.get("spin", 0.0))
		data.charging = data.get("charging", local_charge_active(slot))
	command_count += 1
	if data.action == "reward_focus":
		apply_reward_focus(slot, data)
		if online and not net.is_host: net.send({"type":"command", "slot":slot, "data":data})
		return
	if online and not net.is_host:
		if data.action == "aim": sim.command(slot, data)
		net.send({"type": "command", "slot": slot, "data": data})
	else: sim.command(slot, data)

func apply_reward_focus(slot: int, data: Dictionary) -> void:
	if sim.phase != "reward" or int(data.get("turn", -1)) != sim.turn or slot < 0 or slot >= sim.players.size(): return
	var choice := int(data.get("choice", -1))
	if choice < 0 or choice >= sim.reward_options.size(): return
	reward_choices[slot] = choice
	selected = slot

func charge_valid(charge: Dictionary) -> bool:
	var slot: int = charge.slot
	return not in_menu and not hud.help_open and sim.phase == "plan" and charge.turn == sim.turn and local_slots.has(slot) and slot < sim.players.size() and sim.players[slot].hp > 0 and not sim.players[slot].ready

func local_charge_active(slot: int) -> bool:
	for charge in shot_charges.values():
		if charge.slot == slot and charge_valid(charge): return true
	return false

# The HUD reads the replicated hold state as well as locally owned input.
func is_charging(slot: int) -> bool:
	if in_menu or sim.phase != "plan" or slot < 0 or slot >= sim.players.size(): return false
	var player: Dictionary = sim.players[slot]
	if player.hp <= 0 or player.ready or sim.Effects.frozen(sim, player): return false
	return local_charge_active(slot) or bool(player.get("charging", false))

func stop_charge(source: int) -> void:
	if not shot_charges.has(source): return
	var charge: Dictionary = shot_charges[source]
	shot_charges.erase(source)
	if charge_valid(charge): send_command(charge.slot, {"action":"aim", "charging":false})

func clear_charges() -> void:
	for source in shot_charges.keys(): stop_charge(source)

func begin_charge(source: int, slot: int) -> void:
	if shot_charges.has(source) or local_charge_active(slot): return
	var charge := {"slot": slot, "turn": sim.turn, "elapsed": 0.0}
	if not charge_valid(charge): return
	shot_charges[source] = charge
	send_command(slot, {"action": "aim", "power": MIN_POWER})

func update_charges(dt: float) -> void:
	for source in shot_charges.keys():
		var charge: Dictionary = shot_charges[source]
		if not charge_valid(charge):
			shot_charges.erase(source); continue
		charge.elapsed = minf(CHARGE_SECONDS, float(charge.elapsed) + dt)
		send_command(charge.slot, {"action": "aim", "power": lerpf(MIN_POWER, 1.0, charge.elapsed / CHARGE_SECONDS)})

func release_charge(source: int) -> void:
	if not shot_charges.has(source): return
	var charge: Dictionary = shot_charges[source]
	shot_charges.erase(source)
	if not charge_valid(charge): return
	# Flush the last value before ready; both commands carry the same turn.
	send_command(charge.slot, {"action": "aim", "power": lerpf(MIN_POWER, 1.0, charge.elapsed / CHARGE_SECONDS)})
	send_command(charge.slot, {"action": "ready"})

func cancel_charge(slot: int) -> void:
	for source in spin_buttons.keys():
		if spin_buttons[source].slot == slot: spin_buttons.erase(source)
	for source in shot_charges.keys():
		if shot_charges[source].slot == slot: shot_charges.erase(source)
	send_command(slot, {"action": "cancel"})

func set_spin_button(source: int, slot: int, left: bool, pressed: bool) -> void:
	if not pressed and not spin_buttons.has(source): return
	var state: Dictionary = spin_buttons.get(source, {"slot": slot, "turn": sim.turn, "left": false, "right": false})
	state["left" if left else "right"] = pressed
	if not state.left and not state.right:
		spin_buttons.erase(source); return
	if not charge_valid(state): return
	spin_buttons[source] = state
	if state.left and state.right: send_command(state.slot, {"action": "aim", "spin": 0.0})
	elif pressed: adjust_spin(state.slot, -0.12 if left else 0.12)

func adjust_spin(slot: int, amount: float) -> void:
	send_command(slot, {"action": "aim", "spin": clampf(float(sim.players[slot].get("spin", 0.0)) + amount, -1.0, 1.0)})

func read_continuous_input(dt: float) -> void:
	update_charges(dt)
	for source in spin_buttons.keys():
		var state: Dictionary = spin_buttons[source]
		if not charge_valid(state):
			spin_buttons.erase(source); continue
		if state.left and state.right: continue
		adjust_spin(state.slot, (float(state.right)-float(state.left))*dt)

	if sim.phase != "plan" or hud.help_open: return
	var slot_for_keyboard := keyboard_slot()
	var turn_axis := float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
	if turn_axis != 0 and slot_for_keyboard >= 0:
		send_command(slot_for_keyboard, {"action": "aim", "angle": float(sim.players[slot_for_keyboard].angle) + turn_axis * dt * 2.3})
	for device in pad_slots:
		var slot := device_slot(device)
		if slot < 0 or slot >= sim.players.size(): continue
		# D-pad left/right rotate the existing aim, like the keyboard arrows.
		# Held D-pad buttons take priority over analog input, even when cancelled.
		if pad_aim_buttons.has(device):
			var turn := pad_aim_direction(device).x
			if turn != 0.0:
				selected = slot
				send_command(slot, {"action": "aim", "angle": float(sim.players[slot].angle) + turn * PAD_DPAD_TURN_SPEED * dt})
			continue
		var direction := pad_aim_direction(device)
		if direction.length() > PAD_STICK_DEADZONE:
			selected = slot
			var angle := smooth_stick_angle(float(sim.players[slot].angle), direction, dt)
			send_command(slot, {"action": "aim", "angle": angle})

func smooth_stick_angle(current: float, direction: Vector2, dt: float) -> float:
	# Rescale outside the radial deadzone; small deflections give fine control.
	var strength := clampf((direction.length() - PAD_STICK_DEADZONE) / (1.0 - PAD_STICK_DEADZONE), 0.0, 1.0)
	return rotate_toward(current, direction.angle(), PAD_STICK_TURN_SPEED * strength * strength * dt)

func track_pad_aim(event: InputEvent) -> void:
	if not pad_slots.has(event.device): return
	if event is InputEventJoypadMotion and event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		var direction: Vector2 = pad_aim_axes.get(event.device, Vector2.ZERO)
		if event.axis == JOY_AXIS_LEFT_X: direction.x = event.axis_value
		else: direction.y = event.axis_value
		pad_aim_axes[event.device] = direction
	elif event is InputEventJoypadButton and event.button_index in [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN]:
		var buttons: Dictionary = pad_aim_buttons.get(event.device, {})
		if event.pressed: buttons[event.button_index] = true
		else: buttons.erase(event.button_index)
		if buttons.is_empty(): pad_aim_buttons.erase(event.device)
		else: pad_aim_buttons[event.device] = buttons

func pad_aim_direction(device: int) -> Vector2:
	var buttons: Dictionary = pad_aim_buttons.get(device, {})
	if not buttons.is_empty():
		return Vector2(int(buttons.has(JOY_BUTTON_DPAD_RIGHT)) - int(buttons.has(JOY_BUTTON_DPAD_LEFT)), int(buttons.has(JOY_BUTTON_DPAD_DOWN)) - int(buttons.has(JOY_BUTTON_DPAD_UP)))
	return pad_aim_axes.get(device, Vector2.ZERO)

func native_local_seats() -> Array:
	var seats: Array = pad_slots.values().duplicate()
	if keyboard_seat and not seats.has(0):seats.append(0)
	seats.sort()
	return seats

func active_local_seats() -> Array:
	var seats := native_local_seats()
	for seat in phone_slots.values():
		if not seats.has(seat): seats.append(seat)
	seats.sort()
	return seats

func on_controller_roster() -> void:
	if not local_server_address_applied and controller_hub.net.room != "":
		local_server_address_applied = true
		var configured: Dictionary = hud.game_menu.PhoneConnection.describe("ws://" + ServerAddress.normalize(relay_url), PackedStringArray())
		if configured.local:
			# The app owns the local server and knows its actual (possibly fallback) port.
			relay_url = ServerAddress.normalize(controller_hub.net.server_url); hud.url_field.text = relay_url
	var phones: Array = controller_hub.net.roster.filter(func(player): return str(player.owner) != controller_hub.net.peer_id)
	var connected_slots: Array = phones.map(func(player): return int(player.slot))
	for slot in phone_slots.keys():
		if not connected_slots.has(slot): phone_slots.erase(slot)
	for phone in phones:
		var slot := int(phone.slot)
		if not phone_slots.has(slot):
			for seat in ([0,1,2,3] if in_menu else run_seats):
				if not active_local_seats().has(seat): phone_slots[slot]=int(seat); break
		if phone_slots.has(slot): local_avatars[int(phone_slots[slot])] = str(phone.avatar)
	sync_lobby_seats()
	hud.game_menu.update_phone_connection()

func on_phone_command(slot: int, data: Dictionary) -> void:
	if in_menu or not phone_slots.has(slot) or int(data.get("turn",-1)) != sim.turn: return
	var index := run_seats.find(phone_slots[slot])
	if index < 0 or index >= local_slots.size(): return
	send_command(int(local_slots[index]), data.duplicate())

func sync_lobby_seats() -> void:
	if not in_menu:return
	if controller_hub != null:
		controller_hub.set_native_avatars(native_local_seats().map(func(seat): return local_avatars[int(seat)]))
	var count:=active_local_seats().size()
	if not net.pending.is_empty():net.pending.count=count;net.pending.avatars=active_avatars()
	if net.connected and net.room!="":net.send({"type":"seats","count":count,"avatars":active_avatars()})

func active_avatars() -> Array:
	return active_local_seats().map(func(seat): return local_avatars[int(seat)])

func set_local_avatar(seat: int, avatar: String) -> void:
	if not in_menu or not active_local_seats().has(seat) or not Avatars.IDS.has(avatar): return
	local_avatars[seat]=avatar; save_settings(); sync_lobby_seats()

func avatar_for_player(slot: int) -> String:
	if net.room!="":
		for player in net.roster:
			if int(player.slot)==slot: return str(player.get("avatar",local_avatars[slot]))
	if not in_menu and slot<sim.players.size(): return str(sim.players[slot].get("avatar",local_avatars[slot]))
	return str(local_avatars[slot])

func play_connected() -> void:
	if net.connected and net.room!="":
		if net.is_host:
			sync_lobby_seats();net.send({"type":"start"})
		else:hud.message_label.text="Забег начнёт ведущий комнаты."
		return
	if active_local_seats().is_empty():keyboard_seat=true;sync_lobby_seats()
	start_local(active_local_seats().size(),1)

func menu_roster() -> Dictionary:
	var result: Dictionary = {}
	if net.connected and net.room!="":
		for player in net.roster:
			result[int(player.slot)]="ПО СЕТИ" if str(player.owner)!=net.peer_id else "ГЕЙМПАД"
		var active:=active_local_seats()
		if keyboard_seat and active.has(0) and active.find(0)<local_slots.size():result[int(local_slots[active.find(0)])]="КЛАВИАТУРА"
		for seat in phone_slots.values():
			var index := active.find(seat)
			if index >= 0 and index < local_slots.size(): result[int(local_slots[index])]="ТЕЛЕФОН"
	else:
		for seat in active_local_seats():result[int(seat)]="ТЕЛЕФОН" if phone_slots.values().has(seat) else ("КЛАВИАТУРА" if seat==0 and keyboard_seat else "ГЕЙМПАД")
	return result

func register_pad(device: int) -> bool:
	if pad_slots.has(device): return false
	var seats: Array = [0,1,2,3] if in_menu else run_seats
	for slot in seats:
		if pad_slots.values().has(slot) or phone_slots.values().has(slot) or (slot==0 and keyboard_seat): continue
		pad_slots[device] = int(slot)
		var player_id: int = int(slot) if in_menu else int(local_slots[run_seats.find(slot)])
		pad_notice = "P%d · %s — ПОДКЛЮЧЁН" % [player_id+1,sim.Catalog.NAMES[player_id]]
		pad_notice_time = 4.0
		arena.sound("ready",player_id)
		Input.start_joy_vibration(device,0.25,0.45,0.22)
		if in_menu:sync_lobby_seats()
		return true
	return false

func on_pad_connection(device: int, connected: bool) -> void:
	if connected or not pad_slots.has(device): return
	stop_charge(device); spin_buttons.erase(device); pad_aim_axes.erase(device); pad_aim_buttons.erase(device)
	var slot: int = int(pad_slots[device]); pad_slots.erase(device)
	var index:=run_seats.find(slot)
	var player_id: int = slot if in_menu or index<0 else int(local_slots[index])
	pad_notice = "P%d — КОНТРОЛЛЕР ОТКЛЮЧЁН" % (player_id+1); pad_notice_time = 5.0
	if in_menu:sync_lobby_seats()

func device_slot(device: int) -> int:
	var seat := int(pad_slots.get(device,-1))
	if seat<0:return -1
	if in_menu:return seat
	var index:=run_seats.find(seat)
	return int(local_slots[index]) if index>=0 and index<local_slots.size() else -1

func keyboard_slot() -> int:
	if not keyboard_seat: return -1
	var index := run_seats.find(0)
	return int(local_slots[index]) if index >= 0 and index < local_slots.size() else -1

func menu_input(event: InputEvent) -> bool:
	if event is InputEventJoypadButton and event.pressed:
		if register_pad(event.device): return true
		if not pad_slots.has(event.device): return true
		hud.game_menu.menu_device=event.device
		match event.button_index:
			JOY_BUTTON_X: hud.game_menu.focus_roster()
			JOY_BUTTON_DPAD_UP: hud.game_menu.navigate(Vector2.UP)
			JOY_BUTTON_DPAD_DOWN: hud.game_menu.navigate(Vector2.DOWN)
			JOY_BUTTON_DPAD_LEFT: hud.game_menu.navigate(Vector2.LEFT)
			JOY_BUTTON_DPAD_RIGHT: hud.game_menu.navigate(Vector2.RIGHT)
			JOY_BUTTON_B: hud.game_menu.back()
			JOY_BUTTON_A: hud.game_menu.accept()
		return true
	if event is InputEventJoypadMotion and event.axis in [JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y]:
		if pad_slots.has(event.device) and absf(event.axis_value)>.6 and menu_axis_time<=0:
			hud.game_menu.menu_device=event.device
			hud.game_menu.navigate(Vector2(signf(event.axis_value),0) if event.axis==JOY_AXIS_LEFT_X else Vector2(0,signf(event.axis_value)))
			menu_axis_time = .22
		return true
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_TAB: return true
		hud.game_menu.menu_device=-1
		if pad_slots.is_empty() and not keyboard_seat and not phone_slots.values().has(0):
			keyboard_seat = true;sync_lobby_seats()
		var focus = get_viewport().gui_get_focus_owner()
		if hud.game_menu.keyboard_event(event): return true
		if focus in [hud.game_menu.keyboard_input, hud.url_field] and event.keycode in [KEY_UP,KEY_DOWN]:
			hud.game_menu.navigate(Vector2.UP if event.keycode==KEY_UP else Vector2.DOWN); return true
		if focus is LineEdit and focus != hud.code_field and event.keycode not in [KEY_ESCAPE,KEY_BACK]: return false
		match event.keycode:
			KEY_UP: hud.game_menu.navigate(Vector2.UP)
			KEY_DOWN: hud.game_menu.navigate(Vector2.DOWN)
			KEY_LEFT: hud.game_menu.navigate(Vector2.LEFT)
			KEY_RIGHT: hud.game_menu.navigate(Vector2.RIGHT)
			KEY_ESCAPE, KEY_BACK: hud.game_menu.back()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				if not event.echo: hud.game_menu.accept()
			_: return false
		return true
	return false

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion or event is InputEventJoypadButton:
		track_pad_aim(event)
	# Releases must be consumed even if a menu, help screen or phase changed.
	if event is InputEventKey and event.physical_keycode == KEY_SPACE and not event.pressed:
		release_charge(-1); get_viewport().set_input_as_handled(); return
	if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_A and not event.pressed:
		release_charge(event.device); get_viewport().set_input_as_handled(); return
	if in_menu and menu_input(event):
		get_viewport().set_input_as_handled(); return
	if not in_menu and event is InputEventJoypadButton and event.pressed and not pad_slots.has(event.device):
		register_pad(event.device)
		get_viewport().set_input_as_handled(); return
	if not in_menu and not hud.help_open and sim.phase == "plan":
		if event is InputEventJoypadButton and event.button_index in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
			var slot := device_slot(event.device)
			if slot >= 0: set_spin_button(event.device, slot, event.button_index == JOY_BUTTON_LEFT_SHOULDER, event.pressed)
			get_viewport().set_input_as_handled(); return
		if event is InputEventKey and event.physical_keycode in [KEY_Z, KEY_C] and not event.echo:
			var slot := keyboard_slot()
			if slot >= 0: set_spin_button(-1, slot, event.physical_keycode == KEY_Z, event.pressed)
			get_viewport().set_input_as_handled(); return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
			get_viewport().set_input_as_handled(); return
		if in_menu: return
		if hud.help_open and event.physical_keycode not in [KEY_H, KEY_ESCAPE, KEY_M]: return
		var slot := keyboard_slot()
		if event.physical_keycode not in [KEY_H, KEY_ESCAPE, KEY_M, KEY_ENTER] and slot < 0: return
		if slot >= 0 and event.physical_keycode in [KEY_LEFT, KEY_RIGHT, KEY_A, KEY_D, KEY_SPACE, KEY_ENTER, KEY_BACKSPACE, KEY_BACK, KEY_Q, KEY_1, KEY_2, KEY_3]: selected = slot
		if slot >= 0 and sim.phase == "reward" and event.physical_keycode in [KEY_LEFT, KEY_RIGHT, KEY_A, KEY_D, KEY_SPACE, KEY_ENTER]:
			var choice: int = int(reward_choices.get(selected, maxi(0, int(sim.players[selected].get("reward_choice", -1)))))
			if event.physical_keycode in [KEY_LEFT, KEY_A]: choice = posmod(choice - 1, 3)
			if event.physical_keycode in [KEY_RIGHT, KEY_D]: choice = posmod(choice + 1, 3)
			reward_choices[selected] = choice
			if event.physical_keycode in [KEY_SPACE, KEY_ENTER]: send_command(selected, {"action": "reward", "choice": choice})
			get_viewport().set_input_as_handled(); return
		match event.physical_keycode:
			KEY_H: clear_charges(); spin_buttons.clear(); pad_aim_axes.clear(); pad_aim_buttons.clear(); hud.help_open = not hud.help_open;arena.sound("ui")
			KEY_M: arena.muted = not arena.muted
			KEY_ESCAPE:
				if hud.help_open: hud.help_open = false
				else: return_menu()
			KEY_SPACE: begin_charge(-1, selected)
			KEY_BACKSPACE, KEY_BACK: cancel_charge(int(shot_charges[-1].slot) if shot_charges.has(-1) else selected)
			KEY_Q: send_command(selected, {"action": "ability"})
			KEY_1, KEY_2, KEY_3:
				reward_choices[selected] = event.physical_keycode - KEY_1
				send_command(selected, {"action": "reward", "choice": event.physical_keycode - KEY_1})
			KEY_ENTER:
				if sim.phase in ["win", "lose"]: return_menu()
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed and not in_menu:
		var slot := device_slot(event.device)
		if slot < 0: return
		if event.button_index == JOY_BUTTON_START:
			clear_charges(); spin_buttons.clear(); pad_aim_axes.clear(); pad_aim_buttons.clear()
			hud.help_open = not hud.help_open
			get_viewport().set_input_as_handled(); return
		if hud.help_open: return
		selected = slot
		if sim.phase in ["win", "lose"] and event.button_index == JOY_BUTTON_A: return_menu(); return
		if sim.phase == "reward":
			var choice: int = int(reward_choices.get(slot, maxi(0, int(sim.players[slot].get("reward_choice", -1)))))
			if event.button_index == JOY_BUTTON_DPAD_LEFT: choice = posmod(choice - 1, 3)
			if event.button_index == JOY_BUTTON_DPAD_RIGHT: choice = posmod(choice + 1, 3)
			reward_choices[slot] = choice
			if event.button_index == JOY_BUTTON_A: send_command(slot, {"action": "reward", "choice": choice})
			if event.button_index == JOY_BUTTON_B: cancel_charge(slot)
		else:
			match event.button_index:
				JOY_BUTTON_A: begin_charge(event.device, slot)
				JOY_BUTTON_B: cancel_charge(slot)
				JOY_BUTTON_X: send_command(slot, {"action": "ability"})
				JOY_BUTTON_START: hud.help_open = not hud.help_open
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and not in_menu:
		var keyboard_player := keyboard_slot()
		if keyboard_player < 0: return
		selected = keyboard_player
		if sim.phase == "reward" and event.button_index == MOUSE_BUTTON_LEFT and not hud.help_open:
			var point: Vector2 = event.position / hud.scale_factor
			for i in 3:
				if hud.reward_screen.choice_rect(i).has_point(point):
					reward_choices[selected] = i
					send_command(selected, {"action": "reward", "choice": i})
		elif sim.phase == "plan" and not hud.help_open:
			if event.button_index == MOUSE_BUTTON_LEFT:
				var slot: int = shot_charges[-1].slot if shot_charges.has(-1) else selected
				var offset: Vector2 = arena.floor_point(event.position) - sim.pos(sim.players[slot])
				if offset.length() > 0.05: send_command(slot, {"action": "aim", "angle": offset.angle()})
			if event.button_index == MOUSE_BUTTON_RIGHT: send_command(selected, {"action": "ability"})

func on_network(data: Dictionary) -> void:
	match data.get("type", ""):
		"joined":
			local_slots = net.slots; selected = int(local_slots[0]) if not local_slots.is_empty() else 0; hud.update_lobby()
			sync_lobby_seats()
		"slots": local_slots = net.slots; selected = int(local_slots[0]) if not local_slots.is_empty() else 0
		"seats_rejected":
			var accepted:int=data.slots.size()
			var seats:=active_local_seats()
			for device in pad_slots.keys():
				if seats.find(pad_slots[device])>=accepted:pad_slots.erase(device)
			if keyboard_seat and seats.find(0)>=accepted:keyboard_seat=false
			for slot in phone_slots.keys():
				if seats.find(phone_slots[slot])>=accepted:phone_slots.erase(slot)
			pad_notice=str(data.message);pad_notice_time=4.0
		"roster":
			for player in net.roster:
				var key: String=str(player.owner)+":"+str(player.slot)
				if not roster_known.has(key) and str(player.owner)!=net.peer_id:
					pad_notice="P%d — ПОДКЛЮЧЁН ПО СЕТИ"%(int(player.slot)+1);pad_notice_time=4.0;arena.sound("ready",int(player.slot))
			roster_known.clear()
			for player in net.roster:roster_known[str(player.owner)+":"+str(player.slot)]=true
			hud.update_lobby()
		"start":
			online = true; start_game(int(data.count), int(data.difficulty))
		"lobby":
			enter_lobby()
		"command":
			if online and net.is_host:
				if data.data.get("action") == "reward_focus": apply_reward_focus(int(data.slot), data.data)
				else: sim.command(int(data.slot), data.data)
		"snapshot":
			if online and not net.is_host: sim.restore(data.state)
		"ended":
			var reason: String = data.message
			leave_room(); hud.game_menu.connection_failed(reason)

func on_error(reason: String) -> void:
	if not in_menu and online:
		leave_room()
	hud.game_menu.connection_failed(reason)

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
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		clear_charges(); spin_buttons.clear(); pad_aim_axes.clear(); pad_aim_buttons.clear()
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if arena != null: arena.stop_audio()
		if net != null: net.disconnect_room()
		await get_tree().create_timer(0.15).timeout
		get_tree().quit()
