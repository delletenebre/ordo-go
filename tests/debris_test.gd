extends SceneTree
const Debris=preload("res://scripts/coal_debris.gd")
var checks:=0
var failures:=0
func _init()->void:call_deferred("run")
func check(value:bool,message:String)->void:
	checks+=1
	if not value:failures+=1;push_error(message)
func run()->void:
	var debris:=Debris.new();root.add_child(debris)
	var event:={"id":1,"x":0.0,"z":3.0,"strength":.68,"radius":.34,"vx":9.0,"vz":0.0,"damage":3}
	var count:=debris.shatter(event,3)
	check(count==12 and debris.active_count()==12,"Heavy death creates a bounded group of chunks")
	var first:Dictionary=debris.pieces[0]
	var start:Vector3=first.body.position
	check(first.body.linear_velocity.x>0 and first.body.angular_velocity.length()>0,"Chunks carry impact momentum and spin")
	for i in 50:await physics_frame
	check(first.body.position.distance_to(start)>.2,"Chunks move under actual rigid-body physics")
	for i in 80:await physics_frame
	check(first.body.position.y>-.10,"Chunks bounce or settle on the arena floor")
	for i in 12:event.id+=1;debris.shatter(event,3)
	var old:Vector3=first.body.position
	check(debris.active_count()==debris.CAPACITY and debris.dropped>0,"Pool saturates without allocating more bodies")
	debris.shatter(event,3)
	check(first.body.position==old,"Saturation never teleports a live fragment")
	debris.step(3.0)
	check(debris.active_count()==0 and first.body.freeze,"Fragments retire and freeze after settling")
	debris.shatter(event);debris.clear()
	check(debris.active_count()==0,"Restart clears physical debris")
	debris.queue_free();await process_frame
	print("DEBRIS: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
