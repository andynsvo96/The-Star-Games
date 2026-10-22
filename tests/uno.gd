extends SceneTree

const Rules = preload("res://Games/uno/host/rules.gd")
const Host = preload("res://Games/uno/host/main.tscn")
var checks := 0
var failures := 0
var awards := 0
var reports := 0
var private_views: Dictionary = {}
var public_view: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)


func card(rules: RefCounted, suit: String, kind: String, copy := 0) -> int:
	return rules.cards.filter(func(value: Dictionary) -> bool: return value.color == suit and value.kind == kind)[copy].id


func fixture(count := 4) -> RefCounted:
	var rules := Rules.new()
	rules.start(count)
	rules.turn = 0
	rules.direction = 1
	rules.color = "red"
	rules.phase = "play"
	rules.drawn = -1
	rules.pending_draw = 0
	rules.allow_stacking = true # Explicitly exercise the optional stacking variant.
	rules.jump_open = false
	rules.discard = [card(rules, "red", "0")]
	rules.hands = [[card(rules, "red", "5"), card(rules, "blue", "3")], [card(rules, "yellow", "6")], [card(rules, "green", "7")], [card(rules, "blue", "8")]]
	while rules.hands.size() < count:
		rules.hands.append([card(rules, "red", str(rules.hands.size() - 3))])
	rules.deck = range(108).filter(func(id: int) -> bool: return not rules.discard.has(id) and not rules.hands.any(func(hand: Array) -> bool: return hand.has(id)))
	return rules


func host_for(count: int) -> Node:
	var players: Array = []
	for index in count:
		players.append({"id": "phone-%d" % index, "display_name": "Player %d" % index, "color": "#2463eb", "reconnect_token": "secret-%d" % index})
	var host := Host.instantiate()
	root.add_child(host)
	var context := GameSessionContext.new("uno", players, {"id": "local-host", "display_name": "Host", "color": "#e53935"}, count > 0)
	context.reduced_motion = true
	host.settings_store = preload("res://tests/game_settings_fixture.gd").new()
	host.initialize_session(context)
	host.points_awarded.connect(func(_id: String, amount: int) -> void: awards += amount)
	host.result_reported.connect(func(_id: String, _win: bool) -> void: reports += 1)
	host.controller_private_state_updated.connect(func(id: String, view: Dictionary) -> void: private_views[id] = view)
	host.controller_state_updated.connect(func(view: Dictionary) -> void: public_view = view)
	host.start_game()
	host.ai_timer.stop()
	host.catch_timer.stop()
	return host


func _run() -> void:
	seed(1025)
	var rules := fixture()
	check(rules.cards.size() == 108 and rules.cards.filter(func(value: Dictionary) -> bool: return value.kind == "draw4").size() == 4, "Original deck contains 108 cards and four Wild Draw Fours")
	check(rules.cards.filter(func(value: Dictionary) -> bool: return value.kind == "0").size() == 4, "Each color has exactly one zero")
	check(not rules.play(1, rules.hands[1][0]) and not rules.play(0, rules.hands[1][0]), "Wrong turn and another player's card are rejected")
	check(not rules.play(0, card(rules, "blue", "3")), "Color and number mismatch is rejected")
	var revision: int = rules.revision
	check(rules.call_uno(0) and rules.armed[0] and rules.revision == revision + 1, "Manual UNO can be armed with two cards before playing")
	check(rules.play(0, card(rules, "red", "5")) and rules.hands[0].size() == 1 and rules.catch_target == -1 and rules.turn == 1, "Declaring before playing avoids the automatic penalty")
	check(rules.plays.size() == 1 and rules.plays[0].seat == 0 and rules.plays[0].card.kind == "5", "Played-card log records accepted plays without rejected inputs or UNO calls")
	check(rules.view_for(-1).uno_players == [true,false,false,false] and rules.view_for(-1).hand.is_empty(), "Last-card declaration is public persistent state without revealing a hand")
	rules.turn = 0
	rules.draw(0)
	check(not rules.view_for(-1).uno_players[0], "Drawing another card clears the persistent UNO marker")
	rules = fixture()
	rules.play(0, card(rules, "red", "5"))
	check(rules.catch_target == -1 and rules.hands[0].size() == 3, "Missed UNO automatically draws two cards without an opponent catch")
	check(rules.motion.flights.size() == 2 and rules.motion.flights[1].kind == "draw" and rules.motion.flights[1].count == 2 and rules.motion.flights[1].card.is_empty(), "Missed UNO movement follows the play without exposing penalty faces")
	check(not rules.call_uno(0) and not rules.catch_uno(2, 0) and rules.hands[0].size() == 3, "Late calls and catches cannot undo or duplicate the penalty")
	rules = fixture()
	rules.play(0, card(rules, "red", "5"))
	check(not rules.call_uno(0) and not rules.catch_uno(1, 0), "Declaring after playing cannot rescue a missed UNO")
	rules = fixture()
	rules.play(0, card(rules, "red", "5"))
	rules.draw(1)
	check(not rules.catch_uno(2, 0), "Starting the next turn closes the missed-call catch window")
	for kind in ["skip", "reverse", "draw2"]:
		rules = fixture()
		rules.hands[0].append(card(rules, "red", kind))
		var count: int = rules.hands[1].size()
		check(rules.play(0, card(rules, "red", kind)), "Action card is playable")
		check(rules.turn == (3 if kind == "reverse" else 1 if kind == "draw2" else 2), "Action changes turn in the correct direction")
		if kind == "draw2":
			check(rules.hands[1].size() == count and rules.pending_draw == 2, "Draw Two remains pending until the recipient stacks or draws")
			check(rules.draw(1) and rules.hands[1].size() == count + 2 and rules.pending_draw == 0 and rules.turn == 2, "Taking the full penalty skips the recipient and clears the total")
		if kind == "skip": check(rules.feedback.events[0].kind == "skip" and rules.feedback.events[0].seat == 1, "Skip feedback identifies the skipped player")
	rules = fixture()
	var drawn: int = card(rules, "red", "9")
	rules.deck.erase(drawn)
	rules.deck.append(drawn)
	check(rules.draw(0) and rules.turn == 0 and rules.drawn == drawn, "A playable single draw allows an optional play")
	check(not rules.play(0, card(rules, "red", "5")), "Only the newly drawn card may be played after drawing")
	check(rules.pass_turn(0) and rules.turn == 1 and not rules.pass_turn(1), "Keeping the draw ends the turn; passing without drawing is rejected")
	for matching_color in [false, true]:
		rules = fixture()
		var wild: int = card(rules, "wild", "draw4")
		rules.hands[0] = [wild, card(rules, "red" if matching_color else "blue", "5")]
		check(not rules.play(0, wild, "purple"), "Invalid Wild colors cannot change state")
		var before: int = rules.hands[1].size()
		check(rules.play(0, wild, "green") and rules.phase == "play" and rules.color == "green", "Draw Four is allowed regardless of other colors, with no decision phase")
		check(rules.hands[1].size() == before and rules.turn == 1 and rules.pending_draw == 4, "Draw Four passes a pending four-card penalty to the next player")
		check(rules.motion.flights[0].kind == "play" and rules.motion.flights[1].seat == 0, "Missed UNO penalty affects the caller while Draw Four remains pending")
		check(rules.view_for(-1).top.selected_color == "green" and rules.motion.flights[0].card.selected_color == "green" and not rules.cards[wild].has("selected_color"), "Chosen Wild color is public display metadata without changing the rules card")
		check(rules.plays.size() == 1 and rules.plays[0].color == "green" and rules.plays[0].card.color == "wild", "Log preserves the played Wild and its chosen color without logging penalty draws")
		check(not rules.view_for(-1).has("challenge_result") and rules.view_for(1).pending_draw == 4, "Only the public penalty total is exposed")
		check(rules.draw(1) and rules.hands[1].size() == before + 4 and rules.turn == 2 and rules.motion.flights[0].card.is_empty(), "Taking Draw Four exposes count-only movement and skips the turn")
	rules = fixture()
	var first_four: int = card(rules, "wild", "draw4", 0)
	var second_four: int = card(rules, "wild", "draw4", 1)
	var two: int = card(rules, "green", "draw2")
	rules.hands[0].append(first_four)
	rules.hands[1].append(second_four)
	rules.hands[2].append(two)
	check(rules.play(0, first_four, "blue") and rules.play(1, second_four, "red") and rules.pending_draw == 8, "Two Draw Fours accumulate a public +8")
	check(not rules.play(2, rules.hands[2][0]) and not rules.pass_turn(2), "A pending stack rejects ordinary cards and passing")
	check(not rules.play(2, two) and rules.pending_draw == 8 and rules.color == "red", "Draw Two cannot be stacked on Draw Four")
	var recipient_count: int = rules.hands[2].size()
	check(rules.view_for(-1).pending_draw == 8 and rules.view_for(-1).hand.is_empty(), "Spectators receive the accumulated total without secret hands")
	check(rules.draw(2) and rules.hands[2].size() == recipient_count + 8 and rules.pending_draw == 0 and rules.turn == 3, "The recipient receives all eight cards once and loses their turn")
	check(rules.motion.flights[0].count == 8 and rules.motion.flights[0].card.is_empty(), "Stack draw movement keeps drawn identities private")
	check(not rules.requires_auto_draw(), "Taking a penalty clears automatic draw eligibility")
	rules = fixture()
	check(rules.call_uno(0) and rules.feedback.events[0].kind == "uno" and rules.feedback.events[0].seat == 0, "A separate pre-play UNO action publishes a player-specific logo event")
	check(rules.hands[0].size() == 2 and rules.plays.is_empty(), "UNO declares without selecting or playing a card")
	check(rules.play(0, rules.hands[0][0]) and rules.hands[0].size() == 1, "A subsequent separate play consumes the declaration")
	rules = fixture()
	rules.hands[0] = [card(rules, "red", "draw2")]
	check(rules.play(0, rules.hands[0][0]) and rules.winner == 0 and rules.session_wins[0] == 1 and rules.hands[1].size() == 3, "Last Draw Two settles penalty and records one immediate winner")
	check(not rules.play(1, rules.hands[1][0]), "Moves stop once a hand has a winner")
	var wins: Array = rules.session_wins.duplicate()
	var dealer: int = rules.dealer
	check(rules.play_again() and rules.session_wins == wins and rules.history.size() == 1 and rules.dealer == (dealer + 1) % 4 and rules.round_number == 2, "Replay rotates the dealer and preserves wins/history")
	check(rules.plays.is_empty(), "Replay starts a fresh played-card log")
	rules = fixture()
	rules.hands[0] = [card(rules, "wild", "draw4")]
	rules.play(0, rules.hands[0][0], "blue")
	check(rules.winner == 0 and rules.hands[1].size() == 5 and rules.session_wins[0] == 1, "Final Draw Four applies its penalty and immediately records one winner")
	rules = fixture()
	rules.deck.clear()
	rules.discard = [card(rules, "green", "2"), card(rules, "yellow", "4"), card(rules, "red", "0")]
	check(rules.draw(0) and rules.discard == [card(rules, "red", "0")] and rules.deck.size() == 1, "Empty draw pile reshuffles discards while preserving the top card")
	for count in [4, 5, 6]:
		for level in 3:
			for sample in 5:
				rules = Rules.new()
				rules.start(count)
				check(rules.hands.all(func(hand: Array) -> bool: return hand.size() in [7, 9]) and rules.discard.size() == 1, "Deal supports four to six seats and starting actions")
				for step in 1600:
					if rules.winner >= 0: break
					var seat: int = rules.turn
					var decision: Dictionary = Rules.computer_action(rules.view_for(seat), level)
					if decision.action == "play" and rules.hands[seat].size() == 2: rules.call_uno(seat)
					var accepted := false
					match decision.action:
						"play": accepted = rules.play(seat, int(decision.card), str(decision.color))
						"draw": accepted = rules.draw(seat)
						"pass": accepted = rules.pass_turn(seat)
						"color": accepted = rules.choose_color(seat, str(decision.color))
					check(accepted, "Every computer decision is accepted by the authoritative rules")
					var all_cards: Array = rules.deck.duplicate()
					all_cards.append_array(rules.discard)
					for hand in rules.hands: all_cards.append_array(hand)
					check(all_cards.size() == 108 and all_cards.all(func(id: int) -> bool: return all_cards.count(id) == 1), "Cards are conserved without duplicates through draws, penalties and shuffles")
				check(rules.winner >= 0 and rules.session_wins.count(1) == 1, "AI tables finish with exactly one winner")
	for count in range(7):
		var host := host_for(count)
		check(host.seats.size() == maxi(4, count) and host.seats.filter(func(player: Dictionary) -> bool: return player.ai).size() == (3 if count == 0 else maxi(0, 4 - count)), "AI fills only to four; host is a seat only with no phones")
		check(host.sounds.size() == 4 and not host.sounds.has("uno") and host.sounds.values().all(func(sound: AudioStreamPlayer) -> bool: return sound.bus == "Effects" and sound.stream is AudioStreamOggVorbis and sound.stream.get_length() > 0 and not sound.stream.loop), "UNO declarations are silent; card and victory cues retain Effects volume")
		check(is_equal_approx(host.sounds.win.stream.get_length(), AudioStreamOggVorbis.load_from_file("res://Games/uno/audio/victory.ogg").get_length()) and is_equal_approx(host.sounds.shuffle.stream.get_length(), AudioStreamOggVorbis.load_from_file("res://Games/uno/audio/card-shuffle.ogg").get_length()) and not is_equal_approx(host.sounds.win.stream.get_length(), host.sounds.shuffle.stream.get_length()), "Victory uses its own fanfare and opening deals retain their shuffle foley")
		check(public_view.hand.is_empty() and public_view.legal_cards.is_empty() and not JSON.stringify(public_view).contains("secret-"), "Host public snapshot omits every private hand and token")
		for player in host.session.players:
			check(private_views[player.id].viewer == host._seat_for(player.id) and private_views[player.id].hand.size() == host.rules.hands[host._seat_for(player.id)].size(), "Admitted phone receives only its own hand")
		if count > 0:
			host.rules = fixture(host.seats.size())
			var base: int = host.rules.revision
			for invalid in [null, true, "0", -1, 108, 1.5, INF, NAN, {}, []]:
				host.handle_controller_message("phone-0", {"action": "play", "revision": base, "card": invalid})
			check(host.rules.revision == base, "Malformed card values do not change authoritative state")
			host.handle_controller_message("intruder", {"action": "draw", "revision": base})
			host.handle_controller_message("phone-0", {"action": "draw", "revision": base - 1})
			for action in ["accept", "challenge"]: host.handle_controller_message("phone-0", {"action": action, "revision": base})
			host.handle_controller_message("phone-0", {"action": "play", "card": host.rules.hands[0][0], "call_uno": "true", "revision": base})
			check(host.rules.revision == base, "Unadmitted sender and stale input are ignored")
			host.animating = true
			host.handle_controller_message("phone-0", {"action": "draw", "revision": base})
			check(host.rules.revision == base, "Input during movement is discarded")
			host.animating = false
			host.player_disconnected("phone-0")
			var own: Array = host.rules.hands[0].duplicate()
			host.handle_controller_message("phone-0", {"action": "draw", "revision": base})
			check(host.rules.revision == base and host.rules.hands[0] == own and host._snapshot(0).paused, "Disconnect pauses play while retaining the exact hand")
			host.player_reconnected({"id": "intruder"})
			check(not host.missing.is_empty(), "Unknown reconnect cannot clear the pause")
			host.player_reconnected(host.session.players[0])
			check(host.missing.is_empty() and host._snapshot(0).hand.size() == own.size(), "Admitted reconnect restores the same seat and hand")
			host.rules.hands[0] = [card(host.rules, "red", "5")]
			host.rules.play(0, host.rules.hands[0][0])
			var previous_awards := awards
			var previous_reports := reports
			host._publish()
			host._publish()
			check(awards - previous_awards == (1 if count >= 4 else 0) and reports - previous_reports == (count if count >= 4 else 0), "Only entirely human tables award one win point and one result per player, once")
		host.shutdown_game()
		check(host.stopped and host.ai_timer.is_stopped() and host.catch_timer.is_stopped(), "Leaving cancels AI and catch callbacks")
		host.queue_free()
		await process_frame
	var automatic_host := host_for(4)
	automatic_host.rules = fixture()
	var penalty_card: int = card(automatic_host.rules,"wild","draw4")
	automatic_host.rules.hands[0].append(penalty_card)
	var forced_count: int = automatic_host.rules.hands[1].size()
	automatic_host.handle_controller_message("phone-0",{"action":"play","card":penalty_card,"color":"blue","revision":automatic_host.rules.revision})
	check(automatic_host.rules.pending_draw == 0 and automatic_host.rules.hands[1].size() == forced_count + 4 and automatic_host.rules.turn == 2, "Host automatically takes Draw Four when the recipient has nothing to stack")
	automatic_host.rules = fixture()
	penalty_card = card(automatic_host.rules,"red","draw2")
	automatic_host.rules.hands[0].append(penalty_card)
	automatic_host.rules.hands[1].append(card(automatic_host.rules,"green","draw2"))
	automatic_host.handle_controller_message("phone-0",{"action":"play","card":penalty_card,"revision":automatic_host.rules.revision})
	check(automatic_host.rules.pending_draw == 2 and not automatic_host.rules.requires_auto_draw() and automatic_host._snapshot(1).legal_cards.size() == 1, "A recipient with a plus card can choose to stack or keep it and draw")
	automatic_host.shutdown_game()
	automatic_host.queue_free()
	await process_frame
	var dealing_host := host_for(4)
	dealing_host.rules.pending_draw = 0
	dealing_host.session.reduced_motion = false
	dealing_host._start_deal()
	dealing_host._publish()
	var deal_revision: int = dealing_host.rules.revision
	var presentation_revision: int = dealing_host.deal_revision
	dealing_host.handle_controller_message("phone-0",{"action":"draw","revision":deal_revision})
	check(dealing_host.dealing and dealing_host.animating and dealing_host.rules.revision == deal_revision, "Opening shuffle/deal locks host-authoritative input")
	check(dealing_host._snapshot(-1).hand.is_empty() and dealing_host._snapshot(-1).deal.seats == 4 and not JSON.stringify(dealing_host._snapshot(-1).deal).contains("card"), "Deal timeline exposes no private cards")
	await create_timer(1.3).timeout
	check(dealing_host.table._visible_count(0) > 0 and dealing_host.table._visible_count(0) < 7, "Card counts grow progressively during the seven-card deal")
	dealing_host.player_disconnected("phone-0")
	var frozen_deal: float = dealing_host._snapshot(0).deal.elapsed
	await create_timer(.15).timeout
	check(is_equal_approx(dealing_host._snapshot(0).deal.elapsed,frozen_deal), "Disconnect freezes the authoritative deal clock")
	dealing_host.player_reconnected(dealing_host.session.players[0])
	await create_timer(dealing_host.motion_timer.time_left + .08).timeout
	check(not dealing_host.dealing and not dealing_host.animating and dealing_host.table._visible_count(0) == 7, "Deal settles before placement unlocks")
	dealing_host.rules._finish(0)
	dealing_host._publish()
	dealing_host.handle_controller_message("phone-0",{"action":"play_again","revision":dealing_host.rules.revision})
	check(dealing_host.dealing and dealing_host._snapshot(0).deal.revision != presentation_revision, "Every replay starts a new shuffle/deal timeline")
	dealing_host.shutdown_game()
	check(dealing_host.queued_sounds.is_empty() and dealing_host.motion_timer.is_stopped(), "Exit cancels opening deal audio and callbacks")
	dealing_host.queue_free()
	await process_frame
	var moving_host := host_for(4)
	moving_host.rules = fixture()
	moving_host.session.reduced_motion = false
	moving_host._publish()
	moving_host.handle_controller_message("phone-0", {"action": "play", "card": moving_host.rules.hands[0][0], "revision": moving_host.rules.revision})
	check(moving_host.animating and moving_host.table.flights.size() == 2 and is_equal_approx(moving_host.motion_timer.time_left, 1.06), "Missed UNO locks movement until the played card and both automatic penalty cards land")
	var moving_revision: int = moving_host.rules.revision
	moving_host.handle_controller_message("phone-1", {"action": "draw", "revision": moving_revision})
	check(moving_host.rules.revision == moving_revision, "The following player cannot move while a card travels")
	moving_host._publish()
	check(moving_host.table.flights.size() == 2, "Duplicate host snapshots do not restart the play and automatic UNO penalty")
	moving_host.handle_controller_message("phone-2", {"action": "catch", "target": 0, "revision": moving_revision})
	check(moving_host.table.flights.size() == 2 and moving_host.motion_timer.time_left > 1.0 and moving_host.rules.hands[0].size() == 3, "A catch cannot add a second penalty while the automatic cards are moving")
	check(public_view.motion.flights[1].card.is_empty(), "Penalty movement publishes counts without drawn identities")
	await create_timer(1.15).timeout
	check(not moving_host.animating and moving_host.table.flights.is_empty(), "Input resumes only after all play and catch cards have landed")
	moving_host.rules = fixture()
	moving_host.rules.hands[0] = [card(moving_host.rules, "wild", "draw4")]
	moving_host._publish()
	var prior_awards := awards
	moving_host.handle_controller_message("phone-0", {"action": "play", "card": moving_host.rules.hands[0][0], "color": "blue", "revision": moving_host.rules.revision})
	check(moving_host.rules.winner == 0 and moving_host.animating and not moving_host.result_sent and awards == prior_awards, "The winning Draw Four settles card movement before saved results and celebration")
	moving_host.handle_controller_message("phone-0", {"action": "play_again", "revision": moving_host.rules.revision})
	check(moving_host.rules.phase == "finished", "Replay cannot interrupt a winning card or its automatic penalty")
	await create_timer(1.4).timeout
	check(not moving_host.animating and moving_host.result_sent and awards == prior_awards + 1, "One winning result is recorded after all four penalty cards land")
	moving_host._publish()
	check(awards == prior_awards + 1, "Movement completion and duplicate syncs cannot award a second win")
	moving_host.shutdown_game()
	check(moving_host.queued_sounds.is_empty() and moving_host.sounds.values().all(func(sound: AudioStreamPlayer) -> bool: return not sound.playing), "Leaving cancels queued movement audio and stops all card sounds")
	moving_host.queue_free()
	await process_frame
	var local_host := host_for(0)
	local_host.rules = fixture()
	local_host._publish()
	check(local_host.actions.draw.visible and not local_host.actions.draw.disabled, "DRAW appears for the host's playable turn")
	local_host.rules.turn = 1
	local_host._publish()
	check(local_host.actions.draw.visible and local_host.actions.draw.disabled, "DRAW remains visible and grey during the computer's turn")
	local_host.rules.turn = 0
	local_host._publish()
	var selection_revision: int = local_host.rules.revision
	local_host.table.uno_pressed.emit()
	check(local_host.rules.armed[0] and local_host.rules.hands[0].size() == 2 and local_host.rules.revision == selection_revision + 1 and local_host.selected_card == -1, "Native UNO declares before selection without playing a card")
	local_host._select_card(local_host.rules.hands[0][0])
	check(local_host.rules.hands[0].size() == 1 and local_host.rules.catch_target == -1 and local_host.selected_card == -1, "Native selection immediately plays the card after a separate declaration")
	local_host.rules = fixture()
	local_host._select_card(local_host.rules.hands[0][0])
	check(local_host.rules.hands[0].size() == 3, "Native card selection without pressing UNO automatically draws two penalty cards")
	local_host.rules = fixture()
	local_host.player_disconnected("unadmitted")
	local_host.shutdown_game()
	check(not local_host.color_dialog.visible and local_host.queued_sounds.all(func(timer: Timer) -> bool: return timer.is_stopped()), "Leaving closes color selection and cancels scheduled card sounds")
	local_host.queue_free()
	await process_frame
	var catalog := GameCatalog.new()
	catalog.scan()
	var entries: Array = catalog.games.filter(func(game: Dictionary) -> bool: return game.id == "uno")
	check(entries.size() == 1 and entries[0].min_players == 1 and entries[0].max_players == 6, "Catalog admits one to six humans for UNO")
	# Allow the audio mixer to release stopped playback references before exit.
	await create_timer(0.15).timeout
	print("UNO: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
