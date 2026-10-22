extends RefCounted

# Five seconds of flight, followed by a readable final hold.
const EJECTION_DURATION := 6.5

# The host owns roles, ballots and simultaneous night resolution.
const MAFIA_ROLES := ["mafia", "godfather"]
const ROLE_NAMES := {"mafia": "Mafia", "godfather": "Godfather", "detective": "Detective", "doctor": "Doctor", "boxer": "Boxer", "civilian": "Civilian"}
var players: Array = []
var roles: Array = []
var alive: Array = []
var disconnected: Array = []
var options := {"godfather": false, "boxer": false, "ejection": true}
var phase := "idle"
var revision := 0
var round_number := 0
var day := 0
var night_actions: Dictionary = {}
var votes: Dictionary = {}
var pending_suspicions: Dictionary = {}
var suspicions: Array = []
var last_wills: Dictionary = {}
var ejection: Dictionary = {}
var investigations: Dictionary = {}
var outcome: Dictionary = {}
var session_wins: Array = []
var history: Array = []
var events: Array = []
var event := ""


static func role_plan(count: int, selected: Dictionary = {}) -> Dictionary:
	if count < 4 or count > 16:
		return {}
	var mafia_count := 1 if count <= 6 else (2 if count <= 10 else (3 if count <= 13 else 4))
	var godfather := int(count >= 7 and selected.get("godfather", false) == true)
	var boxer := int(count >= 7 and selected.get("boxer", false) == true)
	return {"mafia": mafia_count - godfather, "godfather": godfather, "detective": 1, "doctor": 1, "boxer": boxer, "civilian": count - mafia_count - 2 - boxer}


func setup(roster: Array) -> bool:
	if role_plan(roster.size()).is_empty():
		return false
	players = roster.duplicate(true)
	disconnected.clear()
	for seat in players.size():
		if not bool(players[seat].get("connected", true)):
			disconnected.append(seat)
	session_wins.resize(players.size())
	session_wins.fill(0)
	alive.resize(players.size())
	alive.fill(true)
	phase = "setup"
	event = "Waiting for the host to start."
	revision += 1
	return true


func set_option(key: String, enabled: bool) -> bool:
	if phase not in ["setup", "finished"] or paused() or not options.has(key) or (key != "ejection" and players.size() < 7) or options[key] == enabled:
		return false
	options[key] = enabled
	revision += 1
	return true


func apply_options(selected: Dictionary) -> bool:
	if phase == "idle" or not disconnected.is_empty() or selected.size() != options.size():
		return false
	for key in options:
		if not selected.get(key) is bool or (key != "ejection" and players.size() < 7 and selected[key]):
			return false
	if selected == options:
		return false
	options = selected.duplicate()
	_start_round()
	return true


func restart() -> bool:
	if phase not in ["setup", "finished"] or paused():
		return false
	return _start_round()


func _start_round() -> bool:
	var plan := role_plan(players.size(), options)
	if plan.is_empty():
		return false
	roles.clear()
	for role in plan:
		for index in int(plan[role]):
			roles.append(role)
	roles.shuffle()
	alive.fill(true)
	night_actions.clear()
	votes.clear()
	pending_suspicions.clear()
	suspicions.clear()
	last_wills.clear()
	ejection.clear()
	investigations.clear()
	outcome.clear()
	events.clear()
	round_number += 1
	day = 1
	phase = "night"
	event = "Night 1. Private actions are open."
	revision += 1
	return true


func valid_seat(seat: int) -> bool:
	return seat >= 0 and seat < players.size()


func is_mafia(seat: int) -> bool:
	return valid_seat(seat) and roles.size() == players.size() and roles[seat] in MAFIA_ROLES


func missing() -> Array:
	# Eliminated spectators cannot stall the living players; replays need everyone.
	return disconnected.filter(func(seat: int) -> bool: return phase in ["setup", "finished"] or alive[seat])


func paused() -> bool:
	return not missing().is_empty()


func set_disconnected(seat: int) -> bool:
	if not valid_seat(seat) or disconnected.has(seat):
		return false
	disconnected.append(seat)
	revision += 1
	return true


func reconnect(seat: int) -> bool:
	if not disconnected.has(seat):
		return false
	disconnected.erase(seat)
	revision += 1
	return true


func night_actors() -> Array:
	var result: Array = []
	for seat in roles.size():
		if alive[seat] and roles[seat] != "civilian":
			result.append(seat)
	return result


func night_targets(seat: int) -> Array:
	var result: Array = []
	if not valid_seat(seat) or roles.size() != players.size() or not alive[seat] or roles[seat] == "civilian":
		return result
	for target in players.size():
		if not alive[target] or (is_mafia(seat) and is_mafia(target)):
			continue
		if target == seat and roles[seat] != "doctor":
			continue
		result.append(target)
	return result


func night_action(seat: int, target: int) -> bool:
	if phase != "night" or paused() or disconnected.has(seat) or not night_actors().has(seat) or night_actions.has(seat):
		return false
	if target != -1 and not night_targets(seat).has(target):
		return false
	if target == -1 and roles[seat] in ["detective", "doctor"]:
		return false
	night_actions[seat] = target
	revision += 1
	if _night_complete():
		_resolve_night()
	return true


func can_suspect(seat: int) -> bool:
	if not valid_seat(seat) or roles.size() != players.size() or paused() or disconnected.has(seat):
		return false
	if not alive[seat]:
		return phase in ["night", "vote"] and not last_wills.has(seat)
	return phase == "night" and roles[seat] == "civilian" and not pending_suspicions.has(seat)


func suspect(seat: int, target: int) -> bool:
	if not can_suspect(seat) or (target != -1 and (not valid_seat(target) or not alive[target] or target == seat)):
		return false
	var last_will: bool = not alive[seat]
	pending_suspicions[seat] = {"voter": seat, "target": target, "last_will": last_will}
	if last_will:
		last_wills[seat] = target
	revision += 1
	if phase == "night" and _night_complete():
		_resolve_night()
	return true


func _night_complete() -> bool:
	if night_actions.size() != night_actors().size():
		return false
	for seat in players.size():
		if alive[seat] and roles[seat] == "civilian" and not pending_suspicions.has(seat):
			return false
	return true


func _resolve_night() -> void:
	# Suspicions become public only at dawn, including the victim's final living choice.
	suspicions = pending_suspicions.values().duplicate(true)
	pending_suspicions.clear()
	var blocked := -1
	for actor in night_actions:
		if roles[actor] == "boxer":
			blocked = int(night_actions[actor])
	var tally: Dictionary = {}
	var protected := -1
	# Boxer cancels the actor's action, not a target's entire attack tally.
	for actor in night_actions:
		var target: int = night_actions[actor]
		if actor == blocked:
			if roles[actor] == "detective":
				_add_report(actor, target, "blocked")
			continue
		if target < 0:
			continue
		if is_mafia(actor):
			tally[target] = int(tally.get(target, 0)) + 1
		elif roles[actor] == "doctor":
			protected = target
		elif roles[actor] == "detective":
			_add_report(actor, target, "mafia" if roles[target] == "mafia" else "civilian")
	var leaders := _leaders(tally)
	var victim: int = leaders.pick_random() if not leaders.is_empty() else -1
	if victim >= 0 and victim != protected:
		alive[victim] = false
		event = "Day %d. %s was eliminated overnight." % [day, players[victim].display_name]
	else:
		event = "Day %d. Everyone survived the night." % day
	events.push_front(event)
	var suspected_names := PackedStringArray()
	for suspicion in public_suspicions():
		suspected_names.append(str(players[suspicion.target].display_name))
	events.push_front("Day %d. Suspected players: %s." % [day, ", ".join(suspected_names) if not suspected_names.is_empty() else "no one"])
	phase = "vote"
	votes.clear()
	_check_winner()
	revision += 1


func _add_report(actor: int, target: int, result: String) -> void:
	if not investigations.has(actor):
		investigations[actor] = []
	investigations[actor].push_front({"night": day, "target": target, "result": result})


# Only target identities are public. Authors and last-will status expose roles.
func public_suspicions() -> Array:
	var targets: Array = []
	for suspicion in suspicions:
		if suspicion.target >= 0 and not targets.has(suspicion.target):
			targets.append(suspicion.target)
	targets.sort()
	return targets.map(func(target: int) -> Dictionary: return {"target": target})


static func _leaders(tally: Dictionary) -> Array:
	var leaders: Array = []
	var most := 0
	for target in tally:
		var count: int = tally[target]
		if count > most:
			most = count
			leaders = [target]
		elif count == most:
			leaders.append(target)
	return leaders


func begin_vote(viewer := -1) -> bool:
	if phase != "discussion" or paused() or (viewer != -1 and (not valid_seat(viewer) or not alive[viewer] or disconnected.has(viewer))):
		return false
	phase = "vote"
	votes.clear()
	event = "Day %d. Town voting is open." % day
	revision += 1
	return true


func vote(seat: int, target: int) -> bool:
	if phase != "vote" or paused() or not valid_seat(seat) or not alive[seat] or disconnected.has(seat) or votes.has(seat):
		return false
	if target != -1 and (not valid_seat(target) or not alive[target] or target == seat):
		return false
	votes[seat] = target
	revision += 1
	if votes.size() == alive.count(true):
		_resolve_vote()
	return true


func _resolve_vote() -> void:
	var tally: Dictionary = {}
	for target in votes.values():
		tally[target] = int(tally.get(target, 0)) + 1
	var leaders := _leaders(tally)
	var convicted: int = leaders[0] if leaders.size() == 1 else -1
	if convicted >= 0:
		alive[convicted] = false
		event = "%s was voted out on day %d." % [players[convicted].display_name, day]
	else:
		event = "Day %d ended without an elimination." % day
	events.push_front(event)
	if convicted >= 0:
		ejection = {"seat": convicted, "reveal": options.ejection, "day": day, "elapsed": 0.0, "duration": EJECTION_DURATION}
		if options.ejection:
			ejection["mafia"] = is_mafia(convicted)
		phase = "ejection"
	else:
		_after_vote()
	revision += 1


func advance_ejection(delta: float) -> bool:
	if phase != "ejection" or paused():
		return false
	ejection.elapsed = minf(float(ejection.duration), float(ejection.elapsed) + maxf(0.0, delta))
	if ejection.elapsed < ejection.duration:
		return false
	_after_vote()
	revision += 1
	return true


func _after_vote() -> void:
	if not _check_winner():
		day += 1
		phase = "night"
		night_actions.clear()
		votes.clear()


func _check_winner() -> bool:
	var mafia_count := 0
	var town_count := 0
	for seat in players.size():
		if alive[seat]:
			if is_mafia(seat):
				mafia_count += 1
			else:
				town_count += 1
	if mafia_count == 0 or mafia_count >= town_count:
		_finish(mafia_count > 0)
		return true
	return false


func _finish(mafia_wins: bool) -> void:
	if phase == "finished":
		return
	var winners: Array = []
	var points: Array = []
	for seat in players.size():
		var won := is_mafia(seat) == mafia_wins
		points.append(int(won))
		if won:
			winners.append(seat)
			session_wins[seat] += 1
	outcome = {"mafia_wins": mafia_wins, "winners": winners, "points": points, "roles": roles.duplicate(), "round": round_number, "day": day}
	history.push_front(outcome.duplicate(true))
	phase = "finished"
	event = "Mafia wins!" if mafia_wins else "Town wins!"


func view_for(viewer := -1) -> Dictionary:
	var public_players: Array = []
	for seat in players.size():
		var player: Dictionary = players[seat]
		public_players.append({"id": str(player.get("id", "")), "display_name": str(player.get("display_name", "Player")), "color": str(player.get("color", "#58d6ff")), "pose": int(player.get("pose", 0)), "alive": bool(alive[seat]), "connected": not disconnected.has(seat)})
	var ballots: Array = []
	if phase == "vote":
		for seat in votes:
			ballots.append({"voter": seat, "target": votes[seat]})
	var state := {"viewer": viewer, "players": public_players, "phase": phase, "revision": revision, "round": round_number, "day": day, "options": options.duplicate(), "role_plan": role_plan(players.size(), options), "paused": paused(), "missing": missing(), "status": event, "ballots": ballots, "vote_count": votes.size() if phase == "vote" else 0, "alive_count": alive.count(true), "outcome": outcome.duplicate(true), "history": history.duplicate(true), "events": events.duplicate(), "session_wins": session_wins.duplicate(), "ejection": ejection.duplicate() if phase == "ejection" else {}, "daytime": phase in ["discussion", "vote", "ejection", "finished"]}
	if not valid_seat(viewer):
		state["suspicions"] = public_suspicions()
	if valid_seat(viewer):
		var role: String = roles[viewer] if roles.size() == players.size() else ""
		var allies: Array = []
		var mafia_votes: Array = []
		if is_mafia(viewer):
			for seat in players.size():
				if is_mafia(seat):
					allies.append(seat)
					if phase == "night" and night_actions.has(seat):
						mafia_votes.append({"voter": seat, "target": night_actions[seat]})
		state["secret"] = {"role": role, "allies": allies, "mafia_votes": mafia_votes, "reports": investigations.get(viewer, []).duplicate(true)}
		state["can_act"] = phase == "night" and not paused() and not disconnected.has(viewer) and night_actors().has(viewer) and not night_actions.has(viewer)
		state["can_vote"] = phase == "vote" and not paused() and not disconnected.has(viewer) and alive[viewer] and not votes.has(viewer)
		state["can_begin_vote"] = phase == "discussion" and not paused() and not disconnected.has(viewer) and alive[viewer]
		state["can_suspect"] = can_suspect(viewer)
		state["suspect_submitted"] = pending_suspicions.has(viewer)
		state["suspect_choice"] = pending_suspicions.get(viewer, {}).get("target", -1)
		state["last_will_used"] = last_wills.has(viewer)
		state["suspect_targets"] = []
		if state.can_suspect:
			for target in players.size():
				if alive[target] and target != viewer:
					state.suspect_targets.append(target)
		state["submitted"] = night_actions.has(viewer) if phase == "night" else (votes.has(viewer) if phase == "vote" else false)
		state["choice"] = night_actions.get(viewer, -1) if phase == "night" else votes.get(viewer, -1)
		state["targets"] = night_targets(viewer) if state.can_act else []
		if state.can_vote:
			for target in players.size():
				if alive[target] and target != viewer:
					state.targets.append(target)
	return state
