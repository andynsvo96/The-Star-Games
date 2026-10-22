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


func card(rules: RefCounted, suit: String, kind: String, copy := 0) -> int:
	return rules.cards.filter(func(value: Dictionary) -> bool: return value.color == suit and value.kind == kind)[copy].id


func fixture(count := 4) -> RefCounted:
	var rules := Rules.new()
	rules.start(count)
	rules.turn = 0
	rules.color = "red"
	rules.phase = "play"
	rules.direction = 1
	rules.drawn = -1
	rules.pending_draw = 0
	rules.jump_open = false
	rules.discard = [card(rules, "red", "9")]
	rules.hands = []
	for seat in count:
		rules.hands.append([card(rules, "blue", str(seat + 1)), card(rules, "yellow", str(seat + 1))])
	return rules


func rebuild_deck(rules: RefCounted) -> void:
	rules.deck = range(108).filter(func(id: int) -> bool: return not rules.discard.has(id) and not rules.hands.any(func(hand: Array) -> bool: return hand.has(id)))


func conserved(rules: RefCounted) -> bool:
	var all_cards: Array = rules.deck + rules.discard
	for hand in rules.hands: all_cards.append_array(hand)
	return all_cards.size() == 108 and all_cards.all(func(id: int) -> bool: return all_cards.count(id) == 1)


func _run() -> void:
	seed(7030)
	var rules := fixture()
	check(not rules.allow_stacking and not rules.allow_seven_zero and not rules.allow_jump_ins and not rules.draw_until_play and not rules.force_play, "All five house rules default off")
	for kind in ["draw2", "draw4"]:
		for stacking in [false, true]:
			rules = fixture()
			rules.allow_stacking = stacking
			var suit := "wild" if kind == "draw4" else "red"
			var first := card(rules, suit, kind)
			var same := card(rules, "wild" if kind == "draw4" else "green", kind, 1)
			var mixed := card(rules, "green" if kind == "draw4" else "wild", "draw2" if kind == "draw4" else "draw4")
			rules.hands[0].append(first)
			rules.hands[1].append(same)
			rules.hands[1].append(mixed)
			rebuild_deck(rules)
			check(rules.play(0, first, "blue"), "Plus card starts a pending penalty")
			var revision: int = rules.revision
			check(not rules.play(1, mixed, "red") and rules.revision == revision, "Mixed plus cards are rejected in either direction without changing state")
			check(rules.playable(1, same) == stacking and rules.requires_auto_draw() != stacking, "Stacking toggle determines whether a matching plus card can be kept or stacked")
			if stacking:
				check(rules.play(1, same, "green") and rules.pending_draw == (8 if kind == "draw4" else 4), "Matching plus cards stack across colors")
			check(conserved(rules), "Matching stacks preserve all 108 cards")
	for count in [4, 5, 6]:
		for direction in [-1, 1]:
			rules = fixture(count)
			rules.allow_seven_zero = true
			rules.direction = direction
			var zero := card(rules, "red", "0")
			rules.hands[0].append(zero)
			var before: Array = rules.hands.duplicate(true)
			before[0].erase(zero)
			rebuild_deck(rules)
			check(rules.play(0, zero) and rules.turn == rules.next_seat(0), "Zero passes hands and keeps the next turn in the current direction")
			for source in count:
				check(rules.hands[rules.next_seat(source)] == before[source], "Every entire hand reaches its directional neighbor")
			check(conserved(rules) and rules.motion.flights.size() == count + 1 and rules.motion.flights.slice(1).all(func(flight: Dictionary) -> bool: return flight.kind == "hand" and flight.card.is_empty()), "Hand passing publishes only back-of-hand flights and conserves cards")
			rules = fixture(count)
			rules.allow_seven_zero = true
			rules.direction = direction
			var seven := card(rules, "red", "7")
			rules.hands[0].append(seven)
			rebuild_deck(rules)
			before = rules.hands.duplicate(true)
			before[0].erase(seven)
			check(rules.play(0, seven) and rules.phase == "swap" and rules.swap_seat == 0, "Seven waits for the owner to choose an opponent")
			check(rules.view_for(0).swap_targets.size() == count - 1 and rules.view_for(1).swap_targets.is_empty() and rules.view_for(-1).hand.is_empty(), "Only the chooser receives target controls; private hands remain private")
			var revision: int = rules.revision
			check(not rules.swap_hands(1, 0) and not rules.swap_hands(0, 0) and not rules.swap_hands(0, count) and not rules.draw(0) and not rules.set_option("allow_seven_zero", false) and rules.revision == revision, "Swap blocks wrong chooser, self/invalid targets, other actions and rule changes")
			check(rules.swap_hands(0, count - 1) and rules.hands[0] == before[count - 1] and rules.hands[count - 1] == before[0] and rules.turn == rules.next_seat(0), "Seven exchanges entire remaining hands and resumes the directional next turn")
			check(conserved(rules) and rules.view_for(0).hand.map(func(face: Dictionary) -> int: return int(face.id)) == before[count - 1], "Transferred cards appear only in their new owner's private view")
	rules = fixture()
	var seven := card(rules, "red", "7")
	rules.hands[0].append(seven)
	check(rules.play(0, seven) and rules.phase == "play", "Seven remains an ordinary number when disabled")
	for last_kind in ["7", "0"]:
		rules = fixture()
		rules.allow_seven_zero = true
		rules.hands[0] = [card(rules, "red", last_kind)]
		rebuild_deck(rules)
		rules.play(0, rules.hands[0][0])
		if last_kind == "7":
			check(rules.winner < 0, "Final Seven still waits for a swap selection")
			rules.swap_hands(0, 2)
		check(rules.winner == (2 if last_kind == "7" else 1) and rules.session_wins.count(1) == 1, "Empty-hand winner is checked after the hand transfer, exactly once")
	for enabled in [false, true]:
		rules = fixture()
		rules.allow_jump_ins = enabled
		var first := card(rules, "red", "5")
		var exact := card(rules, "red", "5", 1)
		var color_only := card(rules, "red", "6")
		var number_only := card(rules, "green", "5")
		rules.hands[0].append(first)
		rules.hands[2].append_array([exact, color_only, number_only])
		rebuild_deck(rules)
		rules.play(0, first)
		check(rules.playable(2, exact) == enabled and not rules.playable(2, color_only) and not rules.playable(2, number_only), "Jump-in requires the option and an exact owned number/color match")
		check(not rules.can_jump_in(2, first) and rules.view_for(-1).jump_cards.is_empty(), "Jump-ins reject unowned cards and expose no eligible opponents' cards")
		if enabled:
			check(rules.play(2, exact) and rules.turn == 3 and rules.feedback.events[0].kind == "jump", "Jump-in takes the turn and play continues from the jumping seat")
	rules = fixture()
	rules.allow_jump_ins = true
	rules.hands[0].append(card(rules, "red", "5"))
	rules.hands[2].append(card(rules, "red", "5", 1))
	rebuild_deck(rules)
	rules.play(0, card(rules, "red", "5"))
	rules.draw(1)
	check(rules.jump_cards(2).is_empty(), "The next player's draw closes the jump-in window even if their turn passes")
	# Exercise all combinations, directions/reversals, AI swap choices and reshuffles.
	for count in [4, 5, 6]:
		for settings in 32:
			for level in 3:
				rules = Rules.new()
				rules.allow_stacking = bool(settings & 1)
				rules.allow_seven_zero = bool(settings & 2)
				rules.allow_jump_ins = bool(settings & 4)
				rules.draw_until_play = bool(settings & 8)
				rules.force_play = bool(settings & 16)
				rules.start(count)
				for step in 2400:
					if rules.winner >= 0: break
					var seat: int = rules.turn
					if rules.phase == "play" and step % 3 == 0:
						for candidate in count:
							if not rules.jump_cards(candidate).is_empty():
								seat = candidate
								break
					var input: Dictionary = Rules.computer_action(rules.view_for(seat), level)
					if input.action in ["play", "color"] and rules.hands[seat].size() == 2: rules.call_uno(seat)
					var accepted := false
					match input.action:
						"play": accepted = rules.play(seat, int(input.card), str(input.color))
						"draw": accepted = rules.draw(seat)
						"pass": accepted = rules.pass_turn(seat)
						"color": accepted = rules.choose_color(seat, str(input.color))
						"swap": accepted = rules.swap_hands(seat, int(input.target))
					check(accepted and conserved(rules), "Every variant AI decision is valid and preserves the deck")
				check(rules.winner >= 0 and rules.session_wins.count(1) == 1, "Every variant AI table finishes with one winner")
	var host := Host.instantiate()
	root.add_child(host)
	var players: Array = []
	for seat in 4: players.append({"id":"phone-%d" % seat, "display_name":"Player %d" % seat, "color":"#2463eb"})
	var context := GameSessionContext.new("uno", players, {}, true)
	context.reduced_motion = true
	host.settings_store = preload("res://tests/game_settings_fixture.gd").new()
	host.initialize_session(context)
	host.start_game()
	await create_timer(.6).timeout
	host.rules = fixture()
	host.pending_options = host.rules.view_for(-1).options.duplicate()
	var before: Array = host.rules.hands.duplicate(true)
	host.rule_choices.allow_seven_zero.button_pressed = true
	host.rule_choices.allow_jump_ins.button_pressed = true
	host.rule_choices.allow_stacking.button_pressed = false
	check(not host.rules.allow_seven_zero and not host.rules.allow_jump_ins and not host.rules.allow_stacking and host.rules.hands == before and not host.apply_options.disabled, "Host toggles stage options and enable Apply while the live hand stays unchanged")
	host._apply_options()
	check(host.rules.allow_seven_zero and host.rules.allow_jump_ins and not host.rules.allow_stacking and host.rules.hands.all(func(hand: Array) -> bool: return hand.size() == 7) and host.apply_options.disabled, "Apply starts a fresh seven-card hand using all staged options")
	host.rules = fixture()
	host.rules.allow_seven_zero = true
	host.rules.allow_jump_ins = true
	var revision: int = host.rules.revision
	host.handle_controller_message("phone-0", {"action":"set_option", "option":"allow_stacking", "enabled":true, "revision":revision})
	check(host.rules.revision == revision and not host.rules.allow_stacking, "Phone controllers cannot change host options")
	host.rules.hands[0].append(card(host.rules, "red", "7"))
	rebuild_deck(host.rules)
	host.handle_controller_message("phone-0", {"action":"play", "card":card(host.rules, "red", "7"), "revision":revision})
	await create_timer(.6).timeout
	var snapshot: Dictionary = host._snapshot(0)
	host.player_disconnected("phone-0")
	host.player_reconnected(players[0])
	check(host._snapshot(0).swap_targets == snapshot.swap_targets and host.rules.phase == "swap", "Reconnect restores a pending hand-swap choice")
	for target in [null, "2", true, -1, 4, 1.5]: host.handle_controller_message("phone-0", {"action":"swap", "target":target, "revision":host.rules.revision})
	check(host.rules.phase == "swap", "Host rejects malformed swap targets")
	host.handle_controller_message("phone-0", {"action":"swap", "target":2, "revision":revision})
	check(host.rules.phase == "swap", "Host rejects stale swap selection")
	host.handle_controller_message("phone-0", {"action":"swap", "target":2, "revision":host.rules.revision})
	check(host.rules.phase == "play", "Host accepts the chooser's current valid swap")
	await create_timer(.6).timeout
	host.rules._finish(0)
	host.handle_controller_message("phone-0", {"action":"play_again", "revision":host.rules.revision})
	check(host.rules.allow_seven_zero and host.rules.allow_jump_ins and not host.rules.allow_stacking, "Play Again preserves all three rule settings")
	host.rules = fixture()
	host.rules.allow_stacking = false
	host.rules.hands[0].append(card(host.rules, "red", "draw2"))
	var kept_plus := card(host.rules, "green", "draw2")
	host.rules.hands[1].append(kept_plus)
	rebuild_deck(host.rules)
	var recipient_count: int = host.rules.hands[1].size()
	host.handle_controller_message("phone-0", {"action":"play", "card":card(host.rules, "red", "draw2"), "revision":host.rules.revision})
	check(host.rules.pending_draw == 0 and host.rules.hands[1].size() == recipient_count + 2 and host.rules.hands[1].has(kept_plus) and host.rules.turn == 2, "Disabling stacking makes the host draw automatically even when the recipient holds a matching plus card")
	await create_timer(.6).timeout
	host.rules = fixture()
	host.rules.hands[0].append(card(host.rules, "red", "draw2"))
	host.rules.hands[1].append(card(host.rules, "wild", "draw4"))
	rebuild_deck(host.rules)
	recipient_count = host.rules.hands[1].size()
	host.handle_controller_message("phone-0", {"action":"play", "card":card(host.rules, "red", "draw2"), "revision":host.rules.revision})
	check(host.rules.pending_draw == 0 and host.rules.hands[1].size() == recipient_count + 2, "A recipient with only the wrong plus kind also draws automatically")
	await create_timer(.6).timeout
	host.rules = fixture()
	host.rules.allow_jump_ins = true
	var first := card(host.rules, "red", "5")
	var exact := card(host.rules, "red", "5", 1)
	host.rules.hands[0].append(first)
	host.rules.hands[2] = [host.rules.hands[2][0], exact]
	rebuild_deck(host.rules)
	host.session.reduced_motion = false
	host.handle_controller_message("phone-0", {"action":"play", "card":first, "revision":host.rules.revision})
	revision = host.rules.revision
	host.handle_controller_message("phone-2", {"action":"play", "card":exact, "revision":revision})
	check(host.animating and host.rules.revision == revision, "Host discards jump-ins while the discard is still moving")
	await create_timer(.55).timeout
	host.motion_timer.stop()
	host._settled()
	host.handle_controller_message("phone-2", {"action":"play", "card":exact, "revision":revision - 1})
	check(host.rules.revision == revision, "Host rejects a stale jump-in after the discard lands")
	host.seats[2].ai = true
	host._computer_jump()
	check(host.rules.discard.back() == exact and host.rules.turn == 3 and host.rules.hands[2].size() == 1, "AI declares before jumping with its own exact card")
	host.seats[2].ai = false
	# Allow the final flight and spoken cue to finish before checking exit cleanup.
	await create_timer(1.0).timeout
	host.shutdown_game()
	check(host.jump_timer.is_stopped() and not host.table.swap_buttons.any(func(button: Button) -> bool: return button.is_visible_in_tree()), "Exit stops jump-in callbacks and closes the swap dialog")
	host.queue_free()
	await process_frame
	await create_timer(.15).timeout
	print("UNO variants: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
