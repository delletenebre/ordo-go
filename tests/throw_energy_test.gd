extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
var failures:=0
var checks:=0
func check(value:bool,message:String)->void:
	checks+=1
	if not value:failures+=1;push_error(message)
func _init()->void:
	var solo_speed:=0.0
	for count in range(1,5):
		var sim:=Sim.new();sim.start(count,1,42)
		for p in sim.players:p.power=1;p.ready=true
		if count==1:solo_speed=sim.launch_speed(sim.players[0])
		for p in sim.players:check(is_equal_approx(sim.launch_speed(p),solo_speed),"Party size and seat never change base throw power")
	var sim:=Sim.new();sim.start(1,1,42);sim.enemies.clear();sim.stones.clear()
	var player:Dictionary=sim.players[0]
	var results:Array=[]
	for power in [.15,1.0]:
		sim.place(player,Vector2(2.0,0));player.angle=0;player.power=power;player.ready=true
		sim.launch()
		var bounces:=0;var previous:Vector2=sim.vel(player)
		for step in 540:
			sim.move_bodies(Sim.STEP,true)
			var velocity:Vector2=sim.vel(player)
			if previous.dot(velocity)<0:bounces+=1
			check(velocity.is_finite() and velocity.length()<=sim.Runestones.SPEED_LIMIT+.001,"Ricochets keep finite bounded speed")
			previous=velocity
		results.append(bounces)
	check(int(results[1])>=2 and int(results[1])>int(results[0]),"Full power sustains several ricochets in the same lane")
	print("THROW ENERGY: ",checks," checks, bounces ",results,", ",failures," failures")
	quit(1 if failures else 0)
