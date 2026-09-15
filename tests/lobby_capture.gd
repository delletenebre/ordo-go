extends SceneTree
const Main=preload("res://tests/support/test_main.gd")
func _init() -> void:call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://work/rewards")
	var game=Main.new();root.add_child(game);await process_frame
	game.set_process(false);game.register_pad(10);game.register_pad(11);game.pad_notice_time=0;game.arena.stop_audio()
	var menu=game.hud.game_menu
	var modes: Array=["network","join","keyboard","roster","lobby"]
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--mode="):modes=[argument.trim_prefix("--mode=")]
	if modes==["server-states"]:modes=["server","server-loading","server-success","server-error"]
	for mode in modes:
		menu.show_screen("home" if mode in ["roster","controllers"] else ("join" if mode=="keyboard" else ("server" if mode.begins_with("server-") else mode)))
		if mode.begins_with("server-"):
			var status: String=mode.trim_prefix("server-")
			menu.set_server_checking(status in ["loading","success"]);menu.server_status.state=status
			game.hud.message_label.text={"loading":"Проверяем сервер…","success":"Сервер доступен. Адрес сохранён.","error":"Сервер не отвечает. Проверьте адрес и подключение."}[status]
			menu.refresh()
			if status=="error":menu.server_save.grab_focus()
		if mode in ["controllers","lobby"] and game.controller_hub==null:
			game.controller_hub=preload("res://scripts/controller_hub.gd").new();game.add_child(game.controller_hub)
			game.controller_hub.net.server_url="ws://127.0.0.1:8788";game.controller_hub.net.room="009042";game.controller_hub.status="";game.controller_hub.relay.browser_url="http://127.0.0.1:8787"
		if mode=="controllers":
			game.net.server_url="ws://127.0.0.1:8788";game.net.room="482731";menu.update_phone_connection()
		if mode=="roster":menu.menu_device=10;menu.focus_roster()
		if mode=="lobby":
			game.net.server_url="ws://127.0.0.1:8788";game.net.connected=true;game.net.room="482731";game.net.peer_id="tv-a";game.net.is_host=true
			game.net.roster=[{"slot":0,"owner":"tv-a","avatar":"manas"},{"slot":1,"owner":"tv-a","avatar":"kanykei"},{"slot":2,"owner":"tv-b","avatar":"ilbirs"},{"slot":3,"owner":"tv-b","avatar":"tulpar"}]
			game.local_slots=[0,1];game.hud.update_lobby()
			menu.menu_device=10;menu.focus_roster()
		for i in 25:game.arena.render_state(game.sim,1.0/60);await process_frame
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://work/rewards/setup-%s.png"%mode)
		var panel = menu.phone_panel if mode=="controllers" else menu.network_window
		print(mode," bounds: ",panel.get_global_rect())
		var phone_bounds: Rect2=menu.phone_panel.get_global_rect()
		if phone_bounds.end.x>640*game.hud.scale_factor or phone_bounds.end.y>958*game.hud.scale_factor:push_error("Phone information exceeds the left menu wing");quit(1);return
		if mode!="controllers" and panel.get_global_rect().end.y>768*game.hud.scale_factor:push_error("Network panel overlaps players");quit(1);return
	game.arena.stop_audio();game.queue_free();await process_frame;quit()
