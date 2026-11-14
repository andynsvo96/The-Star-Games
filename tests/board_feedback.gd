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
	var pages := screen.add_illustrated_guide("How to Play", [{"section":"Moves", "heading":"First <move>", "detail":"Literal [public] rules.", "image":"res://ui/playful/control-help.svg", "description":"An offline example"}, {"section":"Rules", "heading":"Second rule", "detail":"A separate topic.", "image":"res://ui/playful/control-help.svg", "description":"Another offline example"}], true)
	pages.overlay.show()
	check(pages.close.text == "×" and pages.close.get_parent() == pages.heading_row and not pages.actions.is_ancestor_of(pages.close), "Paged references keep an accessible X in the fixed header")
	pages.guide.next.pressed.emit()
	check(pages.guide.page == 1 and pages.guide.previous.disabled == false and pages.guide.next.disabled and pages.guide.topics.get_item_text(0) == "Second rule", "Paged guide navigation changes section and topic together with bounded endpoints")
	var current_picture: Control = pages.guide.picture
	pages.guide.set_items(pages.guide.items)
	check(pages.guide.page == 1 and pages.guide.picture == current_picture, "Repeated paged guide snapshots preserve topic and artwork nodes")
	pages.guide.reload_artwork()
	check(pages.guide.page == 1 and pages.guide.copy.get_child(0).text == "Second rule" and pages.guide.picture == current_picture, "Cosmetic reload retains the selected lesson and image target")
	pages.guide.tabs.get_child(0).pressed.emit()
	check(pages.guide.page == 0 and pages.guide.copy.get_child(0).text == "First <move>", "Section navigation renders literal lesson titles")
	pages.guide.tabs.get_child(1).pressed.emit()
	check(pages.guide.page == 1, "Switching back restores a section's last selected page")
	var demo: GameGuideDemonstration = pages.guide.demonstration
	var clip := {"background":"res://ui/playful/score-ledger.svg", "sprites":[{"image":"res://ui/playful/control-help.svg", "rect":[.1,.2,.2,.2]}], "steps":[{"caption":"Literal <move>", "duration":1.0, "moves":[{"sprite":0, "rect":[.6,.2,.2,.2]}]}]}
	demo.set_demonstration(clip)
	demo._advance(.95)
	check(demo.sprites[0].rect[0] > .1 and demo.sprites[0].rect[0] < .6 and demo.paths.has(0), "Public examples interpolate artwork with a source-to-destination route")
	var progress: float = demo.elapsed
	demo.stage.pressed.emit()
	for frame in 8: await process_frame
	check(is_equal_approx(demo.elapsed, progress), "Pause retains the current demonstration phase")
	demo.stage.pressed.emit()
	check(demo.playing and demo.elapsed == progress and demo.get_child_count() == 1, "Clicking the image resumes its phase without caption or transport controls")
	pages.guide.set_reduced_motion(true)
	check(not demo.visible and pages.guide.picture.visible, "Reduced motion retains the static annotated reference")
	pages.guide.set_reduced_motion(false)
	check(demo.visible and not pages.guide.picture.visible, "Animated references return without replacing the page")
	var tray := GamePieceTray.new(); screen.content.add_child(tray)
	var stock := [{"key":1,"label":"Example piece","count":2,"enabled":true,"texture":RuntimeAssets.texture("res://ui/playful/control-help.svg")},{"key":2,"label":"Empty piece","count":0,"enabled":true}]
	tray.set_items(stock, 1)
	var held := tray.buttons[0]
	tray.set_items(stock, 1)
	check(tray.buttons[0] == held and held.button_pressed and not held.disabled and tray.buttons[1].disabled and held.accessibility_name.contains("2 in reserve"), "Reserve trays retain controls, selection and authoritative empty-slot locks")
	check(tray.buttons[1].get_meta("tray_count").get_theme_color("font_color") == GameLook.DISABLED_INK, "Unavailable reserve counts retain readable ink on disabled controls")
	tray.hide()
	for shape in [Vector2i(1280,720), Vector2i(480,850), Vector2i(844,390), Vector2i(320,568)]:
		root.min_size = Vector2i.ONE
		root.content_scale_size = shape; root.size = shape
		for frame in 12: await process_frame
		check(root.get_visible_rect().encloses(pages.panel.get_global_rect()) and root.get_visible_rect().encloses(pages.actions.get_global_rect()), "Paged reference and navigation fit %s" % shape)
	pages.overlay.hide()
	check(screen.back_button.visible, "Closing short-screen help restores shared return navigation")
	root.content_scale_size = Vector2i(1280,720); root.size = Vector2i(1280,720)
	var round_results := GameRoundResults.new()
	screen.content.add_child(round_results)
	var entries := [{"display_name":"Literal [winner]", "color":"#000000", "winner":true, "metrics":[{"label":"Moves", "value":12}]}]
	round_results.set_results(entries)
	var result_card: Control = round_results.get_child(0)
	round_results.set_results(entries)
	check(round_results.get_child(0) == result_card and result_card.get_child(0).get_child(0).get_child(0).text == "Literal [winner]", "Unchanged results retain nodes and literal identity")
	screen.set_score_card_current_game(card)
	check(not card.score_panel.visible and card.player.text == "Literal <player> [name]", "Current-game cards omit totals without losing identity")
	var themed_card := screen.add_score_card(screen.content, null, Color.WHITE, "ledger")
	var original_surface: StyleBoxTexture = themed_card.panel.get_theme_stylebox("panel")
	var artwork := RuntimeAssets.texture("res://ui/playful/score-ornate.svg")
	screen.set_score_card_artwork(themed_card, artwork)
	var themed_surface: StyleBoxTexture = themed_card.panel.get_theme_stylebox("panel")
	check(themed_surface.texture == artwork and themed_surface.get_content_margin(SIDE_LEFT) == 24 and original_surface.texture != artwork, "Custom player frames preserve safe insets and do not mutate shared artwork")
	screen.set_score_card_current_game(themed_card, false, true)
	check(themed_card.name_panel.custom_minimum_size.y == 0 and themed_card.player.get_theme_font_size("font_size") == 18, "Tight player identities remove reserved height without shrinking names")
	themed_card.panel.hide()
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
	var fit_holder := Control.new(); root.add_child(fit_holder); fit_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fitted := GameScreen.new(); fit_holder.add_child(fitted); fitted.configure("Fit fixture"); fitted.scores.hide(); fitted.status.hide()
	var board := Control.new(); board.custom_minimum_size = Vector2(180,180); fitted.content.add_child(board)
	var replay := Button.new(); replay.text = "Play again"; replay.custom_minimum_size.y = 44; fitted.content.add_child(replay)
	fitted.center_board(board,replay)
	for frame in 8: await process_frame
	var centered_limit := fitted.board_height_limit()
	fitted.fit_board_to_space()
	for frame in 8: await process_frame
	var top := fitted._board_top_margin() + fitted._board_header_height()
	var bottom := fitted.available_size().y - 24 - replay.get_combined_minimum_size().y
	check(fitted.board_height_limit() >= centered_limit and is_equal_approx(fitted.board_height_limit(),bottom-top), "Available-space fitting uses the complete height between heading and reserved actions")
	check(is_equal_approx(fitted._board_center_y(),(top+bottom)/2), "Available-space fitting keeps shared centering between actual obstructions")
	var reserved_limit := fitted.board_height_limit(); replay.hide()
	for frame in 8: await process_frame
	check(is_equal_approx(fitted.board_height_limit(),reserved_limit), "Hidden replay retains its space in an expanded board composition")
	fit_holder.queue_free(); await process_frame
	if DisplayServer.get_name() != "headless":
		var viewport := SubViewport.new()
		viewport.size = Vector2i(256,256)
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var reference := GameGuideDemonstration.new()
		viewport.add_child(reference)
		reference.size = Vector2(256,256)
		reference.set_demonstration({"background":"res://ui/playful/score-ledger.svg", "sprites":[], "steps":[]})
		for frame in 4: await process_frame
		await RenderingServer.frame_post_draw
		var original := viewport.get_texture().get_image()
		var samples := [Vector2i(64,64),Vector2i(128,64),Vector2i(128,128),Vector2i(192,160)]
		reference.stage.grab_focus(); reference.stage.pressed.emit()
		for frame in 4: await process_frame
		await RenderingServer.frame_post_draw
		var paused := viewport.get_texture().get_image()
		var border_point := Vector2i(128,2)
		check(reference.stage.has_focus() and not reference.playing and paused.get_pixelv(border_point).is_equal_approx(GameLook.RED) and samples.all(func(point: Vector2i) -> bool: return paused.get_pixelv(point).is_equal_approx(original.get_pixelv(point))), "Paused illustrations show a red border without changing artwork brightness")
		reference.stage.release_focus()
		for frame in 2: await process_frame
		await RenderingServer.frame_post_draw
		check(viewport.get_texture().get_image().get_pixelv(border_point).is_equal_approx(GameLook.RED), "The paused border follows playback state when focus moves elsewhere")
		reference.stage.grab_focus()
		reference.stage.pressed.emit()
		for frame in 4: await process_frame
		await RenderingServer.frame_post_draw
		var resumed := viewport.get_texture().get_image()
		check(reference.stage.has_focus() and reference.playing and resumed.get_pixelv(border_point).is_equal_approx(original.get_pixelv(border_point)) and samples.all(func(point: Vector2i) -> bool: return resumed.get_pixelv(point).is_equal_approx(original.get_pixelv(point))), "Resuming removes the border and preserves brightness while keeping keyboard focus")
		DirAccess.make_dir_recursive_absolute("res://.test_data/board-feedback/")
		paused.save_png("res://.test_data/board-feedback/tutorial-paused.png")
		resumed.save_png("res://.test_data/board-feedback/tutorial-resumed.png")
		viewport.queue_free(); await process_frame
	print("Board feedback: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
