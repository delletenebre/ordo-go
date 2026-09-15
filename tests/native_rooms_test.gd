extends SceneTree
const Rooms = preload("res://scripts/local_rooms.gd")
var server = Rooms.new()
var messages: Array = []
var failures := 0
func check(value: bool, message: String) -> void:
	if not value: failures+=1;push_error(message)
func receive(id: int, data: Dictionary) -> void:
	# JSON numbers become floats in Godot; test the real wire representation.
	server.receive(id,JSON.parse_string(JSON.stringify(data)))
func _init() -> void:
	server.outgoing.connect(func(id,data):messages.append({"peer":id,"data":data.duplicate(true)}))
	for id in [1,2,3]:server.add_peer(id)
	receive(1,{"type":"create","count":1,"controllerHub":true})
	var code: String=server.peers[1].room
	check(code.length()==4 and code.is_valid_int(),"Controller hub has a separate internal identifier")
	receive(2,{"type":"join","controller":true,"count":1,"avatar":"ilbirs"})
	check(server.peers[2].room==code and server.peers[2].slots==[1],"Controller joins its TV without a code")
	receive(2,{"type":"avatar","slot":1,"avatar":"bugu"})
	check(server.peers[2].avatars==["bugu"],"JSON slot resolves to its own avatar")
	receive(2,{"type":"avatar","slot":0,"avatar":"tulpar"})
	check(server.peers[1].avatars==["manas"],"Phone cannot edit native controller avatar")
	receive(1,{"type":"controller_status","playing":true})
	messages.clear()
	receive(2,{"type":"command","slot":1,"data":{"action":"aim","turn":1,"angle":1.2,"power":8,"spin":-8}})
	check(messages.size()==1 and messages[0].peer==1 and messages[0].data.type=="command","Phone command reaches owning TV with JSON numeric slot")
	if messages.size()==1:check(messages[0].data.data.power==1 and messages[0].data.data.spin==-1,"Native relay clamps aim fields")
	messages.clear()
	receive(2,{"type":"command","slot":0,"data":{"action":"ready","turn":1}})
	check(not messages.any(func(m):return m.data.type=="command"),"Foreign slot rejected")
	receive(3,{"type":"join","controller":true,"count":1})
	check(server.peers[3].room=="","New controller waits until next match")
	receive(1,{"type":"controller_status","playing":false})
	receive(3,{"type":"join","controller":true,"count":1})
	check(server.peers[3].room==code,"Controller can join after match")
	server.remove_peer(2)
	check(server.rooms.has(code) and server.peers[3].room==code,"Controller departure preserves its TV hub")
	server.remove_peer(1)
	check(server.rooms.is_empty() and server.peers[3].room=="","TV departure closes its hub")
	check(Rooms.RoomCode.valid("000042") and Rooms.RoomCode.valid("000000"),"Six-digit codes preserve leading zeroes")
	for invalid in ["HK1234","12345","1234567","12.345"]:
		check(not Rooms.RoomCode.valid(invalid),"Invalid room format is rejected: "+invalid)
	server.add_peer(4);server.add_peer(5)
	receive(4,{"type":"create","count":1})
	var match_code: String=server.peers[4].room
	check(Rooms.RoomCode.valid(match_code),"Native match generates six numeric digits")
	messages.clear();receive(5,{"type":"join","code":"HK1234","count":1})
	check(server.peers[5].room=="" and messages.back().data.message.contains("шесть цифр"),"Native server validates the numeric format")
	receive(5,{"type":"join","code":match_code.substr(0,3)+"-"+match_code.substr(3),"count":1})
	check(server.peers[5].room==match_code,"Native server joins a formatted six-digit code")
	print("NATIVE ROOMS: failures=",failures);quit(1 if failures else 0)
