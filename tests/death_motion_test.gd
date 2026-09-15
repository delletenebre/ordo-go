extends SceneTree
const Motion = preload("res://scripts/death_motion.gd")
const Sim = preload("res://scripts/simulation.gd")
const Arena = preload("res://scripts/arena.gd")
var checks := 0
var failures := 0

func _init() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)

func event_at(point: Vector2, velocity: Vector2, kind: String = "coal", mass: float = 0.7) -> Dictionary:
	return {"id": 1, "target": 20, "kind": "death", "color": -1, "text": "", "strength": 0.68,
		"radius": 0.34, "enemy_kind": kind, "mass": mass, "damage": 1,
		"x": point.x, "z": point.y, "vx": velocity.x, "vz": velocity.y}

func with_style(event: Dictionary, style: String) -> Dictionary:
	for i in 100:
		event.id = i + 1
		var state := Motion.create(event)
		if state.style == style: return state
	push_error("Missing eligible style: " + style)
	failures += 1
	return Motion.create(event)

func finish(state: Dictionary) -> void:
	for i in 360:
		Motion.advance(state, 1.0 / 120.0)
		if state.done: return

func run() -> void:
	var launch := event_at(Vector2(3, 3), Vector2(12, 0))
	var flight := with_style(launch, "flight")
	var outward_id := int(launch.id)
	Motion.advance(flight, 0.5)
	check(flight.outside and flight.p.x > Motion.WALL_OUTER and not flight.done, "Strong outward hit clears parapet with whole visible body")
	check(is_equal_approx(flight.p.z, 3.0), "Flight keeps the hit direction, without steering toward the closest edge")
	finish(flight)
	check(flight.reason == "outside" and flight.p.y < -3.0, "Body falls visibly below the arena before retirement")
	var low := with_style(event_at(Vector2(5.7, 0), Vector2(4, 0)), "slide")
	finish(low)
	check(low.reason == "wall" and not low.outside and low.v.x < 0, "Low trajectory strikes and fractures against the inner wall")
	var heavy_event := event_at(Vector2(5.45, 0.8), Vector2(9, 0), "brute", 2.2)
	heavy_event.radius = 0.49
	var heavy := with_style(heavy_event, "skip")
	var rolled_rim := false
	for i in 360:
		Motion.advance(heavy, 1.0 / 120.0)
		if heavy.style == "rim_roll": rolled_rim = true
		if heavy.done: break
	check(rolled_rim and heavy.outside and heavy.reason == "outside", "Heavy body can convert a strong lip contact into a continuous roll beyond the wall")
	var inward := with_style(event_at(Vector2(3, 3), Vector2(-8, 0)), "flight")
	finish(inward)
	check(not inward.outside and inward.reason == "land", "Insufficient inward flight lands inside instead of teleporting to an edge")
	var frost := with_style(event_at(Vector2(2, 3), Vector2(10, 0), "frost", 1.0), "air_split")
	finish(frost)
	var fragment := Motion.fragment_event(frost)
	check(frost.reason == "fracture" and fragment.y > 0.7 and fragment.vx > 9, "Air fracture inherits elevated position and forward momentum")
	check(fragment.enemy_kind == "frost" and fragment.directed, "Fragments preserve enemy material and directed breakup")
	var boss := Motion.create(event_at(Vector2(2, 3), Vector2(10, 0), "ram", 5.0))
	check(boss.style in ["topple", "roll", "slide"] and boss.v.y <= 0.8, "Boss silhouette remains heavy")
	var weak := Motion.create(event_at(Vector2(2, 3), Vector2.ZERO))
	check(weak.v == Vector3.ZERO and weak.style in ["crumble", "split", "topple"], "Damage without momentum cannot launch a corpse")
	var repeated := Motion.create(launch, str(Motion.create(launch).style))
	check(repeated.style != Motion.create(launch).style, "Eligible alternatives avoid an immediate identical death")
	for kind in ["coal", "moth", "hopper", "frost", "brute", "ram", "weaver", "eater"]:
		var variants: Dictionary = {}
		var mass: float = Sim.Catalog.ENEMIES[kind].mass
		for seed_value in 30:
			var varied := event_at(Vector2(2, 3), Vector2(9, 0), kind, mass)
			varied.id = seed_value
			var state := Motion.create(varied)
			variants[state.style] = true
			finish(state)
			check(state.done, "Every sampled death has a bounded lifetime: " + kind)
		check(variants.size() >= 3, "Each enemy type has at least three eligible reactions: " + kind)
	var small_steps := with_style(event_at(Vector2(3, 3), Vector2(12, 0)), "flight")
	var large_steps: Dictionary = small_steps.duplicate(true)
	for i in 60: Motion.advance(small_steps, 1.0 / 120.0)
	for i in 15: Motion.advance(large_steps, 1.0 / 30.0)
	check(small_steps.p.distance_to(large_steps.p) < 0.001, "Death trajectory agrees at 30 and 120 rendered FPS")
	var sim := Sim.new(); sim.start(1, 1, 42); sim.enemies.clear(); sim.stones.clear()
	sim.spawn("coal", 0)
	var dead: Dictionary = sim.enemies[0]
	sim.place(dead, Vector2(3, 3)); sim.velocity(dead, Vector2(12, 0))
	sim.hit_enemy(dead, 1, "test", sim.pos(dead))
	var death: Dictionary = sim.events[-1]
	check(death.kind == "death" and death.enemy_kind == "coal" and death.mass == 0.7, "Simulation publishes type and mass with the authoritative death")
	var kills := sim.kills; sim.hit_enemy(dead, 8, "test_again", sim.pos(dead))
	check(sim.kills == kills, "Animated death cannot award a second kill")
	var remote := Sim.new(); remote.restore(JSON.parse_string(JSON.stringify(sim.snapshot())))
	check(remote.events[-1].vx == 12.0 and remote.events[-1].enemy_kind == "coal", "Death momentum survives JSON snapshots")
	sim.spawn("hopper", 0); var jumper: Dictionary = sim.enemies[-1]
	jumper.jump = 0.25; jumper.sx = 1.0; jumper.sz = 3.0; jumper.tx = 4.0; jumper.tz = 3.0
	var jumping := sim.death_details(jumper, 2)
	check(jumping.height > 1.0 and jumping.vy > 0 and jumping.vx > 3.0, "Airborne death preserves the current jump height and both velocity components")
	# Wall deaths receive the reflected current velocity, never last-step velocity.
	sim.start(1, 1, 42); sim.enemies.clear(); sim.stones.clear(); sim.spawn("coal", 0)
	dead = sim.enemies[0]; sim.place(dead, Vector2(5.75, 0)); sim.velocity(dead, Vector2(10, 0))
	sim.move_bodies(Sim.STEP, true)
	death = sim.events[-1]
	check(death.kind == "death" and death.surface == "wall" and death.vx < 0, "Wall kill carries reflected motion, avoiding a false outward launch")
	# Remote presentation can start without an existing actor and is bounded.
	var arena := Arena.new(); arena.muted = true; root.add_child(arena)
	launch.id = outward_id
	arena.start_death(launch)
	check(arena.actors.has("20") and arena.death_motions.has("20"), "Missing remote actor is reconstructed for the flight")
	var moving: Dictionary = arena.death_motions["20"]
	var face_anchor: Node3D = moving.face.get_parent()
	var reference: Node3D = moving.rig.reference
	var face_offset: Vector3 = reference.visual.to_local(moving.face.global_position)
	arena.step_deaths(0.01)
	check(moving.face.position.is_equal_approx(Vector3.ZERO) and moving.face.get_parent()==face_anchor, "Death expressions keep their local origin beneath the face attachment")
	check(reference.visual.to_local(moving.face.global_position).is_equal_approx(face_offset), "Death rotation keeps the face attached to the visible body")
	for i in 30: arena.step_deaths(1.0 / 60.0)
	check(arena.actors.has("20") and arena.death_motions["20"].outside, "Whole actor persists across the boundary")
	for i in 180: arena.step_deaths(1.0 / 60.0)
	check(arena.actors.is_empty() and arena.death_motions.is_empty(), "Outside corpse is eventually released")
	arena.start_death(launch); arena.reset_presentation()
	check(arena.death_motions.is_empty() and arena.previous_deaths.is_empty(), "Restart clears animation and variant history")
	arena.queue_free(); await process_frame
	print("DEATH MOTION: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
