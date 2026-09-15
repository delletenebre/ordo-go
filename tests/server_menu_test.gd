extends SceneTree
const Main = preload("res://tests/support/test_main.gd")
const Relay = preload("res://scripts/local_relay.gd")
class ReplyRelay extends Relay:
	var wrong := false
	var silent := false
	func send(id: int, data: Dictionary) -> void:
		if silent:return
		super.send(id, {"type":"unrelated"} if wrong else data)
class SavingMain extends Main:
	var saves := 0
	func save_settings() -> void: saves += 1
var failures := 0
var game

func check(value: bool, label: String) -> void:
	if not value: failures += 1; push_error(label)

func until(condition: Callable) -> bool:
	for i in 300:
		if condition.call(): return true
		await create_timer(.01).timeout
	return false

func _init() -> void: call_deferred("run")

func run() -> void:
	game=SavingMain.new();root.add_child(game);await process_frame
	game.set_process(false);game.arena.stop_audio();game.register_pad(10)
	var menu=game.hud.game_menu
	game.relay_url="saved.example.org";menu.show_screen("server")
	await process_frame;await process_frame
	check(menu.server_keys[0].has_focus(), "Server opens with remote keyboard focused")
	game.hud.url_field.clear()
	for character in ".:/-_":
		var keys: Array=menu.server_keys.filter(func(key):return key.text==character)
		check(keys.size()==1, "Dedicated key: "+character)
		keys[0].grab_focus();menu.accept()
	check(game.hud.url_field.text==".:/-_", "Remote enters all requested punctuation")
	menu.move_server_caret(-1);menu.type_server("x");menu.erase_server()
	check(game.hud.url_field.text==".:/-_", "Cursor insertion and backspace preserve adjacent text")
	game.hud.url_field.select_all();menu.type_server("a")
	check(game.hud.url_field.text=="a", "Onscreen key replaces selected text")
	var event:=InputEventKey.new();event.pressed=true;event.unicode=98
	game._input(event)
	check(game.hud.url_field.text=="ab", "Physical typing works while a key is focused")
	game.hud.url_field.grab_focus();event=InputEventKey.new();event.pressed=true;event.keycode=KEY_DOWN
	game._input(event)
	check(not game.hud.url_field.has_focus(), "Down exits address field to keyboard")
	game.hud.url_field.text="host/path";menu.save_server()
	check(menu.screen=="server" and menu.server_status.state=="error" and game.saves==0, "Invalid address shows cross without saving or closing")
	menu.back()
	check(game.hud.url_field.text==game.relay_url, "Back discards unverified draft")
	var relay:=ReplyRelay.new();root.add_child(relay)
	var started: Dictionary=relay.start_server()
	if not started.has("url"):check(false,"Relay starts");quit(1);return
	var address: String=game.ServerAddress.normalize(started.url)
	menu.show_screen("server");game.hud.url_field.text=" ws://"+address+"/ "
	menu.save_server()
	check(menu.server_status.state=="loading" and menu.server_save.disabled and game.saves==0, "Save spins and waits before persistence")
	menu.save_server()
	menu.server_probe._process(5.1)
	check(await until(func():return menu.server_status.state=="success"), "Real relay response displays checkmark")
	check(game.saves==1 and game.relay_url==address and menu.screen=="server", "Validated address saves once and checkmark remains visible")
	check(relay.rooms.rooms.is_empty(), "Probe creates no room and takes no player slots")
	check(await until(func():return menu.screen=="network"), "Success closes after checkmark")
	relay.wrong=true;menu.show_screen("server");menu.save_server();menu.server_probe._process(5.1)
	check(await until(func():return menu.server_status.state=="error"), "Wrong protocol response shows cross")
	check(menu.screen=="server" and game.saves==1 and not menu.server_save.disabled, "Failure stays open and allows retry")
	await process_frame;await process_frame
	var bounds: Rect2=menu.network_window.get_global_rect()
	check(bounds.position.y>=0 and bounds.end.y<=768*game.hud.scale_factor, "Keyboard and error fit above player strip")
	relay.silent=true;menu.save_server();menu.server_probe._process(5.1)
	check(await until(func():return menu.server_probe.sent), "Silent server accepts WebSocket handshake")
	menu.server_probe._process(5.1)
	check(menu.server_status.state=="error" and game.saves==1, "Open socket without protocol reply never succeeds")
	relay.set_process(false);menu.save_server();menu.server_probe._process(5.1);menu.server_probe._process(5.1)
	check(menu.server_status.state=="error" and menu.screen=="server" and game.saves==1, "Timeout retains draft and saved address")
	menu.save_server();menu.back();relay.set_process(true)
	await create_timer(.1).timeout
	check(menu.screen=="network" and menu.server_probe.socket==null and game.saves==1, "Back cancels outstanding probe")
	relay.queue_free();game.queue_free();await process_frame
	print("SERVER MENU: failures=",failures);quit(1 if failures else 0)
