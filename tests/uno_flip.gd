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
	var found: Array = rules.cards.filter(func(face: Dictionary) -> bool: return face.color == suit and face.kind == kind)
	return int(found[copy].id)


func fixture(dark := false) -> RefCounted:
	var rules := Rules.new()
	rules.gamemode = "flip"
	rules.start(4)
	rules.side = "dark" if dark else "light"
	rules._activate_faces()
	rules.turn = 0
	rules.direction = 1
	rules.phase = "play"
	rules.drawn = -1
	rules.pending_draw = 0
	rules.pending_color = ""
	rules.winner = -1
	rules.motion.clear()
	return rules


func arrange(rules: RefCounted, own: Array, pile: Array, stock: Array = []) -> void:
	rules.hands = [own.duplicate(), [], [], []]
	rules.discard = pile.duplicate()
	var available: Array = range(112).filter(func(id: int) -> bool: return not own.has(id) and not pile.has(id) and not stock.has(id))
	for seat in range(1, 4):
		for index in 3: rules.hands[seat].append(available.pop_front())
	rules.deck = available + stock
	rules.color = rules.cards[pile.back()].color
	rules.armed.fill(false)
	rules.declared.fill(false)


func conserved(rules: RefCounted) -> bool:
	var ids: Array = rules.deck + rules.discard
	for hand in rules.hands: ids.append_array(hand)
	ids.sort()
	return ids == range(112)


func _run() -> void:
	seed(3829)
	var rules := fixture()
	check(rules.cards.size() == 112 and rules.flip_faces.size() == 112, "Flip uses 112 fixed two-sided identities")
	for dark in [false, true]:
		rules.side = "dark" if dark else "light"
		rules._activate_faces()
		var palette: Array = Rules.DARK_COLORS if dark else Rules.COLORS
		for suit in palette:
			for kind in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "reverse", "flip", "draw5" if dark else "draw1", "skip_all" if dark else "skip"]:
				check(rules.cards.filter(func(face: Dictionary) -> bool: return face.color == suit and face.kind == kind).size() == 2, "Two copies of every Flip colored face: " + suit + " " + kind)
		for kind in ["wild", "draw_color" if dark else "draw2"]:
			check(rules.cards.filter(func(face: Dictionary) -> bool: return face.color == "wild" and face.kind == kind).size() == 4, "Four copies of each Flip Wild")
		check(not rules.cards.any(func(face: Dictionary) -> bool: return face.kind in ["0", "draw4"]), "Flip has no zero or Draw Four")
	check(not rules.set_gamemode("unknown") and rules.gamemode == "flip", "Unknown modes are rejected")

	# Turn over the entire piles, rather than the played Flip alone.
	rules = fixture()
	var flip := card(rules, "red", "flip")
	var first := card(rules, "blue", "3")
	var middle := card(rules, "red", "4")
	arrange(rules, [flip, card(rules, "green", "8"), card(rules, "blue", "2")], [first, middle])
	var stock: Array = rules.deck.duplicate()
	stock.reverse()
	var hand: Array = rules.hands[0].slice(1)
	var faces: Array = rules.flip_faces.duplicate(true)
	check(rules.play(0, flip), "A matching Flip can be played")
	check(rules.side == "dark" and rules.discard == [flip, middle, first] and rules.deck == stock, "Flip reverses both piles and exposes the oldest discard's other face")
	check(rules.hands[0] == hand and rules.flip_faces == faces and conserved(rules), "Flip preserves every held card identity and fixed face pair")
	check(rules.direction == 1 and rules.motion.flights.back().kind == "flip", "Flip keeps direction and adds a separate motion lock")
	rules._flip(0)
	check(rules.side == "light" and rules.discard == [first, middle, flip] and rules.flip_faces == faces, "A second Flip restores the same light faces and pile orientation")
	var public: Dictionary = rules.view_for(-1)
	check(public.hand.is_empty() and public.backs.all(func(backs: Array) -> bool: return backs.all(func(face: Dictionary) -> bool: return not face.has("id") and face.side == "dark")), "Public reverse faces never include active hands or card IDs")
	check(rules.view_for(0).hand.all(func(face: Dictionary) -> bool: return face.has("opposite")), "Only the owner receives both faces of held card identities")

	# Revealing an action does not trigger it. A revealed Wild needs a color.
	rules = fixture()
	first = rules.flip_faces.find(rules.flip_faces.filter(func(pair: Dictionary) -> bool: return pair.dark.color == "wild")[0])
	flip = card(rules, "red", "flip")
	arrange(rules, [flip,card(rules,"green","8"),card(rules,"blue","2")], [first,card(rules,"red","4")])
	check(rules.play(0,flip) and rules.phase == "flip_color" and rules.turn == 0 and rules.pending_draw == 0 and rules.pending_color.is_empty(), "A newly revealed Wild asks the flipper for color without applying its draw action")
	check(not rules.choose_color(1,"pink") and not rules.choose_color(0,"red") and rules.choose_color(0,"purple") and rules.turn == 1 and rules.color == "purple", "Revealed Wild choices validate player and active palette, then continue normal order")

	for dark in [false,true]:
		rules = fixture(dark)
		var suit: String = "pink" if dark else "red"
		var draw_kind: String = "draw5" if dark else "draw1"
		var amount := 5 if dark else 1
		var draw_card := card(rules,suit,draw_kind)
		arrange(rules,[draw_card,card(rules,suit,"8"),card(rules,suit,"2")],[card(rules,suit,"4")])
		check(rules.play(0,draw_card) and rules.pending_draw == amount and rules.requires_auto_draw(), "Numeric draw penalty waits for landing without stacking")
		var before: int = rules.hands[1].size()
		check(rules.draw(1) and rules.hands[1].size() == before + amount and rules.turn == 2 and rules.drawn == -1, "Draw One/Five is received in full and skips the recipient")
		rules = fixture(dark)
		draw_card = card(rules,suit,draw_kind)
		arrange(rules,[draw_card],[card(rules,suit,"4")])
		before = rules.hands[1].size()
		check(rules.play(0,draw_card) and rules.winner == 0 and rules.hands[1].size() == before + amount and conserved(rules), "A final Draw One/Five applies its penalty before the win")
		rules = fixture(dark)
		rules.allow_stacking = true
		var other_suit: String = "teal" if dark else "blue"
		draw_card = card(rules,suit,draw_kind)
		var stack := card(rules,other_suit,draw_kind)
		arrange(rules,[draw_card,card(rules,suit,"8"),card(rules,suit,"2")],[card(rules,suit,"4")],[stack])
		rules.deck.erase(stack)
		rules.hands[1].append(stack)
		check(rules.play(0,draw_card) and rules.play(1,stack) and rules.pending_draw == amount * 2, "Optional numeric stacking accepts only the same kind across colors")

	rules = fixture()
	var wild := card(rules,"wild","draw2")
	arrange(rules,[wild,card(rules,"red","8"),card(rules,"blue","2")],[card(rules,"red","4")])
	check(not rules.playable(0,wild), "Flip Wild Draw Two respects the matching-color restriction without challenges")
	rules.color = "yellow"
	check(not rules.play(0,wild,"purple") and rules.play(0,wild,"green") and rules.phase == "play" and rules.pending_draw == 2, "Wild Draw Two chooses a light color and has no challenge/acceptance phase")
	check(rules.draw(1) and rules.turn == 2 and conserved(rules), "Wild Draw Two resolves as an ordinary two-card penalty")

	rules = fixture(true)
	var skip := card(rules,"pink","skip_all")
	arrange(rules,[skip,card(rules,"pink","8"),card(rules,"purple","2")],[card(rules,"pink","4")])
	check(rules.play(0,skip) and rules.turn == 0 and rules.feedback.events.filter(func(event: Dictionary) -> bool: return event.kind == "skip").size() == 3, "Skip Everyone skips every opponent and gives the player another turn")

	rules = fixture(true)
	rules.allow_stacking = true
	wild = card(rules,"wild","draw_color")
	var chosen := card(rules,"purple","9")
	arrange(rules,[wild,card(rules,"orange","8"),card(rules,"pink","2")],[card(rules,"teal","4")],[chosen,card(rules,"teal","3"),card(rules,"wild","wild"),card(rules,"orange","3")])
	var before: int = rules.hands[1].size()
	check(rules.play(0,wild,"purple") and rules.pending_color == "purple" and rules.requires_auto_draw() and rules.legal_cards(1).is_empty(), "Wild Draw Color resolves immediately even with optional stacking")
	check(rules.draw(1) and rules.hands[1].size() == before + 4 and rules.hands[1].back() == chosen and rules.turn == 2 and rules.pending_color.is_empty() and conserved(rules), "Draw Color includes the chosen-color card, ignores Wilds, and skips the recipient")
	rules = fixture(true)
	wild = card(rules,"wild","draw_color")
	chosen = card(rules,"purple","9")
	arrange(rules,[wild],[card(rules,"teal","4")],[chosen,card(rules,"orange","3")])
	before = rules.hands[1].size()
	check(rules.play(0,wild,"purple") and rules.winner == 0 and rules.hands[1].size() == before + 2, "A final Wild Draw Color is paid before finishing")
	var wins: Array = rules.session_wins.duplicate()
	faces = rules.flip_faces.duplicate(true)
	check(rules.play_again() and (rules.side == "light" or rules.flip_faces[rules.discard.back()].light.kind == "flip") and rules.flip_faces == faces and rules.session_wins == wins and rules.hands.all(func(held: Array) -> bool: return held.size() == 7), "Replay retains pairs and wins and starts with a light-side opening, including an opening Flip")

	rules = fixture(true)
	wild = card(rules,"wild","draw_color")
	arrange(rules,[wild,card(rules,"orange","8"),card(rules,"pink","2")],[card(rules,"teal","4")])
	for id in rules.deck.duplicate():
		if rules.cards[id].color == "purple":
			rules.deck.erase(id)
			rules.hands[2].append(id)
	check(rules.play(0,wild,"purple") and rules.draw(1) and rules.pending_color.is_empty() and rules.turn == 2 and conserved(rules), "Draw Color finishes safely when the chosen color is absent from available stock")
	rules = fixture()
	flip = card(rules,"red","flip")
	arrange(rules,[flip],[card(rules,"red","4")])
	check(rules.play(0,flip) and rules.side == "dark" and rules.winner == 0 and rules.session_wins[0] == 1 and rules.history.size() == 1, "A final Flip ends the hand with exactly one win on the new side")

	# Simulate every AI difficulty, seat count, and optional-rule configuration.
	for count in [4,5,6]:
		for difficulty in [0,1,2]:
			for house_rules in [false,true]:
				rules = Rules.new()
				rules.gamemode = "flip"
				for option in ["allow_stacking","allow_seven_zero","allow_jump_ins","draw_until_play","force_play"]: rules.set(option,house_rules)
				rules.start(count)
				var completed := true
				for step in 4000:
					if rules.winner >= 0: break
					var seat: int = rules.turn
					var action: Dictionary = Rules.computer_action(rules.view_for(seat),difficulty)
					if rules.hands[seat].size() == 2: rules.call_uno(seat)
					var accepted := false
					match action.action:
						"play": accepted = rules.play(seat,action.card,action.color)
						"color": accepted = rules.choose_color(seat,action.color)
						"draw": accepted = rules.draw(seat)
						"pass": accepted = rules.pass_turn(seat)
						"swap": accepted = rules.swap_hands(seat,action.target)
					if not accepted or not conserved(rules):
						completed = false
						break
				check(completed and rules.winner >= 0, "Flip AI game completes with conserved cards: seats=%d difficulty=%d house=%s" % [count,difficulty,house_rules])

	rules = fixture()
	rules.allow_jump_ins = true
	flip = card(rules,"red","flip")
	first = -1
	for id in rules.flip_faces.size():
		var face: Dictionary = rules.flip_faces[id].dark
		if str(face.kind).is_valid_int() and (face.color != rules.flip_faces[flip].dark.color or face.kind != rules.flip_faces[flip].dark.kind):
			first = id
			break
	arrange(rules,[flip,card(rules,"green","8"),card(rules,"blue","2")],[first,card(rules,"red","4")])
	rules.play(0,flip)
	var exposed: Dictionary = rules.cards[rules.discard.back()]
	var mate: int = rules.cards.filter(func(face: Dictionary) -> bool: return face.color == exposed.color and face.kind == exposed.kind and face.id != exposed.id)[0].id
	for held_hand in rules.hands: held_hand.erase(mate)
	rules.deck.erase(mate)
	rules.hands[2].append(mate)
	check(rules.can_jump_in(2,mate) and rules.play(2,mate) and rules.turn == 3, "Optional jump-ins match the newly exposed active-side number after a Flip")

	# The existing staged native settings path owns changing mode.
	var host := Host.instantiate()
	root.add_child(host)
	var context := GameSessionContext.new("uno",[],{"id":"host","display_name":"Host","color":"#e53935"},false)
	context.reduced_motion = true
	host.settings_store = preload("res://tests/game_settings_fixture.gd").new()
	host.initialize_session(context)
	host.start_game()
	host.auto_timer.stop()
	host.ai_timer.stop()
	check(host.rules.gamemode == "classic" and host.rules.cards.size() == 108 and host.gamemode_choice.selected == 0, "Classic remains the default")
	var revision: int = host.rules.revision
	host._set_gamemode(1)
	check(host.rules.gamemode == "classic" and host.rules.revision == revision and not host.apply_options.disabled, "Selecting Flip stages the mode without changing the hand")
	host.rules.session_wins[0] = 2
	host.rules.history.append({"round":1,"winner":0})
	host._apply_options()
	check(host.rules.gamemode == "flip" and host.rules.cards.size() == 112 and host.rules.session_wins[0] == 2 and host.rules.history.size() == 1 and host.apply_options.disabled, "Apply replaces the deck and preserves completed session results")
	host.auto_timer.stop()
	host.ai_timer.stop()
	host.rules.side = "light"
	host.rules._activate_faces()
	host.rules.turn = 0
	var high_id := 111
	host.rules.hands[0] = [high_id]
	host.rules.phase = "play"
	host.rules.color = "red"
	host.rules.pending_draw = 0
	host.rules.pending_color = ""
	host._local_action({"action":"play","card":high_id,"color":"green"})
	check(host.rules.winner == 0, "Host validation accepts Flip card IDs above 107")
	host._set_gamemode(0)
	host._apply_options()
	check(host.rules.gamemode == "classic" and host.rules.cards.size() == 108 and host.rules.session_wins[0] == 3, "Switching back restores the Classic deck and retains wins")
	host.shutdown_game()
	host.queue_free()
	await process_frame
	await create_timer(.2).timeout
	print("UNO Flip: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
