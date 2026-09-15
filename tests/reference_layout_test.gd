extends SceneTree
const Arena=preload("res://scripts/arena.gd")
const Sim=preload("res://scripts/simulation.gd")
const Rules=preload("res://scripts/runestones.gd")
var checks:=0
var failures:=0
func _init()->void:call_deferred("run")
func check(value:bool,message:String)->void:
	checks+=1
	if not value:failures+=1;push_error(message)
func run()->void:
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	var arena:=Arena.new();arena.muted=true;root.add_child(arena)
	var sim:=Sim.new();sim.start(4,1,77381)
	for viewport_size in [Vector2i(1540,1020),Vector2i(1920,1080),Vector2i(1000,760)]:
		root.content_scale_size=viewport_size;await process_frame;arena.frame_camera()
		for i in 75:arena.render_state(sim,1.0/60.0)
		var bounds:=arena.actor_frame_bounds(sim)
		var actual:=root.get_visible_rect().size
		check(Rect2(Vector2.ZERO,actual).encloses(bounds),"Live actor bounds stay inside %s: %s"%[viewport_size,bounds])
		for point in [Vector2.ZERO,Vector2(5.4,0),Vector2(-4.5,2),Vector2(0,5.5),Vector2(0,-5.5)]:
			check(arena.floor_point(arena.screen_point(point,0)).distance_to(point)<.001,"Aim round trip after camera fitting at %s"%viewport_size)
	# Rendered stones must follow authoritative snapshots, including restored layouts.
	sim.stones[0].x-=.25;sim.stones[0].z+=.15
	sim.stones[0].collector=true;sim.stones[0].souls=2;sim.stones[0].effect="guard"
	arena.render_state(sim,.016)
	check(Vector2(arena.rune_stones[0].position.x,arena.rune_stones[0].position.z).distance_to(sim.pos(sim.stones[0]))<.001,"Stone art follows authoritative collision position")
	check(float(arena.rune_stones[0].get_node("Rune").material_override.get_shader_parameter("rune_glow"))>1.0,"Charged stone lights its carved surface")
	check(Sim.RADIUS-Rules.PLACEMENT_RADIUS-Rules.BODY_RADIUS>float(sim.players[0].r)*2,"Outer lane still passes a complete player token")
	# Mouth transitions preserve distinct readable forms and blend between reactions.
	var face=arena.actors[str(int(sim.enemies[0].id))].get_node("Face")
	face.react("fear",1.0)
	for i in 20:face.step(1.0/60.0,Vector2.ZERO)
	check(face.mouth_size.y>.38,"Fear opens a round mouth")
	face.remaining=0;face.react("joy",1.0)
	var before:Vector2=face.mouth_size;face.step(1.0/60.0,Vector2.ZERO)
	check(face.mouth_size.distance_to(before)<.12,"Emotion changes blend rather than snap")
	for i in 30:face.step(1.0/60.0,Vector2.ZERO)
	check(face.mouth_curve<-.1 and face.mouth_size.x>.58,"Joy forms a wide curved smile")
	face.remaining=0;face.react("anger",1.0)
	for i in 30:face.step(1.0/60.0,Vector2.ZERO)
	check(face.mouth_curve>.06 and face.mouth_size.y<.15,"Anger forms a compressed frown")
	arena.queue_free();await process_frame
	print("REFERENCE LAYOUT: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
