extends Node3D
const Felt=preload("res://scripts/enemy_felt.gd")
var tongues:Array=[]
var materials:Array[ShaderMaterial]=[]
var lamp:OmniLight3D
var sparks:MultiMeshInstance3D
var arena_ref
var torso:MeshInstance3D
var age:=0.0
var strength:=0.0
var charred:=0.0
var smoke_age:=0.0
var radius:=1.0
var previous_position:=Vector3.ZERO

func build(arena,r:float)->void:
	arena_ref=arena;radius=r;torso=get_parent().get_node("Body")
	collect_materials(get_parent())
	# Root the flame sheets at irregular exposed yarn patches. Keep the face open.
	for i in 9:
		var angle:=PI+(float(i)-4.0)*.36
		var y:=.12+fposmod(float(i)*.31,.67)
		var outward:=Vector3(sin(angle),y,cos(angle)).normalized()
		var height:=r*(.77+fposmod(i*.27,.47))
		var mat:=ShaderMaterial.new();mat.shader=preload("res://shaders/enemy_fire.gdshader")
		mat.set_shader_parameter("phase",i*1.73)
		var quad:=QuadMesh.new();quad.size=Vector2(r*(.61+fposmod(i*.17,.18)),height)
		var flame:MeshInstance3D=arena.mesh_node(self,quad,Vector3.ZERO,mat)
		flame.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tongues.append({"node":flame,"mat":mat,"root":outward*r*1.06,"height":height})
	lamp=OmniLight3D.new();lamp.position=Vector3(0,r*1.6,-r*.25);lamp.omni_range=r*3.4
	lamp.light_color=Color("ff9b47");lamp.shadow_enabled=false;add_child(lamp)
	var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true
	var bead:=SphereMesh.new();bead.radius=r*.008;bead.height=r*.016;bead.radial_segments=6;bead.rings=3
	mm.mesh=bead;mm.instance_count=22
	sparks=MultiMeshInstance3D.new();sparks.multimesh=mm;sparks.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ember:=StandardMaterial3D.new();ember.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	ember.vertex_color_use_as_albedo=true;ember.emission_enabled=true;ember.emission=Color("ff6f16");ember.emission_energy_multiplier=.8
	sparks.material_override=ember;add_child(sparks)
	previous_position=get_parent().global_position
	hide()

func collect_materials(node:Node)->void:
	if node is GeometryInstance3D:
		var mat=node.material_override
		if mat is ShaderMaterial and mat.shader in [Felt.YarnShader,preload("res://shaders/enemy_reference.gdshader")] and mat not in materials:materials.append(mat)
	for child in node.get_children():collect_materials(child)

func step(value:float,dt:float)->void:
	age+=dt;strength=move_toward(strength,value,dt*1.8);charred=maxf(charred,strength)
	for mat in materials:
		mat.set_shader_parameter("heat",strength)
		mat.set_shader_parameter("charred",charred)
		mat.set_shader_parameter("elapsed",age)
	visible=strength>.01
	var velocity:Vector3=(get_parent().global_position-previous_position)/maxf(dt,.0001)
	previous_position=get_parent().global_position
	if not visible:return
	lamp.light_energy=strength*(.65+sin(age*7.1)*.04+sin(age*11.3)*.025)
	for tongue in tongues:
		var flame:MeshInstance3D=tongue.node
		var height:float=tongue.height*(.45+strength*.55)
		flame.position=torso.transform*tongue.root+Vector3.UP*height*.40
		var forward:Vector3=arena_ref.camera.global_position-flame.global_position;forward.y=0;forward=forward.normalized()
		flame.global_basis=Basis(Vector3.UP.cross(forward),Vector3.UP,forward)
		flame.scale.y=.45+strength*.55
		tongue.mat.set_shader_parameter("elapsed",age)
		tongue.mat.set_shader_parameter("strength",smoothstep(.2,.8,strength))
		tongue.mat.set_shader_parameter("drift",Vector2(-velocity.x,-velocity.z).limit_length(3)*radius*.045)
	for i in 22:
		var t:=fposmod(age*(.30+fposmod(i*.17,.20))+float(i)*.618,1.0)
		var a:=i*2.4+sin(age*.7+i)*.25
		var p:=Vector3(cos(a)*(.66+t*.3),1.45+t*1.6,sin(a)*.64-.18)*radius
		p.x+=sin(t*5+i)*radius*.12
		var size:=sin(t*PI)*strength*(.5+fposmod(i*.23,.7))
		sparks.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*maxf(.001,size)),p))
		sparks.multimesh.set_instance_color(i,Color(1.0,.45+(.4*(1-t)),.06))
	smoke_age+=dt
	if smoke_age>.24 and strength>.3:
		smoke_age=0
		arena_ref.smoke.emit_puff(global_position+Vector3(sin(age)*radius*.35,radius*2.0,-radius*.30),Vector3(.03,.55,-.04),radius*.65,1.15,strength*.14)
