class_name OrdoEnemyMotion
extends RefCounted

# Material response affects presentation, not damage, HP or authoritative masses.
const PROFILES={
	"coal":{"strain":.035,"settle":.22,"stride":1.10,"lift":.20,"rock":.08,"bounce":.18,"friction":.84},
	"stone":{"strain":.008,"settle":.30,"stride":.92,"lift":.10,"rock":.045,"bounce":.08,"friction":.94},
	"ceramic":{"strain":.012,"settle":.24,"stride":1.02,"lift":.15,"rock":.055,"bounce":.10,"friction":.87},
	"felt":{"strain":.12,"settle":.55,"stride":1.20,"lift":.16,"rock":.075,"bounce":.28,"friction":.92},
}
static func material_kind(kind:String)->String:
	return {"brute":"stone","ram":"stone","frost":"ceramic","weaver":"felt"}.get(kind,"coal")
static func profile(kind:String)->Dictionary:return PROFILES[material_kind(kind)]
static func jump_peak(kind:String)->float:return 1.10 if kind=="weaver" else 1.45
static func jump_height(entity:Dictionary)->float:
	var u:=clampf(float(entity.get("jump",0)),0,1)
	return 4.0*jump_peak(str(entity.get("kind","hopper")))*u*(1-u)
static func jump_velocity(entity:Dictionary)->float:
	var u:=clampf(float(entity.get("jump",0)),0,1)
	var duration:=1.70 if int(entity.get("chill",0))>0 else .95
	return 4.0*jump_peak(str(entity.get("kind","hopper")))*(1-2*u)/duration

# Exact critical damping; equivalent decay at 30, 60 and 120 presentation FPS.
static func spring(x:float,v:float,omega:float,dt:float)->Vector2:
	var c:=v+omega*x;var decay:=exp(-omega*dt)
	return Vector2((x+c*dt)*decay,(v-omega*c*dt)*decay)

static func foot_phase(distance:float,radius:float,profile_data:Dictionary,side_index:int)->Vector2:
	var stride:=radius*float(profile_data.stride)
	var u:=fposmod(distance/stride+float(side_index)*.5,1.0)
	# Planted stance traverses backwards at body speed; only the return arc lifts.
	if u<.62:return Vector2((.31-u)*stride,0)
	var swing:=(u-.62)/.38
	return Vector2(lerpf(-.31,.31,smoothstep(0,1,swing))*stride,sin(swing*PI)*radius*float(profile_data.lift))
