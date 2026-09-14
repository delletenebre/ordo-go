class_name OrdoCoalDebris
extends Node3D

const CoalMesh = preload("res://scripts/coal_mesh.gd")
const CAPACITY := 128
const FLOOR_LAYER := 128
var pieces: Array = []
var cursor := 0
var dropped := 0
var bounce_cooldown := 0.0
var audio_system
var muted := false

func _ready() -> void:
	var floor_body:=StaticBody3D.new();floor_body.collision_layer=FLOOR_LAYER;floor_body.collision_mask=0
	var floor_shape:=CylinderShape3D.new();floor_shape.radius=6.25;floor_shape.height=.12
	var floor_collision:=CollisionShape3D.new();floor_collision.shape=floor_shape;floor_collision.position.y=-.015
	floor_body.add_child(floor_collision);add_child(floor_body)
	var meshes:Array=[]
	for i in 8:meshes.append(CoalMesh.fragment(610+i))
	var material:=CoalMesh.material_for("coal",77);material.set_shader_parameter("surface_scale",.25)
	var physics_material:=PhysicsMaterial.new();physics_material.bounce=.35;physics_material.friction=.82
	for i in CAPACITY:
		var body:=RigidBody3D.new();body.name="CoalFragment%d"%i;body.freeze=true;body.visible=false
		body.collision_layer=0;body.collision_mask=0;body.gravity_scale=1.0
		body.linear_damp=.38;body.angular_damp=.7;body.physics_material_override=physics_material
		body.continuous_cd=true;body.contact_monitor=true;body.max_contacts_reported=1
		var collision:=CollisionShape3D.new();collision.shape=SphereShape3D.new();collision.shape.radius=.1;body.add_child(collision)
		var visual:=MeshInstance3D.new();visual.mesh=meshes[i%8];visual.material_override=material;body.add_child(visual)
		body.body_entered.connect(_bounce);add_child(body)
		pieces.append({"body":body,"visual":visual,"shape":collision.shape,"life":0.0,"size":.1})

func _bounce(_body: Node) -> void:
	if bounce_cooldown>0 or muted or audio_system==null:return
	bounce_cooldown=.14
	audio_system.play_sound("impact",-29.0)

func shatter(event: Dictionary, combo: int = 0) -> int:
	var rng:=RandomNumberGenerator.new();rng.seed=int(event.id)*1777+29
	var radius:=float(event.get("radius",float(event.strength)*.5))
	var velocity:=Vector3(float(event.get("vx",0)),0,float(event.get("vz",0)))
	var power:=clampf(velocity.length()*.14+float(event.get("damage",1))*.16+combo*.065,.45,1.65)
	var team:=int(event.get("team_size",1))
	if team>=2:power=minf(power*1.30,2.1)
	var count:=16 if radius>.7 or team>=2 else (12 if power>1.05 else 9)
	var created:=0
	var origin:=Vector3(float(event.x),radius*.85+.08,float(event.z))
	for i in count:
		var slot:=-1
		for offset in CAPACITY:
			var candidate:=(cursor+offset)%CAPACITY
			if float(pieces[candidate].life)<=0:slot=candidate;break
		if slot<0:dropped+=count-i;break
		cursor=(slot+1)%CAPACITY
		var item:Dictionary=pieces[slot];var body:RigidBody3D=item.body
		var direction:=Vector3(rng.randf_range(-1,1),rng.randf_range(-.2,.7),rng.randf_range(-1,1)).normalized()
		var size:=radius*rng.randf_range(.22,.42)
		item.size=size;item.life=2.25+rng.randf()*.35
		item.shape.radius=size*.80
		item.visual.scale=Vector3(size,size*rng.randf_range(.65,1.0),size*rng.randf_range(.75,1.05))
		body.position=origin+direction*radius*.37
		body.rotation=Vector3(rng.randf(),rng.randf(),rng.randf())*TAU
		body.mass=size*1.5;body.collision_mask=FLOOR_LAYER;body.freeze=false;body.sleeping=false
		body.linear_velocity=velocity.limit_length(9)*.37+direction*power*rng.randf_range(1.1,2.3)+Vector3.UP*rng.randf_range(1.4,2.5)
		body.angular_velocity=Vector3(rng.randf_range(-9,9),rng.randf_range(-10,10),rng.randf_range(-9,9))
		body.visible=true;created+=1
	return created

func step(dt: float) -> void:
	bounce_cooldown=maxf(0,bounce_cooldown-dt)
	for item in pieces:
		if float(item.life)<=0:continue
		item.life=maxf(0,float(item.life)-dt)
		if float(item.life)<.40:
			item.body.collision_mask=0
			item.visual.scale=Vector3.ONE*float(item.size)*smoothstep(0,.40,float(item.life))
		if float(item.life)<=0:
			item.body.freeze=true;item.body.visible=false;item.body.collision_mask=0

func active_count() -> int:
	var total:=0
	for item in pieces:
		if float(item.life)>0:total+=1
	return total

func clear() -> void:
	for item in pieces:
		item.life=0.0;item.body.freeze=true;item.body.visible=false;item.body.collision_mask=0
	dropped=0
