extends Control
var state := "idle":
	set(value):
		state = value
		queue_redraw()
var angle := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(dt: float) -> void:
	if state == "loading" and is_visible_in_tree():
		angle += dt * 5.0
		queue_redraw()

func _draw() -> void:
	var center := size / 2
	match state:
		"loading": draw_arc(center, 12, angle, angle + TAU * .75, 24, Color("e9b865"), 3, true)
		"success": draw_polyline(PackedVector2Array([center + Vector2(-12,0), center + Vector2(-3,9), center + Vector2(14,-10)]), Color("95dc9a"), 4, true)
		"error":
			draw_line(center - Vector2(10,10), center + Vector2(10,10), Color("ff867b"), 4, true)
			draw_line(center + Vector2(-10,10), center + Vector2(10,-10), Color("ff867b"), 4, true)
