extends SceneTree
const Main = preload("res://scripts/main.gd")
const Network = preload("res://scripts/network.gd")
class TestMain extends Main:
	func save_settings() -> void: pass
var host
var guest
var phone_a
var phone_b
var state_a: Dictionary = {}
var state_b: Dictionary = {}
var failures := 0
func _init() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	if not value: failures += 1; push_error(label)
func until(condition: Callable) -> bool:
	for i in 600:
		if condition.call(): return true
		await create_timer(.02).timeout
	return false
func run() -> void:
	host=TestMain.new();root.add_child(host)
	guest=TestMain.new();root.add_child(guest)
	phone_a=Network.new();root.add_child(phone_a)
	phone_b=Network.new();root.add_child(phone_b)
	phone_a.message.connect(func(data):
		if data.type=="snapshot":state_a=data.state
		if data.type=="controller_wait":state_a={})
	phone_b.message.connect(func(data):
		if data.type=="snapshot":state_b=data.state
		if data.type=="controller_wait":state_b={})
	if not await until(func():return host.controller_hub.net.room!="" and guest.controller_hub.net.room!=""):
		check(false,"Both TV servers start automatically");await finish();return
	check(host.in_menu and guest.in_menu,"No game starts with the controller servers")
	check(host.controller_hub.net.server_url!=guest.controller_hub.net.server_url,"Second TV chooses a free port while first keeps its server")
	check(not host.hud.game_menu.phone_address.text.is_empty(),"Home shows connection address before any game")
	check(not host.hud.game_menu.phone_address.text.contains("127.0.0.1"),"Home screen advertises a phone-accessible IP")
	var http:=HTTPRequest.new();root.add_child(http)
	http.request(host.controller_hub.relay.browser_url)
	var response: Array=await http.request_completed
	check(response[1]==200 and response[3].get_string_from_utf8().contains("controller.js"),"TV serves the browser controller itself")
	http.queue_free()
	host.register_pad(10);guest.register_pad(20)
	if not await until(func():return host.controller_hub.net.roster.size()==1 and guest.controller_hub.net.roster.size()==1):
		check(false,"Native controllers reserve hub seats");await finish();return
	phone_a.connect_room(host.controller_hub.net.server_url,"",1,false,["ilbirs"]);phone_a.pending.controller=true
	phone_b.connect_room(guest.controller_hub.net.server_url,"",1,false,["tulpar"]);phone_b.pending.controller=true
	if not await until(func():return host.phone_slots.size()==1 and guest.phone_slots.size()==1):
		check(false,"Phones join their own TVs before a game");await finish();return
	var code_a: String=phone_a.room;var code_b: String=phone_b.room
	check(host.active_local_seats()==[0,1] and guest.active_local_seats()==[0,1],"Each TV combines one gamepad and one phone")
	# The match uses separate connections. Phone sockets and room codes stay intact.
	host.net.connect_room(host.controller_hub.net.server_url,"",2,true,host.active_avatars())
	if not await until(func():return host.net.room!=""):check(false,"Match creation");await finish();return
	guest.net.connect_room(host.net.server_url,host.net.room,2,false,guest.active_avatars())
	if not await until(func():return host.net.roster.size()==4):check(false,"TVs share all four players");await finish();return
	check(host.hud.game_menu.match_address.text.contains(str(host.controller_hub.relay.socket_listener.get_local_port())),"Other TV gets the WebSocket address, separate from phone HTTP")
	host.play_connected()
	if not await until(func():return not state_a.is_empty() and not state_b.is_empty()):check(false,"Both phones receive match state");await finish();return
	check(phone_a.room==code_a and phone_b.room==code_b,"Joining shared match never reconnects phones")
	check(int(state_a.controller_slots[str(phone_a.slots[0])])==1 and int(state_b.controller_slots[str(phone_b.slots[0])])==3,"Phone identities map to P2 and P4 in the shared game")
	phone_b.send({"type":"command","slot":phone_b.slots[0],"data":{"action":"aim","turn":state_b.turn,"angle":1.23,"power":.8,"spin":-.4}})
	if not await until(func():return is_equal_approx(host.sim.players[3].angle,1.23)):
		check(false,"Guest phone aims through its TV to authoritative host")
	phone_b.send({"type":"command","slot":phone_b.slots[0],"data":{"action":"ability","turn":state_b.turn}})
	phone_b.send({"type":"command","slot":phone_b.slots[0],"data":{"action":"ready","turn":state_b.turn}})
	check(await until(func():return host.sim.players[3].ready and host.sim.players[3].ability),"Guest phone controls ability and readiness")
	check(is_equal_approx(host.sim.players[3].power,.8) and is_equal_approx(host.sim.players[3].spin,-.4),"Guest phone power and spin survive both network hops")
	check(not host.sim.players[0].ready and not host.sim.players[1].ready and not host.sim.players[2].ready,"Guest phone cannot control other players")
	phone_a.send({"type":"command","slot":phone_a.slots[0],"data":{"action":"ready","turn":state_a.turn}})
	check(await until(func():return host.sim.players[1].ready),"Host phone controls its own player")
	host.sim.begin_reward();host.sim.reward_options=["stitch","spark","guard"]
	check(await until(func():return state_b.get("phase")=="reward"),"Phone sees TV reward phase")
	phone_b.send({"type":"command","slot":phone_b.slots[0],"data":{"action":"reward_focus","turn":state_b.turn,"choice":2}})
	check(await until(func():return guest.reward_choices.get(3,-1)==2 and host.reward_choices.get(3,-1)==2),"Phone stick focuses gift on both TVs through both network hops")
	check(guest.selected==3 and host.selected==3 and not host.sim.players[3].reward,"Focus identifies P4 without confirming a gift")
	phone_b.send({"type":"command","slot":phone_b.slots[0],"data":{"action":"reward","turn":state_b.turn,"choice":2}})
	check(await until(func():return host.sim.players[3].reward_choice==2),"Phone A confirms the focused gift")
	phone_b.send({"type":"command","slot":phone_b.slots[0],"data":{"action":"cancel","turn":state_b.turn}})
	check(await until(func():return not host.sim.players[3].reward),"Phone B cancels gift readiness")
	host.return_menu()
	check(await until(func():return guest.in_menu and state_a.is_empty() and state_b.is_empty()),"Return to menu puts both phones back in waiting mode")
	check(phone_a.connected and phone_b.connected and phone_a.room==code_a and phone_b.room==code_b,"Phones remain connected between matches")
	phone_b.send({"type":"avatar","slot":phone_b.slots[0],"avatar":"bugu"})
	check(await until(func():return guest.local_avatars[1]=="bugu"),"Phone can change avatar after shared match ends")
	# A later standalone game reuses exactly the same phone controller connection.
	guest.on_pad_connection(20,false)
	guest.play_connected()
	check(await until(func():return not state_b.is_empty() and state_b.players.size()==1),"Same phone plays alone in the next local game without reconnecting")
	check(int(state_b.controller_slots[str(phone_b.slots[0])])==0,"Persistent phone remaps to P1 after gamepad leaves")
	phone_b.send({"type":"command","slot":phone_b.slots[0],"data":{"action":"aim","turn":state_b.turn,"angle":.75,"power":.6}})
	phone_b.send({"type":"command","slot":phone_b.slots[0],"data":{"action":"ready","turn":state_b.turn}})
	check(await until(func():return guest.sim.players[0].ready and is_equal_approx(guest.sim.players[0].power,.6)),"Phone controls its remapped player in standalone play")
	print("PHONE HUB: failures=",failures)
	await finish()
func finish() -> void:
	var ports: Array=[int(host.controller_hub.relay.server_url.get_slice(":",2)),int(guest.controller_hub.relay.server_url.get_slice(":",2)),int(host.controller_hub.relay.browser_url.get_slice(":",2)),int(guest.controller_hub.relay.browser_url.get_slice(":",2))]
	phone_a.disconnect_room();phone_b.disconnect_room();phone_a.queue_free();phone_b.queue_free()
	for game in [host,guest]:game.arena.stop_audio();game.net.disconnect_room();game.queue_free()
	await process_frame
	await create_timer(.15).timeout
	for port in ports:
		if port<=0:continue
		var probe:=TCPServer.new()
		check(probe.listen(port,"127.0.0.1")==OK,"Closing TV releases its owned server port")
		probe.stop()
	quit(1 if failures else 0)
