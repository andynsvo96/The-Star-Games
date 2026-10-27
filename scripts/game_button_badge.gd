class_name GameButtonBadge
extends Control

var count := 0:
	set(value): count = maxi(0,value); visible = count > 0; queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE; z_index = 2; size = Vector2(22,22)
	get_parent().resized.connect(_place); _place()

func _place() -> void:
	position = Vector2(get_parent().size.x-17,-4)

func _draw() -> void:
	draw_circle(Vector2(11,11),10,Color("d9373f"),true,-1,true)
	var text := str(count) if count < 100 else "99+"; var font := get_theme_default_font(); var font_size := 11 if count > 9 else 13
	draw_string(font,Vector2(11-font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x/2,16),text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color.WHITE)
