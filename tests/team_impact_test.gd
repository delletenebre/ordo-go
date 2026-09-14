extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Team=preload("res://scripts/team_impact.gd")
var checks:=0
var failures:=0
func _init()->void:call_deferred("run")
func check(value:bool,message:String)->void:
	checks+=1
	if not value:failures+=1;push_error(message)
func run()->void:
	var sim:=Sim.new();sim.start(3,1,33);sim.enemies.clear();sim.spawn("brute",0)
	var enemy:Dictionary=sim.enemies[0]
	check(Team.record(sim,sim.players[0],enemy,10,10)==0,"First player starts contact window")
	sim.phase_time=.1
	check(Team.record(sim,sim.players[0],enemy,10,10)==0,"Same player cannot create a team strike")
	check(Team.record(sim,sim.players[1],enemy,10,10)==1,"Second player inside 220ms earns one extra damage")
	check(sim.events[-1].kind=="team_clash" and sim.events[-1].multiplier==2,"Team strike is an authoritative event")
	check(Team.record(sim,sim.players[2],enemy,10,10)==1 and sim.events[-1].multiplier==3,"Third player upgrades the team strike")
	sim.team_contacts.clear();sim.phase_time=0
	Team.record(sim,sim.players[0],enemy,10,10);sim.phase_time=.221
	check(Team.record(sim,sim.players[1],enemy,10,10)==0,"Uncoordinated hits outside window remain ordinary")
	check(Team.record(sim,sim.players[0],enemy,4.49,12)==0,"Slow bumped players do not count")
	# Two actual fast players hit opposite sides of the same coal in one physics step.
	sim.start(2,1,33);sim.enemies.clear();sim.stones.clear();sim.spawn("coal",0)
	enemy=sim.enemies[0];sim.place(enemy,Vector2(0,3))
	sim.place(sim.players[0],Vector2(-.77,3));sim.place(sim.players[1],Vector2(.77,3))
	sim.velocity(sim.players[0],Vector2.RIGHT*11);sim.velocity(sim.players[1],Vector2.LEFT*11)
	sim.move_bodies(Sim.STEP,true)
	var clashes:=sim.events.filter(func(e):return e.kind=="team_clash")
	var deaths:=sim.events.filter(func(e):return e.kind=="death")
	check(clashes.size()==1,"Same-step lethal converging collision still triggers team effect")
	check(deaths.size()==1 and int(deaths[0].get("team_size",1))==2,"Only one death, with enhanced fracture")
	check(sim.kills==1,"Cooperative lethal contact never duplicates kill rewards")
	var remote:=Sim.new();remote.restore(JSON.parse_string(JSON.stringify(sim.snapshot())))
	check(remote.events.any(func(e):return e.kind=="team_clash" and int(e.multiplier)==2),"Remote receives team impact")
	print("TEAM IMPACT: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
