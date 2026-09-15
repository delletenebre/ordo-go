extends SceneTree
const Main = preload("res://tests/support/test_main.gd")
class RecordingNetwork extends RefCounted:
	var is_host := false
	var packets: Array = []
	func send(data: Dictionary) -> void: packets.append(data.duplicate(true))
var game
var failures := 0
func _init() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value: failures += 1; push_error(message)
func key(code: int, pressed: bool = true, echo: bool = false) -> void:
	var event := InputEventKey.new(); event.physical_keycode = code; event.keycode = code; event.pressed = pressed; event.echo = echo
	game._input(event)
func pad(device: int, button: int, pressed: bool = true) -> void:
	var event := InputEventJoypadButton.new(); event.device = device; event.button_index = button; event.pressed = pressed
	game._input(event)
func axis(device: int, code: int, value: float) -> void:
	var event := InputEventJoypadMotion.new(); event.device = device; event.axis = code; event.axis_value = value
	game._input(event)
func check_stick() -> void:
	game.sim.players[1].angle = 0.0
	var first_angle: float = game.sim.players[0].angle
	axis(11, JOY_AXIS_LEFT_Y, .24); game.read_continuous_input(.1)
	check(is_zero_approx(game.sim.players[1].angle), "Stick drift inside the deadzone does not move aim")
	axis(11, JOY_AXIS_LEFT_Y, .4); game.read_continuous_input(.1)
	var fine_angle: float = game.sim.players[1].angle
	check(fine_angle > 0.0 and fine_angle < .05, "Small stick deflection permits fine aim correction")
	game.sim.players[1].angle = 0.0
	axis(11, JOY_AXIS_LEFT_Y, 1.0); game.read_continuous_input(.1)
	var full_angle: float = game.sim.players[1].angle
	check(full_angle > fine_angle * 4.0 and full_angle < PI/4, "Full stick turns faster but cannot snap to its target")
	check(is_equal_approx(game.sim.players[0].angle, first_angle), "Analog aim affects only its controller's player")
	game.sim.players[1].angle = 0.0
	for i in 6: game.read_continuous_input(1.0/60.0)
	check(is_equal_approx(game.sim.players[1].angle, full_angle), "Stick turn speed is independent of frame rate")
	for i in 60: game.read_continuous_input(1.0/60.0)
	check(is_equal_approx(game.sim.players[1].angle, PI/2), "Held stick reaches the exact target without overshooting")
	axis(11, JOY_AXIS_LEFT_Y, 0.0); game.read_continuous_input(.1)
	check(is_equal_approx(game.sim.players[1].angle, PI/2), "Released stick stops immediately without residual motion")
	game.sim.players[1].angle = TAU - .1
	axis(11, JOY_AXIS_LEFT_X, 1.0); game.read_continuous_input(.1)
	check(is_zero_approx(game.sim.players[1].angle), "Stick takes the short path across the angle wrap")
	axis(11, JOY_AXIS_LEFT_X, 0.0)
func run() -> void:
	game = Main.new(); root.add_child(game)
	await process_frame
	game.keyboard_seat = true; game.pad_slots = {11:1}
	game.start_local(2, 1); game.set_process(false)
	key(KEY_Q); check(game.sim.players[0].ability, "Q selects ability")
	key(KEY_SPACE); check(not game.sim.players[0].ready and game.is_charging(0), "Press starts charging without confirming")
	check(is_equal_approx(game.sim.players[0].power, .15), "Charge starts at minimum")
	game.read_continuous_input(.3)
	check(is_equal_approx(game.sim.players[0].power, .575), "Half hold gives interpolated power")
	check(bool(game.sim.snapshot().players[0].get("charging",false)), "Native hold is included in snapshots for other TVs")
	key(KEY_SPACE, true, true)
	check(is_equal_approx(game.sim.players[0].power, .575), "Key repeat does not restart charge")
	var click := InputEventMouseButton.new(); click.button_index = MOUSE_BUTTON_LEFT; click.pressed = true; click.position = Vector2(1000,400)
	var old_angle: float = game.sim.players[0].angle
	game._input(click)
	check(not is_equal_approx(game.sim.players[0].angle, old_angle) and is_equal_approx(game.sim.players[0].power,.575), "Mouse corrects direction without changing charge")
	game.read_continuous_input(.3)
	check(is_equal_approx(game.sim.players[0].power,1.0), "Full charge takes 0.6 seconds")
	game.read_continuous_input(2.0)
	check(is_equal_approx(game.sim.players[0].power,1.0) and not game.sim.players[0].ready, "Full charge clamps and waits for release")
	key(KEY_TAB); check(game.selected == 0 and game.sim.players.size() == 2, "Tab neither switches nor adds players")
	pad(11,JOY_BUTTON_X); check(game.selected == 1, "Gamepad can focus its own player")
	key(KEY_SPACE, false)
	check(game.sim.players[0].ready and not game.sim.players[1].ready, "Release confirms original slot despite selection change")
	key(KEY_SPACE); key(KEY_SPACE, false)
	check(not game.sim.players[1].ready, "Keyboard cannot charge the focused gamepad player")
	key(KEY_BACKSPACE); key(KEY_SPACE); key(KEY_SPACE, false)
	check(game.sim.players[0].ready and is_equal_approx(game.sim.players[0].power,.15), "Quick tap confirms minimum power")
	key(KEY_BACKSPACE); check(not game.sim.players[0].ready, "Backspace unlocks")
	key(KEY_SPACE); game.read_continuous_input(.3); key(KEY_BACKSPACE); key(KEY_SPACE, false)
	check(not game.sim.players[0].ready and not game.is_charging(0), "Cancel while holding prevents release confirmation")
	key(KEY_SPACE); key(KEY_H); check(game.hud.help_open and game.shot_charges.is_empty(), "Help opens and drops held charge")
	check(not game.sim.players[0].charging, "Help clears replicated charge before hiding the guide")
	key(KEY_ESCAPE); key(KEY_SPACE, false)
	check(not game.hud.help_open and not game.in_menu and not game.sim.players[0].ready, "Release after help does not fire")
	key(KEY_SPACE); game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT); key(KEY_SPACE, false)
	check(not game.sim.players[0].ready and not game.sim.players[0].charging, "Focus loss cancels held shot and replicated feedback")
	key(KEY_SPACE); game.sim.begin_plan(); key(KEY_SPACE, false)
	check(not game.sim.players[0].ready and game.shot_charges.is_empty(), "Old turn release cannot confirm next turn")
	game.keyboard_seat = false; game.run_seats = [0,1]; game.pad_slots = {10:0, 11:1}
	check_stick()
	var first_angle: float = game.sim.players[0].angle
	game.sim.players[1].angle = 1.2
	pad(11,JOY_BUTTON_DPAD_RIGHT); pad(11,JOY_BUTTON_DPAD_DOWN); game.read_continuous_input(.1)
	var turned_angle: float = game.sim.players[1].angle
	check(turned_angle > 1.2 and turned_angle < 1.4 and is_equal_approx(game.sim.players[0].angle,first_angle),"D-pad gradually rotates only its own player from the current aim")
	pad(11,JOY_BUTTON_DPAD_DOWN,false); game.read_continuous_input(.1)
	check(is_equal_approx(game.sim.players[1].angle - turned_angle, turned_angle - 1.2),"Diagonal D-pad hold does not change rotation speed")
	turned_angle = game.sim.players[1].angle
	axis(11, JOY_AXIS_LEFT_X, 1.0)
	pad(11,JOY_BUTTON_DPAD_LEFT); game.read_continuous_input(.1)
	check(game.pad_aim_direction(11)==Vector2.ZERO and is_equal_approx(game.sim.players[1].angle, turned_angle),"Opposite D-pad directions cancel and suppress stick input")
	axis(11, JOY_AXIS_LEFT_X, 0.0)
	pad(11,JOY_BUTTON_DPAD_RIGHT,false); game.read_continuous_input(.1)
	check(is_equal_approx(game.sim.players[1].angle, 1.35), "D-pad left reverses the gradual rotation")
	pad(11,JOY_BUTTON_DPAD_LEFT,false); pad(11,JOY_BUTTON_DPAD_RIGHT,false)
	game.sim.players[1].angle=1.2; game.read_continuous_input(.1)
	check(is_equal_approx(game.sim.players[1].angle,1.2),"Released D-pad stops issuing aim")
	pad(11,JOY_BUTTON_DPAD_DOWN); game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(game.pad_aim_direction(11)==Vector2.ZERO,"Focus loss clears held aim")
	pad(10,JOY_BUTTON_LEFT_SHOULDER); game.read_continuous_input(.25); pad(10,JOY_BUTTON_LEFT_SHOULDER,false)
	check(game.sim.players[0].spin<0.0 and game.sim.players[1].spin==0.0,"L1 adjusts only its own spin")
	pad(10,JOY_BUTTON_LEFT_SHOULDER); pad(10,JOY_BUTTON_RIGHT_SHOULDER)
	check(game.sim.players[0].spin==0.0,"Both shoulders restore straight shot")
	pad(10,JOY_BUTTON_LEFT_SHOULDER,false); pad(10,JOY_BUTTON_RIGHT_SHOULDER,false)
	pad(10,JOY_BUTTON_A); pad(10,JOY_BUTTON_RIGHT_SHOULDER); game.read_continuous_input(.6); pad(10,JOY_BUTTON_RIGHT_SHOULDER,false)
	check(game.sim.players[0].spin>0.0 and game.is_charging(0),"R1 adjusts spin during power charge")
	pad(11,JOY_BUTTON_A); game.read_continuous_input(.3)
	check(game.sim.players[0].power > game.sim.players[1].power, "Pads charge independently")
	pad(10,JOY_BUTTON_A,false)
	check(game.sim.players[0].ready and not game.sim.players[1].ready and game.is_charging(1), "Pad release confirms only its own shot")
	pad(11,JOY_BUTTON_B); pad(11,JOY_BUTTON_A,false)
	check(not game.sim.players[1].ready, "B cancels charging")
	pad(11,JOY_BUTTON_A); pad(11,JOY_BUTTON_DPAD_LEFT); game.on_pad_connection(11,false); pad(11,JOY_BUTTON_A,false)
	check(game.pad_aim_direction(11)==Vector2.ZERO,"Disconnect clears only that controller aim")
	check(not game.sim.players[1].ready and game.shot_charges.is_empty(), "Disconnect cancels charge")
	check(not game.sim.players[1].charging, "Disconnected gamepad stops remote feedback")
	game.sim.begin_plan()
	var actual_net = game.net
	var recorder := RecordingNetwork.new(); game.net = recorder; game.online = true
	game.begin_charge(-1,0); game.read_continuous_input(.3)
	game.sim.players[0].power = .2 # Simulate an older host snapshot arriving before release.
	game.release_charge(-1)
	var aim: Dictionary = recorder.packets[-2].data
	check(not bool(aim.get("charging",true)),"Final network aim clears holding while preserving final power")
	check(aim.action=="aim" and aim.has("angle") and aim.has("spin") and is_equal_approx(aim.power,.575),"Network release flushes complete final aim despite older power snapshot")
	check(recorder.packets[-1].data.action=="ready" and recorder.packets[-1].data.turn==aim.turn,"Network confirms after final aim in same turn")
	game.net = actual_net; game.online = false
	game.keyboard_seat = true; game.pad_slots = {11:1}; game.selected = 1
	game.sim.begin_reward(); key(KEY_1)
	check(game.sim.players[0].reward and not game.sim.players[1].reward, "Keyboard selects only its own reward despite gamepad focus")
	key(KEY_TAB); key(KEY_2)
	check(game.sim.players[0].reward_choice == 1 and not game.sim.players[1].reward, "Tab cannot redirect keyboard rewards")
	pad(11,JOY_BUTTON_A)
	for i in 250: game.sim.tick(1.0/120)
	check(game.sim.wave == 2, "All rewards advance wave")
	print("INPUT: hold/release, power, aim correction, cancellation, independent pads, help and rewards; failures=", failures)
	game.arena.stop_audio();await create_timer(.2).timeout
	game.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	quit(1 if failures else 0)
