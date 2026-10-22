extends SceneTree

const Rules = preload("res://Games/uno/host/rules.gd")
const Host = preload("res://Games/uno/host/main.tscn")
var checks := 0
var failures := 0


func _init() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)


func fixture() -> RefCounted:
	var rules := Rules.new()
	rules.start(4)
	rules.turn = 0
	rules.phase = "play"
	rules.color = "red"
	rules.direction = 1
	rules.drawn = -1
	rules.pending_draw = 0
	rules.discard = [17] # Red 9.
	rules.hands = [[79], [9, 27], [13, 57], [15, 61]]
	rules.deck = range(108).filter(func(id: int) -> bool: return not rules.discard.has(id) and not rules.hands.any(func(hand: Array) -> bool: return hand.has(id)))
	for id in [81, 85, 3]: rules.deck.erase(id)
	rules.deck.append_array([3, 85, 81]) # Blue 3, Blue 5, then playable Red 2.
	rules.jump_open = false
	return rules


func _run() -> void:
	var dealt := Rules.new()
	dealt.force_play = true
	dealt.start(4)
	check(dealt.drawn == -1 and not dealt.requires_forced_play(), "Force Play never treats the initial seven-card deal as a draw decision")
	dealt.restart_round()
	check(dealt.drawn == -1 and not dealt.requires_forced_play(), "Applying settings starts a fresh hand that still needs manual card selection")
	var rules := fixture()
	check(not rules.allow_stacking and not rules.draw_until_play and not rules.force_play, "Stacking, Draw Until Play and Force Play default off")
	check(rules.requires_turn_draw(), "A normal turn with no playable card needs an automatic draw")
	check(rules.draw(0) and rules.turn == 1 and rules.drawn == -1 and rules.hands[0].size() == 2, "Default drawing takes one unplayable card and passes")
	rules = fixture()
	rules.draw_until_play = true
	check(rules.draw(0) and rules.turn == 0 and rules.requires_turn_draw(), "Draw Until Play stays on the same turn after an unplayable card")
	check(rules.draw(0) and rules.turn == 0 and rules.drawn == -1, "A second unplayable draw continues the sequence")
	check(rules.draw(0) and rules.drawn == 3 and not rules.requires_turn_draw() and rules.hands[0].size() == 4, "Repeated draws stop at the first playable card")
	check(rules.legal_cards(0) == [3] and rules.pass_turn(0), "The playable draw can be kept, with only that card eligible for play")
	rules = fixture()
	rules.draw_until_play = true
	rules.hands[0].append(5) # An existing playable Red 3.
	check(rules.draw(0) and rules.turn == 1, "A voluntary unplayable draw does not start Draw Until Play when the hand already had a legal card")
	rules = fixture()
	rules.force_play = true
	rules.hands[0].append(3)
	check(not rules.requires_forced_play() and not rules.requires_turn_draw(), "An existing playable card waits for the player to choose it with Force Play enabled")
	check(rules.play(0,3), "An existing card remains manually playable under Force Play")
	rules = fixture()
	rules.deck.erase(3)
	rules.deck.append(3)
	check(rules.draw(0) and rules.pass_turn(0), "A playable pickup can be kept while Force Play is off")
	rules.force_play = true
	rules.turn = 0
	check(rules.drawn == -1 and not rules.requires_forced_play() and rules.playable(0,3), "A card kept on an earlier turn stays manual when Force Play is enabled")
	rules = fixture()
	rules.draw_until_play = true
	rules.force_play = true
	for step in 3: rules.draw(0)
	var revision: int = rules.revision
	check(rules.requires_forced_play() and not rules.pass_turn(0) and rules.revision == revision, "Force Play rejects keeping a playable drawn card")
	check(rules.play(0, rules.drawn) and rules.drawn == -1 and rules.discard.back() == 3, "Playing the forced draw clears the decision")
	for kind in ["wild", "draw4"]:
		rules = fixture()
		rules.force_play = true
		var wild: int = rules.cards.filter(func(card: Dictionary) -> bool: return card.kind == kind)[0].id
		rules.deck.erase(wild)
		rules.deck.append(wild)
		check(rules.draw(0) and rules.phase == "drawn_color" and rules.drawn == wild, "A forced Wild draw waits for its owner's color choice")
		revision = rules.revision
		check(not rules.choose_color(1, "green") and not rules.choose_color(0, "purple") and not rules.pass_turn(0) and rules.revision == revision, "Forced Wild rejects the wrong chooser, invalid colors and keeping")
		check(rules.call_uno(0) and rules.choose_color(0, "green") and rules.discard.back() == wild and rules.color == "green" and rules.catch_target == -1, "Color selection automatically plays the Wild and preserves a manual UNO declaration")
		check(rules.motion.flights[0].card.selected_color == "green", "The played Wild face publishes the chosen color only after the choice")
	rules = fixture()
	rules.deck.erase(3)
	rules.deck.append(3)
	rules.draw(0)
	check(rules.set_option("force_play", true) and rules.requires_forced_play(), "Enabling Force Play during a drawn-card decision applies to that draw")
	rules = fixture()
	rules.draw_until_play = true
	rules.deck.clear()
	check(rules.draw(0) and rules.turn == 1, "An exhausted pile ends repeated drawing without looping")
	rules = fixture()
	rules.draw_until_play = true
	rules.force_play = true
	rules.pending_draw = 4
	rules.discard = [104]
	check(rules.draw(0) and rules.turn == 1 and rules.drawn == -1 and rules.hands[0].size() == 5, "Draw Until Play and Force Play do not extend or play from a plus-card penalty")
	var host := Host.instantiate()
	root.add_child(host)
	var players: Array = []
	for seat in 4: players.append({"id":"phone-%d" % seat, "display_name":"Player %d" % seat, "color":"#2463eb"})
	var context := GameSessionContext.new("uno", players, {}, true)
	context.reduced_motion = false
	host.settings_store = preload("res://tests/game_settings_fixture.gd").new()
	host.initialize_session(context)
	host.rules = fixture()
	host.rule_choices.draw_until_play.button_pressed = true
	host.rule_choices.force_play.button_pressed = true
	check(not host.rules.draw_until_play and not host.rules.force_play and host.rules.hands[0].size() == 1, "Host draw variants remain pending until Apply")
	host._apply_options()
	check(host.rules.draw_until_play and host.rules.force_play and host.dealing, "Apply restarts the opening deal with both new draw options")
	host.motion_timer.stop()
	host.dealing = false
	host.animating = false
	host.rules = fixture()
	host.rules.force_play = true
	host.rules.hands[0].append_array([3,100])
	host._publish()
	var existing_hand: Array = host.rules.hands[0].duplicate()
	var existing_revision: int = host.rules.revision
	host._automatic_turn()
	await create_timer(.85).timeout
	check(host.auto_timer.is_stopped() and host.rules.hands[0] == existing_hand and host.rules.plays.is_empty() and host.rules.revision == existing_revision, "The authoritative host waits for a human click on existing cards despite Force Play")
	host.handle_controller_message("phone-0", {"action":"play","card":3,"revision":existing_revision})
	check(not host.rules.hands[0].has(3) and host.rules.discard.back() == 3, "A human controller click plays its existing card with Force Play on")
	host.motion_timer.stop()
	host.animating = false
	host.rules = fixture()
	host.rules.draw_until_play = true
	host.rules.force_play = true
	host._publish()
	check(not host.auto_timer.is_stopped(), "Host schedules an automatic draw when the current player has no legal card")
	host._automatic_turn()
	check(host.animating and host.rules.hands[0].size() == 2 and host.auto_timer.is_stopped(), "Automatic draw begins movement and stops the next automatic action")
	revision = host.rules.revision
	host._automatic_turn()
	check(host.rules.revision == revision, "Automatic actions cannot run while a card is moving")
	host.player_disconnected("phone-0")
	await create_timer(.55).timeout
	check(host.auto_timer.is_stopped() and host.rules.revision == revision and host._snapshot(0).paused, "Disconnect prevents continuing the automatic draw sequence")
	host.player_reconnected(players[0])
	check(not host.auto_timer.is_stopped(), "Reconnect schedules the next required draw")
	await create_timer(2.7).timeout
	check(host.rules.drawn == 3 and host.rules.hands[0].size() == 4 and host.rules.turn == 0 and host.rules.requires_forced_play(), "The host draws repeatedly and stops for the playable card to land")
	check(host._snapshot(-1).hand.is_empty() and host._snapshot(1).drawn == -1 and host.rules.motion.flights[0].card.is_empty(), "Draw sequences keep all picked-up identities private")
	host.handle_controller_message("phone-0", {"action":"pass", "revision":host.rules.revision})
	check(host.rules.drawn == 3, "Controller cannot bypass Force Play by sending keep")
	await create_timer(.8).timeout
	check(host.rules.discard.back() == 3 and host.rules.turn == 1 and host.rules.drawn == -1, "The host automatically plays the drawn card after landing")
	host.motion_timer.stop()
	host.animating = false
	host.rules._finish(0)
	host.handle_controller_message("phone-0", {"action":"play_again", "revision":host.rules.revision})
	check(host.rules.draw_until_play and host.rules.force_play and not host.rules.allow_stacking, "Play Again preserves both new options and stacking's off setting")
	host.shutdown_game()
	check(host.auto_timer.is_stopped(), "Leaving cancels all automatic draw/play callbacks")
	host.queue_free()
	await process_frame
	await create_timer(.15).timeout
	print("UNO draw: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
