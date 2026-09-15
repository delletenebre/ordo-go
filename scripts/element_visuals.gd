extends Node3D
const Fire = preload("res://shaders/field_flame.gdshader")
const FlameMesh = preload("res://scripts/field_flame_mesh.gd")
const IceMesh = preload("res://scripts/field_ice_mesh.gd")
const Ice = preload("res://shaders/element_ice.gdshader")
var marks: Dictionary = {}
var elapsed := 0.0
var haze

func _ready() -> void:
	haze=preload("res://scripts/element_haze.gd").new(); add_child(haze)

func make_mark(arena, radius: float, ground: bool) -> Dictionary:
	var node := Node3D.new(); add_child(node)
	var ice_mat := ShaderMaterial.new(); ice_mat.shader = Ice
	var ice := Node3D.new(); node.add_child(ice)
	ice_mat.set_shader_parameter("solid",1.0 if ground else 0.0)
	var sheet: MeshInstance3D=arena.mesh_node(ice,IceMesh.build(ground),Vector3.ZERO,ice_mat)
	sheet.scale=Vector3.ONE*radius*(1.23 if ground else 1.0)
	sheet.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var flames: Array = []
	var tongue_count := 1 if ground else 3
	for i in tongue_count:
		var angle := -PI*.5 if i==0 else (PI*.20 if i==1 else PI*.80)
		var height := radius*2.5 if ground else radius*(2.1 if i==0 else .85)
		var mat := ShaderMaterial.new(); mat.shader=Fire; mat.set_shader_parameter("phase",i*2.31)
		var volume := FlameMesh.build(radius*(2.2 if ground else (2.2 if i==0 else .90)),height)
		var rim := 0.0 if ground else radius*.68
		var root_point := Vector3(cos(angle)*rim,.02 if ground else radius*.25,sin(angle)*rim)
		var flame: MeshInstance3D = arena.mesh_node(node,volume,root_point,mat)
		flame.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flames.append({"node":flame,"mat":mat,"root":root_point,"height":height})
	var lamp := OmniLight3D.new(); lamp.position.y=radius*.8
	lamp.light_color=Color("ff963b"); lamp.omni_range=radius*5; lamp.shadow_enabled=false
	node.add_child(lamp)
	# Fixed batch: rising embers do not allocate particles or nodes each frame.
	var mm := MultiMesh.new(); mm.transform_format=MultiMesh.TRANSFORM_3D; mm.use_colors=true
	var bead := SphereMesh.new(); bead.radius=radius*.018; bead.height=radius*.036; bead.radial_segments=6; bead.rings=3
	mm.mesh=bead; mm.instance_count=18
	var sparks := MultiMeshInstance3D.new(); sparks.multimesh=mm
	sparks.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ember := StandardMaterial3D.new(); ember.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	ember.vertex_color_use_as_albedo=true; ember.emission_enabled=true; ember.emission=Color("ffb535"); ember.emission_energy_multiplier=1.1
	sparks.material_override=ember; node.add_child(sparks)
	var pips: Array = []
	for i in 2:
		pips.append(arena.sphere(node,Vector3((i-.5)*.11,radius*2.65,0),Vector3.ONE*.055,arena.material(Color("ffd178"),1.0)))
	return {"node":node,"ice":ice,"ice_mat":ice_mat,"flames":flames,"pips":pips,"fire":0.0,"cold":0.0,"live":true,"owner":-1,"exit":0.0,"ground":ground,"lamp":lamp,"sparks":sparks,"radius":radius,"age":0.0,"velocity":Vector3.ZERO,"haze_time":0.0}

func step(sim, arena, dt: float) -> void:
	elapsed += dt
	haze.step(dt,arena.camera.global_basis)
	for mark in marks.values(): mark.live=false
	for item in sim.pickups:
		if item.kind != "element" or item.get("used",false): continue
		var key := "drop:%d" % int(item.id)
		if not marks.has(key): marks[key]=make_mark(arena,.30,true)
		var mark: Dictionary=marks[key]; mark.live=true
		mark.node.position=Vector3(float(item.x),.10+sin(elapsed*2+int(item.id))*.025,float(item.z))
		mark.want_fire=item.element=="fire"; mark.want_cold=item.element=="frost"; mark.ticks=0
	for body in sim.players+sim.enemies:
		var key := "actor:%d" % int(body.id)
		var burn: bool=sim.Effects.burning(sim,body)
		var chill: bool=sim.Effects.cold(body) and int(body.hp)>0
		if not burn and not chill: continue
		if not marks.has(key): marks[key]=make_mark(arena,float(body.r),false)
		var mark: Dictionary=marks[key]; mark.live=true
		var actor=arena.actors.get(str(int(body.id)))
		mark.node.position=actor.position if actor!=null else Vector3(float(body.x),.03,float(body.z))
		mark.velocity=Vector3(float(body.get("vx",0)),0,float(body.get("vz",0)))
		mark.want_fire=burn; mark.want_cold=chill; mark.ticks=int(body.get("statuses",{}).get("burn",0))
	for key in marks.keys():
		var mark: Dictionary=marks[key]
		mark.age+=dt
		if not mark.live and mark.ground:
			if int(mark.owner)<0:
				for event in sim.events:
					if event.kind=="element_pickup" and key=="drop:%d"%int(event.get("pickup",-1)):
						mark.owner=int(event.target); mark.origin=mark.node.position
			if int(mark.owner)>=0:
				mark.exit+=dt
				var actor=arena.actors.get(str(int(mark.owner)))
				if actor!=null:
					var t:=clampf(float(mark.exit)/.42,0,1)
					mark.node.position=Vector3(mark.origin).lerp(actor.position+Vector3.UP*.3,smoothstep(0,1,t))+Vector3.UP*sin(t*PI)*.48
		var arriving: bool=mark.ground and int(mark.owner)>=0 and float(mark.exit)<.42
		var strength := 1.0-smoothstep(.24,.42,float(mark.exit)) if arriving else 1.0
		mark.fire=move_toward(float(mark.fire),strength if (mark.live or arriving) and mark.get("want_fire",false) else 0.0,dt*4.5)
		mark.cold=move_toward(float(mark.cold),strength if (mark.live or arriving) and mark.get("want_cold",false) else 0.0,dt*10)
		mark.ice.visible=float(mark.cold)>.001
		mark.ice.scale=Vector3.ONE*lerpf(.65,1.0,float(mark.cold))
		mark.ice_mat.set_shader_parameter("strength",mark.cold)
		var radius: float=mark.radius
		mark.haze_time+=dt
		if mark.live and float(mark.haze_time)>=.24 and (float(mark.cold)>.1 or float(mark.fire)>.1):
			mark.haze_time=0.0
			var cold: bool=float(mark.cold)>float(mark.fire)
			var angle:=elapsed*2.4+float(mark.node.get_instance_id()%19)
			var outward:=Vector3(cos(angle),0,sin(angle))
			var point: Vector3=mark.node.position+outward*radius*.76+Vector3.UP*radius*(.30 if cold else 2.35)
			var velocity: Vector3=outward*(.15 if cold else .035)+Vector3.UP*(.045 if cold else .34)+Vector3(mark.velocity)*.08
			haze.emit_wisp(point,velocity,radius*(1.15 if cold else .75),cold,maxf(float(mark.cold),float(mark.fire)))
		var flare := sin(clampf(float(mark.age)/.55,0,1)*PI)*.24
		var camera_right: Vector3=arena.camera.global_basis.x
		var lean := clampf(-Vector3(mark.velocity).dot(camera_right)*.065,-.55,.55)
		var forward: Vector3=arena.camera.global_position-mark.node.global_position
		forward.y=0; forward=forward.normalized()
		for flame in mark.flames:
			flame.node.visible=float(mark.fire)>.001
			flame.node.global_basis=Basis(Vector3.UP.cross(forward),Vector3.UP,forward)
			var growth := (.7+float(mark.fire)*.3+flare)

			flame.node.scale.y=growth
			flame.node.position=Vector3(flame.root)
			flame.mat.set_shader_parameter("elapsed",elapsed)
			flame.mat.set_shader_parameter("strength",mark.fire)
			flame.mat.set_shader_parameter("lean",lean)
		mark.lamp.light_energy=float(mark.fire)*(.65+sin(elapsed*9.3)*.06+sin(elapsed*15.7)*.025+flare)
		mark.sparks.visible=float(mark.fire)>.001
		for i in 18:
			var t := fposmod(elapsed*(.42+fposmod(i*.13,.25))+i*.618,1.0)
			var angle := i*2.39996+sin(t*4+i)*.22
			var point := Vector3(cos(angle)*(.55+t*.35),.6+t*3.4,sin(angle)*(.55+t*.35))*radius
			point-=Vector3(mark.velocity).limit_length(8)*t*t*.055
			var size := sin(t*PI)*float(mark.fire)*(1.0+flare)*(.5+fposmod(i*.23,.7))
			mark.sparks.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*maxf(.001,size)),point))
			mark.sparks.multimesh.set_instance_color(i,Color(1.0,.40+.45*(1-t),.06))
		for i in 2: mark.pips[i].visible=mark.live and i<int(mark.get("ticks",0))
		if not mark.live and float(mark.fire)<=0 and float(mark.cold)<=0:
			mark.node.queue_free(); marks.erase(key)

func clear() -> void:
	for mark in marks.values(): mark.node.queue_free()
	marks.clear()
	if haze!=null: haze.clear()
