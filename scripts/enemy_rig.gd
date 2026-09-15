class_name OrdoEnemyRig
extends Node3D
const Motion=preload("res://scripts/enemy_motion.gd")
const Craft=preload("res://scripts/enemy_craft.gd")
var appearance:="coal"
var kind:="coal"
var radius:=.34
var mass:=.7
var parts:Array=[]
var torso:MeshInstance3D
var face:Node3D
var profile_data:Dictionary
var previous_position:=Vector2.ZERO
var previous_velocity:=Vector2.ZERO
var distance:=0.0
var age:=0.0
var recoil:=0.0
var recoil_velocity:=0.0
var attack_age:=10.0
var last_phase:=""
var last_fired:=false
var was_airborne:=false
var dying:=false
var death_velocity:=Vector3.ZERO
var facing:=Vector2.DOWN
var head_basis:=Basis.IDENTITY
var head_offset:=Vector3.ZERO
var reference:Node3D

static func variant(enemy_kind:String,_id:int)->String:return Motion.material_kind(enemy_kind)

func build(arena,actor:Node3D,entity:Dictionary,_override:String="")->void:
	kind=str(entity.kind);appearance=Motion.material_kind(kind);profile_data=Motion.profile(kind)
	radius=float(entity.r);mass=float(entity.get("mass",.7))
	torso=actor.get_node("Body");face=actor.get_node("Face")
	previous_position=Vector2(float(entity.x),float(entity.z))
	age=fposmod(float(entity.id)*.317,TAU)
	parts=Craft.build(arena,actor,torso,kind,radius,int(entity.id))
	reference=actor.get_node_or_null("ReferenceBody")
	for label in ["WingLeft","WingRight","HornLeft","HornRight"]:
		var part:=actor.get_node_or_null(label) as Node3D
		if part!=null:parts.append({"node":part,"rest":part.transform,"role":"wing" if label.begins_with("Wing") else "mark","side":-1.0 if label.ends_with("Left") else 1.0})

func hit(strength:float)->void:
	var omega:=4.6/float(profile_data.settle)
	recoil_velocity+=float(profile_data.strain)*omega*clampf(strength,.25,2.0)

func step(entity:Dictionary,phase:String,phase_time:float,dt:float)->void:
	if dying:return
	age+=dt
	var point:=Vector2(float(entity.x),float(entity.z))
	var travelled:=point.distance_to(previous_position)
	if travelled<radius*4:distance+=travelled
	previous_position=point
	var velocity:=Vector2(float(entity.vx),float(entity.vz));var speed:=velocity.length()
	var jump:=float(entity.get("jump",0.0));var airborne:=jump>0
	if was_airborne and not airborne:hit(1.3 if appearance=="felt" else .7)
	was_airborne=airborne
	if (velocity-previous_velocity).length()>1.5:hit(minf((velocity-previous_velocity).length()*.12,1.4))
	previous_velocity=velocity
	var state:=Motion.spring(recoil,recoil_velocity,4.6/float(profile_data.settle),dt)
	recoil=clampf(state.x,0,float(profile_data.strain));recoil_velocity=state.y
	var attack:String=entity.get("attack","");var fired:bool=entity.get("fired",false)
	var start_rush:=last_phase!="enemy" and phase=="enemy" and attack=="rush" and not fired
	var contact:=last_phase=="enemy" and phase=="enemy" and fired and not last_fired
	if start_rush or contact:attack_age=0;face.react("anger" if start_rush else "surprise",.22)
	last_phase=phase;last_fired=fired;attack_age+=dt
	var windup:=clampf(phase_time/.90,0,1) if phase=="enemy" and not fired and attack not in ["rush","jump"] else 0.0
	var strike:=sin(clampf(attack_age/.32,0,1)*PI)
	var move_amount:=clampf(speed*.45,0,1) if not airborne else 0.0
	if speed>.12:facing=facing.lerp(velocity.normalized(),1-exp(-12*dt)).normalized()
	var gait_angle:=distance/(radius*float(profile_data.stride))*TAU
	var rock:=sin(gait_angle)*float(profile_data.rock)*move_amount
	var lean:=velocity.limit_length(4)*(.013 if appearance=="stone" else .023)
	head_basis=Basis.from_euler(Vector3(lean.y+windup*.055-strike*.07,0,rock-lean.x))
	var breath:=sin(age*2.1)*.012 if appearance=="felt" else 0.0
	var strain:=recoil+(windup*.055 if appearance=="felt" else 0.0)
	var stretch:=Vector3(1+strain*.35+breath,1-strain+breath,1+strain*.35+breath)
	head_offset=Vector3(0,absf(sin(gait_angle))*radius*.025*move_amount-radius*strain*.10,0)
	if airborne:head_basis=Basis.from_euler(Vector3(-sin(jump*PI)*.09,0,0))
	var centre:=Vector3(0,radius*.94,0)
	torso.transform=Transform3D(head_basis.scaled_local(stretch),centre+head_offset)
	face.transform=Transform3D(head_basis,centre+head_offset-head_basis*centre)
	var foot_index:=0
	for p in parts:
		var rest:Transform3D=p.rest;var node:Node3D=p.node
		node.transform=rest
		match p.role:
			"foot":
				var foot:=Motion.foot_phase(distance,radius,profile_data,foot_index);foot_index+=1
				if move_amount>.03:
					node.position+=Vector3(facing.x*foot.x,foot.y,facing.y*foot.x)*move_amount
				if airborne:
					node.position.y+=sin(jump*PI)*radius*.30
					node.rotation.x=-sin(jump*PI)*.5
			"wing":
				node.transform=Transform3D(head_basis,centre+head_offset-head_basis*centre)*rest
				node.rotation.z+=float(p.side)*(sin(age*(7+speed*2))*.16*move_amount+windup*.3-strike*.45)
			"shield":
				node.transform=Transform3D(head_basis,centre+head_offset-head_basis*centre)*rest
				node.position+=Vector3(0,windup*radius*.09,-strike*radius*.07)
				node.rotation.x+=windup*.09-strike*.11
			"crown","mark":node.transform=Transform3D(head_basis,centre+head_offset-head_basis*centre)*rest
			"winding":
				node.scale=Vector3.ONE*(1+strain*.09)
				node.rotation.y=float(p.side)*recoil*.11
			"knot":node.rotation.z=sin(age*2.1)*.025+float(p.side)*recoil
	if reference!=null:reference.step()

func begin_death(velocity:Vector3)->void:
	dying=true;death_velocity=velocity

func step_death(death_age:float,_dt:float)->void:
	var t:=clampf(death_age/(.75 if appearance=="felt" else .32),0,1)
	for p in parts:
		var node:Node3D=p.node
		if p.role=="foot":node.rotation.x=-t*.3
		if p.role=="wing":node.rotation.z+=float(p.side)*_dt*1.2
		if p.role=="shield":node.rotation.x=t*.50;node.position.y=-t*t*radius*.15
		if p.role=="winding":
			node.scale=Vector3.ONE*(1+t*.18)
			node.rotation.y=float(p.side)*t*.42
			node.position.y=-t*t*radius*.13
		if p.role=="knot":node.position.x=t*radius*.12
	if appearance=="felt":torso.scale.y=1-t*.22
	if reference!=null:reference.die(death_age)

func release_parts(parent:Node3D)->Array:
	var debris:Array=[]
	for p in parts:
		if p.role not in ["shield","crown","winding","knot","wing"]:continue
		var node:Node3D=p.node
		node.reparent(parent)
		var velocity:=death_velocity*.55+Vector3(float(p.side)*.5,.45,.15)
		if p.role=="winding":velocity=death_velocity*.45+Vector3(float(p.side)*.35,.22,.15)
		debris.append({"node":node,"velocity":velocity,"spin":float(p.side)*1.3+.4,"age":0.0,"life":1.7 if appearance=="felt" else 1.1,"scale":node.scale,"bounce":float(profile_data.bounce),"friction":float(profile_data.friction),"soft_loop":p.role=="winding"})
	return debris
