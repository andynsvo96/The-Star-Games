class_name GameResourceHand
extends Button

# An inspectable icon-only inventory. Callers supply permitted quantities.
var items: Array = []
var amounts: Array[Label] = []
var compact := false

func _ready() -> void:
	tooltip_text = ""; custom_minimum_size = Vector2(220,102)
	for state in ["normal","hover","pressed","disabled"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
	resized.connect(_layout)

func set_items(values: Array) -> void:
	items = values
	while amounts.size() < items.size():
		var label := Label.new(); label.mouse_filter = Control.MOUSE_FILTER_IGNORE; label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_override("font",GameLook.interface_font()); label.add_theme_font_size_override("font_size",18); label.add_theme_color_override("font_color",Color("19384c")); add_child(label); amounts.append(label)
	var description := PackedStringArray()
	for index in amounts.size():
		amounts[index].visible = index < items.size()
		if index < items.size(): amounts[index].text = str(items[index].amount); description.append("%s: %s" % [items[index].label,items[index].amount])
	accessibility_name = ", ".join(description)+". Inspect resources and production"; _layout()

func card_rect(index: int) -> Rect2:
	var step := size.x/maxi(1,items.size())
	return Rect2(Vector2(index*step+3,18 if compact else 22),Vector2(maxf(20,step-8),size.y-(23 if compact else 28)))

func _layout() -> void:
	custom_minimum_size = Vector2(220,56 if compact else 102)
	for index in mini(items.size(),amounts.size()):
		var card := card_rect(index); amounts[index].position = Vector2(card.end.x-23,4); amounts[index].size = Vector2(28,28)
	queue_redraw()

func _draw() -> void:
	for index in items.size():
		var rect := card_rect(index); var color: Color = items[index].get("color",Color("b8d0da"))
		draw_style_box(GameLook.box(color.darkened(.28),color.lightened(.35),4,1),Rect2(rect.position+Vector2(0,2),rect.size+Vector2(2,2)))
		draw_style_box(GameLook.box(color,color.lightened(.4),4,2),rect)
		var texture: Texture2D = items[index].get("texture")
		if texture: GameLook.draw_texture_contained(self,texture,Rect2(rect.position+(Vector2(3,4) if compact else Vector2(6,12)),rect.size-(Vector2(6,8) if compact else Vector2(12,22))))
		var amount: Label = amounts[index]
		draw_circle(amount.position+amount.size/2,14,Color("e6ebed"),true,-1,true)
