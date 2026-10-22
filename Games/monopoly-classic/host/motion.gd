extends RefCounted

# One host clock orders dice, board movement, public cards and cash feedback.
const ROLL_SECONDS := 1.05
const STEP_SECONDS := .27
var revision := 0
var duration := 0.0
var moves: Array = []
var rolls: Array = []
var specials: Array = []
var money: Array = []
var cues: Array = []
var cards := GameCardMotion.new()


func clear() -> void:
	revision += 1
	duration = 0; moves = []; rolls = []; specials = []; money = []; cues = []
	cards.begin([]); cards.revision = revision


func begin(events: Array, before: Array, roster: Array, labels: Dictionary) -> void:
	clear()
	var cursor := 0.0
	var balances := before.duplicate()
	var pending_go: Array = []
	for event in events:
		var kind := str(event.kind)
		if kind == "roll":
			rolls.append({"start": cursor, "duration": ROLL_SECONDS, "dice": event.dice.duplicate()})
			cues.append({"cue": "roll", "start": cursor}); cursor += ROLL_SECONDS
			if int(event.dice[0]) == int(event.dice[1]):
				specials.append({"kind":"doubles", "start":cursor, "duration":.85})
				cues.append({"cue":"doubles", "start":cursor}); cursor += .85
		elif kind in ["move", "jail"]:
			var steps := posmod(int(event.from) - int(event.to), 40) if event.get("backwards", false) else posmod(int(event.to) - int(event.from), 40)
			var seconds := .9 if kind == "jail" else maxf(STEP_SECONDS, steps * STEP_SECONDS)
			moves.append({"seat": int(event.seat), "from": int(event.from), "to": int(event.to), "start": cursor, "duration": seconds, "backwards": event.get("backwards", false), "teleport": kind == "jail"})
			if kind == "move":
				for step in steps: cues.append({"cue": "move", "start": cursor + (step + .8) * STEP_SECONDS})
			var income_end := 0.0
			for payment in pending_go:
				payment.start = cursor + minf(seconds, (40 - int(event.from)) * STEP_SECONDS)
				money.append(payment); cues.append({"cue": "cash", "start": payment.start})
				income_end = maxf(income_end, float(payment.start) + float(payment.duration))
			pending_go.clear(); cursor = maxf(cursor + seconds, income_end)
			if kind == "jail":
				specials.append({"kind": "jail", "seat": int(event.seat), "start": cursor, "duration": 1.35})
				cues.append({"cue": "jail", "start": cursor + .42}); cursor += 1.35
		elif kind == "card":
			var community := str(event.card.key).begins_with("community-")
			if community:
				specials.append({"kind": "chest", "seat": int(event.seat), "start": cursor, "duration": .9})
				cues.append({"cue": "chest", "start": cursor}); cursor += .65
			var card: Dictionary = event.card.duplicate(true)
			card.display_name = str(labels.get(card.key, card.name))
			var art := "res://Games/monopoly-classic/art/%s.svg" % card.key
			cards.flights.append({"from": {"zone": "community" if community else "chance"}, "to": {"zone": "reveal"}, "card": card, "delay": cursor, "duration": .5})
			cues.append({"cue": "card_draw", "start": cursor})
			cards.effects.append({"card": card, "art": art, "display_name": card.display_name, "label": str(roster[int(event.seat)].display_name) + " · " + card.display_name, "start": cursor + .5, "duration": 1.75})
			cursor += 2.25
			cards.flights.append({"from": {"zone": "reveal"}, "to": {"zone": "player", "seat": int(event.seat)}, "card": card, "delay": cursor, "duration": .5})
			cues.append({"cue": "card_draw", "start": cursor}); cursor += .5
		elif kind == "trade":
			var trade_end := cursor
			for index in event.get("transfers", []).size():
				var transfer: Dictionary = event.transfers[index]
				cards.flights.append({"from":{"zone":"player", "seat":int(transfer.from)}, "to":{"zone":"player", "seat":int(transfer.to)}, "card":transfer.card.duplicate(true), "delay":cursor + index * .13, "duration":.85})
				cues.append({"cue":"card_draw", "start":cursor + index * .13}); trade_end = maxf(trade_end, cursor + index * .13 + .95)
			for pair in [["give_cash", int(event.seat), int(event.target)], ["take_cash", int(event.target), int(event.seat)]]:
				var amount := int(event.get(pair[0], 0))
				if amount <= 0: continue
				money.append({"seat":pair[1], "target":pair[2], "changes":[{"seat":pair[1],"amount":-amount},{"seat":pair[2],"amount":amount}], "start":cursor, "duration":1.25})
				cues.append({"cue":"cash", "start":cursor}); trade_end = maxf(trade_end, cursor + 1.25)
			cursor = trade_end
		if event.has("balances") and balances.size() == event.balances.size():
			var changes: Array = []
			for seat in balances.size():
				var delta := int(event.balances[seat]) - int(balances[seat])
				if delta != 0: changes.append({"seat": seat, "amount": delta})
			balances = event.balances.duplicate()
			if not changes.is_empty() and kind != "trade":
				var payer := -1; var payee := -1
				for change in changes:
					if int(change.amount) < 0: payer = int(change.seat)
					else: payee = int(change.seat)
				var payment := {"seat": payer, "target": payee if payer >= 0 else -1, "changes": changes, "start": cursor, "duration": 1.15}
				if kind == "go": pending_go.append(payment)
				else:
					money.append(payment); cues.append({"cue": "cash", "start": cursor}); cursor += 1.15
		if kind in ["build", "sell", "sell_group"]: cues.append({"cue": "build", "start": maxf(0, cursor - 1.15)})
		if kind == "win": cues.append({"cue": "win", "start": cursor})
	for event in money: cursor = maxf(cursor, float(event.start) + float(event.duration))
	duration = cursor; cards.duration = cursor; cards.revision = revision


func view(elapsed: float, active: bool) -> Dictionary:
	var result := cards.view(-1, elapsed, active)
	result.money = money.duplicate(true)
	return result
