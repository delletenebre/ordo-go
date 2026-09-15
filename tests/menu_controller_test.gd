extends SceneTree
const Main = preload("res://tests/support/test_main.gd")
# Integration fixtures must not overwrite the player's server or avatars.
class TestMain extends Main:
	func save_settings() -> void: pass
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
	game=TestMain.new();root.add_child(game);await process_frame
	for id in 4:
		pad(10+id,JOY_BUTTON_A)
		check(game.in_menu and game.device_slot(10+id)==id,"First press joins correct seat without starting game")
		check(game.pad_notice.contains("P%d"%(id+1)) and game.pad_notice_time>0,"Visible join indication names the player")
	check(game.active_local_seats().size()==4,"Four real controllers form four seats")
	pad(14,JOY_BUTTON_A);check(game.in_menu and game.pad_slots.size()==4,"Fifth controller cannot activate menu")
	pad(10,JOY_BUTTON_DPAD_DOWN);check(game.get_viewport().gui_get_focus_owner()==game.hud.game_menu.network_button,"Down moves to the next visible button")
	pad(10,JOY_BUTTON_DPAD_UP);check(game.get_viewport().gui_get_focus_owner()==game.hud.local_button,"Up returns to Play")
	game.on_pad_connection(11,false);check(game.device_slot(12)==2 and game.device_slot(13)==3,"Unplugging P2 never renumbers P3 and P4")
	pad(21,JOY_BUTTON_A);check(game.device_slot(21)==1,"New controller fills P2 vacancy")
	var menu = game.hud.game_menu
	menu.show_screen("join");await process_frame;await process_frame;await process_frame
	check(menu.code_editing and menu.keyboard_panel.visible and menu.keyboard_keys.size()==10,"Join immediately shows ten numeric keys")
	check(menu.keyboard_keys[0].has_focus(),"Join focuses the first digit")
	check(menu.network_window.get_global_rect().end.y<768*game.hud.scale_factor,"Keyboard clears roster")
	check(game.hud.join_button.disabled,"Incomplete code cannot connect")
	pad(10,JOY_BUTTON_DPAD_RIGHT);pad(10,JOY_BUTTON_A)
	check(game.hud.code_field.text=="2","Remote selects visible digit")
	pad(10,JOY_BUTTON_DPAD_DOWN);pad(10,JOY_BUTTON_A)
	check(game.hud.code_field.text=="25","Remote navigates numeric rows")
	menu.keyboard_keys[9].grab_focus();pad(10,JOY_BUTTON_A)
	check(game.hud.code_field.text=="250","Remote can enter zero")
	key(KEY_BACKSPACE);check(game.hud.code_field.text=="25","Physical Backspace works on grid")
	for character in "0234":
		var typed:=InputEventKey.new();typed.pressed=true;typed.unicode=character.unicode_at(0);game._input(typed)
	check(game.hud.code_field.text=="250234" and game.hud.join_button.has_focus(),"Six digits focus Connect directly")
	menu.keyboard_delete.grab_focus();pad(10,JOY_BUTTON_A)
	check(game.hud.code_field.text=="25023" and game.hud.join_button.disabled,"Dedicated Backspace removes one digit")
	game.hud.code_field.grab_focus();game.hud.code_field.select_all()
	var typed:=InputEventKey.new();typed.pressed=true;typed.keycode=KEY_0;typed.unicode=48
	Input.parse_input_event(typed);await process_frame
	check(game.hud.code_field.text=="0","Native keyboard preserves leading zero")
	typed=InputEventKey.new();typed.pressed=true;typed.keycode=KEY_H;typed.unicode=104
	Input.parse_input_event(typed);await process_frame
	check(game.hud.code_field.text=="0","Native input rejects letters")
	menu.keyboard_keys[2].grab_focus();pad(10,JOY_BUTTON_A)
	check(game.hud.code_field.text=="03","Physical and onscreen typing can be mixed")
	pad(10,JOY_BUTTON_B)
	check(menu.screen=="network" and not menu.code_editing,"Back exits code entry")
	menu.show_screen("join");await process_frame
	menu.back_buttons.join.grab_focus();pad(10,JOY_BUTTON_A)
	check(menu.screen=="network","Visible Back exits code entry")
	menu.show_screen("home")
	game.local_avatars=["manas","kanykei","ilbirs","bugu"]
	pad(12,JOY_BUTTON_DPAD_DOWN);pad(12,JOY_BUTTON_DPAD_DOWN)
	check(menu.screen=="home" and menu.roster_buttons[2].has_focus(),"Down from menu reaches the controller's roster slot")
	pad(12,JOY_BUTTON_DPAD_RIGHT)
	check(game.local_avatars[2]=="bugu" and menu.roster_buttons[2].has_focus(),"Right changes avatar immediately without opening a page")
	pad(10,JOY_BUTTON_DPAD_LEFT)
	check(game.local_avatars[0]=="tulpar" and game.local_avatars[2]=="bugu" and menu.roster_buttons[0].has_focus(),"Another controller cycles only its own seat, wrapping backwards")
	pad(10,JOY_BUTTON_DPAD_RIGHT)
	check(game.local_avatars[0]=="manas","Avatar selection wraps forwards")
	var motion:=InputEventJoypadMotion.new();motion.device=21;motion.axis=JOY_AXIS_LEFT_X;motion.axis_value=1
	game.menu_axis_time=0;game._input(motion)
	check(game.local_avatars[1]=="bakai" and menu.roster_buttons[1].has_focus(),"Stick input uses its controller's ownership")
	pad(21,JOY_BUTTON_DPAD_UP)
	check(menu.network_button.has_focus(),"Up returns to the previous menu button")
	pad(12,JOY_BUTTON_X);game.on_pad_connection(12,false);menu.refresh()
	check(not menu.roster_buttons[2].visible and menu.network_button.has_focus(),"Disconnected focused seat returns focus to menu")
	pad(12,JOY_BUTTON_A)
	menu.show_screen("home");game.hud.local_button.grab_focus();pad(10,JOY_BUTTON_A)
	check(not game.in_menu and game.sim.players.size()==4,"New Game starts connected party with one activation")
	game.return_menu();menu.network_button.grab_focus();pad(21,JOY_BUTTON_DPAD_DOWN)
	check(menu.roster_buttons[1].has_focus(),"Home menu leads directly to roster")
	pad(21,JOY_BUTTON_B)
	check(menu.screen=="home" and menu.network_button.has_focus(),"Back leaves roster and restores home menu focus")
	# A second household may own global P3/P4 while using local seats P1/P2.
	game.net.connected=true;game.net.room="482731";game.net.peer_id="remote"
	game.net.roster=[{"slot":0,"owner":"host"},{"slot":1,"owner":"host"},{"slot":2,"owner":"remote"},{"slot":3,"owner":"remote"}]
	game.local_slots=[2,3];game.pad_slots={10:0,21:1};menu.show_screen("home")
	game.hud.local_button.grab_focus();pad(10,JOY_BUTTON_A)
	check(game.in_menu and menu.screen=="lobby","New Game returns room members to the shared lobby")
	await process_frame;await process_frame
	menu.visible_controls().back().grab_focus();pad(21,JOY_BUTTON_DPAD_DOWN)
	check(menu.roster_buttons[3].has_focus() and not menu.roster_buttons[0].visible,"Remote TV focuses only its owned global slot")
	pad(21,JOY_BUTTON_DPAD_RIGHT)
	check(game.local_avatars[1]=="semetei" and game.local_avatars[3]=="bugu","Global P4 changes local seat P2, not local seat P4")
	game.net.connected=false;game.net.room="";game.net.roster=[];game.local_slots=[]
	game.pad_slots={10:0,21:1,12:2,13:3};menu.show_screen("home")
	game.hud.local_button.grab_focus();pad(10,JOY_BUTTON_A)
	check(not game.in_menu and game.sim.players.size()==4,"Home starts actual connected party")
	game.sim.begin_reward();game.sim.reward_options=["stitch","spark","guard"]
	pad(12,JOY_BUTTON_DPAD_RIGHT);pad(12,JOY_BUTTON_A)
	check(game.sim.players[2].reward_choice==1 and not game.sim.players[0].reward,"P3 controls its own bonus")
	pad(12,JOY_BUTTON_B);check(not game.sim.players[2].reward,"Gamepad cancels reward readiness")
	game.return_menu();game.pad_slots.clear();game.keyboard_seat=false
	key(KEY_TAB)
	check(not game.keyboard_seat and game.active_local_seats().is_empty(),"Tab does not join a keyboard player")
	key(KEY_DOWN);key(KEY_DOWN);key(KEY_RIGHT)
	check(menu.roster_buttons[0].has_focus(),"Keyboard arrows reach and cycle its roster seat")
	pad(30,JOY_BUTTON_A);check(game.device_slot(30)==1,"Keyboard first reserves P1, pad joins P2")
	game.hud.local_button.grab_focus();key(KEY_ENTER);check(not game.in_menu,"One remote OK/Enter starts focused action")
	game.local_slots=[2,3];game.run_seats=[0,1]
	check(game.keyboard_slot()==2,"Keyboard seat maps to its authoritative network slot")
	game.pad_slots={40:0,41:1}
	check(game.device_slot(40)==2 and game.device_slot(41)==3,"Local controller seats map to authoritative network slots")
	game.pad_slots={40:0};game.keyboard_seat=false;game.register_pad(41)
	check(game.pad_notice.contains("P4"),"Join notice uses the network player number")
	game.return_menu();game.pad_slots={50:0,51:2};game.keyboard_seat=false
	game.play_connected()
	check(game.sim.players.size()==2 and game.device_slot(51)==1,"Start uses real controllers, excludes empty/disconnected slots")
	check(game.sim.enemies.size()==game.sim.Catalog.wave_spec(1,2,1).kinds.size(),"Wave scales from actual run roster")
	game.on_pad_connection(50,false)
	check(game.sim.players.size()==2,"Run difficulty never shrinks after disconnect")
	game.return_menu();game.pad_slots.clear();game.keyboard_seat=false
	game.net.connected=true;game.net.room="000234";game.net.peer_id="tv";game.net.is_host=true
	game.net.roster=[{"slot":0,"owner":"phone","name":"Телефон"},{"slot":1,"owner":"remote","name":"Другой ТВ"}]
	game.local_slots=[];game.on_network({"type":"start","count":2,"difficulty":1})
	check(game.sim.players.size()==2 and game.run_seats.is_empty(),"Spectator TV contributes no imaginary local player")
	var commands_before: int=game.command_count
	key(KEY_TAB);key(KEY_Q);key(KEY_SPACE);key(KEY_Z)
	check(game.sim.players.size()==2 and game.keyboard_slot()==-1 and game.command_count==commands_before,"Spectator keyboard cannot add or control players mid-run")
	menu.show_screen("server")
	game.hud.url_field.text=" wss://Play.Example.org/ "
	check(menu.store_server_address() and game.relay_url=="play.example.org" and game.hud.url_field.text=="play.example.org","Server field saves only the domain")
	game.hud.url_field.text="host/path"
	check(not menu.store_server_address() and game.relay_url=="play.example.org","Invalid server input cannot replace saved domain")
	print("MENU CONTROLLERS: failures=",failures)
	game.set_process(false);game.arena.stop_audio();await create_timer(.2).timeout
	game.queue_free();await process_frame;quit(1 if failures else 0)
