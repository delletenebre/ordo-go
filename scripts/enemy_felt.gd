class_name OrdoEnemyFelt
extends RefCounted

const YarnShader=preload("res://shaders/enemy_yarn.gdshader")
const FiberMap=preload("res://assets/enemy-felt-v1.png")
const FACE_NORMAL=Vector3(0,.52,.854166)
const FACE_UP=Vector3(0,.854166,-.52)

static func material(color:Color,r:float,strand:bool=true)->ShaderMaterial:
	var mat:=ShaderMaterial.new();mat.shader=YarnShader
	mat.set_shader_parameter("fiber_map",FiberMap)
	mat.set_shader_parameter("wool_color",color)
	mat.set_shader_parameter("radius",r)
	mat.set_shader_parameter("strand",strand)
	return mat

static func build(arena,body:MeshInstance3D,r:float,seed_value:int)->Array:
	body.material_override=material(Color("514b42"),r,false)
	var parts:Array=[]
	var light:=material(Color("c9baa0"),r)
	var shade:=material(Color("b6a386"),r)
	var fuzz:=SurfaceTool.new();fuzz.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng:=RandomNumberGenerator.new();rng.seed=seed_value*193+7
	# Six broad skeins and two crossing stays make an irregular wound ball.
	# Each rope is a continuous three-ply helix, not a stack of ring primitives.
	for bundle in 8:
		var node:=Node3D.new();body.add_child(node);node.name="Winding%d"%bundle
		var axis:=Basis(Vector3.FORWARD,-.28 if bundle<6 else (.92 if bundle==6 else -.87))
		var latitude:float=[-.90,-.57,-.24,.10,.44,.79,.10,-.23][bundle]
		var centers:=PackedVector3Array()
		for i in 257:
			var a:=float(i)/256*TAU
			var lat:=latitude+sin(a*2.0+bundle*.8)*.035
			var direction:=axis*Vector3(cos(a)*cos(lat),sin(lat),sin(a)*cos(lat))
			direction=clear_face(direction,bundle)
			centers.append(direction*r*(1.015+float(bundle%3)*.014))
		var mat:=light if bundle%3 else shade
		rope(node,centers,r*.091,mat,r,rng,fuzz)
		parts.append({"node":node,"rest":node.transform,"role":"winding","side":-1.0 if bundle%2 else 1.0})
	var knot:=Node3D.new();body.add_child(knot);knot.name="YarnKnot"
	knot.position=Vector3(-.10,1.045,-.10)*r
	arena.sphere(knot,Vector3.ZERO,Vector3(.40,.29,.34)*r,shade)
	for ring in 3:
		var loop:=PackedVector3Array();var axis:=Basis(Vector3.FORWARD,float(ring)*1.07)
		for i in 129:
			var a:=i*TAU/128.0
			loop.append(axis*Vector3(cos(a)*.15,sin(a)*.15,sin(a*2)*.028)*r)
		rope(knot,loop,r*.042,light,r,rng,null)
	parts.append({"node":knot,"rest":knot.transform,"role":"knot","side":0.0})
	var halo:=MeshInstance3D.new();halo.name="LooseWoolFibers";body.add_child(halo)
	halo.mesh=fuzz.commit();halo.material_override=light;halo.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return parts

static func clear_face(direction:Vector3,bundle:int)->Vector3:
	var front:=direction.dot(FACE_NORMAL)
	if front<=.45:return direction
	var x:=direction.x;var y:=direction.dot(FACE_UP)
	var width:=.61;var height:=.48
	var distance:=sqrt(x*x/(width*width)+y*y/(height*height))
	if distance>=1.0:return direction
	# Route the same strand around an oval opening. Nothing crosses the eyes.
	if distance<.05:y=.05 if bundle>3 else -.05;distance=absf(y)/height
	x/=distance;y/=distance
	return (Vector3.RIGHT*x+FACE_UP*y+FACE_NORMAL*sqrt(maxf(.05,1-x*x-y*y))).normalized()

static func rope(parent:Node3D,centers:PackedVector3Array,width:float,mat:Material,r:float,rng:RandomNumberGenerator,fuzz:SurfaceTool)->void:
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var along:=0.0;var lengths:=PackedFloat32Array([0.0])
	for i in range(1,centers.size()):
		along+=centers[i].distance_to(centers[i-1]);lengths.append(along)
	var twists:=maxi(3,roundi(along/(width*3.4)))
	for ply in 3:
		var points:=PackedVector3Array()
		for i in centers.size():
			var tangent:Vector3=(centers[mini(i+1,centers.size()-1)]-centers[maxi(0,i-1)]).normalized()
			var radial:=centers[i].normalized();var side:=tangent.cross(radial).normalized()
			var twist:=lengths[i]/along*TAU*twists+float(ply)*TAU/3
			points.append(centers[i]+(radial*cos(twist)+side*sin(twist))*width*.44)
		add_tube(surface,points,width*.64,r)
		if fuzz!=null:
			for i in range(2,points.size()-2,2):
				var tangent:Vector3=(points[i+1]-points[i-1]).normalized()
				var normal:=centers[i].normalized();var side:=normal.cross(tangent).normalized()
				var a:=rng.randf()*TAU;var out:=normal*cos(a)+side*sin(a)
				var base:=points[i]+out*width*.63
				var length:=r*rng.randf_range(.012,.041)
				var tip:=base+out*length+tangent*length*.60
				var mid:=base.lerp(tip,.5)+out*length*.2
				var edge:=side*r*.0010
				for vertex in [base-edge,mid+edge,mid-edge,base-edge,base+edge,mid+edge,mid-edge,tip,mid+edge]:
					fuzz.set_normal(out);fuzz.set_uv(Vector2(lengths[i]/r,a/TAU));fuzz.add_vertex(vertex)
	surface.index()
	var mesh:=MeshInstance3D.new();mesh.mesh=surface.commit();mesh.material_override=mat;parent.add_child(mesh)

static func add_tube(surface:SurfaceTool,points:PackedVector3Array,width:float,r:float)->void:
	var vertices:=PackedVector3Array();var normals:=PackedVector3Array();var uvs:=PackedVector2Array()
	var distance:=0.0;var old_side:=Vector3.ZERO
	for i in points.size():
		if i>0:distance+=points[i].distance_to(points[i-1])
		var tangent:Vector3=(points[mini(i+1,points.size()-1)]-points[maxi(0,i-1)]).normalized()
		var helper:=Vector3.UP if absf(tangent.y)<.94 else Vector3.FORWARD
		var side:=tangent.cross(helper).normalized() if i==0 else (old_side-tangent*old_side.dot(tangent)).normalized()
		old_side=side;var normal:=tangent.cross(side).normalized()
		for j in 9:
			var n:=side*cos(j*TAU/8.0)+normal*sin(j*TAU/8.0)
			normals.append(n);vertices.append(points[i]+n*width);uvs.append(Vector2(distance/r*6.0,float(j)/8))
	for i in points.size()-1:
		for j in 8:
			for index in [i*9+j,(i+1)*9+j,(i+1)*9+j+1,i*9+j,(i+1)*9+j+1,i*9+j+1]:
				surface.set_normal(normals[index]);surface.set_uv(uvs[index]);surface.add_vertex(vertices[index])
