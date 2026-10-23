extends CanvasLayer

# Local UI inspection only. No arbitrary game methods or controller commands.
var opened := false
var target: Control
var selected: Control
var overlay: Control
var panel: PanelContainer
var preview_bar: PanelContainer
var outline: Control
var tree: Tree
var search: LineEdit
var hidden_only: CheckBox
var details: Label
var count_label: Label
var notice: Label
var preview_button: Button
var scenario_choice: OptionButton
var scenario_button: Button
var saved_visibility: Array[Dictionary] = []
var checked: Dictionary = {}
var scenarios: Array = []
var previous_focus: WeakRef
var screenshot_pending := false
var suspended_inputs: Dictionary = {}


func _ready() -> void:
	layer = 100
	_build()
	overlay.hide()
	set_process(false)
	get_viewport().size_changed.connect(_fit)
	get_tree().node_added.connect(_on_node_added)


func _build() -> void:
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	outline = Control.new()
	outline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outline.draw.connect(_draw_selection)
	overlay.add_child(outline)
	panel = PanelContainer.new()
	panel.theme = get_parent().theme
	overlay.add_child(panel)
	var margin := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 12)
	panel.add_child(margin)
	var outer := VBoxContainer.new()
	margin.add_child(outer)
	var header := HBoxContainer.new()
	outer.add_child(header)
	var heading := _label("Debug Lab · F8")
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	header.add_child(_button("Close", close))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	scroll.add_child(column)
	column.add_child(_label("Host UI inspection. Connected controllers continue playing."))
	search = LineEdit.new()
	search.placeholder_text = "Filter name, path, or text"
	search.accessibility_name = "Filter host UI elements"
	search.text_changed.connect(func(_value: String) -> void: refresh())
	column.add_child(search)
	hidden_only = CheckBox.new()
	hidden_only.text = "Hidden only"
	hidden_only.toggled.connect(func(_value: bool) -> void: refresh())
	column.add_child(hidden_only)
	var actions := HFlowContainer.new()
	column.add_child(actions)
	actions.add_child(_button("Rescan", refresh))
	actions.add_child(_button("Mark checked", _mark_checked))
	count_label = _label("")
	column.add_child(count_label)
	tree = Tree.new()
	tree.hide_root = true
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.custom_minimum_size.y = 220
	tree.accessibility_name = "Loaded host UI elements"
	tree.item_selected.connect(_inspect_selected)
	column.add_child(tree)
	details = _label("Select an element.")
	details.custom_minimum_size.y = 72
	column.add_child(details)
	preview_button = _button("Preview selected", _preview_selected)
	preview_button.disabled = true
	column.add_child(preview_button)
	scenario_choice = OptionButton.new()
	scenario_choice.custom_minimum_size.y = 44
	scenario_choice.accessibility_name = "Host UI scenarios"
	column.add_child(scenario_choice)
	scenario_button = _button("Preview scenario", _preview_scenario)
	column.add_child(scenario_button)
	notice = _label("Previews reveal existing controls. Test real triggers during live play.")
	column.add_child(notice)
	preview_bar = PanelContainer.new()
	preview_bar.theme = panel.theme
	overlay.add_child(preview_bar)
	var preview_actions := HFlowContainer.new()
	preview_actions.add_theme_constant_override("h_separation", 8)
	preview_bar.add_child(preview_actions)
	preview_actions.add_child(_button("Restore / Inspector", _end_preview))
	var capture := _button("Save screenshot", _capture)
	capture.disabled = DisplayServer.get_name() == "headless"
	preview_actions.add_child(capture)
	preview_actions.add_child(_button("Close · F8", close))
	preview_bar.hide()
	_fit()


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 14)
	return label


func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	button.pressed.connect(callback)
	return button


func _fit() -> void:
	if not is_instance_valid(panel): return
	var available := get_viewport().get_visible_rect().size
	panel.position = Vector2(12, 12)
	panel.size = Vector2(minf(420, available.x - 24), maxf(200, available.y - 24))
	preview_bar.position = Vector2(12, 12)
	preview_bar.size.x = maxf(200, minf(560, available.x - 24))


func open_for(control: Control) -> void:
	close()
	if not is_instance_valid(control): return
	target = control
	checked.clear()
	var focus := get_viewport().gui_get_focus_owner()
	previous_focus = weakref(focus) if focus != null else null
	if focus != null: focus.release_focus()
	opened = true
	_suspend_inputs(target)
	overlay.show()
	panel.show()
	preview_bar.hide()
	refresh()
	_load_scenarios()
	_fit()
	search.grab_focus()
	set_process(true)


func close() -> void:
	_restore_visibility()
	opened = false
	_restore_inputs()
	selected = null
	target = null
	if is_instance_valid(overlay): overlay.hide()
	set_process(false)
	if previous_focus != null:
		var focus = previous_focus.get_ref()
		if is_instance_valid(focus) and focus.is_visible_in_tree(): focus.grab_focus()
	previous_focus = null


func _exit_tree() -> void:
	_restore_visibility()
	_restore_inputs()


func _on_node_added(node: Node) -> void:
	if opened and is_instance_valid(target) and target.is_ancestor_of(node):
		_suspend_added_input.call_deferred(weakref(node))


func _suspend_added_input(reference: WeakRef) -> void:
	var node = reference.get_ref()
	if opened and is_instance_valid(target) and is_instance_valid(node) and target.is_ancestor_of(node):
		_suspend_inputs(node)


func _suspend_inputs(node: Node) -> void:
	var flags := [node.is_processing_input(), node.is_processing_unhandled_input(), node.is_processing_unhandled_key_input(), node.is_processing_shortcut_input()]
	if flags.has(true) and not suspended_inputs.has(node.get_instance_id()):
		suspended_inputs[node.get_instance_id()] = {"node": weakref(node), "flags": flags}
		node.set_process_input(false)
		node.set_process_unhandled_input(false)
		node.set_process_unhandled_key_input(false)
		node.set_process_shortcut_input(false)
	for child in node.get_children(): _suspend_inputs(child)


func _restore_inputs() -> void:
	for entry in suspended_inputs.values():
		var node = entry.node.get_ref()
		if not is_instance_valid(node): continue
		node.set_process_input(entry.flags[0])
		node.set_process_unhandled_input(entry.flags[1])
		node.set_process_unhandled_key_input(entry.flags[2])
		node.set_process_shortcut_input(entry.flags[3])
	suspended_inputs.clear()


func _process(_delta: float) -> void:
	if not is_instance_valid(target) or not target.is_inside_tree():
		close()
		return
	outline.queue_redraw()


func refresh() -> void:
	if not opened or not is_instance_valid(target): return
	var selected_id := selected.get_instance_id() if is_instance_valid(selected) else 0
	tree.clear()
	var root_item := tree.create_item()
	var pending: Array[Node] = [target]
	var loaded := 0
	var hidden := 0
	var reviewed := 0
	while not pending.is_empty() and loaded < 6000:
		var node: Node = pending.pop_back()
		for child in node.get_children(): pending.append(child)
		if not node is Control: continue
		loaded += 1
		var invisible: bool = not node.is_visible_in_tree()
		if invisible: hidden += 1
		var id := node.get_instance_id()
		if checked.has(id): reviewed += 1
		var caption := str(target.get_path_to(node)) + " · " + node.get_class()
		var text := _control_text(node)
		if not text.is_empty(): caption += " · " + text.replace("\n", " ").left(70)
		if hidden_only.button_pressed and not invisible: continue
		if not search.text.is_empty() and not caption.to_lower().contains(search.text.to_lower()): continue
		var item := tree.create_item(root_item)
		item.set_text(0, ("✓ " if checked.has(id) else "") + ("[hidden] " if invisible else "") + caption)
		item.set_metadata(0, id)
		item.set_tooltip_text(0, "")
		if id == selected_id: item.select(0)
	count_label.text = "%d loaded · %d hidden · %d marked checked" % [loaded, hidden, reviewed]
	_inspect_selected()


func _control_text(control: Control) -> String:
	if control is Label or control is RichTextLabel or control is BaseButton: return str(control.text)
	return control.accessibility_name


func _inspect_selected() -> void:
	var item := tree.get_selected()
	selected = instance_from_id(int(item.get_metadata(0))) as Control if item != null else null
	preview_button.disabled = not is_instance_valid(selected)
	if not is_instance_valid(selected):
		details.text = "Select an element."
		return
	var rect := selected.get_global_rect()
	details.text = "%s\n%s · %s\nPosition %.0f, %.0f · Size %.0f × %.0f" % [target.get_path_to(selected), selected.get_class(), "visible" if selected.is_visible_in_tree() else "hidden", rect.position.x, rect.position.y, rect.size.x, rect.size.y]
	outline.queue_redraw()


func _mark_checked() -> void:
	if is_instance_valid(selected):
		checked[selected.get_instance_id()] = true
		refresh()


func _reveal(control: Control) -> void:
	if not is_instance_valid(control) or not (control == target or target.is_ancestor_of(control)): return
	var node: Node = control
	while node != null:
		if node is CanvasItem and not node.visible:
			saved_visibility.append({"node": weakref(node), "visible": node.visible})
			var blocked := node.is_blocking_signals()
			node.set_block_signals(true)
			node.show()
			node.set_block_signals(blocked)
		if node == target: break
		node = node.get_parent()
	selected = control


func _preview_selected() -> void:
	if not is_instance_valid(selected): return
	var control := selected
	_restore_visibility()
	_reveal(control)
	panel.hide()
	preview_bar.show()
	outline.queue_redraw()


func _restore_visibility() -> void:
	for item in saved_visibility:
		var node = item.node.get_ref()
		if not is_instance_valid(node): continue
		# If live gameplay hid it again, leave that authoritative update intact.
		if node.visible:
			var blocked: bool = node.is_blocking_signals()
			node.set_block_signals(true)
			node.visible = item.visible
			node.set_block_signals(blocked)
	saved_visibility.clear()


func _end_preview() -> void:
	_restore_visibility()
	preview_bar.hide()
	panel.show()
	refresh()


func _load_scenarios() -> void:
	scenario_choice.clear()
	scenarios.clear()
	if target is BaseGame:
		for item in target.debug_ui_scenarios().slice(0, 100):
			if not item is Dictionary or not item.get("label") is String or not item.get("paths") is Array: continue
			scenarios.append(item)
			scenario_choice.add_item(item.label)
	if scenarios.is_empty(): scenario_choice.add_item("No named scenarios in this game")
	scenario_choice.disabled = scenarios.is_empty()
	scenario_button.disabled = scenarios.is_empty()


func _preview_scenario() -> void:
	var index := scenario_choice.selected
	if index < 0 or index >= scenarios.size() or not is_instance_valid(target): return
	_restore_visibility()
	for path in scenarios[index].paths.slice(0, 32):
		if not path is String and not path is NodePath: continue
		# Paths are relative and confined to this game; no arbitrary call hooks.
		var value := str(path)
		if value.begins_with("/") or value.split("/").has(".."): continue
		_reveal(target.get_node_or_null(NodePath(value)) as Control)
	panel.hide()
	preview_bar.show()


func _draw_selection() -> void:
	if opened and is_instance_valid(selected) and selected.is_visible_in_tree():
		outline.draw_rect(selected.get_global_rect(), Color("ffbf47"), false, 3)


func _capture() -> void:
	if screenshot_pending or DisplayServer.get_name() == "headless": return
	screenshot_pending = true
	preview_bar.hide()
	outline.hide()
	await RenderingServer.frame_post_draw
	var folder := "user://debug_lab"
	DirAccess.make_dir_recursive_absolute(folder)
	var path := folder.path_join("host-%d.png" % Time.get_ticks_msec())
	var error := get_viewport().get_texture().get_image().save_png(path)
	if is_instance_valid(outline): outline.show()
	if opened: preview_bar.show()
	screenshot_pending = false
	notice.text = "Screenshot saved: " + ProjectSettings.globalize_path(path) if error == OK else "Could not save screenshot."
