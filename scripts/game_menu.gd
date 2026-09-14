extends RefCounted
const EmberButton = preload("res://scripts/ember_button.gd")
const Catalog = preload("res://scripts/catalog.gd")
var network_panel: VBoxContainer
var count_button: Button
var difficulty_button: Button
var network_button: Button
var hud
var code_editing := false
var code_cursor := 0
var code_hint: Label
const CODE_CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

func make_button(label: String, parent: Node, callback: Callable) -> Button:
	var b := EmberButton.new(); b.text = label
	parent.add_child(b)
	b.pressed.connect(func(): hud.game.arena.sound("ui"); callback.call())
	b.focus_entered.connect(func(): hud.game.arena.sound("ui"))
	return b

func build(owner) -> void:
	hud = owner
	hud.menu = Control.new(); hud.add_child(hud.menu); hud.menu.size = Vector2(1400,650)
	hud.options_root = VBoxContainer.new(); hud.options_root.size = Vector2(510,610)
	hud.options_root.add_theme_constant_override("separation",18); hud.menu.add_child(hud.options_root)
	hud.local_count = OptionButton.new()
	for i in 4: hud.local_count.add_item(str(i+1))
	hud.menu.add_child(hud.local_count); hud.local_count.hide()
	hud.difficulty = OptionButton.new()
	for label in ["УЮТНАЯ НОЧЬ","ИСПЫТАНИЕ","БУРЯ"]: hud.difficulty.add_item(label)
	hud.difficulty.selected = 1; hud.menu.add_child(hud.difficulty); hud.difficulty.hide()
	hud.local_button = make_button("ИГРАТЬ",hud.options_root,func(): hud.game.start_local(hud.local_count.selected+1,hud.difficulty.selected))
	hud.local_button.custom_minimum_size.y=110;hud.local_button.add_theme_font_size_override("font_size",30)
	network_button = make_button("С ДРУЗЬЯМИ",hud.options_root,func(): show_network(not network_panel.visible))
	network_button.custom_minimum_size.y=102;network_button.add_theme_font_size_override("font_size",26)
	var settings := HBoxContainer.new();settings.add_theme_constant_override("separation",16);hud.options_root.add_child(settings)
	count_button = make_button("",settings,func(): cycle_count(1));count_button.custom_minimum_size.x=205
	count_button.add_theme_font_size_override("font_size",17)
	difficulty_button = make_button("",settings,func(): cycle_difficulty(1));difficulty_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	difficulty_button.add_theme_font_size_override("font_size",16)
	network_panel = VBoxContainer.new(); network_panel.add_theme_constant_override("separation",10)
	network_panel.position = Vector2(580,-95); network_panel.size = Vector2(650,410); hud.menu.add_child(network_panel)
	hud.label_node("КОМНАТА ДЛЯ ТВ И ТЕЛЕФОНОВ",network_panel,22,hud.gold)
	hud.url_field = LineEdit.new(); hud.url_field.placeholder_text = "Адрес сервера"; hud.url_field.text = hud.game.relay_url
	hud.url_field.custom_minimum_size.y = 48; network_panel.add_child(hud.url_field)
	hud.connect_button = make_button("СОЗДАТЬ КОМНАТУ",network_panel,func(): hud.connect_room(true))
	var row := HBoxContainer.new(); network_panel.add_child(row)
	hud.code_field = LineEdit.new(); hud.code_field.placeholder_text = "КОД КОМНАТЫ"; hud.code_field.max_length = 6
	hud.code_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(hud.code_field)
	hud.join_button = make_button("ВОЙТИ",row,func(): hud.connect_room(false)); hud.join_button.custom_minimum_size.x = 190
	code_hint = hud.label_node("Код: A / OK — ввод с пульта или геймпада",network_panel,14,hud.gold)
	hud.room_label = hud.label_node("",network_panel,21,hud.gold)
	hud.message_label = hud.label_node("",network_panel,16,hud.cream)
	hud.message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; hud.message_label.custom_minimum_size.x = 630
	hud.start_button = make_button("НАЧАТЬ ОБЩИЙ МАТЧ",network_panel,func(): hud.game.net.send({"type":"start","difficulty":hud.difficulty.selected})); hud.start_button.hide()
	network_panel.hide(); refresh(); hud.local_button.grab_focus()

func cycle_count(direction: int) -> void:
	var minimum: int = hud.game.minimum_local_count()
	var count: int = hud.local_count.selected+1+direction
	if count > 4: count = minimum
	if count < minimum: count = 4
	hud.local_count.select(count-1); refresh()

func cycle_difficulty(direction: int) -> void:
	hud.difficulty.select(posmod(hud.difficulty.selected+direction,3)); refresh()

func refresh() -> void:
	count_button.text = "‹  ИГРОКОВ: %d  ›" % (hud.local_count.selected+1)
	difficulty_button.text = "‹  %s  ›" % hud.difficulty.get_item_text(hud.difficulty.selected)

func show_network(show: bool) -> void:
	code_editing = false
	network_panel.visible = show
	if show: hud.connect_button.grab_focus()
	else: network_button.grab_focus()

func navigate(direction: Vector2) -> void:
	var focus = hud.get_viewport().gui_get_focus_owner()
	if code_editing:
		if absf(direction.x)>0:
			code_cursor = posmod(code_cursor+int(signf(direction.x)),6)
		else:
			var code: String = hud.code_field.text
			var index := CODE_CHARS.find(code[code_cursor])
			code[code_cursor] = CODE_CHARS[posmod(index-int(signf(direction.y)),CODE_CHARS.length())]
			hud.code_field.text = code
		hud.code_field.select(code_cursor,code_cursor+1)
		return
	if absf(direction.x) > absf(direction.y):
		if focus == count_button: cycle_count(1 if direction.x>0 else -1)
		elif focus == difficulty_button: cycle_difficulty(1 if direction.x>0 else -1)
		return
	var buttons: Array = [hud.local_button,network_button,count_button,difficulty_button]
	if network_panel.visible: buttons = [hud.connect_button,hud.code_field,hud.join_button]
	if network_panel.visible and hud.start_button.visible: buttons.append(hud.start_button)
	var index := buttons.find(focus)
	buttons[posmod(index+(1 if direction.y>0 else -1),buttons.size())].grab_focus()

func draw() -> void:
	# Keep the live hearth visible beside a felt menu wing.
	hud.draw_texture_rect(hud.reward_screen.Wool,Rect2(0,0,660,1000),false,Color("161d2b"))
	hud.draw_rect(Rect2(0,0,660,1000),Color(.01,.015,.025,.32))
	for y in range(18,980,22): hud.draw_line(Vector2(641,y),Vector2(646,y+10),Color("947350"),3,true)
	hud.text_at("В О Й Л О Ч Н Ы Е   Л Е Г Е Н Д Ы",Vector2(88,95),16,hud.gold)
	hud.text_at("ORDO",Vector2(78,228),116,hud.cream)
	hud.text_at("Х Р А Н И Т Е Л И   О Ч А Г А",Vector2(88,273),21,hud.gold)
	if network_panel.visible:
		var box = hud.style(Color(.025,.035,.05,.96),Color("80684d"))
		hud.draw_style_box(box,Rect2(665,235,710,525))

	hud.draw_texture_rect(hud.reward_screen.Wool,Rect2(685,768,885,190),false,Color(.065,.075,.09,.96))
	# Four persistent seats make controller joins visible even inside network setup.
	for id in 4:
		var center := Vector2(830+id*198,858)
		var assigned: bool = hud.game.pad_slots.values().has(id)
		var active: bool = id <= hud.local_count.selected
		var connected: bool = assigned or (id==0 and hud.game.keyboard_seat)
		if connected: hud.reward_screen.fire_ring(hud,center,42,.85)
		if active: hud.reward_screen.token(hud,id,center,92)
		else:
			hud.draw_circle(center,40,Color("222831"));hud.draw_arc(center,40,0,TAU,48,Color("645747"),2,true)
			hud.text_at("+",center+Vector2(-15,11),30,Color("8b8173"),HORIZONTAL_ALIGNMENT_CENTER,30)
		hud.text_at("P%d"%(id+1),center+Vector2(-70,-62),20,Catalog.COLORS[id],HORIZONTAL_ALIGNMENT_CENTER,140)
		var label := "ПОДКЛЮЧЁН" if assigned else ("КЛАВИАТУРА" if connected else "НАЖМИТЕ КНОПКУ")
		hud.text_at(label,center+Vector2(-96,75),13,hud.gold if connected else Color("b4ac9f"),HORIZONTAL_ALIGNMENT_CENTER,192)
	hud.text_at("↑ ↓ — выбор   ·   ← → — настройка",Vector2(89,766),18,hud.cream)
	hud.text_at("A / OK — войти   ·   B / Esc — назад",Vector2(89,801),18,hud.gold)
	hud.text_at("Нажмите кнопку на каждом геймпаде",Vector2(89,882),16,Color("b4ac9f"))

func accept() -> void:
	var focus = hud.get_viewport().gui_get_focus_owner()
	if focus == hud.code_field:
		if code_editing:
			code_editing=false;hud.code_field.deselect();hud.join_button.grab_focus()
			code_hint.text="Код: A / OK — ввод с пульта или геймпада"
		else:
			code_editing=true;code_cursor=0
			var code: String = hud.code_field.text.to_upper()
			while code.length()<6:code+="A"
			hud.code_field.text=code;hud.code_field.select(0,1)
			code_hint.text="← → — символ · ↑ ↓ — изменить · A / OK — готово"
	elif focus is BaseButton: focus.pressed.emit()

func back() -> void:
	if code_editing:
		code_editing=false;hud.code_field.deselect();hud.join_button.grab_focus()
		code_hint.text="Код: A / OK — ввод с пульта или геймпада"
	else: show_network(false)
