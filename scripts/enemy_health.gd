extends RefCounted

# Screen-space embroidery: readable at small window sizes and attached to the
# rendered actor, including remote interpolation and jumps.
const LOSS_TIME := 0.48
var states: Dictionary = {}

func update(enemies: Array, actors: Dictionary, dt: float) -> void:
	var live: Dictionary = {}
	for enemy in enemies:
		var id := int(enemy.id)
		if int(enemy.hp) <= 0 or not actors.has(str(id)): continue
		live[id] = true
		var actor: Node3D = actors[str(id)]
		var maximum := maxi(1, int(enemy.max_hp))
		var hp := clampi(int(enemy.hp), 0, maximum)
		if not states.has(id) or states[id].actor != actor.get_instance_id() or states[id].maximum != maximum:
			states[id] = {"hp": hp, "previous": hp, "maximum": maximum,
				"age": LOSS_TIME, "actor": actor.get_instance_id()}
		var state: Dictionary = states[id]
		state.age = minf(LOSS_TIME, float(state.age) + maxf(0.0, dt))
		if hp < int(state.hp):
			state.previous = state.hp; state.age = 0.0
		elif hp > int(state.hp):
			state.previous = hp; state.age = LOSS_TIME
		state.hp = hp
	for id in states.keys():
		if not live.has(id): states.erase(id)

func draw_stitch(hud: Control, at: Vector2, width: float, unit: float, filled: bool, flash: float = 0.0) -> void:
	# A short raised thread with clipped ends, matching the rug's warm binding.
	var half := width*.5
	var shape := PackedVector2Array([
		at+Vector2(-half,0), at+Vector2(-half+unit,-3*unit),
		at+Vector2(half-unit,-3*unit), at+Vector2(half,0),
		at+Vector2(half-unit,3*unit), at+Vector2(-half+unit,3*unit)])
	var outline := shape.duplicate()
	outline.append(outline[0])
	hud.draw_polyline(outline, Color("22211e", .68), 1.8*unit, true)
	var fill := Color("e0c595") if filled else Color("534a3e")
	hud.draw_colored_polygon(shape, fill.lerp(Color("e5c899"), flash*.8))
	if filled:
		hud.draw_line(at+Vector2(-half+2*unit,-1.8*unit),at+Vector2(half-2*unit,-1.8*unit),Color("f5dfb7",.7),unit,true)

func draw_backing(hud: Control, at: Vector2, width: float, unit: float) -> void:
	var left := at-Vector2(width*.5,0)
	var right := at+Vector2(width*.5,0)
	# A continuous dark felt strip separates health from the busy rug pattern.
	var color := Color("211f1b",.94)
	hud.draw_line(left,right,color,11*unit,true)
	hud.draw_circle(left,5.5*unit,color,true,-1,true)
	hud.draw_circle(right,5.5*unit,color,true,-1,true)

func draw(hud: Control) -> void:
	var arena = hud.game.arena
	var pixel_scale := maxf(.01, hud.get_viewport().get_stretch_transform().get_scale().x)
	var unit := clampf(hud.size.x * pixel_scale / 1440.0, .95, 1.2) / pixel_scale
	# HUD's other artwork uses a 1600-unit canvas. Health keeps a pixel floor.
	hud.draw_set_transform(Vector2.ZERO)
	for enemy in hud.game.sim.enemies:
		var id := int(enemy.id)
		if not states.has(id) or not arena.actors.has(str(id)): continue
		var actor: Node3D = arena.actors[str(id)]
		var top := actor.global_position + Vector3(0, float(enemy.r)*(2.8 if int(enemy.max_hp)>5 else 2.4), 0)
		if arena.camera.is_position_behind(top): continue
		var at: Vector2 = arena.camera.unproject_position(top) - Vector2(0, 8*unit)
		var state: Dictionary = states[id]
		var hp := int(state.hp)
		var maximum := int(state.maximum)
		var loss := 1.0 - smoothstep(0.0, LOSS_TIME, float(state.age))
		if maximum <= 5:
			var stitch_width := 16.0 if maximum == 1 else 11.0
			draw_backing(hud,at,((maximum-1)*14+stitch_width-4)*unit,unit)
			for index in maximum:
				var point := at + Vector2((index-(maximum-1)*.5)*14*unit, 0)
				var lost := index >= hp and index < int(state.previous) and loss > 0.0
				# The glow cools into the spent thread without moving the row.
				draw_stitch(hud, point, stitch_width*unit, unit, index < hp, loss if lost else 0.0)
		else:
			var width := 68*unit
			var left := at + Vector2(-width*.5, 3*unit)
			draw_backing(hud,at+Vector2(0,3*unit),width,unit)
			var label := "%d / %d" % [hp, maximum]
			var label_width: float = hud.font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,roundi(13*unit)).x
			var baseline := at+Vector2(-label_width*.5,-7*unit)
			hud.draw_string_outline(hud.font, baseline, label, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(13*unit), 4, Color("181c1d"))
			hud.draw_string(hud.font, baseline, label, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(13*unit), Color("e0c595"))
			hud.draw_line(left, left+Vector2(width,0), Color("22211e",.68), 5*unit, true)
			hud.draw_line(left, left+Vector2(width,0), Color("534a3e"), 6*unit, true)
			hud.draw_line(left, left+Vector2(width*hp/maximum,0), Color("e0c595"), 6*unit, true)
			if loss > 0:
				hud.draw_line(left+Vector2(width*hp/maximum,0), left+Vector2(width*int(state.previous)/maximum,0), Color("e5c899",loss*.8), 6*unit, true)
			for stitch in 6:
				var point := left+Vector2(width*stitch/5.0,0)
				hud.draw_line(point-Vector2(0,3*unit),point+Vector2(0,3*unit),Color("252421",.9),unit,true)
	hud.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE*hud.scale_factor)
