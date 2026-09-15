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
	net.connect_room(url, code, 2, host, ["manas","kanykei"] if host else ["ilbirs","tulpar"])
func receive(data: Dictionary) -> void:
	match data.type:
		"joined":
			if host:
				var handle := FileAccess.open(file, FileAccess.WRITE); handle.store_string(data.code); handle.close()
		"roster":
			if host and net.roster.size() == 4 and not started and not data.get("started",false): net.send({"type": "start", "difficulty": 1})
		"start":
			started = true
			if host:
				sim.start(int(data.count), 1, 42)
				for slot in net.slots: sim.command(int(slot), {"action":"ready"})
				for player in net.roster: sim.players[int(player.slot)].avatar=player.avatar
		"command":
			if host: commands += 1; sim.command(int(data.slot), data.data)
		"snapshot":
			if not host:
				snapshots += 1; sim.restore(data.state)
				if sim.players.size()!=4 or sim.players[2].get("avatar","")!="ilbirs" or sim.players[3].get("avatar","")!="tulpar":
					push_error("Two-TV avatars missing from snapshot");quit(1);return
				if sim.stones.size()!=4 or sim.stones.filter(func(stone):return stone.get("collector",false)).size()!=2 or sim.rune_seed!=42:
					push_error("Authoritative rune state missing from network snapshot");quit(1);return
				if not sent_ready:
					sent_ready = true
					for slot in net.slots: net.send({"type":"command","slot":int(slot),"data":{"action":"ready","turn":sim.turn}})
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
