class_name OrdoAimPreview
extends RefCounted

const GUIDE_LENGTH := 5.0
const GUIDE_BOUNCE_TAIL := 1.4

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
	if absf(float(player.get("spin", 0.0))) > 0.001: return trace_curved(sim, player)
	var origin: Vector2 = sim.pos(player)
	var direction := Vector2.from_angle(float(player.angle))
	var radius := float(player.r)
	var distance: float = sim.launch_speed(player) / sim.DRAG * (1.0 - exp(-sim.DRAG * 4.5))
	var points := PackedVector2Array([origin])
	var result := {"points": points, "kind": "stop", "id": -1, "bounces": 0, "boost_segment": -1}
	for bounce in 2:
		var nearest := minf(distance, circle_distance(origin, direction, Vector2.ZERO, sim.RADIUS-radius, true))
		var kind := "wall" if nearest < distance else "stop"
		var normal := -(origin + direction * nearest).normalized()
		var hit_id := -1
		var charged:=false
		for obstacle in sim.stones + [{"x":0.0, "z":0.0, "r":sim.CORE_RADIUS}]:
			var center: Vector2 = sim.pos(obstacle)
			var hit := circle_distance(origin, direction, center, float(obstacle.r)+radius)
			if hit < nearest:
				nearest = hit; kind = "stone"; normal = (origin+direction*hit-center).normalized()
				charged=sim.Runestones.charged(obstacle) and obstacle.get("effect","")=="surge"
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
		var coefficient:float=sim.WALL_BOUNCE if kind=="wall" else sim.STONE_BOUNCE
		if kind=="stone" and charged:
			coefficient=2.0;result.boost_segment=points.size()-1
		distance=minf((distance-nearest)*coefficient,sim.Runestones.SPEED_LIMIT/sim.DRAG)
		if distance < 0.12: break
		direction = direction.bounce(normal)
		origin = end + normal * 0.005
		result.bounces += 1
	result.points = points
	return result

# Fixed-step curved forecast uses the same velocity rotation, drag and surface
# response as the throw. Other tokens are stationary until the first body hit.
static func trace_curved(sim, player: Dictionary) -> Dictionary:
	var location: Vector2 = sim.pos(player)
	var v := Vector2.from_angle(float(player.angle)) * float(sim.launch_speed(player))
	var spin := float(player.get("spin", 0.0))
	var radius := float(player.r)
	var points := PackedVector2Array([location])
	var contacts: Array[int] = []
	var result := {"points": points, "kind": "stop", "id": -1, "bounces": 0, "boost_segment": -1, "contacts": contacts, "first_end": -1}
	var obstacles: Array = sim.stones + [{"x": 0.0, "z": 0.0, "r": sim.CORE_RADIUS}]
	var bodies: Array = sim.players + sim.enemies
	var traveled := 0.0
	var rune_used := false
	for step in 540:
		v = sim.curl_velocity(v, spin, sim.STEP)
		spin *= exp(-sim.SPIN_DRAG * sim.STEP)
		var previous := location
		location += v * sim.STEP
		traveled += previous.distance_to(location)
		v *= exp(-sim.DRAG * sim.STEP)
		if v.length() < 0.07: v = Vector2.ZERO
		var surface := ""
		if location.length() > sim.RADIUS - radius:
			var n := location.normalized()
			location = n * (sim.RADIUS - radius); v = v.bounce(n) * sim.WALL_BOUNCE
			surface = "wall"
		for obstacle in obstacles:
			var diff: Vector2 = location - sim.pos(obstacle)
			var min_d := float(obstacle.r) + radius
			if diff.length() >= min_d: continue
			var n := diff.normalized() if diff.length() > 0.001 else Vector2.RIGHT
			location = sim.pos(obstacle) + n * min_d
			if v.dot(n) < 0.0:
				v = v.bounce(n)
				if not rune_used and v.length() >= 1.4 and sim.Runestones.charged(obstacle) and obstacle.get("effect", "") == "surge":
					v = v.normalized() * minf(v.length()*2.0, sim.Runestones.SPEED_LIMIT)
					rune_used = true; result.boost_segment = points.size()
				else: v *= sim.STONE_BOUNCE
				surface = "stone"
		if surface != "":
			points.append(location); contacts.append(points.size()-1)
			if result.first_end < 0: result.first_end = points.size()-1
			if result.bounces == 1:
				result.kind = surface; break
			result.bounces += 1
		var body_hit := false
		for body in bodies:
			if int(body.id) == int(player.id) or int(body.hp) <= 0: continue
			if float(body.get("jump", 0.0)) > 0: continue
			if location.distance_to(sim.pos(body)) >= float(body.r)+radius: continue
			points.append(location)
			result.kind = "enemy" if body.has("kind") else "ally"; result.id = int(body.id)
			body_hit = true; break
		if body_hit: break
		if v == Vector2.ZERO: break
		if surface == "" and step % 4 == 0 and traveled > radius+0.15 and points[-1].distance_to(location) > 0.07:
			points.append(location)
	if points[-1].distance_to(location) > 0.001 or points.size() == 1: points.append(location)
	if result.first_end < 0: result.first_end = points.size()-1
	result.points = points; result.contacts = contacts
	return result

# A bounded aiming hint uses one reference charge, independent of the held power.
# It suggests direction/curl and one reflection, not the eventual stopping point.
static func direction_guide(sim, player: Dictionary) -> Dictionary:
	var reference := player.duplicate(true)
	reference.power = 1.0
	var preview := trace(sim,reference)
	var points: PackedVector2Array = preview.points
	var contacts: Array = preview.get("contacts",range(1,points.size()-1))
	var limit := GUIDE_LENGTH
	var traveled := 0.0
	for i in range(1,points.size()):
		traveled += points[i-1].distance_to(points[i])
		if not contacts.is_empty() and i == int(contacts[0]):
			limit = minf(limit,traveled+GUIDE_BOUNCE_TAIL)
		elif contacts.size()>1 and i == int(contacts[1]):
			limit = minf(limit,maxf(0.0,traveled-.02))
	var guide := shorten(preview,limit)
	# A geometric hint never promises damage at a future body contact.
	guide.kind = "guide"; guide.id = -1
	return guide

# Crop by traveled distance, including any early reflection.
static func shorten(preview: Dictionary, max_distance: float) -> Dictionary:
	var result := preview.duplicate()
	var source: PackedVector2Array = preview.points
	var points := PackedVector2Array([source[0]])
	var remaining := max_distance
	var cropped := false
	for i in range(1,source.size()):
		var length := source[i-1].distance_to(source[i])
		if length > remaining:
			points.append(source[i-1].lerp(source[i],remaining/maxf(length,.001)))
			cropped = true; break
		points.append(source[i]); remaining -= length
	if not cropped: return result
	var contacts: Array = []
	for i in preview.get("contacts", range(1,source.size()-1)):
		if i < points.size()-1: contacts.append(i)
	result.points = points; result.contacts = contacts
	result.kind = "stop"; result.id = -1
	result.bounces = contacts.size()
	result.first_end = contacts[0] if not contacts.is_empty() else points.size()-1
	return result
