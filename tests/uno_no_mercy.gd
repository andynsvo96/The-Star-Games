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
	return int(rules.cards.filter(func(face: Dictionary) -> bool: return face.color == suit and face.kind == kind)[copy].id)


func fixture() -> RefCounted:
	var rules := Rules.new()
	rules.set_gamemode("no_mercy")
	rules.start(4)
	rules.turn = 0
	rules.phase = "play"
	rules.pending_draw = 0
	rules.drawn = -1
	rules.motion.clear()
	return rules


func arrange(rules: RefCounted, own: Array, pile: Array, stock: Array = []) -> void:
	rules.hands = [own.duplicate(), [], [], []]
	rules.discard = pile.duplicate()
	var available: Array = range(rules.cards.size()).filter(func(id: int) -> bool: return not own.has(id) and not pile.has(id) and not stock.has(id))
	for seat in range(1, 4):
		for index in 3: rules.hands[seat].append(available.pop_front())
	rules.deck = available + stock
	rules.color = str(rules.cards[pile.back()].color)
	rules.armed.fill(false)
	rules.declared.fill(false)


func conserved(rules: RefCounted) -> bool:
	var ids: Array = rules.deck + rules.discard + rules.retired
	for hand in rules.hands: ids.append_array(hand)
	ids.sort()
	return ids == range(rules.cards.size())


func _run() -> void:
	seed(89214)
	var rules := fixture()
	check(rules.cards.size() == 168, "No Mercy uses the 168-card base deck")
	for suit in Rules.COLORS:
		for kind in ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "draw4", "skip_all"]:
			check(rules.cards.filter(func(face: Dictionary) -> bool: return face.color == suit and face.kind == kind).size() == 2, "Two copies per color: " + suit + " " + kind)
		for kind in ["skip", "reverse", "draw2", "discard_all"]:
			check(rules.cards.filter(func(face: Dictionary) -> bool: return face.color == suit and face.kind == kind).size() == 3, "Three copies per color: " + suit + " " + kind)
	for kind in ["reverse_draw4", "color_roulette", "draw6", "draw10"]:
		check(rules.cards.filter(func(face: Dictionary) -> bool: return face.kind == kind).size() == (8 if kind in ["reverse_draw4", "color_roulette"] else 4), "Correct Wild multiplicity: " + kind)
	check(not rules.cards.any(func(face: Dictionary) -> bool: return face.kind == "wild"), "No plain Wilds are added to the base No Mercy deck")
	check(rules.allow_stacking and rules.allow_seven_zero and rules.allow_mercy and rules.draw_until_play and not rules.allow_jump_ins and not rules.force_play, "No Mercy defaults enable its rules and leave Jump-Ins/Force Play off")
	for attempt in 40:
		rules.restart_round()
		check(str(rules.cards[rules.discard.back()].kind).is_valid_int() and rules.pending_draw == 0 and rules.phase == "play" and conserved(rules), "Opening skips every action and preserves cards")

	rules = fixture()
	var draw2 := card(rules,"red","draw2")
	var draw4 := card(rules,"blue","draw4")
	var draw6 := card(rules,"wild","draw6")
	var draw10 := card(rules,"wild","draw10")
	arrange(rules,[draw2,card(rules,"green","9"),card(rules,"green","8")],[card(rules,"red","5")],[draw4,draw6,draw10])
	for pair in [[1,draw4],[2,draw6],[3,draw10]]:
		rules.deck.erase(pair[1])
		rules.hands[pair[0]].append(pair[1])
	check(rules.play(0,draw2) and rules.play(1,draw4) and rules.play(2,draw6,"yellow") and rules.play(3,draw10,"red") and rules.pending_draw == 22, "+2/+4/+6/+10 stack across colors by the last card's value")
	check(not rules.playable(0,card(rules,"green","9")), "A numeric card cannot answer a draw stack")
	var lower := card(rules,"red","draw2",1)
	rules.deck.erase(lower)
	rules.hands[0].append(lower)
	check(not rules.playable(0,lower), "Lower draw cards cannot answer a +10")
	check(rules.draw(0) and rules.eliminated[0] and rules.turn == 1 and rules.pending_draw == 0 and conserved(rules), "A stack eliminates at 25 and resumes with the next surviving seat")
	var out_view: Dictionary = rules.view_for(0)
	check(out_view.hand.is_empty() and out_view.legal_cards.is_empty() and out_view.eliminated[0] and not rules.call_uno(0) and not rules.draw(0), "Eliminated players have no hand or valid actions")

	rules = fixture()
	rules.allow_stacking = false
	arrange(rules,[card(rules,"red","draw2"),card(rules,"blue","8"),card(rules,"green","9")],[card(rules,"red","5")])
	check(rules.play(0,card(rules,"red","draw2")) and rules.requires_auto_draw() and rules.legal_cards(1).is_empty() and rules.draw(1) and rules.turn == 2, "Stacking off pays the penalty and skips without offering a stack")
	rules = fixture()
	var zero := card(rules,"red","0")
	arrange(rules,[zero,card(rules,"blue","8"),card(rules,"green","9")],[card(rules,"red","5")])
	rules._eliminate(1)
	var before_zero: Array = rules.hands.duplicate(true)
	check(rules.play(0,zero) and rules.turn == 2 and rules.hands[1].is_empty() and rules.hands[2] == before_zero[0].slice(1) and rules.hands[0] == before_zero[3] and conserved(rules), "Zero passes only surviving hands and skips eliminated seats")
	rules = fixture()
	rules.allow_seven_zero = false
	var seven := card(rules,"red","7")
	arrange(rules,[seven,card(rules,"blue","8"),card(rules,"green","9")],[card(rules,"red","5")])
	check(rules.play(0,seven) and rules.phase == "play" and rules.turn == 1, "7-0 off makes a seven an ordinary number card")
	rules = fixture()
	rules.allow_jump_ins = true
	var jump := card(rules,"red","5",1)
	arrange(rules,[card(rules,"blue","8"),card(rules,"green","9"),card(rules,"blue","9")],[card(rules,"red","5")])
	for held in rules.hands: held.erase(jump)
	rules.deck.erase(jump)
	rules.hands[2].append(jump)
	rules.jump_open = true
	check(rules.play(2,jump) and rules.turn == 3 and conserved(rules), "Optional No Mercy Jump-Ins accept an exact numbered face and take over the turn")

	rules = fixture()
	var discard_all := card(rules,"red","discard_all")
	var red := card(rules,"red","8")
	var blue := card(rules,"blue","8")
	arrange(rules,[discard_all,red,blue,card(rules,"red","draw2")],[card(rules,"red","5")])
	check(rules.can_call_uno(0) and rules.call_uno(0), "UNO can be declared before Discard All reduces a larger hand to one card")
	check(rules.play(0,discard_all) and rules.hands[0] == [blue] and rules.discard.back() == discard_all and rules.discard.has(red) and conserved(rules), "Discard All removes only matching colors beneath the action card")
	check(rules.motion.flights.filter(func(flight: Dictionary) -> bool: return flight.kind == "play").size() == 3, "All discarded cards receive public play flights")
	rules = fixture()
	discard_all = card(rules,"red","discard_all")
	arrange(rules,[discard_all,card(rules,"red","8")],[card(rules,"red","5")])
	check(rules.play(0,discard_all) and rules.winner == 0 and rules.session_wins[0] == 1, "Discard All can empty the hand for one win")
	for kind in ["7","0"]:
		rules = fixture()
		var final := card(rules,"red",kind)
		arrange(rules,[final],[card(rules,"red","5")])
		check(rules.play(0,final) and rules.winner == 0 and rules.phase == "finished", "A final " + kind + " wins immediately before hand transfers")
	rules = fixture()
	var skip := card(rules,"red","skip_all")
	arrange(rules,[skip,red,blue],[card(rules,"red","5")])
	check(rules.play(0,skip) and rules.turn == 0, "Skip Everyone retains the current turn")

	rules = fixture()
	var roulette := card(rules,"wild","color_roulette")
	var matching := card(rules,"red","6")
	arrange(rules,[roulette,blue,card(rules,"blue","9")],[card(rules,"yellow","5")],[matching,card(rules,"wild","draw6"),card(rules,"green","4")])
	var before: int = rules.hands[1].size()
	check(rules.play(0,roulette) and rules.phase == "roulette_color" and rules.turn == 1 and not rules.requires_auto_draw(), "Color Roulette waits for the recipient's choice")
	check(not rules.choose_color(0,"red") and not rules.choose_color(1,"purple") and not rules.draw(1), "Roulette rejects wrong owners, colors and early draws")
	check(not rules.view_for(-1).top.has("selected_color") and rules.view_for(2).hand.size() == 3, "Roulette choice does not expose another player's cards")
	check(rules.choose_color(1,"red") and rules.requires_auto_draw() and rules.draw(1) and rules.turn == 2 and rules.hands[1].size() == before + 3 and rules.hands[1].back() == matching and conserved(rules), "Roulette ignores Wilds, includes the chosen-color card and skips the recipient")

	rules = fixture()
	rules.force_play = true
	roulette = card(rules,"wild","color_roulette")
	arrange(rules,[card(rules,"blue","8"),card(rules,"green","9"),card(rules,"blue","9")],[card(rules,"red","5")],[roulette])
	check(rules.draw(0) and rules.phase == "play" and rules.requires_forced_play() and rules.play(0,roulette) and rules.phase == "roulette_color" and rules.turn == 1, "Forced drawn Roulette plays directly and asks only its recipient for color")

	rules = fixture()
	rules._eliminate(2)
	rules._eliminate(3)
	var reverse := card(rules,"wild","reverse_draw4")
	for hand in rules.hands: hand.erase(reverse)
	rules.retired.erase(reverse)
	rules.deck.erase(reverse)
	rules.hands[0].append(reverse)
	rules.turn = 0
	check(rules.play(0,reverse,"blue") and rules.direction == -1 and rules.turn == 0 and rules.pending_draw == 4, "At two survivors, Wild Reverse +4 targets its own player")
	var answer := card(rules,"wild","draw6")
	for hand in rules.hands: hand.erase(answer)
	rules.retired.erase(answer)
	rules.deck.erase(answer)
	rules.hands[0].append(answer)
	check(rules.play(0,answer,"red") and rules.turn == 1 and rules.pending_draw == 10 and conserved(rules), "Two-player Reverse +4 can be stacked back onto the opponent")

	rules = fixture()
	arrange(rules,[blue,card(rules,"blue","9"),card(rules,"green","9")],[card(rules,"red","5")],[card(rules,"red","6"),card(rules,"green","4")])
	check(rules.draw(0) and rules.turn == 0 and rules.drawn < 0 and rules.requires_turn_draw(), "Draw Til Play retains the turn after an unplayable draw")
	check(rules.draw(0) and rules.drawn >= 0 and not rules.requires_forced_play() and rules.pass_turn(0), "Force Play off preserves the drawn-card Play/Keep decision")
	rules = fixture()
	rules.allow_mercy = false
	rules._take(0,30)
	check(not rules.eliminated[0] and rules.hands[0].size() == 37 and conserved(rules), "Mercy off permits hands above 25")
	rules = fixture()
	rules._eliminate(1)
	rules._eliminate(2)
	rules._take(3,17)
	rules.turn = 3
	# Ensure an ordinary draw crosses exactly 25.
	rules.color = "blue"
	check(rules.hands[3].size() == 24 and rules.draw(3) and rules.winner == 0 and rules.session_wins[0] == 1 and conserved(rules), "The last surviving player receives one win")
	var results: Array = rules.session_wins.duplicate()
	check(rules.play_again() and rules.eliminated.all(func(out: bool) -> bool: return not out) and rules.retired.is_empty() and rules.session_wins == results, "Replay restores all seats and keeps completed wins")
	rules = fixture()
	rules._eliminate(1)
	var held: Array = rules.retired.duplicate()
	rules.deck.clear()
	rules.discard = [rules.discard.back()]
	var recycled: Array = rules._take(0,1)
	check(not recycled.is_empty() and held.has(recycled[0]) and rules.retired.is_empty(), "Retired hands return only when stock needs recycling")

	for count in [4,5,6]:
		for difficulty in [0,1,2]:
			for custom in ["defaults","extras","off"]:
				rules = Rules.new()
				rules.set_gamemode("no_mercy")
				if custom == "extras":
					rules.allow_jump_ins = true
					rules.force_play = true
				elif custom == "off":
					for option in Rules.default_options("no_mercy"): rules.set(option,false)
				rules.start(count)
				var valid := true
				for step in 4000:
					if rules.winner >= 0: break
					var seat: int = rules.turn
					var input: Dictionary = Rules.computer_action(rules.view_for(seat),difficulty)
					if rules.hands[seat].size() == 2: rules.call_uno(seat)
					var accepted := false
					match input.action:
						"play": accepted = rules.play(seat,input.card,input.color)
						"color": accepted = rules.choose_color(seat,input.color)
						"draw": accepted = rules.draw(seat)
						"pass": accepted = rules.pass_turn(seat)
						"swap": accepted = rules.swap_hands(seat,input.target)
					if not accepted or not conserved(rules) or not rules.is_active(rules.turn):
						valid = false
						break
				check(valid and rules.winner >= 0, "No Mercy AI completes with conserved cards: seats=%d difficulty=%d custom=%s" % [count,difficulty,custom])

	var host := Host.instantiate()
	root.add_child(host)
	var context := GameSessionContext.new("uno",[],{"id":"host","display_name":"Host","color":"#e53935"},false)
	context.reduced_motion = true
	host.settings_store = preload("res://tests/game_settings_fixture.gd").new()
	host.initialize_session(context)
	host.start_game()
	for timer in [host.ai_timer,host.auto_timer,host.jump_timer,host.catch_timer]: timer.process_mode = Node.PROCESS_MODE_DISABLED
	host._set_rule("allow_jump_ins",true)
	host._set_rule("force_play",true)
	var revision: int = host.rules.revision
	host._set_gamemode(2)
	check(host.rules.gamemode == "classic" and host.rules.revision == revision and host.pending_options == Rules.default_options("no_mercy"), "Selecting a mode stages its own defaults without mutating the active game")
	check(host.rule_choices.allow_mercy.visible and host.rule_choices.allow_mercy.button_pressed and not host.rule_choices.force_play.button_pressed, "No Mercy visibly enables Mercy and clears Force Play")
	host.rules.session_wins[0] = 2
	host._apply_options()
	check(host.rules.gamemode == "no_mercy" and host.rules.cards.size() == 168 and host.rules.allow_mercy and host.rules.session_wins[0] == 2 and not host._options_changed(), "Apply deals a new No Mercy hand and preserves completed wins")
	revision = host.rules.revision
	host._set_rule("allow_mercy",false)
	check(host.rules.allow_mercy and host.rules.revision == revision, "Rule edits remain staged during play")
	host._apply_options()
	check(not host.rules.allow_mercy and host.rules.revision > revision and host.rules.hands.all(func(hand: Array) -> bool: return hand.size() == 7), "Applying a rule change abandons and restarts the hand")
	host._set_gamemode(1)
	check(host.pending_options == Rules.default_options("flip") and not host.rule_choices.allow_mercy.visible, "Flip replaces No Mercy rules with its own defaults")
	host._apply_options()
	check(host.rules.gamemode == "flip" and not host.rules.allow_stacking and not host.rules.allow_mercy and host.rules.cards.size() == 112, "Applied Flip does not carry No Mercy rules")
	host._set_gamemode(2)
	host._set_rule("allow_jump_ins",true)
	host._apply_options()
	check(host.rules.allow_jump_ins and host.rules.allow_mercy, "Host can override mode defaults before Apply")
	host._set_gamemode(0)
	host._apply_options()
	check(host.rules.cards.size() == 108 and not host.rules.allow_jump_ins and not host.rules.force_play and not host.rules.allow_mercy, "Classic replaces the previous mode's custom rules")
	host.shutdown_game()
	host.queue_free()
	await process_frame
	host = Host.instantiate()
	root.add_child(host)
	var players: Array = []
	for seat in 4: players.append({"id":"phone-%d" % seat,"profile_id":"profile-%d" % seat,"display_name":"Player %d" % seat,"color":"#e53935"})
	context = GameSessionContext.new("uno",players,{},true)
	context.reduced_motion = true
	host.settings_store = preload("res://tests/game_settings_fixture.gd").new()
	host.initialize_session(context)
	host.start_game()
	for timer in [host.ai_timer,host.auto_timer,host.jump_timer,host.catch_timer]: timer.process_mode = Node.PROCESS_MODE_DISABLED
	var awards: Array = []
	var reports: Array = []
	host.points_awarded.connect(func(id: String, amount: int) -> void: awards.append({"id":id,"amount":amount}))
	host.result_reported.connect(func(id: String, won: bool) -> void: reports.append({"id":id,"won":won}))
	host._set_gamemode(2)
	host._apply_options()
	for seat in [1,2,3]: host.rules._eliminate(seat)
	host.rules._check_survivor()
	host._publish()
	host._publish()
	check(awards == [{"id":"profile-0","amount":1}] and reports.size() == 4 and reports.filter(func(result: Dictionary) -> bool: return result.won).size() == 1, "Last-survivor scoring reports one win, three losses and one point exactly once")
	host._action(0,{"action":"play_again","revision":host.rules.revision})
	check(host.rules.winner < 0 and host.rules.eliminated.all(func(out: bool) -> bool: return not out) and host.rules.session_wins[0] == 1 and awards.size() == 1, "Replay restores eliminated participants without duplicating saved results")
	host._set_rule("allow_mercy",false)
	host._apply_options()
	check(reports.size() == 4 and awards.size() == 1 and host.rules.session_wins[0] == 1, "Applying house rules never scores an abandoned hand")
	host.shutdown_game()
	host.queue_free()
	await process_frame
	await create_timer(.15).timeout
	print("UNO No Mercy: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
