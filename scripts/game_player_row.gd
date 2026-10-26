class_name GamePlayerRow
extends Button

# Compact, inspectable public identity with module-supplied icon/count pairs.
var player := {}
var active := false
var compact := false
var metrics: Array = []
var name_label := Label.new()
var values: Array[Label] = []

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(164,72); tooltip_text = ""
	for state in ["normal","hover","pressed","disabled"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
	name_label.clip_text = true; name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_font_size_override("font_size",13); name_label.add_theme_color_override("font_color",GameLook.SCROLL_INK)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(name_label)
	resized.connect(_layout)
	_layout()

func set_player(identity: Dictionary, counters: Array, current := false) -> void:
	player = identity; metrics = counters; active = current
	name_label.text = str(player.get("display_name",""))
	while values.size() < metrics.size():
		var label := Label.new(); label.mouse_filter = Control.MOUSE_FILTER_IGNORE; label.add_theme_font_size_override("font_size",12); label.add_theme_color_override("font_color",GameLook.SCROLL_INK); add_child(label); values.append(label)
	var description := PackedStringArray([name_label.text,"Current turn" if active else "Player details"])
	for index in values.size():
		values[index].visible = index < metrics.size()
		if index < metrics.size():
			values[index].text = str(metrics[index].value); description.append(str(metrics[index].get("label",""))+": "+values[index].text)
	accessibility_name = ", ".join(description); _layout()

func _layout() -> void:
	custom_minimum_size = Vector2(96,54) if compact else Vector2(164,72)
	name_label.position = Vector2(34,4) if compact else Vector2(44,9); name_label.size = Vector2(maxf(0,size.x-(40 if compact else 52)),24)
	name_label.add_theme_font_size_override("font_size",11 if compact else 13)
	var count := mini(3,metrics.size()) if compact else metrics.size()
	var step := (size.x-16)/maxi(1,count)
	for index in values.size():
		values[index].visible = index < count
		values[index].position = Vector2(9+index*step+16,30 if compact else 43); values[index].size = Vector2(maxf(12,step-16),20)
	queue_redraw()

func _draw() -> void:
	var identity := Color(str(player.get("color","#58d6ff")))
	draw_style_box(GameLook.box(GameLook.CREAM,Color("e9b94f") if active else GameLook.WOOD_EDGE,8,3 if active else 1),Rect2(Vector2.ONE*2,size-Vector2.ONE*4))
	draw_style_box(GameLook.box(identity,identity,2,0),Rect2(Vector2(3,10),Vector2(4,size.y-20)))
	GameLook.draw_table_avatar(self,Rect2(8,5,22,22) if compact else Rect2(10,8,29,29),identity,int(player.get("pose",0)))
	var count := mini(3,metrics.size()) if compact else metrics.size()
	var step := (size.x-16)/maxi(1,count)
	for index in count:
		var texture: Texture2D = metrics[index].get("texture")
		if texture: draw_texture_rect(texture,Rect2(9+index*step,32 if compact else 45,14,16),false)
