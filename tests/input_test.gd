extends SceneTree
const Main = preload("res://scripts/main.gd")
var game
var failures := 0
func _init() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value: failures += 1; push_error(message)
func key(code: int) -> void:
	var event := InputEventKey.new(); event.physical_keycode = code; event.keycode = code; event.pressed = true
	game._input(event)
func run() -> void:
	game = Main.new(); root.add_child(game)
	await process_frame
	game.start_local(2, 1)
	key(KEY_Q); check(game.sim.players[0].ability, "Q selects ability")
	key(KEY_SPACE); check(game.sim.players[0].ready, "Space confirms")
	key(KEY_BACKSPACE); check(not game.sim.players[0].ready, "Backspace unlocks")
	key(KEY_TAB); check(game.selected == 1, "Tab selects local ally")
	key(KEY_SPACE); check(game.sim.players[1].ready and not game.sim.players[0].ready, "Keyboard routes to selected slot")
	key(KEY_H); check(game.hud.help_open, "Help opens")
	key(KEY_ESCAPE); check(not game.hud.help_open and not game.in_menu, "Escape closes help before leaving game")
	game.sim.begin_reward(); key(KEY_1); check(game.sim.players[1].reward, "Reward selected by keyboard")
	key(KEY_TAB); key(KEY_2)
	for i in 250: game.sim.tick(1.0/120)
	check(game.sim.wave == 2, "All rewards advance wave")
	print("INPUT: keyboard, ready/cancel/reselect, help and reward flow; failures=", failures)
	game.set_process(false);game.arena.stop_audio();await create_timer(.2).timeout
	game.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	quit(1 if failures else 0)
