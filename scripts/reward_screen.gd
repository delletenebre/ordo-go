extends RefCounted
const Catalog = preload("res://scripts/catalog.gd")
const Wool = preload("res://assets/wool-detail.png")
const Caps = preload("res://assets/player-caps-v2.png")
var icons: Dictionary = {}

func prepare() -> void:
	for key in Catalog.BOONS:
		icons[key] = load("res://assets/boons/%s.png" % key)

func choice_rect(index: int) -> Rect2:
	return Rect2(245 + index * 380, 300, 350, 390)

func player_rect(index: int, count: int) -> Rect2:
	return Rect2(800 - count * 160 + index * 320, 772, 300, 113)

func backdrop(hud) -> void:
	hud.draw_texture_rect(Wool, Rect2(0, 0, 1600, 1000), false, Color("151b29"))
	hud.draw_rect(Rect2(0, 0, 1600, 1000), Color(0.01, 0.015, 0.03, 0.32))
	for y in [35, 965]:
		hud.draw_line(Vector2(40, y), Vector2(1560, y), Color("352c28"), 8, true)
		for x in range(45, 1555, 22):
			hud.draw_line(Vector2(x, y-2), Vector2(x+10, y+2), Color("97704a"), 3, true)

func fire_ring(hud, center: Vector2, radius: float, strength: float = 1.0) -> void:
	var pulse := 0.9 + 0.1 * sin(hud.clock * 4.3)
	hud.draw_texture_rect(hud.aim_halo, Rect2(center-Vector2.ONE*radius*1.5, Vector2.ONE*radius*3), false, Color(1, 0.27, 0.025, 0.4*strength))
	for layer in range(4, 0, -1):
		hud.draw_arc(center, radius, 0, TAU, 112, Color(1, 0.22+layer*0.05, 0.015, 0.07*strength*pulse), layer*7, true)
	hud.draw_arc(center, radius, 0, TAU, 112, Color(1, 0.53, 0.06, strength), 4.8, true)
	hud.draw_arc(center, radius-0.8, 0, TAU, 112, Color(1, 0.91, 0.47, strength), 1.8, true)
	for i in 24:
		var life := fposmod(hud.clock * 0.5 + i * 0.618, 1.0)
		var angle := i * 2.4 + sin(hud.clock*1.3+i)*0.04
		var point := center + Vector2.from_angle(angle) * (radius+3+life*30) + Vector2(0, -life*18)
		var opacity := sin(life*PI)*strength
		hud.draw_texture_rect(hud.aim_halo, Rect2(point-Vector2(8,8),Vector2(16,16)),false,Color(1,0.35,0.03,opacity*.5))
		hud.draw_circle(point, 1.3+sin(i)*0.5, Color(1,0.72,0.16,opacity))

func token(hud, id: int, center: Vector2, diameter: float) -> void:
	# Sample only the round authored puck, excluding the atlas cell corners.
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	var cell := Vector2(id%2,floori(id/2.0))
	for i in 64:
		var radial := Vector2.from_angle(TAU*i/64.0)
		points.append(center+radial*diameter*.415)
		uvs.append((cell+Vector2(.5,.5)+radial*.415)/2.0)
	hud.draw_polygon(points,PackedColorArray([Color.WHITE]),uvs,Caps)

func draw(hud) -> void:
	var game = hud.game
	var sim = game.sim
	backdrop(hud)
	hud.text_at("В О Л Н А  %02d  П Р О Й Д Е Н А" % sim.wave,Vector2(0,110),17,hud.gold,HORIZONTAL_ALIGNMENT_CENTER,1600)
	hud.text_at("ВПЛЕТИТЕ НОВУЮ НИТЬ",Vector2(0,177),42,hud.cream,HORIZONTAL_ALIGNMENT_CENTER,1600)
	hud.text_at("Выберите дар — и вы готовы к следующей волне",Vector2(0,220),21,Color("c3b299"),HORIZONTAL_ALIGNMENT_CENTER,1600)
	var player: Dictionary = sim.players[game.selected]
	var selected_choice := int(player.get("reward_choice",-1))
	var cursor := int(game.reward_choices.get(game.selected,maxi(0,selected_choice)))
	for i in sim.reward_options.size():
		var key: String = sim.reward_options[i]
		var boon: Dictionary = Catalog.BOONS[key]
		var rect := choice_rect(i)
		var center := Vector2(rect.get_center().x,449)
		var chosen: bool = selected_choice == i
		if chosen: fire_ring(hud,center,144)
		hud.draw_texture_rect(icons[key],Rect2(center-Vector2(160,160),Vector2(320,320)),false)
		if not chosen and cursor == i:
			hud.draw_arc(center,146,PI*.15,PI*.85,36,Color("bd9970"),2,true)
			hud.draw_circle(center+Vector2(0,145),3,hud.cream)
		hud.text_at(boon.name,Vector2(rect.position.x,641),26,hud.cream,HORIZONTAL_ALIGNMENT_CENTER,rect.size.x)
		var words := str(boon.text).split(" ")
		var line := ""
		var y := 674
		for word in words:
			if hud.font.get_string_size(line+word,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x > 325:
				hud.text_at(line,Vector2(rect.position.x,y),18,Color("c3b299"),HORIZONTAL_ALIGNMENT_CENTER,rect.size.x)
				y += 25; line = ""
			line += word + " "
		hud.text_at(line,Vector2(rect.position.x,y),18,Color("c3b299"),HORIZONTAL_ALIGNMENT_CENTER,rect.size.x)
		var owners: Array = []
		for p in sim.players:
			if int(p.get("reward_choice",-1)) == i: owners.append(int(p.id))
		for j in owners.size():
			var pos := center+Vector2((j-(owners.size()-1)*0.5)*42,-170)
			token(hud,owners[j],pos,43)
		hud.text_at(str(i+1),Vector2(center.x-15,612),14,hud.gold,HORIZONTAL_ALIGNMENT_CENTER,30)
	var ready := 0
	for p in sim.players:
		var id := int(p.id)
		var rect := player_rect(id,sim.players.size())
		var center := rect.position+Vector2(46,53)
		if p.reward: ready += 1; fire_ring(hud,center,28,0.65)
		token(hud,id,center,62)
		var label := "P%d · %s" % [id+1,Catalog.NAMES[id]]
		hud.text_at(label,rect.position+Vector2(86,38),16,Catalog.COLORS[id])
		var status := "ГОТОВ" if p.reward else "ВЫБИРАЕТ…"
		hud.text_at(status,rect.position+Vector2(86,65),17,hud.gold if p.reward else Color("938d85"))
		if id == game.selected:
			hud.text_at("ВАШ ВЫБОР",rect.position+Vector2(86,89),11,hud.cream)
	var status := "ГОТОВЫ  %d / %d" % [ready,sim.players.size()]
	if ready == sim.players.size(): status = "ВСЕ ГОТОВЫ · НОВАЯ ВОЛНА ЧЕРЕЗ %d" % maxi(1,ceili(sim.timer))
	hud.text_at(status,Vector2(0,753),18,hud.gold,HORIZONTAL_ALIGNMENT_CENTER,1600)
	hud.text_at("1 / 2 / 3 — выбрать   ·   ← → + A / OK — выбрать   ·   B / Backspace — отменить   ·   Tab — игрок",Vector2(0,927),16,Color("b3a48e"),HORIZONTAL_ALIGNMENT_CENTER,1600)
