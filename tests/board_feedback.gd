extends SceneTree

# Framework-only score cues and compact disclosure checks.
var failures := 0
var checks := 0


func _init() -> void:
	call_deferred("_run")


func check(ok: bool, caption: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + caption)


func _run() -> void:
	var holder := Control.new()
	root.add_child(holder)
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var screen := GameScreen.new()
	holder.add_child(screen)
	screen.configure("Feedback fixture")
	screen.use_playful_style("")
	var card := screen.add_score_card(screen.content, null)
	card.player.text = "Literal <player> [name]"
	screen.set_score_card_seat(card, 4, Color("171717"))
	screen.set_score_card_turn_glow(card, true, false)
	var rules := GameRulesPanel.new()
	rules.small_heading = true
	rules.quiet_heading = true
	screen.content.add_child(rules)
	rules.fit(220, 240, true)
	for frame in 12: await process_frame
	var before: Rect2 = card.panel.get_global_rect()
	check(card.seat_token.seat == 4 and card.seat_token.identity == Color("171717") and card.player.text == "Literal <player> [name]", "Numbered tokens preserve literal names and identity colors")
	check(card.turn_glow.active and card.turn_glow.age > 0 and card.turn_glow.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Turn feedback breathes without intercepting input")
	screen.set_score_card_turn_glow(card, true, true)
	var age: float = card.turn_glow.age
	for frame in 8: await process_frame
	check(card.turn_glow.age == age and card.turn_glow.active, "Reduced motion retains a static turn highlight")
	screen.set_score_card_turn_glow(card, false, true)
	for frame in 8: await process_frame
	check(card.panel.get_global_rect().is_equal_approx(before), "Turn cues never change score-card geometry")
	check(rules.heading.get_theme_stylebox("focus") is StyleBoxEmpty and rules.heading.focus_mode == Control.FOCUS_ALL, "Quiet disclosure removes its inner yellow rectangle while retaining keyboard access")
	check(rules.heading.custom_minimum_size.y >= 44 and rules.heading.text.begins_with("RULES / EFFECTS"), "Small rules headings retain a reachable target")
	var guide := screen.add_illustrated_guide("Public examples", [{"heading":"Literal [heading]", "detail":"Use < and > as ordinary text.", "image":"res://ui/playful/control-help.svg", "description":"A public reference card"}])
	guide.overlay.show()
	for frame in 8: await process_frame
	var example: Control = guide.guide.get_child(0)
	guide.guide.set_items(guide.guide.items)
	check(guide.guide.get_child(0) == example, "Repeated guide updates preserve reading nodes")
	check(example.get_child(0).text == "Literal [heading]" and example.get_child(2).text.contains("< and >"), "Illustrated help renders all text literally")
	check(example.get_child(1).texture != null and not example.get_child(1).accessibility_name.is_empty(), "Illustrations keep an offline image and text alternative")
	check(root.get_visible_rect().encloses(guide.actions.get_global_rect()), "Illustrated guide keeps Close outside its scrolling body")
	guide.overlay.hide()
	var round_results := GameRoundResults.new()
	screen.content.add_child(round_results)
	var entries := [{"display_name":"Literal [winner]", "color":"#000000", "winner":true, "metrics":[{"label":"Moves", "value":12}]}]
	round_results.set_results(entries)
	var result_card: Control = round_results.get_child(0)
	round_results.set_results(entries)
	check(round_results.get_child(0) == result_card and result_card.get_child(0).get_child(0).get_child(0).text == "Literal [winner]", "Unchanged results retain nodes and literal identity")
	screen.set_score_card_current_game(card)
	check(not card.score_panel.visible and card.player.text == "Literal <player> [name]", "Current-game cards omit totals without losing identity")
	var help_button := Button.new(); screen.content.add_child(help_button); GameLook.help_control(help_button)
	check(GameLook.text_contrast(help_button.get_theme_color("font_color"), help_button.get_theme_color("panel", "GamePalette")) >= 4.5, "Question-mark controls retain readable contrast")
	var settings := screen.add_corner_details(["SETTINGS"], Callable(), false, false, false, true, true, false, true)[0]
	screen.add_settings_form(settings)
	var toggle: Button = settings.get_meta("toggle_button")
	var corner_help := screen.add_corner_help(toggle, func() -> void: guide.overlay.show())
	var close: Button = settings.get_meta("settings_close")
	toggle.button_pressed = true
	for frame in 8: await process_frame
	var outside := InputEventMouseButton.new(); outside.button_index = MOUSE_BUTTON_LEFT; outside.pressed = true
	settings.get_meta("settings_backdrop").gui_input.emit(outside)
	check(toggle.button_pressed and screen.back_button.disabled and not corner_help.visible, "Close-only Settings blocks outside dismissal, board help and game navigation")
	check(close.shortcut == null and root.get_visible_rect().encloses(close.get_global_rect()), "Close-only Settings has a reachable Close without an Escape shortcut")
	close.pressed.emit()
	check(not toggle.button_pressed and not screen.back_button.disabled, "Close restores the board and shared return navigation")
	for frame in 4: await process_frame
	check(corner_help.size == Vector2(44,44) and absf(corner_help.get_global_rect().end.x + 8 - toggle.get_global_rect().position.x) < .1, "Corner help keeps a full target and a fixed Settings gap")
	var preview_check := GameMovePreview.new(); holder.add_child(preview_check)
	preview_check.configure(func(cell: int) -> Rect2: return Rect2(30 + cell * 100, 30, 32, 32), func(_record: Dictionary) -> Control: var visual := Label.new(); visual.text = "A"; return visual)
	var demonstration := {"key":"one", "from":0, "to":1, "path":[0,1]}
	preview_check.update_preview(demonstration, false, true)
	var held_visual := preview_check.visual
	check(held_visual.global_position.is_equal_approx(Vector2(130,30)), "Reduced motion holds a preview at its destination")
	preview_check.update_preview(demonstration, false, false)
	check(preview_check.visual == held_visual and preview_check.elapsed == preview_check.duration, "Duplicate snapshots retain the settled ghost")
	demonstration.key = "two"; preview_check.update_preview(demonstration, true, false)
	check(preview_check.elapsed == 0 and preview_check.paused, "A new suggestion restarts an independent preview and honors pause")
	preview_check.update_preview({}, false, false)
	check(preview_check.key.is_empty() and not is_instance_valid(preview_check.visual), "Cleared guidance removes its ghost")
	demonstration.key = "animated"; preview_check.update_preview(demonstration, false, false)
	await create_timer(.12).timeout
	check(preview_check.elapsed > 0 and preview_check.elapsed < preview_check.duration, "A new live preview advances independently")
	preview_check.update_preview(demonstration, true, false)
	var held_age := preview_check.elapsed
	await create_timer(.08).timeout
	check(preview_check.elapsed == held_age, "Pause freezes the current demonstration phase")
	preview_check.update_preview(demonstration, false, false)
	await create_timer(.4).timeout
	check(preview_check.visual.global_position.is_equal_approx(Vector2(130,30)), "A completed demonstration stays at its destination")
	holder.queue_free()
	await process_frame
	print("Board feedback: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
