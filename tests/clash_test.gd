extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Clash=preload("res://scripts/player_clash.gd")
var checks:=0
var failures:=0
func _init()->void:call_deferred("run")
func check(value:bool,message:String)->void:
	checks+=1
	if not value:failures+=1;push_error(message)
func run()->void:
	var sim:=Sim.new();sim.start(2,1,77);sim.enemies.clear();sim.stones.clear()
	var a:Dictionary=sim.players[0];var b:Dictionary=sim.players[1]
	check(Clash.eligible(a,b,Vector2.RIGHT*6,Vector2.LEFT.rotated(deg_to_rad(44.9))*6,Vector2.RIGHT),"44.9 degree opposing approach qualifies")
	check(not Clash.eligible(a,b,Vector2.RIGHT*6,Vector2.LEFT.rotated(deg_to_rad(45.1))*6,Vector2.RIGHT),"45.1 degree approach does not qualify")
	check(not Clash.eligible(a,b,Vector2.RIGHT*5.49,Vector2.LEFT*9,Vector2.RIGHT),"Both players must be fast")
	check(not Clash.eligible(a,b,Vector2.RIGHT*9,Vector2.RIGHT*9,Vector2.RIGHT),"Following collision cannot trigger")
	check(not Clash.eligible(a,b,Vector2.RIGHT*9,Vector2.LEFT*9,Vector2.DOWN),"Glancing trajectories cannot trigger")
	sim.place(a,Vector2(-.44,3));sim.place(b,Vector2(.44,3))
	sim.velocity(a,Vector2.RIGHT*7);sim.velocity(b,Vector2.LEFT*7)
	sim.move_bodies(Sim.STEP,true)
	var events:=sim.events.filter(func(e):return e.kind=="clash")
	check(events.size()==1 and events[0].multiplier==2,"Actual collision triggers double clash")
	check(sim.vel(a).x<0 and sim.vel(b).x>0,"Random launch directions split outward")
	check(a.hp==4 and b.hp==4,"Cooperative clash does not hurt players")
	check(a.clash_used and b.clash_used,"Both participants spend their clash for this throw")
	check(not Clash.resolve(sim,a,b,Vector2.RIGHT),"Clash cannot chain repeatedly")
	a.clash_used=false;b.clash_used=false
	sim.velocity(a,Vector2.RIGHT*12);sim.velocity(b,Vector2.LEFT*12)
	Clash.resolve(sim,a,b,Vector2.RIGHT)
	check(sim.events[-1].multiplier==3 and is_equal_approx(sim.vel(a).length(),24),"Strong throws get triple impulse with speed cap")
	var packet:=JSON.parse_string(JSON.stringify(sim.snapshot())) as Dictionary
	var remote:=Sim.new();remote.restore(packet)
	check(remote.vel(remote.players[0]).is_equal_approx(sim.vel(a)) and remote.events[-1].kind=="clash" and int(remote.events[-1].multiplier)==3 and Vector2(float(remote.events[-1].avx),float(remote.events[-1].avz)).is_equal_approx(sim.vel(a)),"Both screens receive the same velocities and clash event")
	var chosen:=sim.vel(a)
	a.clash_used=false;b.clash_used=false;sim.velocity(a,Vector2.RIGHT*12);sim.velocity(b,Vector2.LEFT*12)
	Clash.resolve(sim,a,b,Vector2.RIGHT)
	check(chosen.is_equal_approx(sim.vel(a)),"Authoritative random deflection is reproducible")
	a.ready=true;b.ready=true;sim.launch()
	check(not a.clash_used and not b.clash_used,"Next throw permits another coordinated clash")
	print("CLASH: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
