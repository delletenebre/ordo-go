class_name OrdoRunestones
extends RefCounted

const SOULS_PER_CHARGE := 2
const FLIGHT_TIME := 0.65
const SPEED_LIMIT := 24.0
const EFFECTS = {
	"surge":{"name":"Разгон ×2","color":"64daff","text":"Удваивает скорость одного рикошета."},
	"heal":{"name":"Живая нить","color":"7de3ae","text":"Восстанавливает одну жизнь раненому хранителю."},
	"guard":{"name":"Оберег","color":"ffd07d","text":"Один блок урона и дебаффа. До двух ходов."},
	"thorns":{"name":"Колючий панцирь","color":"dba4ee","text":"Устойчивость ×2,5 и один ответный урон за ход. Два хода."},
	"class":{"name":"Дар узора","color":"8fe9dd","text":"Выбрасывает временный класс в свободную точку поля."},
}
const ROLLS = ["surge","surge","surge","heal","guard","thorns","class","class"]

static func reset(sim) -> void:
	sim.soul_flights.clear();sim.rune_drops.clear();sim.rune_serial=0
	var rng:=RandomNumberGenerator.new();rng.seed=sim.rune_seed
	var first:=rng.randi_range(0,maxi(0,sim.stones.size()-1))
	for i in sim.stones.size():
		var stone:Dictionary=sim.stones[i]
		stone.id=i;stone.souls=0;stone.incoming=0;stone.effect=""
		stone.collector=(i==first or (sim.players.size()>1 and i==(first+2)%sim.stones.size()))

static func collect(sim, enemy: Dictionary, point: Vector2) -> void:
	var nearest:=INF;var target:Dictionary={}
	for stone in sim.stones:
		if not stone.get("collector",false):continue
		if int(stone.get("souls",0))+int(stone.get("incoming",0))>=SOULS_PER_CHARGE:continue
		var distance:float=point.distance_squared_to(sim.pos(stone))
		if distance<nearest:nearest=distance;target=stone
	if target.is_empty():return
	target.incoming=int(target.get("incoming",0))+1
	var flight:={"id":int(enemy.id),"stone":int(target.id),"x":point.x,"z":point.y,"height":float(enemy.r),"left":FLIGHT_TIME}
	sim.soul_flights.append(flight)
	sim.emit("soul_depart",point,-1,1.0,"",{"stone":int(target.id),"tx":float(target.x),"tz":float(target.z)})

static func advance(sim, dt: float) -> void:
	for flight in sim.soul_flights:
		flight.left=maxf(0,float(flight.left)-dt)
		if float(flight.left)>0:continue
		var index:=int(flight.stone)
		if index<0 or index>=sim.stones.size():continue
		var stone:Dictionary=sim.stones[index]
		stone.incoming=maxi(0,int(stone.get("incoming",0))-1)
		stone.souls=mini(SOULS_PER_CHARGE,int(stone.get("souls",0))+1)
		if int(stone.souls)==SOULS_PER_CHARGE:
			sim.rune_serial+=1
			var rng:=RandomNumberGenerator.new();rng.seed=sim.rune_seed+sim.rune_serial*7187+index*89
			stone.effect=ROLLS[rng.randi_range(0,ROLLS.size()-1)]
		sim.emit("rune_ready" if int(stone.souls)==SOULS_PER_CHARGE else "soul_arrive",sim.pos(stone),-1,1.0,str(stone.get("effect","")),{"stone":index})
	sim.soul_flights=sim.soul_flights.filter(func(flight):return float(flight.left)>0)

	for drop in sim.rune_drops:
		drop.left=maxf(0,float(drop.left)-dt)
		if float(drop.left)>0:continue
		sim.pickups.append({"id":int(drop.id),"kind":"spirit","spirit":drop.spirit,"x":float(drop.x),"z":float(drop.z),"expires":sim.turn+3,"born":sim.turn,"from_rune":true})
		sim.emit("spirit_spawn",sim.pos(drop),-1,.7,drop.spirit)
	sim.rune_drops=sim.rune_drops.filter(func(drop):return float(drop.left)>0)

static func expire(sim) -> void:
	for player in sim.players:
		if sim.turn>=int(player.get("rune_boon",{}).get("expires",0)):player.rune_boon={}

static func boon(player: Dictionary, kind: String) -> bool:
	return player.get("rune_boon",{}).get("kind","")==kind

static func mass(body: Dictionary, attacking: bool) -> float:
	return float(body.mass)*(2.5 if not attacking and boon(body,"thorns") else 1.0)

static func throw_class(sim, stone: Dictionary) -> bool:
	var existing:int=sim.rune_drops.size()
	for item in sim.pickups:
		if item.kind=="spirit" and not item.get("used",false):existing+=1
	if existing>=(1 if sim.players.size()==1 else 2):return false
	var rng:=RandomNumberGenerator.new();rng.seed=sim.rune_seed+sim.rune_serial*991+int(stone.id)*67
	for attempt in 50:
		var point:=Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(2.0,4.65)
		var free:=true
		for body in sim.players+sim.enemies+sim.stones+sim.pickups+sim.rune_drops:
			if point.distance_to(sim.pos(body))<float(body.get("r",.4))+.68:free=false;break
		if not free:continue
		var keys:Array=sim.Spirits.TYPES.keys()
		var kind:String=keys[rng.randi_range(0,keys.size()-1)]
		sim.entity_id+=1
		sim.rune_drops.append({"id":sim.entity_id,"spirit":kind,"x":point.x,"z":point.y,"sx":float(stone.x),"sz":float(stone.z),"left":FLIGHT_TIME})
		return true
	return false

static func charged(stone: Dictionary) -> bool:
	return bool(stone.get("collector",false)) and int(stone.get("souls",0))>=SOULS_PER_CHARGE

static func activate(sim, body: Dictionary, stone: Dictionary, reflected: Vector2, attacking: bool) -> Vector2:
	if not attacking or body.has("kind") or int(body.hp)<=0 or body.get("rune_used",false) or not charged(stone):return Vector2.ZERO
	if reflected.length()<1.4:return Vector2.ZERO
	var kind:String=stone.get("effect","surge")
	match kind:
		"heal":
			if int(body.hp)>=int(body.max_hp):return Vector2.ZERO
			body.hp=mini(int(body.max_hp),int(body.hp)+1)
			sim.emit("heal",sim.pos(body),int(body.id),1.0,"+1")
		"guard","thorns":
			if not body.get("rune_boon",{}).is_empty():return Vector2.ZERO
			body.rune_boon={"kind":kind,"expires":sim.turn+2,"retaliated":-1}
		"class":
			if not throw_class(sim,stone):return Vector2.ZERO
	stone.souls=0;stone.effect="";body.rune_used=true
	var result:Vector2=reflected*sim.STONE_BOUNCE
	if kind=="surge":result=reflected.normalized()*minf(reflected.length()*2.0,SPEED_LIMIT)
	sim.emit("rune_boost" if kind=="surge" else "rune_gift",sim.pos(stone),int(body.id),1.7,kind,{"stone":int(stone.id),"player":int(body.id),"vx":result.x,"vz":result.y})
	return result
