extends SceneTree

const Rules = preload("res://Games/monopoly-deal/host/rules.gd")
const AI = preload("res://Games/monopoly-deal/host/ai.gd")
var checks := 0
var failures := 0


func _init() -> void:
	call_deferred("_run")


func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + description)


func fresh(count := 2):
	var game = Rules.new(); game.start(count)
	for seat in count: game.hands[seat].clear(); game.banks[seat].clear(); game.properties[seat].clear(); game.loose[seat].clear()
	game.deck.clear(); game.discard.clear(); game.history.clear(); return game


func id(game, key: String, index := 0) -> int:
	return int(game.cards.filter(func(card: Dictionary) -> bool: return card.key == key)[index].id)


func act(game, seat: int, command: Dictionary) -> bool:
	if game.parallel_pending() and command.action in ["pay", "accept", "no"]:
		var decision: Dictionary = game.decision_for(seat)
		if not decision.is_empty(): command.target = decision.target; command.effect = decision.effect
	command.revision = game.revision; return game.apply(seat, command)


func put(game, seat: int, key: String, color: String, gid := -1, index := 0) -> void:
	game._put_property(seat, id(game, key, index), color, gid)


func conserved(game) -> bool:
	var found: Array = game.deck.duplicate(); found.append_array(game.discard)
	for seat in game.hands.size():
		found.append_array(game.hands[seat]); found.append_array(game.banks[seat]); found.append_array(game.loose[seat])
		for group in game.properties[seat]: found.append_array(group.cards); found.append_array(group.buildings)
	return found.size() == 106 and found.duplicate().reduce(func(unique: Array, value: int) -> Array:
		if not unique.has(value): unique.append(value)
		return unique, []).size() == 106


func _run() -> void:
	var game = Rules.new(); game.start(5)
	check(game.cards.size() == 106 and game.cards.filter(func(card: Dictionary) -> bool: return card.kind == "property").size() == 28, "Classic inventory has 106 playable cards and 28 properties")
	check(game.cards.filter(func(card: Dictionary) -> bool: return card.kind == "wild").size() == 11 and game.cards.filter(func(card: Dictionary) -> bool: return card.kind == "rent").size() == 13, "Inventory includes 11 property wilds and 13 rents")
	check(game.hands[0].size() == 7 and game.hands[4].size() == 5 and conserved(game), "Five starting cards, two turn draws, unique conserved deck")
	var public: Dictionary = game.view_for(-1)
	check(public.hand.is_empty() and public.actions.is_empty() and not public.has("deck"), "Public view omits private hands, legal choices and deck order")
	check(game.view_for(0).hand.size() == 7 and game.view_for(1).hand.size() == 5, "Targeted views carry only the owner's hand")
	game = fresh(); game.hands[0] = [id(game,"money-1"),id(game,"money-2"),id(game,"money-3"),id(game,"money-4")]
	for key in ["money-1","money-2","money-3"]: check(act(game,0,{"action":"bank","card":id(game,key)}), "Legal bank play " + key)
	check(not act(game,0,{"action":"bank","card":id(game,"money-4")}), "Fourth normal play rejected")
	check(not game.apply(0,{"action":"end","revision":game.revision-1}) and not game.apply(0,{"action":"end","revision":"bad"}), "Stale and malformed revisions rejected")
	check(game.turn == 0 and game.plays == 3 and game.phase == "play", "Third play leaves End Turn available without permitting a fourth play")
	check(act(game,0,{"action":"end"}) and game.turn == 1, "The owner explicitly ends after three plays")
	check(not act(game,0,{"action":"end"}), "Previous seat cannot end the new turn")
	check(act(game,1,{"action":"end"}) and game.turn == 0, "Manual End turn still stops early")
	game = fresh(); game.hands[0] = [id(game,"money-1"),id(game,"money-2"),id(game,"money-3")] + range(9)
	for key in ["money-1","money-2","money-3"]: act(game,0,{"action":"bank","card":id(game,key)})
	check(game.turn == 0 and game.phase == "play" and game.hands[0].size() == 9, "Third play does not automatically begin discarding")
	check(act(game,0,{"action":"end"}) and game.phase == "discard", "Manual End Turn begins required discarding")
	for value in [0,1]: act(game,0,{"action":"discard","card":value})
	check(game.turn == 1 and game.hands[0].size() == 7, "Explicit turn end advances after required discards")
	game = fresh(); game.hands[0] = [id(game,"pass-go")]; game.plays = 2
	check(act(game,0,{"action":"go","card":id(game,"pass-go")}) and game.turn == 0 and game.plays == 3, "Pass Go on the third play still waits for End Turn")
	game = fresh(); put(game,0,"mediterranean-avenue","brown"); game.hands[0] = [id(game,"baltic-avenue"),id(game,"wild-light-blue-brown"),id(game,"pass-go")]
	var quick: Array = game.tap_choices(0,id(game,"baltic-avenue"))
	check(quick.size() == 1 and quick[0].payload.group == 0, "Property tap immediately joins the fullest matching group")
	check(game.tap_choices(0,id(game,"wild-light-blue-brown")).size() == 2, "Wild tap asks only for a color")
	check(game.tap_choices(0,id(game,"pass-go")).size() == 1 and game.tap_choices(0,id(game,"pass-go"),true)[0].payload.action == "bank", "Action tap plays directly while Bank mode banks directly")
	game = fresh(); game.hands[0] = [id(game,"money-1")]
	check(game.tap_choices(0,id(game,"money-1")).size() == 1 and game.tap_choices(0,id(game,"money-1"))[0].payload.action == "bank", "Money taps always bank directly outside Bank mode")
	game = fresh(); game.hands[0] = range(10)
	check(act(game,0,{"action":"end"}) and game.phase == "discard", "Oversized hand requires explicit discard")
	for value in [0,1,2]: check(act(game,0,{"action":"discard","card":value}), "Owner chooses discard")
	check(game.turn == 1 and game.hands[0].size() == 7, "Discard resumes next turn at seven")
	game = fresh(); put(game,0,"mediterranean-avenue","brown"); put(game,0,"baltic-avenue","brown",0)
	put(game,0,"park-place","dark-blue"); put(game,0,"boardwalk","dark-blue",1)
	put(game,0,"electric-company","utility"); game.hands[0] = [id(game,"water-works")]; game.plays = 2
	check(act(game,0,{"action":"property","card":id(game,"water-works"),"color":"utility","group":2}) and game.winner == 0 and game.turn == 0, "A third-play winning property wins before automatic turn advancement")
	game = fresh(); put(game,0,"mediterranean-avenue","brown"); put(game,0,"baltic-avenue","brown",0)
	game.hands[0] = [id(game,"rent-light-blue-brown"),id(game,"double-rent"),id(game,"double-rent",1),id(game,"just-say-no",1)]
	game.hands[1] = [id(game,"just-say-no")]
	game.banks[1] = [id(game,"money-10")]
	check(act(game,0,{"action":"rent","card":id(game,"rent-light-blue-brown"),"group":0,"double":[id(game,"double-rent")]}) and game.pending.amount == 4 and game.plays == 2, "Rent and a double consume two plays and double rent")
	check(act(game,1,{"action":"no","card":id(game,"just-say-no")}) and game.pending.canceled, "Defender can cancel rent")
	check(act(game,0,{"action":"no","card":id(game,"just-say-no",1)}) and not game.pending.canceled and game.plays == 3, "Attacker can counter Just Say No using the third play")
	check(act(game,1,{"action":"accept"}) and game.phase == "pay", "Accepted response opens payment")
	game.banks[1] = [id(game,"money-10")]
	check(not act(game,1,{"action":"pay","cards":[]}) and not act(game,1,{"action":"pay","cards":[id(game,"money-10"),id(game,"money-10")]}), "Cannot underpay or repeat payment cards")
	check(act(game,1,{"action":"pay","cards":[id(game,"money-10")]}) and game.banks[0].has(id(game,"money-10")) and game.phase == "play" and game.turn == 0, "Payment finishes without change and preserves manual End Turn after three plays")
	game = fresh(); game.hands[0] = [id(game,"sly-deal")]; put(game,1,"mediterranean-avenue","brown"); put(game,1,"baltic-avenue","brown",0)
	check(not game.legal_actions(0).any(func(choice: Dictionary) -> bool: return choice.payload.action == "sly-deal"), "Sly Deal cannot take from a complete set")
	game.hands[0] = [id(game,"deal-breaker")]
	check(act(game,0,{"action":"deal-breaker","card":id(game,"deal-breaker"),"target":1,"group":0}) and act(game,1,{"action":"accept"}) and game.properties[0].size() == 1, "Deal Breaker transfers a complete set")
	game = fresh(); put(game,0,"mediterranean-avenue","brown"); put(game,0,"baltic-avenue","brown",0); game.hands[0]=[id(game,"house"),id(game,"hotel")]
	check(not act(game,0,{"action":"building","card":id(game,"hotel"),"group":0}), "Hotel requires a House")
	check(act(game,0,{"action":"building","card":id(game,"house"),"group":0}) and act(game,0,{"action":"building","card":id(game,"hotel"),"group":0}) and game.rent(game.properties[0][0]) == 9, "House and Hotel add 3M and 4M rent")
	game = fresh(); put(game,0,"wild-any","brown"); put(game,0,"wild-any","brown",0,1)
	check(game.completed(0) == 0 and game.rent(game.properties[0][0]) == 0 and game.payment_assets(0).is_empty(), "Zero-value multicolor wilds alone do not complete sets, charge rent or pay")
	game = fresh(); game.hands[0] = [id(game,"boardwalk"),id(game,"wild-light-blue-brown")]
	check(not act(game,0,{"action":"bank","card":id(game,"boardwalk")}) and not act(game,0,{"action":"bank","card":id(game,"wild-light-blue-brown")}), "G0351 never banks ordinary or wild properties")
	game = fresh(); put(game,0,"mediterranean-avenue","brown"); put(game,0,"baltic-avenue","brown",0)
	game.hands[0] = [id(game,"rent-any"),id(game,"double-rent"),id(game,"double-rent",1),id(game,"just-say-no",1)]; game.hands[1] = [id(game,"just-say-no")]
	game.banks[1] = [id(game,"money-10")]
	check(act(game,0,{"action":"rent","card":id(game,"rent-any"),"group":0,"target":1,"double":[id(game,"double-rent"),id(game,"double-rent",1)]}) and game.pending.amount == 8 and game.plays == 3, "G0351 doubles Any Rent and counts all three cards")
	check(act(game,1,{"action":"no","card":id(game,"just-say-no")}) and not act(game,0,{"action":"no","card":id(game,"just-say-no",1)}), "No fourth own-turn play is allowed to counter a cancellation")
	check(act(game,0,{"action":"accept"}) and game.turn == 0 and game.pending.is_empty(), "Canceled third-play attack returns to manual End Turn")
	game = fresh(); put(game,0,"mediterranean-avenue","brown"); put(game,0,"baltic-avenue","brown")
	check(act(game,0,{"action":"move","card":id(game,"baltic-avenue"),"color":"brown","group":0}) and game.completed(0) == 1 and game.plays == 0, "Own played properties can merge into a set without spending a play")
	game.properties[0][0].buildings = [id(game,"house"),id(game,"hotel")]
	check(act(game,0,{"action":"move","card":id(game,"baltic-avenue"),"color":"brown","group":-1}) and game.discard.has(id(game,"house")) and game.discard.has(id(game,"hotel")), "Breaking a developed set discards its buildings")
	game = fresh(); put(game,1,"mediterranean-avenue","brown"); put(game,1,"baltic-avenue","brown",0); game.properties[1][0].buildings = [id(game,"house"),id(game,"hotel")]
	game.hands[0] = [id(game,"debt-collector")]
	check(act(game,0,{"action":"debt","card":id(game,"debt-collector"),"target":1}) and act(game,1,{"action":"accept"}), "Debt opens an explicit building payment")
	check(act(game,1,{"action":"pay","cards":[id(game,"house"),id(game,"hotel")]}) and game.banks[0].has(id(game,"house")) and game.banks[0].has(id(game,"hotel")) and not game.discard.has(id(game,"hotel")), "Paid buildings become recipient bank cards, transferred before set cleanup")
	game = fresh(); game.hands[0] = [id(game,"money-1")]
	var wire: Dictionary = JSON.parse_string(JSON.stringify({"action":"bank","card":id(game,"money-1"),"revision":game.revision}))
	check(game.apply(0,wire), "Real JSON numeric decoding cannot reject a legal integer command")
	for level in 3:
		for count in [2,3,4,5]:
			seed(7400 + level * 10 + count)
			game = Rules.new(); game.start(count)
			var accepted := true; var safe := true; var turns := 0
			while game.winner < 0 and turns < 1800:
				var seat: int = int(game.pending.ask) if game.phase == "response" else int(game.pending.target) if game.phase == "pay" else game.turn
				var command: Dictionary = AI.choose(game.view_for(seat),level)
				if not act(game,seat,command): accepted = false; break
				if not conserved(game): safe = false; break
				turns += 1
			check(accepted and safe and game.winner >= 0, "%d-seat AI level %d completes with valid moves and card conservation (%d actions)" % [count,level,turns])
	print("Monopoly Deal: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
