class_name OrdoFieldEffects
extends RefCounted

const STRONG_IMPACT := 1.7
const COLD_SPEED := 0.6

static func statuses(body: Dictionary) -> Dictionary:
	if not body.has("statuses"): body.statuses = {}
	return body.statuses

static func burning(sim, body: Dictionary) -> bool:
	return int(body.hp) > 0 and (body.get("statuses", {}).has("burn") or (body.has("kind") and sim.Bosses.hot(sim, body)))

static func cold(body: Dictionary) -> bool:
	return body.get("statuses", {}).has("frost") or body.get("statuses", {}).has("frozen")

static func frozen(sim, body: Dictionary) -> bool:
	return body.get("statuses", {}).has("frozen") and int(body.get("freeze_turn", -1)) == sim.turn

static func thaw(sim, body: Dictionary) -> void:
	statuses(body).erase("frost"); body.statuses.erase("frozen"); body.erase("freeze_turn")
	if body.get("cold_cancelled", false) and sim.phase != "enemy": body.fired = false
	body.erase("cold_cancelled")

static func extinguish(sim, body: Dictionary) -> void:
	statuses(body).erase("burn"); body.erase("burn_tick"); body.erase("fire_pickup_turn")
	if body.get("boss_phase", "") == "burning":
		body.boss_phase = "doused"; body.stun = maxi(1, int(body.stun))
		sim.emit("boss_phase", sim.pos(body), 0, .8, "ПОТУШЕН · ПРОПУСК АТАКИ", {"actor":int(body.id)})

static func steam(sim, a: Dictionary, b: Dictionary, point: Vector2, normal: Vector2) -> void:
	extinguish(sim, a); extinguish(sim, b); thaw(sim, a); thaw(sim, b)
	sim.emit("steam", point, -1, 1.0, "", {"a":int(a.id), "b":int(b.id), "nx":normal.x, "nz":normal.y})

static func ignite(sim, body: Dictionary, turns: int) -> void:
	if int(body.hp) <= 0: return
	if cold(body):
		steam(sim, body, body, sim.pos(body), Vector2.RIGHT)
		return
	statuses(body).burn = maxi(int(body.statuses.get("burn", 0)), turns)
	sim.emit("element_apply", sim.pos(body), -1, float(turns), "burn", {"target":int(body.id)})

static func freeze_next(sim, body: Dictionary) -> void:
	if int(body.hp) <= 0: return
	statuses(body).frozen = 1; body.freeze_turn = sim.turn + 1
	sim.emit("element_apply", sim.pos(body), -1, 1.0, "frozen", {"target":int(body.id)})

static func collect(sim, body: Dictionary, item: Dictionary) -> void:
	if item.get("used", false) or int(body.hp) <= 0: return
	item.used = true
	sim.emit("element_pickup", sim.pos(item), -1, 1.0, item.element, {"target":int(body.id), "pickup":int(item.id)})
	if item.element == "fire":
		ignite(sim, body, 1)
		if statuses(body).has("burn"): body.fire_pickup_turn = sim.turn
	elif burning(sim, body):
		steam(sim, body, body, sim.pos(body), Vector2.RIGHT)
	elif body.has("kind"):
		statuses(body).frozen = 1; body.freeze_turn = maxi(int(body.get("freeze_turn", -1)), sim.turn)
		body.fired = true; body.cold_cancelled = true; body.jump = 0.0
		sim.velocity(body, Vector2.ZERO)
	else:
		statuses(body).frost = maxi(1, int(body.statuses.get("frost", 0)))
		sim.velocity(body, sim.vel(body) * COLD_SPEED)

static func collect_near(sim, bodies: Array) -> void:
	for body in bodies:
		for item in sim.pickups:
			if item.kind == "element" and not item.get("used", false) and sim.pos(body).distance_to(sim.pos(item)) <= float(body.r) + .25:
				collect(sim, body, item)

# Resolve the current contact graph before physical damage. Repeating the graph
# reaches a same-step chain independently of body order, without reflecting a
# newly acquired flame back into its original source in that same collision.
static func contacts(sim, bodies: Array) -> Dictionary:
	var touching: Dictionary = {}
	var edges: Array = []
	var initial_fire: Dictionary = {}
	var initial_cold: Dictionary = {}
	var quenched: Dictionary = {}
	var protected: Dictionary = {}
	for body in bodies:
		initial_fire[int(body.id)] = burning(sim, body)
		initial_cold[int(body.id)] = cold(body)
	for i in bodies.size():
		for j in range(i + 1, bodies.size()):
			var a: Dictionary = bodies[i]; var b: Dictionary = bodies[j]
			if int(a.hp) <= 0 or int(b.hp) <= 0: continue
			var delta: Vector2 = sim.pos(b) - sim.pos(a)
			if delta.length() >= float(a.r) + float(b.r): continue
			var key := "%d:%d" % [mini(int(a.id), int(b.id)), maxi(int(a.id), int(b.id))]
			touching[key] = true
			if sim.element_contacts.has(key): continue
			var normal := delta.normalized() if delta.length() > .001 else Vector2.RIGHT
			var edge := {"a":a, "b":b, "normal":normal, "strong":(sim.vel(a) - sim.vel(b)).dot(normal) >= STRONG_IMPACT}
			edges.append(edge)
	sim.element_contacts = touching
	# Opposite elements cancel before either can propagate through this contact.
	for edge in edges:
		var a: Dictionary = edge.a; var b: Dictionary = edge.b
		if (initial_fire[int(a.id)] and initial_cold[int(b.id)]) or (initial_cold[int(a.id)] and initial_fire[int(b.id)]):
			if not quenched.has(int(a.id)) or not quenched.has(int(b.id)):
				steam(sim, a, b, (sim.pos(a) + sim.pos(b)) * .5, edge.normal)
			quenched[int(a.id)] = true; quenched[int(b.id)] = true
			protected["steam:%d:%d" % [mini(int(a.id),int(b.id)),maxi(int(a.id),int(b.id))]] = true
	# A strong blow breaks the old ice. Only a previously warm counterpart gets
	# next-turn ice, so the very same blow cannot immediately break its new shell.
	var to_freeze: Array = []
	for edge in edges:
		if not edge.strong: continue
		var a: Dictionary = edge.a; var b: Dictionary = edge.b
		if quenched.has(int(a.id)) or quenched.has(int(b.id)): continue
		for pair in [[a,b], [b,a]]:
			if not initial_cold[int(pair[0].id)]: continue
			thaw(sim, pair[0])
			if not initial_cold[int(pair[1].id)]: to_freeze.append(pair)
	for pair in to_freeze:
		var target: Dictionary = pair[1]
		if not target.has("kind") and sim.block_player(target): protected["block:%d:%d" % [int(pair[0].id),int(target.id)]] = true
		else: freeze_next(sim, target)
	var sent: Dictionary = {}
	for iteration in bodies.size():
		var changed := false
		for edge in edges:
			for pair in [[edge.a,edge.b], [edge.b,edge.a]]:
				var source: Dictionary = pair[0]; var target: Dictionary = pair[1]
				var sid := int(source.id); var tid := int(target.id)
				if quenched.has(sid) or quenched.has(tid): continue
				if not burning(sim, source): continue
				if initial_fire[tid] and not initial_fire[sid]: continue
				var key := "%d:%d" % [sid, tid]
				if sent.has(key): continue
				sent[key] = true
				if cold(target):
					steam(sim, source, target, (sim.pos(source) + sim.pos(target)) * .5, edge.normal)
					quenched[sid] = true; quenched[tid] = true
					protected["steam:%d:%d" % [mini(sid,tid),maxi(sid,tid)]] = true
				elif not target.has("kind") and sim.block_player(target): protected["block:%d:%d" % [sid,tid]] = true
				else:
					var before := int(statuses(target).get("burn", 0))
					ignite(sim, target, 2 if edge.strong else 1)
					changed = changed or before != int(target.statuses.get("burn", 0))
		if not changed: break
	return protected

static func end_turn(sim) -> void:
	if sim.effects_tick_turn == sim.turn: return
	sim.effects_tick_turn = sim.turn
	for body in sim.players + sim.enemies:
		var state := statuses(body)
		if int(body.hp) <= 0:
			state.clear(); body.erase("freeze_turn"); continue
		# A collected flame stays charged through the next throw. Contact burns
		# keep their existing timing; refreshing cannot consume pickup grace.
		if state.has("burn") and int(body.get("fire_pickup_turn", -1)) != sim.turn:
			if body.has("kind"): sim.hit_enemy(body, 1, "burn:%d:%d" % [sim.turn, int(body.id)], sim.pos(body))
			else: sim.damage_player(body, 1)
			state.burn -= 1
			if int(state.burn) <= 0:
				state.erase("burn"); body.erase("fire_pickup_turn")
		if state.has("frozen") and int(body.get("freeze_turn", -1)) <= sim.turn: thaw(sim, body)
		if int(body.hp) <= 0: state.clear(); body.erase("freeze_turn")
	sim.enemies = sim.enemies.filter(func(body): return int(body.hp) > 0)

static func spawn_sources(sim) -> void:
	if sim.turn % 3 != 1: return
	for element in ["fire", "frost"]:
		var exists := false
		for item in sim.pickups:
			if item.kind == "element" and item.element == element: exists = true
		if exists: continue
		for attempt in 36:
			var angle: float = (attempt * 2.39996) + sim.turn * .73 + (1.3 if element == "frost" else 0.0)
			var point := Vector2.from_angle(angle) * (2.6 if attempt % 2 == 0 else 4.2)
			var free := true
			for body in sim.players + sim.enemies + sim.stones + sim.pickups:
				if sim.pos(body).distance_to(point) < float(body.get("r", .35)) + .8: free = false; break
			if not free: continue
			sim.entity_id += 1
			sim.pickups.append({"id":sim.entity_id, "kind":"element", "element":element, "x":point.x, "z":point.y, "r":.25})
			break
