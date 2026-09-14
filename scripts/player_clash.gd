class_name OrdoPlayerClash
extends RefCounted
const MIN_SPEED := 5.5
const HEAVY_SPEED := 9.0
const FACING_DOT := 0.70710678 # At most 45 degrees away from opposing headings.
const SPEED_LIMIT := 24.0

static func eligible(a: Dictionary,b: Dictionary,va:Vector2,vb:Vector2,normal:Vector2) -> bool:
	if a.has("kind") or b.has("kind") or int(a.hp)<=0 or int(b.hp)<=0:return false
	if a.get("clash_used",false) or b.get("clash_used",false):return false
	if va.length()<MIN_SPEED or vb.length()<MIN_SPEED:return false
	var da:=va.normalized();var db:=vb.normalized()
	return da.dot(-db)>=FACING_DOT and da.dot(normal)>=FACING_DOT and db.dot(-normal)>=FACING_DOT

static func resolve(sim,a:Dictionary,b:Dictionary,normal:Vector2) -> bool:
	var va:Vector2=sim.vel(a);var vb:Vector2=sim.vel(b)
	if not eligible(a,b,va,vb,normal):return false
	var multiplier:=3 if minf(va.length(),vb.length())>=HEAVY_SPEED else 2
	var rng:=RandomNumberGenerator.new()
	rng.seed=sim.rune_seed+sim.turn*4099+mini(int(a.id),int(b.id))*131+maxi(int(a.id),int(b.id))*719
	# Separate outward cones preserve a readable split and prevent immediate re-collision.
	var first:=(-normal).rotated(rng.randf_range(-PI*.24,PI*.24))
	var second:=normal.rotated(rng.randf_range(-PI*.24,PI*.24))
	var first_speed:=minf(va.length()*multiplier,SPEED_LIMIT)
	var second_speed:=minf(vb.length()*multiplier,SPEED_LIMIT)
	sim.velocity(a,first*first_speed);sim.velocity(b,second*second_speed)
	a.clash_used=true;b.clash_used=true
	var center:Vector2=(sim.pos(a)+sim.pos(b))*.5
	sim.emit("clash",center,-1,float(multiplier),"ТЫДЫЩ!",{"a":int(a.id),"b":int(b.id),"avx":first.x*first_speed,"avz":first.y*first_speed,"bvx":second.x*second_speed,"bvz":second.y*second_speed,"multiplier":multiplier})
	return true
