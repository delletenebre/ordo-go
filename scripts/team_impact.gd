class_name OrdoTeamImpact
extends RefCounted
const WINDOW := 0.22
const MIN_SPEED := 4.5

static func record(sim,player:Dictionary,enemy:Dictionary,player_speed:float,closing_speed:float) -> int:
	if player_speed<MIN_SPEED or closing_speed<MIN_SPEED:return 0
	var key:=str(int(enemy.id));var slot:=str(int(player.id))
	var cluster:Dictionary=sim.team_contacts.get(key,{"hits":{},"count":1})
	var now:float=sim.phase_time
	for previous in cluster.hits.keys():
		if now-float(cluster.hits[previous])>WINDOW:cluster.hits.erase(previous)
	cluster.hits[slot]=now
	var count:int=cluster.hits.size()
	sim.team_contacts[key]=cluster
	if count<2 or count<=int(cluster.count):return 0
	cluster.count=count
	var slots:Array=[]
	for id in cluster.hits:slots.append(int(id))
	sim.emit("team_clash",sim.pos(enemy),int(player.id),float(count),"ТЫДЫЩ!",{"target":int(enemy.id),"participants":slots,"multiplier":count})
	# Same-step lethal hits still strengthen the already queued physical fracture.
	for event in sim.events:
		if event.kind=="death" and int(event.get("target",-1))==int(enemy.id):event.team_size=count
	return 1 if count<=3 else 0
