class_name GameResourceHand
extends Button

# An inspectable icon-only inventory. Callers supply permitted quantities.
var items: Array = []
var amounts: Array[Label] = []
var compact := false
var inspect_caption := "Inspect resources and production"

func _ready() -> void:
	tooltip_text = ""; custom_minimum_size = Vector2(220,102)
	for state in ["normal","hover","pressed","disabled"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
	resized.connect(_layout)

func set_items(values: Array) -> void:
	items = values
	while amounts.size() < items.size():
		var label := Label.new(); label.mouse_filter = Control.MOUSE_FILTER_IGNORE; label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_override("font",GameLook.interface_font()); label.add_theme_font_size_override("font_size",16); label.add_theme_color_override("font_color",Color("19384c")); add_child(label); amounts.append(label)
	var description := PackedStringArray()
	for index in amounts.size():
		amounts[index].visible = index < items.size()
		if index < items.size():
			amounts[index].text = str(items[index].amount); amounts[index].modulate.a = .38 if int(items[index].amount) == 0 and not items[index].has("card") else 1.0
			amounts[index].visible = not items[index].has("card") or int(items[index].amount) > 0
			description.append("%s: %s" % [items[index].label,items[index].amount])
	accessibility_name = ", ".join(description)+". "+inspect_caption; _layout()

func card_rect(index: int) -> Rect2:
	var step := size.x/maxi(1,items.size())
	return Rect2(Vector2(index*step+3,18 if compact else 22),Vector2(maxf(20,step-8),size.y-(23 if compact else 28)))

func _layout() -> void:
	custom_minimum_size = Vector2(220,56 if compact else 102)
	for index in mini(items.size(),amounts.size()):
		var diameter := 20 if compact else 24
		var card := card_rect(index); amounts[index].add_theme_font_size_override("font_size",14 if compact else 16); amounts[index].position = Vector2(card.end.x-diameter+5,6); amounts[index].size = Vector2.ONE*diameter
	queue_redraw()

func _draw() -> void:
	for index in items.size():
		var rect := card_rect(index); var color: Color = items[index].get("color",Color("b8d0da")); var alpha := .38 if int(items[index].amount) == 0 else 1.0
		if items[index].has("card"):
			paint_card(self,rect,null,Color("021b2c") if items[index].get("empty",false) else color)
			if not items[index].get("empty",false): GameCard.paint(self,rect,items[index].card,items[index].get("texture"),color)
			alpha = 1.0
		else: paint_card(self,rect,items[index].get("texture"),color,alpha)
		var amount: Label = amounts[index]
		if amount.visible: draw_circle(amount.position+amount.size/2,amount.size.x/2,Color(Color("e6ebed"),alpha),true,-1,true)

static func paint_card(canvas: CanvasItem, bounds: Rect2, texture: Texture2D, color: Color, alpha := 1.0) -> void:
	canvas.draw_style_box(GameLook.box(Color(color.darkened(.28),alpha),Color(color.lightened(.35),alpha),4,1),Rect2(bounds.position+Vector2(0,2),bounds.size+Vector2(2,2)))
	canvas.draw_style_box(GameLook.box(Color(color,alpha),Color(color.lightened(.4),alpha),4,2),bounds)
	if texture: GameLook.draw_texture_contained(canvas,texture,Rect2(bounds.position+bounds.size*Vector2(.13,.17),bounds.size*Vector2(.74,.66)),Color(1,1,1,alpha))
