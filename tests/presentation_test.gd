extends SceneTree
const Sim = preload("res://scripts/simulation.gd")
const Preview = preload("res://scripts/aim_preview.gd")
const Arena = preload("res://scripts/arena.gd")
var failures := 0
var checks := 0
func _init() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)
func run() -> void:
	var sim := Sim.new(); sim.start(1,1,42)
	sim.stones.clear(); sim.enemies.clear()
	var p: Dictionary = sim.players[0]
	sim.place(p,Vector2(0,3.5)); p.angle=0.0; p.power=0.15
	var before := JSON.stringify(sim.snapshot())
	var low := Preview.trace(sim,p)
	check(JSON.stringify(sim.snapshot())==before,"Preview is read-only")
	p.power=0.70; var high := Preview.trace(sim,p)
	check(low.points[1].distance_to(sim.pos(p))<high.points[1].distance_to(sim.pos(p)),"Power changes useful range")
	var base_speed := sim.launch_speed(p)
	p.statuses={"frost":1,"snare":1}
	check(is_equal_approx(sim.launch_speed(p),base_speed*0.6*0.7),"Preview and throw share debuff speed")
	p.statuses={}; p.angle=-PI/2
	var center := Preview.trace(sim,p)
	check(center.bounces==1,"Core predicts a reflection")
	check(absf(center.points[1].length()-(sim.CORE_RADIUS+float(p.r)))<0.002,"Reflection accounts for token radius")
	p.angle=0.0; sim.place(p,Vector2(5.4,0)); var wall := Preview.trace(sim,p)
	check(wall.bounces==1 and wall.points[2].x<wall.points[1].x,"Wall reflection points inward")
	sim.place(p,Vector2(0,3)); sim.enemies=[{"id":11,"x":2.0,"z":3.0,"r":0.4,"hp":2,"kind":"coal","jump":0.0}]
	var enemy := Preview.trace(sim,p)
	check(enemy.kind=="enemy" and enemy.id==11,"Stops at first enemy")
	check(absf(enemy.points[-1].x-1.17)<0.002,"Enemy contact includes both radii")
	check(Preview.circle_distance(Vector2(0.9,0),Vector2.RIGHT,Vector2.ZERO,1.0)==INF,"Escapes starting overlap")
	# Compare open-lane prediction against the actual fixed-step damped throw.
	sim.enemies.clear(); sim.place(p,Vector2(0,3));p.power=0.15;p.ready=true
	var endpoint: Vector2 = Preview.trace(sim,p).points[-1]
	sim.launch()
	for i in 540: sim.move_bodies(Sim.STEP,true)
	check(sim.pos(p).distance_to(endpoint)<0.06,"Free-shot endpoint agrees with fixed-step physics")
	var arena := Arena.new(); arena.muted=true; root.add_child(arena)
	sim.start(2,1,42); arena.render_state(sim,0.016)
	var id := str(int(sim.enemies[0].id)); var actor = arena.actors[id]
	for i in 40: arena.render_state(sim,1.0/60.0)
	check(arena.smoke.active_count()>0,"Idle enemies produce smoke")
	check(arena.actors[id]==actor,"Actors retain identity across frames")
	# JSON numbers may be floats. They must resolve to the same presentation actor.
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(sim.snapshot()));sim.restore(snapshot)
	arena.render_state(sim,0.016,true)
	check(arena.actors[id]==actor,"Network JSON does not recreate actors")
	var dead: Dictionary = sim.enemies.pop_front();sim.emit("death",sim.pos(dead))
	arena.render_state(sim,0.016)
	check(arena.actors.has(id) and arena.retiring.has(id),"Death retains actor for its dissolve")
	check(arena.smoke.active_count()>10,"Death emits persistent smoke")
	for i in 45: arena.render_state(sim,1.0/60.0)
	check(not arena.actors.has(id),"Death retires after settle")
	arena.smoke.clear()
	for i in arena.smoke.CAPACITY: arena.smoke.emit_puff(Vector3.ZERO,Vector3.UP,1.0,2.0)
	check(not arena.smoke.emit_puff(Vector3.ONE,Vector3.UP,1.0,2.0),"Saturated pool never replaces live smoke")
	check(arena.smoke.puffs[0].p==Vector3.ZERO,"No particle teleport on saturation")
	arena.reset_presentation()
	check(arena.smoke.active_count()==0 and arena.actors.is_empty(),"New match clears old presentation")
	arena.queue_free(); await process_frame; await create_timer(0.1).timeout
	print("PRESENTATION: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
