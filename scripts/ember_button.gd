extends Button
static var art: AtlasTexture
const FocusFire = preload("res://scripts/focus_fire.gd")
var fire
var normal: StyleBoxTexture

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
	for state in ["normal","hover","pressed","disabled"]:
		var box := StyleBoxTexture.new(); box.texture = art
		box.modulate_color = Color(.75,.72,.68) if state=="normal" else Color.WHITE
		if state=="disabled": box.modulate_color = Color(.4,.4,.4,.65)
		add_theme_stylebox_override(state,box)
		if state=="normal": normal=box
	add_theme_stylebox_override("focus",StyleBoxEmpty.new())
	fire=FocusFire.new();add_child(fire);fire.position=-Vector2.ONE*FocusFire.PADDING
	resized.connect(update_border);update_border()
	fire.visible=has_focus()

func update_border() -> void:
	if fire:fire.configure(size)

func _process(_dt: float) -> void:
	if not is_visible_in_tree(): return
	if normal:normal.modulate_color=Color.WHITE if has_focus() else Color(.75,.72,.68)
	if fire:fire.visible=has_focus()
