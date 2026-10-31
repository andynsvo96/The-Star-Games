class_name GameReferenceGallery
extends Container

# Readable reference faces with independent flips, without an inspection step.
var entries: Array = []
var wide := false
var card_height_limit := 0.0
var grid_height := 0.0

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	resized.connect(queue_sort)

func _get_minimum_size() -> Vector2:
	return Vector2(0, grid_height)

func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN: _fit()

func set_items(items: Array) -> void:
	entries = items
	for child in get_children(): remove_child(child); child.queue_free()
	for entry: Dictionary in entries:
		var tile := Control.new(); tile.mouse_filter = Control.MOUSE_FILTER_PASS
		add_child(tile)
		tile.set_meta("reference", entry); tile.set_meta("side", "front")
		var label := Label.new(); label.name = "Caption"; label.text = str(entry.label)
		label.add_theme_font_size_override("font_size", 16); label.add_theme_color_override("font_color", Color("fff4d9"))
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; label.max_lines_visible = 2
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(label)
		var face := GameCard.new(); face.name = "Face"; face.card = {"layout":"art"}; tile.add_child(face)
		var button := Button.new(); button.name = "Flip"; button.theme = theme
		button.icon = RuntimeAssets.texture("res://ui/playful/control-rotate.svg")
		tile.add_child(button); GameLook.action(button,false); GameLook.compact_control(button,true); button.custom_minimum_size = Vector2(44,44)
		button.pressed.connect(func() -> void:
			tile.set_meta("side", "back" if tile.get_meta("side") == "front" else "front")
			_update_face(tile); queue_sort())
		_update_face(tile)
	queue_sort()

func _update_face(tile: Control) -> void:
	var entry: Dictionary = tile.get_meta("reference")
	var topic: Dictionary = entry.topic
	var side := str(tile.get_meta("side"))
	var source: Variant = topic.get(side+"_wide",topic[side]) if wide else topic[side]
	var face: GameCard = tile.get_node("Face")
	face.texture = GameCard.artwork(str(source)) if source is String else source
	face.accessibility_name = str(topic.get(side+"_label",entry.label))
	face.accessibility_description = str(topic.get(side+"_description",topic.get("description","")))
	face.queue_redraw()
	var next_side := "back" if side == "front" else "front"
	tile.get_node("Flip").accessibility_name = "Flip %s to %s" % [entry.label,topic.get(next_side+"_label",next_side)]

func _fit() -> void:
	if not is_inside_tree() or entries.is_empty(): return
	var gap := 24.0
	var columns := 1 if wide else clampi(int((size.x+gap)/384.0),1,entries.size())
	var preferred := 1050.0 if wide else 500.0
	if card_height_limit > 0:
		preferred = minf(preferred,maxf(560 if wide else 360,card_height_limit*(1280.0/500.0 if wide else 640.0/900.0)))
	var width := maxf(1,minf(preferred,(size.x-(columns-1)*gap)/columns))
	var row_heights: Array[float] = []
	for index in get_child_count():
		var tile: Control = get_child(index)
		_update_face(tile)
		var face: GameCard = tile.get_node("Face")
		var aspect := 640.0/900.0
		if face.texture != null and face.texture.get_height() > 0: aspect = float(face.texture.get_width())/face.texture.get_height()
		var row := index/columns
		if row >= row_heights.size(): row_heights.append(0)
		row_heights[row] = maxf(row_heights[row],width/aspect+52)
		face.position = Vector2(0,52); face.size = Vector2(width,width/aspect)
		var label: Label = tile.get_node("Caption"); label.position = Vector2(0,0); label.size = Vector2(maxf(1,width-56),44)
		var button: Button = tile.get_node("Flip"); button.position = Vector2(width-44,0); button.size = Vector2(44,44)
	var height := gap*maxi(0,row_heights.size()-1)
	for value in row_heights: height += value
	var top := maxf(0,(size.y-height)/2)
	for index in get_child_count():
		var row := index/columns
		var y := top+gap*row
		for previous in row: y += row_heights[previous]
		get_child(index).position = Vector2((size.x-columns*width-(columns-1)*gap)/2+(index%columns)*(width+gap),y)
		get_child(index).size = Vector2(width,row_heights[row])
	if not is_equal_approx(grid_height,height): grid_height = height; update_minimum_size()
