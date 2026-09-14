extends SceneTree
const Network = preload("res://scripts/network.gd")
const Simulation = preload("res://scripts/simulation.gd")
var net
var sim = Simulation.new()
var host := false
var manual := false
var reported := false
var file := ""
var url := ""
var started := false
var elapsed := 0.0
var send_time := 0.0
var commands := 0
var snapshots := 0
var sent_ready := false
var resolving := false
func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--host": host = true
		if arg == "--manual": manual = true
		if arg.begins_with("--code-file="): file = arg.trim_prefix("--code-file=")
		if arg.begins_with("--url="): url = arg.trim_prefix("--url=")
	call_deferred("setup")
func setup() -> void:
	net = Network.new(); root.add_child(net); net.message.connect(receive)
	net.connection_error.connect(func(reason):
		if not resolving: push_error(reason); quit(1))
	var code := "" if host else FileAccess.get_file_as_string(file)
	net.connect_room(url, code, 1, host)
func receive(data: Dictionary) -> void:
	match data.type:
		"joined":
			if host:
				var handle := FileAccess.open(file, FileAccess.WRITE); handle.store_string(data.code); handle.close()
		"roster":
			if host and net.roster.size() == 2 and not started: net.send({"type": "start", "difficulty": 1})
		"start":
			started = true
			if host:
				sim.start(int(data.count), 1, 42); sim.command(0, {"action": "ready"})
		"command":
			if host: commands += 1; sim.command(int(data.slot), data.data)
		"snapshot":
			if not host:
				snapshots += 1; sim.restore(data.state)
				if not sent_ready:
					sent_ready = true
					net.send({"type": "command", "slot": int(net.slots[0]), "data": {"action": "ready", "turn": sim.turn}})
				if sim.phase == "resolve":
					resolving = true
					if snapshots > 5: print("CLIENT_OK snapshots=", snapshots, " players=", sim.players.size()); quit(0)
func _process(dt: float) -> bool:
	elapsed += dt
	if elapsed > (300 if manual else 12): push_error("Network integration timeout"); quit(1)
	if started and host:
		sim.tick(minf(dt, 0.05)); send_time += dt
		if send_time > 0.05:
			send_time = 0; net.send({"type": "snapshot", "state": sim.snapshot()})
		if sim.phase == "resolve" and commands > 0:
			resolving = true
			if sim.phase_time > 0.4 and not reported:
				reported = true; print("HOST_OK commands=", commands)
				if not manual: quit(0)
	return false
