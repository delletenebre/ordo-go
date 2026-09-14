extends SceneTree
const Main = preload("res://scripts/main.gd")
var game
var failures := 0
func check(value: bool, message: String) -> void:
	if not value: failures += 1; push_error(message)
func pad(device: int, button: int) -> void:
	var event := InputEventJoypadButton.new();event.device=device;event.button_index=button;event.pressed=true;game._input(event)
func key(code: int) -> void:
	var event := InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=true;game._input(event)
func _init() -> void: call_deferred("run")
func run() -> void:
	game=Main.new();root.add_child(game);await process_frame
	for id in 4:
		pad(10+id,JOY_BUTTON_A)
		check(game.in_menu and game.device_slot(10+id)==id,"First press joins correct seat without starting game")
		check(game.pad_notice.contains("P%d"%(id+1)) and game.pad_notice_time>0,"Visible join indication names the player")
	check(game.hud.local_count.selected==3,"Four joined controllers select four players")
	pad(14,JOY_BUTTON_A);check(game.in_menu and game.pad_slots.size()==4,"Fifth controller cannot activate menu")
	pad(10,JOY_BUTTON_DPAD_DOWN);pad(10,JOY_BUTTON_DPAD_DOWN);check(game.get_viewport().gui_get_focus_owner()==game.hud.game_menu.count_button,"Dpad moves visible focus")
	pad(10,JOY_BUTTON_DPAD_DOWN);pad(10,JOY_BUTTON_DPAD_RIGHT);check(game.hud.difficulty.selected==2,"Dpad changes setting")
	game.on_pad_connection(11,false);check(game.device_slot(12)==2 and game.device_slot(13)==3,"Unplugging P2 never renumbers P3 and P4")
	pad(21,JOY_BUTTON_A);check(game.device_slot(21)==1,"New controller fills P2 vacancy")
	game.hud.game_menu.show_network(true);game.hud.code_field.grab_focus()
	pad(10,JOY_BUTTON_A);pad(10,JOY_BUTTON_DPAD_UP);pad(10,JOY_BUTTON_DPAD_RIGHT);pad(10,JOY_BUTTON_DPAD_UP);pad(10,JOY_BUTTON_A)
	check(game.hud.code_field.text=="BBAAAA" and game.get_viewport().gui_get_focus_owner()==game.hud.join_button,"Room code can be entered without a keyboard")
	pad(10,JOY_BUTTON_B)
	game.hud.local_button.grab_focus();pad(10,JOY_BUTTON_A);check(not game.in_menu and game.sim.players.size()==4,"Joined pad starts configured party")
	game.sim.begin_reward();game.sim.reward_options=["stitch","spark","guard"]
	pad(12,JOY_BUTTON_DPAD_RIGHT);pad(12,JOY_BUTTON_A)
	check(game.sim.players[2].reward_choice==1 and not game.sim.players[0].reward,"P3 controls its own bonus")
	pad(12,JOY_BUTTON_B);check(not game.sim.players[2].reward,"Gamepad cancels reward readiness")
	game.return_menu();game.pad_slots.clear();game.keyboard_seat=false
	key(KEY_DOWN);pad(30,JOY_BUTTON_A);check(game.device_slot(30)==1,"Keyboard first reserves P1, pad joins P2")
	game.hud.local_button.grab_focus();key(KEY_ENTER);check(not game.in_menu,"Remote OK/Enter starts focused action")
	game.local_slots=[2,3];game.pad_slots={40:0,41:1}
	check(game.device_slot(40)==2 and game.device_slot(41)==3,"Local controller seats map to authoritative network slots")
	game.pad_slots={40:0};game.keyboard_seat=false;game.register_pad(41)
	check(game.pad_notice.contains("P4"),"Join notice uses the network player number")
	print("MENU CONTROLLERS: failures=",failures)
	game.set_process(false);game.arena.stop_audio();await create_timer(.2).timeout
	game.queue_free();await process_frame;quit(1 if failures else 0)
