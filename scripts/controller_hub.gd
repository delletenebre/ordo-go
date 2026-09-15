extends Node
const LocalRelay = preload("res://scripts/local_relay.gd")
const Network = preload("res://scripts/network.gd")
signal changed
signal command_received(slot: int, data: Dictionary)
var relay = LocalRelay.new()
var net = Network.new()
var status := "Запускаем подключение телефонов…"
var native_avatars: Array = []
var playing := false

func _ready() -> void:
	add_child(relay); add_child(net)
	net.message.connect(receive)
	net.connection_error.connect(func(reason): status=reason; changed.emit())

func start() -> void:
	var result: Dictionary = await relay.start_server()
	if result.has("error"): status=result.error; changed.emit(); return
	net.connect_room(result.url, "", native_avatars.size(), true, native_avatars)
	net.pending.controllerHub = true

func set_native_avatars(avatars: Array) -> void:
	if native_avatars == avatars: return
	native_avatars = avatars.duplicate()
	if not net.pending.is_empty(): net.pending.count=avatars.size(); net.pending.avatars=avatars
	if net.connected and net.room != "": net.send({"type":"seats", "count":avatars.size(), "avatars":avatars})

func receive(data: Dictionary) -> void:
	match data.get("type", ""):
		"joined":
			status=""; net.send({"type":"seats", "count":native_avatars.size(), "avatars":native_avatars}); changed.emit()
		"roster", "slots": changed.emit()
		"command": command_received.emit(int(data.slot), data.data)

func set_playing(value: bool) -> void:
	playing = value
	if net.room != "": net.send({"type":"controller_status", "playing":value})

func publish(state: Dictionary, slots: Dictionary) -> void:
	if net.room == "": return
	state.controller_slots = slots
	net.send({"type":"snapshot", "state":state})

func _exit_tree() -> void: net.disconnect_room()
