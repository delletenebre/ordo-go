extends SceneTree
const Sim = preload("res://scripts/simulation.gd")
const Arena = preload("res://scripts/arena.gd")
const Spirits = preload("res://scripts/spirits.gd")
var failures := 0
var checks := 0
func _init() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)
func run() -> void:
	var sim := Sim.new(); sim.start(4,1,42); sim.pickups.clear()
	var arena := Arena.new(); arena.muted = true; root.add_child(arena)
	var index := 0
	for kind in Spirits.TYPES:
		sim.pickups.append({"id":900+index,"kind":"spirit","spirit":kind,"x":float(index)-3,"z":0.0,"expires":4})
		index += 1
	sim.pickups.append({"id":920,"kind":"heart","x":-1.0,"z":-2.0})
	sim.pickups.append({"id":921,"kind":"charge","x":1.0,"z":-2.0})
	sim.add_hazard(Vector2(3,-2),0.8,"ice")
	for i in 4: sim.players[i].statuses = { ["burn","frost","snare","weak"][i]:2 }
	var state := JSON.stringify(sim.snapshot())
	for i in 30: arena.render_state(sim,1.0/60)
	var visuals = arena.spirit_visuals
	check(visuals.patches.size()==7,"All seven spirits receive magic")
	check(visuals.fields.size()==7,"Both pickups, all four curses and ice zone receive magic")
	check(JSON.stringify(sim.snapshot())==state,"Magic does not mutate gameplay")
	var patch: Dictionary = visuals.patches["900"]
	var aura = patch.aura
	sim.restore(JSON.parse_string(state)); arena.render_state(sim,0.016,true)
	check(visuals.patches["900"].aura==aura,"Network snapshot retains aura identity")
	var item: Dictionary = sim.pickups[0]
	Spirits.collect(sim,sim.players[0],item);sim.pickups.remove_at(0)
	arena.render_state(sim,0.016)
	check(patch.exit and patch.owner==0,"Pickup follows the receiving player")
	check(aura.get_parent()==patch.node,"Magic travels with the original medallion")
	for i in 45: arena.render_state(sim,1.0/60)
	check(not visuals.patches.has("900") and visuals.fields.has("pending:0:eagle"),"Arrival hands magic to the recipient")
	sim.players[0].statuses.clear(); arena.render_state(sim,0.016)
	check(visuals.fields.has("status:0:burn"),"Expired curse fades instead of disappearing")
	for i in 30: arena.render_state(sim,1.0/60)
	check(not visuals.fields.has("status:0:burn"),"Expired curse releases its visual")
	arena.reset_presentation()
	check(visuals.fields.is_empty() and visuals.patches.is_empty(),"Reset clears every magic effect")
	arena.queue_free(); await process_frame
	print("MAGIC: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
