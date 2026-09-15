extends SceneTree
const Main = preload("res://tests/support/test_main.gd")

func _init() -> void: call_deferred("run")

func capture(game, label: String, frames: int = 12) -> void:
	for i in frames:
		game.arena.render_state(game.sim, 1.0/60.0)
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://work/enemy-health/"+label+".png")

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://work/enemy-health")
	root.size = Vector2i(1440, 960)
	var game = Main.new(); root.add_child(game); await process_frame
	game.start_local(2,1); game.set_process(false); game.arena.stop_audio()
	var sim = game.sim
	sim.enemies.clear(); sim.pickups.clear(); sim.events.clear()
	var kinds := ["coal", "hopper", "brute", "brute", "frost", "ram"]
	var points := [Vector2(-3.8,-2.4), Vector2(-1.8,-3.9), Vector2(2,-3.3), Vector2(4.1,-.7), Vector2(-3.6,1.5), Vector2(2.7,2.2)]
	for index in kinds.size():
		sim.spawn(kinds[index],0); sim.place(sim.enemies[-1],points[index])
	sim.enemies[3].hp = 1; sim.enemies[4].hp = 1; sim.enemies[5].hp = 8
	sim.begin_plan(); sim.events.clear()
	await capture(game,"wide",45)
	sim.hit_enemy(sim.enemies[2],1,"health-capture",sim.pos(sim.enemies[2]))
	await capture(game,"hit",3)
	await capture(game,"settled",40)
	root.size = Vector2i(820,1000)
	await capture(game,"narrow",20)
	game.queue_free(); await process_frame; quit()
