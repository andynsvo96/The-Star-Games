class_name GameActionPreview
extends VBoxContainer

# Presentation only: options describe already-authorized public outcomes.
signal option_selected(index: int)
var selector := OptionButton.new()
var body := VBoxContainer.new()
var options: Array = []
var selected := 0
var presentation := "default"
var player_buttons: Array[Button] = []
var card_groups: Array = []
var card_grids: Array = []
var empty_choices: Array = []
var outcome: VBoxContainer

func _ready() -> void:
	add_theme_constant_override("separation", 12)
	var title := Label.new(); title.text = "Action preview"; title.add_theme_font_size_override("font_size", 20); title.add_theme_color_override("font_color", Color("eef8ff")); add_child(title)
	add_child(selector); selector.custom_minimum_size.y = 44; selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selector.item_selected.connect(func(index: int) -> void: selected = index; _render(); option_selected.emit(index))
	add_child(body); body.add_theme_constant_override("separation", 10)

func set_options(items: Array, index := 0, mode := "default") -> void:
	options = items; presentation = mode; selected = clampi(index, -1, maxi(0, items.size() - 1)); selector.clear()
	for item in items: selector.add_item(str(item.label))
	selector.visible = items.size() > 1 and not presentation in ["players", "cards"]
	if not items.is_empty() and selected >= 0: selector.select(selected)
	_render()

func _render() -> void:
	player_buttons.clear()
	card_groups.clear(); card_grids.clear(); empty_choices.clear()
	for child in body.get_children(): body.remove_child(child); child.queue_free()
	if options.is_empty(): return
	if presentation == "cards": _render_cards(); return
	if presentation == "players":
		for index in options.size():
			var option: Dictionary = options[index]
			var group := VBoxContainer.new(); group.add_theme_constant_override("separation", 4); body.add_child(group)
			var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 8); group.add_child(row)
			var player: Dictionary = option.players[0]
			var avatar := TextureRect.new(); avatar.texture = RuntimeAssets.texture("res://web/avatar-%d.svg" % int(player.get("pose", 0))); avatar.custom_minimum_size = Vector2(28, 32); avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; avatar.modulate = Color(player.get("color", "#ffffff")); row.add_child(avatar)
			var button := Button.new(); button.text = "%s · $%d" % [player.display_name, player.bank_total]; button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; button.toggle_mode = true; button.size_flags_horizontal = Control.SIZE_EXPAND_FILL; button.accessibility_name = "%s, Bank: $%d" % [player.display_name, player.bank_total]; row.add_child(button); player_buttons.append(button)
			button.pressed.connect(func() -> void: _select_player(index))
			if not option.get("items", []).is_empty():
				var fan := GameCardFan.new(); group.add_child(fan); fan.set_items(option.items)
		_select_player(selected, false)
		return
	var item: Dictionary = options[selected]
	var summary := Label.new(); summary.text = str(item.get("summary", "")); summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; summary.add_theme_font_size_override("font_size", 16); body.add_child(summary)
	for player in item.get("players", []):
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 8); body.add_child(row)
		var avatar := TextureRect.new(); avatar.texture = RuntimeAssets.texture("res://web/avatar-%d.svg" % int(player.get("pose", 0))); avatar.custom_minimum_size = Vector2(28, 32); avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; avatar.modulate = Color(player.get("color", "#ffffff")); row.add_child(avatar)
		var label := Label.new(); label.text = str(player.display_name); label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(label)
		if player.has("amount"):
			var amount := Label.new(); amount.text = "$%d" % player.amount; amount.add_theme_color_override("font_color", GameLook.table_owed_color()); row.add_child(amount)
	if not item.get("items", []).is_empty():
		var grid := GameCardGrid.new(); grid.preferred_width = 72; body.add_child(grid); grid.set_items(item.items)
	if not str(item.get("note", "")).is_empty():
		var note := Label.new(); note.text = str(item.note); note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; note.add_theme_font_size_override("font_size", 13); note.add_theme_color_override("font_color", Color("b5d6e7")); body.add_child(note)


func _select_player(index: int, notify := true) -> void:
	selected = index
	for slot in player_buttons.size():
		player_buttons[slot].set_pressed_no_signal(slot == selected)
		GameLook.table_action(player_buttons[slot], "play" if slot == selected else "bank")
	if notify: option_selected.emit(selected)


# Every eligible public card stays visible, grouped by owner and choice role.
# Selecting one side of an exchange preserves the other offered side when possible.
func _render_cards() -> void:
	for option in options:
		for group in option.get("groups", []):
			if not card_groups.any(func(prior: Dictionary) -> bool: return prior.key == group.key and prior.value == group.value and prior.owner == group.owner): card_groups.append(group)
	var exchange := card_groups.any(func(group: Dictionary) -> bool: return group.key == "give")
	if exchange:
		card_groups.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if a.key != b.key: return a.key == "give"
			return int(a.owner) < int(b.owner) if a.owner != b.owner else int(a.value) < int(b.value))
	var buckets: Dictionary = {}
	for group in card_groups:
		var key := "%s:%s" % [group.key, group.owner]
		if not buckets.has(key): buckets[key] = []
		buckets[key].append(group)
	var category := ""
	for groups: Array in buckets.values():
		var first: Dictionary = groups[0]
		if exchange and category != str(first.key):
			category = str(first.key)
			var caption := Label.new(); caption.text = "Your cards to give" if category == "give" else "Opponents' cards to take"; caption.add_theme_font_size_override("font_size", 18); caption.add_theme_color_override("font_color", Color("ffe36c")); body.add_child(caption)
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 8); body.add_child(row)
		var avatar := TextureRect.new(); avatar.texture = RuntimeAssets.texture("res://web/avatar-%d.svg" % int(first.player.get("pose", 0))); avatar.custom_minimum_size = Vector2(28, 32); avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; avatar.modulate = Color(first.player.get("color", "#ffffff")); row.add_child(avatar)
		var label := Label.new(); label.text = str(first.player.display_name); label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(label)
		var items: Array = []
		for group: Dictionary in groups:
			for source: Dictionary in group.items:
				var entry := source.duplicate(); entry.caption = str(group.label); items.append(entry)
			if group.items.is_empty():
				var button := Button.new(); button.text = str(group.label) + " · No bank cards"; button.custom_minimum_size.y = 44; body.add_child(button)
				button.pressed.connect(func() -> void: _select_group(group)); empty_choices.append({"button": button, "group": group})
		if not items.is_empty():
			var grid := GameCardGrid.new(); grid.preferred_width = 92; grid.maximum_columns = 4; grid.left_aligned = true; body.add_child(grid); grid.set_items(items)
			grid.card_pressed.connect(func(card: Dictionary) -> void:
				for group: Dictionary in groups:
					if group.items.any(func(entry: Dictionary) -> bool: return int(entry.card.id) == int(card.id)): _select_group(group); return)
			card_grids.append({"grid": grid, "groups": groups})
	outcome = VBoxContainer.new(); outcome.add_theme_constant_override("separation", 6); body.add_child(outcome); _update_cards()


func _select_group(group: Dictionary) -> void:
	if group.key == "affected": return
	var best := -1; var score := -1
	for index in options.size():
		var groups: Array = options[index].get("groups", [])
		if not groups.any(func(item: Dictionary) -> bool: return item.key == group.key and item.value == group.value and item.owner == group.owner): continue
		var matches := 0
		for current in options[selected].get("groups", []) if selected >= 0 else []:
			if groups.any(func(item: Dictionary) -> bool: return item.key == current.key and item.value == current.value and item.owner == current.owner): matches += 1
		if matches > score: best = index; score = matches
	if best < 0: return
	selected = best; _update_cards(); option_selected.emit(selected)


func _group_selected(group: Dictionary) -> bool:
	return selected >= 0 and group.key != "affected" and options[selected].get("groups", []).any(func(item: Dictionary) -> bool: return item.key == group.key and item.value == group.value and item.owner == group.owner)


func _update_cards() -> void:
	for entry in card_grids:
		var ids: Array = []
		for group in entry.groups:
			if _group_selected(group):
				for item in group.items: ids.append(item.card.id)
		entry.grid.set_selected(ids)
	for entry in empty_choices: GameLook.table_action(entry.button, "play" if _group_selected(entry.group) else "bank")
	for child in outcome.get_children(): outcome.remove_child(child); child.queue_free()
	if selected < 0:
		var prompt := Label.new(); prompt.text = "Choose the player or card for this action."; prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; outcome.add_child(prompt)
		return
	var item: Dictionary = options[selected]
	var summary := Label.new(); summary.text = str(item.get("summary", "")); summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; outcome.add_child(summary)
	for player in item.get("players", []):
		var label := Label.new(); label.text = str(player.display_name) + (" · $%d" % player.amount if player.has("amount") else ""); label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; outcome.add_child(label)
