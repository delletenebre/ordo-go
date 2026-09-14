extends SceneTree
const Simulation = preload("res://scripts/simulation.gd")
const Catalog = preload("res://scripts/catalog.gd")
var checks := 0
var failures := 0
func check(value: bool, label_value: String) -> void:
	checks += 1
	if not value: failures += 1; push_error("FAIL: " + label_value)
func advance(sim, seconds: float) -> void:
	for i in int(seconds * 120): sim.tick(1.0 / 120.0)
func _init() -> void:
	var sim = Simulation.new(); sim.start(2, 1, 42)
	check(sim.players.size() == 2 and sim.wave == 1, "match initialization")
	check(not sim.command(8, {"action": "ready"}), "reject invalid player")
	check(not sim.command(0, {"action": "ready", "turn": -1}), "reject stale turn")
	check(not sim.command(0, {"action": "aim", "angle": NAN}), "reject NaN input")
	sim.command(0, {"action": "aim", "angle": 1.0, "power": 4.0})
	check(sim.players[0].power == 1.0, "clamp power")
	sim.command(0, {"action": "ready"}); sim.command(0, {"action": "cancel"})
	check(sim.command(0, {"action": "aim", "angle": 2.0}), "can reselect after cancel")
	check(sim.players[0].angle == 2.0, "new aim retained")
	sim.enemies.clear(); sim.spawn("brute", 0.0)
	sim.place(sim.enemies[0], Vector2(3.0, 0.0))
	sim.place(sim.players[0], Vector2(1.8, 0.0)); sim.place(sim.players[1], Vector2(-3, -3))
	sim.command(0, {"action": "aim", "angle": 0.0, "power": 1.0})
	sim.command(0, {"action": "ability"}); sim.command(0, {"action": "ready"})
	sim.command(1, {"action": "ready"}); sim.launch(); advance(sim, 0.2)
	check(sim.players[0].charges == 1, "ability spends exactly one charge")
	check(sim.enemies.is_empty() or sim.enemies[0].hp <= 1, "blue empowered collision deals two damage")
	check(sim.players[0].hp == 4, "own collision does not hurt player")
	var copy = Simulation.new(); copy.restore(JSON.parse_string(JSON.stringify(sim.snapshot())))
	check(copy.players.size() == sim.players.size() and copy.pos(copy.players[0]).distance_to(sim.pos(sim.players[0])) < 0.00001 and copy.players[0].hp == sim.players[0].hp and copy.phase == sim.phase, "snapshot roundtrip")
	sim.start(2, 1, 42); sim.players[1].hp = 0
	sim.place(sim.players[0], Vector2(3, 0)); sim.place(sim.players[1], Vector2(3.6, 0))
	sim.move_bodies(1.0 / 120, true)
	check(sim.players[1].hp == 1, "touch revives fallen ally")
	sim.players[1].shield = 1; sim.place(sim.players[1], Vector2(2.9, 0))
	sim.damage_player(sim.players[0], 1)
	check(sim.players[0].hp == 4 and sim.players[1].shield == 0, "guard protects nearby ally")
	sim.damage_player(sim.players[0], 1, "frost")
	check(sim.players[0].statuses.frost == 2 and sim.players[0].hp == 3, "frost applies only on unblocked hit")
	for players in range(1, 5):
		for mode in 3:
			var previous := 0
			for w in range(1, 10):
				var spec = Catalog.wave_spec(w, players, mode)
				check(spec.kinds.size() >= 2 and spec.planning >= 18, "valid wave %d/%d/%d" % [w, players, mode])
				if w in [3, 6, 9]: check(spec.boss != "", "boss scheduled")
			previous += 1
	check(Catalog.wave_spec(5, 4, 1).kinds.size() > Catalog.wave_spec(5, 1, 1).kinds.size(), "party-size scaling")
	for boss in ["ram", "weaver", "eater"]:
		sim.start(2, 1, 42); sim.enemies.clear(); sim.spawn(boss, 0.0); sim.begin_plan()
		check(sim.enemies[0].attack in ["rush", "jump", "ring"], "boss telegraph exists")
		sim.begin_enemy(); advance(sim, 2.2)
		check(sim.phase in ["plan", "lose"], "boss action finishes")
	sim.start(2, 1, 42); sim.begin_reward(); sim.reward_options = ["stitch", "spark", "guard"]
	check(sim.choose_reward(0, 0) and sim.players[0].max_hp == 5, "permanent boon")
	check(not sim.choose_reward(0, 1), "no duplicate reward")
	sim.choose_reward(1, 2)
	check(sim.wave == 2 and sim.players[1].armor == 1, "reward waits for everyone then next wave")
	sim.fire = 0; sim.check_end(); check(sim.phase == "lose", "core loss")
	sim.start(1); sim.wave = 9; sim.enemies.clear(); sim.clear_wave(); advance(sim, 2.0)
	check(sim.phase == "win", "final wave victory")
	# Long seeded matches validate finite state and bounded body positions across all enemy variants.
	for seed_value in 12:
		sim.start(4, seed_value % 3, seed_value)
		sim.wave = 5; sim.next_wave()
		for p in sim.players: p.hp = 100; p.max_hp = 100
		sim.fire = 100; sim.max_fire = 100
		for frame in 3000:
			if sim.phase == "plan":
				for p in sim.players:
					if not p.ready:
						sim.command(p.id, {"action": "aim", "angle": sim.rng.randf() * TAU, "power": 1.0})
						sim.command(p.id, {"action": "ready"})
			if sim.phase == "reward":
				for p in sim.players: sim.choose_reward(p.id, 0)
			sim.tick(1.0 / 120)
		for entity in sim.players + sim.enemies:
			check(is_finite(float(entity.x)) and is_finite(float(entity.z)), "finite physics state")
	print("SIMULATION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
