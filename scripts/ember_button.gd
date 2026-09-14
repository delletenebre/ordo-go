extends Button
static var art: AtlasTexture
var ember_time := 0.0
var normal: StyleBoxTexture
var focus_outline := PackedVector2Array()

func _ready() -> void:
	if art == null:
		var source: Texture2D = load("res://assets/menu-button-felt.png")
		art = AtlasTexture.new(); art.atlas = source
		# Ignore the generated near-transparent fringe; keep the full felt edge.
		var ratio := source.get_size()/Vector2(2172,724)
		art.region = Rect2(Vector2(47,112)*ratio,Vector2(2080,474)*ratio)
	custom_minimum_size.y = maxf(custom_minimum_size.y,76)
	add_theme_font_size_override("font_size",23)
	add_theme_color_override("font_color",Color("ead9ba"))
	add_theme_color_override("font_focus_color",Color("fff0bf"))
	for state in ["normal","hover","pressed"]:
		var box := StyleBoxTexture.new(); box.texture = art
		box.modulate_color = Color(.75,.72,.68) if state=="normal" else Color.WHITE
		add_theme_stylebox_override(state,box)
		if state=="normal": normal=box
	add_theme_stylebox_override("focus",StyleBoxEmpty.new())
	resized.connect(update_border);update_border()

func update_border() -> void:
	focus_outline.clear()
	var radius := size.y*.5-2.0
	for side in 2:
		var center := Vector2(size.x-radius-2 if side==0 else radius+2,size.y*.5)
		for i in 33:
			var angle := -PI*.5+PI*i/32.0+PI*side
			focus_outline.append(center+Vector2.from_angle(angle)*radius)
	if not focus_outline.is_empty():focus_outline.append(focus_outline[0])

func _process(dt: float) -> void:
	if not is_visible_in_tree(): return
	ember_time+=dt
	if normal:normal.modulate_color=Color.WHITE if has_focus() else Color(.75,.72,.68)
	queue_redraw()

func _draw() -> void:
	if not has_focus():return
	if focus_outline.size()>2:
		draw_polyline(focus_outline,Color(1,.2,.01,.12),24,true)
		draw_polyline(focus_outline,Color(1,.3,.01,.2),13,true)
		draw_polyline(focus_outline,Color(1,.47,.025,.65),5,true)
		draw_polyline(focus_outline,Color(1,.89,.45,.95),1.8,true)
	for i in 14:
		var life := fposmod(ember_time*.55+i*.618,1)
		var p := Vector2(25+fposmod(i*91.0,size.x-50),-2-life*21)
		draw_circle(p,1.3,Color(1,.67,.12,sin(life*PI)))
	draw_circle(Vector2(26,size.y*.5),3,Color("ffe49c"))
