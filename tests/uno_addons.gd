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


func fixture(layout: Array = []) -> RefCounted:
	var rules := Rules.new()
	for pack in Rules.AddOns.PACKS: rules.enabled_addons[pack[0]] = true
	rules.start(4)
	rules.addons.reset()
	rules.hands = [[], [], [], []]
	rules.discard = []
	rules.deck = range(rules.cards.size())
	for seat in 4:
		var cards: Array = layout[seat] if seat < layout.size() else ["blue:%d" % (seat + 4), "green:%d" % (seat + 5), "yellow:%d" % (seat + 1)]
		for token in cards:
			var parts: PackedStringArray = str(token).split(":")
			var speed := str(parts[0]).begins_with("speed-")
			var suit := str(parts[0]).trim_prefix("speed-")
			var id: int = rules.deck.filter(func(index: int) -> bool: return rules.cards[index].color == suit and rules.cards[index].kind == parts[1] and (not speed or rules.cards[index].get("addon", "") == "speed"))[0]
			rules.hands[seat].append(id)
			rules.deck.erase(id)
	var top: int = rules.deck.filter(func(id: int) -> bool: return rules.cards[id].color == "red" and rules.cards[id].kind == "5")[0]
	rules.deck.erase(top)
	rules.discard = [top]
	rules.turn = 0
	rules.direction = 1
	rules.color = "red"
	rules.phase = "play"
	rules.pending_draw = 0
	rules.drawn = -1
	rules.winner = -1
	rules.armed.fill(false)
	rules.declared.fill(false)
	return rules


func play_first(rules, suit := "red") -> bool:
	if rules.can_call_uno(rules.turn): rules.call_uno(rules.turn)
	return rules.play(rules.turn, rules.hands[rules.turn][0], suit)


func pay(rules) -> void:
	for step in 12:
		if rules.phase != "addon_response": return
		check(rules.draw(rules.turn), "Penalty can be accepted")


func _run() -> void:
	seed(44297)
	for pack in Rules.AddOns.PACKS:
		var rules := Rules.new()
		rules.enabled_addons[pack[0]] = true
		rules.start(4)
		var added: Array = rules.cards.filter(func(card: Dictionary) -> bool: return card.has("addon"))
		check(added.size() == (13 if pack[0] == "love_island" else 16), str(pack[1]) + " has the approved playable count")
		for kind in Rules.AddOns.WILDS[pack[0]]:
			check(added.filter(func(card: Dictionary) -> bool: return card.kind == kind).size() == ((1 if kind == "eggs" else 2) if pack[0] == "love_island" else 4), "Wild copy count: " + kind)
		var faces := {}
		for card in added:
			var stem := Rules.card_art_prefix(card) + str(card.color) + "-" + str(card.kind)
			faces[stem] = true
			if card.color == "wild":
				for suit in Rules.COLORS: faces["addon-" + suit + "-" + str(card.kind) + "-chosen"] = true
		for stem in faces: check(load("res://Games/uno/art/cards/" + stem + ".svg") is Texture2D, "Offline add-on artwork imports: " + stem)
		if pack[0] == "speed":
			for index in 4:
				for number in range(1 + index * 2, 4 + index * 2): check(added.any(func(card: Dictionary) -> bool: return card.color == ["yellow","red","blue","green"][index] and card.kind == str(number)), "Speed color/number distribution")
		for mode in ["flip", "no_mercy"]:
			rules.set_gamemode(mode)
			rules.restart_round()
			check(rules.cards.size() == (112 if mode == "flip" else 168) and not rules.cards.any(func(card: Dictionary) -> bool: return card.has("addon")), "Packs cannot change " + mode)
	var r = fixture([["red:reverse_draw2","blue:8","green:9"]])
	check(play_first(r) and r.direction == -1 and r.turn == 3 and r.pending_draw == 2, "Reverse Draw 2 attacks the new direction")
	pay(r)
	check(r.turn == 2, "Reverse Draw 2 skips the recipient")
	r = fixture([["wild:power_reverse","red:1","blue:8"]])
	check(play_first(r) and r.direction == -1 and r.turn == 0, "Power Reverse gives another turn")
	r = fixture([["red:draw2","red:1","blue:8"],["wild:no_u","red:3","blue:4"]])
	check(play_first(r) and not r.requires_auto_draw() and r.legal_cards(1).has(r.hands[1][0]), "No U offers a response even without normal stacking")
	check(r.view_for(1).addon_draw and not r.view_for(1).has("addon_accept"), "A draw response uses the regular Draw action without a second penalty button")
	check(not r.view_for(0).addon_draw and not r.view_for(-1).addon_draw, "Only the penalty recipient receives the enabled draw action")
	check(play_first(r) and r.turn == 0 and r.pending_draw == 2 and r.direction == -1, "No U sends the penalty back")
	pay(r)
	r = fixture([["red:draw2","red:1","blue:8"],["red:stack1","red:3","blue:4"],["wild:stack3","yellow:stack2","green:8"]])
	play_first(r)
	check(play_first(r) and r.pending_draw == 3 and r.turn == 2, "Stack 1 adds one to a matching-color draw")
	check(play_first(r) and r.pending_draw == 6 and r.turn == 3, "Wild Stack 3 adds three independently of Allow Stacking")
	pay(r)
	for defense in ["block", "rebound", "deflect", "redirect"]:
		r = fixture([["red:draw2","red:1","blue:8"],["wild:" + defense,"red:3","blue:4"]])
		play_first(r)
		check(play_first(r), "Defense response: " + defense)
		if defense == "block": check(r.pending_draw == 0 and r.turn == 2, "Block cancels the draw")
		if defense == "rebound": check(r.turn == 0 and r.pending_draw == 3, "Rebound returns the draw plus one")
		if defense == "deflect": check(r.turn == 2 and r.pending_draw == 2, "Deflect sends to the next player")
		if defense == "redirect": check(r.addons.choose(r, 1, {"target":3}) and r.turn == 3, "Redirect uses a validated target choice")
		pay(r)
	r = fixture([["red:skip","red:1","blue:8"],["wild:block","red:3","blue:4"]])
	check(play_first(r) and r.phase == "addon_response" and r.pending_draw == 0, "Skip also offers a defensive response")
	check(not r.view_for(1).addon_draw and r.view_for(1).addon_accept == "ACCEPT SKIP", "Skip-only responses remain an explicit non-draw choice")
	check(play_first(r) and r.turn == 2, "Block stops Skip")
	r = fixture([["red:swap1","blue:1","green:2"],["yellow:3","green:4","blue:5"]])
	var own: Array = r.hands[0].duplicate()
	check(play_first(r) and r.phase == "addon_choice", "Swap 1 asks for a target")
	var rev: int = r.revision
	check(not r.addons.choose(r, 1, {"target":2}) and r.revision == rev, "Other players cannot answer someone else's choice")
	check(r.addons.choose(r, 0, {"target":1}) and r.addons.choice.kind == "give", "Swap 1 asks which own card to give")
	check(r.addons.choose(r, 0, {"card":own[1]}) and r.hands[1].has(own[1]) and r.hands[0].size() == 2, "Swap 1 exchanges one random opponent card for the chosen own card")
	r = fixture([["wild:force_trade","blue:1","green:2"]])
	play_first(r)
	check(r.addons.choose(r, 0, {"target":1}) and r.addons.choose(r, 0, {"target":2}), "Force Trade allows two other players")
	r = fixture([["wild:double_speed","red:1","green:2"],["red:skip","red:reverse","red:3","blue:9"],["blue:4","blue:5","green:8"]])
	check(play_first(r) and r.addons.speed == 3 and r.addons.remaining == 3, "Double Speed adds two levels for the next turn")
	check(play_first(r) and r.turn == 1 and r.addons.remaining == 2, "An early Skip does not skip during Speed")
	check(play_first(r) and r.turn == 1 and r.direction == 1 and r.addons.remaining == 1, "An early Reverse does not reverse during Speed")
	check(play_first(r) and r.turn == 2, "Speed completes after the required cards")
	check(r.draw(2) and r.addons.speed == 1, "Crashing draws current speed and resets it")
	r = fixture([["red:reveal_hands","blue:1","green:2"]])
	play_first(r)
	check(r.view_for(-1).revealed_hands.size() == 4, "Reveal Hands deliberately exposes every hand")
	r.addons.start_turn(r, 0)
	check(r.view_for(-1).revealed_hands.is_empty(), "Reveal Hands expires at the revealer's next turn")
	r = fixture([["wild:chat","blue:1","green:2"]])
	play_first(r)
	r.addons.choose(r, 0, {"target":1})
	check(r.view_for(0).addon_choice.cards.size() == 3 and r.view_for(1).addon_choice.is_empty() and r.view_for(-1).addon_choice.is_empty(), "Chat reveals the chosen hand only to the chooser")
	check(r.addons.choose(r, 0, {"value":"skip"}) and r.phase == "play", "Chat's exchange is optional")
	r = fixture([["wild:nemesis","red:draw2","red:1"]])
	play_first(r)
	r.addons.choose(r, 0, {"target":1})
	r.addons.start_turn(r, 0)
	var count: int = r.hands[1].size()
	play_first(r)
	pay(r)
	check(r.hands[1].size() == count + 4, "Nemesis adds two only to its owner's attack on the enemy")
	check(r.addons.end_enemy(r, 0), "The owner can end Nemesis")
	r = fixture([["wild:double_down","red:skip","blue:1","green:2"]])
	play_first(r)
	check(r.addons.choose(r, 0, {"card":r.hands[0][0]}) and r.phase == "addon_response", "Double Down resolves the extra card's action")
	pay(r)
	check(r.turn == 2, "Double Down's extra Skip skips the next seat")
	r = fixture([["wild:swap_hands","wild:double_down","wild:match_max","blue:1","green:2"]])
	check(r.addons.can_combo(r, 0) and r.call_uno(0) and r.addons.combo(r, 0), "U-N-O letters enable an instant-UNO choice")
	var keep: int = r.hands[0][-1]
	check(r.addons.choose(r, 0, {"card":keep}) and r.addons.choose(r, 0, {"value":"blue"}) and r.hands[0] == [keep] and r.color == "blue" and r.phase == "play", "U-N-O keeps one chosen card without activating letter actions")
	r = fixture([["wild:coupled","red:1","green:2"],["blue:3","blue:4","blue:5"]])
	play_first(r)
	check(r.addons.choose(r, 0, {"target":1}) and r.phase == "addon_assist" and r.turn == 0, "Coupled Up offers the helper a playable card")
	var partner: Array = r.hands[1].duplicate()
	check(play_first(r) and r.hands[1] == partner and r.turn == 2, "The helper plays for the partner without a partner draw")
	r = fixture([["red:text","blue:1","green:2"]])
	play_first(r)
	check(r.addons.choose(r, 0, {"value":"draw"}) and r.phase == "addon_response", "Text offers its three rules")
	pay(r)
	check(r.hands[1].size() == 4 and r.hands[2].size() == 4 and r.hands[3].size() == 4, "Text makes every other player draw one")
	_more_rules()
	await _host_settings()
	_simulations()
	print("UNO add-ons: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _more_rules() -> void:
	var r = fixture([["red:refresh_hand","blue:1","green:2"]])
	var old: Array = r.hands[0].duplicate()
	play_first(r)
	check(r.hands[0].size() == 2 and not r.hands[0].any(func(id: int) -> bool: return old.has(id)), "Refresh replaces exactly the remaining hand")
	r = fixture([["wild:pass_hands","blue:1","green:2"]])
	old = r.hands[2].duplicate()
	play_first(r)
	check(r.hands[3] == old and r.hands[1].size() == 2, "Pass Hands rotates the entire table")
	r = fixture([["wild:pass_color","red:1","green:2"],["red:3","blue:4","blue:5"]])
	r.direction = -1
	var red: int = r.hands[0][1]
	play_first(r)
	check(r.hands[1].has(red) and not r.hands[0].has(red), "Pass Color passes physical left even when play is reversed")
	r = fixture([["wild:trick","blue:1","green:2"],["blue:3","blue:4","blue:5"]])
	check(play_first(r) and r.turn == 0, "Trick gives the sender another turn when the next player lacks the chosen color")
	r = fixture([["wild:color_challenge","blue:1","green:2"],["red:3","blue:4","blue:5"]])
	play_first(r)
	check(r.view_for(0).revealed_cards.has(1) and r.view_for(1).revealed_cards.is_empty() and r.view_for(-1).revealed_cards.is_empty(), "Color Challenge shows matching proof only to its sender")
	pay(r)
	r = fixture([["wild:instigator","blue:1","green:2"]])
	play_first(r)
	check(r.addons.choose(r,0,{"target":1,"amount":2}) and r.addons.choose(r,0,{"target":2,"amount":4}) and r.addons.choose(r,0,{"value":"done"}), "Instigator stages independent amounts per target")
	pay(r)
	check(r.hands[1].size() == 5 and r.hands[2].size() == 7 and r.hands[3].size() == 3, "Instigator draws only the selected amounts")
	r = fixture([["red:draw2","red:1","blue:8"],["wild:petty","red:3","blue:4"]])
	play_first(r)
	check(play_first(r), "Petty Play can retaliate while receiving a draw")
	pay(r)
	check(r.hands[0].size() == 5 and r.hands[1].size() == 4, "Petty retaliates with three without silently cancelling the original penalty")
	r = fixture([["wild:misery","blue:1","green:2"],["red:3","blue:4","blue:5","green:3","yellow:9"]])
	play_first(r)
	pay(r)
	check(r.hands.slice(1).all(func(hand: Array) -> bool: return hand.size() == 5), "Misery makes every other hand match the largest")
	r = fixture([["wild:eggs","blue:1","green:2"],["red:3","red:4","blue:5"]])
	play_first(r)
	check(r.addons.choose(r,0,{"target":1}), "Eggs chooses the linked player")
	r.addons.start_turn(r,1)
	play_first(r)
	r.addons.start_turn(r,1)
	play_first(r)
	check(r.hands[1].size() == 1 and r.hands[0].size() == 1, "Reaching UNO also discards the basket owner's hand down to one")
	r = fixture([["wild:eggs","blue:1","green:2"],["red:3","red:4","blue:5"],["red:draw2","blue:3","green:4"]])
	play_first(r)
	r.addons.choose(r,0,{"target":1})
	r.direction = -1
	r.addons.start_turn(r,2)
	play_first(r)
	pay(r)
	check(r.hands[0].size() == 4 and r.hands[1].size() == 5, "Eggs mirrors linked Draw Two penalties")
	r = fixture([["wild:coupled","red:1","green:2"],["blue:3","blue:4","blue:5"]])
	play_first(r)
	r.addons.choose(r,0,{"target":1})
	check(r.addons.decline(r,0) and r.phase == "play" and r.turn == 1 and r.requires_turn_draw(), "Coupled help can be declined without a deadlock")
	r.restart_round()
	check(r.addons.couple == [-1,-1] and r.addons.basket == [-1,-1] and r.addons.enemies.is_empty() and r.addons.speed == 1, "A fresh hand clears all ongoing add-on relationships")
	r = fixture([["red:1","blue:2","green:3"],["red:5","blue:4"]])
	r.allow_jump_ins = true
	r.jump_open = true
	check(r.can_call_uno(1) and r.call_uno(1) and r.play(1,r.hands[1][0]) and r.hands[1].size() == 1 and r.declared[1] and r.turn == 2, "Jump-in keeps its UNO declaration and transfers the turn with packs enabled")
	r = fixture([["red:1","blue:2","green:3"]])
	r.force_play = true
	var forced: int = r.deck.filter(func(id: int) -> bool: return r.cards[id].kind == "nemesis")[0]
	r.deck.erase(forced)
	r.deck.append(forced)
	check(r.draw(0) and r.phase == "drawn_color" and not r.pass_turn(0), "Force Play still requires a drawn add-on Wild's color")
	check(r.choose_color(0,"blue") and r.phase == "addon_choice" and r.addons.choice.kind == "nemesis", "The forced Wild runs its normal add-on choice")
	r.addons.choose(r,0,{"target":1})
	r = fixture([["wild:block"],["red:3","blue:4"],["wild:eliminator"],["green:5","yellow:6"]])
	r.turn = 2
	check(play_first(r) and r.hands[0].is_empty() and r.winner == 2, "Playing the last Eliminator wins before a simultaneously emptied opponent")


func _host_settings() -> void:
	var host := Host.instantiate()
	root.add_child(host)
	host.settings_store = preload("res://tests/game_settings_fixture.gd").new()
	host.initialize_session(GameSessionContext.new("uno", [], {"id":"host","display_name":"Host","color":"#e53935"}, false))
	host.start_game()
	check(host.addon_choices.size() == 9 and host.pending_addons.values().all(func(on: bool) -> bool: return not on), "Nine independent add-ons default off")
	var revision: int = host.rules.revision
	host._set_addon("reverse", true)
	check(not host.apply_options.disabled and host.rules.cards.size() == 108 and host.rules.revision == revision, "Add-on edits are staged until Apply")
	host._apply_options()
	check(host.rules.cards.size() == 124 and host.apply_options.disabled, "Apply rebuilds a new hand with the selected pack")
	host.rules._finish(0)
	check(host.rules.play_again() and host.rules.cards.size() == 124 and host.rules.session_wins[0] == 1, "Replay keeps add-ons and session wins")
	host._set_gamemode(1)
	check(not host.addons_button.visible, "Add-Ons is hidden for Flip")
	host._apply_options()
	check(host.rules.cards.size() == 112 and not host.rules.addons.active(host.rules), "Applying Flip excludes every add-on")
	host.rules = fixture([[],["red:1","blue:2"],["green:3","yellow:4"],["blue:5","green:6"]])
	# Keep every opponent nonempty while the AI makes Double Down's private choice.
	host.rules.hands[0] = [host.rules.deck.pop_back(),host.rules.deck.pop_back()]
	host.rules.addons.context = {"actor":1,"origin":1,"after":2,"uno_pending":true}
	host.rules.addons._ask(host.rules,"double","Choose an extra card to discard.")
	host.difficulty = Rules.Difficulty.HARD
	host.animating = false
	host._computer_turn()
	check(host.rules.hands[1].size() == 1 and host.rules.declared[1], "Host AI declares UNO before Double Down's extra-card choice")
	host.shutdown_game()
	host.queue_free()
	await process_frame


func _simulations() -> void:
	for difficulty in 3:
		for configuration in range(10):
			var rules := Rules.new()
			for index in Rules.AddOns.PACKS.size(): rules.enabled_addons[Rules.AddOns.PACKS[index][0]] = configuration == 9 or configuration == index
			rules.start(4)
			for step in 3000:
				if rules.phase == "finished": break
				var seat: int = rules.turn
				if rules.can_call_uno(seat): rules.call_uno(seat)
				var input: Dictionary = Rules.computer_action(rules.view_for(seat), difficulty)
				var accepted := false
				match input.action:
					"play": accepted = rules.play(seat, input.card, input.get("color", ""))
					"draw": accepted = rules.draw(seat)
					"pass": accepted = rules.pass_turn(seat)
					"color": accepted = rules.choose_color(seat, input.color)
					"addon_choose": accepted = rules.addons.choose(rules, seat, input)
				check(accepted, "AI advances pack %d difficulty %d phase %s" % [configuration, difficulty, rules.phase])
				if not accepted: break
				var held: Array = rules.deck + rules.discard
				for hand in rules.hands: held += hand
				check(held.size() == rules.cards.size() and held.size() == _unique(held), "Every physical card exists in exactly one place")
			check(rules.winner >= 0 and rules.session_wins.reduce(func(total: int, wins: int) -> int: return total + wins, 0) == 1, "Every AI hand finishes with exactly one win")


func _unique(ids: Array) -> int:
	var unique := {}
	for id in ids: unique[id] = true
	return unique.size()
