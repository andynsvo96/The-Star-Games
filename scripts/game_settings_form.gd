class_name GameSettingsForm
extends VBoxContainer

# Shared, staged settings presentation. The module owns validation and Apply.
var actions := VBoxContainer.new()
var fields: Array[Dictionary] = []
var compact := false:
	set(value):
		compact = value
		add_theme_constant_override("separation", 8 if compact else 20)
		for section in get_children():
			if section is VBoxContainer and section != actions:
				section.add_theme_constant_override("separation", 4 if compact else 10)


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8 if compact else 20)
	add_child(actions)
	resized.connect(_fit_fields)


func add_section(caption: String) -> VBoxContainer:
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation", 4 if compact else 10)
	add_child(group)
	if actions.get_parent() == self:
		move_child(group, actions.get_index())
	var heading := Label.new()
	heading.text = caption.to_upper()
	GameLook.settings_heading(heading, false)
	group.add_child(heading)
	return group


func add_choice(group: VBoxContainer, caption: String, choices: Array[String]) -> OptionButton:
	var choice := OptionButton.new()
	choice.fit_to_longest_item = false
	choice.clip_text = true
	for item in choices:
		choice.add_item(item)
	_add_field(group, caption, choice)
	return choice


func add_toggle(group: VBoxContainer, caption: String, enabled: bool) -> Button:
	var toggle := Button.new()
	toggle.toggle_mode = true
	toggle.set_pressed_no_signal(enabled)
	_add_field(group, caption, toggle, true)
	toggle.set_meta("settings_caption", caption)
	GameLook.settings_toggle(toggle, enabled)
	toggle.toggled.connect(func(on: bool) -> void: GameLook.settings_toggle(toggle, on))
	return toggle


func add_number(group: VBoxContainer, caption: String, minimum: float, maximum: float, step: float, value: float, suffix := "") -> SpinBox:
	var input := SpinBox.new()
	input.min_value = minimum
	input.max_value = maximum
	input.step = step
	input.value = value
	input.suffix = suffix
	input.get_line_edit().virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL
	_add_field(group, caption, input)
	return input


func add_control(group: VBoxContainer, caption: String, control: Control) -> Control:
	_add_field(group, caption, control)
	return control


func add_action(caption: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	GameLook.settings_action(button, true)
	actions.add_child(button)
	button.pressed.connect(callback)
	return button


func _add_field(group: VBoxContainer, caption: String, control: Control, compact := false) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	group.add_child(row)
	var label := Label.new()
	label.text = caption
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_override("font", GameLook.interface_font())
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color("c1d2df"))
	row.add_child(label)
	control.accessibility_name = caption
	control.size_flags_horizontal = Control.SIZE_SHRINK_END
	row.add_child(control)
	GameLook.settings_control(control)
	fields.append({"control": control, "compact": compact})
	_fit_fields.call_deferred()


func _fit_fields() -> void:
	var available := size.x
	if available <= 0:
		return
	var label_width := minf(160, available * .42)
	for field in fields:
		field.control.custom_minimum_size = Vector2(80 if field.compact else maxf(92, available - label_width - 16), 44)
