extends Button
const Avatars = preload("res://scripts/avatar_catalog.gd")
const FocusFire = preload("res://scripts/focus_fire.gd")
var avatar_id := "manas"
var selected := false
var diameter := 128.0:
	set(value):
		diameter=value;update_border()
var fire

func _ready() -> void:
	custom_minimum_size = Vector2(158,160)
	for state in ["normal","hover","pressed","focus","disabled"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
	fire = FocusFire.new(); add_child(fire)
	resized.connect(update_border);update_border()

func update_border() -> void:
	if not fire:return
	fire.configure(Vector2.ONE*diameter,.8)
	fire.position = Vector2((size.x-diameter)*.5,0)-Vector2.ONE*FocusFire.PADDING

func _process(_dt: float) -> void:
	if not is_visible_in_tree(): return
	fire.visible = has_focus()
	queue_redraw()

func _draw() -> void:
	var rect := Rect2((size.x-diameter)*.5,0,diameter,diameter)
	draw_texture_rect(Avatars.texture(avatar_id),rect,false,Color(1,1,1,.45) if disabled else Color.WHITE)
	var label := Avatars.title(avatar_id)
	draw_string(ThemeDB.fallback_font,Vector2(0,diameter+24),label,HORIZONTAL_ALIGNMENT_CENTER,size.x,18,Color("ffe4ac") if has_focus() else Color("e8d7b8"))
	if selected: draw_line(Vector2(size.x*.3,diameter+31),Vector2(size.x*.7,diameter+31),Color("e9b865"),3,true)
