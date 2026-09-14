class_name OrdoNetwork
extends Node
signal message(data: Dictionary)
signal connection_error(reason: String)
var socket: WebSocketPeer
var pending: Dictionary = {}
var is_host := false
var connected := false
var room := ""
var slots: Array = [0]
var roster: Array = []
var connect_time := 0.0

func connect_room(url: String, code: String, count: int, create: bool) -> void:
	disconnect_room()
	socket = WebSocketPeer.new(); socket.inbound_buffer_size = 524288; socket.outbound_buffer_size = 524288
	socket.heartbeat_interval = 10.0
	pending = {"type": "create" if create else "join", "code": code.strip_edges().to_upper(), "count": count, "name": "Хранитель"}
	var result := socket.connect_to_url(url.strip_edges())
	if result != OK:
		socket = null; connection_error.emit("Не удалось открыть адрес сервера."); return
	connect_time = 0.0

func _process(dt: float) -> void:
	if socket == null: return
	socket.poll(); connect_time += dt
	var state := socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not pending.is_empty():
			send(pending); pending = {}; connected = true
		while socket.get_available_packet_count() > 0:
			var data = JSON.parse_string(socket.get_packet().get_string_from_utf8())
			if not data is Dictionary: continue
			match data.get("type", ""):
				"joined": room = data.code; slots = data.slots.map(func(slot): return int(slot)); is_host = data.host
				"slots": slots = data.slots.map(func(slot): return int(slot))
				"roster": roster = data.players
				"error": connection_error.emit(data.message)
				"ended": connection_error.emit(data.message)
			message.emit(data)
	elif state == WebSocketPeer.STATE_CLOSED:
		socket = null; connected = false; connection_error.emit("Связь с сервером потеряна. Проверьте адрес и подключение.")
	elif not connected and connect_time > 10.0:
		disconnect_room(); connection_error.emit("Сервер не отвечает. Проверьте адрес и подключение.")

func send(data: Dictionary) -> void:
	if socket != null and socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.send_text(JSON.stringify(data))

func disconnect_room() -> void:
	if socket != null: socket.close()
	socket = null; connected = false; room = ""; pending = {}; roster = []
