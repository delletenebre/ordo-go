extends SceneTree
const Arena=preload("res://scripts/arena.gd")
const Rig=preload("res://scripts/enemy_rig.gd")
const Motion=preload("res://scripts/enemy_motion.gd")
const Sim=preload("res://scripts/simulation.gd")
var checks:=0
var failures:=0
func _init()->void:call_deferred("run")
func check(value:bool,message:String)->void:
	checks+=1
	if not value:failures+=1;push_error(message)
func run()->void:
	var arena:=Arena.new();arena.muted=true;root.add_child(arena)
	var sim:=Sim.new();sim.start(1,1,71);sim.enemies.clear()
	for kind in ["coal","brute","frost","weaver"]:
		sim.spawn(kind,0);var e:Dictionary=sim.enemies[-1];sim.place(e,Vector2(2,2))
		arena.render_state(sim,0)
		var rig:Node3D=arena.actors[str(int(e.id))].get_node("Rig")
		var before:=JSON.stringify(e);var nodes:Array=[]
		for p in rig.parts:nodes.append(p.node.get_instance_id())
		for frame in 30:rig.step(e,"plan",0,1.0/60)
		check(JSON.stringify(e)==before,"Animation does not alter combat state")
		var still:float=rig.distance
		for frame in 10:rig.step(e,"plan",0,1.0/60)
		check(rig.distance==still,"Idle does not walk in place")
		e.vx=1.0
		for frame in 30:
			e.x+=1.0/60;rig.step(e,"resolve",0,1.0/60)
		check(is_equal_approx(rig.distance-still,.5),"Gait follows real displacement")
		e.vx=0.0;e.attack="slam";e.fired=false
		rig.step(e,"enemy",.5,.016);e.fired=true;rig.step(e,"enemy",.95,.016)
		check(rig.attack_age<.05,"Attack animation follows actual fired edge")
		rig.hit(1.2);rig.step(e,"plan",0,.016)
		check(rig.recoil>0 and rig.recoil<=float(Motion.profile(kind).strain),"Material strain is bounded")
		rig.begin_death(Vector3(2,0,0));rig.step_death(.2,.016)
		for n in rig.parts.size():check(rig.parts[n].node.get_instance_id()==nodes[n],"Death keeps original parts")
		var pieces:Array=rig.release_parts(arena.actor_root)
		if kind!="coal":check(not pieces.is_empty() and pieces[0].velocity.x>0,"Craft parts retain incoming momentum")
		arena.rig_debris.append_array(pieces)
	sim.start(2,1,72);sim.enemies.clear();sim.spawn("weaver",0)
	var boss:Dictionary=sim.enemies[-1];arena.render_state(sim,0)
	var actor:Node3D=arena.actors[str(int(boss.id))]
	var heat:Node3D=actor.get_node("Heat");var reference:Node3D=actor.get_node("ReferenceBody")
	check(reference.material in heat.materials,"Burning light reaches the actual reference body material")
	for frame in 60:heat.step(1,1.0/60)
	check(float(reference.material.get_shader_parameter("heat"))>.95,"Yarn surface ignites with the flame")
	for frame in 60:heat.step(0,1.0/60)
	check(not heat.visible and float(reference.material.get_shader_parameter("heat"))==0,"Frost extinguishes all flame and surface glow")
	check(float(reference.material.get_shader_parameter("charred"))>.95,"Cooled yarn retains its scorch marks")
	for fps in [30,60,120]:
		var state:=Vector2(0,2)
		for i in fps:state=Motion.spring(state.x,state.y,8,1.0/fps)
		check(state.distance_to(Motion.spring(0,2,8,1))<.00001,"Spring is frame-rate independent")
	for kind in ["hopper","weaver"]:
		for chill in [0,1]:
			var e:={"kind":kind,"jump":.31,"chill":chill};var h:=Motion.jump_height(e);var v:=Motion.jump_velocity(e)
			e.jump+=.0001/(1.70 if chill else .95)
			check(absf((Motion.jump_height(e)-h)/.0001-v)<.01,"Death vertical speed is derivative of rendered jump")
	for frame in 160:arena.step_rig_debris(1.0/60)
	check(arena.rig_debris.is_empty(),"Debris is bounded and cleaned up")
	for kind in ["coal","brute","frost"]:
		arena.debris.clear();arena.debris.shatter({"id":12,"x":2.0,"z":2.0,"strength":.7,"enemy_kind":kind})
		var piece:Dictionary=arena.debris.pieces.filter(func(x):return x.life>0)[0]
		check(is_equal_approx(piece.body.physics_material_override.bounce,float(Motion.profile(kind).bounce)),"Fragments use material bounce")
	arena.debris.clear()
	check(arena.debris.shatter({"id":1,"strength":1.0,"enemy_kind":"weaver"})==0,"Felt releases winding loops without coal chunks")
	arena.reset_presentation();arena.queue_free();await process_frame
	print("ENEMY RIGS: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
