class_name GameDebugPanel
extends Control

signal start_requested(manifest: Dictionary, count: int, delay: float, reduced: bool)
signal exit_requested

var game_choice: OptionButton
var player_choice: OptionButton
var pace_choice: OptionButton
var reduced: CheckBox
var notice: Label
var start_button: Button
var games: Array = []
var selected_id := ""
var selected_count := 2


func configure(catalog: Array, previous_id := "", count := 2) -> void:
	selected_id = previous_id; selected_count = count
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 24)
	add_child(margin)
	var scroll := ScrollContainer.new(); scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; margin.add_child(scroll)
	var center := CenterContainer.new(); center.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.add_child(center)
	var body := VBoxContainer.new(); center.add_child(body)
	scroll.resized.connect(func() -> void: body.custom_minimum_size.x = minf(760, maxf(0, scroll.size.x - 12)))
	var back := Button.new(); back.text = "Back"; back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN; back.custom_minimum_size.x = 100; back.pressed.connect(func() -> void: exit_requested.emit()); body.add_child(back)
	var heading := Label.new(); heading.text = "AUTOPLAY DEBUG"; heading.add_theme_font_size_override("font_size", 28); body.add_child(heading)
	var description := Label.new(); description.text = "Test players play one game to completion. Profiles, standings and game preferences stay separate. Pause bots pauses their inputs; game clocks and animations continue."; description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; body.add_child(description)
	game_choice = _choice(body, "Game")
	for manifest: Dictionary in catalog:
		if manifest.has("game_choices"): continue
		games.append(manifest)
		game_choice.add_item(str(manifest.title))
		if str(manifest.id) == selected_id: game_choice.select(games.size() - 1)
	player_choice = _choice(body, "Test players")
	pace_choice = _choice(body, "Action pace")
	for caption in ["Fast (0.05 sec)", "Normal (0.25 sec)", "Slow (1 sec)"]: pace_choice.add_item(caption)
	pace_choice.select(1)
	reduced = CheckBox.new(); reduced.text = "Reduced motion"; reduced.button_pressed = true; body.add_child(reduced)
	notice = Label.new(); notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; body.add_child(notice)
	start_button = Button.new(); start_button.text = "Start autoplay"; start_button.pressed.connect(_start); body.add_child(start_button)
	game_choice.item_selected.connect(func(_index: int) -> void: _select_game())
	player_choice.item_selected.connect(func(index: int) -> void: selected_count = player_choice.get_item_id(index))
	_select_game()


func _choice(parent: Control, caption: String) -> OptionButton:
	var label := Label.new(); label.text = caption; parent.add_child(label)
	var choice := OptionButton.new(); choice.accessibility_name = caption; choice.custom_minimum_size.y = 44; parent.add_child(choice)
	return choice


func _select_game() -> void:
	player_choice.clear()
	start_button.disabled = true
	if games.is_empty():
		notice.text = "No playable modules installed. Copy Games/_Template to start a module with debug support."
		return
	var manifest: Dictionary = games[game_choice.selected]
	selected_id = str(manifest.id)
	var driver := GameDebugAdapter.for_game(manifest)
	if driver == null:
		notice.text = "This module needs host/debug.gd. See docs/DEBUG_AUTOPLAY.md for the shared adapter contract."
		return
	for value: int in driver.supported_counts(manifest):
		player_choice.add_item(str(value), value)
		if value == selected_count: player_choice.select(player_choice.item_count - 1)
	if player_choice.item_count == 0:
		notice.text = "This module has no supported test player counts."
		return
	selected_count = player_choice.get_item_id(player_choice.selected)
	start_button.disabled = false
	notice.text = "No phones required. Collections list their individual games here. Runs stop at completion or after 30 seconds without progress; the action limit is 20,000."
	if not driver.description().is_empty(): notice.text += "\n" + driver.description()


func _start() -> void:
	if start_button.disabled or games.is_empty(): return
	start_requested.emit(games[game_choice.selected], selected_count, [0.05, 0.25, 1.0][pace_choice.selected], reduced.button_pressed)
