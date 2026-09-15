extends SceneTree
const Mend = preload("res://scripts/hearth_mend.gd")
const Arena = preload("res://scripts/arena.gd")
const Sim = preload("res://scripts/simulation.gd")
var checks := 0
var failures := 0
func _init() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)
func run() -> void:
	var event := {"kind": "hearth_mend", "fire_before": 3, "fire_after": 4, "x": 0.92, "z": 0, "color": 0}
	var pulses := [{"event": event, "life": 0.1}]
	check(Mend.pip_state(pulses, 3, 4).x == 0, "New socket waits for spark arrival")
	check(Mend.pip_state(pulses, 2, 4).x == 1, "Existing health stays lit")
	pulses[0].life = Mend.PIP_TIME + 0.2
	check(Mend.pip_state(pulses, 3, 4).x == 1 and Mend.pip_state(pulses, 3, 4).y > 0, "Arrival lights and pulses restored health")
	check(Mend.pip_state(pulses, 3, 3) == Vector2.ZERO, "Later damage overrides a pending heal animation")
	check(Mend.pip_state([], 3, 4) == Vector2(1, 0), "Late snapshot shows settled health without event")
	var from := Vector2(20, 60); var core := Vector2(100, 50); var socket := Vector2(120, 10)
	check(Mend.flight_point(from, core, socket, 0) == from, "Spark starts at contact")
	check(Mend.flight_point(from, core, socket, Mend.CORE_TIME) == core, "Spark passes through crystal")
	check(Mend.flight_point(from, core, socket, Mend.PIP_TIME) == socket, "Spark lands in restored socket")
	var arena := Arena.new(); arena.muted = true; root.add_child(arena)
	var sim := Sim.new(); sim.start(1, 1, 42); sim.events.clear()
	arena.play_event(event)
	arena.render_state(sim, 0.1)
	check(arena.flame_root.mend_age > 1, "Crystal waits for contact spark")
	arena.render_state(sim, 0.2)
	check(arena.flame_root.mend_age < 0.3, "Crystal blooms when spark arrives")
	var elapsed: float = arena.flame_root.mend_age
	arena.render_state(sim, 0.1)
	check(arena.flame_root.mend_age > elapsed, "Crystal pulse runs once")
	arena.reset_presentation()
	check(arena.hearth_mends.is_empty() and arena.flame_root.mend_age > 1, "New game clears pending mend presentation")
	arena.queue_free(); await process_frame
	print("HEARTH MEND: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
