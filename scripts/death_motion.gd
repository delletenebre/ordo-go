class_name OrdoDeathMotion
extends RefCounted

# Presentation physics only. Living actors, damage and rewards stay in Simulation.
const GRAVITY := 9.8
const STEP := 1.0 / 120.0
const WALL_INNER := 6.15
const WALL_OUTER := 6.83
const FLOOR := 0.045

static func wall_height(point: Vector2) -> float:
	var angle := point.angle()
	var rear := 1.0 - smoothstep(-0.15, 0.70, sin(angle))
	var height := 0.30 + rear * 0.17
	# Include the raised shoulders drawn by Masonry.wall.
	for i in 12:
		var shoulder := TAU * (i + 0.40) / 12.0 + 0.3
		var raised := 1.0 - smoothstep(-0.15, 0.65, sin(shoulder))
		if raised >= 0.25 and absf(angle_difference(angle, shoulder)) < 0.12:
			height = maxf(height, 0.60 + raised * 0.13)
	return height

static func create(event: Dictionary, previous: String = "") -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(event.id) * 1777 + int(event.get("target", 0)) * 31 + 29
	var kind := str(event.get("enemy_kind", "coal"))
	var radius := float(event.get("radius", 0.34))
	var mass := float(event.get("mass", 0.7))
	var velocity := Vector3(float(event.get("vx", 0)), 0, float(event.get("vz", 0)))
	var speed := velocity.length()
	var boss := mass >= 4.0
	var options: Array = ["crumble", "split", "topple"]
	if speed >= 3.0:
		options = ["roll", "skip", "slide"]
		if kind == "moth": options = ["flutter", "spin", "skip"]
		if kind == "frost": options = ["split", "slide", "air_split"]
		if kind == "brute" or boss: options = ["topple", "roll", "slide"]
	if speed >= 7.0 and not boss:
		options = ["flight", "air_split", "skip"]
		if kind == "moth": options = ["flutter", "spin", "flight"]
		if kind == "hopper": options = ["skip", "flight", "spin"]
		if kind == "frost": options = ["air_split", "split", "flight"]
	if options.has(previous) and options.size() > 1: options.erase(previous)
	var style: String = options[rng.randi_range(0, options.size() - 1)]
	var lift := 0.0
	if style in ["flight", "air_split", "flutter", "spin"]:
		lift = clampf(1.2 + speed * 0.27, 2.0, 5.8)
	elif style == "skip":
		lift = clampf(1.0 + speed * 0.10, 1.4, 2.5)
	# Heavy silhouettes tip and roll; mass is already included in horizontal speed.
	if mass >= 2.0: lift *= 0.72
	if boss: lift = minf(lift, 0.8)
	velocity.y = lift + float(event.get("vy", 0))
	var direction := Vector3(velocity.x, 0, velocity.z).normalized()
	var axis := Vector3.UP.cross(direction)
	if axis.length_squared() < 0.01: axis = Vector3.RIGHT
	var spin := axis * rng.randf_range(3.0, 6.0) / sqrt(maxf(mass, 0.5))
	if style in ["spin", "flutter"]: spin += Vector3.UP * rng.randf_range(5.0, 9.0)
	if style == "slide": spin *= 0.18
	var delay := rng.randf_range(0.15, 0.24)
	if style == "crumble": delay = rng.randf_range(0.09, 0.14)
	if style == "air_split": delay = rng.randf_range(0.30, 0.48)
	if boss: delay = rng.randf_range(0.65, 0.90)
	return {"event": event.duplicate(true), "kind": kind, "style": style,
		"radius": radius, "mass": mass, "boss": boss, "age": 0.0,
		"p": Vector3(float(event.x), radius * 0.94 + 0.03 + float(event.get("height", 0)), float(event.z)),
		"v": velocity, "spin": spin, "rotation": Vector3.ZERO, "delay": delay,
		"bounces": 0, "outside": false, "done": false, "reason": "", "trail": 0.0}

static func advance(state: Dictionary, dt: float, stones: Array = []) -> void:
	var remaining := dt
	while remaining > 0.000001 and not bool(state.done):
		var step := minf(STEP, remaining)
		_tick(state, step, stones)
		remaining -= step

static func _tick(s: Dictionary, dt: float, stones: Array) -> void:
	s.age += dt
	# Very short compression; no global pause and no loss of the incoming momentum.
	if float(s.age) <= 0.045: return
	if s.has("rim"):
		_rim_tick(s, dt)
		return
	var p: Vector3 = s.p
	var v: Vector3 = s.v
	var r := float(s.radius)
	var old := p
	v.y -= GRAVITY * dt
	p += v * dt
	s.rotation += s.spin * dt
	var horizontal := Vector2(p.x, p.z)
	var old_horizontal := Vector2(old.x, old.z)
	var distance := horizontal.length()
	var bottom := p.y - r * 0.90
	var outward := Vector2(v.x, v.z).dot(horizontal) > 0.0
	var wall_contact := distance + r > WALL_INNER and distance - r < WALL_OUTER
	if wall_contact and outward and bottom < wall_height(horizontal):
		var normal := horizontal.normalized()
		var radial_speed := Vector2(v.x, v.z).dot(normal)
		var top := wall_height(horizontal)
		if float(s.mass) >= 2.0 and not bool(s.boss) and radial_speed >= 6.0 and p.y > top + 0.05:
			# A heavy body catches the low parapet above its centre of contact.
			# Convert retained impact energy into a continuous roll around the lip.
			var contact := normal * (WALL_INNER - r)
			var pivot := normal * ((WALL_INNER + WALL_OUTER) * 0.5)
			var arm := Vector2(contact.length() - pivot.length(), p.y - top)
			var energy := radial_speed * radial_speed * 0.65 + 2.0 * GRAVITY * p.y
			if energy > 2.0 * GRAVITY * (top + arm.length()) + 1.0:
				s.rim = {"center": pivot, "normal": normal, "top": top, "arm": arm.length(),
					"angle": atan2(arm.x, arm.y), "energy": energy}
				s.style = "rim_roll"; s.p = Vector3(contact.x, p.y, contact.y)
				return
		# Clip at the inner face; never tunnel through the visible masonry.
		var contact := normal * minf(old_horizontal.length(), WALL_INNER - r)
		p.x = contact.x; p.z = contact.y
		var reflected := Vector2(v.x, v.z).bounce(normal) * 0.30
		v.x = reflected.x; v.z = reflected.y
		s.done = true; s.reason = "wall"
	if distance - r > WALL_OUTER: s.outside = true
	if not bool(s.outside):
		# Hearth and rune stones stop low corpses as they stop living actors.
		for index in range(-1, stones.size()):
			var center := Vector2.ZERO if index < 0 else Vector2(float(stones[index].x), float(stones[index].z))
			var obstacle_radius := 1.13 if index < 0 else float(stones[index].r)
			var top := 0.70 if index < 0 else 0.46
			var offset := horizontal - center
			if bottom < top and offset.length() < obstacle_radius + r and Vector2(v.x, v.z).dot(offset) < 0.0:
				p = old; v *= 0.35; s.done = true; s.reason = "stone"
				break
		var floor_center := FLOOR + r * 0.90
		if p.y <= floor_center and distance < WALL_INNER:
			p.y = floor_center
			if v.y < -1.0 and s.style in ["skip", "flutter"] and int(s.bounces) < 2:
				v.y = -v.y * (0.64 if s.kind == "hopper" else 0.45)
				v.x *= 0.83; v.z *= 0.83; s.bounces += 1
			elif s.style in ["flight", "spin", "air_split", "flutter"] and float(s.age) > 0.15:
				s.done = true; s.reason = "land"
			else:
				v.y = 0.0
				var friction := 0.85 if s.style == "slide" else 2.6
				v.x *= exp(-friction * dt); v.z *= exp(-friction * dt)
	if s.style in ["crumble", "split", "air_split"] and float(s.age) >= float(s.delay):
		s.done = true; s.reason = "fracture"
	if s.style in ["topple", "roll", "slide"] and float(s.age) >= (float(s.delay) if bool(s.boss) else 0.55):
		s.done = true; s.reason = "fracture"
	# Outside actors remain visible below the edge, then leave the bounded pool.
	if p.y < -3.2 or float(s.age) > 2.4:
		s.done = true; s.reason = "outside" if bool(s.outside) else "fracture"
	s.p = p; s.v = v

static func _rim_tick(s: Dictionary, dt: float) -> void:
	var rim: Dictionary = s.rim
	var speed := sqrt(maxf(0.0, float(rim.energy) - 2.0 * GRAVITY * Vector3(s.p).y))
	rim.angle = minf(PI * 0.5, float(rim.angle) + speed / float(rim.arm) * dt)
	var angle := float(rim.angle)
	var normal: Vector2 = rim.normal
	var point: Vector2 = rim.center + normal * float(rim.arm) * sin(angle)
	s.p = Vector3(point.x, float(rim.top) + float(rim.arm) * cos(angle), point.y)
	s.v = Vector3(normal.x * cos(angle) * speed, -sin(angle) * speed, normal.y * cos(angle) * speed)
	s.rotation += Vector3(-normal.y, 0, normal.x) * speed / float(rim.arm) * dt
	if angle >= PI * 0.5:
		s.outside = true
		s.erase("rim")

static func fragment_event(state: Dictionary) -> Dictionary:
	var event: Dictionary = state.event.duplicate(true)
	var p: Vector3 = state.p
	var v: Vector3 = state.v
	event.x = p.x; event.z = p.z; event.y = p.y
	event.vx = v.x; event.vy = v.y; event.vz = v.z
	event.directed = true; event.style = state.style
	return event
