class_name OrdoCoalDebris
extends Node3D

const CoalMesh = preload("res://scripts/coal_mesh.gd")
const DeathMotion = preload("res://scripts/death_motion.gd")
const EnemyMotion = preload("res://scripts/enemy_motion.gd")
const Materials = preload("res://scripts/enemy_materials.gd")
const CAPACITY := 128
const FLOOR_LAYER := 128
var pieces: Array = []
var cursor := 0
var dropped := 0
var bounce_cooldown := 0.0
var audio_system
var muted := false
var materials: Dictionary = {}
var surfaces: Array[Mesh] = []
var ceramic_shards: Array[Mesh] = []
var physics: Dictionary = {}

func _ready() -> void:
	var floor_body:=StaticBody3D.new();floor_body.collision_layer=FLOOR_LAYER;floor_body.collision_mask=0
	var floor_shape:=CylinderShape3D.new();floor_shape.radius=6.38;floor_shape.height=.12
	var floor_collision:=CollisionShape3D.new();floor_collision.shape=floor_shape;floor_collision.position.y=-.015
	floor_body.add_child(floor_collision);add_child(floor_body)
	# Fragments obey the same parapet as whole corpses; high pieces can clear it.
	for i in 96:
		var angle := TAU * i / 96.0
		var point := Vector2(cos(angle), sin(angle)) * 6.49
		var height := DeathMotion.wall_height(point)
		var shape := BoxShape3D.new(); shape.size = Vector3(0.68, height + 0.18, 0.45)
		var collision := CollisionShape3D.new(); collision.shape = shape
		collision.position = Vector3(point.x, (height - 0.18) * 0.5, point.y)
		collision.rotation.y = -angle
		floor_body.add_child(collision)
	var meshes:Array=[]
	for i in 8:
		meshes.append(CoalMesh.fragment(610+i))
		surfaces.append(meshes[-1]);ceramic_shards.append(shard(i))
	for kind in ["coal", "moth", "hopper", "frost", "brute", "ram", "weaver", "eater"]:
		var mat := Materials.surface(kind, 77)
		if EnemyMotion.material_kind(kind)=="coal":mat.set_shader_parameter("surface_scale", 0.25)
		materials[kind] = mat
		var response:=PhysicsMaterial.new();var profile:=EnemyMotion.profile(kind)
		response.bounce=float(profile.bounce);response.friction=float(profile.friction)
		physics[kind]=response
	var material: ShaderMaterial = materials.coal
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
	var kind:=str(event.get("enemy_kind","coal"))
	if EnemyMotion.material_kind(kind)=="felt":return 0
	var rng:=RandomNumberGenerator.new();rng.seed=int(event.id)*1777+29
	var radius:=float(event.get("radius",float(event.strength)*.5))
	var velocity:=Vector3(float(event.get("vx",0)),float(event.get("vy",0)),float(event.get("vz",0)))
	var directed := bool(event.get("directed", false))
	var style := str(event.get("style", "crumble"))
	var power:=clampf(velocity.length()*.14+float(event.get("damage",1))*.16+combo*.065,.45,1.65)
	var team:=int(event.get("team_size",1))
	if team>=2:power=minf(power*1.30,2.1)
	var count:=16 if radius>.7 or team>=2 else (12 if power>1.05 else 9)
	var created:=0
	var origin:=Vector3(float(event.x),float(event.get("y",radius*.85+.08)),float(event.z))
	for i in count:
		var slot:=-1
		for offset in CAPACITY:
			var candidate:=(cursor+offset)%CAPACITY
			if float(pieces[candidate].life)<=0:slot=candidate;break
		if slot<0:dropped+=count-i;break
		cursor=(slot+1)%CAPACITY
		var item:Dictionary=pieces[slot];var body:RigidBody3D=item.body
		body.physics_material_override=physics.get(kind,physics.coal)
		item.visual.mesh=ceramic_shards[i%8] if kind=="frost" else surfaces[i%8]
		var direction:=Vector3(rng.randf_range(-1,1),rng.randf_range(-.2,.7),rng.randf_range(-1,1)).normalized()
		var size:=radius*rng.randf_range(.22,.42)
		if directed and i < 2 and style in ["split", "air_split", "topple"]: size = radius * rng.randf_range(0.52, 0.68)
		item.size=size;item.life=2.25+rng.randf()*.35
		item.shape.radius=size*.80
		item.visual.scale=Vector3(size,size*rng.randf_range(.65,1.0),size*rng.randf_range(.75,1.05))
		item.visual.material_override = materials.get(str(event.get("enemy_kind", "coal")), materials.coal)
		body.position=origin+direction*radius*.37
		body.rotation=Vector3(rng.randf(),rng.randf(),rng.randf())*TAU
		body.mass=size*1.5;body.collision_mask=FLOOR_LAYER;body.freeze=false;body.sleeping=false
		if directed:
			var spread := 0.65 if style in ["air_split", "split", "flight"] else 1.0
			body.linear_velocity = velocity + direction * power * spread * rng.randf_range(0.7, 1.6) + Vector3.UP * rng.randf_range(0.3, 1.0)
		else:
			body.linear_velocity=velocity.limit_length(9)*.37+direction*power*rng.randf_range(1.1,2.3)+Vector3.UP*rng.randf_range(1.4,2.5)
		body.angular_velocity=Vector3(rng.randf_range(-9,9),rng.randf_range(-10,10),rng.randf_range(-9,9))
		body.visible=true;created+=1
	return created

# Thin curved ceramic wall pieces retain the glaze instead of becoming coal.
static func shard(index:int)->ArrayMesh:
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for layer in 2:
		for y in 4:
			for x in 4:
				var corners:=[Vector2i(x,y),Vector2i(x+1,y),Vector2i(x+1,y+1),Vector2i(x,y),Vector2i(x+1,y+1),Vector2i(x,y+1)]
				if layer==1:corners.reverse()
				for cell in corners:
					var u:float=(float(cell.x)/4-.5)*1.5;var v:float=(float(cell.y)/4-.5)*1.3
					var direction:=Vector3(sin(u)*cos(v),sin(v),cos(u)*cos(v))
					surface.set_normal(direction if layer==0 else -direction)
					surface.add_vertex(direction*(1.5 if layer==0 else 1.36)-Vector3(0,0,1.36)+Vector3(0,sin(u*3+index)*.05,0))
	return surface.commit()

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
