extends SceneTree
const Simulation = preload("res://scripts/simulation.gd")
var failures := 0
var checks := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)
func advance(sim, seconds: float) -> void:
	for i in ceili(seconds*120): sim.tick(1.0/120)
func _init() -> void:
	for count in range(1,5):
		var sim = Simulation.new(); sim.start(count,1,42); sim.begin_reward()
		sim.reward_options = ["stitch","spark","guard"]
		check(not sim.choose_reward(-1,0) and not sim.choose_reward(count,0) and not sim.choose_reward(0,3),"Invalid reward input rejected")
		for i in count:
			check(sim.command(i,{"action":"reward","choice":0,"turn":sim.turn}),"Each player chooses independently")
			check(not sim.choose_reward(i,0),"Repeat packet does not restart countdown or duplicate gift")
			if i<count-1:
				advance(sim,3); check(sim.phase=="reward" and sim.timer==0,"Wait indefinitely for everyone")
		advance(sim,.7)
		check(sim.players[0].max_hp==4 and sim.wave==1,"No bonus applies during countdown")
		check(sim.choose_reward(0,1),"A chosen bonus can be replaced")
		check(sim.players[0].max_hp==4 and sim.players[0].damage==0,"Reselection cannot farm buffs")
		check(sim.command(0,{"action":"cancel"}),"Readiness can be cancelled")
		advance(sim,3); check(sim.wave==1 and not sim.players[0].reward,"Cancel stops transition")
		check(not sim.command(0,{"action":"reward","choice":1,"turn":sim.turn-1}),"Old turn cannot choose")
		sim.choose_reward(0,1)
		var copy = Simulation.new(); copy.restore(JSON.parse_string(JSON.stringify(sim.snapshot())))
		check(copy.players[0].reward_choice==1 and copy.timer==sim.timer,"Snapshot preserves selected gift and countdown")
		advance(sim,2.1); advance(copy,2.1)
		check(sim.wave==2 and sim.players[0].damage==1 and sim.players[0].max_hp==4,"Only final gift committed")
		check(copy.wave==2 and copy.players[0].damage==1,"Restored host commits exactly once")
		check(not sim.choose_reward(0,0),"Late reward packet cannot apply in next wave")
		for i in range(1,count):check(sim.players[i].max_hp==5,"All other gifts applied once")
		sim.begin_reward(); check(sim.players[0].reward_choice==-1 and not sim.players[0].reward,"Next reward starts empty")
	var sim = Simulation.new(); sim.start(2,1,42);sim.begin_reward();sim.reward_options=["mend","charge","stride"];sim.fire=1;sim.players[1].hp=0
	sim.choose_reward(0,0);advance(sim,3);check(sim.wave==1,"Fallen player still gets a choice")
	sim.choose_reward(0,1);sim.choose_reward(0,0);sim.choose_reward(1,0);advance(sim,2.1)
	check(sim.fire==6 and sim.players[0].bonus_charges==0,"Shared hearth repairs once per final choice plus wave heal")
	print("REWARD: ",checks," checks; failures=",failures)
	quit(1 if failures else 0)
