extends SceneTree


func _init() -> void: call_deferred("_run")


func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 2: quit(1); return
	var store = preload("res://Games/poker/host/session_store.gd").new(); store.path = arguments[0]
	var saved: Dictionary = store.load_game(); var ok := not saved.is_empty()
	if ok:
		var id := "poker-omaha" if saved.rules.variant == "omaha" else "poker-texas-holdem"
		var host = load("res://Games/%s/host/main.tscn" % id).instantiate(); host.saved_game = store; host.settings_store = preload("res://tests/game_settings_fixture.gd").new(); root.add_child(host)
		var humans: Array = saved.seats.filter(func(player: Dictionary) -> bool: return not player.ai)
		var context := GameSessionContext.new(id, [] if saved.solo else humans, humans[0] if saved.solo else {}, not saved.solo); context.reduced_motion = true
		host.initialize_session(context); host.start_game(); host.set_process(false)
		ok = host.awaiting_resume; host.resume_game()
		ok = ok and not host.awaiting_resume and host.rules.turn == int(saved.rules.turn) and host.rules.deck == saved.rules.deck.map(func(card: Variant) -> int: return int(card)) and is_equal_approx(host.turn_remaining, float(saved.turn_remaining))
		host.shutdown_game(); host.queue_free(); await process_frame
	var result := FileAccess.open(arguments[1], FileAccess.WRITE); result.store_string(JSON.stringify({"ok": ok})); result.close()
	print("Poker fresh-process resume: ", ok); quit(0 if ok else 1)
