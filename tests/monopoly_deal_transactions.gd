extends SceneTree

var checks := 0
var failures := 0
var host: Node

func _init() -> void: call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + message)

func fixture() -> void:
	host.rules.start(3)
	for seat in 3:
		host.rules.hands[seat].clear(); host.rules.banks[seat].clear(); host.rules.properties[seat].clear(); host.rules.loose[seat].clear()
	host.rules.deck = range(host.rules.cards.size()); host.rules.discard.clear()
	host.animating = false; host.motion_timer.stop(); host._publish(); host.ai_timer.stop()

func take(key: String, seat: int, bank := false) -> int:
	var id: int = host.rules.deck.filter(func(candidate: int) -> bool: return host.rules.cards[candidate].key == key)[0]
	host.rules.deck.erase(id)
	if bank: host.rules.banks[seat].append(id)
	else: host.rules.hands[seat].append(id)
	return id

func act(seat: int, command: Dictionary) -> bool:
	if host.rules.parallel_pending() and command.action in ["pay", "accept", "no"]:
		var decision: Dictionary = host.rules.decision_for(seat)
		if not decision.is_empty(): command.target = decision.target; command.effect = decision.effect
	command.revision = host.rules.revision
	return host._action(seat, command)

func _run() -> void:
	host = load("res://Games/monopoly-deal/host/main.tscn").instantiate(); root.add_child(host)
	host.settings_store = preload("res://tests/game_settings_fixture.gd").new()
	var context := GameSessionContext.new("monopoly-deal", [{"id":"a", "display_name":"Alex", "color":"#2463eb"}, {"id":"b", "display_name":"Sam", "color":"#08a750"}, {"id":"c", "display_name":"Nina", "color":"#e53935"}], {}, true)
	context.reduced_motion = true; host.initialize_session(context); host.start_game()
	fixture()
	var debt := take("debt-collector", 0); var money := take("money-10", 1, true)
	check(act(0, {"action":"debt", "card":debt, "target":1}) and host.rules.phase == "pay", "Debt goes directly to asset choices when the target cannot refuse")
	var view: Dictionary = host._snapshot(1)
	check(view.pending.card.id == debt and view.pending.actor == 0 and view.pending.target == 1 and view.payment.amount == 5, "Payment identifies the exact played card, sender, selected player and amount")
	check(view.actions.is_empty() and not act(1, {"action":"accept"}), "No redundant Accept command remains while choosing payment")
	check(act(1, {"action":"pay", "cards":[money]}) and host.rules.banks[0].has(money), "Payment still requires deliberate host-validated asset selection")
	check(host.rules.action_notices[-1].outcome == "paid" and host.rules.action_notices[-1].paid == 10, "Completed payment context records the actual amount without change")

	fixture(); debt = take("debt-collector", 0); money = take("money-10", 1, true)
	var no := take("just-say-no", 1)
	check(act(0, {"action":"debt", "card":debt, "target":1}) and host.rules.phase == "response" and host.rules.legal_actions(1).size() == 2, "A player holding Just Say No retains a genuine response choice")
	check(act(1, {"action":"no", "card":no}) and host.rules.phase == "play" and host.rules.banks[1].has(money), "An uncounterable Just Say No automatically cancels without another acknowledgement")
	check(host.rules.action_notices[-1].canceled and host.rules.action_notices[-1].responder == 1, "Cancellation context identifies who actually played Just Say No")

	fixture(); debt = take("debt-collector", 0); money = take("money-10", 1, true)
	no = take("just-say-no", 1); var counter := take("just-say-no", 0)
	act(0, {"action":"debt", "card":debt, "target":1}); act(1, {"action":"no", "card":no})
	check(host.rules.phase == "response" and host.rules.pending.ask == 0, "An available counter restores an explicit choice for the sender")
	check(act(0, {"action":"no", "card":counter}) and host.rules.phase == "pay", "A counter with no opposing counter goes directly to payment")
	check(host.rules.plays == 2 and host.rules.action_notices[-1].responder == 0 and not host.rules.action_notices[-1].canceled, "Counters preserve play accounting and clear cancellation")

	fixture(); debt = take("debt-collector", 0); no = take("just-say-no", 1); take("just-say-no", 0)
	take("money-1", 1, true)
	host.rules.plays = 2; act(0, {"action":"debt", "card":debt, "target":1}); act(1, {"action":"no", "card":no})
	check(host.rules.phase == "play" and host.rules.plays == 3 and host.rules.action_notices[-1].canceled, "A sender out of plays cannot create a fourth play and has no redundant cancellation acknowledgement")

	fixture(); var sly := take("sly-deal", 0); var property := take("boardwalk", 1)
	host.rules.hands[1].erase(property); host.rules._receive_property(1, property, "dark-blue")
	check(act(0, {"action":"sly-deal", "card":sly, "target":1, "take":property}) and host.rules.phase == "play" and host.rules.properties[1].is_empty(), "Unavoidable property theft resolves immediately")
	view = host._snapshot(1)
	check(view.action_notices[-1].card.key == "sly-deal" and view.action_notices[-1].take_card.id == property and view.action_notices[-1].outcome == "resolved", "The chosen victim still receives exact action and stolen-card context after immediate resolution")
	check(host._action_summary(view.action_notices[-1], 1).contains("You were chosen") and host._action_summary(view.action_notices[-1], 1).contains("Sly Deal"), "Immediate-transfer feedback explicitly names the card and selection")

	fixture(); var birthday := take("birthday", 0); take("money-2", 1, true); take("money-2", 2, true)
	check(act(0, {"action":"birthday", "card":birthday}) and host._snapshot(1).has("payment") and host._snapshot(2).has("payment"), "Multi-player charges open every recipient's independent payment choices")
	money = host.rules.banks[1][0]; act(1, {"action":"pay", "cards":[money]})
	check(host.rules.phase == "pay" and host.rules.pending.target == 2 and host.rules.action_notices.size() == 2, "Each chosen recipient retains their own card context as payments advance")
	check(host._snapshot(-1).hand.is_empty() and host._snapshot(-1).actions.is_empty() and not host._snapshot(-1).has("payment"), "Public action context never exposes a private hand, response cards or payment choices")

	fixture(); var rent_card := take("rent-light-blue-brown", 0); var double := take("double-rent", 0)
	for key in ["mediterranean-avenue", "baltic-avenue"]:
		property = take(key, 0); host.rules.hands[0].erase(property); host.rules._receive_property(0, property, "brown")
	take("money-10", 1, true)
	check(act(0, {"action":"rent", "card":rent_card, "group":host.rules.properties[0][0].id, "double":[double]}) and host.rules.phase == "pay", "Doubled Rent also goes directly to payment choices")
	view = host._snapshot(1)
	check(view.pending.amount == 4 and view.pending.modifiers.size() == 1 and view.pending.modifiers[0].key == "double-rent", "Rent context identifies the multiplier card and actual calculated charge")
	money = host.rules.banks[1][0]; act(1, {"action":"pay", "cards":[money]})
	check(host.rules.phase == "play" and host.rules.action_notices.size() == 2 and host.rules.action_notices.any(func(details: Dictionary) -> bool: return details.target == 2 and details.paid == 0), "An empty recipient completes independently without hiding earlier recipients' context")

	fixture(); debt = take("debt-collector", 0)
	check(not act(0, {"action":"debt", "card":debt, "target":1}) and host.rules.phase == "play" and host.rules.action_notices.is_empty() and host.rules.hands[0].has(debt), "A target with no payable assets cannot be charged or consume a card")

	host.shutdown_game(); host.queue_free(); await process_frame
	print("Monopoly Deal transactions: %d checks, %d failures" % [checks, failures]); quit(1 if failures else 0)
