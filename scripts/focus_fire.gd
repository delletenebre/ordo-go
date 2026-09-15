extends Control
const FireShader = preload("res://shaders/focus_fire.gdshader")
const PADDING := 52.0
const SPARK_LIMIT := 36
var body_size := Vector2(510,110)
var strength := 1.0
var elapsed := 0.0
var next_flare := 0.0
var flare_cursor := 0
var rng := RandomNumberGenerator.new()
var flares: Array[Dictionary] = []
var sparks: Array[Dictionary] = []
var surface: ColorRect
var fire_material: ShaderMaterial
var halo: GradientTexture2D

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	rng.randomize()
	fire_material=ShaderMaterial.new();fire_material.shader=FireShader
	fire_material.set_shader_parameter("seed",rng.randf_range(0,80))
	surface=ColorRect.new();surface.mouse_filter=Control.MOUSE_FILTER_IGNORE
	surface.material=fire_material;surface.color=Color.WHITE;add_child(surface)
	# One cached soft particle texture; no hard circles or rows of static dots.
	var gradient:=Gradient.new()
	gradient.offsets=PackedFloat32Array([0,.12,.35,1])
	gradient.colors=PackedColorArray([Color.WHITE,Color(1,1,1,.65),Color(1,1,1,.13),Color(1,1,1,0)])
	halo=GradientTexture2D.new();halo.gradient=gradient;halo.width=32;halo.height=32
	halo.fill=GradientTexture2D.FILL_RADIAL;halo.fill_from=Vector2(.5,.5);halo.fill_to=Vector2(1,.5)
	for i in 3:flares.append({"point":Vector2.ZERO,"age":2.0,"duration":1.0,"power":0.0})
	for i in SPARK_LIMIT:sparks.append({"age":10.0,"life":1.0,"point":Vector2.ZERO,"velocity":Vector2.ZERO,"width":1.0})
	configure(body_size,strength)

func configure(dimensions: Vector2, intensity: float = 1.0) -> void:
	body_size=dimensions;strength=intensity
	size=body_size+Vector2.ONE*PADDING*2.0
	if surface:
		surface.size=size
		fire_material.set_shader_parameter("body_size",body_size)
		fire_material.set_shader_parameter("strength",strength)

func rim_point() -> Vector2:
	var radius:=minf(body_size.x,body_size.y)*.5-2.0
	var straight:=maxf(0.0,body_size.x*.5-radius)
	var angle:=rng.randf_range(-PI,PI)
	var point:=Vector2(cos(angle),sin(angle))*radius
	if rng.randf()<.65 and straight>1.0:
		point=Vector2(rng.randf_range(-straight,straight),-radius if rng.randf()<.8 else radius)
	else:point.x+=straight*signf(point.x)
	return point

func ignite() -> void:
	var root:=rim_point()
	var flare:Dictionary=flares[flare_cursor];flare_cursor=(flare_cursor+1)%3
	flare.point=root;flare.age=0.0;flare.duration=rng.randf_range(.35,.85);flare.power=rng.randf_range(.6,1.7)
	var remaining:=rng.randi_range(1,3)
	for spark in sparks:
		if spark.age<spark.life:continue
		spark.age=0.0;spark.life=rng.randf_range(.3,.85);spark.point=root
		var outward:=Vector2(root.x/maxf(1,body_size.x*.5),root.y/maxf(1,body_size.y*.5)).normalized()
		spark.velocity=outward*rng.randf_range(12,35)+Vector2(rng.randf_range(-12,12),rng.randf_range(-44,-18))
		spark.width=rng.randf_range(.8,1.7)
		remaining-=1
		if remaining<=0:break

func _process(dt: float) -> void:
	if not is_visible_in_tree():return
	elapsed+=dt;next_flare-=dt
	if next_flare<=0:
		ignite();next_flare=rng.randf_range(.16,.7)
	for i in flares.size():
		var flare:Dictionary=flares[i];flare.age+=dt
		fire_material.set_shader_parameter(["flare_a","flare_b","flare_c"][i],Vector4(flare.point.x,flare.point.y,flare.age/flare.duration,flare.power))
	for spark in sparks:spark.age+=dt
	fire_material.set_shader_parameter("clock",elapsed)
	queue_redraw()

func _draw() -> void:
	var origin:=size*.5
	for spark in sparks:
		var age:float=spark.age
		if age>=spark.life:continue
		var fraction:float=age/spark.life
		var opacity:=smoothstep(0.0,.07,age)*(1.0-smoothstep(.3,1.0,fraction))*strength
		var at:Vector2=origin+spark.point+spark.velocity*age+Vector2(0,-14*age*age)
		var tail:Vector2=at-spark.velocity.normalized()*(2.0+fraction*3.0)
		draw_texture_rect(halo,Rect2(at-Vector2(8,8),Vector2(16,16)),false,Color(1,.3,.015,opacity*.55))
		draw_line(tail,at,Color(1,.57,.06,opacity*.65),spark.width*2.3,true)
		draw_line(tail.lerp(at,.55),at,Color(1,.91,.38,opacity),spark.width,true)
