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
	holder.queue_free()
	await process_frame
	print("Board feedback: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
