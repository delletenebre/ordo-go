class_name OrdoSimulation
extends RefCounted

const Catalog = preload("res://scripts/catalog.gd")
const RADIUS := 6.1
const CORE_RADIUS := 0.92
const STEP := 1.0 / 120.0
var rng := RandomNumberGenerator.new()
var players: Array = []
var enemies: Array = []
var hazards: Array = []
var pickups: Array = []
var events: Array = []
var stones: Array = []
var phase := "menu"
var wave := 0
var turn := 0
var difficulty := 1
var fire := 8
var max_fire := 8
var timer := 0.0
var phase_time := 0.0
var event_id := 0
var entity_id := 10
var hits: Dictionary = {}
var reward_options: Array = []
var last_reason := ""
var kills := 0
var ready_time := 0.0

func _init() -> void:
	for a in [0.3, 1.85, 3.4, 4.95]:
		stones.append({"x": cos(a) * 4.6, "z": sin(a) * 4.6, "r": 0.46})

func start(count: int, mode: int = 1, seed_value: int = 20260914) -> void:
	rng.seed = seed_value
	players.clear(); enemies.clear(); hazards.clear(); pickups.clear(); events.clear()
	phase = "plan"; wave = 0; turn = 0; difficulty = clampi(mode, 0, 2)
	max_fire = [10, 8, 6][difficulty]; fire = max_fire; kills = 0; event_id = 0; entity_id = 10
	for i in clampi(count, 1, 4):
		var a: float = PI * 0.5 + i * TAU / float(clampi(count, 1, 4))
		players.append({"id": i, "x": cos(a) * 3.5, "z": sin(a) * 3.5, "vx": 0.0, "vz": 0.0, "r": 0.43, "mass": 1.2, "hp": 4, "max_hp": 4, "angle": a + PI, "power": 0.65, "ready": false, "ability": false, "charges": 2, "bonus_charges": 0, "damage": 0, "speed": 1.0, "armor": 0, "armor_per_wave": 0, "shield": 0, "boost": false, "statuses": {}, "reward": false})
	next_wave()

func pos(e: Dictionary) -> Vector2:
	return Vector2(float(e.x), float(e.z))

func vel(e: Dictionary) -> Vector2:
	return Vector2(float(e.vx), float(e.vz))

func place(e: Dictionary, p: Vector2) -> void:
	e.x = p.x; e.z = p.y

func velocity(e: Dictionary, v: Vector2) -> void:
	e.vx = v.x; e.vz = v.y

func emit(kind: String, p: Vector2, color: int = -1, strength: float = 1.0, message: String = "") -> void:
	event_id += 1
	events.append({"id": event_id, "kind": kind, "x": p.x, "z": p.y, "color": color, "strength": strength, "text": message})
	if events.size() > 100: events.pop_front()

func spawn(kind: String, a: float, bonus_hp: int = 0) -> void:
	var def: Dictionary = Catalog.ENEMIES[kind]
	entity_id += 1
	if float(def.radius) > 0.7: a += 0.5
	var p := Vector2(cos(a), sin(a)) * (4.5 if float(def.radius) > 0.7 else 5.6)
	var hp: int = int(def.hp) + bonus_hp
	enemies.append({"id": entity_id, "kind": kind, "x": p.x, "z": p.y, "vx": 0.0, "vz": 0.0, "r": def.radius, "mass": def.mass, "hp": hp, "max_hp": hp, "angle": a + PI, "tx": 0.0, "tz": 0.0, "attack": "rush", "fired": false, "stun": 0, "jump": 0.0, "sx": p.x, "sz": p.y})
	emit("spawn", p, -1, float(def.radius))

func next_wave() -> void:
	wave += 1
	if wave > 9:
		phase = "win"; emit("victory", Vector2.ZERO, 1, 3.0); return
	enemies.clear(); hazards.clear(); pickups.clear()
	var spec := Catalog.wave_spec(wave, players.size(), difficulty)
	var total: int = spec.kinds.size() + (0 if spec.boss == "" else 1)
	for i in spec.kinds.size():
		spawn(spec.kinds[i], float(i) * TAU / total + wave * 0.45)
	if spec.boss != "": spawn(spec.boss, -PI / 2.0, spec.boss_bonus)
	for p in players:
		p.hp = mini(int(p.hp) + 1, int(p.max_hp))
		p.charges = 2 + int(p.bonus_charges)
		p.armor = p.armor_per_wave
		p.statuses = {}; p.shield = 0
	if wave > 1: fire = mini(fire + 1, max_fire)
	emit("wave", Vector2.ZERO, 1, 1.0, Catalog.WAVE_NAMES[wave - 1])
	begin_plan()

func begin_plan() -> void:
	phase = "plan"; phase_time = 0.0; turn += 1; hits.clear(); ready_time = 0.0
	timer = float(Catalog.wave_spec(wave, players.size(), difficulty).planning)
	for p in players:
		velocity(p, Vector2.ZERO); p.ready = false; p.ability = false; p.boost = false; p.shield = 0
	for e in enemies:
		velocity(e, Vector2.ZERO); e.fired = false; e.jump = 0.0
		var origin := pos(e)
		var target := Vector2.ZERO
		var kind: String = e.kind
		if kind in ["hopper", "frost", "weaver", "ram"]:
			var nearest := 999.0
			for p in players:
				if int(p.hp) <= 0: continue
				var d := origin.distance_to(pos(p))
				if d < nearest: nearest = d; target = pos(p)
		var dir := (target - origin).normalized()
		e.angle = dir.angle()
		e.attack = "rush"
		if kind in ["hopper", "weaver"]:
			e.attack = "jump"
		elif kind == "eater":
			e.attack = "ring"; target = Vector2.ZERO
		elif kind == "frost":
			e.attack = "frost"
		elif kind == "brute" and origin.length() < 2.5:
			e.attack = "slam"; target = origin
		else:
			var length: float = float(Catalog.ENEMIES[kind].speed)
			if kind == "ram": length = 5.5
			target = origin + dir * minf(length, origin.distance_to(target))
		e.tx = target.x; e.tz = target.y

func command(slot: int, data: Dictionary) -> bool:
	if slot < 0 or slot >= players.size(): return false
	var p: Dictionary = players[slot]
	if data.get("turn", turn) != turn: return false
	if phase == "reward" and data.get("action", "") == "reward":
		return choose_reward(slot, int(data.get("choice", -1)))
	if phase != "plan" or int(p.hp) <= 0: return false
	var action: String = data.get("action", "aim")
	if action == "ready":
		p.ready = not bool(p.ready); return true
	if action == "ability":
		if not bool(p.ready) and int(p.charges) > 0: p.ability = not bool(p.ability)
		return true
	if action == "cancel": p.ready = false; return true
	if action != "aim" or bool(p.ready): return false
	var a := float(data.get("angle", p.angle))
	var power := float(data.get("power", p.power))
	if not is_finite(a) or not is_finite(power): return false
	p.angle = fposmod(a, TAU); p.power = clampf(power, 0.15, 1.0)
	return true

func tick(dt: float) -> void:
	if phase in ["menu", "win", "lose", "reward"]: return
	phase_time += dt
	if phase == "plan":
		timer = maxf(0.0, timer - dt)
		var all_ready := true
		for p in players:
			if int(p.hp) > 0 and not bool(p.ready): all_ready = false
		ready_time = ready_time + dt if all_ready else 0.0
		if timer <= 0.0 or ready_time > 0.75: launch()
		return
	if phase == "resolve":
		move_bodies(dt, true)
		var moving := false
		for e in players + enemies:
			if vel(e).length_squared() > 0.05: moving = true
		if (phase_time > 0.65 and not moving) or phase_time > 4.5: begin_enemy()
	elif phase == "enemy":
		enemy_actions(dt)
		move_bodies(dt, false)
		if phase_time > 2.1: end_turn()
	elif phase == "clear" and phase_time > 1.7:
		if wave == 9: phase = "win"; emit("victory", Vector2.ZERO, 1, 3.0)
		else: begin_reward()
	check_end()

func launch() -> void:
	phase = "resolve"; phase_time = 0.0; hits.clear()
	for p in players:
		if int(p.hp) <= 0: continue
		if not bool(p.ready): p.shield = 1; continue
		var dir := Vector2(cos(float(p.angle)), sin(float(p.angle)))
		var speed: float = (3.0 + float(p.power) * 8.5) * float(p.speed)
		if p.statuses.has("frost"): speed *= 0.6
		if p.statuses.has("snare"): speed *= 0.7
		for h in hazards:
			if h.kind == "ice" and pos(p).distance_to(pos(h)) < float(h.r): speed *= 0.7
		if bool(p.ability) and int(p.charges) > 0:
			p.charges -= 1; p.boost = true
			match int(p.id):
				1: p.shield = 2
				2:
					for e in enemies:
						var offset := pos(e) - pos(p)
						if offset.length() < 3.7 and dir.dot(offset.normalized()) > 0.3:
							velocity(e, vel(e) + dir * 6.0 / sqrt(float(e.mass)))
					emit("wind", pos(p), 2, 2.0)
		velocity(p, dir * speed)
		emit("launch", pos(p), int(p.id), float(p.power))

func move_bodies(dt: float, attacking: bool) -> void:
	var bodies: Array = []
	for p in players:
		if int(p.hp) > 0: bodies.append(p)
	for e in enemies:
		if int(e.hp) > 0 and float(e.jump) <= 0.0: bodies.append(e)
	for b in bodies:
		var v := vel(b)
		var location := pos(b) + v * dt
		v *= exp(-1.7 * dt)
		if v.length() < 0.07: v = Vector2.ZERO
		if location.length() > RADIUS - float(b.r):
			var n := location.normalized(); location = n * (RADIUS - float(b.r)); v = v.bounce(n) * 0.72
			if attacking and b.has("kind") and v.length() > 2.4:
				hit_enemy(b, 1, "wall:%s" % b.id, location)
		for obstacle in stones + [{"x": 0.0, "z": 0.0, "r": CORE_RADIUS}]:
			var diff := location - pos(obstacle)
			var min_d: float = float(obstacle.r) + float(b.r)
			if diff.length() < min_d:
				var n := diff.normalized() if diff.length() > 0.001 else Vector2.RIGHT
				location = pos(obstacle) + n * min_d
				if v.dot(n) < 0.0:
					var impact := v.length(); v = v.bounce(n) * 0.7
					if attacking and b.has("kind") and impact > 2.5:
						hit_enemy(b, 1, "stone:%s" % b.id, location)
		place(b, location); velocity(b, v)
	for i in bodies.size():
		for j in range(i + 1, bodies.size()):
			var a: Dictionary = bodies[i]; var b: Dictionary = bodies[j]
			var diff := pos(b) - pos(a)
			var separation: float = float(a.r) + float(b.r)
			if diff.length() >= separation: continue
			var n := diff.normalized() if diff.length() > 0.001 else Vector2.RIGHT
			var inv_a := 1.0 / float(a.mass); var inv_b := 1.0 / float(b.mass)
			var overlap := separation - diff.length()
			place(a, pos(a) - n * overlap * inv_a / (inv_a + inv_b))
			place(b, pos(b) + n * overlap * inv_b / (inv_a + inv_b))
			var impact := (vel(a) - vel(b)).dot(n)
			if impact <= 0.0: continue
			var impulse := n * impact * 1.68 / (inv_a + inv_b)
			velocity(a, vel(a) - impulse * inv_a); velocity(b, vel(b) + impulse * inv_b)
			if impact < 1.7: continue
			var key := "%s:%s" % [a.id, b.id]
			if hits.has(key): continue
			hits[key] = true
			emit("impact", (pos(a) + pos(b)) * 0.5, -1, minf(impact / 5.0, 2.0))
			if attacking:
				if a.has("kind") and b.has("kind"):
					hit_enemy(a, 1, key + "a", pos(a)); hit_enemy(b, 1, key + "b", pos(b))
				elif a.has("kind"): player_hit(b, a, key)
				elif b.has("kind"): player_hit(a, b, key)
			elif a.has("kind") != b.has("kind"):
				var enemy: Dictionary = a if a.has("kind") else b
				var player: Dictionary = b if a.has("kind") else a
				if enemy.attack == "rush" and not bool(enemy.fired):
					damage_player(player, 1, "snare" if enemy.kind == "moth" else "")
					enemy.fired = true
	for p in players:
		if int(p.hp) <= 0: continue
		for ally in players:
			if int(ally.hp) <= 0 and pos(p).distance_to(pos(ally)) < 0.95 and attacking:
				ally.hp = 1; emit("heal", pos(ally), int(ally.id), 1.0, "+1")
		for item in pickups:
			if not item.get("used", false) and pos(p).distance_to(pos(item)) < 0.7:
				item.used = true
				if item.kind == "heart": p.hp = mini(int(p.hp) + 1, int(p.max_hp))
				else: p.charges = mini(int(p.charges) + 1, 5)
				emit("heal", pos(p), int(p.id), 0.8, "+1")
	pickups = pickups.filter(func(x): return not x.get("used", false))
	enemies = enemies.filter(func(x): return int(x.hp) > 0)

func player_hit(p: Dictionary, e: Dictionary, key: String) -> void:
	var damage := 1 + int(p.damage)
	if p.statuses.has("weak"): damage = maxi(1, damage - 1)
	if bool(p.boost) and int(p.id) == 0: damage += 1; p.boost = false
	hit_enemy(e, damage, key + "hit", pos(e))
	if bool(p.boost) and int(p.id) == 3:
		p.boost = false; emit("blast", pos(e), 3, 2.0)
		for other in enemies:
			var offset := pos(other) - pos(e)
			if other.id != e.id and offset.length() < 2.0:
				velocity(other, vel(other) + offset.normalized() * 6.0 / sqrt(float(other.mass)))
				hit_enemy(other, 1, key + ":blast:%s" % other.id, pos(other))

func hit_enemy(e: Dictionary, amount: int, key: String, point: Vector2) -> void:
	if hits.has(key) or int(e.hp) <= 0: return
	hits[key] = true; e.hp -= amount
	emit("damage", point, -1, float(amount), str(amount))
	if int(e.hp) <= 0:
		kills += 1; emit("death", point, -1, float(e.r) * 2.0)
		if rng.randf() < 0.28:
			entity_id += 1
			pickups.append({"id": entity_id, "x": point.x, "z": point.y, "kind": "heart" if rng.randf() < 0.55 else "charge"})

func damage_player(p: Dictionary, amount: int, status: String = "") -> void:
	if int(p.hp) <= 0: return
	for guard in players:
		if int(guard.hp) > 0 and int(guard.shield) > 0 and (guard.id == p.id or (int(guard.id) == 1 and pos(guard).distance_to(pos(p)) < 2.0)):
			guard.shield -= 1; emit("shield", pos(p), 1, 1.0); return
	if int(p.armor) > 0: p.armor -= 1; emit("shield", pos(p), 1, 1.0); return
	p.hp = maxi(0, int(p.hp) - amount)
	if status != "": p.statuses[status] = 2
	emit("hurt", pos(p), int(p.id), 1.0, "−%d" % amount)

func begin_enemy() -> void:
	if enemies.is_empty(): clear_wave(); return
	phase = "enemy"; phase_time = 0.0; hits.clear()
	for p in players: velocity(p, Vector2.ZERO)
	for e in enemies:
		velocity(e, Vector2.ZERO)
		e.sx = e.x; e.sz = e.z
		if int(e.stun) > 0: e.stun -= 1; e.fired = true; continue
		if e.attack == "rush":
			var target := Vector2(float(e.tx), float(e.tz))
			velocity(e, (target - pos(e)).limit_length(5.5) * 1.85)
		elif e.attack == "jump": e.jump = 0.001

func enemy_actions(dt: float) -> void:
	for e in enemies:
		if bool(e.fired): continue
		if e.attack == "rush":
			if pos(e).length() <= CORE_RADIUS + float(e.r) + 0.1:
				damage_fire(1); e.fired = true
				if e.kind in ["coal", "moth"]: e.hp = 0; emit("death", pos(e))
			continue
		if e.attack == "jump":
			e.jump = minf(1.0, float(e.jump) + dt / 0.95)
			var from := Vector2(float(e.sx), float(e.sz)); var to := Vector2(float(e.tx), float(e.tz))
			place(e, from.lerp(to, float(e.jump)))
			if float(e.jump) < 1.0: continue
			e.jump = 0.0; e.fired = true
			var radius := 1.6 if e.kind == "weaver" else 1.05
			area_attack(pos(e), radius, "frost" if e.kind == "weaver" else "")
			if e.kind == "weaver": add_hazard(pos(e), 1.8, "ice")
		elif phase_time > 0.9:
			e.fired = true
			if e.attack == "frost":
				var target := Vector2(float(e.tx), float(e.tz))
				area_attack(target, 1.1, "frost"); add_hazard(target, 1.1, "ice")
			elif e.attack == "slam":
				area_attack(pos(e), 1.4, "weak")
				if pos(e).length() < 2.0: damage_fire(1)
			elif e.attack == "ring":
				var ring_radius := 2.4 if turn % 2 == 0 else 4.5
				emit("ring", Vector2.ZERO, 3, ring_radius)
				for p in players:
					if absf(pos(p).length() - ring_radius) < 0.8: damage_player(p, 1, "burn")
				if turn % 3 == 0: damage_fire(1)
				if turn % 2 == 0: spawn("coal", rng.randf() * TAU)

func area_attack(center: Vector2, radius: float, status: String) -> void:
	emit("ice" if status == "frost" else "blast", center, -1, radius)
	for p in players:
		if pos(p).distance_to(center) < radius + float(p.r) * 0.5:
			damage_player(p, 1, status)
			velocity(p, (pos(p) - center).normalized() * 3.0)

func add_hazard(p: Vector2, radius: float, kind: String) -> void:
	entity_id += 1
	hazards.append({"id": entity_id, "x": p.x, "z": p.y, "r": radius, "kind": kind, "turns": 3})

func damage_fire(amount: int) -> void:
	for p in players:
		if int(p.hp) > 0 and int(p.id) == 1 and int(p.shield) > 0 and pos(p).length() < 2.8:
			p.shield -= 1; emit("shield", Vector2.ZERO, 1, 2.0); return
	fire = maxi(0, fire - amount); emit("fire_hurt", Vector2.ZERO, 3, 2.0, "−1")

func end_turn() -> void:
	for p in players:
		if p.statuses.has("burn"): damage_player(p, 1)
		for key in p.statuses.keys():
			p.statuses[key] -= 1
			if int(p.statuses[key]) <= 0: p.statuses.erase(key)
	for h in hazards: h.turns -= 1
	hazards = hazards.filter(func(h): return int(h.turns) > 0)
	check_end()
	if phase == "lose": return
	if enemies.is_empty(): clear_wave()
	else: begin_plan()

func clear_wave() -> void:
	phase = "clear"; phase_time = 0.0
	for p in players: velocity(p, Vector2.ZERO)
	emit("clear", Vector2.ZERO, 1, 2.0, "ВОЛНА ПРОЙДЕНА")

func begin_reward() -> void:
	phase = "reward"; reward_options.clear()
	var keys: Array = Catalog.BOONS.keys()
	for i in range(keys.size() - 1, 0, -1):
		var j := rng.randi_range(0, i); var swap = keys[i]; keys[i] = keys[j]; keys[j] = swap
	reward_options = keys.slice(0, 3)
	for p in players: p.reward = false

func choose_reward(slot: int, choice: int) -> bool:
	if phase != "reward" or choice < 0 or choice >= reward_options.size(): return false
	var p: Dictionary = players[slot]
	if bool(p.reward): return false
	p.reward = true
	match reward_options[choice]:
		"stitch": p.max_hp += 1; p.hp = mini(int(p.hp) + 1, int(p.max_hp))
		"spark": p.damage += 1
		"stride": p.speed = minf(1.75, float(p.speed) + 0.15)
		"charge": p.bonus_charges += 1
		"guard": p.armor_per_wave += 1
		"mend": fire = mini(max_fire, fire + 2)
	emit("heal", pos(p), slot, 1.0)
	for other in players:
		if not bool(other.reward): return true
	next_wave()
	return true

func check_end() -> void:
	if phase in ["menu", "win", "lose"]: return
	if fire <= 0:
		phase = "lose"; last_reason = "Огонь погас. Попробуйте прикрыть очаг Стражем."; return
	var alive := false
	for p in players:
		if int(p.hp) > 0: alive = true
	if not alive: phase = "lose"; last_reason = "Все хранители погасли. Касайтесь павших, чтобы поднять их."

func snapshot() -> Dictionary:
	return {"players": players.duplicate(true), "enemies": enemies.duplicate(true), "hazards": hazards.duplicate(true), "pickups": pickups.duplicate(true), "events": events.duplicate(true), "phase": phase, "wave": wave, "turn": turn, "difficulty": difficulty, "fire": fire, "max_fire": max_fire, "timer": timer, "phase_time": phase_time, "reward_options": reward_options.duplicate(), "kills": kills, "reason": last_reason}

func restore(s: Dictionary) -> void:
	players = s.players; enemies = s.enemies; hazards = s.hazards; pickups = s.pickups; events = s.events
	phase = s.phase; wave = int(s.wave); turn = int(s.turn); difficulty = int(s.difficulty)
	fire = int(s.fire); max_fire = int(s.max_fire); timer = float(s.timer); phase_time = float(s.phase_time)
	reward_options = s.reward_options; kills = int(s.kills); last_reason = s.reason
