extends SceneTree

const Host = preload("res://Games/uno/host/main.tscn")
var checks := 0
var failures := 0
var awards := 0
var reports := 0


func _init() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	seed(8173)
	for humans in [0, 4]:
		var players: Array = []
		for seat in humans: players.append({"id":"phone-%d" % seat,"display_name":"Player %d" % seat,"color":"#2463eb"})
		var host := Host.instantiate()
		root.add_child(host)
		host.settings_store = preload("res://tests/game_settings_fixture.gd").new()
		host.initialize_session(GameSessionContext.new("uno",players,{"id":"host","display_name":"Host","color":"#e53935"},humans > 0))
		host.points_awarded.connect(func(_id: String, amount: int) -> void: awards += amount)
		host.result_reported.connect(func(_id: String, _won: bool) -> void: reports += 1)
		host.start_game()
		check(host.apply_options.disabled, "Apply starts disabled with no staged changes")
		check(host.apply_options.get_theme_stylebox("disabled").bg_color == GameLook.DISABLED_FILL and host.apply_options.get_theme_stylebox("normal").bg_color != GameLook.DISABLED_FILL, "Disabled Apply is visibly grey and pending changes use the primary color")
		if humans > 0:
			var base_revision: int = host.rules.revision
			host.handle_controller_message("phone-0",{"action":"apply_options","revision":base_revision})
			host.handle_controller_message("phone-0",{"action":"set_difficulty","difficulty":2,"revision":base_revision})
			check(host.rules.revision == base_revision and host.difficulty == 1, "Controllers cannot apply options or change host difficulty")
		var before: Array = host.rules.hands.duplicate(true)
		var revision: int = host.rules.revision
		var round_number: int = host.rules.round_number
		var deal_revision: int = host.deal_revision
		host._set_difficulty(2)
		check(host.difficulty == 1 and host.rules.revision == revision and host.rules.hands == before, "Difficulty edits never change the live hand or revision")
		check(host.pending_difficulty == (2 if humans == 0 else 1), "Difficulty is staged only when the table contains AI")
		for option in host.pending_options.keys(): host._set_rule(option,true)
		host._publish()
		check(host.pending_options.values().all(func(on: bool) -> bool: return on) and not host.apply_options.disabled, "All five edits survive ordinary snapshots while Apply is enabled")
		check(host._snapshot(0).options.values().all(func(on: bool) -> bool: return not on) and host._snapshot(0).difficulty == 1, "Controllers see active options until Apply")
		host._apply_options()
		check(host.rules.round_number == round_number + 1 and host.rules.revision > revision and host.deal_revision == deal_revision + 1 and host.dealing, "Apply during an opening deal cancels it and starts one fresh deal")
		check(host.rules.hands.all(func(hand: Array) -> bool: return hand.size() == 7) and host._snapshot(0).options.values().all(func(on: bool) -> bool: return on), "The new hand uses all five options and seven starting cards")
		check(host.difficulty == (2 if humans == 0 else 1) and host.apply_options.disabled, "Difficulty takes effect with the batch and Apply returns to disabled")
		check(awards == 0 and reports == 0, "Abandoning an active hand awards no points or results")
		if humans > 0:
			host.handle_controller_message("phone-0",{"action":"play","card":host.rules.hands[0][0],"revision":revision})
			check(host.rules.hands[0].size() == 7, "Input queued before Apply cannot affect the new hand")
		# Reverting every pending edit makes Apply a no-op.
		var applied_revision: int = host.rules.revision
		for option in host.pending_options.keys():
			host._set_rule(option,false)
			host._set_rule(option,true)
		host._apply_options()
		check(host.apply_options.disabled and host.rules.revision == applied_revision, "Reverting staged edits disables Apply and leaves the current deal intact")
		# An apply cancels a pending Wild/swap, timers and the old hand's play log.
		for phase in ["drawn_color", "swap"]:
			host.motion_timer.stop()
			host.dealing = false
			host.animating = false
			host.rules.phase = phase
			host.rules.drawn = 100 if phase == "drawn_color" else -1
			host.rules.swap_seat = 0 if phase == "swap" else -1
			host.rules.swap_next = 1 if phase == "swap" else -1
			host.selected_card = 100
			host.selected_revision = host.rules.revision
			host.rules.plays.append({"number":1,"seat":0,"card":{"color":"red","kind":"5"},"color":"red"})
			host._set_rule("allow_stacking",not host.rules.allow_stacking)
			host._apply_options()
			check(host.dealing and host.rules.phase not in ["drawn_color","swap"] and host.rules.drawn == -1 and host.rules.swap_seat == -1 and host.selected_card == -1 and host.rules.plays.is_empty(), "Apply clears the old choice and play log before starting a fresh hand")
			check(host.auto_timer.is_stopped() and host.ai_timer.is_stopped() and host.jump_timer.is_stopped(), "No stale automatic/computer action can run during the replacement deal")
		# Preserve completed session history across a restart, without scoring twice.
		host.motion_timer.stop()
		host.dealing = false
		host.animating = false
		host.rules._finish(0)
		host._publish()
		var wins: Array = host.rules.session_wins.duplicate()
		var history: Array = host.rules.history.duplicate(true)
		var previous_awards := awards
		var previous_reports := reports
		host._set_rule("force_play",false)
		host._apply_options()
		check(host.rules.winner == -1 and host.rules.session_wins == wins and host.rules.history == history and awards == previous_awards and reports == previous_reports, "Apply after a win keeps completed history without awarding another result")
		if humans > 0:
			host._set_rule("allow_jump_ins",false)
			host.player_disconnected("phone-0")
			var paused_revision: int = host.rules.revision
			host._apply_options()
			check(host.apply_options.disabled and host.rules.revision == paused_revision and host.rule_choices.values().all(func(toggle: Button) -> bool: return toggle.disabled), "Apply and editing stay disabled while a player is disconnected")
			host.player_reconnected(players[0])
			check(not host.apply_options.disabled and not host.pending_options.allow_jump_ins and host.rules.allow_jump_ins, "Reconnect retains staged changes without applying them")
			host._apply_options()
			check(not host.rules.allow_jump_ins and host.dealing, "Applying after reconnect starts a new hand with the retained edit")
		host.shutdown_game()
		host.queue_free()
		await process_frame
	await create_timer(.15).timeout
	print("UNO options: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
