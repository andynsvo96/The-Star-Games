class_name GamePlayerRow
extends Button

# Compact, inspectable public identity with module-supplied icon/count pairs.
var player := {}
var active := false
var compact := false
var detailed := false
var show_labels := false
var grid_counters := false
var dense := false
var active_identity_outline := false
var dark := false
var leader := ""
var headline := {}
var headline_value := Label.new()
var metrics: Array = []
var name_label := Label.new()
var values: Array[Label] = []
var captions: Array[Label] = []

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(164,72); tooltip_text = ""
	for state in ["normal","hover","pressed","disabled"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
	name_label.clip_text = true; name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_font_size_override("font_size",13); name_label.add_theme_color_override("font_color",GameLook.SCROLL_INK)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(name_label)
	headline_value.mouse_filter = Control.MOUSE_FILTER_IGNORE; headline_value.add_theme_color_override("font_color",GameLook.SCROLL_INK); add_child(headline_value); headline_value.hide()
	resized.connect(_layout)
	_layout()

func set_player(identity: Dictionary, counters: Array, current := false, headline_metric: Dictionary = {}) -> void:
	player = identity; metrics = counters; active = current; headline = headline_metric
	var ink := GameLook.CREAM if dark else GameLook.SCROLL_INK
	name_label.add_theme_color_override("font_color",GameLook.readable_text_color(Color(str(identity.get("color","#58d6ff"))),Color("061d30")) if dark else ink)
	headline_value.add_theme_color_override("font_color",ink)
	headline_value.text = str(headline.get("value",""))
	name_label.text = str(player.get("display_name",""))
	while values.size() < metrics.size():
		var label := Label.new(); label.mouse_filter = Control.MOUSE_FILTER_IGNORE; label.add_theme_font_size_override("font_size",12); label.add_theme_color_override("font_color",GameLook.SCROLL_INK); add_child(label); values.append(label)
		var caption := Label.new(); caption.mouse_filter = Control.MOUSE_FILTER_IGNORE; caption.clip_text = true; caption.add_theme_color_override("font_color",GameLook.SCROLL_INK); add_child(caption); captions.append(caption)
	var description := PackedStringArray([name_label.text,"Current turn" if active else "Player details"])
	if not leader.is_empty(): description.append("Joint leader" if leader == "silver" else "Leader")
	if not headline.is_empty(): description.append(str(headline.get("label",""))+": "+headline_value.text)
	for index in values.size():
		values[index].add_theme_color_override("font_color",ink); captions[index].add_theme_color_override("font_color",ink)
		values[index].visible = index < metrics.size()
		if index < metrics.size():
			values[index].text = str(metrics[index].value); description.append(str(metrics[index].get("label",""))+": "+values[index].text)
			captions[index].text = str(metrics[index].get("caption",metrics[index].get("label","")))
	accessibility_name = ", ".join(description); _layout()

func _layout() -> void:
	headline_value.visible = grid_counters and not headline.is_empty()
	if grid_counters:
		custom_minimum_size = Vector2(96,64 if dense else 72) if compact and not detailed else Vector2(264,76 if dense else 92 if compact else 104)
		var small := compact and not detailed
		var columns := 3
		var left := 32.0 if small else 50.0
		var headline_font := 14 if small else 21 if compact else 25
		var value_width := maxf(19 if small else 29,headline_value.get_theme_font("font").get_string_size(headline_value.text,HORIZONTAL_ALIGNMENT_LEFT,-1,headline_font).x+2)
		var badge := value_width+(20 if small else 34)
		name_label.position = Vector2(left,4 if small else 7); name_label.size = Vector2(maxf(0,size.x-left-badge-7),23)
		name_label.add_theme_font_size_override("font_size",10 if small else 13 if compact else 15)
		headline_value.position = Vector2(size.x-value_width-5,3 if small else 5); headline_value.size = Vector2(value_width,24 if small else 30)
		headline_value.add_theme_font_size_override("font_size",14 if small else 21 if compact else 25)
		var step := (size.x-(12 if small else 20))/float(columns)
		for index in values.size():
			var origin := Vector2((6 if small else 12)+(index%columns)*step,(29 if dense and small else 32 if dense else 31 if small else 39)+(index/columns)*(16 if dense and small else 22 if dense else 18 if small else 26 if compact else 30))
			values[index].visible = index < mini(6,metrics.size()); values[index].position = origin+Vector2(14 if small else 28,-2)
			values[index].size = Vector2(maxf(12,step-(14 if small else 28)),18 if small else 25)
			values[index].add_theme_font_size_override("font_size",11 if dense and small else 16 if dense else 12 if small else 18 if compact else 21)
			var fit_size := values[index].get_theme_font_size("font_size")
			var counter_width := maxf(12,step-(14 if small else 28))
			while fit_size > 8 and values[index].get_theme_font("font").get_string_size(values[index].text,HORIZONTAL_ALIGNMENT_LEFT,-1,fit_size).x > counter_width: fit_size -= 1
			values[index].add_theme_font_size_override("font_size",fit_size)
			values[index].size.x = counter_width
			captions[index].hide()
		queue_redraw(); return
	if detailed:
		custom_minimum_size = Vector2(264,92 if compact else 116)
		name_label.position = Vector2(50,7); name_label.size = Vector2(maxf(0,size.x-62),25)
		name_label.add_theme_font_size_override("font_size",13 if compact else 15)
		var step := (size.x-20)/3.0
		var height := 26.0 if compact else 35.0
		for index in values.size():
			var origin := Vector2(12+(index%3)*step,38+(index/3)*height)
			values[index].visible = index < metrics.size(); values[index].position = origin+Vector2(27,-4); values[index].size = Vector2(step-29,23)
			values[index].add_theme_font_size_override("font_size",16 if compact else 20)
			captions[index].visible = index < metrics.size(); captions[index].position = origin+Vector2(27,13); captions[index].size = Vector2(step-28,14)
			captions[index].add_theme_font_size_override("font_size",9 if compact else 10)
		queue_redraw(); return
	custom_minimum_size = Vector2(96,54) if compact else Vector2(164,72)
	if show_labels: custom_minimum_size.y += 12
	name_label.position = Vector2(34,4) if compact else Vector2(44,9); name_label.size = Vector2(maxf(0,size.x-(40 if compact else 52)),24)
	name_label.add_theme_font_size_override("font_size",11 if compact else 13)
	var count := mini(3,metrics.size()) if compact else metrics.size()
	var step := (size.x-16)/maxi(1,count)
	for index in values.size():
		values[index].visible = index < count
		values[index].position = Vector2(9+index*step+16,30 if compact else 43); values[index].size = Vector2(maxf(12,step-16),20)
		values[index].add_theme_font_size_override("font_size",12)
		captions[index].visible = show_labels and index < count
		captions[index].position = Vector2(7+index*step,47 if compact else 60); captions[index].size = Vector2(step,13)
		captions[index].add_theme_font_size_override("font_size",8 if compact else 9)
	queue_redraw()

func _draw() -> void:
	var identity := Color(str(player.get("color","#58d6ff")))
	var surface: StyleBox = GameLook.asset_player_sheet(identity,active,compact) if dark else GameLook.box(GameLook.CREAM,identity if active and active_identity_outline else Color("e9b94f") if active else GameLook.WOOD_EDGE,8,3 if active else 1)
	draw_style_box(surface,Rect2(Vector2.ONE*2,size-Vector2.ONE*4))
	draw_style_box(GameLook.box(identity,identity,2,0),Rect2(Vector2(3,10),Vector2(4,size.y-20)))
	GameLook.draw_table_avatar(self,Rect2(10,6,32,32) if detailed else Rect2(8,5,22,22) if compact else Rect2(10,8,29,29),identity,int(player.get("pose",0)))
	if leader in ["gold","silver"]:
		var crown := RuntimeAssets.texture("res://ui/playful/table-crown%s.svg" % ("-silver" if leader == "silver" else ""))
		GameLook.draw_texture_contained(self,crown,Rect2(8,-5,26,16) if compact and not detailed else Rect2(10,-7,32,20))
	if grid_counters:
		var small := compact and not detailed
		var columns := 3
		var symbol: Texture2D = headline.get("texture")
		if symbol: draw_texture_rect(symbol,Rect2(Vector2(headline_value.position.x-(18 if small else 29),6 if small else 8),Vector2.ONE*(15 if small else 26)),false)
		var step := (size.x-(12 if small else 20))/float(columns)
		for index in mini(6,metrics.size()):
			var texture: Texture2D = metrics[index].get("texture")
			var bounds := Rect2(Vector2((6 if small else 12)+(index%columns)*step,(29 if dense and small else 32 if dense else 31 if small else 39)+(index/columns)*(16 if dense and small else 22 if dense else 18 if small else 26 if compact else 30)),Vector2.ONE*(13 if small else 20 if dense else 22 if compact else 26))
			if metrics[index].get("highlighted",false): draw_style_box(GameLook.box(Color("ffe49a33"),Color("dfa823"),4,2),bounds.grow(2))
			if texture: GameLook.draw_texture_contained(self,texture,bounds)
		return
	if detailed:
		var step := (size.x-20)/3.0
		for index in metrics.size():
			var texture: Texture2D = metrics[index].get("texture")
			if texture: GameLook.draw_texture_contained(self,texture,Rect2(Vector2(12+(index%3)*step,39+(index/3)*(26 if compact else 35)),Vector2.ONE*(22 if compact else 26)))
		return
	var count := mini(3,metrics.size()) if compact else metrics.size()
	var step := (size.x-16)/maxi(1,count)
	for index in count:
		var texture: Texture2D = metrics[index].get("texture")
		if texture: GameLook.draw_texture_contained(self,texture,Rect2(9+index*step,32 if compact else 45,14,16))
