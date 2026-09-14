class_name OrdoHud
extends Control
const Spirits = preload("res://scripts/spirits.gd")
const SpiritVisuals = preload("res://scripts/spirit_visuals.gd")
const AimPreview = preload("res://scripts/aim_preview.gd")
const Catalog = preload("res://scripts/catalog.gd")
var game
var font: Font = ThemeDB.fallback_font
var cream := Color("f6e8cc")
var muted := Color("a5b1c1")
var gold := Color("e9b865")
var fade := Color(0.035, 0.045, 0.069, 0.9)
var clock := 0.0
var pulse_events: Array = []
var seen := 0
var trails: Dictionary = {}
var menu: Control
var local_count: OptionButton
var difficulty: OptionButton
var url_field: LineEdit
var code_field: LineEdit
var message_label: Label
var start_button: Button
var connect_button: Button
var join_button: Button
var local_button: Button
var options_root: VBoxContainer
var room_label: Label
var help_open := false
var reward_choice := 0
var scale_factor := 1.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	build_menu()

func style(color: Color = Color("182633"), border: Color = Color("80715c")) -> StyleBoxFlat:
	var s := StyleBoxFlat.new(); s.bg_color = color; s.border_color = border
	s.set_border_width_all(2); s.set_corner_radius_all(14)
	s.content_margin_left = 18; s.content_margin_right = 18; s.content_margin_top = 12; s.content_margin_bottom = 12
	return s

func button(text_value: String, parent: Node, callback: Callable) -> Button:
	var b := Button.new(); b.text = text_value; b.custom_minimum_size = Vector2(0, 52)
	b.add_theme_font_size_override("font_size", 19); b.add_theme_color_override("font_color", cream)
	b.add_theme_stylebox_override("normal", style()); b.add_theme_stylebox_override("hover", style(Color("263b47"), gold))
	b.add_theme_stylebox_override("focus", style(Color(0, 0, 0, 0), gold)); b.add_theme_stylebox_override("pressed", style(Color("354957"), cream))
	b.pressed.connect(func():game.arena.sound("ui");callback.call())
	b.focus_entered.connect(func():game.arena.sound("ui"))
	parent.add_child(b); return b

func label_node(text_value: String, parent: Node, size_value: int = 17, color: Color = Color("c5c9cd")) -> Label:
	var l := Label.new(); l.text = text_value; l.add_theme_font_size_override("font_size", size_value)
	l.add_theme_color_override("font_color", color); parent.add_child(l); return l

func build_menu() -> void:
	menu = Control.new(); add_child(menu); menu.position = Vector2(92, 370); menu.size = Vector2(440, 600)
	options_root = VBoxContainer.new(); options_root.size = Vector2(420, 580); options_root.add_theme_constant_override("separation", 12); menu.add_child(options_root)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 12); options_root.add_child(row)
	local_count = OptionButton.new(); local_count.custom_minimum_size = Vector2(203, 46)
	for i in 4: local_count.add_item("%d игрок%s здесь" % [i + 1, "" if i == 0 else "а"])
	row.add_child(local_count)
	difficulty = OptionButton.new(); difficulty.custom_minimum_size = Vector2(203, 46)
	for name_value in ["Уютная ночь", "Испытание", "Буря"]: difficulty.add_item(name_value)
	difficulty.selected = 1; row.add_child(difficulty)
	for option in [local_count, difficulty]:
		option.add_theme_font_size_override("font_size", 17); option.add_theme_stylebox_override("normal", style())
	local_button = button("ИГРАТЬ НА ЭТОМ ЭКРАНЕ", options_root, func(): game.start_local(local_count.selected + 1, difficulty.selected))
	label_node("ИГРА С ДРУЗЬЯМИ НА ДРУГИХ ТВ", options_root, 13, gold)
	url_field = LineEdit.new(); url_field.placeholder_text = "wss://ваш-сервер"; url_field.text = game.relay_url
	url_field.custom_minimum_size = Vector2(0, 43); url_field.add_theme_stylebox_override("normal", style()); options_root.add_child(url_field)
	var net_row := HBoxContainer.new(); net_row.add_theme_constant_override("separation", 10); options_root.add_child(net_row)
	connect_button = button("Создать комнату", net_row, func(): connect_room(true)); connect_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code_field = LineEdit.new(); code_field.placeholder_text = "КОД"; code_field.max_length = 6; code_field.custom_minimum_size = Vector2(105, 50)
	code_field.add_theme_stylebox_override("normal", style()); net_row.add_child(code_field)
	join_button = button("Войти", net_row, func(): connect_room(false))
	room_label = label_node("", options_root, 19, gold)
	message_label = label_node("", options_root, 14, muted); message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; message_label.custom_minimum_size.x = 410
	start_button = button("НАЧАТЬ ОБЩИЙ МАТЧ", options_root, func(): game.net.send({"type": "start", "difficulty": difficulty.selected})); start_button.hide()
	var hint := label_node("Enter / A — выбрать    ·    F11 — полный экран\nОдин геймпад на игрока · телефон вместо геймпада", options_root, 14, muted)
	hint.add_theme_constant_override("line_spacing", 6)
	local_button.grab_focus()

func connect_room(create: bool) -> void:
	if not create and code_field.text.strip_edges().length() != 6:
		message_label.text = "Введите шестизначный код комнаты."; return
	game.relay_url = url_field.text.strip_edges(); game.save_settings()
	message_label.text = "Соединяемся…"
	game.net.connect_room(game.relay_url, code_field.text, local_count.selected + 1, create)

func update_lobby() -> void:
	room_label.text = "КОМНАТА  %s  ·  %d / 4" % [game.net.room, game.net.roster.size()]
	message_label.text = "Передайте код другу. Телефон: откройте адрес сервера в браузере." if game.net.is_host else "Вы в комнате. Ведущий скоро начнёт игру."
	start_button.visible = game.net.is_host
	if game.net.is_host: start_button.grab_focus()

func text_at(value: String, p: Vector2, size_value: int = 20, color: Color = Color("f6e8cc"), align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	draw_string(font, p, value, align, width, size_value, color)

func panel(rect: Rect2, color: Color = Color(0.025, 0.039, 0.058, 0.87), edge: Color = Color("5b5c60")) -> void:
	var s := style(color, edge); draw_style_box(s, rect)

func project(p: Vector2, height: float = 0.1) -> Vector2:
	return game.arena.screen_point(p, height) / scale_factor

func world_ring(center: Vector2, radius: float, color: Color, width: float = 2.0, fill: bool = false) -> void:
	var points := PackedVector2Array()
	for i in 65:
		var a := TAU * i / 64.0
		points.append(project(center + Vector2(cos(a), sin(a)) * radius))
	if fill: draw_colored_polygon(points, Color(color, color.a * 0.10))
	draw_polyline(points, color, width, true)

func arrow(a: Vector2, b: Vector2, color: Color, width: float = 2.0, dotted: bool = false) -> void:
	var length := a.distance_to(b)
	if length < 8: return
	var direction := (b-a)/length
	var tip_size := 11.0 + width
	var stem_end := b-direction*tip_size*0.65
	var under := Color(0.018,0.027,0.043,color.a*0.85)
	if dotted:
		var distance := 0.0
		while distance < length-tip_size:
			var start := a+direction*distance; var end := a+direction*minf(distance+8,length-tip_size)
			draw_line(start,end,Color(color,color.a*0.10),width+10,true);draw_line(start,end,under,width+3,true);draw_line(start,end,color,width,true)
			draw_line(start,end,Color(cream,color.a*0.85),maxf(1,width*.34),true)
			distance += 15
	else:
		draw_line(a,stem_end,under,width+4,true); draw_line(a,stem_end,Color(color,color.a*0.14),width+10,true)
		draw_line(a,stem_end,color,width,true)
	var back := b-direction*tip_size
	var points := PackedVector2Array([b,back+direction.orthogonal()*tip_size*0.48,back+direction*tip_size*0.20,back-direction.orthogonal()*tip_size*0.48])
	draw_colored_polygon(points,color)
	points.append(b); draw_polyline(points,under,1.5,true)

func draw_aim(player: Dictionary, selected_player: bool) -> void:
	var color: Color = Catalog.COLORS[int(player.id)]
	var center := Vector2(float(player.x),float(player.z)); var direction := Vector2.from_angle(float(player.angle))
	var start := center+direction*(float(player.r)+0.15)
	if not selected_player:
		arrow(project(start,0.17),project(start+direction*0.8,0.17),Color(color,0.58),2)
		return
	var preview := AimPreview.trace(game.sim,player)
	var points: PackedVector2Array = preview.points
	for i in range(1,points.size()):
		var from := start if i == 1 else points[i-1]
		if i > 1 and (points[i]-from).normalized().dot(direction) < -0.95: continue
		# A nearby obstacle may leave no visible stem. Keep its impact marker.
		if (points[i]-from).dot((points[i]-points[i-1]).normalized()) > 0.05:
			arrow(project(from,0.17),project(points[i],0.17),Color(color,0.95 if i == 1 else 0.63),4.2 if i == 1 else 2.5,true)
		if i < points.size()-1:
			var joint := project(points[i],0.17)
			draw_circle(joint,6,Color("111c29"));draw_circle(joint,3,color)
	var endpoint: Vector2 = points[-1]
	world_ring(endpoint,float(player.r),Color(color,0.38),1.5)
	var marker := project(endpoint,0.18)
	if preview.kind in ["enemy","ally"]:
		draw_arc(marker,9,0,TAU,32,color,2,true)
		for i in 4:
			var ray := Vector2.from_angle(i*PI/2+PI/4)
			draw_line(marker+ray*12,marker+ray*17,color,2,true)
	# Power is readable next to the moving token without hiding its emblem.
	var anchor := project(center,0.65)+Vector2(0,25)
	draw_line(anchor-Vector2(18,0),anchor+Vector2(18,0),Color("142334"),5,true)
	draw_line(anchor-Vector2(18,0),anchor+Vector2(-18+36*float(player.power),0),color,3,true)

func _process(dt: float) -> void:
	if game == null: return
	clock += dt
	for trail in trails.values():
		for point in trail: point.life -= dt
	for key in trails.keys(): trails[key] = trails[key].filter(func(p): return p.life > 0)
	if not game.in_menu:
		for player in game.sim.players:
			var key := int(player.id)
			if not trails.has(key): trails[key] = []
			if Vector2(float(player.vx), float(player.vz)).length() > 1.2 and game.arena.actors.has(str(key)):
				var body: Node3D = game.arena.actors[str(key)]
				var location := Vector2(body.position.x, body.position.z)
				if trails[key].is_empty() or location.distance_to(trails[key][-1].p) > 0.035:
					trails[key].append({"p": location, "life": 0.32})
					if trails[key].size() > 28: trails[key].pop_front()
	scale_factor = size.x / 1600.0
	menu.scale = Vector2.ONE * scale_factor; menu.position = Vector2(92, 350) * scale_factor
	menu.visible = game.in_menu
	for e in game.sim.events:
		if int(e.id) > seen:
			seen = int(e.id); pulse_events.append({"event": e, "life": 0.0})
	for e in pulse_events: e.life += dt
	pulse_events = pulse_events.filter(func(e): return e.life < 1.2)
	queue_redraw()

func _draw() -> void:
	if game == null: return
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE * scale_factor)
	var sim = game.sim
	if game.in_menu:
		var veil := Rect2(0, 0, 570, 1000); draw_rect(veil, Color(0.018, 0.029, 0.047, 0.94))
		text_at("В О Й Л О Ч Н Ы Е   Л Е Г Е Н Д Ы", Vector2(95, 105), 16, gold)
		text_at("ORDO", Vector2(84, 248), 112, cream)
		text_at("Х Р А Н И Т Е Л И   О Ч А Г А", Vector2(96, 287), 20, gold)
		text_at("Один огонь. Четыре хранителя. Общая история.", Vector2(96, 323), 17, muted)
		text_at("Тёплая шерсть. Холодная ночь.", Vector2(950, 930), 18, cream)
		text_at("Защитите последний огонь перевала.", Vector2(950, 959), 17, muted)
		return
	for key in trails.keys():
		var trail: Array = trails[key]
		for i in range(1, trail.size()):
			var a: Vector2 = project(trail[i - 1].p, 0.17); var b: Vector2 = project(trail[i].p, 0.17)
			if a.distance_to(b) > 100: continue
			var opacity: float = float(trail[i].life) / 0.32
			draw_line(a, b, Color(Catalog.COLORS[key], opacity * 0.16), 12 * opacity, true)
			draw_line(a, b, Color(Catalog.COLORS[key], opacity * 0.8), 4 * opacity, true)
			draw_line(a, b, Color(cream, opacity * 0.65), 1.6 * opacity, true)
	# The tabletop remains the primary surface; all HUD elements sit near its perimeter.
	panel(Rect2(555,12,490,82),Color(0.02,0.03,0.047,0.86),Color("424753"))
	panel(Rect2(1210,16,358,80),Color(0.02,0.03,0.047,0.82),Color("424753"))
	text_at("ORDO", Vector2(35, 54), 32, cream)
	text_at("ХРАНИТЕЛИ ОЧАГА", Vector2(36, 80), 11, gold)
	for i in 9:
		var c := gold if i < sim.wave else Color("44505e")
		var p := Vector2(636 + i * 39, 34)
		if i in [2, 5, 8]:
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -7), p + Vector2(7, 0), p + Vector2(0, 7), p + Vector2(-7, 0)]), c)
		else: draw_circle(p, 4, c)
	text_at("%02d / 09   ·   %s" % [sim.wave, Catalog.WAVE_NAMES[maxi(0, mini(8, sim.wave - 1))]], Vector2(525, 76), 20, cream, HORIZONTAL_ALIGNMENT_CENTER, 550)
	var phase_name: String = {"plan": "ПЛАНИРОВАНИЕ", "resolve": "БРОСОК", "enemy": "ХОД ПРОТИВНИКА", "clear": "ОЧАГ ЗАЩИЩЁН", "reward": "НОВАЯ НИТЬ", "win": "РАССВЕТ", "lose": "ОГОНЬ ПОГАС"}.get(sim.phase, "")
	text_at(phase_name, Vector2(1200, 47), 15, gold, HORIZONTAL_ALIGNMENT_RIGHT, 355)
	text_at("%02d" % ceili(sim.timer) if sim.phase == "plan" else "ХОД %d" % sim.turn, Vector2(1325, 82), 25, cream, HORIZONTAL_ALIGNMENT_RIGHT, 230)
	for i in sim.players.size():
		var p: Dictionary = sim.players[i]; var c: Color = Catalog.COLORS[i]; var y: float = 158.0 + i * 102.0
		var badge:=Vector2(62,y)
		draw_circle(badge,31,Color(c,0.08))
		draw_circle(badge,27,Color(0.015,0.035,0.048,0.91))
		draw_arc(badge,27,0,TAU,64,Color(c,1.0 if game.selected==i else 0.72),3.5,true)
		text_at(Catalog.SYMBOLS[i],badge+Vector2(-17,11),33,c)
		for hp in int(p.max_hp):
			draw_circle(Vector2(110+hp*minf(18.0,82.0/maxf(1,float(p.max_hp)-1)),y-3),5,c if hp<int(p.hp) else Color("35424f"))
		text_at("P%d · %s"%[i+1,"ГОТОВ" if p.ready else Catalog.NAMES[i]],Vector2(109,y-23),11,c)
		text_at("✦ %d"%int(p.charges),Vector2(109,y+22),13,gold)
		var statuses: Array = []
		for status in p.statuses.keys(): statuses.append({"frost": "ХОЛОД", "snare": "НИТИ", "weak": "СЛАБОСТЬ", "burn": "ГОРЕНИЕ"}[status])
		text_at(" · ".join(statuses), Vector2(109, y + 39), 10, Color("a9cee5"))
		if p.hp > 0:
			var center := Vector2(float(p.x), float(p.z))
			if i == game.selected: world_ring(center, 0.6, Color(c, 0.75), 2)
			if p.statuses.has("frost"): world_ring(center, 0.68, Color("abdfef"), 3, true)
			if p.statuses.has("snare"): world_ring(center, 0.53, Color("cab7df"), 3)
			if p.shield > 0: world_ring(center, 1.9 if i == 1 else 0.62, Color(gold, 0.6), 3, true)
			if sim.phase == "plan":
				draw_aim(p,i==game.selected)
				if p.ready: text_at("✓",project(center,0.8)+Vector2(-10,-14),27,c)
			draw_spirit_badge(p,center)
	if sim.phase in ["plan","enemy"]:
		for e in sim.enemies:
			if int(e.stun)>0 or (sim.phase=="enemy" and bool(e.fired)): continue
			var p := Vector2(float(e.x),float(e.z)); var target := Vector2(float(e.tx),float(e.tz))
			var direction := (target-p).normalized()
			var danger := Color(1.0,0.51,0.33,0.46)
			if e.attack=="rush":
				# Display only the start of a rush, keeping the arena uncluttered.
				var end := p+direction*minf(1.45,p.distance_to(target))
				arrow(project(p+direction*(float(e.r)+0.12)),project(end),danger,1.5,true)
			elif e.attack=="ring":
				var radius := 2.4 if sim.turn%2==0 else 4.5
				world_ring(Vector2.ZERO,radius-0.8,Color(danger,0.27),1.5)
				world_ring(Vector2.ZERO,radius+0.8,Color(danger,0.27),1.5)
				world_ring(Vector2.ZERO,radius,danger,2.5)
			else:
				var radius := 1.4 if e.attack=="slam" else (1.1 if e.attack=="frost" else (1.6 if e.kind=="weaver" else 1.05))
				world_ring(p if e.attack=="slam" else target,radius,danger,2,true)

	for e in sim.enemies:
		var p := Vector2(float(e.x), float(e.z)); var screen := project(p, float(e.r) * 2.4)
		if e.max_hp > 5:
			panel(Rect2(1160, 132, 390, 65), Color(0.04, 0.035, 0.05, 0.9), Color("9d6970"))
			text_at(Catalog.ENEMIES[e.kind].name, Vector2(1180, 159), 16, cream)
			draw_rect(Rect2(1180, 174, 347, 5), Color("3a343f"))
			draw_rect(Rect2(1180, 174, 347.0 * float(e.hp) / float(e.max_hp), 5), Color("e89c86"))
		else:
			for hp in int(e.max_hp): draw_circle(screen + Vector2((hp - (int(e.max_hp) - 1) * 0.5) * 10, -8), 3, gold if hp < e.hp else Color("41434b"))
	for h in sim.hazards: world_ring(Vector2(float(h.x), float(h.z)), float(h.r), Color(0.55, 0.8, 0.95, 0.55), 2, true)
	for item in sim.pickups:
		if item.kind=="spirit":
			var point:=Vector2(float(item.x),float(item.z));var anchor:=project(point,0.2)
			for pip in maxi(0,int(item.expires)-sim.turn):draw_circle(anchor+Vector2(-8+pip*8,23),2.4,gold)
			if (get_local_mouse_position()/scale_factor).distance_to(anchor)<27:
				text_at(Spirits.TYPES[item.spirit].name,anchor+Vector2(-70,-30),16,cream,HORIZONTAL_ALIGNMENT_CENTER,140)
			continue
		var p := project(Vector2(float(item.x), float(item.z)), 0.3)
		draw_circle(p, 15, Color(0.02, 0.09, 0.09, 0.8))
		text_at("+" if item.kind == "heart" else "✦", p + Vector2(-8, 8), 24, Color("92e2bc"))
	var core := project(Vector2.ZERO, 2.85)
	panel(Rect2(core.x - 86, core.y - 22, 172, 37), Color(0.06, 0.047, 0.04, 0.92), Color("796448"))
	for hp in sim.max_fire:
		var x: float = core.x - (sim.max_fire - 1) * 8 + hp * 16
		draw_circle(Vector2(x, core.y - 4), 5, gold if hp < sim.fire else Color("514638"))
	for event in pulse_events:
		var e: Dictionary = event.event; var t: float = event.life
		var point := Vector2(float(e.x), float(e.z)); var c := Color(gold, maxf(0, 1 - t))
		if int(e.color) >= 0: c = Color(Catalog.COLORS[int(e.color)], maxf(0, 1 - t))
		if e.kind=="impact" and t<0.25:
			var burst:=project(point,0.4);var alpha:=pow(1-t/0.25,1.5)
			for ray_index in 8:
				var ray:=Vector2.from_angle(ray_index*TAU/8)
				var extent:float=(35 if ray_index%2==0 else 21)*(0.7+t*3)
				draw_line(burst+ray*4,burst+ray*extent,Color(gold,alpha*.14),8,true)
				draw_line(burst+ray*4,burst+ray*extent,Color("fff3cb",alpha),2.1,true)
		if e.kind in ["impact", "blast", "shield", "ice", "death", "clear"]: world_ring(point, 0.2 + t * float(e.strength) * 1.5, c, 3 * maxf(0.1, 1 - t))
		if e.kind in ["damage","hurt","heal","fire_hurt"]:
			var strong:=float(e.strength)>=3.0
			var base_size:=43.0 if strong else 33.0
			var pop:=1.0+0.32*exp(-t*13.0)*sin(t*22.0)
			var size_value:=int(base_size*pop)
			var alpha:=1.0-smoothstep(0.72,1.2,t)
			var tint:=Color("fff2ca") if e.kind=="damage" else (Color("8fffc1") if e.kind=="heal" else Color("ff8585"))
			if strong:tint=Color("ffbd64")
			var origin:=project(point,1.0)+Vector2(-12+posmod(int(e.id),3)*7,-15-t*63)
			draw_string_outline(font,origin,e.text,HORIZONTAL_ALIGNMENT_LEFT,-1,size_value,6,Color(0.035,0.023,0.032,alpha))
			draw_string(font,origin,e.text,HORIZONTAL_ALIGNMENT_LEFT,-1,size_value,Color(tint,alpha))
		if e.kind=="mend_thread":
			var from:=project(point,0.6);var to:=project(Vector2.ZERO,0.7);var flight:=from.lerp(to,smoothstep(0,0.7,t))+Vector2(0,-sin(clampf(t/.7,0,1)*PI)*55)
			if t<0.7:draw_circle(flight,5,Color("d8b6ff"))
	if game.arena.combo_hits>=2 and game.arena.clock-game.arena.combo_last<1.0:
		var message:="КОМБО ×%d"%game.arena.combo_hits
		var opacity:=1.0-smoothstep(0.6,1.0,game.arena.clock-game.arena.combo_last)
		draw_string_outline(font,Vector2(660,153),message,HORIZONTAL_ALIGNMENT_CENTER,280,26,5,Color(0.05,0.025,0.04,opacity))
		draw_string(font,Vector2(660,153),message,HORIZONTAL_ALIGNMENT_CENTER,280,26,Color(gold,opacity))
	panel(Rect2(310, 896, 980, 78), Color(0.025, 0.04, 0.057, 0.95), Color("52606a"))
	if game.selected < sim.players.size():
		var selected: Dictionary = sim.players[game.selected]
		text_at("P%d  %s" % [game.selected + 1, Catalog.NAMES[game.selected]], Vector2(337, 928), 17, Catalog.COLORS[game.selected])
		text_at("СИЛА", Vector2(535, 926), 12, muted)
		draw_rect(Rect2(588, 913, 140, 9), Color("33414e")); draw_rect(Rect2(588, 913, 140 * float(selected.power), 9), Catalog.COLORS[game.selected])
		text_at("%s  %s" % ["✦" if selected.ability else "Q", Catalog.ABILITIES[game.selected]], Vector2(771, 928), 18, gold if selected.ability else cream)
	text_at("WASD / стик — прицел    ↑↓ / курок — сила    Space / A — готов    Q / X — умение    Tab — игрок    H — правила", Vector2(337, 955), 14, muted)
	if game.online: text_at("КОМНАТА  " + game.net.room, Vector2(1320, 955), 13, gold)
	if sim.phase == "reward": draw_reward()
	if sim.phase in ["win", "lose"]: draw_end()
	if help_open: draw_help()

func draw_spirit_badge(player: Dictionary, center: Vector2) -> void:
	var spirit: Dictionary=player.get("spirit",{})
	var kind: String=player.get("pending_spirit","") if spirit.is_empty() else spirit.kind
	if kind=="":return
	if spirit.is_empty() and game.arena.spirit_visuals.arriving(int(player.id)):return
	var anchor:=project(center,1.02)+Vector2(22,-8)
	draw_texture_rect(SpiritVisuals.icon(kind),Rect2(anchor-Vector2(20,20),Vector2(40,40)),false,Color(1,1,1,0.65 if spirit.is_empty() else 1.0))
	if spirit.is_empty():
		text_at("+",anchor+Vector2(15,17),14,gold)
	else:
		for pip in int(spirit.turns):draw_circle(anchor+Vector2(-4+pip*8,22),2.5,gold)
	if int(player.id)==game.selected:
		var description: String=Spirits.TYPES[kind].name+" · "+("следующий ход" if spirit.is_empty() else str(int(spirit.turns))+" ход.")
		panel(Rect2(1170,790,380,67),Color(0.025,0.04,0.057,0.93),Color("857053"))
		draw_texture_rect(SpiritVisuals.icon(kind),Rect2(1180,801,46,46),false)
		text_at(description,Vector2(1238,817),15,gold)
		text_at("H — описание духов узора",Vector2(1238,839),12,muted)

func draw_reward() -> void:
	draw_rect(Rect2(0, 110, 1600, 890), Color(0.025, 0.035, 0.055, 0.86))
	text_at("ВПЛЕТИТЕ НОВУЮ НИТЬ", Vector2(0, 295), 38, cream, HORIZONTAL_ALIGNMENT_CENTER, 1600)
	text_at("Каждый хранитель выбирает улучшение до конца партии", Vector2(0, 336), 18, muted, HORIZONTAL_ALIGNMENT_CENTER, 1600)
	for i in game.sim.reward_options.size():
		var boon: Dictionary = Catalog.BOONS[game.sim.reward_options[i]]
		var x: float = 290 + i * 350
		panel(Rect2(x, 395, 320, 240), Color("172431"), gold if reward_choice == i else Color("5b6470"))
		text_at(["◇", "✦", "❖"][i], Vector2(x, 468), 48, gold, HORIZONTAL_ALIGNMENT_CENTER, 320)
		text_at(boon.name, Vector2(x + 20, 520), 23, cream)
		var words := str(boon.text).split(" "); var line := ""; var y := 556
		for word in words:
			if (line + word).length() > 29: text_at(line, Vector2(x + 20, y), 16, muted); y += 24; line = ""
			line += word + " "
		text_at(line, Vector2(x + 20, y), 16, muted)
	text_at("P%d: клавиши 1 / 2 / 3 · геймпад: ← → и A · Tab — другой местный игрок" % [game.selected + 1], Vector2(0, 709), 18, gold, HORIZONTAL_ALIGNMENT_CENTER, 1600)
	var ready := 0
	for p in game.sim.players:
		if p.reward: ready += 1
	text_at("ВЫБРАЛИ  %d / %d" % [ready, game.sim.players.size()], Vector2(0, 760), 17, cream, HORIZONTAL_ALIGNMENT_CENTER, 1600)

func draw_end() -> void:
	draw_rect(Rect2(0, 110, 1600, 890), Color(0.02, 0.035, 0.05, 0.87))
	text_at("РАССВЕТ НАД ПЕРЕВАЛОМ" if game.sim.phase == "win" else "ПОСЛЕДНЯЯ ИСКРА", Vector2(0, 422), 48, cream, HORIZONTAL_ALIGNMENT_CENTER, 1600)
	text_at("Вы сохранили огонь. Эта история останется в узоре." if game.sim.phase == "win" else game.sim.last_reason, Vector2(0, 475), 22, muted, HORIZONTAL_ALIGNMENT_CENTER, 1600)
	text_at("ВОЛНА %d  ·  ПОБЕЖДЕНО %d  ·  ХОДОВ %d" % [game.sim.wave, game.sim.kills, game.sim.turn], Vector2(0, 540), 20, gold, HORIZONTAL_ALIGNMENT_CENTER, 1600)
	text_at("Enter / A — вернуться к очагу", Vector2(0, 626), 23, cream, HORIZONTAL_ALIGNMENT_CENTER, 1600)

func draw_help() -> void:
	draw_rect(Rect2(0,110,1600,890),Color(0.025,0.04,0.06,0.97))
	text_at("ХРАНИТЕЛИ ОЧАГА",Vector2(100,178),30,cream)
	var rules:=["Выберите направление и силу. Q / X — способность.","Space / A — готовность. B / Backspace — отмена.","Готовые фишки летят одновременно, остальные защищаются.","Сильный удар ранит врага. Оранжевые метки — его намерения.","Коснитесь погасшего союзника при броске, чтобы поднять его.","Tab — смена игрока. M — звук. F11 — весь экран."]
	for i in rules.size():text_at(rules[i],Vector2(100,218+i*30),18,muted)
	text_at("ДУХИ УЗОРА",Vector2(100,445),28,gold)
	text_at("Подберите нашивку броском. Она включится со следующего хода. Один слот на хранителя.",Vector2(100,478),17,muted)
	text_at("Новые нашивки — раз в два хода; лежат три хода. Занятый слот сохраняет нашивку для союзника.",Vector2(100,505),17,muted)
	var keys:Array=Spirits.TYPES.keys()
	for i in keys.size():
		var kind:String=keys[i];var column:=i%2;var row:=i/2
		var origin:=Vector2(100+column*740,555+row*83)
		draw_texture_rect(SpiritVisuals.icon(kind),Rect2(origin,Vector2(56,56)),false)
		text_at(Spirits.TYPES[kind].name,origin+Vector2(70,18),18,gold)
		var description:String=Spirits.TYPES[kind].text
		# Two lines keep descriptions readable on a TV.
		var split:=description.find(". ")
		text_at(description.substr(0,split+1) if split>=0 else description,origin+Vector2(70,40),14,muted)
		if split>=0:text_at(description.substr(split+2),origin+Vector2(70,59),14,muted)
	text_at("H / Esc — закрыть. В сетевом матче время продолжает идти.",Vector2(100,947),17,cream)
