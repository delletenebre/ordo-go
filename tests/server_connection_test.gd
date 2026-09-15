extends SceneTree
const Address = preload("res://scripts/server_address.gd")
const Network = preload("res://scripts/network.gd")
const Relay = preload("res://scripts/local_relay.gd")
var failures := 0
var errors: Array[String] = []

func check(value: bool, label: String) -> void:
	if not value: failures += 1; push_error(label)

func until(condition: Callable) -> bool:
	for i in 300:
		if condition.call(): return true
		await create_timer(.01).timeout
	return false

func _init() -> void: call_deferred("run")

func run() -> void:
	for input in ["play.example.org", " WSS://Play.Example.org/ ", "ws://play.example.org", "https://play.example.org/"]:
		check(Address.normalize(input)=="play.example.org", "Old URLs and pasted addresses become a domain")
	check(Address.candidates("play.example.org")==PackedStringArray(["wss://play.example.org", "ws://play.example.org"]), "TLS is always attempted first")
	check(Address.candidates("192.168.1.20:8788")[1]=="ws://192.168.1.20:8788", "Explicit port survives both attempts")
	check(Address.valid("[::1]:8788"), "Local IPv6 address is accepted")
	for input in ["", "host/path", "host?token=secret", "user@host", "host:0", "host:65536", "host name"]:
		check(Address.candidates(input).is_empty(), "Invalid address rejected: " + input)
	var relay := Relay.new();root.add_child(relay)
	var started: Dictionary = relay.start_server()
	if not started.has("url"): check(false, "Local relay starts");quit(1);return
	var address := Address.normalize(str(started.url))
	var net := Network.new();root.add_child(net)
	net.connection_error.connect(func(reason: String): errors.append(reason))
	net.connect_room(address,"",1,true,["manas"])
	check(net.server_url=="wss://"+address, "Connection starts with TLS")
	# Advance the handshake deadline without waiting ten seconds in the test.
	net._process(10.1)
	check(net.server_url=="ws://"+address and errors.is_empty(), "TLS timeout silently falls back to plain WebSocket")
	check(await until(func(): return not net.room.is_empty()), "Fallback creates the room over a real socket")
	check(net.roster.size()==1 and net.roster[0].avatar=="manas", "Room request and avatar survive retry")
	check(relay.rooms.rooms.size()==1, "Retry creates exactly one room")
	check(net.remaining_urls.is_empty(), "Established connection cannot switch protocols")
	net.disconnect_room()
	net.connect_room(address,"",1,true)
	net.disconnect_room();net._process(20.0)
	check(net.socket==null and net.remaining_urls.is_empty() and errors.is_empty(), "Cancel discards all retries")
	# Force both timeout deadlines while preventing the server from answering.
	relay.set_process(false)
	net.connect_room(address,"",1,true)
	net._process(10.1);net._process(10.1)
	check(errors.size()==1 and net.socket==null and net.pending.is_empty(), "Both failures report one final error and clear request")
	errors.clear();relay.set_process(true)
	net.connect_room(str(started.url),"000000",1,false)
	check(await until(func(): return not errors.is_empty()), "Server rejection reaches the UI")
	check(net.server_url==str(started.url) and net.remaining_urls.is_empty(), "Room rejection does not reconnect")
	net.disconnect_room();net.queue_free();relay.queue_free();await process_frame
	print("SERVER CONNECTION: failures=",failures)
	quit(1 if failures else 0)
