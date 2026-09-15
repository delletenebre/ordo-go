extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Preview=preload("res://scripts/aim_preview.gd")
var failures:=0
var checks:=0
func check(value:bool,message:String)->void:
	checks+=1
	if not value:failures+=1;push_error(message)
func path_length(points:PackedVector2Array)->float:
	var result:=0.0
	for i in range(1,points.size()):result+=points[i-1].distance_to(points[i])
	return result
func _init()->void:
	var sim:=Sim.new();sim.start(1,1,42);sim.stones.clear();sim.enemies.clear()
	var p:Dictionary=sim.players[0];sim.place(p,Vector2(-1.5,3.0));p.angle=0;p.power=.15
	var full:=Preview.trace(sim,p);var original:=JSON.stringify(full)
	var guide:=Preview.shorten(full,2.6)
	check(absf(path_length(guide.points)-2.6)<.001,"Crop retains requested distance")
	check(path_length(guide.points)<path_length(full.points),"Crop limits the physical forecast")
	check(JSON.stringify(full)==original,"Cropping guide cannot shorten cached physical forecast")
	check(guide.kind=="stop" and guide.bounces==0,"Cropped guide does not claim a distant hit")
	sim.place(p,Vector2(5.3,0));p.angle=0;p.power=1
	guide=Preview.shorten(Preview.trace(sim,p),2.6)
	check(guide.bounces==1 and guide.points[-1].x<guide.points[1].x,"Medium guide preserves early wall reflection")
	for spin in [-1.0,0.0,1.0]:
		p.spin=spin
		for origin in [Vector2(-1.5,3.0),Vector2(5.3,0.0)]:
			sim.place(p,origin);p.angle=0;p.power=.15;p.ready=false
			var before:=JSON.stringify(sim.snapshot())
			var fixed:=Preview.direction_guide(sim,p)
			check(JSON.stringify(sim.snapshot())==before,"Direction guide never changes player charge/state")
			check(path_length(fixed.points)<=Preview.GUIDE_LENGTH+.001,"Guide hides the long coasting forecast")
			for power in [.15,.3,.7,1.0]:
				p.power=power;p.ready=power>.5
				check(Preview.direction_guide(sim,p)==fixed,"Charge and ready state cannot stretch or bend the direction guide")
			check(fixed.kind=="guide" and fixed.id==-1,"Direction hint does not promise a damaging hit")
			var contacts:Array=fixed.get("contacts",range(1,fixed.points.size()-1))
			check(contacts.size()<=1,"Only one ricochet is shown")
			if not contacts.is_empty():
				var tail:=PackedVector2Array(fixed.points).slice(int(contacts[0]))
				check(path_length(tail)<=Preview.GUIDE_BOUNCE_TAIL+.001,"Reflected continuation stays short")
	# Sweep full charge, curling, rim starts and speed upgrades: no extrapolated rays.
	var outside:=0;var paths:=0
	for radius in [3.5,5.65]:
		for angle_index in 24:
			sim.place(p,Vector2.from_angle(angle_index*TAU/24.0)*radius)
			p.angle=angle_index*TAU/24.0+.35
			for spin in [-1.0,0.0,1.0]:
				p.spin=spin;p.speed=2.0
				var preview:=Preview.trace(sim,p);paths+=1
				for point in preview.points:
					if point.length()>sim.RADIUS-p.r+.002:outside+=1
	check(outside==0,"All charged forecast points stay inside wall with token clearance")
	print("AIM PREVIEW: ",checks," checks, ",paths," paths, ",failures," failures")
	quit(1 if failures else 0)
