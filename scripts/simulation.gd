class_name OrdoSimulation
extends RefCounted

const TeamImpact=preload("res://scripts/team_impact.gd")
const PlayerClash=preload("res://scripts/player_clash.gd")
const Bosses=preload("res://scripts/boss_rules.gd")
const Effects = preload("res://scripts/field_effects.gd")
const EnemyMotion=preload("res://scripts/enemy_motion.gd")
const Runestones = preload("res://scripts/runestones.gd")
const DRAG := 0.95
const CURL_RATE := 0.18
const SPIN_DRAG := 1.8
const WALL_BOUNCE := 0.94
const STONE_BOUNCE := 0.94
const MAX_RICOCHET_BONUS := 2
const RESOLVE_TIME := 4.5
const MAX_CHAIN_TIME := 8.0
const KILL_FLIGHT_TIME := 1.5
const Spirits = preload("res://scripts/spirits.gd")
const Catalog = preload("res://scripts/catalog.gd")
const RADIUS := 6.1
const CORE_RADIUS := 0.92
const STEP := 1.0 / 120.0
const REWARD_READY_DELAY := 2.0
var rng := RandomNumberGenerator.new()
var players: Array = []
var enemies: Array = []
var hazards: Array = []
var pickups: Array = []
var events: Array = []
var stones: Array = []
var soul_flights: Array = []
var rune_drops: Array = []
var rune_seed:=20260914
var rune_serial:=0
var phase := "menu"
var wave := 0
var turn := 0
var difficulty := 1
var fire := 8
var max_fire := 8
var timer := 0.0
var phase_time := 0.0
var resolve_deadline := RESOLVE_TIME
var event_id := 0
var entity_id := 10
var hits: Dictionary = {}
var team_contacts:Dictionary={}
var element_contacts: Dictionary = {}
var effects_tick_turn := -1
var reward_options: Array = []
var last_reason := ""
var kills := 0
var ready_time := 0.0

func _init() -> void:
	stones=Runestones.layout()

func start(count: int, mode: int = 1, seed_value: int = -1) -> void:
	element_contacts.clear(); effects_tick_turn = -1
	if seed_value < 0:
		rng.randomize()
		seed_value = rng.randi()
	rng.seed = seed_value; rune_seed = seed_value
	players.clear(); enemies.clear(); hazards.clear(); pickups.clear(); events.clear()
	phase = "plan"; wave = 0; turn = 0; difficulty = clampi(mode, 0, 2)
	max_fire = [10, 8, 6][difficulty]; fire = max_fire; kills = 0; event_id = 0; entity_id = 10
	var spacing := TAU / float(clampi(count, 1, 4))
	var rotation := rng.randf() * TAU
	for i in clampi(count, 1, 4):
		var point := edge_position(0.43, rotation + i * spacing, spacing * 0.2)
		var a := point.angle()
		players.append({"id": i, "x": point.x, "z": point.y, "vx": 0.0, "vz": 0.0, "r": 0.43, "mass": 1.2, "hp": 4, "max_hp": 4, "angle": a + PI, "power": 0.15, "spin": 0.0, "flight_spin": 0.0, "ready": false, "ability": false, "charges": 2, "bonus_charges": 0, "damage": 0, "speed": 1.0, "armor": 0, "armor_per_wave": 0, "shield": 0, "boost": false, "statuses": {}, "reward": false, "reward_choice": -1, "spirit": {}, "pending_spirit": ""})
	Runestones.reset(self)
	next_wave()

func pos(e: Dictionary) -> Vector2:
	return Vector2(float(e.x), float(e.z))

func vel(e: Dictionary) -> Vector2:
	return Vector2(float(e.vx), float(e.vz))

func place(e: Dictionary, p: Vector2) -> void:
	e.x = p.x; e.z = p.y

func velocity(e: Dictionary, v: Vector2) -> void:
	var limited:=v.limit_length(Runestones.SPEED_LIMIT)
	e.vx=limited.x;e.vz=limited.y

func emit(kind: String, p: Vector2, color: int = -1, strength: float = 1.0, message: String = "", details: Dictionary = {}) -> void:
	event_id += 1
	var event:={"id": event_id, "kind": kind, "x": p.x, "z": p.y, "color": color, "strength": strength, "text": message}
	event.merge(details);events.append(event)
	if events.size() > 100: events.pop_front()

func edge_position(radius: float, angle: float, spread: float) -> Vector2:
	# Prefer a random point in this actor's sector; occupied sectors can spill
	# into a free perimeter gap without moving players from the previous wave.
	var orbit := RADIUS - radius - 0.08
	var best := Vector2.from_angle(angle) * orbit
	var best_clearance := -INF
	var bodies := players + enemies + stones
	for attempt in 320:
		var candidate_angle := angle + rng.randf_range(-spread, spread) if attempt < 64 else angle + (attempt - 64) * TAU / 256.0
		var point := Vector2.from_angle(candidate_angle) * orbit
		var clearance := INF
		for body in bodies:
			clearance = minf(clearance, point.distance_to(pos(body)) - radius - float(body.r))
		if clearance >= 0.12: return point
		if clearance > best_clearance:
			best = point; best_clearance = clearance
	return best

func spawn(kind: String, a: float, bonus_hp: int = 0, spread: float = 0.0) -> void:
	var def: Dictionary = Catalog.ENEMIES[kind]
	entity_id += 1
	var p := edge_position(float(def.radius), a, spread)
	a = p.angle()
	var hp: int = int(def.hp) + bonus_hp
	enemies.append({"id": entity_id, "kind": kind, "x": p.x, "z": p.y, "vx": 0.0, "vz": 0.0, "r": def.radius, "mass": def.mass, "hp": hp, "max_hp": hp, "angle": a + PI, "tx": 0.0, "tz": 0.0, "attack": "rush", "fired": false, "stun": 0, "chill": 0, "jump": 0.0, "sx": p.x, "sz": p.y})
	Bosses.configure(self, enemies[-1])
	emit("spawn", p, -1, float(def.radius))

func next_wave() -> void:
	element_contacts.clear()
	wave += 1
	if wave > 9:
		phase = "win"; emit("victory", Vector2.ZERO, 1, 3.0); return
	enemies.clear(); hazards.clear(); pickups.clear()
	var spec := Catalog.wave_spec(wave, players.size(), difficulty)
	var total: int = spec.kinds.size() + (0 if spec.boss == "" else 1)
	var spacing := TAU / float(total)
	var rotation := rng.randf() * TAU
	# Place the largest body first so smaller enemies can fit around it.
	if spec.boss != "": spawn(spec.boss, rotation + (total - 1) * spacing, spec.boss_bonus, spacing * 0.2)
	for i in spec.kinds.size():
		spawn(spec.kinds[i], rotation + i * spacing, 0, spacing * 0.2)
	# Only replenish resources here: settled player coordinates persist.
	for p in players:
		p.hp = mini(int(p.hp) + 1, int(p.max_hp))
		p.charges = 2 + int(p.bonus_charges)
		p.armor = p.armor_per_wave
		var carried_fire := int(p.statuses.get("burn", 0)) if int(p.get("fire_pickup_turn", -1)) == turn else 0
		p.statuses = {"burn":carried_fire} if carried_fire > 0 else {}; p.shield = 0
	if wave > 1: fire = mini(fire + 1, max_fire)
	emit("wave", Vector2.ZERO, 1, 1.0, Catalog.WAVE_NAMES[wave - 1])
	begin_plan()

func begin_plan() -> void:
	phase = "plan"; phase_time = 0.0; turn += 1; hits.clear();team_contacts.clear(); ready_time = 0.0
	timer = float(Catalog.wave_spec(wave, players.size(), difficulty).planning)
	Runestones.expire(self)
	Spirits.begin_plan(self)
	Bosses.ensure_counter(self)
	Effects.spawn_sources(self)
	for p in players:
		velocity(p, Vector2.ZERO); p.power = 0.15; p.spin = 0.0; p.flight_spin = 0.0; p.ready = false; p.ability = false; p.boost = false; p.shield = 0; p.ricochets = 0
		if Effects.frozen(self, p): p.ready = true
	resolve_deadline = RESOLVE_TIME
	for e in enemies:
		velocity(e, Vector2.ZERO); e.fired = false; e.jump = 0.0
		var origin := pos(e)
		var target := Vector2.ZERO
		e.target_id = -1
		var kind: String = e.kind
		if kind in ["hopper", "frost", "weaver", "ram"]:
			var nearest := 999.0
			for p in players:
				if int(p.hp) <= 0: continue
				var d := origin.distance_to(pos(p))
				if d < nearest: nearest = d; target = pos(p); e.target_id = int(p.id)
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
			if kind == "ram": length = 5.5 if Bosses.active(self, e) else 4.0
			target = origin + dir * minf(length, origin.distance_to(target))
		e.tx = target.x; e.tz = target.y
		Bosses.plan(self, e)

func command(slot: int, data: Dictionary) -> bool:
	if slot < 0 or slot >= players.size(): return false
	var p: Dictionary = players[slot]
	if data.get("turn", turn) != turn: return false
	if phase == "reward":
		if data.get("action", "") == "reward":
			return choose_reward(slot, int(data.get("choice", -1)))
		if data.get("action", "") == "cancel":
			if not p.reward: return false
			p.reward = false; p.reward_choice = -1; timer = 0.0
			emit("cancel", pos(p), slot)
			return true
		return false
	if phase != "plan" or int(p.hp) <= 0 or Effects.frozen(self, p): return false
	var action: String = data.get("action", "aim")
	if action == "ready":
		p.ready = not bool(p.ready);emit("ready" if p.ready else "cancel",pos(p),slot);return true
	if action == "ability":
		if not bool(p.ready) and int(p.charges) > 0:
			p.ability = not bool(p.ability);emit("ability" if p.ability else "cancel",pos(p),slot)
		return true
	if action == "cancel":
		if p.ready:emit("cancel",pos(p),slot)
		p.ready = false; return true
	if action != "aim" or bool(p.ready): return false
	var a := float(data.get("angle", p.angle))
	var power := float(data.get("power", p.power))
	var spin := float(data.get("spin", p.get("spin", 0.0)))
	if not is_finite(a) or not is_finite(power) or not is_finite(spin): return false
	p.angle = fposmod(a, TAU); p.power = clampf(power, 0.15, 1.0); p.spin = clampf(spin, -1.0, 1.0)
	return true

func tick(dt: float) -> void:
	Runestones.advance(self,dt)
	if phase in ["menu", "win", "lose"]: return
	phase_time += dt
	if phase == "reward":
		for p in players:
			if not p.reward: return
		timer = maxf(0.0, timer - dt)
		if timer <= 0.0:
			for p in players: apply_reward(p, str(reward_options[int(p.reward_choice)]))
			next_wave()
		return
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
		if (phase_time > 0.65 and not moving) or phase_time > resolve_deadline: begin_enemy()
	elif phase == "enemy":
		enemy_actions(dt)
		move_bodies(dt, false)
		if phase_time > 2.1: end_turn()
	elif phase == "clear" and phase_time > 1.7:
		if wave == 9: phase = "win"; emit("victory", Vector2.ZERO, 1, 3.0)
		else: begin_reward()
	check_end()

func launch_speed(p: Dictionary, power: float = -1.0) -> float:
	var speed: float = (3.0 + (float(p.power) if power < 0.0 else power) * 15.0) * float(p.speed)
	if Spirits.active(p,"wind"): speed *= 1.25
	if Effects.frozen(self, p): return 0.0
	if p.statuses.has("frost"): speed *= Effects.COLD_SPEED
	if p.statuses.has("snare"): speed *= 0.7
	for h in hazards:
		if h.kind == "ice" and pos(p).distance_to(pos(h)) < float(h.r): speed *= 0.7
	return minf(speed,Runestones.SPEED_LIMIT)

# Curl rotates velocity without adding kinetic energy. Surface friction bleeds spin.
static func curl_velocity(v: Vector2, spin: float, dt: float) -> Vector2:
	return v.rotated(spin * CURL_RATE * v.length() * dt)

func launch() -> void:
	phase = "resolve"; phase_time = 0.0; resolve_deadline = RESOLVE_TIME; hits.clear();team_contacts.clear()
	for p in players:
		if int(p.hp) <= 0: continue
		p.landed_hit=false;p.rune_used=false;p.clash_used=false;p.flight_spin=0.0;p.ricochets=0
		if Effects.frozen(self, p): velocity(p, Vector2.ZERO); continue
		if not bool(p.ready): p.shield = 1; continue
		var dir := Vector2(cos(float(p.angle)), sin(float(p.angle)))
		var speed := launch_speed(p)
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
		p.flight_spin = float(p.get("spin", 0.0))
		velocity(p, dir * speed)
		emit("launch", pos(p), int(p.id), float(p.power))

func move_bodies(dt: float, attacking: bool) -> void:
	var first_event := event_id
	var bodies: Array = []
	for p in players:
		if int(p.hp) > 0: bodies.append(p)
	for e in enemies:
		if int(e.hp) > 0 and float(e.jump) <= 0.0: bodies.append(e)
	for b in bodies:
		var v := vel(b)
		if attacking and not b.has("kind"):
			v = curl_velocity(v, float(b.get("flight_spin", 0.0)), dt)
			b.flight_spin = float(b.get("flight_spin", 0.0)) * exp(-SPIN_DRAG * dt)
		var location := pos(b) + v * dt
		v *= exp(-(DRAG if attacking else 1.7) * dt)
		if v.length() < 0.07: v = Vector2.ZERO
		if location.length() > RADIUS - float(b.r):
			var n := location.normalized(); location = n * (RADIUS - float(b.r))
			if v.dot(n) > 0.0:
				if attacking: record_ricochet(b, v.length())
				v = v.bounce(n) * (WALL_BOUNCE if attacking else .72)
			if attacking and b.has("kind") and v.length() > 2.4:
				hit_enemy(b, 1, "wall:%s" % b.id, location, {"vx": v.x, "vz": v.y, "surface": "wall"})
		for obstacle in stones + [{"x": 0.0, "z": 0.0, "r": CORE_RADIUS, "hearth": true}]:
			var diff := location - pos(obstacle)
			var min_d: float = float(obstacle.r) + float(b.r)
			if not b.has("kind") and obstacle.get("hearth", false) and diff.length() <= min_d + 0.00001:
				Spirits.touch_hearth(self, b, diff.normalized() * CORE_RADIUS)
			if diff.length() < min_d:
				var n := diff.normalized() if diff.length() > 0.001 else Vector2.RIGHT
				location = pos(obstacle) + n * min_d
				if v.dot(n) < 0.0:
					var impact := v.length()
					if attacking: record_ricochet(b, impact)
					var reflected:=v.bounce(n)
					var boosted:=Runestones.activate(self,b,obstacle,reflected,attacking)
					v=boosted if boosted!=Vector2.ZERO else reflected*(STONE_BOUNCE if attacking else .7)
					if attacking and b.has("kind") and impact > 2.5:
						hit_enemy(b, 1, "stone:%s" % b.id, location, {"vx": v.x, "vz": v.y, "surface": "stone"})
		place(b, location); velocity(b, v)
	Effects.collect_near(self, bodies)
	var element_blocks := Effects.contacts(self, bodies)
	for i in bodies.size():
		for j in range(i + 1, bodies.size()):
			var a: Dictionary = bodies[i]; var b: Dictionary = bodies[j]
			var diff := pos(b) - pos(a)
			var separation: float = float(a.r) + float(b.r)
			if diff.length() >= separation: continue
			if a.has("kind") != b.has("kind"):
				var touching_player: Dictionary = b if a.has("kind") else a
				var touching_enemy: Dictionary = a if a.has("kind") else b
				if attacking and Spirits.active(touching_player, "frost") and (vel(a)-vel(b)).length() >= 1.7:
					Bosses.frost_strike(self, pos(touching_enemy))
			elif attacking and not a.has("kind") and (vel(a)-vel(b)).length() >= 1.7:
				if Spirits.active(a, "frost") or Spirits.active(b, "frost"): Bosses.frost_strike(self, (pos(a)+pos(b))*.5)
			var n := diff.normalized() if diff.length() > 0.001 else Vector2.RIGHT
			var inv_a := 1.0 / Runestones.mass(a,attacking); var inv_b := 1.0 / Runestones.mass(b,attacking)
			var overlap := separation - diff.length()
			place(a, pos(a) - n * overlap * inv_a / (inv_a + inv_b))
			place(b, pos(b) + n * overlap * inv_b / (inv_a + inv_b))
			var impact := (vel(a) - vel(b)).dot(n)
			if impact <= 0.0: continue
			if attacking and PlayerClash.resolve(self,a,b,n,element_blocks.has("steam:%d:%d" % [mini(int(a.id),int(b.id)),maxi(int(a.id),int(b.id))])):continue
			var incoming_a := vel(a); var incoming_b := vel(b)
			var speed_a:=incoming_a.length();var speed_b:=incoming_b.length()
			var impulse := n * impact * (1.88 if attacking else 1.68) / (inv_a + inv_b)
			velocity(a, vel(a) - impulse * inv_a); velocity(b, vel(b) + impulse * inv_b)
			if impact < 1.7: continue
			var key := "%s:%s" % [a.id, b.id]
			if hits.has(key): continue
			hits[key] = true
			emit("impact", (pos(a) + pos(b)) * 0.5, -1, minf(impact / 5.0, 2.0),"",{"a":int(a.id),"b":int(b.id),"speed":impact,"attacking":attacking,"quenched":element_blocks.has("steam:%d:%d" % [mini(int(a.id),int(b.id)),maxi(int(a.id),int(b.id))])})
			if attacking:
				if a.has("kind") and b.has("kind"):
					hit_enemy(a, 1, key + "a", pos(a)); hit_enemy(b, 1, key + "b", pos(b))
				elif a.has("kind"):
					var bonus:=TeamImpact.record(self,b,a,speed_b,impact)
					resolve_player_hit(b, a, key, incoming_b, -n, bonus)
				elif b.has("kind"):
					var bonus:=TeamImpact.record(self,a,b,speed_a,impact)
					resolve_player_hit(a, b, key, incoming_a, n, bonus)
			elif a.has("kind") != b.has("kind"):
				var enemy: Dictionary = a if a.has("kind") else b
				var player: Dictionary = b if a.has("kind") else a
				if enemy.attack == "rush" and not bool(enemy.fired):
					var previous_hp:=int(player.hp)
					if not element_blocks.has("block:%d:%d" % [int(enemy.id),int(player.id)]): damage_player(player, 1, "snare" if enemy.kind == "moth" else "")
					if int(player.hp)<previous_hp: emit("enemy_mood",pos(enemy),-1,1.0,"joy",{"actor":int(enemy.id)})
					enemy.fired = true
					if Runestones.boon(player,"thorns") and int(player.rune_boon.retaliated)!=turn:
						player.rune_boon.retaliated=turn
						hit_enemy(enemy,1,"thorns:%s:%d"%[player.id,turn],pos(enemy))
	for p in players:
		if int(p.hp) <= 0: continue
		# Pair separation can push a token into the hearth on the very last step.
		if pos(p).length() <= CORE_RADIUS + float(p.r) + 0.00001:
			Spirits.touch_hearth(self, p, pos(p).normalized() * CORE_RADIUS)
		for ally in players:
			if int(ally.hp) <= 0 and pos(p).distance_to(pos(ally)) < 0.95 and attacking:
				ally.hp = 1; emit("heal", pos(ally), int(ally.id), 1.0, "+1")
		for item in pickups:
			if item.kind == "element": continue
			if not item.get("used", false) and pos(p).distance_to(pos(item)) < 0.7:
				if item.kind == "spirit":
					if attacking: Spirits.collect(self,p,item)
					continue
				item.used = true
				if item.kind == "heart": p.hp = mini(int(p.hp) + 1, int(p.max_hp))
				else: p.charges = mini(int(p.charges) + 1, 5)
				emit("heal", pos(p), int(p.id), 0.8, "+1")
	pickups = pickups.filter(func(x): return not x.get("used", false))
	# A same-step team contact may change the corpse's final momentum after its
	# lethal hit. Publish that resultant velocity, without awarding death twice.
	for event in events:
		if int(event.id) <= first_event or event.kind != "death" or event.get("surface", "") != "": continue
		for body in bodies:
			if int(body.id) == int(event.get("target", -1)) and int(body.hp) <= 0:
				event.vx = float(body.vx); event.vz = float(body.vz)
	enemies = enemies.filter(func(x): return int(x.hp) > 0)

# Only a moving player earns damage from a real surface/enemy rebound.
func record_ricochet(body: Dictionary, speed: float) -> void:
	if body.has("kind") or speed < 1.7: return
	body.ricochets = mini(MAX_RICOCHET_BONUS, int(body.get("ricochets", 0)) + 1)

func resolve_player_hit(p: Dictionary, e: Dictionary, key: String, incoming: Vector2, toward_enemy: Vector2, team_bonus: int) -> void:
	if int(e.hp) <= 0: return
	player_hit(p, e, key)
	if team_bonus > 0: hit_enemy(e, team_bonus, "team:" + key, pos(e))
	if int(e.hp) > 0:
		record_ricochet(p, incoming.length())
		return
	# A lethal contact punches through in the incoming direction, even if a
	# heavy enemy's collision impulse would otherwise bounce the player back.
	var direction := incoming.normalized() if incoming.length_squared() > 0.01 else toward_enemy
	var speed := maxf(incoming.length(), launch_speed(p, 1.0))
	velocity(p, direction * speed)
	resolve_deadline = minf(MAX_CHAIN_TIME, maxf(resolve_deadline, phase_time + KILL_FLIGHT_TIME))
	emit("kill_boost", pos(p), int(p.id), 1.0, "", {"target": int(e.id), "vx": float(p.vx), "vz": float(p.vz)})

func player_hit(p: Dictionary, e: Dictionary, key: String) -> void:
	if int(e.hp)<=0:return
	p.landed_hit=true
	var ricochet_bonus := clampi(int(p.get("ricochets", 0)), 0, MAX_RICOCHET_BONUS)
	var damage := 1 + int(p.damage) + ricochet_bonus + Spirits.hit(self,p,e,key)
	if e.kind == "ram" and int(e.get("recover_turn", -1)) == turn: damage += 1
	if p.statuses.has("weak"): damage = maxi(1, damage - 1)
	if bool(p.boost) and int(p.id) == 0: damage += 1; p.boost = false
	hit_enemy(e, damage, key + "hit", pos(e))
	if ricochet_bonus > 0:
		emit("ricochet_hit", pos(e), int(p.id), float(ricochet_bonus), "", {"target": int(e.id)})
	if Spirits.active(p,"frost"):Bosses.frost_strike(self,pos(e))
	if bool(p.boost) and int(p.id) == 3:
		p.boost = false; emit("blast", pos(e), 3, 2.0)
		for other in enemies:
			var offset := pos(other) - pos(e)
			if other.id != e.id and offset.length() < 2.0:
				velocity(other, vel(other) + offset.normalized() * 6.0 / sqrt(float(other.mass)))
				hit_enemy(other, 1, key + ":blast:%s" % other.id, pos(other))

func death_details(e: Dictionary, amount: int) -> Dictionary:
	var jump := float(e.get("jump", 0))
	var jump_duration := 1.70 if int(e.get("chill", 0)) > 0 else 0.95
	var motion := vel(e)
	if jump > 0:
		motion = (Vector2(float(e.tx), float(e.tz)) - Vector2(float(e.sx), float(e.sz))) / jump_duration
	return {"target": int(e.id), "enemy_kind": str(e.kind), "radius": float(e.r),
		"mass": float(e.mass), "vx": motion.x, "vz": motion.y, "damage": amount,
		"height": EnemyMotion.jump_height(e) if jump > 0 else 0.0,
		"vy": EnemyMotion.jump_velocity(e) if jump > 0 else 0.0,
		"team_size": int(team_contacts.get(str(int(e.id)), {}).get("count", 1))}

func hit_enemy(e: Dictionary, amount: int, key: String, point: Vector2, motion: Dictionary = {}) -> void:
	if hits.has(key) or int(e.hp) <= 0: return
	hits[key] = true; e.hp -= amount
	emit("damage", point, -1, float(amount), str(amount),{"target":int(e.id)})
	Bosses.damaged(self, e)
	if int(e.hp) <= 0:
		var details := death_details(e, amount)
		details.merge(motion, true)
		kills += 1; emit("death", point, -1, float(e.r) * 2.0, "", details)
		Runestones.collect(self,e,point)
		if rng.randf() < 0.28:
			entity_id += 1
			pickups.append({"id": entity_id, "x": point.x, "z": point.y, "kind": "heart" if rng.randf() < 0.55 else "charge"})

func block_player(p: Dictionary) -> bool:
	if Runestones.boon(p,"guard"):
		p.rune_boon={};emit("shield",pos(p),int(p.id),1.0);return true
	for guard in players:
		if int(guard.hp) > 0 and int(guard.shield) > 0 and (guard.id == p.id or (int(guard.id) == 1 and pos(guard).distance_to(pos(p)) < 2.0)):
			guard.shield -= 1; emit("shield", pos(p), 1, 1.0); return true
	if Spirits.active(p,"shield"):
		p.spirit={};emit("shield",pos(p),1,1.0);return true
	if int(p.armor) > 0: p.armor -= 1; emit("shield", pos(p), 1, 1.0); return true
	return false

func damage_player(p: Dictionary, amount: int, status: String = "") -> void:
	if int(p.hp) <= 0 or block_player(p): return
	p.hp = maxi(0, int(p.hp) - amount)
	if status == "burn": Effects.ignite(self, p, 1)
	elif status != "": p.statuses[status] = 2
	emit("hurt", pos(p), int(p.id), 1.0, "−%d" % amount)

func begin_enemy() -> void:
	if enemies.is_empty(): clear_wave(); return
	phase = "enemy"; phase_time = 0.0; hits.clear()
	var mocker:=-1
	for p in players:
		if bool(p.ready) and int(p.hp)>0 and not p.get("landed_hit",false):
			var nearest:=INF
			for e in enemies:
				if int(e.stun)==0 and pos(e).distance_to(pos(p))<nearest:
					nearest=pos(e).distance_to(pos(p));mocker=int(e.id)
			break
	for e in enemies:
		if int(e.stun)==0:emit("enemy_mood",pos(e),-1,1.0,"mock" if int(e.id)==mocker else "anger",{"actor":int(e.id)})
	for p in players: velocity(p, Vector2.ZERO)
	for e in enemies:
		velocity(e, Vector2.ZERO)
		e.sx = e.x; e.sz = e.z
		if e.attack == "rest": e.fired = true; continue
		if Effects.frozen(self, e): e.fired = true; e.cold_cancelled = true; continue
		if int(e.stun) > 0: e.stun -= 1; e.fired = true; continue
		if e.attack == "rush":
			if e.kind=="ram":e.charged_turn=turn
			var target := Vector2(float(e.tx), float(e.tz))
			velocity(e, (target - pos(e)).limit_length(5.5) * 1.85 * (0.55 if int(e.get("chill",0))>0 else 1.0))
		elif e.attack == "jump": e.jump = 0.001

func enemy_actions(dt: float) -> void:
	for e in enemies:
		if bool(e.fired): continue
		if e.attack == "rush":
			if pos(e).length() <= CORE_RADIUS + float(e.r) + 0.1:
				var previous_fire:=fire
				damage_fire(1); e.fired = true
				if fire<previous_fire:emit("enemy_mood",pos(e),-1,1.0,"joy",{"actor":int(e.id)})
				if e.kind in ["coal", "moth"]:
					e.hp=0;emit("death",pos(e),-1,float(e.r)*2.0,"",death_details(e,1))
			continue
		if e.attack == "jump":
			e.jump = minf(1.0, float(e.jump) + dt / (1.70 if int(e.get("chill",0))>0 else 0.95))
			var from := Vector2(float(e.sx), float(e.sz)); var to := Vector2(float(e.tx), float(e.tz))
			place(e, from.lerp(to, float(e.jump)))
			if float(e.jump) < 1.0: continue
			e.jump = 0.0; e.fired = true
			var radius := 1.6 if e.kind == "weaver" else 1.05
			area_attack(pos(e), radius, "frost" if e.kind == "weaver" else "",e)
			if e.kind == "weaver":
				if not Bosses.hot(self, e): add_hazard(pos(e), 1.8, "ice")
		elif phase_time > 0.9:
			e.fired = true
			if e.attack == "frost":
				var target := Vector2(float(e.tx), float(e.tz))
				area_attack(target, 1.1, "frost",e); add_hazard(target, 1.1, "ice")
			elif e.attack == "slam":
				area_attack(pos(e), 1.4, "weak",e)
				if pos(e).length() < 2.0: damage_fire(1)
			elif e.attack == "ring":
				var ring_radius := float(e.get("ring_radius", 4.5))
				emit("ring", Vector2.ZERO, 3, ring_radius)
				emit("boss_attack",pos(e),3,2.2)
				for p in players:
					if absf(pos(p).length() - ring_radius) < 0.8:
						var previous_hp:=int(p.hp);damage_player(p,1)
						if int(p.hp)<previous_hp:emit("enemy_mood",pos(e),-1,1.0,"joy",{"actor":int(e.id)})
				if Bosses.active(self, e) and turn % 3 == 0: damage_fire(1)
				if Bosses.active(self, e) and turn % 2 == 0: spawn("coal", rng.randf() * TAU)

func area_attack(center: Vector2, radius: float, status: String, attacker: Dictionary = {}) -> void:
	emit("ice" if status == "frost" else "blast", center, -1, radius)
	if not attacker.is_empty() and attacker.kind in ["ram","weaver","eater"]:emit("boss_attack",center,3,1.7)
	for p in players:
		if pos(p).distance_to(center) < radius + float(p.r) * 0.5:
			var previous_hp:=int(p.hp)
			if not attacker.is_empty() and Bosses.hot(self, attacker): Bosses.contact(self, p, attacker)
			else: damage_player(p, 1, status)
			if int(p.hp)<previous_hp and not attacker.is_empty():emit("enemy_mood",pos(attacker),-1,1.0,"joy",{"actor":int(attacker.id)})
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
	Bosses.end_turn(self)
	Effects.end_turn(self)
	for e in enemies: e.chill=0
	for p in players:
		for key in p.statuses.keys():
			if key in ["burn", "frozen"]: continue
			p.statuses[key] -= 1
			if int(p.statuses[key]) <= 0: p.statuses.erase(key)
	for h in hazards: h.turns -= 1
	hazards = hazards.filter(func(h): return int(h.turns) > 0)
	check_end()
	if phase == "lose": return
	if enemies.is_empty(): clear_wave()
	else: begin_plan()

func clear_wave() -> void:
	Effects.end_turn(self)
	check_end()
	if phase == "lose": return
	for p in players:
		var carried_fire := int(p.statuses.get("burn", 0)) if int(p.get("fire_pickup_turn", -1)) == turn and int(p.hp) > 0 else 0
		p.statuses.clear(); p.erase("freeze_turn")
		if carried_fire > 0: p.statuses.burn = carried_fire
	phase = "clear"; phase_time = 0.0
	for p in players: velocity(p, Vector2.ZERO)
	emit("clear", Vector2.ZERO, 1, 2.0, "ВОЛНА ПРОЙДЕНА")

func begin_reward() -> void:
	phase = "reward"; phase_time = 0.0; timer = 0.0; reward_options.clear()
	var keys: Array = Catalog.BOONS.keys()
	for i in range(keys.size() - 1, 0, -1):
		var j := rng.randi_range(0, i); var swap = keys[i]; keys[i] = keys[j]; keys[j] = swap
	reward_options = keys.slice(0, 3)
	for p in players:
		p.reward = false; p.reward_choice = -1; p.ready = false

func choose_reward(slot: int, choice: int) -> bool:
	if phase != "reward" or slot < 0 or slot >= players.size() or choice < 0 or choice >= reward_options.size(): return false
	var p: Dictionary = players[slot]
	if bool(p.reward) and int(p.reward_choice) == choice: return false
	p.reward = true; p.reward_choice = choice; timer = 0.0
	emit("ready", pos(p), slot)
	for other in players:
		if not bool(other.reward): return true
	timer = REWARD_READY_DELAY
	return true

func apply_reward(p: Dictionary, key: String) -> void:
	# Commit once, only after the whole party has settled on its choices.
	match key:
		"stitch": p.max_hp += 1; p.hp = mini(int(p.hp) + 1, int(p.max_hp))
		"spark": p.damage += 1
		"stride": p.speed = minf(1.75, float(p.speed) + 0.15)
		"charge": p.bonus_charges += 1
		"guard": p.armor_per_wave += 1
		"mend": fire = mini(max_fire, fire + 2)
	emit("heal", pos(p), int(p.id), 1.0)

func check_end() -> void:
	if phase in ["menu", "win", "lose"]: return
	if fire <= 0:
		phase = "lose"; emit("defeat",Vector2.ZERO);last_reason = "Огонь погас. Попробуйте прикрыть очаг Стражем."; return
	var alive := false
	for p in players:
		if int(p.hp) > 0: alive = true
	if not alive: phase = "lose"; emit("defeat",Vector2.ZERO);last_reason = "Все хранители погасли. Касайтесь павших, чтобы поднять их."

func snapshot() -> Dictionary:
	return {"element_contacts":element_contacts.duplicate(),"effects_tick_turn":effects_tick_turn,"team_contacts":team_contacts.duplicate(true),"rune_seed":rune_seed,"rune_serial":rune_serial,"rune_drops":rune_drops.duplicate(true),"stones":stones.duplicate(true),"soul_flights":soul_flights.duplicate(true),"players": players.duplicate(true), "enemies": enemies.duplicate(true), "hazards": hazards.duplicate(true), "pickups": pickups.duplicate(true), "events": events.duplicate(true), "phase": phase, "wave": wave, "turn": turn, "difficulty": difficulty, "fire": fire, "max_fire": max_fire, "timer": timer, "phase_time": phase_time, "resolve_deadline": resolve_deadline, "reward_options": reward_options.duplicate(), "kills": kills, "reason": last_reason}

func restore(s: Dictionary) -> void:
	element_contacts = s.get("element_contacts", {})
	effects_tick_turn = int(s.get("effects_tick_turn", -1))
	resolve_deadline = float(s.get("resolve_deadline", RESOLVE_TIME))
	team_contacts=s.get("team_contacts",{})
	stones=s.get("stones",stones);soul_flights=s.get("soul_flights",[])
	rune_seed=int(s.get("rune_seed",20260914));rune_serial=int(s.get("rune_serial",0));rune_drops=s.get("rune_drops",[])
	players = s.players; enemies = s.enemies; hazards = s.hazards; pickups = s.pickups; events = s.events
	phase = s.phase; wave = int(s.wave); turn = int(s.turn); difficulty = int(s.difficulty)
	fire = int(s.fire); max_fire = int(s.max_fire); timer = float(s.timer); phase_time = float(s.phase_time)
	reward_options = s.reward_options; kills = int(s.kills); last_reason = s.reason
