class_name OrdoHud
extends Control
const RuneRules=preload("res://scripts/runestones.gd")
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
var game_menu = preload("res://scripts/game_menu.gd").new()
var reward_screen = preload("res://scripts/reward_screen.gd").new()
var scale_factor := 1.0
var aim_halo: GradientTexture2D
var aim_band: GradientTexture2D

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Cached falloffs keep the aim luminous even without 3D bloom (mobile renderer).
	var falloff := Gradient.new()
	falloff.offsets = PackedFloat32Array([0.0, 0.18, 0.45, 1.0])
	falloff.colors = PackedColorArray([Color.WHITE, Color(1,1,1,0.65), Color(1,1,1,0.16), Color(1,1,1,0)])
	aim_halo = GradientTexture2D.new(); aim_halo.gradient = falloff
	aim_halo.width = 128; aim_halo.height = 128
	aim_halo.fill = GradientTexture2D.FILL_RADIAL
	aim_halo.fill_from = Vector2(0.5,0.5); aim_halo.fill_to = Vector2(1,0.5)
	var band := Gradient.new()
	band.offsets = PackedFloat32Array([0,0.25,0.5,0.75,1])
	band.colors = PackedColorArray([Color(1,1,1,0),Color(1,1,1,0.12),Color.WHITE,Color(1,1,1,0.12),Color(1,1,1,0)])
	aim_band = GradientTexture2D.new(); aim_band.gradient = band
	aim_band.width = 8; aim_band.height = 128
	aim_band.fill_from = Vector2(0,0); aim_band.fill_to = Vector2(0,1)
	reward_screen.prepare()
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
	game_menu.build(self)

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
	if dotted:
		aim_segment(a,stem_end,color,0.0)
	else:
		aim_capsule(a,stem_end,Color(color,color.a*0.16),width+8)
		aim_capsule(a,stem_end,color,width)
	var back := b-direction*tip_size
	var points := PackedVector2Array([b,back+direction.orthogonal()*tip_size*0.48,back+direction*tip_size*0.20,back-direction.orthogonal()*tip_size*0.48])
	draw_colored_polygon(points,color)

func aim_light(at: Vector2, radius: float, color: Color) -> void:
	draw_texture_rect(aim_halo,Rect2(at-Vector2.ONE*radius,Vector2.ONE*radius*2),false,color)

func aim_capsule(a: Vector2, b: Vector2, color: Color, width: float) -> void:
	draw_line(a,b,color,width,true)
	draw_circle(a,width*0.5,color); draw_circle(b,width*0.5,color)

func aim_segment(a: Vector2, b: Vector2, color: Color, traveled: float) -> void:
	var length := a.distance_to(b)
	if length < 1.0: return
	var direction := (b-a)/length
	# A soft continuous light bed ties the separated white dashes into one path.
	draw_set_transform(a*scale_factor,direction.angle(),Vector2.ONE*scale_factor)
	draw_texture_rect(aim_band,Rect2(0,-17,length,34),false,Color(color,color.a*0.72))
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE*scale_factor)
	var distance := fposmod(clock*32.0-traveled,25.0)-25.0
	while distance < length:
		var begin := maxf(0,distance); var end := minf(length,distance+14.0)
		if end > begin:
			var p := a+direction*begin; var q := a+direction*end
			aim_light((p+q)*0.5,19,Color(color,color.a*0.65))
			aim_capsule(p,q,Color(color,color.a*0.35),11.0)
			aim_capsule(p,q,color,6.5)
			aim_capsule(p,q,Color(Color.WHITE.lerp(color,0.10),color.a),3.5)
		distance += 25.0

func aim_spark(at: Vector2, color: Color, radius: float) -> void:
	var pulse := 0.94+0.06*sin(clock*4.0)
	aim_light(at,radius*2.0,Color(color,color.a*0.8))
	aim_light(at,radius*0.72,Color(color,color.a*0.95))
	for i in 8:
		var ray := Vector2.from_angle(i*TAU/8.0+0.18)
		var reach := radius*pulse*(1.0 if i%2==0 else 0.58)
		var side := ray.orthogonal()*2.3
		draw_colored_polygon(PackedVector2Array([at+ray*reach,at+side,at-ray*3,at-side]),color)
		draw_colored_polygon(PackedVector2Array([at+ray*reach*0.87,at+side*0.45,at-ray*2,at-side*0.45]),Color(Color.WHITE,color.a))
	draw_circle(at,3.3,Color(Color.WHITE,color.a))

func draw_aim(player: Dictionary, selected_player: bool) -> void:
	var color: Color = Catalog.COLORS[int(player.id)]
	var center := Vector2(float(player.x),float(player.z)); var direction := Vector2.from_angle(float(player.angle))
	var start := center+direction*(float(player.r)+0.15)
	var preview := AimPreview.trace(game.sim,player)
	var points: PackedVector2Array = preview.points
	# The solver traces the token's center; the visible spark belongs on its rim
	# where it touches the target, especially when the two bodies are adjacent.
	if preview.kind in ["enemy","ally"]:
		var incoming := (points[-1]-points[-2]).normalized()
		points[-1] += incoming*float(player.r)
	var light := Color("168dff") if int(player.id)==0 else color
	light.a = 1.0 if selected_player else 0.75
	var traveled := 0.0
	for i in range(1,points.size()):
		var from := start if i == 1 else points[i-1]
		# A nearby obstacle may leave no visible stem. Keep its impact marker.
		if (points[i]-from).dot((points[i]-points[i-1]).normalized()) > 0.05:
			var a := project(from,0.17); var b := project(points[i],0.17)
			aim_segment(a,b,Color(light,light.a*(1.0 if i==1 else 0.83)),traveled)
			traveled += a.distance_to(b)
	# Draw contacts after the entire ribbon so the outgoing leg cannot cover them.
	for i in range(1,points.size()-1):
		aim_spark(project(points[i],0.17),light,19.0)
	var endpoint: Vector2 = points[-1]
	var marker := project(endpoint,0.18)
	if preview.kind != "stop":
		aim_spark(marker,light,29.0)
	else:
		# An open-lane endpoint is directional; only real contacts get a starburst.
		var heading := (marker-project(points[-2],0.18)).normalized()
		var wing := heading.orthogonal()*7.0
		aim_light(marker,23,Color(light,0.75))
		for side in [-1.0,1.0]:
			var tail: Vector2 = marker-heading*12+wing*side
			aim_capsule(tail,marker,light,6)
			aim_capsule(tail,marker,Color("effaff"),2.5)
	# Power is readable next to the moving token without hiding its emblem.
	if selected_player:
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
	menu.scale = Vector2.ONE * scale_factor; menu.position = Vector2(88, 350) * scale_factor
	menu.visible = game.in_menu
	for e in game.sim.events:
		if int(e.id) > seen:
			seen = int(e.id); pulse_events.append({"event": e, "life": 0.0})
	for e in pulse_events: e.life += dt
	pulse_events = pulse_events.filter(func(e): return e.life < 1.2)
	queue_redraw()

func draw_runestones(sim) -> void:
	var symbols:={"surge":"×2","heal":"♥","guard":"⬡","thorns":"✹","class":"✦"}
	for stone in sim.stones:
		if not stone.get("collector",false):continue
		var anchor:=project(Vector2(float(stone.x),float(stone.z)),.65)
		var kind:String=stone.get("effect","")
		var charged:=RuneRules.charged(stone)
		var color:=Color(RuneRules.EFFECTS[kind].color) if RuneRules.EFFECTS.has(kind) else Color("89bac9")
		for pip in 2:
			var p:=anchor+Vector2(-6+pip*12,22)
			draw_circle(p,4,Color("121a23"));draw_circle(p,2.5,color if pip<int(stone.get("souls",0)) else Color("4a5059"))
		if charged:
			var badge:=anchor+Vector2(24,-16)
			draw_circle(badge,17,Color(.015,.025,.034,.95));draw_arc(badge,16,0,TAU,40,color,1.6,true)
			text_at(symbols.get(kind,"✦"),badge+Vector2(-17,7),20,color,HORIZONTAL_ALIGNMENT_CENTER,34)
		if (get_local_mouse_position()/scale_factor).distance_to(anchor)<36:
			var label:String=RuneRules.EFFECTS[kind].name if charged and RuneRules.EFFECTS.has(kind) else "Души: %d / 2"%int(stone.get("souls",0))
			text_at(label,anchor+Vector2(-110,-42),15,cream,HORIZONTAL_ALIGNMENT_CENTER,220)
	for player in sim.players:
		var boon:Dictionary=player.get("rune_boon",{})
		if boon.is_empty() or int(player.hp)<=0:continue
		var anchor:=project(Vector2(float(player.x),float(player.z)),.90)+Vector2(-26,-8)
		var color:=Color(RuneRules.EFFECTS[boon.kind].color)
		draw_circle(anchor,14,Color(.015,.025,.034,.92));draw_arc(anchor,14,0,TAU,32,color,1.5,true)
		text_at(symbols[boon.kind],anchor+Vector2(-12,6),19,color,HORIZONTAL_ALIGNMENT_CENTER,24)
		for pip in maxi(0,int(boon.expires)-sim.turn):draw_circle(anchor+Vector2(-4+pip*8,19),2,color)

func draw_clashes() -> void:
	for item in pulse_events:
		var event:Dictionary=item.event
		if event.kind not in ["clash","team_clash"]:continue
		if event.kind=="team_clash":
			var superseded:=false
			for other in pulse_events:
				if other.event.kind=="team_clash" and int(other.event.get("target",-1))==int(event.target) and int(other.event.id)>int(event.id):superseded=true
			if superseded:continue
		var age:float=item.life
		var opacity:=1.0-smoothstep(.35,1.0,age)
		var origin:=Vector2(float(event.x),float(event.z))
		world_ring(origin,.25+age*3.3,Color("c5edff",opacity*.9),4.0*(1.0-age)+1.0)
		world_ring(origin,.18+age*2.8,Color("ffdfa2",opacity*.5),2.0)
		var anchor:=project(origin,.8)+Vector2(0,-30-age*44)
		var size_value:=int(42+sin(minf(age/.18,1.0)*PI)*12)
		var label:="ТЫДЫЩ! ×%d"%int(event.multiplier)
		if event.kind=="team_clash":label="ВМЕСТЕ! ТЫДЫЩ ×%d"%int(event.multiplier)
		var width:=font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,size_value).x
		var p:=anchor-Vector2(width*.5,0)
		draw_string_outline(font,p,label,HORIZONTAL_ALIGNMENT_LEFT,-1,size_value,7,Color(.025,.04,.06,opacity))
		text_at(label,p,size_value,Color("fff0c6",opacity))

func draw_wave_clock(sim) -> void:
	# Five visible milestones slide through the nine-wave match without hiding its ends.
	var start:=clampi(int(sim.wave)-3,0,4)
	var capsule:=style(Color(.012,.016,.025,.92),Color(.14,.17,.21,.7))
	capsule.set_corner_radius_all(27);capsule.set_border_width_all(1)
	draw_style_box(capsule,Rect2(624,62,356,59))
	var first:=Vector2(647,86);var spacing:=77.0
	draw_line(first,first+Vector2(spacing*4,0),Color("111720"),9,true)
	draw_line(first,first+Vector2(spacing*4,0),Color("65717a"),3,true)
	for i in 5:
		var wave:=start+i+1;var point:=first+Vector2(spacing*i,0)
		var done:=wave<=int(sim.wave)
		var c:=Color("ff635d") if done else Color("78838f")
		if done and i>0:draw_line(point-Vector2(spacing,0),point,Color("df5558"),3,true)
		draw_circle(point,15,Color("080c12"));draw_circle(point,12,c)
		draw_arc(point,11,-PI*.95,-PI*.12,20,c.lightened(.45),2,true)
		if wave==int(sim.wave):draw_arc(point,15,0,TAU,48,Color(c,.35),3,true)
		if i>0 and game.arena.coal_portrait:
			var tint:=Color.WHITE if wave>=sim.wave else Color(.65,.65,.65,.8)
			draw_texture_rect(game.arena.coal_portrait,Rect2(point+Vector2(-24,-64),Vector2(48,48)),false,tint)
			if wave in [3,6,9]:
				# A small ember crown marks the boss milestones.
				for j in 3:draw_circle(point+Vector2((j-1)*5,-62),1.7,gold)
	text_at("%02d / 09"%sim.wave,Vector2(625,111),11,muted,HORIZONTAL_ALIGNMENT_CENTER,356)
	var center:=Vector2(1490,85)
	var color:=Color("47d8ff") if sim.phase=="plan" else gold
	draw_circle(center,58,Color(.012,.022,.039,.93))
	draw_arc(center,57,0,TAU,96,Color("142537"),3,true)
	var total:float=Catalog.wave_spec(sim.wave,sim.players.size(),sim.difficulty).planning
	var fraction:=clampf(float(sim.timer)/total,0,1) if sim.phase=="plan" else 0.0
	for i in 16:
		var a:float=-PI/2+i*TAU/16
		var filled:=float(i)/16<fraction
		draw_arc(center,49,a+.033,a+TAU/16-.033,8,color if filled else Color("495466"),8,true)
	# Luminous hourglass, drawn as one continuous silhouette at television scale.
	var hourglass:=PackedVector2Array([Vector2(-14,-20),Vector2(14,-20),Vector2(12,-11),Vector2(3,-1),Vector2(3,2),Vector2(12,12),Vector2(14,21),Vector2(-14,21),Vector2(-12,12),Vector2(-3,2),Vector2(-3,-1),Vector2(-12,-11),Vector2(-14,-20)])
	for i in hourglass.size():hourglass[i]+=center
	draw_polyline(hourglass,Color(color,.16),8,true);draw_polyline(hourglass,Color("d9f9ff"),2.6,true)
	var sand:float=.25+.75*fraction
	draw_colored_polygon(PackedVector2Array([center+Vector2(-8,-12)*Vector2(sand,1),center+Vector2(8,-12)*Vector2(sand,1),center+Vector2(0,-3)]),color)
	draw_colored_polygon(PackedVector2Array([center+Vector2(-9,17),center+Vector2(9,17),center+Vector2(0,7+fraction*7)]),color)
	var label: String={"plan":"ПРИЦЕЛ","resolve":"БРОСОК","enemy":"АТАКА","clear":"ПЕРЕДЫШКА","reward":"ДАР","win":"РАССВЕТ","lose":"УГАС"}.get(sim.phase,"")
	text_at(label,center+Vector2(-75,82),12,color,HORIZONTAL_ALIGNMENT_CENTER,150)
	if sim.phase=="plan":text_at(str(ceili(sim.timer)),center+Vector2(-25,40),11,color,HORIZONTAL_ALIGNMENT_CENTER,50)

func _draw() -> void:
	if game == null: return
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE * scale_factor)
	var sim = game.sim
	if game.in_menu:
		game_menu.draw()
		draw_pad_notice()
		return
	if sim.phase == "reward":
		draw_reward()
		draw_pad_notice()
		if help_open: draw_help()
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
	draw_wave_clock(sim)
	draw_runestones(sim)
	draw_clashes()
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
			var danger := Color(1.0,1.0,1.0,0.62)
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
			panel(Rect2(1160, 204, 390, 65), Color(0.04, 0.035, 0.05, 0.9), Color("9d6970"))
			text_at(Catalog.ENEMIES[e.kind].name, Vector2(1180, 231), 16, cream)
			draw_rect(Rect2(1180, 246, 347, 5), Color("3a343f"))
			draw_rect(Rect2(1180, 246, 347.0 * float(e.hp) / float(e.max_hp), 5), Color("e89c86"))
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
	draw_pad_notice()

func draw_pad_notice() -> void:
	if game.pad_notice_time <= 0: return
	var top := 140.0 if game.in_menu else (38.0 if game.sim.phase=="reward" else 190.0)
	panel(Rect2(780,top,710,65),Color(.07,.045,.025,.97),gold)
	text_at(game.pad_notice,Vector2(795,top+42),23,cream,HORIZONTAL_ALIGNMENT_CENTER,680)

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
	reward_screen.draw(self)

func draw_end() -> void:
	draw_rect(Rect2(0, 110, 1600, 890), Color(0.02, 0.035, 0.05, 0.87))
	text_at("РАССВЕТ НАД ПЕРЕВАЛОМ" if game.sim.phase == "win" else "ПОСЛЕДНЯЯ ИСКРА", Vector2(0, 422), 48, cream, HORIZONTAL_ALIGNMENT_CENTER, 1600)
	text_at("Вы сохранили огонь. Эта история останется в узоре." if game.sim.phase == "win" else game.sim.last_reason, Vector2(0, 475), 22, muted, HORIZONTAL_ALIGNMENT_CENTER, 1600)
	text_at("ВОЛНА %d  ·  ПОБЕЖДЕНО %d  ·  ХОДОВ %d" % [game.sim.wave, game.sim.kills, game.sim.turn], Vector2(0, 540), 20, gold, HORIZONTAL_ALIGNMENT_CENTER, 1600)
	text_at("Enter / A — вернуться к очагу", Vector2(0, 626), 23, cream, HORIZONTAL_ALIGNMENT_CENTER, 1600)

func draw_help() -> void:
	draw_rect(Rect2(0,110,1600,890),Color(0.025,0.04,0.06,0.97))
	text_at("ХРАНИТЕЛИ ОЧАГА",Vector2(100,178),30,cream)
	var rules:=["Выберите направление и силу. Q / X — способность.","Space / A — готовность. B / Backspace — отмена.","Готовые фишки летят одновременно, остальные защищаются.","Сильный удар ранит врага. Метки показывают его намерения.","Коснитесь погасшего союзника при броске, чтобы поднять его.","Tab — смена игрока. M — звук. F11 — весь экран."]
	for i in rules.size():text_at(rules[i],Vector2(100,218+i*30),18,muted)
	text_at("ТЫДЫЩ: быстрый встречный бросок, угол до 45° от встречного.",Vector2(100,403),15,gold)
	text_at("Разлёт ×2 / ×3. Один раз на игрока за бросок.",Vector2(100,425),15,muted)
	text_at("РУНИЧЕСКИЕ КАМНИ",Vector2(840,178),28,gold)
	text_at("Две души заряжают камень случайным видимым даром.",Vector2(840,218),16,muted)
	var gifts:=["×2  Разгон: удваивает скорость одного рикошета.","♥  Живая нить: +1 жизнь раненому хранителю.","⬡  Оберег: один блок урона и дебаффа, до двух ходов.","✹  Панцирь: меньше отбрасывание; ответный урон раз в ход.","✦  Дар узора: класс вылетает в свободную точку поля."]
	for i in gifts.size():text_at(gifts[i],Vector2(840,253+i*29),15,cream)
	text_at("Дар забирается рикошетом. Один дар на фишку за бросок.",Vector2(840,412),15,muted)
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
