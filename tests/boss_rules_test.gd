extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Boss=preload("res://scripts/boss_rules.gd")
var checks:=0
var failures:=0
func _init()->void:call_deferred("run")
func check(value:bool,message:String)->void:
	checks+=1
	if not value:failures+=1;push_error(message)
func fixture(count:int,kind:String="weaver"):
	var sim:=Sim.new();sim.start(count,1,42);sim.enemies.clear();sim.pickups.clear();sim.stones.clear()
	sim.spawn(kind,0);sim.begin_plan();return sim
func trigger(sim)->Dictionary:
	var e:Dictionary=sim.enemies[0]
	sim.hit_enemy(e,int(e.hp)-maxi(1,int(e.phase_hp)),"gate",sim.pos(e));return e
func run()->void:
	for count in range(1,5):
		for kind in Boss.KINDS:
			var sim=fixture(count,kind);var e:Dictionary=sim.enemies[0]
			check(int(e.phase_hits)==(0 if count==1 else count+1),"Phase uses team hit budget")
			trigger(sim)
			check((e.boss_phase=="calm")== (count==1),"Solo has no secondary phase")
			check(not Boss.active(sim,e),"Transition gives a full next-plan warning")
			sim.begin_plan()
			check(Boss.active(sim,e)==(count>1),"Coop phase arms on next turn only")
			if count==1:
				check(sim.rune_drops.is_empty(),"Solo needs no counter pickup")
		var upgraded=fixture(count)
		for p in upgraded.players:p.damage=2
		upgraded.enemies.clear();upgraded.spawn("weaver",0)
		check(int(upgraded.enemies[0].phase_hp)==(0 if count==1 else mini(14,(count+1)*3)),"Threshold includes permanent damage")
	var sim=fixture(2);var e:=trigger(sim)
	check(sim.rune_drops.size()==1 and sim.rune_drops[0].spirit=="frost","Phase spits exactly one frost class")
	sim.hits.clear();Boss.damaged(sim,e);check(sim.rune_drops.size()==1,"Repeated hits do not duplicate transition")
	var copy:=Sim.new();copy.restore(JSON.parse_string(JSON.stringify(sim.snapshot())))
	check(copy.enemies[0].boss_phase=="burning" and copy.rune_drops[0].boss_gift,"Phase and rescue flight cross snapshots")
	sim.Runestones.advance(sim,.7)
	var gift:Dictionary=sim.pickups.filter(func(x):return x.get("boss_gift",false))[0]
	check(sim.pos(gift).length()<5.0,"Counter lands inside reachable field")
	sim.begin_plan();var p:Dictionary=sim.players[0];var initial:=int(p.hp)
	Boss.contact(sim,p,e);check(int(p.hp)==initial-1 and p.statuses.has("burn"),"Hot contact damages and ignites")
	Boss.contact(sim,p,e);check(int(p.hp)==initial-1,"Persistent overlap cannot double damage")
	Boss.end_turn(sim);sim.Effects.end_turn(sim);check(int(p.hp)==initial-2,"Boss ignition uses the shared current-turn tick")
	sim.Effects.end_turn(sim);check(int(p.hp)==initial-2,"Burn ticks once even if turn end repeats")
	sim.begin_plan();sim.Effects.end_turn(sim);check(int(p.hp)==initial-2 and not p.statuses.has("burn"),"One-turn boss ignition expires")
	sim.begin_plan();Boss.ignite(sim,p)
	p.spirit={"kind":"wind","turns":1};p.pending_spirit="shield"
	check(sim.Spirits.collect(sim,p,gift) and sim.Spirits.active(p,"frost"),"Guaranteed counter works with occupied class slot immediately")
	check(p.pending_spirit=="","Rescue cannot be overwritten by pending class")
	sim.place(p,sim.pos(e)+Vector2(1.1,0));sim.player_hit(p,e,"cold")
	check(e.boss_phase=="doused" and int(e.stun)==1,"Frost douses boss and cancels response")
	check(not p.statuses.has("burn"),"Frost strike also extinguishes nearby attacker")
	sim.hits.clear();Boss.damaged(sim,e);check(e.boss_phase=="doused","Doused boss does not immediately reignite")
	var shielded=fixture(2);var hot_enemy:=trigger(shielded);shielded.begin_plan()
	var defender:Dictionary=shielded.players[0];defender.shield=1
	Boss.contact(shielded,defender,hot_enemy)
	check(int(defender.hp)==4 and not defender.statuses.has("burn"),"Protection blocks damage and burn together")
	var lethal=fixture(4);lethal.hit_enemy(lethal.enemies[0],999,"kill",Vector2.ZERO)
	check(lethal.rune_drops.is_empty(),"Lethal burst skips phase without invulnerability gate")
	var ram=fixture(2,"ram");var stone:=trigger(ram);ram.begin_plan();ram.begin_enemy();Boss.end_turn(ram);ram.begin_plan()
	check(stone.attack=="rest" and stone.fired,"Empowered ram rests after charge")
	var hp:=int(stone.hp);ram.player_hit(ram.players[0],stone,"punish")
	check(int(stone.hp)==hp-2,"Recovery rewards one extra damage")
	var eater=fixture(2,"eater");var sun:=trigger(eater);eater.begin_plan();var ring:=float(sun.ring_radius);eater.begin_plan()
	check(float(sun.ring_radius)!=ring,"Hungry boss alternates announced ring")
	var targeted=fixture(2,"ram");var target:Dictionary=targeted.enemies[0]
	var point:=Vector2(target.tx,target.tz);targeted.place(targeted.players[int(target.target_id)],Vector2(-2,-2));targeted.begin_enemy()
	check(Vector2(target.tx,target.tz)==point,"Aggro destination remains locked after launch")
	for age in [0.0,2.5,3.0,12.0]:check(is_zero_approx(Boss.marker_alpha(age)),"Target ring absent outside 2.5 second window")
	check(Boss.marker_alpha(1.0)>.99 and Boss.marker_alpha(2.25)<.6,"Marker holds briefly then fades")
	var rescue=fixture(2);var burning:=trigger(rescue);rescue.begin_plan();rescue.rune_drops.clear();rescue.pickups.clear()
	Boss.ensure_counter(rescue);check(rescue.rune_drops.size()==1,"Expired or lost counter cannot soft-lock persistent burn")
	rescue.players[1].hp=0;check(not Boss.hot(rescue,burning),"Last surviving player is spared phase heat")
	print("BOSS RULES: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
