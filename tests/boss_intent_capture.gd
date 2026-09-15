extends SceneTree
const Main=preload("res://tests/support/test_main.gd")
var game
func _init()->void:call_deferred("run")
func run()->void:
	DirAccess.make_dir_recursive_absolute("res://work/enemy-motion")
	var narrow:="--narrow" in OS.get_cmdline_user_args()
	root.content_scale_size=Vector2i(820,1000) if narrow else Vector2i(1440,960)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	game=Main.new();root.add_child(game);await process_frame
	game.start_local(2,1);game.set_process(false);game.arena.muted=true
	var sim=game.sim;sim.enemies.clear();sim.pickups.clear();sim.events.clear()
	sim.wave=6;sim.spawn("weaver",0)
	var boss:Dictionary=sim.enemies[0];sim.place(boss,Vector2(2.8,-1.0))
	sim.place(sim.players[0],Vector2(2.9,2.0));sim.place(sim.players[1],Vector2(-3.0,2.0))
	for point in [Vector2(-2.5,-2.8),Vector2(4.3,.4),Vector2(-4.3,1.1)]:
		sim.spawn("coal",0);sim.place(sim.enemies[-1],point)
	sim.begin_plan();sim.events.clear();game.arena.last_event=sim.event_id
	var output:="res://work/enemy-motion"
	var frames:="/tmp/ordo-boss-frames"
	if narrow:frames+="-narrow"
	DirAccess.make_dir_recursive_absolute(frames)
	RenderingServer.render_loop_enabled=false
	for frame in (190 if narrow else 510):
		if frame==190:sim.hit_enemy(boss,int(boss.hp)-int(boss.phase_hp),"ignite",sim.pos(boss))
		if frame==252:sim.begin_plan()
		if frame==410:
			var player:Dictionary=sim.players[0]
			player.spirit={"kind":"frost","turns":2}
			sim.place(player,sim.pos(boss)+Vector2(.95,.75));sim.Bosses.ignite(sim,player)
			sim.player_hit(player,boss,"douse");sim.phase_time=3.0
		sim.phase_time+=1.0/60
		sim.Runestones.advance(sim,1.0/60)
		game.arena.render_state(sim,1.0/60);game.hud.clock+=1.0/60;game.hud.queue_redraw()
		await process_frame;RenderingServer.force_draw(true,1.0/60)
		root.get_texture().get_image().save_jpg(frames+"/%05d.jpg"%frame,.93)
		if frame in [60,175,222,312,408,465]:
			root.get_texture().get_image().save_png(output+"/boss-%s%03d.png"%["narrow-" if narrow else "",frame])
	game.queue_free();await process_frame;print("BOSS INTENT CAPTURE COMPLETE");quit()
