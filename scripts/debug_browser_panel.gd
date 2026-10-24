class_name DebugBrowserPanel
extends Control

signal exit_requested
signal scan_requested
signal open_requested(browser_ids: PackedStringArray)

var browser_list: VBoxContainer
var browser_choices: Dictionary = {}
var player_count: Label
var connection: Label
var notice: Label
var open_button: Button
var scan_button: Button
var connection_ready := false


func configure(browsers: Array, selected: PackedStringArray, supported: bool, url: String, message: String) -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 24)
	margin.add_theme_constant_override("margin_top", 56) # Keep the music control clear.
	add_child(margin)
	var column := VBoxContainer.new(); margin.add_child(column)
	var header := HBoxContainer.new(); column.add_child(header)
	var back := Button.new(); back.text = "Back"; back.custom_minimum_size = Vector2(100, 44)
	back.pressed.connect(func() -> void: exit_requested.emit()); header.add_child(back)
	var heading := Label.new(); heading.text = "TEST"; heading.add_theme_font_size_override("font_size", 28)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL; header.add_child(heading)
	scan_button = Button.new(); scan_button.text = "Rescan"; scan_button.custom_minimum_size = Vector2(100, 44); scan_button.disabled = not supported
	scan_button.pressed.connect(func() -> void: scan_requested.emit()); header.add_child(scan_button)
	var scroll := ScrollContainer.new(); scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; column.add_child(scroll)
	var body := VBoxContainer.new(); body.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.add_child(body)
	browser_list = VBoxContainer.new(); browser_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; body.add_child(browser_list)
	var description := Label.new()
	description.text = "One selected browser = one test player. Join each controller with a different player name. Refreshing keeps that browser's connection."
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; body.add_child(description)
	connection = Label.new(); connection.text = "Connection: " + url if not url.is_empty() else "Controller server is stopped."
	connection.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; body.add_child(connection)
	player_count = Label.new(); column.add_child(player_count)
	notice = Label.new(); notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; notice.text = message; column.add_child(notice)
	open_button = Button.new(); open_button.custom_minimum_size.y = 44; open_button.pressed.connect(func() -> void: open_requested.emit(selected_browsers())); column.add_child(open_button)
	connection_ready = supported and not url.is_empty()
	set_browsers(browsers, selected)


func set_browsers(browsers: Array, selected: PackedStringArray) -> void:
	for child in browser_list.get_children():
		browser_list.remove_child(child)
		child.queue_free()
	browser_choices.clear()
	for browser: Dictionary in browsers:
		var choice := CheckBox.new()
		choice.text = str(browser.name)
		choice.custom_minimum_size.y = 44
		choice.button_pressed = selected.has(str(browser.id)) and selected_browsers().size() < LanServer.MAX_PLAYERS
		choice.toggled.connect(func(_pressed: bool) -> void: _update_selection())
		browser_list.add_child(choice)
		browser_choices[str(browser.id)] = choice
	if browsers.is_empty():
		var empty := Label.new(); empty.text = "No supported browsers detected. Install a browser, then choose Rescan."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; browser_list.add_child(empty)
	_update_selection()


func selected_browsers() -> PackedStringArray:
	var selected := PackedStringArray()
	for id: String in browser_choices:
		if browser_choices[id].button_pressed:
			selected.append(id)
	return selected


func _update_selection() -> void:
	var count := selected_browsers().size()
	player_count.text = "%d test %s selected" % [count, "player" if count == 1 else "players"]
	open_button.text = "Open %d controller%s" % [count, "" if count == 1 else "s"] if count > 0 else "Select browsers to test"
	open_button.disabled = not connection_ready or count == 0
	for choice: CheckBox in browser_choices.values():
		choice.disabled = not choice.button_pressed and count >= LanServer.MAX_PLAYERS
