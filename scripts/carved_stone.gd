class_name OrdoCarvedStone
extends RefCounted

static var face_mesh: ArrayMesh
static var cuts: Array[Vector2]=[]

static func motif() -> void:
	if not cuts.is_empty():return
	# Mirrored ram-horn curls and a short shared stem, drawn as an inlaid carving.
	for side in [-1.0,1.0]:
		var previous:=Vector2(0,.22)
		for i in 33:
			var t:=float(i)/32.0
			var angle:=PI*.52+t*TAU*1.12
			var radius:=.19*(1.0-t*.78)
			var point:=Vector2(side*(.12+cos(angle)*radius),-.06+sin(angle)*radius)
			cuts.append(previous);cuts.append(point);previous=point
	for pair in [[Vector2(0,.22),Vector2(-.06,.29)],[Vector2(-.06,.29),Vector2(0,.34)],[Vector2(0,.34),Vector2(.06,.29)],[Vector2(.06,.29),Vector2(0,.22)]]:
		cuts.append(pair[0]);cuts.append(pair[1])

static func groove_at(point:Vector2)->float:
	var nearest:=10.0
	for i in range(0,cuts.size(),2):
		var a:=cuts[i];var direction:=cuts[i+1]-a
		var t:=clampf((point-a).dot(direction)/maxf(.00001,direction.length_squared()),0,1)
		nearest=minf(nearest,point.distance_to(a+direction*t))
	return 1.0-smoothstep(.018,.034,nearest)

static func mesh()->ArrayMesh:
	if face_mesh!=null:return face_mesh
	motif()
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var positions:=PackedVector3Array();var values:=PackedFloat32Array()
	for z in 57:
		for x in 57:
			var point:=Vector2((float(x)/56.0-.5)*.88,(float(z)/56.0-.5)*.88)
			var inset:=point.clamp(Vector2(-.35,-.35),Vector2(.35,.35))
			if point.distance_to(inset)>.09:point=inset+(point-inset).normalized()*.09
			var cut:=groove_at(point)
			var edge:=maxf(absf(point.x),absf(point.y))/.44
			var height:=.235-pow(edge,6)*.065-cut*.027
			positions.append(Vector3(point.x,height,point.y));values.append(cut)
	for z in 56:
		for x in 56:
			for corner in [Vector2i(x,z),Vector2i(x+1,z),Vector2i(x+1,z+1),Vector2i(x,z),Vector2i(x+1,z+1),Vector2i(x,z+1)]:
				var index:int=corner.y*57+corner.x
				surface.set_color(Color(values[index],0,0,1));surface.add_vertex(positions[index])
	surface.index();surface.generate_normals();face_mesh=surface.commit();return face_mesh

static func build(arena,root:Node3D,index:int)->void:
	arena.mesh_node(root,arena.Masonry.block(Vector3(.91,.35,.91),index+31),Vector3(0,-.015,0),arena.stone_material(Color("796d62")))
	var mat:=ShaderMaterial.new();mat.shader=preload("res://shaders/carved_stone.gdshader")
	mat.set_shader_parameter("rock_map",preload("res://assets/stone-detail.png"))
	mat.set_shader_parameter("map_offset",Vector2(index*.37,index*.61))
	arena.mesh_node(root,mesh(),Vector3.ZERO,mat).name="Rune"
	for i in 2:
		var socket:=Vector3((i-.5)*.49,.192,.36)
		arena.sphere(root,socket,Vector3(.094,.024,.094),arena.material(Color("302a24")))
		var pip:StandardMaterial3D=arena.material(Color("594a34"));pip.emission_enabled=true;pip.emission_energy_multiplier=0
		arena.sphere(root,socket+Vector3(0,.009,0),Vector3(.048,.016,.048),pip).name="Charge%d"%i
