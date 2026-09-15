class_name OrdoEnemyFace
extends Node3D
var eyes: Array=[]
var brows: Array=[]
var brow_origins:Array=[]
var eye_cores: Array=[]
var mouth:Node3D
var mouth_materials:Array[ShaderMaterial]=[]
var mouth_size:=Vector2(.43,.14)
var mouth_curve:=0.0
var teeth: Array=[]
var radius:=0.4
var time:=0.0
var mood:="neutral"
var remaining:=0.0
var blink_at:=3.2
var blink_age:=1.0
var seed_value:=0

func build(arena, r: float, id: int) -> void:
	radius=r;seed_value=id;blink_at=2.8+fposmod(id*1.713,4.0)
	var dark=arena.wool(Color("101219"));var light=arena.material(Color("e99b29"),0.22)
	light.roughness=.26;light.metallic=.12
	var inner_fire:=ShaderMaterial.new();inner_fire.shader=preload("res://shaders/coal_eye.gdshader")
	for side in [-1.0,1.0]:
		var eye:=Node3D.new();add_child(eye);eye.position=Vector3(side*r*0.32,r*1.17,r*0.97);eyes.append(eye)
		arena.sphere(eye,Vector3.ZERO,Vector3(r*0.35,r*0.39,r*0.18),dark)
		var core=arena.sphere(eye,Vector3(0,0,r*0.10),Vector3(r*0.22,r*0.29,r*0.13),inner_fire)
		eye_cores.append(core)
		var brow:=Node3D.new();add_child(brow);brow.position=Vector3(side*r*0.32,r*1.44,r*0.95);brows.append(brow)
		arena.sphere(brow,Vector3.ZERO,Vector3(r*0.49,r*0.085,r*0.10),arena.wool(Color("22212b")))
	mouth=Node3D.new();mouth.position=Vector3(0,r*.63,r*1.10);add_child(mouth)
	for is_rim in [false,true]:
		var mat:=ShaderMaterial.new();mat.shader=preload("res://shaders/mouth.gdshader")
		mat.set_shader_parameter("rim",is_rim);mat.set_shader_parameter("mouth_color",Color("ffc875") if is_rim else Color("0c0e13"))
		mat.set_shader_parameter("thickness",r*.039)
		mouth_materials.append(mat)
		if is_rim:
			var edge=arena.mesh_node(mouth,preload("res://scripts/mouth_mesh.gd").rim(),Vector3.ZERO,mat)
			edge.custom_aabb=AABB(Vector3(-r,-r,-r),Vector3.ONE*r*2)
		else:
			var cavity:=SphereMesh.new();cavity.radius=1.0;cavity.height=2.0;cavity.radial_segments=48;cavity.rings=16
			arena.mesh_node(mouth,cavity,Vector3.ZERO,mat)
	for side in [-1.0,1.0]:
		var tooth=arena.sphere(mouth,Vector3(side*r*.085,r*.015,r*.025),Vector3(r*.09,r*.07,r*.035),light);teeth.append(tooth);tooth.hide()

	var pivot:=Vector3(0,r*.92,0)
	var tilt:=Basis(Vector3.RIGHT,-.52)
	for part in get_children():
		part.position=pivot+tilt*(part.position-pivot)
		part.basis=tilt*part.basis

	for brow in brows:brow_origins.append(brow.position)

func react(expression: String, duration: float=0.8) -> void:
	var priorities={"neutral":0,"anger":1,"hate":2,"joy":2,"mock":2,"surprise":3,"fear":4}
	if remaining>0 and int(priorities.get(expression,0))<int(priorities.get(mood,0)):return
	mood=expression;remaining=duration

func step(dt: float, look: Vector2) -> void:
	time+=dt
	var had_reaction:=remaining>0
	remaining=maxf(0.0,remaining-dt)
	if had_reaction and remaining<=0 and mood=="fear":mood="hate";remaining=0.7
	elif remaining<=0:mood="neutral"
	if time>=blink_at:
		blink_age=0.0;blink_at=time+3.2+fposmod(seed_value*1.13+time,3.8)
	blink_age+=dt
	var blink:=1.0-0.94*sin(clampf(blink_age/0.17,0,1)*PI) if blink_age<0.17 and mood=="neutral" else 1.0
	var eye_scale:=Vector2.ONE;var target_size:=Vector2(.43,.14);var target_curve:=0.0;var brow_angle:=0.0;var brow_raise:=0.0
	match mood:
		"anger":eye_scale=Vector2(1.0,.73);brow_angle=.35;target_size=Vector2(.57,.12);target_curve=.08
		"hate":eye_scale=Vector2(.98,.55);brow_angle=.46;target_size=Vector2(.55,.095);target_curve=.10
		"surprise":eye_scale=Vector2(1.10,1.25);target_size=Vector2(.30,.38);brow_raise=.11
		"fear":eye_scale=Vector2(1.14,1.30);target_size=Vector2(.42,.43);brow_angle=-.24;brow_raise=.09
		"joy":eye_scale=Vector2(1.08,.64);target_size=Vector2(.63,.25);target_curve=-.13;brow_angle=-.17
		"mock":eye_scale=Vector2(1.07,.52);target_size=Vector2(.62,.18+.15*(.5+.5*sin(time*17)));target_curve=-.11;brow_angle=-.13
	var blend:=1.0-exp(-18.0*dt)
	mouth_size=mouth_size.lerp(target_size,blend);mouth_curve=lerpf(mouth_curve,target_curve,blend)
	for mat in mouth_materials:
		mat.set_shader_parameter("mouth_size",mouth_size*radius*.5)
		mat.set_shader_parameter("curve",mouth_curve*radius)
	for i in 2:
		var side:float=-1.0 if i==0 else 1.0
		brows[i].visible=mood!="neutral"
		eyes[i].scale=eyes[i].scale.lerp(Vector3(eye_scale.x,eye_scale.y*blink,1.0),blend)
		eye_cores[i].position.x=lerpf(eye_cores[i].position.x,clampf(look.x,-1,1)*radius*.022,blend)
		eye_cores[i].position.y=lerpf(eye_cores[i].position.y,-clampf(look.y,-1,1)*radius*.014,blend)
		brows[i].rotation.z=lerpf(brows[i].rotation.z,side*brow_angle,blend)
		brows[i].position.y=lerpf(brows[i].position.y,brow_origins[i].y+radius*brow_raise,blend)
		teeth[i].visible=false
		teeth[i].position.y=radius*(mouth_size.y*.36+mouth_curve*.72-.04)
	position.y=sin(time*17)*radius*0.025 if mood=="mock" else 0.0
