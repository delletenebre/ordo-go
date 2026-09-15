extends Node3D
## A small shared pool for cold breath and warm smoke, independent of the carriers.
const CAPACITY := 96
var slots: Array = []
var mesh := MultiMesh.new()
var cursor := 0
var emitted := 0
var dropped := 0

func _ready() -> void:
	mesh.transform_format=MultiMesh.TRANSFORM_3D; mesh.use_colors=true; mesh.use_custom_data=true
	var quad:=QuadMesh.new(); quad.size=Vector2.ONE
	mesh.mesh=quad; mesh.instance_count=CAPACITY
	mesh.custom_aabb=AABB(Vector3(-10,-2,-10),Vector3(20,12,20))
	var cloud:=MultiMeshInstance3D.new(); cloud.multimesh=mesh
	var mat:=ShaderMaterial.new(); mat.shader=preload("res://shaders/smoke.gdshader")
	cloud.material_override=mat; cloud.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cloud)
	for i in CAPACITY:
		slots.append({"age":2.0,"life":1.0,"p":Vector3.ZERO,"v":Vector3.ZERO,"size":.3,"cold":false})
		mesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO),Vector3.ZERO))

func emit_wisp(point: Vector3, velocity: Vector3, size: float, cold: bool, strength: float) -> void:
	for offset in CAPACITY:
		var i: int=(cursor+offset)%CAPACITY
		var slot: Dictionary=slots[i]
		if float(slot.age)<float(slot.life): continue
		cursor=(i+1)%CAPACITY; emitted+=1
		slot.age=0.0; slot.life=1.55 if cold else 1.15; slot.p=point; slot.v=velocity; slot.size=size; slot.cold=cold
		mesh.set_instance_color(i,Color(Color("d8edf1") if cold else Color("b6a18a"),strength*(.27 if cold else .15)))
		return
	dropped+=1

func step(dt: float, camera_basis: Basis) -> void:
	for i in CAPACITY:
		var slot: Dictionary=slots[i]
		if float(slot.age)>=float(slot.life): continue
		slot.age+=dt
		if float(slot.age)>=float(slot.life):
			mesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO),Vector3.ZERO)); continue
		var age: float=slot.age/slot.life
		slot.p+=Vector3(slot.v)*dt
		slot.v*=exp(-dt*.45)
		var size: float=slot.size*lerpf(.60,1.70,age)
		var aspect:=Vector3(1.6,.65,1.0) if slot.cold else Vector3(.9,1.25,1.0)
		mesh.set_instance_transform(i,Transform3D(camera_basis.scaled(aspect*size),slot.p))
		mesh.set_instance_custom_data(i,Color(age,float(i)*3.71,0,0))

func active_count() -> int:
	var count:=0
	for slot in slots:
		if float(slot.age)<float(slot.life): count+=1
	return count

func clear() -> void:
	for i in CAPACITY:
		slots[i].age=slots[i].life
		mesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO),Vector3.ZERO))
