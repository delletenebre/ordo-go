extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Rules=preload("res://scripts/runestones.gd")
const Preview=preload("res://scripts/aim_preview.gd")
var checks:=0
var failures:=0
func _init()->void:call_deferred("run")
func check(value:bool,message:String)->void:
	checks+=1
	if not value:failures+=1;push_error(message)
func collector(sim)->Dictionary:
	for stone in sim.stones:
		if stone.collector:return stone
	return {}
func ready(stone:Dictionary,kind:String,player:Dictionary)->void:
	stone.souls=2;stone.effect=kind;player.rune_used=false
func run()->void:
	var sim:=Sim.new();sim.start(1,1,42)
	check(sim.stones.filter(func(s):return s.collector).size()==1,"Solo has one soul collector")
	var stone:=collector(sim)
	sim.enemies.clear()
	for i in 3:
		sim.spawn("coal",0.0);var enemy:Dictionary=sim.enemies[-1]
		sim.hit_enemy(enemy,1,"test:%d"%i,sim.pos(stone)+Vector2(.7,0))
	check(sim.soul_flights.size()==2 and int(stone.souls)==0,"Flights reserve capacity; charge waits for arrival")
	Rules.advance(sim,.3);check(int(stone.souls)==0,"Soul has a travel time")
	Rules.advance(sim,.36);check(Rules.charged(stone) and sim.soul_flights.is_empty(),"Two souls finish one charge")
	check(Rules.EFFECTS.has(stone.effect),"Rolled gift is revealed on charged stone")
	var restored:=Sim.new();restored.restore(JSON.parse_string(JSON.stringify(sim.snapshot())))
	check(restored.pos(collector(restored)).is_equal_approx(sim.pos(stone)) and int(collector(restored).souls)==2 and collector(restored).effect==stone.effect and restored.rune_seed==sim.rune_seed,"Charged stones survive network JSON")
	var p:Dictionary=sim.players[0]
	ready(stone,"surge",p)
	var boosted:=Rules.activate(sim,p,stone,Vector2(6,0),true)
	check(is_equal_approx(boosted.length(),12) and stone.souls==0,"Surge doubles incoming speed and consumes charge")
	stone.souls=2;stone.effect="surge"
	check(Rules.activate(sim,p,stone,Vector2(6,0),true)==Vector2.ZERO and stone.souls==2,"One gift per player per throw")
	p.rune_used=false
	check(Rules.activate(sim,p,stone,Vector2(20,0),true).length()==24,"Surge speed is capped")
	ready(stone,"heal",p)
	check(Rules.activate(sim,p,stone,Vector2(6,0),true)==Vector2.ZERO and stone.souls==2,"Full health preserves healing gift")
	p.hp=2
	Rules.activate(sim,p,stone,Vector2(6,0),true)
	check(p.hp==3,"Healing restores exactly one life")
	ready(stone,"guard",p);Rules.activate(sim,p,stone,Vector2(6,0),true)
	sim.damage_player(p,1,"frost")
	check(p.hp==3 and not p.statuses.has("frost") and p.rune_boon.is_empty(),"Guard blocks exactly one damage and status")
	ready(stone,"thorns",p);Rules.activate(sim,p,stone,Vector2(6,0),true)
	check(is_equal_approx(Rules.mass(p,false),float(p.mass)*2.5) and is_equal_approx(Rules.mass(p,true),float(p.mass)),"Thorns resist enemy knockback without weakening own throw")
	sim.turn+=1;Rules.expire(sim);check(Rules.boon(p,"thorns"),"Boon survives next enemy round")
	sim.turn+=1;Rules.expire(sim);check(p.rune_boon.is_empty(),"Boon expires after two rounds")
	ready(stone,"class",p)
	sim.pickups=[{"id":800,"kind":"spirit","spirit":"wind","x":0,"z":3,"expires":99}]
	check(Rules.activate(sim,p,stone,Vector2(6,0),true)==Vector2.ZERO and stone.souls==2,"Class gift preserves charge while field cap is full")
	sim.pickups.clear();sim.enemies.clear()
	Rules.activate(sim,p,stone,Vector2(6,0),true)
	check(sim.rune_drops.size()==1 and sim.pickups.is_empty(),"Class is thrown before it becomes collectible")
	var drop:Dictionary=sim.rune_drops[0]
	var free:=true
	for body in sim.players+sim.stones:
		if sim.pos(drop).distance_to(sim.pos(body))<float(body.get("r",.4))+.68:free=false
	check(free and sim.pos(drop).length()>2,"Class lands in free arena space")
	restored.restore(JSON.parse_string(JSON.stringify(sim.snapshot())))
	check(restored.rune_drops.size()==1 and int(restored.rune_drops[0].id)==int(drop.id) and restored.rune_drops[0].spirit==drop.spirit and restored.pos(restored.rune_drops[0]).is_equal_approx(sim.pos(drop)) and is_equal_approx(float(restored.rune_drops[0].left),float(drop.left)),"Airborne class survives network JSON")
	Rules.advance(sim,.66)
	check(sim.rune_drops.is_empty() and sim.pickups.size()==1 and sim.pickups[0].kind=="spirit","Class becomes a normal pickup on landing")
	sim.start(4,1,42)
	check(sim.stones.filter(func(s):return s.collector).size()==2,"Team has at most two collectors")
	var seen:Dictionary={}
	stone=collector(sim)
	for i in 100:
		stone.souls=1;stone.incoming=1
		sim.soul_flights=[{"id":i,"stone":int(stone.id),"left":.01}]
		Rules.advance(sim,.02);seen[stone.effect]=true
	check(seen.size()==5,"Random gift pool includes all five effects")
	# The preview must distinguish an accelerating rune from a defensive gift.
	sim.start(1,1,42);sim.enemies.clear();sim.pickups.clear();p=sim.players[0]
	sim.stones=[{"id":0,"x":3.0,"z":3.0,"r":.46,"collector":true,"souls":2,"effect":"surge"}]
	# Neither reflected endpoint should be capped by the far wall in this test.
	sim.place(p,Vector2(1,3));p.angle=0;p.power=.15;p.speed=.65
	var boosted_preview:=Preview.trace(sim,p)
	sim.stones[0].effect="guard";var plain_preview:=Preview.trace(sim,p)
	check(boosted_preview.boost_segment==1 and plain_preview.boost_segment==-1,"Preview only accelerates a surge gift")
	check(boosted_preview.points[-1].x<plain_preview.points[-1].x,"Preview extends the accelerated reflection")
	print("RUNESTONES: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
