extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Spirits=preload("res://scripts/spirits.gd")
var checks:=0
var failures:=0
func _init() -> void:call_deferred("run")
func check(value:bool,message:String)->void:
	checks+=1
	if not value:failures+=1;push_error(message)
func enemy(sim,kind:String="brute")->Dictionary:
	sim.enemies.clear();sim.spawn(kind,0.0);return sim.enemies[0]
func give(p:Dictionary,kind:String)->void:p.spirit={"kind":kind,"turns":Spirits.TYPES[kind].turns}
func run()->void:
	var sim:=Sim.new();sim.start(4,1,42)
	var p:Dictionary=sim.players[0]
	var field:=sim.pickups.filter(func(x):return x.kind=="spirit")
	check(field.size()==2,"Team starts with at most two spirits")
	var item:Dictionary=field[0]
	check(Spirits.collect(sim,p,item),"Free slot collects spirit")
	check(p.spirit.is_empty() and p.pending_spirit==item.spirit,"Pickup waits until next plan")
	check(not Spirits.collect(sim,p,field[1]),"Pending slot cannot steal second pickup")
	sim.begin_plan();check(Spirits.active(p,item.spirit),"Next planning activates pickup")
	check(int(p.spirit.turns)==int(Spirits.TYPES[item.spirit].turns),"First active turn is not consumed on pickup")
	give(p,"wind");var boosted:=sim.launch_speed(p);p.spirit={};var normal:=sim.launch_speed(p)
	check(is_equal_approx(boosted,normal*1.25),"Wind affects real launch and prediction")
	give(p,"shield");var hp:=int(p.hp);sim.damage_player(p,1,"burn")
	check(int(p.hp)==hp and p.spirit.is_empty() and not p.statuses.has("burn"),"Shield blocks damage and status once")
	give(p,"eagle");var target:=enemy(sim);sim.player_hit(p,target,"eagle")
	check(int(target.hp)==0 and p.spirit.is_empty(),"Eagle adds two damage and consumes")
	give(p,"lasso");target=enemy(sim);sim.player_hit(p,target,"lasso")
	check(int(target.stun)==1 and p.spirit.is_empty(),"Lasso snares first struck enemy")
	sim.begin_enemy();check(bool(target.fired) and sim.vel(target).is_zero_approx(),"Snared enemy skips its actual response")
	give(p,"frost");target=enemy(sim);sim.player_hit(p,target,"ice")
	check(target.chill==1 and Spirits.active(p,"frost"),"Frost persists for further collisions")
	target.attack="rush";target.tx=0.0;target.tz=0.0;sim.begin_enemy()
	check(sim.vel(target).length()<6.0,"Chilled rush is slowed")
	sim.end_turn();check(int(target.chill)==0,"Enemy chill expires after response")
	give(p,"flame");target=enemy(sim);sim.spawn("coal",0.1)
	var adjacent:Dictionary=sim.enemies[-1];sim.place(adjacent,sim.pos(target)+Vector2(0,0.8))
	sim.player_hit(p,target,"flame")
	check(int(adjacent.hp)==0 and p.spirit.is_empty(),"Flame damages nearby enemies once")
	give(p,"master");sim.fire=3;p.ready=true;Spirits.after_throw(sim)
	check(sim.fire==4,"Master repairs after a committed throw")
	p.ready=false;Spirits.after_throw(sim);check(sim.fire==4,"Waiting defensively cannot repair")
	give(p,"wind");sim.begin_plan();check(int(p.spirit.turns)==1,"Two-turn spirit decrements once per plan")
	sim.begin_plan();check(p.spirit.is_empty(),"Spirit expires on schedule")
	sim.start(1,1,42);p=sim.players[0];field=sim.pickups.filter(func(x):return x.kind=="spirit")
	check(field.size()==1,"Solo has one field spirit")
	var old_id:=int(field[0].id)
	for i in 3:sim.begin_plan()
	check(sim.pickups.filter(func(x):return int(x.id)==old_id).is_empty(),"Uncollected spirit lasts three plans")
	p.pending_spirit="frost";var copy:=Sim.new();copy.restore(JSON.parse_string(JSON.stringify(sim.snapshot())))
	check(copy.players[0].pending_spirit=="frost","Pending and active spirits cross the wire")
	give(p,"eagle");target=enemy(sim);target.hp=0;sim.player_hit(p,target,"already-dead")
	check(Spirits.active(p,"eagle"),"Dead targets cannot consume a spirit")
	# Success/miss reactions derive from gameplay rather than a looping face timer.
	sim.start(1,1,42);p=sim.players[0];p.ready=true;sim.launch();sim.begin_enemy()
	check(sim.events.any(func(x):return x.kind=="enemy_mood" and x.text=="mock"),"Enemy mocks a committed missed throw")
	sim.events.clear();sim.begin_plan();p.ready=true;sim.launch();p.landed_hit=true;sim.begin_enemy()
	check(not sim.events.any(func(x):return x.kind=="enemy_mood" and x.text=="mock"),"Successful throws do not trigger mockery")
	print("SPIRITS: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
