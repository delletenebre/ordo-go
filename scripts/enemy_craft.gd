class_name OrdoEnemyCraft
extends RefCounted
const Wool=preload("res://scripts/wool_mesh.gd")
const Materials=preload("res://scripts/enemy_materials.gd")
const Motion=preload("res://scripts/enemy_motion.gd")

static func build(arena,actor:Node3D,body:MeshInstance3D,kind:String,r:float,seed_value:int)->Array:
	var family:=Motion.material_kind(kind)
	var material:=Materials.surface(kind,seed_value);body.material_override=material
	var parts:Array=[]
	for side in [-1.0,1.0]:
		var foot:=Node3D.new();actor.add_child(foot);foot.name="FootLeft" if side<0 else "FootRight"
		foot.position=Vector3(side*r*.48,r*.10,r*.40)
		arena.sphere(foot,Vector3.ZERO,Vector3(.44,.30,.58)*r,material)
		parts.append({"node":foot,"rest":foot.transform,"role":"foot","side":side})
	match family:
		"stone":
			var shield:=Node3D.new();shield.name="BronzeShield";actor.add_child(shield)
			var brass:=ShaderMaterial.new();brass.shader=preload("res://shaders/enemy_reference.gdshader")
			brass.set_shader_parameter("artwork",preload("res://assets/enemy-bronze-shield-v3.png"))
			brass.set_shader_parameter("source_rect",Vector4(140.0/1774,131.0/887,1489.0/1774,637.0/887))
			var plate:=QuadMesh.new();plate.size=Vector2(1.74,1.74*637/1489)*r
			var shield_art:MeshInstance3D=arena.mesh_node(shield,plate,Vector3.ZERO,brass)
			shield_art.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parts.append({"node":shield,"rest":shield.transform,"role":"shield","side":0.0})
			var groove=arena.material(Color("202831"));groove.roughness=.95
			var mark:=Node3D.new();actor.add_child(mark);mark.name="CarvedMark"
			var normal:=Vector3(0,.84,.55).normalized();var down:=Vector3(0,-.55,.84).normalized()
			var outline:=PackedVector3Array()
			for v in [Vector2(0,-.28),Vector2(.26,0),Vector2(0,.30),Vector2(-.26,0),Vector2(0,-.28)]:
				outline.append((normal+Vector3.RIGHT*v.x+down*v.y).normalized()*r*1.002+Vector3(0,r*.94,0))
			tube(mark,outline,r*.025,groove)
			var curl:=PackedVector3Array()
			for i in 65:
				var t:=float(i)/64;var a:=t*TAU*1.30;var size:=.16*(1-t*.78)
				curl.append((normal+Vector3.RIGHT*cos(a)*size+down*sin(a)*size).normalized()*r*1.006+Vector3(0,r*.94,0))
			tube(mark,curl,r*.018,groove)
			parts.append({"node":mark,"rest":mark.transform,"role":"mark","side":0.0})
		"ceramic":
			var crown:=Node3D.new();actor.add_child(crown);crown.name="GlazedCrown"
			var points:=PackedVector3Array()
			for i in 97:
				var t:=float(i)/96;var a:=t*TAU*1.7;var radius:=r*.22*(1-t*.78)
				points.append(Vector3(cos(a)*radius,r*(1.88+t*.13),sin(a)*radius))
			Wool.thread_path(crown,points,r*.045,material)
			parts.append({"node":crown,"rest":crown.transform,"role":"crown","side":0.0})
		"felt":
			parts.append_array(preload("res://scripts/enemy_felt.gd").build(arena,body,r,seed_value))
	if family in ["felt","stone","coal"]:
		var reference=preload("res://scripts/enemy_reference.gd").new();reference.name="ReferenceBody";actor.add_child(reference)
		reference.build(arena,actor,body,family,r,parts)
	return parts

static func tube(parent:Node3D,points:PackedVector3Array,width:float,mat:Material)->MeshInstance3D:
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vertices:Array[Vector3]=[];var normals:Array[Vector3]=[]
	for i in points.size():
		var tangent:Vector3=(points[mini(i+1,points.size()-1)]-points[maxi(0,i-1)]).normalized()
		var helper:=Vector3.UP if absf(tangent.y)<.94 else Vector3.FORWARD
		var side:=tangent.cross(helper).normalized();var normal:=tangent.cross(side).normalized()
		for j in 8:
			var n:=side*cos(j*TAU/8.0)+normal*sin(j*TAU/8.0)
			normals.append(n);vertices.append(points[i]+n*width)
	for i in points.size()-1:
		for j in 8:
			for index in [i*8+j,(i+1)*8+j,(i+1)*8+(j+1)%8,i*8+j,(i+1)*8+(j+1)%8,i*8+(j+1)%8]:
				surface.set_normal(normals[index]);surface.add_vertex(vertices[index])
	var mesh:=MeshInstance3D.new();mesh.mesh=surface.commit();mesh.material_override=mat;parent.add_child(mesh);return mesh

static func felt_fuzz(r:float,seed_value:int)->ArrayMesh:
	var rng:=RandomNumberGenerator.new();rng.seed=seed_value*313
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 1400:
		var n:=Vector3(rng.randf_range(-1,1),rng.randf_range(-1,1),rng.randf_range(-1,1)).normalized()
		var side:=n.cross(Vector3.UP).normalized()
		var base:=n*r*1.035;var tip:=base+n*r*rng.randf_range(.008,.025)+side*r*.010
		for point in [base-side*r*.0015,tip,base+side*r*.0015]:surface.set_normal(n);surface.add_vertex(point)
	return surface.commit()
