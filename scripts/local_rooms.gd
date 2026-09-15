extends RefCounted
const Avatars = preload("res://scripts/avatar_catalog.gd")
const RoomCode = preload("res://scripts/room_code.gd")
signal outgoing(peer: int, message: Dictionary)
var peers: Dictionary = {}
var rooms: Dictionary = {}

func add_peer(id: int) -> void:
	peers[id] = {"room":"", "slots":[], "avatars":[]}

func send(id: int, data: Dictionary) -> void: outgoing.emit(id, data)
func fail(id: int, message: String) -> void: send(id, {"type":"error", "message":message})
func broadcast(room: Dictionary, data: Dictionary, exclude: int = -1) -> void:
	for id in room.peers:
		if id != exclude: send(id, data)

func roster(room: Dictionary) -> void:
	var players: Array = []
	for id in room.peers:
		var peer: Dictionary = peers[id]
		for i in peer.slots.size():
			players.append({"slot":peer.slots[i], "avatar":peer.avatars[i], "name":Avatars.title(peer.avatars[i]), "owner":str(id), "host":id==room.host})
	broadcast(room, {"type":"roster", "code":room.code, "started":room.started, "players":players})

func leave(id: int) -> void:
	if not peers.has(id): return
	var code: String = peers[id].room
	peers[id].room = ""
	if not rooms.has(code): return
	var room: Dictionary = rooms[code]
	if room.host == id or room.started:
		broadcast(room, {"type":"ended", "message":"Участник отключился. Соберите общую игру заново."}, id)
		for other in room.peers: peers[other].room = ""
		rooms.erase(code)
	else:
		room.peers.erase(id); roster(room)

func remove_peer(id: int) -> void:
	leave(id); peers.erase(id)

static func integer(value) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value))
static func number(value) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func free_slots(room: Dictionary, exclude: int = -1) -> Array:
	var used: Array = []
	for id in room.peers:
		if id != exclude: used.append_array(peers[id].slots)
	return [0,1,2,3].filter(func(slot): return not used.has(slot))

func avatars(data: Dictionary, count: int, previous: Array = []) -> Array:
	var result: Array = []
	var supplied: Array = data.get("avatars",[]) if data.get("avatars",[]) is Array else []
	for i in count:
		var avatar = supplied[i] if i < supplied.size() else (data.get("avatar",Avatars.IDS[i]) if i==0 else Avatars.IDS[i])
		if i>=supplied.size() and i<previous.size() and not data.has("avatar"): avatar=previous[i]
		result.append(avatar if Avatars.IDS.has(avatar) else Avatars.IDS[i])
	return result

func allocate_code(controller: bool) -> String:
	var capacity := 10000 if controller else 1000000
	var start := randi_range(0,capacity-1)
	for i in mini(rooms.size()+1,capacity):
		var code := ("%04d" if controller else "%06d") % ((start+i)%capacity)
		if not rooms.has(code): return code
	return ""

func receive(id: int, data: Dictionary) -> void:
	if not peers.has(id): return
	var peer: Dictionary = peers[id]
	var kind = data.get("type","")
	if kind == "leave": leave(id); return
	if kind in ["create","join"]:
		if peer.room != "": fail(id,"Вы уже подключены."); return
		var count = data.get("count",1)
		if not integer(count) or count<0 or count>4: fail(id,"Нужно от 0 до 4 игроков."); return
		var room: Dictionary
		if kind == "create":
			if rooms.size()>=16: fail(id,"Сервер заполнен."); return
			var hub: bool = data.get("controllerHub",false)==true
			# One persistent controller room belongs to this TV.
			if hub and rooms.values().any(func(r):return r.controllerHub): fail(id,"Контроллеры уже подключаются к этому ТВ."); return
			var code := allocate_code(hub)
			if code=="": fail(id,"Сервер заполнен."); return
			room={"code":code,"host":id,"peers":[],"started":false,"controllerHub":hub,"playing":false}
			rooms[code]=room
		else:
			var code: String = RoomCode.normalize(str(data.get("code","")))
			if data.get("controller",false)==true:
				for candidate in rooms.values():
					if candidate.controllerHub: code=candidate.code; break
			elif not RoomCode.valid(code): fail(id,"Код комнаты: шесть цифр, например 482731."); return
			if not rooms.has(code): fail(id,"ТВ пока не готов к подключению."); return
			room=rooms[code]
			if room.started or room.playing: fail(id,"Идёт матч. Подключитесь перед следующим."); return
		var available := free_slots(room)
		if available.size()<int(count): fail(id,"Все четыре места уже заняты."); return
		peer.room=room.code;peer.slots=available.slice(0,int(count));peer.avatars=avatars(data,int(count));room.peers.append(id)
		send(id,{"type":"joined","id":str(id),"code":room.code,"slots":peer.slots,"host":room.host==id})
		roster(room);return
	if not rooms.has(peer.room): fail(id,"Сначала подключитесь к ТВ."); return
	var room: Dictionary = rooms[peer.room]
	match kind:
		"seats":
			if room.started: fail(id,"Состав игры уже зафиксирован."); return
			var count = data.get("count",-1)
			if not integer(count) or count<0 or count>4: return
			var available := free_slots(room,id)
			if available.size()<int(count): send(id,{"type":"seats_rejected","slots":peer.slots,"message":"Все четыре места уже заняты."}); return
			var retained: Array = peer.slots.slice(0,int(count))
			for slot in available:
				if retained.size()<int(count) and not retained.has(slot): retained.append(slot)
			peer.slots=retained;peer.avatars=avatars(data,int(count),peer.avatars)
			send(id,{"type":"slots","slots":peer.slots});roster(room)
		"avatar":
			if room.started or room.playing: fail(id,"Сменить аватар можно перед матчем."); return
			var index: int = peer.slots.find(int(data.slot)) if integer(data.get("slot")) else -1
			if index<0 or not Avatars.IDS.has(data.get("avatar","")): fail(id,"Это не ваш аватар."); return
			peer.avatars[index]=data.avatar;roster(room)
		"controller_status":
			if id!=room.host or not room.controllerHub or not data.get("playing") is bool: return
			room.playing=data.playing
			if not room.playing: broadcast(room,{"type":"controller_wait"},id);roster(room)
		"start":
			if id!=room.host or room.started or room.controllerHub: fail(id,"Начать игру может ведущий."); return
			var count := 0
			for other in room.peers: count+=peers[other].slots.size()
			if count==0: fail(id,"Сначала подключите игроков."); return
			var slot := 0
			for other in room.peers:
				for i in peers[other].slots.size(): peers[other].slots[i]=slot;slot+=1
				send(other,{"type":"slots","slots":peers[other].slots})
			room.started=true;roster(room)
			var difficulty = data.get("difficulty",1)
			broadcast(room,{"type":"start","count":count,"difficulty":clampi(int(difficulty),0,2) if integer(difficulty) else 1})
		"snapshot":
			if id==room.host and (room.started or room.controllerHub) and data.get("state") is Dictionary:
				broadcast(room,{"type":"snapshot","state":data.state},id)
		"command":
			if not (room.started or (room.controllerHub and room.playing)) or not integer(data.get("slot")) or not peer.slots.has(int(data.slot)):
				fail(id,"Эта фишка принадлежит другому игроку.");return
			var command = data.get("data")
			if not command is Dictionary or not integer(command.get("turn")): return
			var action = command.get("action","")
			if action not in ["aim","ready","cancel","ability","reward","reward_focus"]: return
			var safe := {"action":action,"turn":int(command.turn)}
			if action=="aim":
				if not number(command.get("angle")) or not number(command.get("power")): return
				if command.has("spin") and not number(command.spin): return
				safe.angle=command.angle;safe.power=clampf(float(command.power),.15,1.0)
				if command.has("spin"): safe.spin=clampf(float(command.spin),-1.0,1.0)
			if action in ["reward","reward_focus"]:
				if not integer(command.get("choice")) or command.choice<0 or command.choice>2:return
				safe.choice=int(command.choice)
			send(room.host,{"type":"command","slot":int(data.slot),"data":safe})
