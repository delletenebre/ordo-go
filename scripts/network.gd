class_name OrdoNetwork
extends Node
const ServerAddress = preload("res://scripts/server_address.gd")
signal message(data: Dictionary)
signal connection_error(reason: String)
var socket: WebSocketPeer
var pending: Dictionary = {}
var is_host := false
var connected := false
var room := ""
var server_url := ""
var slots: Array = [0]
var roster: Array = []
var peer_id := ""
var connect_time := 0.0
var remaining_urls := PackedStringArray()

func connect_room(url: String, code: String, count: int, create: bool, avatars: Array = []) -> void:
	disconnect_room()
	pending = {"type": "create" if create else "join", "code": preload("res://scripts/room_code.gd").normalize(code), "count": count, "avatars": avatars}
	var address := url.strip_edges()
	# Explicit URLs are used by the embedded phone hub, whose protocol is known.
	remaining_urls = PackedStringArray([address]) if address.begins_with("ws://") or address.begins_with("wss://") else ServerAddress.candidates(address)
	try_next_address("Не удалось открыть адрес сервера.")

func try_next_address(reason: String) -> void:
	if socket != null: socket.close()
	socket = null
	while not remaining_urls.is_empty():
		server_url = remaining_urls[0]; remaining_urls.remove_at(0)
		socket = WebSocketPeer.new(); socket.inbound_buffer_size = 524288; socket.outbound_buffer_size = 524288
		socket.heartbeat_interval = 10.0
		connect_time = 0.0
		if socket.connect_to_url(server_url) == OK: return
		socket = null
	disconnect_room(); connection_error.emit(reason)

func _process(dt: float) -> void:
	if socket == null: return
	socket.poll(); connect_time += dt
	var state := socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		remaining_urls.clear()
		if not pending.is_empty():
			send(pending); pending = {}; connected = true
		var receiving_socket := socket
		# Message handlers may close or replace this connection (for example, ended).
		while socket == receiving_socket and receiving_socket.get_available_packet_count() > 0:
			var data = JSON.parse_string(receiving_socket.get_packet().get_string_from_utf8())
			if not data is Dictionary: continue
			match data.get("type", ""):
				"joined": peer_id = str(data.id); room = data.code; slots = data.slots.map(func(slot): return int(slot)); is_host = data.host
				"slots": slots = data.slots.map(func(slot): return int(slot))
				"roster": roster = data.players
				"error": connection_error.emit(data.message)
				"ended": connection_error.emit(data.message)
			message.emit(data)
	elif state == WebSocketPeer.STATE_CLOSED:
		try_next_address("Связь с сервером потеряна. Проверьте адрес и подключение.")
	elif not connected and connect_time > 10.0:
		try_next_address("Сервер не отвечает. Проверьте адрес и подключение.")

func send(data: Dictionary) -> void:
	if socket != null and socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.send_text(JSON.stringify(data))

func disconnect_room() -> void:
	remaining_urls.clear()
	if socket != null: socket.close()
	socket = null; connected = false; room = ""; server_url = ""; pending = {}; roster = []; peer_id = ""; is_host = false
