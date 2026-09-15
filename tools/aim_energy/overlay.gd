extends Control

const COLORS = [Color("59c6ff"),Color("ffd167"),Color("65ed9a"),Color("ff7887")]
var demo
var font: Font = ThemeDB.fallback_font

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE

func project(p: Vector2, height: float=.12) -> Vector2:
	return demo.arena.screen_point(p,height)

func label(value: String, at: Vector2, font_size: int, color: Color=Color("f5e8ce")) -> void:
	draw_string_outline(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,5,Color("10151d",.95))
	draw_string(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func path(samples: Array, color: Color, is_guide: bool=false) -> void:
	var traveled := 0.0
	for i in range(1,samples.size()):
		var a: Vector2=samples[i-1].p;var b: Vector2=samples[i].p
		var length := a.distance_to(b)
		var pieces := maxi(1,ceili(length/.018))
		for part in pieces:
			var f:=float(part)/pieces
			var d:=traveled+length*f
			if d<.47 or fposmod(d,.27)>.16:continue
			var speed := lerpf(float(samples[i-1].speed),float(samples[i].speed),f)
			var energy := smoothstep(1.7,8.0,speed)
			var alpha := lerpf(.16,.98,energy)
			var width := lerpf(1.0,3.4,energy)
			if is_guide:alpha=.23;width=1.0
			var start := project(a.lerp(b,f));var end := project(a.lerp(b,float(part+1)/pieces))
			draw_line(start,end,Color("0c1521",alpha*.8),width+2.0,true)
			if not is_guide and energy>.1:draw_line(start,end,Color(color,alpha*.13),width+5.0,true)
			draw_line(start,end,Color(color,alpha),width,true)
		traveled+=length

func _draw() -> void:
	if demo==null or demo.sim==null:return
	var sim=demo.sim
	draw_rect(Rect2(0,0,1280,88),Color("0b101a",.86))
	label("ПРИЦЕЛ И СИЛА · ПРОБНЫЙ ВАРИАНТ",Vector2(30,33),22)
	var titles := ["30% · лёгкий бросок", "70% · сильный бросок", "100% · полный заряд", "4 игрока · общий залп"]
	label(titles[demo.chapter],Vector2(30,65),23,COLORS[0] if demo.chapter<3 else Color("ffd167"))
	label("НАБОР ЗАРЯДА" if demo.aiming else "БРОСОК",Vector2(1010,56),19)
	if demo.aiming:
		for id in demo.guide.paths:path(demo.guide.paths[id],COLORS[id],true)
		for id in demo.traces.paths:path(demo.traces.paths[id],COLORS[id])
		for p in sim.players:
			var id:=int(p.id);var center:Vector2=sim.pos(p)
			var arc:=PackedVector2Array();var fill:=PackedVector2Array()
			for i in 65:
				var at:=project(center+Vector2.from_angle(-PI*.5+float(i)/64*TAU)*.61,.06)
				arc.append(at)
				if float(i)/64<=float(p.power):fill.append(at)
			draw_polyline(arc,Color("0e1b2b",.95),7,true)
			draw_polyline(arc,Color(COLORS[id],.25),2,true)
			if fill.size()>1:draw_polyline(fill,COLORS[id],4.2,true)
			var origin:=project(center,.14);var tip:=project(center+Vector2.from_angle(float(p.angle))*.81,.14)
			var direction:Vector2=(tip-origin).normalized();var side:=direction.orthogonal()*5
			draw_polyline(PackedVector2Array([tip-direction*8+side,tip,tip-direction*8-side]),COLORS[id],2.8,true)
			label("%d%%"%roundi(float(p.power)*100),project(center)+Vector2(-19,35),18,COLORS[id])
		for contact in demo.traces.contacts:
			var id:int=int(contact.a) if int(contact.a)<4 else int(contact.b)
			if id>3:continue
			var at:=project(Vector2(contact.x,contact.z),.45)
			var strong:bool=float(contact.speed)>5
			draw_circle(at,4.5,COLORS[id],true,-1,true)
			for i in 4:
				var dir:=Vector2.from_angle(PI*.25+i*PI*.5)
				draw_line(at+dir*5,at+dir*(15 if strong else 9),COLORS[id],1.6,true)
			label("СИЛЬНЫЙ УДАР" if strong else "ЕСТЬ УРОН",at+Vector2(10,-13),15,COLORS[id])
	else:
		var impacts:=0
		for event in sim.events:
			if event.kind=="impact":impacts+=1
		label("СТОЛКНОВЕНИЯ  %d"%impacts,Vector2(30,124),22,Color("ffd167"))
		label("ПОБЕЖДЕНО  %d"%sim.kills,Vector2(30,154),18)
	draw_rect(Rect2(0,737,1280,63),Color("0b101a",.91))
	label("ЯРКАЯ ЛИНИЯ · ЕСТЬ СИЛА",Vector2(28,766),15,COLORS[0])
	label("ЗАТУХАНИЕ · ДОКАТКА",Vector2(365,766),15,Color("b3b9c0"))
	label("ТОНКИЙ СЛЕД · ОРИЕНТИР",Vector2(664,766),15,Color("8795a5"))
	label("Заряд усиливает бросок. После рикошета видна оставшаяся сила.",Vector2(28,790),14)
