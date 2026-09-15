extends SceneTree

const Sim = preload("res://scripts/simulation.gd")
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func positions(sim, bodies: Array) -> Array:
	return bodies.map(func(body): return sim.pos(body))

func check_layout(sim, bodies: Array, label_value: String) -> void:
	var sides := {}
	for body in bodies:
		var point: Vector2 = sim.pos(body)
		check(point.length() + float(body.r) <= Sim.RADIUS, label_value + ": inside wall")
		check(point.length() >= Sim.RADIUS - float(body.r) - 0.2, label_value + ": at perimeter")
		sides[int(floor(fposmod(point.angle() + PI / 4.0, TAU) / (PI / 2.0)))] = true
		for other in sim.players + sim.enemies + sim.stones:
			if body == other: continue
			check(point.distance_to(sim.pos(other)) >= float(body.r) + float(other.r) + 0.1, label_value + ": clear of other bodies")
	if bodies.size() > 1:
		check(sides.size() > 1, label_value + ": spread across different sides")

func _init() -> void:
	for seed_value in 40:
		for count in range(1, 5):
			for mode in 3:
				var sim := Sim.new()
				sim.start(count, mode, seed_value)
				check_layout(sim, sim.players, "Starting players")
				check_layout(sim, sim.enemies, "Starting enemies")
				var initial := positions(sim, sim.players)
				var enemy_initial := positions(sim, sim.enemies)
				var copy := Sim.new()
				copy.start(count, mode, seed_value)
				check(initial == positions(copy, copy.players) and enemy_initial == positions(copy, copy.enemies), "Explicit seed reproduces layout")
				copy.start(count, mode, seed_value + 1)
				check(initial != positions(copy, copy.players) and enemy_initial != positions(copy, copy.enemies), "Different seeds change both teams")
				# Include players still at the edge and players who finished inside.
				if seed_value % 2 == 0:
					for player in sim.players:
						sim.place(player, sim.pos(player) * 0.5)
				var settled := positions(sim, sim.players)
				for wave_value in range(2, 10):
					# Exercise the actual clear -> reward -> next wave transition.
					sim.enemies.clear()
					sim.clear_wave()
					sim.tick(1.8)
					check(sim.phase == "reward" and settled == positions(sim, sim.players), "Clear preserves settled positions")
					for player in sim.players: sim.choose_reward(int(player.id), 0)
					sim.tick(Sim.REWARD_READY_DELAY + 0.01)
					check(sim.wave == wave_value and sim.phase == "plan", "Reward starts next wave")
					check(settled == positions(sim, sim.players), "Wave transition preserves every player position")
					check_layout(sim, sim.enemies, "Wave %d enemies" % wave_value)
	var random_match := Sim.new()
	random_match.start(4)
	var first := positions(random_match, random_match.players)
	random_match.start(4)
	check(first != positions(random_match, random_match.players), "Immediate new matches get fresh random positions")
	print("SPAWN: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
