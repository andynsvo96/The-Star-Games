extends SceneTree

var checks := 0
var failures := 0

func _init() -> void: call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + message)

func card_id(host, key: String, index := 0) -> int:
	return int(host.rules.cards.filter(func(card: Dictionary) -> bool: return card.key == key)[index].id)

func _run() -> void:
	var host = load("res://Games/monopoly-deal/host/main.tscn").instantiate(); root.add_child(host)
	host.settings_store = preload("res://tests/game_settings_fixture.gd").new()
	var players := [{"id":"a","display_name":"Alex","color":"#2463eb"},{"id":"b","display_name":"Sam","color":"#08a750"}]
	var context := GameSessionContext.new("monopoly-deal", players, {}, true); context.reduced_motion = true
	host.initialize_session(context); host.start_game()
	check(host.turn_seconds == 60 and host._snapshot(0).clock.running, "Default turn clock starts at one minute on the host")
	host._settle_clock(host.clock_updated_usec + 2000000)
	check(host.turn_remaining <= 58 and host.turn_remaining > 57, "Host monotonic elapsed time consumes the active player's allowance")
	host.settings_button.button_pressed = true
	var remaining: float = host.turn_remaining; var revision: int = host.rules.revision
	host._settle_clock(host.clock_updated_usec + 90000000)
	check(is_equal_approx(remaining, host.turn_remaining) and host._snapshot(0).paused and not host.clock_running, "Settings pauses the entire game and clock")
	check(not host._action(0, {"action":"end", "revision":revision}) and host.ai_timer.is_stopped(), "Settings blocks phone commands and AI")
	await process_frame; await process_frame
	check(host.settings_button.get_parent().get_child(0).visible and not host.settings_button.visible, "Settings always focuses its centered sheet above a blocking dim backdrop")
	check(not host.theme_choice.get_parent().get_parent().find_children("*", "Button", true, false).any(func(button: Button) -> bool: return button.text == "Help"), "Host Settings does not contain Help")
	host.settings_button.button_pressed = false
	check(host.clock_running and is_equal_approx(remaining, host.turn_remaining), "Closing Settings resumes the same remaining allowance")
	host.player_disconnected("b"); remaining = host.turn_remaining
	host._settle_clock(host.clock_updated_usec + 90000000)
	check(is_equal_approx(remaining, host.turn_remaining) and not host.clock_running, "A disconnect cannot consume or reset time")
	host.player_reconnected(players[1])
	check(host.clock_running and is_equal_approx(remaining, host.turn_remaining), "Reconnect resumes rather than granting a fresh minute")
	var debt := card_id(host, "debt-collector"); var money := card_id(host, "money-10")
	var refusal := card_id(host, "just-say-no")
	for hand in host.rules.hands: hand.erase(debt); hand.erase(money)
	for hand in host.rules.hands: hand.erase(refusal)
	host.rules.deck.erase(refusal); host.rules.hands[1].append(refusal)
	host.rules.deck.erase(debt); host.rules.deck.erase(money); host.rules.hands[0].append(debt); host.rules.banks[1].append(money)
	check(host._action(0, {"action":"debt", "card":debt, "target":1, "revision":host.rules.revision}), "A real action creates an opponent response")
	remaining = host.turn_remaining; host._settle_clock(host.clock_updated_usec + 90000000)
	check(not host.clock_running and is_equal_approx(remaining, host.turn_remaining), "Opponent response time is excluded")
	host.turn_remaining = 0
	check(not host._finish_timeout() and host.rules.phase == "response", "Expiry preserves an already pending response")
	check(host._action(1, {"action":"accept", "revision":host.rules.revision}) and host.rules.phase == "pay", "An expired turn still allows its pending payment to begin")
	check(not host._finish_timeout(), "Expiry never pays assets on another player's behalf")
	host._settle_clock(host.clock_updated_usec + 90000000)
	check(host._action(1, {"action":"pay", "cards":[money], "revision":host.rules.revision}), "Pending payment remains manually selectable after expiry")
	check(host._finish_timeout() and host.rules.turn == 1 and host.turn_remaining == 60, "Timeout advances only after payment finishes and resets the next clock")
	host.rules.start(2); host._publish()
	var hand: Array = [card_id(host,"money-10"),card_id(host,"money-5"),card_id(host,"money-4"),card_id(host,"money-3"),card_id(host,"money-2"),card_id(host,"money-1"),card_id(host,"money-1",1),card_id(host,"pass-go"),card_id(host,"wild-any")]
	for held in host.rules.hands:
		for id in hand: held.erase(id)
	for id in hand: host.rules.deck.erase(id)
	host.rules.hands[0] = hand.duplicate(); var ordered := hand.duplicate()
	ordered.sort_custom(func(a: int, b: int) -> bool:
		return host.rules.cards[a].value < host.rules.cards[b].value if host.rules.cards[a].value != host.rules.cards[b].value else a < b)
	host.turn_remaining = 0; var stale := {"action":"bank", "card":hand[0], "revision":host.rules.revision}
	check(not host._action(0, stale) and host.rules.turn == 1, "Input racing a deadline cannot start a new play")
	check(host.rules.hands[0].size() == 7 and host.rules.discard == ordered.slice(0,2), "Timeout discards lowest bank values first, with stable card-ID ties")
	check(host.rules.banks[0].is_empty(), "Timeout never plays or banks a card")
	host.rules.start(2); host._publish(); host.turn_remaining = 0
	host._finish_timeout()
	check(host.rules.turn == 1 and host.rules.hands[0].size() == 7, "A hand already at seven needs no automatic discard")
	host.pending_turn_seconds = 90; host._refresh_options(); host._apply_options()
	check(host.turn_seconds == 90 and host.turn_remaining == 90 and host.load_game_settings({"turn_seconds":60.0}).turn_seconds == 90, "Custom turn duration applies, resets and persists through the shared store")
	host.rules.winner = 0; host._replay()
	check(host.turn_seconds == 90 and host.turn_remaining == 90, "Replay preserves the configured duration and grants a fresh allowance")
	host.pending_turn_seconds = NAN; host._refresh_options(); revision = host.rules.revision; host._apply_options()
	check(host.rules.revision == revision and host.turn_seconds == 90, "Non-finite timer settings cannot mutate the game")
	var saved_store = host.settings_store
	host.shutdown_game(); host.queue_free(); await process_frame
	host = load("res://Games/monopoly-deal/host/main.tscn").instantiate(); root.add_child(host); host.settings_store = saved_store
	context = GameSessionContext.new("monopoly-deal", [], {"id":"host", "display_name":"Host", "color":"#2463eb"}); context.reduced_motion = true
	host.initialize_session(context); host.start_game()
	check(host.turn_seconds == 90 and host.turn_remaining == 90, "A new session restores the saved duration")
	host.settings_button.button_pressed = true; host.turn_timer_toggle.button_pressed = false
	check(not host.turn_length.get_parent().visible and host.turn_timer_enabled and not host.apply_button.disabled, "Timer off is staged and hides the duration until enabled")
	host._apply_options()
	check(not host.turn_timer_enabled and not host.clock_running and not host._snapshot(0).clock.enabled, "Applying timer off publishes an untimed game")
	remaining = host.turn_remaining; host._settle_clock(host.clock_updated_usec + 900000000)
	check(is_equal_approx(remaining, host.turn_remaining) and not host._status().contains(":"), "Disabled timer does not count down or display a time")
	host.turn_remaining = 0; revision = host.rules.revision
	check(not host._finish_timeout() and host.rules.revision == revision, "A disabled timer cannot expire even at zero")
	host.rules.winner = 0; host._replay()
	check(not host.turn_timer_enabled and host.turn_seconds == 90 and not host._snapshot(0).clock.running, "Untimed replay preserves off and the configured duration")
	saved_store = host.settings_store; host.shutdown_game(); host.queue_free(); await process_frame
	host = load("res://Games/monopoly-deal/host/main.tscn").instantiate(); root.add_child(host); host.settings_store = saved_store
	host.initialize_session(context); host.start_game()
	check(not host.turn_timer_enabled and not host.turn_length.get_parent().visible and host.turn_seconds == 90 and host.turn_timer_toggle.text == "Turn Timer: OFF", "A fresh session restores timer off, its visible label and its saved duration")
	host.turn_timer_toggle.button_pressed = true; host._apply_options()
	check(host.turn_timer_enabled and host._snapshot(0).clock.running and host.turn_remaining == 90, "Enabling the timer restores the saved duration and starts a fresh allowance")
	host._action(0, {"action":"end", "revision":host.rules.revision}); host.settings_button.button_pressed = true; revision = host.rules.revision
	await create_timer(0.8).timeout
	check(host.rules.revision == revision and host.ai_timer.is_stopped(), "A real computer turn cannot progress while Settings is open")
	host.settings_button.button_pressed = false; await create_timer(0.8).timeout
	check(host.rules.revision > revision, "Computer play resumes after Settings closes")
	host.shutdown_game(); host.queue_free(); await process_frame
	print("Monopoly Deal timer: %d checks, %d failures" % [checks, failures]); quit(1 if failures else 0)
