extends SceneTree
const Health = preload("res://scripts/enemy_health.gd")
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)

func _init() -> void:
	var display = Health.new()
	var actor := Node3D.new()
	var actors := {"11": actor}
	var enemies: Array = [{"id":11,"hp":3,"max_hp":3}]
	display.update(enemies,actors,.016)
	check(display.states[11].age == Health.LOSS_TIME,"First snapshot has no fake damage flash")
	enemies[0].hp = 1
	display.update(enemies,actors,.016)
	check(display.states[11].hp == 1 and display.states[11].previous == 3,"Multi-point damage shows actual remaining health immediately")
	check(display.states[11].age == 0.0,"Damage starts the loss animation")
	# Network JSON uses floating point numbers; repeated snapshots must not
	# retrigger the flash or reset its elapsed time.
	enemies = JSON.parse_string(JSON.stringify(enemies))
	display.update(enemies,actors,.6)
	check(display.states.size() == 1 and display.states[11].age == Health.LOSS_TIME,"Repeated remote snapshot settles under the same entity id")
	enemies[0].hp = 0
	display.update(enemies,actors,.016)
	check(display.states.is_empty(),"Death hides health while the body may still be dissolving")
	enemies[0].hp = 3
	display.update(enemies,actors,.016)
	enemies[0].hp = 2
	display.update(enemies,actors,.016)
	var replacement := Node3D.new(); actors["11"] = replacement
	display.update(enemies,actors,.016)
	check(display.states[11].age == Health.LOSS_TIME,"Reused id in a new match does not inherit damage animation")
	display.update([],actors,.016)
	check(display.states.is_empty(),"Removed enemies release display state")
	actor.free(); replacement.free()
	print("ENEMY HEALTH: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
