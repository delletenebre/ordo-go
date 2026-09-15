extends SceneTree
const Sim = preload("res://scripts/simulation.gd")
const Preview = preload("res://scripts/aim_preview.gd")
var failures := 0
var checks := 0
func _init() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)
func run() -> void:
	var sim := Sim.new(); sim.start(1,1,42); sim.stones.clear(); sim.enemies.clear()
	var p: Dictionary = sim.players[0]
	check(sim.command(0,{"action":"aim","spin":8.0}) and p.spin==1.0,"Clamp positive spin")
	check(sim.command(0,{"action":"aim","spin":-8.0}) and p.spin==-1.0,"Clamp negative spin")
	check(not sim.command(0,{"action":"aim","spin":NAN}),"Reject nonfinite spin")
	var endpoints: Array[Vector2] = []
	for spin in [-1.0,0.0,1.0]:
		# Both mirrored arcs need open space, without an incidental wall reflection.
		sim.begin_plan(); sim.place(p,Vector2(-3.0,2.5)); p.angle=0; p.power=.15; p.spin=spin; p.ready=true
		var before := JSON.stringify(sim.snapshot())
		var preview := Preview.trace(sim,p)
		check(JSON.stringify(sim.snapshot())==before,"Curved preview does not mutate simulation")
		var endpoint: Vector2 = preview.points[-1]
		sim.launch()
		for i in 540: sim.move_bodies(Sim.STEP,true)
		check(sim.pos(p).distance_to(endpoint)<.06,"Preview and fixed-step path agree for spin %s" % spin)
		endpoints.append(sim.pos(p))
	check(endpoints[0].y < endpoints[1].y and endpoints[1].y < endpoints[2].y,"L1 and R1 bend to opposite sides")
	check(absf(endpoints[0].x-endpoints[2].x)<.001 and absf(endpoints[0].y+endpoints[2].y-5)<.001,"Opposite spin gives mirrored throws")
	# Energy stays unchanged; curl alters direction, not speed or damage thresholds.
	for power in [.15,.575,1.0]:
		p.power=power
		var launch_speed:=sim.launch_speed(p)
		var v := Vector2(launch_speed,0); var spin := 1.0; var angle := 0.0; var max_speed_error := 0.0
		for i in 540:
			var curled := Sim.curl_velocity(v,spin,Sim.STEP)
			max_speed_error = maxf(max_speed_error,absf(curled.length()-v.length()))
			angle += v.angle_to(curled); v=curled*exp(-Sim.DRAG*Sim.STEP); spin*=exp(-Sim.SPIN_DRAG*Sim.STEP)
		check(max_speed_error<.00001,"Curl conserves speed throughout flight")
		var decay := (Sim.DRAG+Sim.SPIN_DRAG)*Sim.STEP
		var expected: float = Sim.CURL_RATE*launch_speed*Sim.STEP*(1-exp(-decay*540))/(1-exp(-decay))
		check(absf(angle-expected)<.0001,"Accumulated curvature matches the closed-form discrete sum")
		print("CURL power=",power," angle=",rad_to_deg(angle))
	# Surface reflection shares the fixed-step response, including spin after bounce.
	for position in [Vector2(4.8,1.8),Vector2(-2.3,0.7)]:
		sim.begin_plan(); sim.place(p,position); p.angle=0; p.power=.15; p.spin=.8; p.ready=true
		var preview := Preview.trace(sim,p)
		check(preview.bounces==1,"Curved shot predicts surface bounce")
		sim.launch()
		for i in 540: sim.move_bodies(Sim.STEP,true)
		check(sim.pos(p).distance_to(preview.points[-1])<.02,"Reflected curved forecast matches physics")
	# Remote JSON retains both chosen spin and its decaying flight state.
	var restored := Sim.new(); restored.restore(JSON.parse_string(JSON.stringify(sim.snapshot())))
	check(is_equal_approx(restored.players[0].spin,p.spin) and is_equal_approx(restored.players[0].flight_spin,p.flight_spin),"Snapshot preserves spin")
	sim.begin_plan(); check(p.spin==0.0 and p.flight_spin==0.0,"Next turn clears spin")
	print("SPIN: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
