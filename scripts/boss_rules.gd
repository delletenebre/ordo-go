class_name OrdoBossRules
extends RefCounted

const KINDS = ["ram", "weaver", "eater"]
const MARK_SECONDS := 2.5

static func living(sim) -> int:
	var count := 0
	for p in sim.players:
		if int(p.hp) > 0: count += 1
	return count

# Freeze the reference hit at spawn; temporary buffs cannot move the phase gate.
static func configure(sim, enemy: Dictionary) -> void:
	if enemy.kind not in KINDS: return
	var count: int = sim.players.size()
	var damage := 0.0
	for p in sim.players: damage += 1 + int(p.damage)
	enemy.phase_hits = 0 if count == 1 else count + 1
	enemy.phase_hp = mini(int(enemy.max_hp) - 1, ceili(damage / count * int(enemy.phase_hits)))
	enemy.boss_phase = "calm"; enemy.phase_turn = -1; enemy.target_id = -1
	enemy.recover_turn = -1; enemy.burn_contacts = {}

static func active(sim, enemy: Dictionary) -> bool:
	return living(sim) > 1 and int(enemy.get("phase_turn", -1)) >= 0 and sim.turn >= int(enemy.phase_turn)

static func hot(sim, enemy: Dictionary) -> bool:
	return active(sim, enemy) and enemy.get("boss_phase", "") == "burning"

static func damaged(sim, enemy: Dictionary) -> void:
	if enemy.kind not in KINDS or int(enemy.hp) <= 0: return
	if enemy.get("boss_phase", "calm") != "calm" or living(sim) < 2: return
	if int(enemy.hp) > int(enemy.get("phase_hp", 0)): return
	enemy.phase_turn = sim.turn + 1
	enemy.boss_phase = {"ram":"cracked", "weaver":"burning", "eater":"hungry"}[enemy.kind]
	sim.emit("boss_phase", sim.pos(enemy), 1, 1.0, hint(sim, enemy), {"actor":int(enemy.id)})
	if enemy.kind == "weaver": drop_frost(sim, enemy)

static func plan(sim, enemy: Dictionary) -> void:
	if enemy.kind not in KINDS: return
	# Lock attacks to the planning snapshot, never home in after players launch.
	if enemy.kind == "eater":
		enemy.ring_radius = (2.4 if sim.turn % 2 == 0 else 4.5) if active(sim, enemy) else 4.5
	if enemy.kind == "ram" and int(enemy.get("recover_turn", -1)) == sim.turn:
		enemy.attack = "rest"; enemy.tx = enemy.x; enemy.tz = enemy.z; enemy.target_id = -1
		enemy.fired = true

static func end_turn(sim) -> void:
	for e in sim.enemies:
		if e.kind == "ram" and active(sim, e) and e.attack == "rush" and int(e.get("charged_turn",-1)) == sim.turn:
			e.recover_turn = sim.turn + 1

static func ignite(sim, player: Dictionary) -> void:
	sim.Effects.ignite(sim, player, 1)

# One hot contact per player per turn, including slow contact and both phases.
static func contact(sim, player: Dictionary, enemy: Dictionary) -> void:
	if not hot(sim, enemy) or int(enemy.hp) <= 0: return
	var key := str(int(player.id))
	if int(enemy.burn_contacts.get(key, -1)) == sim.turn: return
	enemy.burn_contacts[key] = sim.turn
	sim.damage_player(player, 1, "burn")

static func frost_strike(sim, point: Vector2) -> void:
	for p in sim.players:
		if sim.pos(p).distance_to(point) <= 1.8 and p.statuses.has("burn"):
			sim.Effects.steam(sim, p, p, sim.pos(p), Vector2.RIGHT)
	for e in sim.enemies:
		if e.get("boss_phase", "") == "burning" and sim.pos(e).distance_to(point) <= float(e.r) + .6:
			sim.Effects.steam(sim, e, e, sim.pos(e), Vector2.RIGHT)
		elif e.get("statuses", {}).has("burn") and sim.pos(e).distance_to(point) <= float(e.r) + .6:
			sim.Effects.steam(sim, e, e, sim.pos(e), Vector2.RIGHT)

static func drop_frost(sim, enemy: Dictionary) -> void:
	# Deterministically choose a clear spot toward the closest living player.
	var destination := Vector2.ZERO
	var best := INF
	for i in 96:
		var point := Vector2.from_angle(i * TAU / 96.0) * (2.6 if i % 2 else 4.0)
		var free := true
		for b in sim.enemies + sim.stones + sim.pickups + sim.rune_drops:
			if point.distance_to(sim.pos(b)) < float(b.get("r", .4)) + .75: free = false; break
		if not free: continue
		for p in sim.players:
			if int(p.hp) <= 0: continue
			var score: float = point.distance_to(sim.pos(p)) + .25 * point.distance_to(sim.pos(enemy))
			if score < best: best = score; destination = point
	if best == INF:
		# Crowded-board rescue: land beside a living player, inside the parapet.
		for p in sim.players:
			if int(p.hp) > 0: destination = sim.pos(p).limit_length(4.7); break
	sim.entity_id += 1
	sim.rune_drops.append({"id":sim.entity_id, "spirit":"frost", "x":destination.x, "z":destination.y,
		"sx":float(enemy.x), "sz":float(enemy.z), "height":float(enemy.r), "left":sim.Runestones.FLIGHT_TIME,
		"boss_gift":true, "boss_id":int(enemy.id)})

static func ensure_counter(sim) -> void:
	var source: Dictionary = {}
	var needed := false
	for e in sim.enemies:
		if e.kind == "weaver": source=e
		if hot(sim,e): needed=true
	for p in sim.players:
		if int(p.hp)<=0:continue
		if p.statuses.has("burn"): needed=true
		if p.get("spirit",{}).get("kind","")=="frost" or p.get("pending_spirit","")=="frost":return
	if not needed:return
	for item in sim.pickups+sim.rune_drops:
		if item.get("spirit","")=="frost" and not item.get("used",false):return
	if source.is_empty():
		for p in sim.players:
			if int(p.hp)>0:source=p;break
	if not source.is_empty():drop_frost(sim,source)

static func hint(sim, enemy: Dictionary) -> String:
	if enemy.kind not in KINDS: return ""
	if living(sim) == 1: return "Один игрок · без второй фазы"
	match enemy.get("boss_phase", "calm"):
		"burning": return "Мороз тушит босса и союзников рядом"
		"doused": return "Потушена · можно добивать"
		"cracked": return "Уязвим: +1 урон" if int(enemy.get("recover_turn", -1)) == sim.turn else "Уйдите с линии · затем бейте"
		"hungry": return "Кольца чередуются · смените дистанцию"
	return "Вторая фаза: ≈ %d ударов до гибели" % int(enemy.get("phase_hits", 0))

static func marker_alpha(age: float) -> float:
	return smoothstep(0.0, .18, age) * (1.0 - smoothstep(2.0, MARK_SECONDS, age))
