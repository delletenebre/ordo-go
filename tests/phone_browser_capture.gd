extends SceneTree
const Main = preload("res://tests/support/test_main.gd")
var game
var elapsed := 0.0
var joined := -1.0
func _init() -> void:call_deferred("run")
func run() -> void:
	game=Main.new();game.auto_local_server=true;root.add_child(game)
	while game.controller_hub.net.room=="":await process_frame
	print("BROWSER_URL ",game.controller_hub.relay.browser_url)
func _process(dt: float) -> bool:
	elapsed+=dt
	if game!=null and game.phone_slots.size()>0:
		if joined<0:joined=elapsed;print("BROWSER_CONNECTED")
		if game.in_menu and elapsed-joined>3:game.play_connected()
		if not game.in_menu and game.sim.players[0].ready:print("BROWSER_SHOT_OK");finish()
	if elapsed>180:
		finish(1)
	return false

func finish(code: int = 0) -> void:
	set_process(false)
	if game!=null:game.arena.stop_audio();game.queue_free()
	await process_frame
	quit(code)
