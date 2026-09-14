class_name OrdoSmoke
extends Node3D
const CAPACITY := 384
var puffs: Array = []
var cursor := 0
var mesh := MultiMesh.new()
var rng := RandomNumberGenerator.new()
var emitted := 0
var dropped := 0

func _ready() -> void:
	rng.seed = 28372
	var quad := QuadMesh.new(); quad.size = Vector2.ONE
	mesh.transform_format = MultiMesh.TRANSFORM_3D
	mesh.use_colors = true; mesh.use_custom_data = true; mesh.mesh = quad
	mesh.instance_count = CAPACITY
	mesh.custom_aabb = AABB(Vector3(-10, -2, -10), Vector3(20, 14, 20))
	var material := ShaderMaterial.new(); material.shader = preload("res://shaders/smoke.gdshader")
	var cloud := MultiMeshInstance3D.new(); cloud.multimesh = mesh; cloud.material_override = material
	cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(cloud)
	for i in CAPACITY:
		puffs.append({"alive": false, "time": 0.0, "duration": 1.0, "p": Vector3.ZERO, "v": Vector3.ZERO, "size": 1.0, "spin": 0.0, "seed": 0.0})
		mesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO))

func emit_puff(p: Vector3, v: Vector3, diameter: float, duration: float, opacity: float = 0.30, tint: Color = Color("a7a1a5")) -> bool:
	var slot := -1
	for offset in CAPACITY:
		var candidate := (cursor + offset) % CAPACITY
		if not puffs[candidate].alive: slot = candidate; break
	if slot < 0: dropped += 1; return false
	cursor = (slot + 1) % CAPACITY; emitted += 1
	puffs[slot] = {"alive": true, "time": 0.0, "duration": duration, "p": p, "v": v, "size": diameter, "spin": rng.randf() * TAU, "seed": rng.randf() * 50.0}
	mesh.set_instance_color(slot, Color(tint, opacity))
	mesh.set_instance_custom_data(slot, Color(0.0, puffs[slot].seed, 0.0, 0.0))
	return true

func step(dt: float, camera_basis: Basis) -> void:
	for i in CAPACITY:
		var puff: Dictionary = puffs[i]
		if not puff.alive: continue
		puff.time += dt
		if float(puff.time) >= float(puff.duration):
			puff.alive = false
			mesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO))
			continue
		var age := float(puff.time) / float(puff.duration)
		puff.p += puff.v * dt; puff.v *= exp(-0.65 * dt); puff.v.y += dt * 0.10
		var diameter: float = float(puff.size) * lerpf(0.65, 1.75, age)
		var basis := camera_basis * Basis(Vector3.BACK, float(puff.spin) + age * 0.12)
		mesh.set_instance_transform(i, Transform3D(basis.scaled(Vector3.ONE * diameter), puff.p))
		mesh.set_instance_custom_data(i, Color(age, float(puff.seed), 0.0, 0.0))

func burst(p: Vector3, strength: float = 1.0) -> void:
	for i in 14:
		var a := rng.randf() * TAU
		var radial := Vector3(cos(a), 0, sin(a))
		emit_puff(p + radial * rng.randf_range(0.04, 0.22), radial * rng.randf_range(0.45, 1.2) + Vector3(0, rng.randf_range(0.22, 0.65), 0), rng.randf_range(0.45, 0.75) * strength, rng.randf_range(1.1, 1.85), 0.40, Color("a99f9e"))

func active_count() -> int:
	var count := 0
	for puff in puffs:
		if puff.alive: count += 1
	return count

func clear() -> void:
	for i in CAPACITY:
		puffs[i].alive = false
		mesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO))
