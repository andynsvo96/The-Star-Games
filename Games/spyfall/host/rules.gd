extends RefCounted

# Secrets never enter public snapshots. All decisions and clocks belong to the host.
var players: Array = []
var locations: Array = []
var duration := 480.0
var remaining := 480.0
var timer_started := false
var vote_duration := 60.0
var vote_remaining := 60.0
var vote_timer_started := false
var vote_number := 0
var revision := 0
var round_number := 0
var phase := "idle"
var spy := -1
var location := ""
var starter := 0
var used_accusations: Array = []
var votes: Dictionary = {}
var suspect := -1
var accuser := -1
var missing: Array = []
var session_points: Array = []
var session_wins: Array = []
var history: Array = []
var outcome: Dictionary = {}
var event := ""
var anonymous_voting := false
var sound_sequence := 0
var sound_events: Array = []


func setup(roster: Array, names: Array, seconds: float, voting_seconds := 60.0) -> bool:
	if roster.size() < 4 or roster.size() > 8 or names.size() < 2:
		return false
	players = roster.duplicate(true)
	locations = names.duplicate()
	duration = seconds
	vote_duration = voting_seconds
	session_points.resize(players.size())
	session_points.fill(0)
	session_wins.resize(players.size())
	session_wins.fill(0)
	return restart()


func restart() -> bool:
	if players.size() < 4 or players.size() > 8 or locations.size() < 2:
		return false
	starter = spy if spy >= 0 else randi_range(0, players.size() - 1)
	spy = randi_range(0, players.size() - 1)
	location = str(locations.pick_random())
	round_number += 1
	remaining = duration
	timer_started = true
	vote_remaining = vote_duration
	vote_timer_started = false
	vote_number = 0
	phase = "playing"
	used_accusations.clear()
	votes.clear()
	suspect = -1
	accuser = -1
	outcome.clear()
	sound_events.clear()
	event = "Round in progress."
	revision += 1
	return true


func valid_seat(seat: int) -> bool:
	return seat >= 0 and seat < players.size()


func clock_running() -> bool:
	return timer_started and phase == "playing" and missing.is_empty()


func vote_clock_running() -> bool:
	return vote_timer_started and phase in ["vote", "final_vote"] and missing.is_empty()


func _reset_vote_clock() -> void:
	vote_number += 1
	vote_remaining = vote_duration
	vote_timer_started = false


func tick(seconds: float) -> bool:
	if not missing.is_empty() or seconds <= 0:
		return false
	if clock_running():
		remaining = maxf(0, remaining - seconds)
		if remaining > 0:
			return false
		phase = "final_vote"
		_reset_vote_clock()
		_record_sound("timer_up")
		votes.clear()
		event = "Time is up. Everyone votes for a suspect on their phone."
		revision += 1
		return true
	if vote_clock_running():
		vote_remaining = maxf(0, vote_remaining - seconds)
		if vote_remaining > 0:
			return false
		_record_sound("timer_up")
		if phase == "vote":
			_reject_accusation("Voting timed out. Conversation resumes.")
		else:
			_resolve_final_vote()
		return true
	return false


func accuse(seat: int, target: int) -> bool:
	if phase != "playing" or not missing.is_empty() or not valid_seat(seat) or seat == spy or not valid_seat(target) or seat == target or used_accusations.has(seat):
		return false
	used_accusations.append(seat)
	accuser = seat
	suspect = target
	votes = {seat: true}
	# The initiator's automatic Yes starts only this accusation's voting deadline.
	_reset_vote_clock()
	vote_timer_started = true
	_record_sound("vote")
	phase = "vote"
	event = "An accusation is open. The round timer is paused; the voting timer is running."
	revision += 1
	return true


func vote(seat: int, agree: bool) -> bool:
	if phase != "vote" or not missing.is_empty() or not valid_seat(seat) or seat == suspect or votes.has(seat):
		return false
	votes[seat] = agree
	_record_sound("vote")
	revision += 1
	if not agree:
		_reject_accusation("The accusation was rejected. Conversation resumes.")
	elif votes.size() == players.size() - 1:
		finish(suspect != spy, "caught" if suspect == spy else "innocent", accuser)
	return true


func _reject_accusation(message: String) -> void:
	phase = "playing"
	vote_timer_started = false
	votes.clear()
	suspect = -1
	accuser = -1
	event = message
	revision += 1


func final_vote(seat: int, target: int) -> bool:
	if phase != "final_vote" or not missing.is_empty() or not valid_seat(seat) or not valid_seat(target) or seat == target or votes.has(seat):
		return false
	votes[seat] = target
	# Waiting in the final-vote view does not use any of its deadline.
	vote_timer_started = true
	_record_sound("vote")
	revision += 1
	if votes.size() == players.size():
		_resolve_final_vote()
	return true


func _resolve_final_vote() -> void:
	var convicted := -1
	for candidate in players.size():
		var count := 0
		for voter in votes:
			if voter != candidate and votes[voter] == candidate:
				count += 1
		if count == players.size() - 1:
			convicted = candidate
			break
	finish(convicted != spy, "caught" if convicted == spy else ("innocent" if convicted >= 0 else "escaped"))


func guess(seat: int, name: String) -> bool:
	if phase != "playing" or not missing.is_empty() or seat != spy or not locations.has(name):
		return false
	finish(name == location, "guessed" if name == location else "wrong_guess")
	outcome["guess"] = name
	return true


func finish(spy_wins: bool, reason: String, initiator := -1) -> void:
	if phase == "finished":
		return
	var points: Array = []
	var winners: Array = []
	for seat in players.size():
		var won := (seat == spy) == spy_wins
		var amount := 0
		if won:
			winners.append(seat)
			amount = (2 if reason == "escaped" else 4) if spy_wins else (2 if seat == initiator else 1)
			session_wins[seat] += 1
		session_points[seat] += amount
		points.append(amount)
	outcome = {"spy_wins": spy_wins, "reason": reason, "spy": spy, "location": location, "points": points, "winners": winners, "round": round_number}
	history.push_front(outcome.duplicate(true))
	phase = "finished"
	_record_sound("spy_win" if spy_wins else "non_spies_win")
	event = "The spy wins!" if spy_wins else "The non-spies win!"
	revision += 1


func _record_sound(kind: String) -> void:
	sound_sequence += 1
	# Public sound events never identify a voter, choice or unfinished spy role.
	sound_events.append({"sequence": sound_sequence, "kind": kind})
	if sound_events.size() > 32:
		sound_events.pop_front()


func set_disconnected(seat: int) -> bool:
	if not valid_seat(seat) or missing.has(seat):
		return false
	missing.append(seat)
	revision += 1
	return true


func reconnect(seat: int) -> bool:
	if not missing.has(seat):
		return false
	missing.erase(seat)
	revision += 1
	return true


func view_for(seat := -1) -> Dictionary:
	var roster: Array = []
	for player in players:
		roster.append({"id": str(player.get("id", "")), "display_name": str(player.get("display_name", "Player")), "color": str(player.get("color", "#58d6ff")), "pose": int(player.get("pose", 0))})
	var status := event
	if not missing.is_empty():
		status = "Paused: waiting for players to reconnect."
	elif phase == "playing":
		status = "%s asks first. Conversation is aloud." % str(players[starter].get("display_name", "Player"))
	elif phase == "vote":
		status = "%s accused %s. Vote on your phone." % [players[accuser].display_name, players[suspect].display_name]
	var voting: Array = []
	if phase in ["vote", "final_vote", "finished"]:
		for target in players.size():
			var voters: Array = []
			for voter in votes:
				var choice: int = suspect if votes[voter] is bool else int(votes[voter])
				if choice == target:
					voters.append(voter)
			voting.append({"target": target, "count": voters.size(), "voters": [] if anonymous_voting else voters})
	var state := {"viewer": seat, "players": roster, "phase": phase, "revision": revision, "round": round_number, "duration": duration, "remaining": remaining, "paused": not missing.is_empty(), "missing": missing.duplicate(), "locations": locations.duplicate(), "suspect": suspect, "accuser": accuser, "vote_count": votes.size(), "voting": voting, "anonymous_voting": anonymous_voting, "session_points": session_points.duplicate(), "session_wins": session_wins.duplicate(), "history": history.duplicate(true), "outcome": outcome.duplicate(true), "status": status}
	state["sound_sequence"] = sound_sequence
	state["timer_started"] = timer_started
	state["vote_duration"] = vote_duration
	state["vote_remaining"] = vote_remaining
	state["vote_timer_started"] = vote_timer_started
	state["vote_number"] = vote_number
	state["sound_events"] = sound_events.duplicate(true)
	if valid_seat(seat):
		state["secret"] = {"spy": seat == spy, "location": "" if seat == spy else location}
		state["can_accuse"] = phase == "playing" and missing.is_empty() and seat != spy and not used_accusations.has(seat)
		state["can_guess"] = phase == "playing" and missing.is_empty() and seat == spy
		state["can_vote"] = missing.is_empty() and not votes.has(seat) and (phase == "final_vote" or (phase == "vote" and seat != suspect))
		state["voted"] = votes.has(seat)
	return state
