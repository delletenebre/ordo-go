class_name OrdoRuneVisuals
extends Node3D
const Rules=preload("res://scripts/runestones.gd")
const SpiritVisuals=preload("res://scripts/spirit_visuals.gd")
var stones:Array=[]
var wisps:Array=[]
var drops:Dictionary={}
var defenses:Dictionary={}
var time:=0.0

func build(arena) -> void:
	for root in arena.rune_stones:
		var mat:ShaderMaterial=root.get_node("Rune").material_override
		var halo_mat=arena.material(Color("55c9ff"),.9)
		var halo=arena.ring(root,Vector3(0,-.175,0),.60,.012,halo_mat);halo.hide()
		stones.append({"root":root,"rune":mat,"halo":halo,"material":halo_mat,"pips":[root.get_node("Charge0").material_override,root.get_node("Charge1").material_override]})
	for i in 12:
		var root:=Node3D.new();add_child(root);root.hide()
		var mat=arena.material(Color("ffc777"),2.1)
		var head=arena.sphere(root,Vector3.ZERO,Vector3.ONE*.11,mat)
		head.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var tail:Array=[]
		for j in 5:
			var glow=arena.sphere(root,Vector3.ZERO,Vector3.ONE*(.078-j*.01),arena.material(Color("8bd6ff"),1.5))
			glow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;tail.append(glow)
		wisps.append({"root":root,"tail":tail})

func path(start:Vector3,end:Vector3,t:float)->Vector3:
	var ease:=t*t*(3-2*t)
	return start.lerp(end,ease)+Vector3(0,sin(t*PI)*.80,0)

func step(sim,arena,dt:float)->void:
	time+=dt
	for i in mini(stones.size(),sim.stones.size()):
		var state:Dictionary=sim.stones[i];var visual:Dictionary=stones[i]
		var charged:=Rules.charged(state)
		var kind:String=state.get("effect","")
		var color:=Color(Rules.EFFECTS[kind].color) if Rules.EFFECTS.has(kind) else Color("86c7df")
		visual.root.position=Vector3(float(state.x),.24,float(state.z))
		visual.root.rotation.y=-atan2(float(state.z),float(state.x))
		visual.rune.set_shader_parameter("rune_color",color)
		visual.rune.set_shader_parameter("rune_glow",(1.4+sin(time*2.8+i)*.10) if charged else (.08+int(state.get("souls",0))*.18 if state.get("collector",false) else 0.0))
		for pip in 2:
			var filled:bool=pip<int(state.get("souls",0))
			visual.pips[pip].albedo_color=color if filled else Color("594a34")
			visual.pips[pip].emission=color
			visual.pips[pip].emission_energy_multiplier=.8 if filled else 0.0
		visual.halo.visible=charged;visual.material.albedo_color=color;visual.material.emission=color
	for i in wisps.size():
		var wisp:Dictionary=wisps[i]
		if i>=sim.soul_flights.size():wisp.root.hide();continue
		var flight:Dictionary=sim.soul_flights[i];var index:=int(flight.stone)
		if index>=sim.stones.size():wisp.root.hide();continue
		var start:=Vector3(float(flight.x),float(flight.height)+.15,float(flight.z))
		var destination:=Vector3(float(sim.stones[index].x),.53,float(sim.stones[index].z))
		var t:=clampf(1-float(flight.left)/Rules.FLIGHT_TIME,0,1)
		wisp.root.position=path(start,destination,t);wisp.root.show()
		for j in wisp.tail.size():wisp.tail[j].position=path(start,destination,maxf(0,t-(j+1)*.045))-wisp.root.position
	var live:Dictionary={}
	for drop in sim.rune_drops:
		var key:=str(int(drop.id));live[key]=true
		if not drops.has(key):
			var sprite:=Sprite3D.new();sprite.texture=SpiritVisuals.icon(drop.spirit);sprite.pixel_size=.00180
			sprite.billboard=BaseMaterial3D.BILLBOARD_DISABLED;sprite.shaded=false;sprite.no_depth_test=false
			sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(sprite);drops[key]=sprite
		var t:=clampf(1-float(drop.left)/Rules.FLIGHT_TIME,0,1)
		drops[key].position=path(Vector3(float(drop.sx),float(drop.get("height",.56)),float(drop.sz)),Vector3(float(drop.x),.185+sin(time*1.6+int(drop.id))*.035,float(drop.z)),t)
		drops[key].scale=Vector3.ONE*(.45+.55*sin(t*PI*.5));drops[key].rotation=Vector3(-PI/2+sin(t*PI)*.8,t*TAU,sin(t*PI)*.15)
	for key in drops.keys():
		if not live.has(key):drops[key].queue_free();drops.erase(key)
	for player in sim.players:
		var id:=int(player.id)
		if not defenses.has(id):
			var root:=Node3D.new();add_child(root)
			var thorn_root:=Node3D.new();root.add_child(thorn_root)
			var metal=arena.material(Color("ddbddd"),.35)
			for j in 10:
				var angle:=j*TAU/10.0
				var mesh:=CylinderMesh.new();mesh.top_radius=0;mesh.bottom_radius=.045;mesh.height=.18;mesh.radial_segments=5
				var thorn=arena.mesh_node(thorn_root,mesh,Vector3(cos(angle)*.51,.17,sin(angle)*.51),metal)
				thorn.rotation=Vector3(0,-angle,PI/2)
			var mat:=ShaderMaterial.new();mat.shader=preload("res://shaders/shield.gdshader");mat.set_shader_parameter("shield_color",Color("ffd07d"))
			var guard=arena.sphere(root,Vector3(0,.15,0),Vector3(1.20,.82,1.20),mat)
			defenses[id]={"root":root,"thorns":thorn_root,"guard":guard}
		var visual:Dictionary=defenses[id]
		visual.root.position=Vector3(float(player.x),.02,float(player.z))
		visual.thorns.visible=int(player.hp)>0 and Rules.boon(player,"thorns")
		visual.guard.visible=int(player.hp)>0 and Rules.boon(player,"guard")

func clear()->void:
	for wisp in wisps:wisp.root.hide()
	for sprite in drops.values():sprite.queue_free()
	drops.clear()
	for defense in defenses.values():defense.root.queue_free()
	defenses.clear()
