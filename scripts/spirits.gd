class_name OrdoSpirits
extends RefCounted
const TYPES = {
	"eagle": {"name":"Беркут", "turns":1, "tile":0, "color":"80baff", "text":"Первый сильный удар наносит +2 урона. Один бросок."},
	"shield": {"name":"Баатыр", "turns":2, "tile":1, "color":"edc56c", "text":"Блокирует следующий урон. До двух ходов."},
	"wind": {"name":"Тулпар", "turns":2, "tile":2, "color":"87d7b0", "text":"Начальная скорость броска +25%. Два хода."},
	"flame": {"name":"Всполох", "turns":1, "tile":3, "color":"ff9d69", "text":"Первый сильный удар: взрыв, 1 урон врагам рядом (радиус 1,6). Один бросок."},
	"master": {"name":"Умай", "turns":2, "tile":4, "color":"cc9de8", "text":"Коснись очага — восстанови 1 здоровье. Любое касание, раз за ход. Два хода."},
	"lasso": {"name":"Аркан", "turns":1, "tile":5, "color":"86c7d0", "text":"Первый сильный удар лишает врага ответной атаки. Один бросок."},
	"frost": {"name":"Аяз", "turns":2, "tile":6, "color":"b7e4ff", "text":"Сильный удар замедляет врага и тушит огонь рядом. Два хода."},
}
static func active(player: Dictionary, kind: String) -> bool:
	return player.get("spirit",{}).get("kind","")==kind

static func begin_plan(sim) -> void:
	for p in sim.players:
		var spirit: Dictionary = p.get("spirit",{})
		if not spirit.is_empty():
			spirit.turns -= 1
			if int(spirit.turns)<=0: p.spirit={}
		var pending: String = p.get("pending_spirit","")
		if pending!="":
			p.spirit={"kind":pending,"turns":TYPES[pending].turns};p.pending_spirit=""
			sim.emit("spirit_active",sim.pos(p),int(p.id),1.0,pending)
	for item in sim.pickups:
		if item.kind=="spirit" and not item.get("boss_gift",false) and sim.turn>=int(item.expires):
			item.used=true;sim.emit("spirit_fade",sim.pos(item),-1,0.6,item.spirit)
	sim.pickups=sim.pickups.filter(func(item):return not item.get("used",false))
	if sim.turn%2!=1: return
	var existing:=0
	for item in sim.pickups:
		if item.kind=="spirit": existing+=1
	var cap:=1 if sim.players.size()==1 else 2
	var rng:=RandomNumberGenerator.new();rng.seed=sim.turn*731+sim.wave*937+sim.players.size()*17
	var keys:Array=TYPES.keys()
	for i in range(existing,cap):
		for attempt in 40:
			var angle:=rng.randf()*TAU;var point:=Vector2.from_angle(angle)*rng.randf_range(2.1,4.6)
			var free:=true
			for body in sim.players+sim.enemies+sim.stones+sim.pickups:
				if point.distance_to(sim.pos(body))<float(body.get("r",0.4))+0.65:free=false;break
			if not free:continue
			var kind:String=keys[rng.randi_range(0,keys.size()-1)]
			sim.entity_id+=1
			sim.pickups.append({"id":sim.entity_id,"kind":"spirit","spirit":kind,"x":point.x,"z":point.y,"expires":sim.turn+3,"born":sim.turn})
			sim.emit("spirit_spawn",point,-1,0.7,kind)
			break

static func collect(sim, player: Dictionary, item: Dictionary) -> bool:
	if item.get("boss_gift", false):
		# The guaranteed counter is usable on this throw, even with an active class.
		player.spirit={"kind":"frost", "turns":3}; player.pending_spirit=""; item.used=true
		sim.emit("spirit_pickup",sim.pos(item),int(player.id),.8,"frost")
		sim.emit("spirit_active",sim.pos(player),int(player.id),1.0,"frost")
		return true
	if not player.get("spirit",{}).is_empty() or player.get("pending_spirit","")!="":return false
	player.pending_spirit=item.spirit;item.used=true
	sim.emit("spirit_pickup",sim.pos(item),int(player.id),0.8,item.spirit)
	return true

static func hit(sim, player: Dictionary, enemy: Dictionary, key: String) -> int:
	var bonus:=0
	if active(player,"eagle"):
		bonus=2;player.spirit={};sim.emit("spirit_strike",sim.pos(enemy),int(player.id),1.0,"eagle")
	elif active(player,"lasso"):
		enemy.stun=maxi(int(enemy.stun),1);player.spirit={};sim.emit("snare",sim.pos(enemy),int(player.id),1.0,"lasso")
	elif active(player,"frost"):
		sim.Bosses.frost_strike(sim, sim.pos(enemy))
		enemy.chill=1;sim.emit("ice",sim.pos(enemy),int(player.id),0.8,"frost")
	elif active(player,"flame"):
		player.spirit={};sim.emit("blast",sim.pos(enemy),3,1.6)
		for other in sim.enemies:
			var delta:Vector2=sim.pos(other)-sim.pos(enemy)
			if other.id!=enemy.id and delta.length()<1.6:
				sim.velocity(other,sim.vel(other)+delta.normalized()*4.0/sqrt(float(other.mass)))
				sim.hit_enemy(other,1,key+":spirit:%s"%other.id,sim.pos(other))
	return bonus

static func touch_hearth(sim, player: Dictionary, contact: Vector2) -> void:
	if int(player.hp) <= 0 or not active(player, "master"): return
	if int(player.spirit.get("mended_turn", -1)) == sim.turn: return
	if sim.fire >= sim.max_fire or sim.fire <= 0: return
	player.spirit.mended_turn = sim.turn
	var before: int = sim.fire
	sim.fire += 1
	sim.emit("hearth_mend", contact, int(player.id), 1.0, "+1", {"fire_before": before, "fire_after": sim.fire})
