extends RefCounted
## Contact -> crystal -> health socket. Shared timing for the world and HUD.
const CORE_TIME := 0.28
const PIP_TIME := 0.68
const DURATION := 1.2
const GOLD := Color("ffd477")
const WHITE := Color("fff4cf")
const VIOLET := Color("d8b6ff")

static func pip_state(events: Array, hp: int, fire: int) -> Vector2:
	if hp >= fire: return Vector2.ZERO
	for item in events:
		var e: Dictionary = item.event
		if e.kind != "hearth_mend" or hp != int(e.fire_after) - 1: continue
		var age: float = item.life - PIP_TIME
		if age < 0: return Vector2.ZERO
		return Vector2(smoothstep(0.0, 0.12, age), sin(clampf(age / 0.5, 0, 1) * PI))
	return Vector2(1, 0)

static func flight_point(from: Vector2, crystal: Vector2, socket: Vector2, t: float) -> Vector2:
	if t < CORE_TIME:
		var u := smoothstep(0.0, CORE_TIME, t)
		return from.lerp(crystal, u) + Vector2(0, -sin(u * PI) * 20)
	var u := smoothstep(CORE_TIME, PIP_TIME, t)
	return crystal.lerp(socket, u) + Vector2(sin(u * PI) * 24, 0)

static func draw(hud, core: Vector2, spacing: float) -> void:
	for item in hud.pulse_events:
		var e: Dictionary = item.event
		if e.kind != "hearth_mend": continue
		var t: float = item.life
		var from: Vector2 = hud.project(Vector2(e.x, e.z), 0.28)
		var crystal: Vector2 = hud.project(Vector2.ZERO, 0.7)
		var socket := core + Vector2((int(e.fire_after) - 1 - (hud.game.sim.max_fire - 1) * 0.5) * spacing, -1)
		if t < CORE_TIME:
			var pulse := t / CORE_TIME
			hud.draw_arc(from, 7 + pulse * 22, 0, TAU, 32, Color(VIOLET, 1 - pulse), 2, true)
		if t < PIP_TIME:
			# A tapered ribbon stays connected to the moving spark.
			var trail := PackedVector2Array()
			for index in 14:
				trail.append(flight_point(from, crystal, socket, maxf(0, t - (13 - index) * 0.009)))
			hud.draw_polyline(trail, Color(GOLD, 0.12), 13, true)
			hud.draw_polyline(trail, Color(GOLD, 0.6), 4, true)
			hud.draw_polyline(trail, WHITE, 1.5, true)
			var head := trail[-1]
			hud.draw_circle(head, 10, Color(GOLD, 0.1))
			hud.draw_circle(head, 5, GOLD)
			hud.draw_circle(head, 2.5, WHITE)
		if t >= CORE_TIME:
			var pulse := clampf((t - CORE_TIME) / 0.5, 0, 1)
			hud.world_ring(Vector2.ZERO, 0.95 + pulse * 0.8, Color(GOLD, (1 - pulse) * 0.65), 2)
		if t >= PIP_TIME and int(e.fire_after) <= hud.game.sim.fire:
			var age := t - PIP_TIME
			var alpha := 1 - smoothstep(0.28, 0.52, age)
			for i in 8:
				var ray := Vector2.from_angle(i * TAU / 8)
				hud.draw_line(socket + ray * (17 + age * 22), socket + ray * (23 + age * 30), Color(GOLD, alpha), 1.6, true)
			var origin := socket + Vector2(-14, -29 - age * 25)
			hud.draw_string_outline(hud.font, origin, "+1", HORIZONTAL_ALIGNMENT_LEFT, -1, 27, 5, Color(0.05, 0.03, 0.02, alpha))
			hud.draw_string(hud.font, origin, "+1", HORIZONTAL_ALIGNMENT_LEFT, -1, 27, Color(WHITE, alpha))
