extends SceneTree
const Main = preload("res://tests/support/test_main.gd")
# Integration fixtures must not overwrite the player's server or avatars.
class TestMain extends Main:
	func save_settings() -> void: pass
var host
var guest
var failures := 0
var url := ""
func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--url="): url = arg.trim_prefix("--url=")
	call_deferred("run")
func check(value: bool, label: String) -> void:
	if not value: failures += 1; push_error(label)
func until(condition: Callable) -> bool:
	for i in 200:
		if condition.call(): return true
		await create_timer(.01).timeout
	return false
func button(game, device: int, code: int, pressed: bool = true) -> void:
	var event := InputEventJoypadButton.new()
	event.device = device; event.button_index = code; event.pressed = pressed
	game._input(event)
func axis(game, device: int, code: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = device; event.axis = code; event.axis_value = value
	game._input(event)
func snapshot() -> void:
	host.net.send({"type":"snapshot", "state":host.sim.snapshot()})
	await create_timer(.08).timeout
func run() -> void:
	host = TestMain.new(); root.add_child(host)
	guest = TestMain.new(); root.add_child(guest)
	await process_frame
	host.set_process(false); guest.set_process(false)
	for device in [10,11]: button(host, device, JOY_BUTTON_A)
	for device in [20,21]: button(guest, device, JOY_BUTTON_A)
	host.net.connect_room(url, "", 2, true, host.active_avatars())
	if not await until(func(): return host.net.room != ""): finish("Host could not create room"); return
	guest.net.connect_room(url, host.net.room, 2, false, guest.active_avatars())
	if not await until(func(): return host.net.roster.size() == 4): finish("Guest could not join room"); return
	host.play_connected()
	if not await until(func(): return not host.in_menu and not guest.in_menu): finish("Match did not start"); return
	await snapshot()
	check(host.local_slots == [0,1] and guest.local_slots == [2,3], "Each TV owns two different players")
	check(host.device_slot(11) == 1 and guest.device_slot(20) == 2 and guest.device_slot(21) == 3, "All controllers retain their assigned player after start")
	# Every pad must aim, including P2 on the host and P3/P4 on the guest.
	for slot in 4:
		var game = host if slot < 2 else guest
		var device: int = 10 + slot if slot < 2 else 20 + slot - 2
		var untouched: Array = host.sim.players.map(func(p): return float(p.angle))
		button(game, device, JOY_BUTTON_DPAD_LEFT)
		game.read_continuous_input(.05)
		button(game, device, JOY_BUTTON_DPAD_LEFT, false)
		var dpad_angle := fposmod(float(untouched[slot]) - 1.5 * .05, TAU)
		check(await until(func(): return is_equal_approx(host.sim.players[slot].angle, dpad_angle)), "P%d gradual D-pad rotation reaches host" % (slot + 1))
		for other in 4:
			if other != slot: check(is_equal_approx(host.sim.players[other].angle, untouched[other]), "P%d does not aim P%d" % [slot+1,other+1])
		axis(game, device, JOY_AXIS_LEFT_X, .7); axis(game, device, JOY_AXIS_LEFT_Y, .7)
		game.read_continuous_input(.05)
		var partial_angle: float = game.sim.players[slot].angle
		check(absf(angle_difference(dpad_angle, partial_angle)) <= .15 + .0001 and not is_equal_approx(partial_angle, PI/4), "P%d stick starts with a bounded turn" % (slot + 1))
		check(await until(func(): return is_equal_approx(host.sim.players[slot].angle, partial_angle)), "P%d partial analog turn reaches host" % (slot + 1))
		for frame in 30:
			game.read_continuous_input(.05)
			await create_timer(.05).timeout
		axis(game, device, JOY_AXIS_LEFT_X, 0); axis(game, device, JOY_AXIS_LEFT_Y, 0)
		check(await until(func(): return is_equal_approx(host.sim.players[slot].angle, PI/4)), "P%d analog aim reaches host" % (slot + 1))
		await snapshot()
		button(game, device, JOY_BUTTON_X)
		check(await until(func(): return host.sim.players[slot].ability), "P%d ability reaches host" % (slot + 1))
		button(game, device, JOY_BUTTON_A)
		button(game, device, JOY_BUTTON_RIGHT_SHOULDER)
		game.read_continuous_input(.3)
		button(game, device, JOY_BUTTON_RIGHT_SHOULDER, false)
		button(game, device, JOY_BUTTON_A, false)
		check(await until(func(): return host.sim.players[slot].ready), "P%d release confirms its shot" % (slot + 1))
		check(is_equal_approx(host.sim.players[slot].power,.575) and host.sim.players[slot].spin > 0, "P%d power and spin reach host" % (slot + 1))
		await snapshot()
		check(guest.sim.players[slot].ready and is_equal_approx(guest.sim.players[slot].angle,PI/4), "P%d result returns in guest snapshot" % (slot + 1))
		button(game, device, JOY_BUTTON_B)
		check(await until(func(): return not host.sim.players[slot].ready), "P%d can cancel readiness" % (slot + 1))
		await snapshot()
	var room: String = host.net.room
	var guest_id: String = guest.net.peer_id
	var guest_socket = guest.net.socket
	var avatars: Array = host.sim.players.map(func(p): return p.avatar)
	for result in ["win", "lose"]:
		host.sim.phase = result; host.sim.wave = 9; host.sim.kills = 100
		await snapshot()
		button(guest, 20, JOY_BUTTON_A)
		check(guest.net.connected and guest.net.room == room and not guest.in_menu, "Guest result confirmation keeps the room connection")
		button(host, 10, JOY_BUTTON_A)
		check(await until(func(): return host.in_menu and guest.in_menu), "Host returns every TV to the lobby")
		check(host.hud.game_menu.screen == "lobby" and guest.hud.game_menu.screen == "lobby", "Both TVs show the shared room")
		check(host.net.room == room and guest.net.room == room and guest.net.peer_id == guest_id and guest.net.socket == guest_socket, "Rematch preserves room code and connection identity")
		check(host.hud.game_menu.leave_button.text == "ЗАВЕРШИТЬ КОМНАТУ" and guest.hud.game_menu.leave_button.text == "ПОКИНУТЬ КОМНАТУ", "Room actions identify host and guest permissions")
		host.play_connected()
		check(await until(func(): return not host.in_menu and not guest.in_menu), "Same host starts the next game")
		await snapshot()
		check(host.sim.phase == "plan" and host.sim.wave == 1 and host.sim.kills == 0, "New match resets result and progress")
		check(host.sim.players.map(func(p): return p.avatar) == avatars, "All four avatars survive the rematch")
		check(guest.local_slots == [2,3] and guest.device_slot(21) == 3, "Guest gamepads retain their players")
		button(guest, 21, JOY_BUTTON_X)
		check(await until(func(): return host.sim.players[3].ability), "Guest controls its player in the restarted match")
	# Closing the room is a separate explicit action available to the host.
	button(guest, 20, JOY_BUTTON_A)
	check(guest.shot_charges.has(20), "Guest holds a shot when host stops the match")
	host.return_menu()
	check(await until(func(): return host.in_menu and guest.in_menu), "Return before closing room")
	await create_timer(.1).timeout
	check(guest.shot_charges.is_empty() and guest.hud.game_menu.screen == "lobby", "Returning to lobby discards held input without sending stale commands")
	host.hud.game_menu.leave_button.pressed.emit()
	check(await until(func(): return guest.net.room == ""), "Host closes the room for everyone")
	check(guest.in_menu and guest.hud.message_label.text.contains("завершил"), "Guest sees why the room closed")
	print("CONTROLLER NETWORK: failures=", failures)
	finish()
func finish(reason: String = "") -> void:
	if reason != "": check(false, reason)
	for game in [host,guest]:
		game.arena.stop_audio(); game.net.disconnect_room(); game.queue_free()
	await process_frame
	quit(1 if failures else 0)
