extends SceneTree
const Main=preload("res://tests/support/test_main.gd")
# Integration fixtures must not overwrite the player's server or avatars.
class TestMain extends Main:
	func save_settings() -> void: pass
const Network=preload("res://scripts/network.gd")
var game
var phone
var failures:=0
func check(value:bool,label:String)->void:
	if not value:failures+=1;push_error(label)
func until(condition:Callable)->bool:
	for i in 500:
		if condition.call():return true
		await create_timer(.01).timeout
	return false
func _init()->void:call_deferred("run")
func run()->void:
	game=TestMain.new();root.add_child(game);phone=Network.new();root.add_child(phone);await process_frame
	game.local_avatars=["manas","kanykei","ilbirs","bugu"]
	var url: String=game.relay_url
	game.register_pad(10)
	var menu=game.hud.game_menu
	menu.show_screen("network");game.hud.connect_button.grab_focus();menu.accept()
	check(menu.screen=="network" and menu.busy,"Create Game starts connection directly from friends menu")
	if not await until(func():return game.net.room!=""):push_error("Relay unavailable");quit(1);return
	check(menu.screen=="lobby" and game.hud.room_label.text==game.net.room,"Created room opens lobby with its code")
	phone.connect_room(url,game.net.room,1,false,["ilbirs"])
	check(await until(func():return game.net.roster.size()==2),"Room sees controller plus WebSocket player")
	game.register_pad(11)
	check(await until(func():return game.net.roster.size()==3 and game.local_slots.size()==2),"A new controller updates the existing room")
	check(game.menu_roster().size()==3,"Main menu renders local and remote players together")
	menu.menu_device=11;menu.focus_roster()
	for i in 6:menu.navigate(Vector2.RIGHT)
	check(menu.roster_buttons[int(game.local_slots[1])].has_focus(),"Avatar focus follows the controller through interleaved network slots")
	check(await until(func():return phone.roster.any(func(player):return player.avatar=="bugu")),"Changing local P2 avatar reaches remote phone")
	game.play_connected()
	check(await until(func():return not game.in_menu),"Host starts mixed room")
	check(game.sim.players.size()==3 and game.run_seats.size()==2,"Run has exactly two controllers and one phone")
	check(game.sim.players[0].avatar=="manas" and game.sim.players[1].avatar=="bugu" and game.sim.players[2].avatar=="ilbirs","Avatars follow owners when server compacts player slots")
	check(game.device_slot(10)==0 and game.device_slot(11)==1 and phone.slots==[2],"Inputs map to the final compact roster")
	phone.send({"type":"command","slot":2,"data":{"action":"aim","angle":1.23,"power":.8,"spin":-.4,"turn":game.sim.turn}})
	check(await until(func():return is_equal_approx(game.sim.players[2].angle,1.23)),"Phone aim reaches host")
	check(is_equal_approx(game.sim.players[2].power,.8) and is_equal_approx(game.sim.players[2].spin,-.4),"Phone power and spin reach host")
	phone.send({"type":"command","slot":2,"data":{"action":"ability","turn":game.sim.turn}})
	phone.send({"type":"command","slot":2,"data":{"action":"ready","turn":game.sim.turn}})
	check(await until(func():return game.sim.players[2].ready and game.sim.players[2].ability),"Phone ability and shot readiness reach host")
	check(not game.sim.players[0].ready and not game.sim.players[1].ready,"Phone controls only its own shot")
	game.sim.begin_reward();game.sim.reward_options=["stitch","spark","guard"]
	phone.send({"type":"command","slot":2,"data":{"action":"reward","choice":1,"turn":game.sim.turn}})
	check(await until(func():return game.sim.players[2].reward),"Phone reward reaches its own player")
	check(game.sim.players[2].reward_choice==1 and not game.sim.players[0].reward,"Phone does not select a controller's reward")
	print("MIXED LOBBY: failures=",failures)
	game.set_process(false);game.arena.stop_audio();game.net.disconnect_room();phone.disconnect_room()
	await create_timer(.2).timeout;game.queue_free();phone.queue_free();await process_frame;quit(1 if failures else 0)
