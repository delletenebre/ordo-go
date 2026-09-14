class_name OrdoEnemyFace
extends Node3D
var eyes: Array=[]
var brows: Array=[]
var brow_origins:Array=[]
var pupils: Array=[]
var mouth: MeshInstance3D
var lip:Node3D
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
	var dark=arena.material(Color("080a0e"));var light=arena.material(Color("ffc46c"),0.7)
	for side in [-1.0,1.0]:
		var eye:=Node3D.new();add_child(eye);eye.position=Vector3(side*r*0.32,r*1.11,r*0.79);eyes.append(eye)
		arena.sphere(eye,Vector3.ZERO,Vector3(r*0.48,r*0.50,r*0.22),dark)
		arena.sphere(eye,Vector3(0,0,r*0.10),Vector3(r*0.25,r*0.30,r*0.13),light)
		var pupil=arena.sphere(eye,Vector3(0,0,r*0.165),Vector3(r*0.10,r*0.14,r*0.05),arena.material(Color("161321")));pupils.append(pupil)
		arena.sphere(eye,Vector3(-r*0.04,r*0.065,r*0.19),Vector3.ONE*r*0.047,arena.material(Color("fff5cd"),0.3))
		var brow:=Node3D.new();add_child(brow);brow.position=Vector3(side*r*0.32,r*1.39,r*0.78);brows.append(brow)
		arena.sphere(brow,Vector3.ZERO,Vector3(r*0.49,r*0.085,r*0.10),arena.wool(Color("22212b")))
	mouth=arena.sphere(self,Vector3(0,r*0.66,r*0.88),Vector3(r*0.33,r*0.07,r*0.08),dark)
	lip=Node3D.new();add_child(lip);lip.position=Vector3(0,r*0.66,r*0.93)
	var lip_mesh=arena.ring(lip,Vector3.ZERO,1.0,0.085,arena.wool(Color("bcb29d")));lip_mesh.rotation.x=PI/2
	lip.scale=Vector3(r*0.165,r*0.035,r*0.04)
	for side in [-1.0,1.0]:
		var tooth=arena.sphere(self,Vector3(side*r*0.07,r*0.71,r*0.935),Vector3(r*0.10,r*0.08,r*0.04),arena.wool(Color("e8dbc5")));teeth.append(tooth);tooth.hide()

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
	var eye_scale:=Vector2.ONE;var mouth_size:=Vector2(0.33,0.16);var brow_angle:=0.0;var brow_raise:=0.0
	match mood:
		"anger":eye_scale=Vector2(1.0,0.73);brow_angle=0.35;mouth_size=Vector2(0.39,0.11)
		"hate":eye_scale=Vector2(0.98,0.55);brow_angle=0.46;mouth_size=Vector2(0.39,0.095)
		"surprise":eye_scale=Vector2(1.10,1.25);mouth_size=Vector2(0.25,0.31);brow_raise=0.11
		"fear":eye_scale=Vector2(1.14,1.30);mouth_size=Vector2(0.38,0.34);brow_angle=-0.24;brow_raise=0.09
		"joy":eye_scale=Vector2(1.08,0.64);mouth_size=Vector2(0.50,0.22);brow_angle=-0.17
		"mock":eye_scale=Vector2(1.07,0.52);mouth_size=Vector2(0.52,0.15+0.15*(0.5+0.5*sin(time*17)));brow_angle=-0.13
	var blend:=1.0-exp(-18.0*dt)
	for i in 2:
		var side:float=-1.0 if i==0 else 1.0
		eyes[i].scale=eyes[i].scale.lerp(Vector3(eye_scale.x,eye_scale.y*blink,1.0),blend)
		pupils[i].position.x=lerpf(pupils[i].position.x,clampf(look.x,-1,1)*radius*0.065,blend)
		pupils[i].position.y=lerpf(pupils[i].position.y,-clampf(look.y,-1,1)*radius*0.035,blend)
		brows[i].rotation.z=lerpf(brows[i].rotation.z,side*brow_angle,blend)
		brows[i].position.y=lerpf(brows[i].position.y,brow_origins[i].y+radius*brow_raise,blend)
		teeth[i].visible=mood in ["joy","mock","anger","hate"]
		pupils[i].scale.x=lerpf(pupils[i].scale.x,radius*(0.065 if mood=="hate" else 0.10),blend)
	lip.scale=lip.scale.lerp(Vector3(radius*mouth_size.x*.5,radius*mouth_size.y*.5,radius*.04),blend)
	mouth.scale=mouth.scale.lerp(Vector3(radius*mouth_size.x,radius*mouth_size.y,radius*0.08),blend)
	position.y=sin(time*17)*radius*0.025 if mood=="mock" else 0.0
