extends SceneTree

var host: Control
var checks := 0
var failures := 0
const OUTPUT := "res://.test_data/uno-player-choice/"


func _init() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)


func settle() -> void:
	for frame in 12: await process_frame


func capture(name: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + name + ".png")


func ask(kind: String, targets: Array, prompt := "Choose a player.") -> void:
	host.rules.addons.context = {"actor":0,"origin":0,"after":1,"uno_pending":false}
	host.rules.addons._ask(host.rules, kind, prompt, targets)
	if kind == "instigator": host.rules.addons.choice.amounts = {}
	if kind == "trade_second": host.rules.addons.choice.first = 1
	host.rules.revision += 1
	host._publish()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	root.min_size = Vector2i.ONE
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	host = load("res://Games/uno/host/main.tscn").instantiate()
	root.add_child(host)
	host.settings_store = preload("res://tests/game_settings_fixture.gd").new()
	var context := GameSessionContext.new("uno",[],{"id":"host","display_name":"Host","color":"#2463eb"},false)
	context.reduced_motion = true
	host.initialize_session(context)
	host.start_game()
	for timer in [host.ai_timer,host.auto_timer,host.catch_timer,host.jump_timer]: timer.process_mode = Node.PROCESS_MODE_DISABLED
	for pack in host.rules.enabled_addons: host.rules.enabled_addons[pack] = true
	host.rules.restart_round()
	host.rules.addons.reset()
	host.rules.hands = [[9,13,79],[5,55,29],[3,27,81],[7,31,85]]
	host.rules.discard = [17]
	host.rules.deck = range(host.rules.cards.size()).filter(func(id: int) -> bool: return not host.rules.discard.has(id) and not host.rules.hands.any(func(hand: Array) -> bool: return hand.has(id)))
	host.rules.pending_draw = 0
	host.rules.pending_color = ""
	host.rules.drawn = -1
	host.rules.phase = "play"
	host.rules.turn = 0
	host._publish()
	await settle()
	var ordinary_size: Vector2 = host.table.size
	for kind in ["swap1","swap_hands","nemesis","match_max","coupled","chat","eggs","petty","redirect","trade_first","trade_second","instigator"]:
		var targets := [0,1,2,3] if kind in ["trade_first","instigator"] else [0,2,3] if kind == "trade_second" else [1,2,3]
		ask(kind, targets)
		await settle()
		check(host.player_focus.visible and host.player_focus.targets.size() == targets.size(), "Every player-choice card highlights its authoritative targets: " + kind)
		check(host.table.swap_buttons.filter(func(button: Button) -> bool: return button.visible).size() == targets.size(), "The badges themselves supply the choice inputs: " + kind)
		check(not host.addon_dialog.overlay.visible and host.controls.get_child_count() == 0 and host.table.size.is_equal_approx(ordinary_size), "Player choices reserve no bottom UI or extra dialog: " + kind)
		check(host._snapshot(-1).player_choice.is_empty() and host._snapshot(1).player_choice.is_empty(), "Only the choosing player receives private target controls: " + kind)
		check(host.player_focus.confirm.visible == (kind == "instigator"), "Only a staged multi-player choice needs Confirm")
	ask("petty", [1,2,3], "Choose a player to draw three cards.")
	for dimensions in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(390,844),Vector2i(844,390),Vector2i(568,320)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		await capture("petty-%dx%d" % [dimensions.x,dimensions.y])
		var prompt: Rect2 = host.player_focus.prompt.get_global_rect()
		check(root.get_visible_rect().encloses(prompt) and prompt.get_center().x > dimensions.x * .5, "The prompt floats on the right inside every viewport")
		check(host.player_focus.targets.all(func(target: Rect2) -> bool: return not prompt.intersects(target)), "The prompt never covers a selectable player badge")
		check(not prompt.intersects(host.actions.draw.get_global_rect()) and not prompt.intersects(host.table.uno_button.get_global_rect()) and not prompt.intersects(host.table.sort_button.get_global_rect()), "The floating prompt leaves the action row reachable at %s" % dimensions)
	var revision: int = host.rules.revision
	host._choose_player(0)
	check(host.rules.revision == revision, "An ineligible own badge cannot submit a choice")
	host.settings_open = true
	host._publish()
	await settle()
	check(not host.player_focus.visible and host.table.swap_buttons.all(func(button: Button) -> bool: return not button.visible), "Settings removes targeting, dimming and active choice inputs")
	host.settings_open = false
	host._publish()
	await settle()
	check(host.player_focus.visible and host.rules.revision == revision, "Closing settings restores the pending target choice without accepting it")
	var before: int = host.rules.hands[1].size()
	host.table.swap_buttons[1].pressed.emit()
	await settle()
	check(host.rules.hands[1].size() == before + 3 and not host.player_focus.visible, "Clicking a badge commits the real Petty Play target and clears the focus")
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	ask("trade_first", [0,1,2,3], "Choose the first player to trade hands.")
	await settle()
	host.table.swap_buttons[1].pressed.emit()
	await capture("trade-second")
	check(host.rules.addons.choice.kind == "trade_second" and not host.table.swap_buttons[1].visible and host.table.swap_buttons[0].visible, "Two-player trades refresh eligibility and support the chooser's own badge when allowed")
	host.table.swap_buttons[2].pressed.emit()
	await settle()
	check(not host.player_focus.visible, "The second trade target clears the scrim after acceptance")
	ask("instigator", [0,1,2,3], "Choose players and 1–4 cards each, then confirm.")
	await settle()
	host.table.swap_buttons[1].pressed.emit()
	await settle()
	host.table.swap_buttons[1].pressed.emit()
	await capture("instigator-amounts")
	check(host.rules.addons.choice.amounts.get(1) == 2 and host.player_focus.counters.any(func(label: Label) -> bool: return label.visible and label.text == "+2"), "Repeated badge presses stage amounts directly beside the player")
	for dimensions in [Vector2i(390,844),Vector2i(844,390),Vector2i(568,320)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		await capture("instigator-%dx%d" % [dimensions.x,dimensions.y])
		var prompt: Rect2 = host.player_focus.prompt.get_global_rect()
		check(root.get_visible_rect().encloses(prompt) and not prompt.intersects(host.actions.draw.get_global_rect()) and not prompt.intersects(host.table.uno_button.get_global_rect()) and not prompt.intersects(host.table.sort_button.get_global_rect()), "Staged choices keep Confirm and the existing action row reachable at %s" % dimensions)
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	var frozen: float = host.player_focus.clock
	await settle()
	check(is_equal_approx(host.player_focus.clock, frozen), "Reduced motion retains a static target halo")
	context.reduced_motion = false
	host._publish()
	await settle()
	check(host.player_focus.clock > frozen, "Eligible badges breathe with motion enabled")
	context.reduced_motion = true
	host._publish()
	before = host.rules.hands[1].size()
	host.player_focus.confirm.pressed.emit()
	await settle()
	check((host.rules.hands[1].size() == before + 2 or host.rules.pending_draw == 2) and host.rules.addons.choice.is_empty() and not host.player_focus.visible, "The floating Confirm commits staged amounts through the host")
	host.rules.phase = "swap"
	host.rules.swap_seat = 0
	host.rules.turn = 0
	host.rules.revision += 1
	host._publish()
	await capture("seven-swap")
	check(host.player_focus.visible and host.player_focus.message.text.contains("swap"), "Classic seven-card swaps use the same right-side focus")
	host.shutdown_game()
	check(not host.player_focus.visible, "Exit clears the target scrim")
	host.queue_free()
	await settle()
	print("UNO player choices: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
