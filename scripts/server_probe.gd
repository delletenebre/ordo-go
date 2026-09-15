extends Node
## Validate the existing relay protocol without creating or joining a room.
const Address = preload("res://scripts/server_address.gd")
const CODE_ERROR := "Код комнаты: шесть цифр, например 482731."
signal completed(ok: bool, reason: String)
var socket: WebSocketPeer
var remaining := PackedStringArray()
var elapsed := 0.0
var sent := false

func start(address: String) -> void:
	cancel()
	remaining = Address.candidates(address)
	next_address()

func cancel() -> void:
	if socket != null: socket.close()
	socket = null
	remaining.clear()

func next_address() -> void:
	if socket != null: socket.close()
	socket = null
	while not remaining.is_empty():
		var url := remaining[0]; remaining.remove_at(0)
		socket = WebSocketPeer.new()
		elapsed = 0.0; sent = false
		if socket.connect_to_url(url) == OK: return
	finish(false, "Сервер не отвечает. Проверьте адрес и подключение.")

func finish(ok: bool, reason: String = "") -> void:
	cancel()
	completed.emit(ok, reason)

func _process(dt: float) -> void:
	if socket == null: return
	socket.poll(); elapsed += dt
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		if not sent:
			# Both shipped relays reject an empty code before touching room state.
			# A WebSocket upgrade alone does not prove this is an ORDO server.
			socket.send_text(JSON.stringify({"type":"join", "code":"", "count":0}))
			sent = true
		while socket.get_available_packet_count() > 0:
			var data = JSON.parse_string(socket.get_packet().get_string_from_utf8())
			if data is Dictionary and data.get("type") == "error" and data.get("message") == CODE_ERROR:
				finish(true); return
			finish(false, "Сервер ответил неверно. Проверьте адрес игрового сервера."); return
	if socket.get_ready_state() == WebSocketPeer.STATE_CLOSED or elapsed >= 5.0:
		next_address()

func _exit_tree() -> void: cancel()
