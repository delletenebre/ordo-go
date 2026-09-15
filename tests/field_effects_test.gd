extends SceneTree
const Sim = preload("res://scripts/simulation.gd")
const FX = preload("res://scripts/field_effects.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func fixture(count: int = 2):
	var sim := Sim.new(); sim.start(count,1,42)
	sim.pickups.clear(); sim.stones.clear(); sim.enemies.clear(); sim.hazards.clear()
	sim.spawn("brute",0); sim.enemies[0].hp=50; sim.enemies[0].max_hp=50
	sim.place(sim.enemies[0],Vector2(-4,-2))
	for i in sim.players.size(): sim.place(sim.players[i],Vector2(2+i*.80,2)); sim.velocity(sim.players[i],Vector2.ZERO)
	return sim

func pickup(sim, body: Dictionary, element: String) -> void:
	FX.collect(sim,body,{"id":999,"element":element,"x":body.x,"z":body.z})

func collide(sim, a: Dictionary, b: Dictionary, strong: bool = true) -> void:
	sim.element_contacts.clear()
	sim.place(a,Vector2(2,2)); sim.place(b,Vector2(2+float(a.r)+float(b.r)-.03,2))
	sim.velocity(a,Vector2(4 if strong else .3,0)); sim.velocity(b,Vector2.ZERO)
	FX.contacts(sim,[a,b])

func _init() -> void:
	for count in range(1,5):
		var sim=fixture(count); var p: Dictionary=sim.players[0]
		pickup(sim,p,"fire")
		check(int(p.statuses.burn)==1 and int(p.hp)==4,"Pickup stores one future tick for party %d"%count)
		var fresh:=Sim.new(); fresh.restore(JSON.parse_string(JSON.stringify(sim.snapshot())))
		FX.end_turn(fresh)
		check(int(fresh.players[0].hp)==4 and FX.burning(fresh,fresh.players[0]),"Fresh snapshot preserves pickup grace before first turn end")
		FX.end_turn(sim); check(int(p.hp)==4 and FX.burning(sim,p),"Pickup turn causes no damage or expiry")
		var saved:=Sim.new(); saved.restore(JSON.parse_string(JSON.stringify(sim.snapshot())))
		saved.begin_plan(); saved.launch()
		check(FX.burning(saved,saved.players[0]) and int(saved.players[0].hp)==4,"Snapshot carries flame into next throw")
		sim.begin_plan()
		for player in sim.players: player.ready=true
		sim.launch()
		check(FX.burning(sim,p),"Collected flame stays visible during next throw")
		FX.end_turn(sim); check(int(p.hp)==3 and not FX.burning(sim,p),"Pickup expires only after next throw")
		FX.end_turn(sim); check(int(p.hp)==3,"End-of-turn damage is idempotent")
	var sim=fixture(); var a: Dictionary=sim.players[0]; var b: Dictionary=sim.players[1]; var enemy: Dictionary=sim.enemies[0]
	pickup(sim,a,"fire"); collide(sim,a,b,false)
	check(int(a.statuses.burn)==1 and int(b.statuses.burn)==1,"Weak ally contact spreads one tick")
	collide(sim,a,b)
	check(int(a.statuses.burn)==2 and int(b.statuses.burn)==2,"Two already burning bodies refresh each other on a new strong blow")
	FX.end_turn(sim); check(int(a.hp)==4 and int(b.hp)==3 and int(a.statuses.burn)==2,"Contact refresh preserves collector grace and one tick per target")
	sim.begin_plan(); FX.end_turn(sim)
	check(int(a.hp)==3 and int(a.statuses.burn)==1 and not FX.burning(sim,b),"Collector begins refreshed burn on next turn")
	sim.begin_plan(); FX.end_turn(sim)
	check(int(a.hp)==2 and not FX.burning(sim,a),"Refreshed pickup expires after two deferred ticks")
	sim=fixture(); a=sim.players[0]; enemy=sim.enemies[0]
	pickup(sim,enemy,"fire"); collide(sim,a,enemy)
	check(int(a.statuses.burn)==2 and int(enemy.statuses.burn)==1,"Player hitting burning enemy gets two ticks without same-event backflow")
	FX.end_turn(sim)
	check(int(a.hp)==3 and int(enemy.hp)==50 and FX.burning(sim,enemy),"Enemy collector also carries fire to next turn")
	var restored:=Sim.new(); restored.restore(JSON.parse_string(JSON.stringify(sim.snapshot())))
	FX.end_turn(restored)
	check(int(restored.players[0].hp)==3,"Restored end-of-turn stamp prevents duplicate tick")
	# Same-step propagation through three bodies must not depend on storage order.
	for order in [[0,1,2],[2,1,0],[1,0,2],[1,2,0],[0,2,1],[2,0,1]]:
		sim=fixture(3)
		for i in 3: sim.velocity(sim.players[i],Vector2((3-i)*4,0))
		pickup(sim,sim.players[0],"fire")
		var bodies: Array=[]
		for i in order: bodies.append(sim.players[i])
		FX.contacts(sim,bodies)
		check(int(sim.players[0].statuses.burn)==1 and int(sim.players[1].statuses.burn)==2 and int(sim.players[2].statuses.burn)==2,"Strong chain is order independent %s"%str(order))
	# Pickup frost slows a player immediately without taking away the next throw.
	sim=fixture(); a=sim.players[0]; enemy=sim.enemies[0]
	sim.velocity(a,Vector2(10,0)); pickup(sim,a,"frost")
	check(is_equal_approx(sim.vel(a).length(),6) and not FX.frozen(sim,a),"Player pickup brakes existing momentum")
	pickup(sim,enemy,"frost"); sim.begin_enemy()
	check(enemy.fired and sim.vel(enemy)==Vector2.ZERO,"Enemy pickup cancels its current response")
	sim.end_turn(); check(not FX.cold(a) and not FX.frozen(sim,enemy),"Pickup cold expires after current turn")
	# Strong ice exchange is decided from the state before the blow.
	sim=fixture(); a=sim.players[0]; b=sim.players[1]
	pickup(sim,a,"frost"); collide(sim,a,b,false)
	check(FX.cold(a) and not FX.cold(b),"Weak contact neither shatters nor transfers frost")
	collide(sim,a,b)
	check(not FX.cold(a) and b.statuses.has("frozen") and int(b.freeze_turn)==sim.turn+1,"Strong hit frees source and schedules next-turn freeze")
	check(not FX.frozen(sim,b),"New ice does not steal the current throw")
	sim.end_turn()
	check(FX.frozen(sim,b) and b.ready,"Frozen player is ready without input next plan")
	check(not sim.command(1,{"action":"aim","power":1.0}) and not sim.command(1,{"action":"cancel"}),"Host refuses frozen player input")
	var charges:=int(b.charges); b.ability=true; sim.launch()
	check(sim.vel(b)==Vector2.ZERO and int(b.charges)==charges,"Frozen player skips launch and ability cost")
	FX.end_turn(sim); check(not FX.cold(b),"Frozen player recovers after skipped turn")
	sim=fixture(); a=sim.players[0]; enemy=sim.enemies[0]
	pickup(sim,a,"frost"); collide(sim,a,enemy); sim.end_turn(); sim.begin_enemy()
	check(enemy.fired and sim.vel(enemy)==Vector2.ZERO,"Transferred ice skips enemy next response")
	# Fire + ice cancels on either direction, including a weak contact.
	for strong in [false,true]:
		for reverse in [false,true]:
			sim=fixture(); a=sim.players[0]; b=sim.players[1]
			pickup(sim,a,"fire"); pickup(sim,b,"frost")
			collide(sim,b if reverse else a,a if reverse else b,strong)
			check(not FX.cold(a) and not FX.cold(b) and not FX.burning(sim,a) and not FX.burning(sim,b),"Opposite elements cancel before strong/weak transfer")
			var steam_events: Array=sim.events.filter(func(e):return e.kind=="steam")
			check(steam_events.size()==1,"Exactly one steam event per quench")
			FX.contacts(sim,[a,b])
			check(sim.events.filter(func(e):return e.kind=="steam").size()==1,"Persistent overlap does not replay steam")
	sim=fixture(); a=sim.players[0]; pickup(sim,a,"fire"); pickup(sim,a,"frost")
	check(not FX.cold(a) and not FX.burning(sim,a),"Opposite pickup neutralizes existing element")
	FX.ignite(sim,a,1); FX.end_turn(sim)
	check(int(a.hp)==3 and not FX.burning(sim,a),"Quenching clears pickup grace before a new contact burn")
	sim=fixture(); a=sim.players[0]; b=sim.players[1]
	pickup(sim,a,"fire"); b.armor=1; collide(sim,a,b)
	check(not FX.burning(sim,b) and int(b.armor)==0,"Armor blocks incoming status without contact HP damage")
	a.shield=1; FX.end_turn(sim)
	check(int(a.shield)==1 and FX.burning(sim,a),"Pickup grace does not consume shield")
	sim.begin_plan(); a.shield=1; FX.end_turn(sim)
	check(int(a.hp)==4 and not FX.burning(sim,a),"Shielded tick expires even when blocked")
	sim=fixture(3); a=sim.players[0]; b=sim.players[1]
	pickup(sim,a,"fire"); pickup(sim,sim.players[2],"fire"); b.armor=1
	sim.velocity(a,Vector2(4,0)); sim.velocity(sim.players[2],Vector2(-4,0))
	FX.contacts(sim,sim.players)
	check(b.statuses.get("burn",0)==2,"One armor charge cannot block two separate sources in the same physics step")
	# Integrated collision path, including the special ally clash early return.
	sim=fixture(); a=sim.players[0]; b=sim.players[1]
	pickup(sim,a,"fire"); sim.velocity(a,Vector2(7,0)); sim.velocity(b,Vector2(-7,0))
	sim.move_bodies(1.0/120,true)
	check(b.statuses.get("burn",0)==2 and a.clash_used and b.clash_used,"Ally clash carries strong fire before its early return")
	sim=fixture(); a=sim.players[0]; b=sim.players[1]
	pickup(sim,a,"frost"); pickup(sim,b,"fire"); sim.velocity(a,Vector2(7,0)); sim.velocity(b,Vector2(-7,0))
	sim.move_bodies(1.0/120,true)
	check(sim.events.any(func(event):return event.kind=="clash" and event.get("quenched",false)),"Steam replaces clash decoration while preserving its physical rebound")
	sim=fixture(); enemy=sim.enemies[0]
	sim.pickups.append({"id":998,"kind":"element","element":"fire","x":enemy.x,"z":enemy.z})
	sim.move_bodies(1.0/120,false)
	check(enemy.statuses.get("burn",0)==1 and sim.pickups.is_empty(),"Enemy physically collects and consumes source")
	sim=fixture(1); a=sim.players[0]; a.hp=1; pickup(sim,a,"fire"); sim.enemies.clear(); sim.begin_enemy()
	check(sim.phase=="clear" and int(a.hp)==1 and FX.burning(sim,a),"Final kill preserves fresh pickup without lethal tick")
	sim.begin_reward(); sim.next_wave()
	check(FX.burning(sim,a),"Fresh pickup survives rewards and next wave planning")
	sim.launch(); check(FX.burning(sim,a),"Wave transition keeps flame for next throw")
	FX.end_turn(sim); check(not FX.burning(sim,a),"Carried flame expires at next turn end")
	sim=fixture(1); a=sim.players[0]; a.hp=1; FX.ignite(sim,a,1); sim.enemies.clear(); sim.begin_enemy()
	check(sim.phase=="lose","Contact burn still ticks before final wave clear")
	sim=fixture(1); a=sim.players[0]; a.hp=1; FX.ignite(sim,a,2); sim.enemies[0].hp=1; FX.ignite(sim,sim.enemies[0],1); sim.end_turn()
	check(sim.phase=="lose" and sim.enemies.is_empty(),"Simultaneous final enemy/player burn deaths lose consistently")
	print("FIELD EFFECTS: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
