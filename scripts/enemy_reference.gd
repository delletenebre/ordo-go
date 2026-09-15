class_name OrdoEnemyReference
extends Node3D
const BodyShader=preload("res://shaders/enemy_reference.gdshader")
var visual:MeshInstance3D
var material:ShaderMaterial
var actor:Node3D
var torso:MeshInstance3D
var face:Node3D
var arena_ref
var view_camera:Camera3D
var radius:=1.0
var family:="felt"
var image_size:=Vector2.ONE
var hidden_parts:Array=[]
var foot_visuals:Array=[]
var shield:Node3D
var death_age:=0.0

func build(arena,root_actor:Node3D,body:MeshInstance3D,kind:String,r:float,parts:Array,view:Camera3D=null)->void:
	arena_ref=arena;actor=root_actor;torso=body;face=actor.get_node("Face");radius=r;family=kind
	view_camera=view if view!=null else arena.camera
	image_size=Vector2(2.42,2.42)*r if family=="felt" else Vector2(2.18,2.18)*r
	var texture=load({"felt":"res://assets/enemy-felt-body-v2.png","stone":"res://assets/enemy-stone-body-v2.png","coal":"res://assets/enemy-coal-body-v3.png"}[family])
	material=ShaderMaterial.new();material.shader=BodyShader;material.set_shader_parameter("artwork",texture)
	var quad:=QuadMesh.new();quad.size=image_size
	visual=MeshInstance3D.new();visual.mesh=quad;visual.material_override=material;add_child(visual)
	visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	for part in parts:
		if part.role in ["winding","knot","mark"]:
			part.node.hide();hidden_parts.append(part.node)
		if part.role=="foot":
			for child in part.node.get_children():
				if child is GeometryInstance3D:child.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_texture=preload("res://assets/enemy-parts/weaver/top-knot.png") if family=="felt" else preload("res://assets/enemy-parts/bulwark/foot-01.png")
			var foot:=MeshInstance3D.new();var sheet:=QuadMesh.new();sheet.size=Vector2(.46,.34)*r
			foot.mesh=sheet;foot.material_override=mat;part.node.add_child(foot);foot.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;foot_visuals.append(foot)
	shield=actor.get_node_or_null("BronzeShield")
	for child in body.get_children():
		if child is GeometryInstance3D:child.hide()
	configure_face()
	step()

func configure_face()->void:
	for i in 2:
		var u:float=([.39,.66] if family=="felt" else [.36,.64])[i]
		var v:=.65 if family=="felt" else .53
		var eye:Node3D=face.eyes[i];eye.position=uv_point(Vector2(u,v),.022*radius);eye.basis=Basis.IDENTITY
		var socket:Node3D=eye.get_child(0);socket.scale*=.74
		var core:Node3D=face.eye_cores[i];core.scale*=.85;core.position=Vector3(0,0,.036*radius)
		var brow:Node3D=face.brows[i];brow.position=eye.position+Vector3(0,.16*radius,.014*radius);brow.basis=Basis.IDENTITY;brow.scale*=.85
		face.brow_origins[i]=brow.position
	face.mouth.position=uv_point(Vector2(.52,.765) if family=="felt" else Vector2(.51,.635 if family=="stone" else .69),.036*radius)
	face.mouth.basis=Basis.IDENTITY;face.mouth.scale=Vector3.ONE*.80
	for mat in face.mouth_materials:
		mat.shader=preload("res://shaders/enemy_reference_mouth.gdshader")
		mat.set_shader_parameter("thickness",radius*.028)

func uv_point(uv:Vector2,depth:float)->Vector3:
	return Vector3((uv.x-.5)*image_size.x,(.5-uv.y)*image_size.y,depth)

func step()->void:
	var camera_basis:Basis=view_camera.global_basis
	var compression:=torso.scale
	var rock:float=torso.rotation.z
	if death_age>0:rock+=torso.get_parent().rotation.z+torso.get_parent().rotation.x*.35
	visual.global_transform=Transform3D(camera_basis*Basis(Vector3.BACK,rock),actor.global_position+Vector3(0,radius*.10,radius*.28)+camera_basis.y*(image_size.y*.46))
	visual.scale=Vector3(compression.x,compression.y,1)
	# During death the expression animates beneath a stable attachment node.
	# Move that attachment with the illustrated body, not the face's local origin.
	if face.get_parent().name=="FaceAnchor":
		face.get_parent().global_transform=visual.global_transform
	else:face.global_transform=visual.global_transform
	for foot in foot_visuals:foot.global_basis=camera_basis
	if family=="stone":
		if shield!=null:
			var tilt:=shield.rotation.x
			var lift:=shield.position.y
			shield.global_transform=visual.global_transform*Transform3D(Basis(Vector3.RIGHT,tilt),Vector3(0,-radius*.67+lift,radius*.08))

func die(age:float)->void:
	death_age=age;step()
	material.set_shader_parameter("opacity",1.0-smoothstep(.12,.52,age))
	face.visible=age<.42
	if family=="felt" and age>.12:
		for part in hidden_parts:part.show()
