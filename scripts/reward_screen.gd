extends RefCounted
const Catalog = preload("res://scripts/catalog.gd")
const Wool = preload("res://assets/wool-detail.png")
const Caps = preload("res://assets/player-caps-v2.png")
const FocusFire = preload("res://scripts/focus_fire.gd")
var fires: Dictionary = {}
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

func begin_frame() -> void:
	for fire in fires.values():fire.hide()

func fire_ring(hud, center: Vector2, radius: float, strength: float = 1.0) -> void:
	var key := "%s:%s" % [center,radius]
	if not fires.has(key):
		var flame=FocusFire.new();hud.add_child(flame);fires[key]=flame
	var fire=fires[key]
	fire.configure(Vector2.ONE*radius*2,strength)
	fire.position=(center-Vector2.ONE*(radius+FocusFire.PADDING))*hud.scale_factor
	fire.scale=Vector2.ONE*hud.scale_factor
	fire.show()

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
		var active: bool = chosen or cursor == i
		var diameter := 320.0 if active else 256.0
		if active: fire_ring(hud,center,144,1.0 if chosen else .9)
		hud.draw_texture_rect(icons[key],Rect2(center-Vector2.ONE*diameter*0.5,Vector2.ONE*diameter),false)
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
	hud.text_at("1 / 2 / 3 — выбрать   ·   ← → + A / OK — выбрать   ·   B / Backspace — отменить",Vector2(0,927),16,Color("b3a48e"),HORIZONTAL_ALIGNMENT_CENTER,1600)
