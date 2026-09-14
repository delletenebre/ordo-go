class_name OrdoAimPreview
extends RefCounted

# Trace the initial throw only. Other players' simultaneous impulses are unknown.
static func circle_distance(origin: Vector2, direction: Vector2, center: Vector2, radius: float, inside: bool = false) -> float:
	var offset := origin - center
	var b := offset.dot(direction)
	var c := offset.length_squared() - radius * radius
	var discriminant := b * b - c
	if discriminant < 0: return INF
	if not inside and c < 0 and b >= 0: return INF
	var distance := -b + sqrt(discriminant) if inside else -b - sqrt(discriminant)
	return maxf(0.0, distance) if distance >= -0.001 or c < 0 else INF

static func trace(sim, player: Dictionary) -> Dictionary:
	var origin: Vector2 = sim.pos(player)
	var direction := Vector2.from_angle(float(player.angle))
	var radius := float(player.r)
	var distance: float = sim.launch_speed(player) / 1.7 * (1.0 - exp(-1.7 * 4.5))
	var points := PackedVector2Array([origin])
	var result := {"points": points, "kind": "stop", "id": -1, "bounces": 0}
	for bounce in 2:
		var nearest := minf(distance, circle_distance(origin, direction, Vector2.ZERO, sim.RADIUS-radius, true))
		var kind := "wall" if nearest < distance else "stop"
		var normal := -(origin + direction * nearest).normalized()
		var hit_id := -1
		for obstacle in sim.stones + [{"x":0.0, "z":0.0, "r":sim.CORE_RADIUS}]:
			var center: Vector2 = sim.pos(obstacle)
			var hit := circle_distance(origin, direction, center, float(obstacle.r)+radius)
			if hit < nearest:
				nearest = hit; kind = "stone"; normal = (origin+direction*hit-center).normalized()
		for body in sim.players + sim.enemies:
			if int(body.id) == int(player.id) or int(body.hp) <= 0: continue
			if body.has("jump") and float(body.jump)>0: continue
			var hit := circle_distance(origin, direction, sim.pos(body), float(body.r)+radius)
			if hit < nearest:
				nearest = hit; kind = "enemy" if body.has("kind") else "ally"; hit_id = int(body.id)
		var end := origin + direction * nearest
		points.append(end)
		result.kind = kind; result.id = hit_id
		if kind not in ["wall", "stone"] or bounce == 1: break
		distance = (distance-nearest)*(0.72 if kind == "wall" else 0.7)
		if distance < 0.12: break
		direction = direction.bounce(normal)
		origin = end + normal * 0.005
		result.bounces += 1
	result.points = points
	return result
