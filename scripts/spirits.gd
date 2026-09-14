class_name OrdoSpirits
extends RefCounted
const TYPES = {
	"eagle": {"name":"Беркут", "turns":1, "tile":0, "color":"80baff", "text":"Первый сильный удар наносит +2 урона. Один бросок."},
	"shield": {"name":"Щит", "turns":2, "tile":1, "color":"edc56c", "text":"Блокирует следующий урон. До двух ходов."},
	"wind": {"name":"Ветер", "turns":2, "tile":2, "color":"87d7b0", "text":"Дальность броска +25%. Два хода."},
	"flame": {"name":"Пламя", "turns":1, "tile":3, "color":"ff9d69", "text":"Первый сильный удар вызывает взрыв радиусом 1,6. Один бросок."},
	"master": {"name":"Мастер", "turns":2, "tile":4, "color":"cc9de8", "text":"После каждого своего броска восстанавливает 1 здоровье очага. Два хода."},
	"lasso": {"name":"Аркан", "turns":1, "tile":5, "color":"86c7d0", "text":"Первый задетый враг пропускает ответную атаку. Один бросок."},
	"frost": {"name":"Мороз", "turns":2, "tile":6, "color":"b7e4ff", "text":"Задетые враги движутся на 45% медленнее. Два броска; холод — на одну атаку."},
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
		if item.kind=="spirit" and sim.turn>=int(item.expires):
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
		enemy.chill=1;sim.emit("ice",sim.pos(enemy),int(player.id),0.8,"frost")
	elif active(player,"flame"):
		player.spirit={};sim.emit("blast",sim.pos(enemy),3,1.6)
		for other in sim.enemies:
			var delta:Vector2=sim.pos(other)-sim.pos(enemy)
			if other.id!=enemy.id and delta.length()<1.6:
				sim.velocity(other,sim.vel(other)+delta.normalized()*4.0/sqrt(float(other.mass)))
				sim.hit_enemy(other,1,key+":spirit:%s"%other.id,sim.pos(other))
	return bonus

static func after_throw(sim) -> void:
	for p in sim.players:
		if int(p.hp)>0 and bool(p.ready) and active(p,"master") and sim.fire<sim.max_fire:
			sim.fire+=1;sim.emit("mend_thread",sim.pos(p),int(p.id),1.0,"master")
			sim.emit("heal",Vector2.ZERO,1,1.0,"+1")
