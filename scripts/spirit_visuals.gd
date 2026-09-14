@static_unload
class_name OrdoSpiritVisuals
extends Node3D
const Spirits = preload("res://scripts/spirits.gd")
const ATLAS = preload("res://assets/spirits-atlas.png")
const MagicAura = preload("res://scripts/magic_aura.gd")
const CURSE_COLORS = {"burn": Color("ff704c"), "frost": Color("84cfea"), "snare": Color("ba86e6"), "weak": Color("c071b2"), "ice": Color("84cfea")}
static var icons: Dictionary = {}
var patches: Dictionary = {}
var fields: Dictionary = {}
var time := 0.0

static func icon(kind: String) -> AtlasTexture:
	if icons.has(kind): return icons[kind]
	var index: int = Spirits.TYPES[kind].tile
	var cell := Vector2(ATLAS.get_width()/4.0,ATLAS.get_height()/2.0)
	var texture := AtlasTexture.new();texture.atlas=ATLAS
	texture.region=Rect2(Vector2(index%4,index/4)*cell,cell)
	texture.filter_clip=true;icons[kind]=texture;return texture

func step(sim, arena, dt: float) -> void:
	time+=dt
	var live: Dictionary={}
	for item in sim.pickups:
		if item.kind!="spirit":continue
		var key:=str(int(item.id));live[key]=true
		if not patches.has(key):
			var root:=Node3D.new();add_child(root)
			arena.cylinder(root,Vector3(0,0.055,0),0.33,0.08,arena.wool(Color("39373d")))
			var sprite:=Sprite3D.new();sprite.texture=icon(item.spirit);sprite.pixel_size=0.00180
			sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD;sprite.alpha_scissor_threshold=0.25
			sprite.rotation.x=-PI/2;sprite.position.y=0.105
			sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(sprite)
			var aura := MagicAura.new(); root.add_child(aura)
			aura.setup(Color(Spirits.TYPES[item.spirit].color), 0.36, false, float(item.id))
			patches[key]={"node":root,"sprite":sprite,"aura":aura,"age":0.0,"exit":false,"owner":-1,"item":item.duplicate(),"from":Vector3.ZERO}
		var patch:Dictionary=patches[key];patch.age+=dt
		patch.node.position=Vector3(float(item.x),0.08+sin(time*1.6+int(item.id))*0.035,float(item.z))
		patch.node.scale=Vector3.ONE*smoothstep(0.0,0.38,float(patch.age))
		patch.aura.step(time, smoothstep(0.0,0.38,float(patch.age)), arena.camera.global_basis)
	for key in patches.keys():
		var patch:Dictionary=patches[key]
		if live.has(key):continue
		if not patch.exit:
			patch.exit=true;patch.age=0.0;patch.from=patch.node.position
			for event in sim.events:
				if event.kind=="spirit_pickup" and event.text==patch.item.spirit and Vector2(float(event.x)-float(patch.item.x),float(event.z)-float(patch.item.z)).length()<0.02:
					patch.owner=int(event.color)
		patch.age+=dt
		var t:=clampf(float(patch.age)/0.65,0,1)
		var target:Vector3=patch.from+Vector3(0,0.5,0)
		if int(patch.owner)>=0 and int(patch.owner)<sim.players.size():
			var player:Dictionary=sim.players[int(patch.owner)]
			target=Vector3(float(player.x),0.95,float(player.z))
		patch.node.position=patch.from.lerp(target,smoothstep(0,1,t))+Vector3(0,sin(t*PI)*0.75,0)
		patch.node.scale=Vector3.ONE*lerpf(1.0,0.15,t*t)
		patch.sprite.modulate.a=1.0-smoothstep(0.7,1,t)
		patch.aura.step(time, 1.0-smoothstep(0.45,1.0,t), arena.camera.global_basis)
		if t>=1:patch.node.queue_free();patches.erase(key)
	step_fields(sim, arena, dt)

func field(key: String, point: Vector3, color: Color, radius: float, cursed: bool, strength: float) -> void:
	if not fields.has(key):
		var aura := MagicAura.new(); add_child(aura)
		aura.setup(color, radius, cursed, float(key.hash() % 1000))
		aura.strength = strength
		fields[key] = {"node": aura, "alpha": 0.0, "live": true}
	fields[key].live = true
	fields[key].node.position = point

func step_fields(sim, arena, dt: float) -> void:
	for value in fields.values(): value.live = false
	for item in sim.pickups:
		if item.kind == "spirit": continue
		var color := Color("ff91ae") if item.kind == "heart" else Color("ffd780")
		field("pickup:%s" % int(item.id), Vector3(float(item.x), 0.08, float(item.z)), color, 0.32, false, 1.0)
	for hazard in sim.hazards:
		field("hazard:%s" % int(hazard.id), Vector3(float(hazard.x), 0.065, float(hazard.z)), CURSE_COLORS.get(hazard.kind, Color("ba86e6")), float(hazard.r) * 0.90, true, 0.65)
	for player in sim.players:
		if int(player.hp) <= 0: continue
		var actor: Node3D = arena.actors.get(str(int(player.id)))
		var point := actor.position if actor != null else Vector3(float(player.x), 0.03, float(player.z))
		point.y += 0.06
		for status in player.statuses:
			field("status:%s:%s" % [int(player.id), status], point, CURSE_COLORS.get(status, Color("ba86e6")), 0.48, true, 0.70)
		var spirit: Dictionary = player.get("spirit", {})
		if not spirit.is_empty():
			field("active:%s:%s" % [int(player.id), spirit.kind], point, Color(Spirits.TYPES[spirit.kind].color), 0.47, false, 0.65)
		elif player.get("pending_spirit", "") != "" and not arriving(int(player.id)):
			field("pending:%s:%s" % [int(player.id), player.pending_spirit], point, Color(Spirits.TYPES[player.pending_spirit].color), 0.47, false, 0.4)
	for key in fields.keys():
		var value: Dictionary = fields[key]
		value.alpha = move_toward(float(value.alpha), 1.0 if value.live else 0.0, dt * 3.0)
		value.node.step(time, float(value.alpha), arena.camera.global_basis)
		if not value.live and float(value.alpha) <= 0.0:
			value.node.queue_free(); fields.erase(key)

func clear() -> void:
	for patch in patches.values():patch.node.queue_free()
	patches.clear()
	for value in fields.values(): value.node.queue_free()
	fields.clear()

func arriving(slot:int)->bool:
	for patch in patches.values():
		if patch.exit and int(patch.owner)==slot:return true
	return false
