extends RefCounted
const EmberButton = preload("res://scripts/ember_button.gd")
const Avatars = preload("res://scripts/avatar_catalog.gd")
const Catalog = preload("res://scripts/catalog.gd")
const PhoneConnection = preload("res://scripts/phone_connection.gd")
const RoomCode = preload("res://scripts/room_code.gd")
var hud
var network_window: PanelContainer
var network_panel: VBoxContainer
var network_button: Button
var screen := "home"
var pages: Dictionary = {}
var page_controls: Dictionary = {}
var back_buttons: Dictionary = {}
var join_choice: Button
var server_return := "network"
var busy := false
var code_editing := false
var keyboard_panel: VBoxContainer
var keyboard_input: LineEdit
var keyboard_keys: Array[Button] = []
var keyboard_delete: Button
var roster_buttons: Array[Control] = []
var roster_return: Control
var menu_device := -2
var match_address: Label
var phone_address: Label
var phone_hint: Label
var phone_panel: VBoxContainer

func make_button(label: String, parent: Node, callback: Callable) -> Button:
	var b := EmberButton.new(); b.text=label; parent.add_child(b)
	b.pressed.connect(func(): hud.game.arena.sound("ui"); callback.call())
	b.focus_entered.connect(func(): hud.game.arena.sound("ui"))
	b.custom_minimum_size.y=68
	return b

func page(id: String, title: String, subtitle: String) -> VBoxContainer:
	var box := VBoxContainer.new();box.custom_minimum_size.x=700
	box.add_theme_constant_override("separation",12);network_window.add_child(box)
	pages[id]=box;page_controls[id]=[]
	hud.label_node(title,box,28,hud.gold)
	if subtitle!="":
		var note= hud.label_node(subtitle,box,18,hud.cream)
		note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	box.hide();return box

func action(id: String, label: String, callback: Callable) -> Button:
	var b=make_button(label,pages[id],callback)
	# Match the felt asset's proportions instead of stretching it across the panel.
	b.custom_minimum_size=Vector2(380,86)
	b.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
	page_controls[id].append(b);return b

func add_back(id: String) -> void:
	back_buttons[id]=action(id,"НАЗАД",back)

func build(owner) -> void:
	hud=owner
	hud.menu=Control.new();hud.add_child(hud.menu);hud.menu.size=Vector2(1400,650)
	hud.options_root=VBoxContainer.new();hud.options_root.size=Vector2(510,610)
	hud.options_root.add_theme_constant_override("separation",18);hud.menu.add_child(hud.options_root)
	hud.local_button=make_button("НОВАЯ ИГРА",hud.options_root,func():
		if hud.game.net.room!="":show_screen("lobby")
		else:hud.game.play_connected()
	)
	hud.local_button.custom_minimum_size.y=110;hud.local_button.add_theme_font_size_override("font_size",30)
	network_button=make_button("С ДРУЗЬЯМИ",hud.options_root,func(): show_network(true))
	network_button.custom_minimum_size.y=102;network_button.add_theme_font_size_override("font_size",26)
	network_window=PanelContainer.new();hud.menu.add_child(network_window);network_window.position=Vector2(622,-140)
	var frame=hud.style(Color(.025,.035,.05,.94),Color("80684d"))
	frame.content_margin_left=40;frame.content_margin_right=40;frame.content_margin_top=32;frame.content_margin_bottom=32
	network_window.add_theme_stylebox_override("panel",frame)
	page("network","С ДРУЗЬЯМИ","До четырёх игроков: рядом на одном ТВ, с телефона или с другого ТВ через интернет.")
	hud.connect_button=action("network","СОЗДАТЬ ИГРУ",func(): hud.connect_room(true))
	join_choice=action("network","ПОДКЛЮЧИТЬСЯ",func(): show_screen("join"))
	action("network","СЕРВЕР",func(): server_return="network";show_screen("server"));add_back("network")
	network_panel=page("join","ПОДКЛЮЧИТЬСЯ","Введите код с экрана ведущего: шесть цифр.")
	hud.code_field=LineEdit.new();hud.code_field.placeholder_text="482731";hud.code_field.max_length=6
	hud.code_field.custom_minimum_size.y=64;hud.code_field.add_theme_font_size_override("font_size",32)
	network_panel.add_child(hud.code_field);page_controls.join.append(hud.code_field)
	build_keyboard()
	var lobby=page("lobby","КОМНАТА ОЖИДАНИЯ","Код общей игры для другого ТВ. Телефоны остаются подключены к своему ТВ.")
	lobby.add_theme_constant_override("separation",12)
	hud.room_label=hud.label_node("",lobby,56,hud.cream);hud.room_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	match_address=hud.label_node("",lobby,20,hud.gold);match_address.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	hud.start_button=action("lobby","НАЧАТЬ ОБЩИЙ МАТЧ",func(): hud.game.play_connected())
	action("lobby","ПОКИНУТЬ КОМНАТУ",func(): hud.game.net.disconnect_room();busy=false;show_screen("network"))
	var server=page("server","СЕРВЕР","Все ТВ и телефоны должны подключаться к одному серверу. Для игры из разных квартир нужен его публичный адрес.")
	hud.url_field=LineEdit.new();hud.url_field.text=hud.game.relay_url;hud.url_field.custom_minimum_size.y=56;server.add_child(hud.url_field);page_controls.server.append(hud.url_field)
	action("server","СОХРАНИТЬ",func(): hud.game.relay_url=hud.url_field.text.strip_edges();hud.game.save_settings();show_screen(server_return));add_back("server")
	phone_panel=VBoxContainer.new();hud.menu.add_child(phone_panel)
	phone_panel.position=Vector2(0,394);phone_panel.custom_minimum_size.x=510
	phone_panel.add_theme_constant_override("separation",12)
	hud.label_node("ТЕЛЕФОН ВМЕСТО ГЕЙМПАДА",phone_panel,19,hud.gold)
	phone_address=hud.label_node("",phone_panel,26,hud.cream);phone_address.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	phone_hint=hud.label_node("Подключение телефонов запускается…",phone_panel,17,hud.gold);phone_hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	build_roster()
	hud.message_label=hud.label_node("",pages.network,17,hud.cream);hud.message_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	hud.message_label.hide();show_screen("home")

func show_screen(id: String, clear_message: bool = true) -> void:
	screen=id;code_editing=id=="join"
	for key in pages: pages[key].visible=key==id
	network_window.visible=id!="home"
	update_phone_connection()
	roster_return=null
	if hud.message_label:
		if clear_message:hud.message_label.text=""
		if id!="home":
			hud.message_label.reparent(pages[id]);hud.message_label.visible=not hud.message_label.text.is_empty()
	if id=="lobby":
		hud.start_button.visible=hud.game.net.is_host
		update_phone_connection()
	refresh()
	var controls=visible_controls()
	if not controls.is_empty(): controls[0].grab_focus()
	if id=="join":focus_code_key()

func show_network(show: bool) -> void:
	show_screen(("lobby" if hud.game.net.room!="" else "network") if show else "home")

func refresh() -> void:
	if hud.connect_button:
		hud.connect_button.disabled=busy;hud.join_button.disabled=busy or not RoomCode.valid(hud.code_field.text)
		hud.connect_button.text="СОЗДАЁМ…" if busy else "СОЗДАТЬ ИГРУ"
		hud.join_button.text="ПОДКЛЮЧАЕМСЯ…" if busy else "ПОДКЛЮЧИТЬСЯ"
	if hud.message_label: hud.message_label.visible=not hud.message_label.text.is_empty()
	if screen=="lobby":
		hud.start_button.visible=hud.game.net.is_host
		hud.start_button.disabled=hud.game.net.roster.is_empty()
	for slot in roster_buttons.size():
		var button:=roster_buttons[slot]
		var available:=local_seat_for_slot(slot)>=0 and screen not in ["join","server"]
		if button.has_focus() and not available: leave_roster()
		button.visible=available
		button.tooltip_text="← → — сменить аватар · ↑ — к меню"
	network_window.size.y=network_window.get_combined_minimum_size().y
	# Leave room above the player strip, including connection/error messages.
	network_window.position.y=minf(-140,402-network_window.size.y)

func update_phone_connection() -> void:
	if phone_address == null: return
	var shared: Dictionary = PhoneConnection.describe(hud.game.net.server_url, IP.get_local_addresses())
	match_address.visible=not shared.urls.is_empty()
	match_address.text="ДРУГОЙ ТВ · " + str(shared.urls[0]).replace("https://","wss://").replace("http://","ws://") if not shared.urls.is_empty() else ""
	var hub = hud.game.controller_hub
	var source = hub.net if hub != null else hud.game.net
	var endpoint: String = hub.relay.browser_url if hub != null and hub.relay.browser_url != "" else source.server_url
	var info: Dictionary = PhoneConnection.describe(endpoint, IP.get_local_addresses())
	var address_text: String = "\n".join(info.urls)
	var hint: String
	if hub != null and hub.status != "": hint=hub.status
	elif info.urls.is_empty(): hint="Адрес для телефона недоступен. Проверьте подключение ТВ к сети."
	else: hint=("Телефон подключите к сети ТВ. " if info.local else "") + "Откройте адрес в браузере и нажмите «Подключить»."
	phone_address.text=address_text;phone_address.visible=not address_text.is_empty()
	phone_hint.text=hint

func connected() -> void:
	busy=false
	if screen in ["network","join"]: show_screen("lobby")
	hud.room_label.text=hud.game.net.room
	update_phone_connection()
	if screen=="lobby":hud.message_label.text="" if hud.game.net.is_host else "Вы подключены. Игру начнёт ведущий."
	refresh()

func connection_failed(reason: String) -> void:
	busy=false
	if screen=="home" or screen=="lobby": show_screen("network")
	hud.message_label.text=reason;refresh()

func visible_controls() -> Array:
	var controls: Array=[]
	if screen=="home":return [hud.local_button,network_button]
	for node in page_controls.get(screen,[]):
		if node.is_visible_in_tree() and not (node is BaseButton and node.disabled): controls.append(node)
	return controls

func navigate(direction: Vector2) -> void:
	var focus=hud.get_viewport().gui_get_focus_owner()
	if roster_buttons.has(focus):
		if direction.y<0: leave_roster()
		elif direction.x!=0: cycle_avatar(int(signf(direction.x)))
		return
	var controls=visible_controls()
	if controls.is_empty():return
	if not controls.has(focus):controls[0].grab_focus();return
	var origin: Vector2=focus.get_global_rect().get_center()
	var best=null;var best_score:=INF
	for candidate in controls:
		if candidate==focus:continue
		var offset:Vector2=candidate.get_global_rect().get_center()-origin
		var forward:=offset.dot(direction)
		if forward<4:continue
		# Only consider controls in the requested direction's cone.
		var sideways:=absf(offset.cross(direction))
		if sideways>forward*1.5:continue
		var score:=forward+sideways*3.0
		if score<best_score:best_score=score;best=candidate
	if best!=null:best.grab_focus()
	elif direction.y>0: focus_roster()

func accept() -> void:
	var focus=hud.get_viewport().gui_get_focus_owner()
	if roster_buttons.has(focus): cycle_avatar(1)
	elif focus==keyboard_input:focus_code_key()
	elif focus is BaseButton and not focus.disabled:focus.pressed.emit()

func back() -> void:
	if roster_buttons.has(hud.get_viewport().gui_get_focus_owner()):leave_roster();return
	if busy:hud.game.net.disconnect_room();busy=false
	match screen:
		"join":show_screen("network")
		"server":show_screen(server_return)
		"lobby":show_screen("home")
		_:show_screen("home")

func build_keyboard() -> void:
	keyboard_panel=network_panel;keyboard_input=hud.code_field
	keyboard_input.virtual_keyboard_type=LineEdit.KEYBOARD_TYPE_NUMBER
	keyboard_input.text_changed.connect(func(_value: String): sync_code())
	var grid:=GridContainer.new();grid.columns=3;grid.add_theme_constant_override("h_separation",10);grid.add_theme_constant_override("v_separation",8);keyboard_panel.add_child(grid)
	for character in "1234567890":
		if character=="0":grid.add_child(Control.new())
		var key=make_button(character,grid,func():type_code(character))
		key.custom_minimum_size=Vector2(0,58);key.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		keyboard_keys.append(key);page_controls.join.append(key)
	keyboard_delete=make_button("BACKSPACE",grid,erase_code);keyboard_delete.custom_minimum_size=Vector2(0,58)
	keyboard_delete.size_flags_horizontal=Control.SIZE_EXPAND_FILL;page_controls.join.append(keyboard_delete)
	var actions:=HBoxContainer.new();actions.add_theme_constant_override("separation",16);keyboard_panel.add_child(actions)
	hud.join_button=make_button("ПОДКЛЮЧИТЬСЯ",actions,func(): hud.connect_room(false))
	back_buttons.join=make_button("НАЗАД",actions,back)
	for button in [hud.join_button,back_buttons.join]:
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;button.custom_minimum_size.y=76
		page_controls.join.append(button)

func focus_code_key() -> void:
	keyboard_keys[0].grab_focus()

func sync_code() -> void:
	var code: String=""
	for character in keyboard_input.text:
		if RoomCode.DIGITS.contains(character):code+=character
	if keyboard_input.text!=code:
		var caret:=keyboard_input.caret_column
		keyboard_input.text=code;keyboard_input.caret_column=mini(caret,code.length())
	hud.join_button.disabled=busy or not RoomCode.valid(code)

func type_code(character: String) -> void:
	var before:=keyboard_input.text;var caret:=keyboard_input.caret_column
	keyboard_input.insert_text_at_caret(character.to_upper())
	if not RoomCode.valid_prefix(keyboard_input.text):keyboard_input.text=before;keyboard_input.caret_column=caret;return
	sync_code()
	if not hud.join_button.disabled:hud.join_button.grab_focus()

func erase_code() -> void:
	if keyboard_input.has_selection():keyboard_input.delete_text(keyboard_input.get_selection_from_column(),keyboard_input.get_selection_to_column())
	elif keyboard_input.caret_column>0:keyboard_input.delete_char_at_caret()
	sync_code()

func keyboard_event(event: InputEventKey) -> bool:
	if not code_editing or keyboard_input.has_focus():return false
	if event.keycode==KEY_BACKSPACE:erase_code();return true
	if event.unicode>=32 and not event.ctrl_pressed and not event.meta_pressed:
		var character:=String.chr(event.unicode).to_upper()
		if RoomCode.DIGITS.contains(character):type_code(character);return true
	return false

func build_roster() -> void:
	for slot in 4:
		var button:=Button.new()
		button.position=Vector2(830+slot*198-88,780)-Vector2(88,350)
		button.size=Vector2(176,174)
		button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
		for state in ["normal","hover","pressed","focus","disabled"]:
			button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
		hud.menu.add_child(button);roster_buttons.append(button)
		button.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed:
				menu_device=-2
				remember_menu_focus()
		)
		button.pressed.connect(func():
			menu_device=-2
			var side: float=button.get_local_mouse_position().x-button.size.x/2
			cycle_avatar(-1 if side<0 else 1)
		)

# Server slots can be interleaved between households. Resolve ownership before
# mapping a displayed slot back to this TV's stable controller seat.
func local_seat_for_slot(slot: int) -> int:
	var seats: Array=hud.game.active_local_seats()
	if hud.game.net.connected and hud.game.net.room!="":
		var owned:=false
		for player in hud.game.net.roster:
			if int(player.slot)==slot and str(player.owner)==hud.game.net.peer_id:owned=true
		if not owned:return -1
		var index: int=hud.game.local_slots.find(slot)
		return int(seats[index]) if index>=0 and index<seats.size() and hud.game.native_local_seats().has(seats[index]) else -1
	return slot if hud.game.native_local_seats().has(slot) else -1

func input_seat() -> int:
	if menu_device>=0:return int(hud.game.pad_slots.get(menu_device,-1))
	if menu_device==-1:return 0 if hud.game.keyboard_seat else -1
	var focused: int=roster_buttons.find(hud.get_viewport().gui_get_focus_owner())
	if focused>=0:return local_seat_for_slot(focused)
	var seats: Array=hud.game.native_local_seats()
	return int(seats[0]) if not seats.is_empty() else -1

func remember_menu_focus() -> void:
	var focus=hud.get_viewport().gui_get_focus_owner()
	if visible_controls().has(focus):roster_return=focus

func focus_roster() -> void:
	if screen in ["join","server"]:return
	var seat:=input_seat()
	for slot in roster_buttons.size():
		if seat>=0 and local_seat_for_slot(slot)==seat:
			remember_menu_focus()
			roster_buttons[slot].show();roster_buttons[slot].grab_focus()
			return

func leave_roster() -> void:
	var controls:=visible_controls()
	if is_instance_valid(roster_return) and controls.has(roster_return):roster_return.grab_focus()
	elif not controls.is_empty():controls.back().grab_focus()

func cycle_avatar(step: int) -> void:
	var seat:=input_seat()
	if seat<0:return
	focus_roster()
	var slot: int=roster_buttons.find(hud.get_viewport().gui_get_focus_owner())
	if slot<0 or local_seat_for_slot(slot)!=seat:return
	var index:=posmod(Avatars.index(hud.game.local_avatars[seat])+step,Avatars.IDS.size())
	hud.game.set_local_avatar(seat,Avatars.IDS[index])
	hud.game.arena.sound("ui")

func draw() -> void:
	# Keep the live hearth visible beside a felt menu wing.
	hud.draw_texture_rect(hud.reward_screen.Wool,Rect2(0,0,660,1000),false,Color("161d2b"))
	hud.draw_rect(Rect2(0,0,660,1000),Color(.01,.015,.025,.32))
	for y in range(18,980,22): hud.draw_line(Vector2(641,y),Vector2(646,y+10),Color("947350"),3,true)
	hud.text_at("В О Й Л О Ч Н Ы Е   Л Е Г Е Н Д Ы",Vector2(88,95),16,hud.gold)
	hud.text_at("ORDO",Vector2(78,228),116,hud.cream)
	hud.text_at("Х Р А Н И Т Е Л И   О Ч А Г А",Vector2(88,273),21,hud.gold)
	hud.draw_texture_rect(hud.reward_screen.Wool,Rect2(685,768,885,190),false,Color(.065,.075,.09,.96))
	# Four persistent seats make controller joins visible even inside network setup.
	var roster: Dictionary=hud.game.menu_roster()
	for id in 4:
		var center := Vector2(830+id*198,858)
		var connected: bool = roster.has(id)
		var focused: bool=roster_buttons[id].has_focus()
		if focused:
			hud.reward_screen.fire_ring(hud,center,44,.65)
			hud.text_at("‹",center+Vector2(-83,10),34,hud.gold)
			hud.text_at("›",center+Vector2(65,10),34,hud.gold)
		if connected: hud.draw_texture_rect(Avatars.texture(hud.game.avatar_for_player(id)),Rect2(center-Vector2.ONE*46,Vector2.ONE*92),false)
		else:
			hud.draw_circle(center,40,Color("222831"));hud.draw_arc(center,40,0,TAU,48,Color("645747"),2,true)
			hud.text_at("+",center+Vector2(-15,11),30,Color("8b8173"),HORIZONTAL_ALIGNMENT_CENTER,30)
		hud.text_at("P%d"%(id+1),center+Vector2(-70,-62),20,Catalog.COLORS[id],HORIZONTAL_ALIGNMENT_CENTER,140)
		var label: String=Avatars.title(hud.game.avatar_for_player(id)) if connected else "НАЖМИТЕ КНОПКУ"
		hud.text_at(label,center+Vector2(-96,66),16,hud.gold if connected else Color("b4ac9f"),HORIZONTAL_ALIGNMENT_CENTER,192)
		if connected: hud.text_at(roster[id],center+Vector2(-96,88),11,Color("b4ac9f"),HORIZONTAL_ALIGNMENT_CENTER,192)
