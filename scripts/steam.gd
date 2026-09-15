extends "res://scripts/smoke.gd"
## Separate pooled white vapor: contact jets, rolling cloud, buoyant wisps.
var bursts: Array = []

func _ready() -> void:
	super._ready()
	get_child(0).material_override.shader = preload("res://shaders/steam.gdshader")
	rng.seed = 38107

func quench(event: Dictionary) -> void:
	var p := Vector3(float(event.x), .4, float(event.z))
	var axis := Vector3(float(event.get("nx", 1)), 0, float(event.get("nz", 0))).normalized()
	bursts.append({"p":p, "axis":axis, "age":0.0, "cloud":false, "wisps":false})
	for i in 10:
		var side := -1.0 if i % 2 == 0 else 1.0
		var along := axis * side
		emit_puff(p + along*.035, along*rng.randf_range(.7,1.5)+Vector3.UP*rng.randf_range(.3,.65), rng.randf_range(.28,.42), .45, .36, Color("ffdba3") if side < 0 else Color("c5eeff"))

func step(dt: float, camera_basis: Basis) -> void:
	for burst in bursts:
		burst.age += dt
		if not burst.cloud and float(burst.age) >= .065:
			burst.cloud = true
			for i in 16:
				var a := i*2.39996
				var radial := Vector3(cos(a),0,sin(a))
				emit_puff(burst.p + radial*.09, radial*rng.randf_range(.32,.75)+Vector3.UP*rng.randf_range(.45,.95), rng.randf_range(.52,.82), rng.randf_range(1.05,1.6), .27, Color("d8e7ed"))
		if not burst.wisps and float(burst.age) >= .24:
			burst.wisps = true
			for i in 7:
				var side := sin(i*2.39996)
				emit_puff(burst.p+Vector3(side*.15,.18,cos(i)*.12), burst.axis*side*.25+Vector3.UP*rng.randf_range(.75,1.2), rng.randf_range(.45,.7), 1.7, .18, Color("edf4f6"))
	bursts = bursts.filter(func(burst): return float(burst.age) < .3)
	super.step(dt, camera_basis)

func clear() -> void:
	bursts.clear()
	super.clear()
