class_name OrdoHud
extends Control
const RuneRules=preload("res://scripts/runestones.gd")
const Spirits = preload("res://scripts/spirits.gd")
const HearthMend = preload("res://scripts/hearth_mend.gd")
const SpiritVisuals = preload("res://scripts/spirit_visuals.gd")
const AimPreview = preload("res://scripts/aim_preview.gd")
const Catalog = preload("res://scripts/catalog.gd")
const Bosses = preload("res://scripts/boss_rules.gd")
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
var aim_cache: Dictionary = {}
var aim_glow := Node2D.new()
var aim_paths: Array = []
var charge_full_since: Dictionary = {}
var aim_halo: GradientTexture2D
var enemy_health = preload("res://scripts/enemy_health.gd").new()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Cached soft light for player trajectories and their contact sparks.
	var falloff := Gradient.new()
	falloff.offsets = PackedFloat32Array([0.0, 0.18, 0.45, 1.0])
	falloff.colors = PackedColorArray([Color.WHITE, Color(1,1,1,0.65), Color(1,1,1,0.16), Color(1,1,1,0)])
	aim_halo = GradientTexture2D.new(); aim_halo.gradient = falloff
	aim_halo.width = 128; aim_halo.height = 128
	aim_halo.fill = GradientTexture2D.FILL_RADIAL
	aim_halo.fill_from = Vector2(0.5,0.5); aim_halo.fill_to = Vector2(1,0.5)
	# Additive light is isolated from text/panels: the rug receives colored light,
	# instead of a translucent white road marking painted over its texture.
	var light_material := CanvasItemMaterial.new()
	light_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	aim_glow.material = light_material; aim_glow.show_behind_parent = true
	add_child(aim_glow); aim_glow.draw.connect(draw_aim_glow)
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
	if game_menu.busy:return
	if not create and not game_menu.RoomCode.valid(code_field.text):
		message_label.text = "Введите шесть цифр: 482731."; return
	if not game_menu.store_server_address(): return
	game_menu.busy=true;game_menu.refresh()
	message_label.text = "Соединяемся…"
	game.net.connect_room(game.relay_url, code_field.text, game.active_local_seats().size(), create,game.active_avatars())

func update_lobby() -> void:
	game_menu.connected()

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

func enemy_heading(center: Vector2, direction: Vector2, radius: float, color: Color) -> void:
	# Matte strokes with a dark keyline stay readable over both rug colors.
	var tip := project(center+direction*(radius+0.32),0.12)
	var heading := (tip-project(center,0.12)).normalized()
	var back := tip-heading*10.0
	var chevron := PackedVector2Array([back+heading.orthogonal()*5.5,tip,back-heading.orthogonal()*5.5])
	draw_polyline(chevron,Color("25251f",.8),4.5,true)
	draw_polyline(chevron,color,2.3,true)

func enemy_route(origin: Vector2, target: Vector2, radius: float) -> void:
	var delta := target-origin
	if delta.length() <= radius+.18: return
	var start := origin+delta.normalized()*(radius+.20)
	var count := clampi(ceili(start.distance_to(target)/.36), 1, 22)
	for i in count:
		var a := start.lerp(target,float(i)/count)
		var b := start.lerp(target,(float(i)+.50)/count)
		var from := project(a,.06)
		var to := project(b,.06)
		draw_line(from,to,Color("25251f",.55),4.0,true)
		draw_line(from,to,Color("d3c09d",.66),2.0,true)
	world_ring(target,.12,Color("25251f",.6),3.6)
	world_ring(target,.12,Color("d3c09d",.70),1.8)

func boss_target(player: Dictionary, age: float) -> void:
	var alpha := Bosses.marker_alpha(age)
	if alpha <= 0.0: return
	var point := Vector2(float(player.x),float(player.z))
	var center := project(point,.23)
	var radius := clampf(project(point+Vector2(.68,0),.23).distance_to(center),23,54)
	radius *= 1.08+.025*sin(age*5.0)
	var color := Color("ffcf6b",alpha)
	for i in 8:
		var angle := i*TAU/8.0+age*.12
		draw_arc(center,radius,angle+.045,angle+TAU/8.0-.065,10,Color("2e2318",alpha*.75),4.5,true)
		draw_arc(center,radius,angle+.045,angle+TAU/8.0-.065,10,Color("ffb336",alpha*.23),6.0,true)
		draw_arc(center,radius,angle+.045,angle+TAU/8.0-.065,10,color,2.6,true)
		var dir := Vector2.from_angle(angle)
		draw_line(center+dir*(radius-3),center+dir*(radius+5),color,2.4,true)
	var tip := center-Vector2(0,radius+5+sin(age*5)*2.5)
	var arrow := PackedVector2Array([tip,tip+Vector2(-9,-17),tip+Vector2(-3,-17),tip+Vector2(-3,-24),tip+Vector2(3,-24),tip+Vector2(3,-17),tip+Vector2(9,-17)])
	draw_colored_polygon(arrow,Color("ffe4a3",alpha))

func aim_light(at: Vector2, radius: float, color: Color) -> void:
	draw_texture_rect(aim_halo,Rect2(at-Vector2.ONE*radius,Vector2.ONE*radius*2),false,color)

# Long luminous strokes share a single cadence along the entire curved path.
# Build whole dashes before drawing, so physics samples never look like beads.
func aim_dashes(path: PackedVector2Array, color: Color, strength: float, core_only: bool = false, full_age: float = -1.0, contacts: PackedInt32Array = PackedInt32Array()) -> void:
	if path.size() < 2: return
	var distances := PackedFloat32Array([0.0])
	for i in range(1,path.size()): distances.append(distances[-1]+path[i-1].distance_to(path[i]))
	var length: float = distances[-1]
	if length < 1.0: return
	var dash_length := 19.0
	var spacing := 32.0
	# The whole guide remains visible; stationary dashes fill from the token outward.
	var cursor := 0.0
	var segment := 1
	var contact_index := 0
	while cursor < length:
		var begin := maxf(0.0,cursor)
		var end := minf(length,cursor+dash_length)
		cursor += spacing
		# A reflection is a joint between strokes, never an L-shaped dash.
		# Leave room for its marker and restart the cadence on the outgoing leg.
		if contact_index < contacts.size():
			var joint := float(distances[contacts[contact_index]])
			end = minf(end,joint-6.0)
			if cursor >= joint-6.0:
				cursor = joint+6.0
				contact_index += 1
		if end-begin < 3.0: continue
		while segment < path.size()-1 and distances[segment] <= begin: segment += 1
		var dash := PackedVector2Array()
		var index := segment
		var span := maxf(.001,distances[index]-distances[index-1])
		dash.append(path[index-1].lerp(path[index],(begin-distances[index-1])/span))
		while index < path.size()-1 and distances[index] < end:
			dash.append(path[index]); index += 1
		span = maxf(.001,distances[index]-distances[index-1])
		dash.append(path[index-1].lerp(path[index],(end-distances[index-1])/span))
		var fraction := (begin+end)*0.5/length
		var fade := 1.0-smoothstep(0.60,1.0,fraction)
		var energy := 1.0-smoothstep(strength-.035,strength+.035,fraction) if strength>=0.0 else 0.0
		var pulse := 0.0
		if full_age>=0.0 and full_age<.34:
			pulse = exp(-pow((fraction-full_age/.34)/.13,2.0))
		var width := lerpf(2.5,4.8,energy)+pulse*1.4
		var opacity := lerpf(.66,1.0,energy)*fade
		if core_only:
			# The core uses normal blending, so bright rug threads do not bleach
			# away the player's color. The separate layer adds only the light spill.
			var core := Color(color.lerp(Color.WHITE,.16+energy*.45+pulse*.2),opacity)
			draw_polyline(dash,Color("101c2a",fade*.6),width+2.0,true)
			draw_polyline(dash,core,width,true)
			draw_circle(dash[0],width*.5,core,true,-1,true)
			draw_circle(dash[-1],width*.5,core,true,-1,true)
		else:
			var middle := (dash[0]+dash[-1])*.5
			var glow_size := Vector2(dash[0].distance_to(dash[-1])+28.0,32.0)
			aim_glow.draw_set_transform(middle,(dash[-1]-dash[0]).angle())
			aim_glow.draw_texture_rect(aim_halo,Rect2(-glow_size*.5,glow_size),false,Color(color,opacity*(.18+energy*.6+pulse*.3)))
			aim_glow.draw_set_transform(Vector2.ZERO)
			aim_glow.draw_polyline(dash,Color(color,opacity*.38),width+4.0,true)

func aim_contact(at: Vector2, color: Color, radius: float) -> void:
	aim_glow.draw_texture_rect(aim_halo,Rect2(at-Vector2.ONE*radius,Vector2.ONE*radius*2.0),false,Color(color,.45))

func draw_aim_glow() -> void:
	for shot in aim_paths:
		aim_dashes(shot.path,shot.color,shot.strength,false,shot.full_age,shot.contacts)
		for contact in shot.contacts:
			aim_contact(shot.path[contact],shot.color,12.0)

func cached_aim(player: Dictionary) -> Dictionary:
	var sim = game.sim
	var geometry: Array = []
	for body in sim.players + sim.enemies:
		geometry.append([body.id, body.x, body.z, body.r, body.hp, body.get("jump", 0.0)])
	var signature := hash([sim.turn, player.id, player.angle, player.get("spin", 0.0), player.speed, player.statuses, player.get("spirit",{}), sim.hazards, geometry, sim.stones])
	var entry: Dictionary = aim_cache.get(int(player.id), {})
	if entry.get("signature", -1) != signature:
		var preview := AimPreview.direction_guide(sim, player)
		entry = {"signature": signature, "preview": preview}
		aim_cache[int(player.id)] = entry
	return entry.preview

func draw_aim(player: Dictionary, selected_player: bool) -> void:
	if game.sim.Effects.frozen(game.sim, player): return
	var charging: bool = game.is_charging(int(player.id))
	var charged: bool = charging or bool(player.ready)
	var preview := cached_aim(player)
	var points: PackedVector2Array = preview.points
	# The bright portion encodes charge; it never alters the guide geometry.
	var strength := float(player.power) if charged else -1.0
	var full_age := clock-float(charge_full_since[int(player.id)]) if charge_full_since.has(int(player.id)) else -1.0
	var light: Color = Catalog.AIM_COLORS[int(player.id)]
	# Trim the path at the token rim using path length, preserving curl near launch.
	# Clipping in world space keeps glow anchors on the rug even at a crowded rim.
	var screen_path := PackedVector2Array()
	var contacts := PackedInt32Array()
	var world_contacts: Array = preview.get("contacts",range(1,points.size()-1))
	var trim := float(player.r)+0.12
	for i in range(1,points.size()):
		var from := points[i-1]; var to := points[i]
		var segment_length := from.distance_to(to)
		if trim >= segment_length:
			trim -= segment_length; continue
		if screen_path.is_empty():
			from = from.lerp(to,trim/maxf(segment_length,.001)); trim = 0.0
			screen_path.append(project(from.limit_length(game.sim.RADIUS-.04),.10))
		screen_path.append(project(to.limit_length(game.sim.RADIUS-.04),.10))
		if i in world_contacts: contacts.append(screen_path.size()-1)
	aim_dashes(screen_path,light,strength,true,full_age,contacts)
	var shot := {"path":screen_path,"color":light,"strength":strength,"full_age":full_age,"contacts":contacts}
	# The guide follows the token center. Mark that exact turn, so the hint
	# cannot imply a second, disconnected impact farther away on the wall.
	for i in contacts:
		var at := screen_path[i]
		draw_circle(at,5.2,Color("101c2a",.85),true,-1,true)
		draw_arc(at,3.4,0,TAU,20,light.lightened(.25),1.8,true)
	aim_paths.append(shot)

func _process(dt: float) -> void:
	if game == null: return
	clock += dt
	if game.in_menu: enemy_health.states.clear()
	else: enemy_health.update(game.sim.enemies, game.arena.actors, dt)
	for player in game.sim.players:
		var slot := int(player.id)
		if game.sim.phase == "plan" and (game.is_charging(slot) or bool(player.ready)) and float(player.power)>=.999:
			if not charge_full_since.has(slot):charge_full_since[slot]=clock
		else: charge_full_since.erase(slot)
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
	game_menu.refresh()
	for e in game.sim.events:
		if int(e.id) > seen:
			seen = int(e.id); pulse_events.append({"event": e, "life": 0.0})
	for e in pulse_events: e.life += dt
	pulse_events = pulse_events.filter(func(e): return e.life < 1.2)
	aim_glow.scale = Vector2.ONE*scale_factor
	aim_glow.visible = not game.in_menu and game.sim.phase == "plan" and not help_open
	queue_redraw()

func draw_runestones(sim) -> void:
	var symbols:={"surge":"×2","heal":"♥","guard":"⬡","thorns":"✹","class":"✦"}
	for stone in sim.stones:
		if not stone.get("collector",false):continue
		var anchor:=project(Vector2(float(stone.x),float(stone.z)),.65)
		var kind:String=stone.get("effect","")
		var charged:=RuneRules.charged(stone)
		var color:=Color(RuneRules.EFFECTS[kind].color) if RuneRules.EFFECTS.has(kind) else Color("89bac9")
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
		if event.get("quenched",false):continue
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
	draw_style_box(capsule,Rect2(696,67,438,79))
	var first:=Vector2(727,109);var spacing:=90.0
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
			draw_texture_rect(game.arena.coal_portrait,Rect2(point+Vector2(-30,-82),Vector2(60,60)),false,tint)
			if wave in [3,6,9]:
				# A small ember crown marks the boss milestones.
				for j in 3:draw_circle(point+Vector2((j-1)*5,-79),1.7,gold)
	# The countdown sits in the left margin, away from the tabletop.
	var center:=Vector2(98,564)
	var color:=Color("67cde9") if sim.phase=="plan" else gold
	var total:float=Catalog.wave_spec(sim.wave,sim.players.size(),sim.difficulty).planning
	var fraction:=clampf(float(sim.timer)/total,0,1) if sim.phase=="plan" else 0.0
	draw_circle(center,32,Color(.012,.022,.039,.88))
	draw_arc(center,31,0,TAU,64,Color("344553"),2,true)
	if fraction>0:draw_arc(center,31,-PI/2,-PI/2+TAU*fraction,64,color,3,true)
	text_at(str(ceili(sim.timer)) if sim.phase=="plan" else "✦",center+Vector2(-24,9),24,color,HORIZONTAL_ALIGNMENT_CENTER,48)
	var label: String={"plan":"ПРИЦЕЛ","resolve":"БРОСОК","enemy":"АТАКА","clear":"ПЕРЕДЫШКА","reward":"ДАР","win":"РАССВЕТ","lose":"УГАС"}.get(sim.phase,"")
	text_at(label,center+Vector2(-75,57),12,muted,HORIZONTAL_ALIGNMENT_CENTER,150)

func player_symbol(at:Vector2,slot:int,radius:float,color:Color)->void:
	if slot==3:
		draw_arc(at,radius*.72,0,TAU,64,color,8,true)
		return
	var sides:int=[3,6,4][slot]
	var points:=PackedVector2Array()
	for i in sides+1:points.append(at+Vector2.from_angle(-PI/2+TAU*i/sides)*radius)
	if slot==0:
		draw_polyline(points,color,5,true)
	elif slot==1:
		draw_colored_polygon(points,color.darkened(.18));draw_polyline(points,color.lightened(.35),3,true)
	else:
		draw_colored_polygon(points,color)
		var hole:=PackedVector2Array()
		for i in 4:hole.append(at+Vector2.from_angle(-PI/2+TAU*i/4)*radius*.36)
		draw_colored_polygon(hole,Color("102c24"))

func _draw() -> void:
	if game == null: return
	aim_paths.clear(); aim_glow.queue_redraw()
	reward_screen.begin_frame()
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE * scale_factor)
	var sim = game.sim
	if game.in_menu:
		game_menu.draw()
		draw_pad_notice()
		return
	if sim.phase == "reward":
		draw_reward()
		draw_pad_notice()
		if help_open:
			draw_help();reward_screen.begin_frame()
		return
	for key in trails.keys():
		var trail: Array = trails[key]
		for i in range(1, trail.size()):
			var a: Vector2 = project(trail[i - 1].p, 0.17); var b: Vector2 = project(trail[i].p, 0.17)
			if a.distance_to(b) > 100: continue
			var opacity: float = float(trail[i].life) / 0.32
			draw_line(a, b, Color(Catalog.COLORS[key], opacity * 0.08), 7 * opacity, true)
			draw_line(a, b, Color(Catalog.COLORS[key], opacity * 0.55), 2.5 * opacity, true)
			draw_line(a, b, Color(cream, opacity * 0.35), 1.0 * opacity, true)
	# The tabletop remains the primary surface; all HUD elements sit near its perimeter.
	draw_wave_clock(sim)
	draw_runestones(sim)
	draw_clashes()
	for i in sim.players.size():
		var p: Dictionary = sim.players[i]; var c: Color = Catalog.COLORS[i]; var y: float = 98.0+i*107.0
		var badge:=Vector2(98,y)
		aim_light(badge,65,Color(c,.24))
		draw_circle(badge,43,Color(.012,.025,.036,.95))
		draw_arc(badge,42,0,TAU,80,Color(c,.2),9,true)
		draw_arc(badge,41,0,TAU,80,c,3.5,true)
		player_symbol(badge,i,22,c)
		for hp in int(p.max_hp):
			var pip:=Vector2(172+hp*minf(32.0,135.0/maxf(1,float(p.max_hp)-1)),y)
			draw_circle(pip,10,Color(c,.5) if hp<int(p.hp) else Color("536372"))
			draw_circle(pip,8,c if hp<int(p.hp) else Color("16212e"))
		if p.ready:text_at("✓",Vector2(168,y+30),20,c)
		var statuses: Array = []
		for status in p.statuses.keys():
			if status == "burn": statuses.append("ОГОНЬ · %d · −1/ХОД" % int(p.statuses.burn))
			elif status == "frozen": statuses.append("ЛЁД · ПРОПУСК БРОСКА" if sim.Effects.frozen(sim,p) else "ЛЁД · СЛЕДУЮЩИЙ ХОД")
			else: statuses.append({"frost":"ХОЛОД", "snare":"НИТИ", "weak":"СЛАБОСТЬ"}.get(status,status))
		text_at(" · ".join(statuses), Vector2(165, y + 33), 10, Color("a9cee5"))
		if p.hp > 0:
			var center := Vector2(float(p.x), float(p.z))
			if i == game.selected and not game.is_charging(i) and not p.ready: world_ring(center, 0.6, Color(c, 0.45), 1.5)
			if p.statuses.has("frost"): world_ring(center, 0.68, Color("abdfef"), 3, true)
			if p.statuses.has("snare"): world_ring(center, 0.53, Color("cab7df"), 3)
			if p.shield > 0: world_ring(center, 1.9 if i == 1 else 0.62, Color(gold, 0.6), 3, true)
			if sim.phase == "plan":
				draw_aim(p,i==game.selected)
				if p.ready and not sim.Effects.frozen(sim,p): text_at("✓",project(center,0.8)+Vector2(-10,-14),27,c)
			draw_spirit_badge(p,center)
	if sim.phase in ["plan","enemy"]:
		var marked: Dictionary = {}
		for e in sim.enemies:
			if int(e.stun)>0 or sim.Effects.frozen(sim,e) or e.attack=="rest" or (sim.phase=="enemy" and bool(e.fired)): continue
			var p := Vector2(float(e.x),float(e.z)); var target := Vector2(float(e.tx),float(e.tz))
			var direction := (target-p).normalized()
			var danger := Color("cbb58f",0.78)
			var target_id := int(e.get("target_id",-1))
			if sim.phase=="plan" and e.kind in Bosses.KINDS and not marked.has(target_id):
				for player in sim.players:
					if int(player.id)==target_id and int(player.hp)>0:
						boss_target(player,float(sim.phase_time));marked[target_id]=true
			if e.attack=="rush":
				enemy_route(p,target,float(e.r))
				enemy_heading(p,direction,float(e.r),danger)
			elif e.attack=="ring":
				var radius := float(e.get("ring_radius",4.5))
				world_ring(Vector2.ZERO,radius-0.8,Color(danger,0.18),1.0)
				world_ring(Vector2.ZERO,radius+0.8,Color(danger,0.18),1.0)
				world_ring(Vector2.ZERO,radius,Color(danger,0.5),1.5)
			else:
				if e.attack=="jump":enemy_route(p,target,float(e.r))
				var radius := 1.4 if e.attack=="slam" else (1.1 if e.attack=="frost" else (1.6 if e.kind=="weaver" else 1.05))
				world_ring(p if e.attack=="slam" else target,radius,Color(danger,0.5),1.5)

	for e in sim.enemies:
		if int(e.hp) <= 0: continue
		if e.kind in Bosses.KINDS:
			panel(Rect2(1160, 204, 390, 88), Color(0.04, 0.035, 0.05, 0.9), Color("9d6970"))
			text_at(Catalog.ENEMIES[e.kind].name, Vector2(1180, 231), 16, cream)
			draw_rect(Rect2(1180, 246, 347, 5), Color("3a343f"))
			draw_rect(Rect2(1180, 246, 347.0 * float(e.hp) / float(e.max_hp), 5), Color("e89c86"))
			text_at(Bosses.hint(sim,e),Vector2(1180,275),14,muted)
	enemy_health.draw(self)
	for h in sim.hazards: world_ring(Vector2(float(h.x), float(h.z)), float(h.r), Color(0.55, 0.8, 0.95, 0.55), 2, true)
	for item in sim.pickups:
		if item.kind=="element":
			var at:=project(Vector2(float(item.x),float(item.z)),.5)
			if (get_local_mouse_position()/scale_factor).distance_to(at)<35:
				text_at("Огонь · 1 ход" if item.element=="fire" else "Мороз · тормозит",at+Vector2(-100,-38),16,cream,HORIZONTAL_ALIGNMENT_CENTER,200)
			continue
		if item.kind=="spirit":
			var point:=Vector2(float(item.x),float(item.z));var anchor:=project(point,0.2)
			if item.get("boss_gift",false):text_at("Мороз · сразу",anchor+Vector2(-55,28),13,Color("b7e4ff"))
			else:
				for pip in mini(3,maxi(0,int(item.expires)-sim.turn)):draw_circle(anchor+Vector2(-8+pip*8,23),2.4,gold)
			if (get_local_mouse_position()/scale_factor).distance_to(anchor)<27:
				text_at(Spirits.TYPES[item.spirit].name.get_slice(" — ",0),anchor+Vector2(-70,-30),16,cream,HORIZONTAL_ALIGNMENT_CENTER,140)
			continue
		var p := project(Vector2(float(item.x), float(item.z)), 0.3)
		draw_circle(p, 15, Color(0.02, 0.09, 0.09, 0.8))
		text_at("+" if item.kind == "heart" else "✦", p + Vector2(-8, 8), 24, Color("92e2bc"))
	var crystal_tip: float = game.arena.flame_root.position.y + 1.24 * game.arena.flame_root.scale.y
	var core := project(Vector2.ZERO,crystal_tip) + Vector2(0,-36)
	var spacing:=minf(29.0,242.0/float(sim.max_fire))
	var bar_width:float=sim.max_fire*spacing+20.0
	panel(Rect2(core.x-bar_width*.5,core.y-24,bar_width,46),Color(.025,.023,.022,.95),Color("675543"))
	for hp in sim.max_fire:
		var center:=Vector2(core.x+(hp-(sim.max_fire-1)*.5)*spacing,core.y-1)
		var mend := HearthMend.pip_state(pulse_events, hp, sim.fire)
		var radius := minf(16,spacing*.49) * (1.0 + mend.y * 0.22)
		if mend.y > 0:
			draw_circle(center, radius + 7, Color(HearthMend.GOLD, mend.y * 0.14))
		var points:=PackedVector2Array()
		for corner in 8:points.append(center+Vector2.from_angle(TAU*corner/8.0+PI/8.0)*radius)
		draw_colored_polygon(points,Color("424445").lerp(Color("ffc64e").lerp(HearthMend.WHITE,mend.y * 0.8),mend.x))
		points.append(points[0])
		draw_polyline(points,Color("575653").lerp(HearthMend.WHITE,mend.x),1.3,true)
	HearthMend.draw(self, core, spacing)
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
	if game.arena.combo_hits>=2 and game.arena.clock-game.arena.combo_last<1.0:
		var message:="КОМБО ×%d"%game.arena.combo_hits
		var opacity:=1.0-smoothstep(0.6,1.0,game.arena.clock-game.arena.combo_last)
		draw_string_outline(font,Vector2(660,153),message,HORIZONTAL_ALIGNMENT_CENTER,280,26,5,Color(0.05,0.025,0.04,opacity))
		draw_string(font,Vector2(660,153),message,HORIZONTAL_ALIGNMENT_CENTER,280,26,Color(gold,opacity))
	if game.selected < sim.players.size():
		var selected:Dictionary=sim.players[game.selected]
		var ink:Color=Catalog.COLORS[game.selected]
		text_at("P%d · %s"%[game.selected+1,Catalog.NAMES[game.selected]],Vector2(28,676),14,ink)
		text_at("Q · УМЕНИЕ  %d"%int(selected.charges),Vector2(28,703),12,gold if selected.ability else muted)
		text_at("ОТПУСТИ · %d%%" % roundi(float(selected.power)*100) if game.is_charging(game.selected) else ("B / ⌫ · ОТМЕНА" if selected.ready else "SPACE / A · ДЕРЖИ"),Vector2(28,730),12,ink if game.is_charging(game.selected) else muted)
	if sim.phase == "plan" and game.selected < sim.players.size():
		var spin: float = float(sim.players[game.selected].get("spin",0.0))
		text_at("L1 / R1 · ПОДКРУТКА",Vector2(28,757),11,muted)
		text_at("ПРЯМО" if absf(spin)<.01 else "%s %d%%" % ["ВЛЕВО" if spin<0 else "ВПРАВО",roundi(absf(spin)*100)],Vector2(28,780),12,Catalog.COLORS[game.selected])
	text_at("H · УПРАВЛЕНИЕ",Vector2(28,size.y/scale_factor-28),12,muted)
	if game.online:text_at(game.net.room,Vector2(28,size.y/scale_factor-53),13,gold)
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
		var description: String=Spirits.TYPES[kind].name.get_slice(" — ",0)+" · "+("следующий ход" if spirit.is_empty() else str(int(spirit.turns))+" ход.")
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
	var next := "Enter / A — вернуться к очагу"
	if game.online:
		next = "Enter / A — в комнату для новой игры" if game.net.is_host else "Ждём ведущего · вы остаётесь в комнате"
	text_at(next, Vector2(0, 626), 23, cream, HORIZONTAL_ALIGNMENT_CENTER, 1600)

func draw_help() -> void:
	draw_rect(Rect2(0,110,1600,890),Color(0.025,0.04,0.06,0.97))
	text_at("ХРАНИТЕЛИ ОЧАГА",Vector2(100,178),30,cream)
	var rules:=["A/D, ←/→ — поворот; мышь / стик — наведение. Q / X — способность.","Держите Space / A: сила растёт. Отпустите — готовность.","L1/R1 (Z/C) — подкрутка; обе кнопки — прямо.","При зарядке можно целиться. B / Backspace — отмена.","Готовые фишки летят одновременно, остальные защищаются.","Сильный удар ранит врага. Метки показывают его намерения.","Коснитесь погасшего союзника при броске, чтобы поднять его.","M — звук. F11 — весь экран."]
	for i in rules.size():text_at(rules[i],Vector2(100,218+i*23),16,muted)
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
