extends SceneTree
const Sim = preload("res://scripts/simulation.gd")
var checks := 0
var failures := 0

func _init() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)

func arena():
	var sim := Sim.new(); sim.start(1, 1, 42)
	sim.enemies.clear(); sim.stones.clear(); sim.pickups.clear(); sim.events.clear()
	return sim

func enemy_at(sim, point: Vector2, hp: int = 1) -> Dictionary:
	sim.spawn("brute", 0)
	var enemy: Dictionary = sim.enemies[-1]
	enemy.hp = hp; enemy.max_hp = hp
	sim.place(enemy, point)
	return enemy

func events_of(sim, kind: String) -> Array:
	return sim.events.filter(func(e): return e.kind == kind)

func run() -> void:
	# Damage is additive, capped, and retains existing class/reward modifiers.
	for rebounds in [0, 1, 2, 9]:
		var sim = arena(); var p: Dictionary = sim.players[0]
		var e := enemy_at(sim, Vector2(3, 0), 20)
		p.ricochets = rebounds
		sim.player_hit(p, e, "damage")
		check(e.hp == 20 - (1 + mini(rebounds, 2)), "Base/one/two/many ricochets deal 1/2/3/3")
	var sim = arena(); var p: Dictionary = sim.players[0]
	var e := enemy_at(sim, Vector2(3, 0), 20)
	p.ricochets = 2; p.damage = 1; p.statuses.weak = 2; p.boost = true
	sim.player_hit(p, e, "modifiers")
	check(e.hp == 16 and not p.boost, "Ricochet adds to reward, weakness and one-use ability")

	# Real wall reflection, followed by a lethal two-damage contact.
	sim = arena(); p = sim.players[0]; e = enemy_at(sim, Vector2(3.8, 0), 2)
	sim.place(p, Vector2(5.5, 0)); p.angle = 0; p.power = 1; p.ready = true
	sim.launch()
	for step in 90:
		sim.move_bodies(Sim.STEP, true)
		if e.hp <= 0: break
	check(e.hp == 0 and p.ricochets == 1, "Actual bank shot kills a two-HP enemy")
	check(is_equal_approx(sim.vel(p).length(), 18.0) and sim.vel(p).x < 0, "Kill restores full speed along incoming bank direction")
	check(events_of(sim, "kill_boost").size() == 1 and sim.kills == 1, "One boost and one reward per lethal contact")

	# Hearth and uncharged rune stone both count, enemy-turn pushes do not.
	for stone in [false, true]:
		sim = arena(); p = sim.players[0]
		var center := Vector2(3, 0) if stone else Vector2.ZERO
		var radius := .44 if stone else Sim.CORE_RADIUS
		if stone: sim.stones = [{"id":0, "x":center.x, "z":center.y, "r":radius}]
		sim.place(p, center + Vector2(radius + float(p.r) + .01, 0)); sim.velocity(p, Vector2.LEFT * 8)
		sim.move_bodies(Sim.STEP, true)
		check(p.ricochets == 1 and sim.vel(p).x > 0, "Hearth/stone reflection earns ricochet bonus")
		sim.place(p, center + Vector2(radius + float(p.r) + .01, 0)); sim.velocity(p, Vector2.LEFT * 8)
		sim.move_bodies(Sim.STEP, false)
		check(p.ricochets == 1, "Enemy phase cannot charge ricochet damage")
		sim.record_ricochet(p, .1)
		check(p.ricochets == 1, "Slow resting contacts cannot charge damage")

	# Separation outside the rim must not reflect inward motion or farm damage.
	sim = arena(); p = sim.players[0]
	sim.place(p, Vector2(5.8, 0)); sim.velocity(p, Vector2.LEFT * 4)
	sim.move_bodies(Sim.STEP, true)
	check(p.ricochets == 0 and sim.vel(p).x < 0, "Wall correction preserves inward motion")

	# Surviving enemies power the next hit; this contact remains direct damage.
	sim = arena(); p = sim.players[0]; e = enemy_at(sim, Vector2(2.8, 2), 3)
	sim.place(p, Vector2(1.9, 2)); sim.velocity(p, Vector2.RIGHT * 8)
	sim.move_bodies(Sim.STEP, true)
	check(e.hp == 2 and p.ricochets == 1 and events_of(sim, "kill_boost").is_empty(), "Surviving enemy charges next contact without kill boost")
	check(sim.vel(p).x < 0, "Surviving heavy enemy retains physical reflection")

	# Three separate kills re-launch the same low-power throw without aiming anew.
	sim = arena(); p = sim.players[0]
	for x in [-1.8, 0.0, 1.8]: enemy_at(sim, Vector2(x, 2.5))
	sim.place(p, Vector2(-3, 2.5)); p.angle = 0; p.power = .15; p.ready = true
	sim.launch()
	for step in 100:
		sim.pickups.clear()
		sim.move_bodies(Sim.STEP, true)
		check(sim.vel(p).is_finite() and sim.vel(p).length() <= 24.001, "Kill chains stay finite and speed bounded")
		if sim.kills == 3: break
	check(sim.kills == 3 and events_of(sim, "kill_boost").size() == 3, "Low-power throw punches through three enemies")
	check(p.power == .15 and p.charges == 2 and not p.boost, "Kill boost does not refill ability or rewrite chosen power")

	# A cooperative bonus can be the lethal damage; corpse contacts cannot repeat it.
	sim = arena(); p = sim.players[0]; e = enemy_at(sim, Vector2(3, 2), 2)
	sim.phase_time = 4.4
	sim.resolve_player_hit(p, e, "team", Vector2.RIGHT * 4, Vector2.RIGHT, 1)
	check(e.hp == 0 and events_of(sim, "kill_boost").size() == 1, "Team bonus kill also boosts its finisher")
	check(is_equal_approx(sim.resolve_deadline, 5.9), "Late kill leaves 1.5 seconds for continued flight")
	sim.resolve_player_hit(p, e, "corpse", Vector2.RIGHT * 4, Vector2.RIGHT, 1)
	check(events_of(sim, "kill_boost").size() == 1, "Same-step corpse contact cannot award another boost")
	e = enemy_at(sim, Vector2(3, 2)); sim.phase_time = 7.8
	sim.resolve_player_hit(p, e, "cap", Vector2.RIGHT * 24, Vector2.RIGHT, 0)
	check(sim.resolve_deadline == 8 and is_equal_approx(sim.vel(p).length(), 24), "Chain duration caps at eight seconds and keeps faster rune velocity")

	p.speed = 1.15; p.statuses.frost = 2
	e = enemy_at(sim, Vector2(3, 2))
	sim.resolve_player_hit(p, e, "frost", Vector2.RIGHT * 3, Vector2.RIGHT, 0)
	check(is_equal_approx(sim.vel(p).length(), 18 * 1.15 * .6), "Full recharge respects speed rewards and cold")
	p.ricochets = 2
	var remote := Sim.new(); remote.restore(JSON.parse_string(JSON.stringify(sim.snapshot())))
	check(remote.players[0].ricochets == 2 and remote.resolve_deadline == 8 and events_of(remote, "kill_boost").size() == 3, "Network snapshot preserves chain state and effects")
	sim.begin_plan()
	check(p.ricochets == 0 and sim.resolve_deadline == Sim.RESOLVE_TIME, "New turn resets damage chain and flight deadline")
	p.ricochets = 2; p.ready = true; sim.launch()
	check(p.ricochets == 0, "Launch starts a fresh ricochet chain")
	# Exercise the actual phase transition, not just the stored deadline.
	sim = arena(); p = sim.players[0]
	e = enemy_at(sim, Vector2(3, 2))
	sim.phase = "resolve"; sim.phase_time = 4.4
	sim.resolve_player_hit(p, e, "late", Vector2.RIGHT * 4, Vector2.RIGHT, 0)
	enemy_at(sim, Vector2(-4, -2), 50)
	sim.place(p, Vector2(-3, 2.5)); sim.phase_time = 4.6
	sim.tick(Sim.STEP)
	check(sim.phase == "resolve", "Actual tick keeps the late kill flight past the old cutoff")
	sim.phase_time = sim.resolve_deadline + Sim.STEP
	sim.tick(Sim.STEP)
	check(sim.phase == "enemy", "Extended flight still yields to the enemy phase")
	print("RICOCHET: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
