class_name GameIllustratedGuide
extends VBoxContainer

# Static public examples. The enclosing phase dialog owns scrolling and Close.
var items: Array = []
var paged := false
var page := 0
var groups: Array[String] = []
var group_pages: Dictionary = {}
var tabs: HBoxContainer
var selectors: BoxContainer
var topics: OptionButton
var navigation: HBoxContainer
var previous: Button
var next: Button
var counter: Label
var lesson: GridContainer
var picture: TextureRect
var copy: VBoxContainer
signal page_changed


func set_items(examples: Array) -> void:
	if items == examples:
		return
	items = examples.duplicate(true)
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if paged:
		_build_pages()
		return
	add_theme_constant_override("separation", 24)
	for example in items:
		var section := VBoxContainer.new()
		section.add_theme_constant_override("separation", 8)
		add_child(section)
		var heading := Label.new()
		heading.text = str(example.get("heading", ""))
		heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		heading.add_theme_font_override("font", GameLook.interface_font(700))
		heading.add_theme_font_size_override("font_size", 21)
		section.add_child(heading)
		var picture := TextureRect.new()
		picture.texture = RuntimeAssets.texture(str(example.get("image", "")))
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.custom_minimum_size.y = 210
		picture.accessibility_name = str(example.get("description", ""))
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		section.add_child(picture)
		var detail := Label.new()
		detail.text = str(example.get("detail", ""))
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.add_theme_font_override("font", GameLook.interface_font())
		detail.add_theme_font_size_override("font_size", 16)
		section.add_child(detail)


func _build_pages() -> void:
	groups.clear()
	for item in items:
		var group := str(item.get("section", "Guide"))
		if group not in groups: groups.append(group)
	selectors = BoxContainer.new()
	selectors.vertical = true
	selectors.add_theme_constant_override("separation", 8)
	add_child(selectors)
	tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	selectors.add_child(tabs)
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for group in groups:
		var button := Button.new()
		button.text = group
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_override("font", GameLook.interface_font(700))
		button.add_theme_font_size_override("font_size", 13)
		button.custom_minimum_size.y = 44
		button.pressed.connect(func() -> void: select_page(int(group_pages.get(group, _indices(group)[0]))))
		tabs.add_child(button)
	topics = OptionButton.new()
	topics.custom_minimum_size.y = 44
	topics.accessibility_name = "Lesson topic"
	topics.add_theme_font_override("font", GameLook.interface_font())
	topics.item_selected.connect(func(index: int) -> void: select_page(topics.get_item_id(index)))
	selectors.add_child(topics)
	topics.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lesson = GridContainer.new()
	lesson.add_theme_constant_override("h_separation", 24)
	lesson.add_theme_constant_override("v_separation", 12)
	add_child(lesson)
	picture = TextureRect.new()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lesson.add_child(picture)
	copy = VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 12)
	lesson.add_child(copy)
	if navigation == null:
		navigation = HBoxContainer.new()
		navigation.add_theme_constant_override("separation", 8)
		previous = Button.new(); previous.text = "PREV"; previous.accessibility_name = "Previous lesson"
		next = Button.new(); next.text = "NEXT"; next.accessibility_name = "Next lesson"
		counter = Label.new(); counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; counter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		navigation.add_child(previous); navigation.add_child(counter); navigation.add_child(next)
		for button in [previous, next]:
			GameLook.board_action(button)
			button.add_theme_font_size_override("font_size", 13)
			button.add_theme_font_override("font", GameLook.interface_font(700))
		previous.pressed.connect(func() -> void: select_page(page - 1))
		next.pressed.connect(func() -> void: select_page(page + 1))
		resized.connect(_fit_page)
	select_page(clampi(page, 0, maxi(0, items.size() - 1)))


func _indices(group: String) -> Array[int]:
	var result: Array[int] = []
	for index in items.size():
		if str(items[index].get("section", "Guide")) == group: result.append(index)
	return result


func select_page(index: int) -> void:
	if items.is_empty():
		previous.disabled = true; next.disabled = true
		return
	page = clampi(index, 0, items.size() - 1)
	var item: Dictionary = items[page]
	var group := str(item.get("section", "Guide"))
	group_pages[group] = page
	for button in tabs.get_children():
		button.set_pressed_no_signal(button.text == group)
		GameLook.guide_section(button, button.text == group)
	topics.clear()
	var indices := _indices(group)
	for entry in indices: topics.add_item(str(items[entry].heading), entry)
	topics.select(indices.find(page))
	for child in copy.get_children():
		copy.remove_child(child); child.queue_free()
	for field in ["heading", "detail", "tip"]:
		if str(item.get(field, "")).is_empty(): continue
		var label := Label.new()
		label.text = str(item[field])
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_override("font", GameLook.interface_font(700 if field == "heading" else 400))
		label.add_theme_font_size_override("font_size", 23 if field == "heading" else 16)
		copy.add_child(label)
	picture.texture = RuntimeAssets.texture(str(item.get("image", "")))
	picture.accessibility_name = str(item.get("description", ""))
	counter.text = "%d / %d" % [page + 1, items.size()]
	previous.disabled = page == 0; next.disabled = page == items.size() - 1
	_fit_page()
	page_changed.emit()


func reload_artwork() -> void:
	if paged:
		if not items.is_empty(): picture.texture = RuntimeAssets.texture(str(items[page].get("image", "")))
		return
	var pictures := find_children("*", "TextureRect", true, false)
	for index in mini(pictures.size(), items.size()): pictures[index].texture = RuntimeAssets.texture(str(items[index].get("image", "")))


func _fit_page() -> void:
	if lesson == null: return
	var wide := size.x >= 580
	var short_wide := wide and get_viewport_rect().size.y < 560
	selectors.vertical = not short_wide
	lesson.columns = 2 if wide else 1
	var edge := clampf(get_viewport_rect().size.y - 230, 112, 220) if short_wide else minf(260, size.x * .46)
	picture.custom_minimum_size = Vector2(edge if wide else 0, edge if wide else clampf(size.x * .6, 140, 220))
