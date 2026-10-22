extends SceneTree

const Rules = preload("res://Games/mafia/host/rules.gd")
const Host = preload("res://Games/mafia/host/main.tscn")
var checks := 0
var failures := 0
var awards: Array = []
var reports: Array = []
var public_state: Dictionary = {}
var private_states: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)


func roster(count := 7) -> Array:
	var result: Array = []
	for seat in count:
		result.append({"id": "p%d" % seat, "display_name": "Player <%d>" % seat, "profile_id": "profile%d" % seat, "reconnect_token": "token%d" % seat, "color": "#2463eb", "pose": seat % 6})
	return result


func fixture(role_list: Array = ["mafia", "mafia", "detective", "doctor", "boxer", "civilian", "civilian"]):
	var rules = Rules.new()
	rules.setup(roster(role_list.size()))
	rules.restart()
	rules.roles = role_list.duplicate()
	return rules


func night(rules, choices: Dictionary) -> void:
	for actor in rules.night_actors():
		check(rules.night_action(actor, choices.get(actor, default_target(rules, actor))), "Every living night role can confirm exactly once")
	for seat in rules.players.size():
		if rules.alive[seat] and rules.roles[seat] == "civilian":
			check(rules.suspect(seat, -1), "Civilians can explicitly suspect no one")


func default_target(rules, actor: int) -> int:
	return actor if rules.roles[actor] == "doctor" else (rules.night_targets(actor)[0] if rules.roles[actor] == "detective" else -1)


func _send(host: Node, seat: int, action: String, extra: Dictionary = {}) -> void:
	var message := {"action": action, "revision": host.rules.revision}
	message.merge(extra, true)
	host.handle_controller_message("p%d" % seat, message)


func _run() -> void:
	seed(1879)
	for count in range(4, 17):
		for special in [false, true]:
			var rules = Rules.new()
			check(rules.setup(roster(count)) and rules.phase == "setup", "All supported counts enter host setup")
			check(not rules.options.godfather and not rules.options.boxer, "Optional roles default off")
			rules.set_option("godfather", special)
			rules.set_option("boxer", special)
			check(rules.restart(), "Host starts all supported role plans")
			var mafia_count := 1 if count <= 6 else (2 if count <= 10 else (3 if count <= 13 else 4))
			check(rules.roles.size() == count and rules.roles.count("mafia") + rules.roles.count("godfather") == mafia_count and rules.roles.count("doctor") == 1 and rules.roles.count("detective") == 1, "Roles scale without adding seats or extra mafia for Godfather")
			check(rules.roles.count("boxer") == int(special and count >= 7) and rules.roles.count("godfather") == int(special and count >= 7), "Special roles become available at seven players")
			check(not rules.set_option("boxer", not special) and not rules.restart(), "Live games cannot change roles or be replayed")
			var public: Dictionary = rules.view_for()
			check(not public.has("secret") and public.outcome.is_empty() and not public.has("night_total"), "Public state omits roles, actions and living role counts")
			for seat in count:
				var view: Dictionary = rules.view_for(seat)
				check(view.secret.role == rules.roles[seat] and not JSON.stringify(view).contains("profile") and not JSON.stringify(view).contains("token"), "Private snapshots reveal only their owner's role and strip profile metadata")
				check(view.secret.allies.size() == (mafia_count if rules.is_mafia(seat) else 0), "Only mafia receive their team identities")
	var invalid = Rules.new()
	check(not invalid.setup(roster(3)) and not invalid.setup(roster(17)), "Player limits reject three and seventeen")
	var collaboration = fixture()
	check(collaboration.night_action(0, 5), "Mafia can confirm an eligible kill vote")
	check(collaboration.view_for(1).secret.mafia_votes == [{"voter": 0, "target": 5}], "Fellow mafia sees the confirmed voter and target")
	for viewer in range(2, 7):
		check(collaboration.view_for(viewer).secret.mafia_votes.is_empty() and collaboration.view_for(viewer).secret.allies.is_empty(), "Town never receives mafia choices or identities")
	check(not collaboration.night_action(0, 6) and not collaboration.night_action(1, 0) and not collaboration.night_action(5, 0) and not collaboration.night_action(2, 2) and not collaboration.night_action(4, 4), "Repeated, team-kill, civilian and illegal self actions are rejected")
	check(collaboration.night_targets(3).has(3), "Doctor can protect themself")
	check(not collaboration.night_action(2, -1) and not collaboration.night_action(3, -1), "Detective and Doctor cannot pass on the authoritative host")
	var doubled = fixture()
	night(doubled, {0: 5, 1: 5, 4: 0})
	check(not doubled.alive[5] and doubled.phase == "vote" and doubled.votes.is_empty(), "Blocking one of two votes still kills and dawn immediately opens empty voting")
	var single = fixture(["mafia", "detective", "doctor", "boxer", "civilian", "civilian", "civilian"])
	night(single, {0: 4, 3: 0})
	check(single.alive.count(true) == 7, "Boxer stops a sole mafia vote")
	var recounted = fixture()
	night(recounted, {0: 5, 1: 6, 4: 0})
	check(recounted.alive[5] and not recounted.alive[6], "Removing a vote happens before tally and tie selection")
	var protected = fixture()
	night(protected, {0: 5, 1: 5, 3: 5})
	check(protected.alive[5], "Doctor prevents a multiple-mafia attack")
	var blocked_doctor = fixture()
	night(blocked_doctor, {0: 5, 1: 5, 3: 5, 4: 3})
	check(not blocked_doctor.alive[5], "Boxer cancels Doctor's protection")
	var blocked_detective = fixture()
	night(blocked_detective, {2: 0, 4: 2})
	check(blocked_detective.view_for(2).secret.reports[0].result == "blocked" and blocked_detective.view_for(3).secret.reports.is_empty(), "Blocked Detective gets no alignment result and reports stay private")
	for target in [0, 1, 5]:
		var investigated = fixture(["mafia", "godfather", "detective", "doctor", "boxer", "civilian", "civilian"])
		night(investigated, {2: target})
		check(investigated.view_for(2).secret.reports[0].result == ("mafia" if target == 0 else "civilian"), "Detective sees Mafia correctly and Godfather as civilian")
	var seen: Dictionary = {}
	for repeat in 90:
		var tied = fixture(["mafia", "mafia", "mafia", "detective", "doctor", "civilian", "civilian", "civilian", "civilian", "civilian", "civilian"])
		for actor in tied.night_actors():
			tied.night_action(actor, 5 + actor if actor < 3 else default_target(tied, actor))
		for seat in range(5, 11):
			tied.suspect(seat, -1)
		var killed: int = tied.alive.find(false)
		check(killed in [5, 6, 7] and tied.alive.count(false) == 1, "Three tied mafia votes kill exactly one voted target")
		seen[killed] = true
	check(seen.size() == 3, "Random ties can select every tied target")
	var plurality = fixture(["mafia", "mafia", "mafia", "detective", "doctor", "civilian", "civilian", "civilian", "civilian", "civilian", "civilian"])
	night(plurality, {0: 5, 1: 5, 2: 6})
	check(not plurality.alive[5] and plurality.alive[6], "A lower-vote target is never selected over the plurality leader")
	var simultaneous = fixture()
	night(simultaneous, {0: 4, 1: 4, 4: 0, 2: 1})
	check(not simultaneous.alive[4] and simultaneous.investigations[2][0].result == "mafia", "Night actions resolve simultaneously even when Boxer dies")
	check(not simultaneous.night_action(4, 0) and simultaneous.phase == "vote" and not simultaneous.vote(4, 0), "Eliminated players cannot act or vote")
	var paused = fixture()
	paused.night_action(0, 5)
	var secret: Dictionary = paused.view_for(1).secret
	check(paused.set_disconnected(3) and paused.paused() and not paused.night_action(1, 5), "A living disconnect pauses all choices")
	check(paused.reconnect(3) and not paused.paused() and paused.view_for(1).secret == secret, "Reconnect preserves role and teammates' confirmed votes")
	paused.alive[5] = false
	paused.set_disconnected(5)
	check(not paused.paused(), "A disconnected eliminated spectator does not pause survivors")
	var tied_day = fixture()
	night(tied_day, {})
	check(tied_day.phase == "vote" and tied_day.view_for(6).can_vote and tied_day.view_for().vote_count == 0, "Dawn opens the daytime ballot without a player's request")
	for seat in 7:
		tied_day.vote(seat, 0 if seat in [1, 2, 3] else (1 if seat in [0, 4, 5] else -1))
	check(tied_day.phase == "night" and tied_day.day == 2 and tied_day.alive.count(true) == 7 and tied_day.night_actions.is_empty(), "Town ties eliminate nobody and reset choices for the next night")
	var skip_day = fixture()
	night(skip_day, {})
	skip_day.begin_vote()
	for seat in 7:
		skip_day.vote(seat, -1)
	check(skip_day.phase == "night" and skip_day.alive.count(true) == 7, "A Skip majority eliminates nobody")
	var town = fixture(["mafia", "detective", "doctor", "civilian"])
	night(town, {})
	town.begin_vote()
	for seat in 4:
		town.vote(seat, 1 if seat == 0 else 0)
	check(town.phase == "ejection" and town.history.is_empty(), "The final mafia's default ejection plays before recording the result")
	town.advance_ejection(Rules.EJECTION_DURATION)
	check(town.phase == "finished" and not town.outcome.mafia_wins and town.outcome.winners == [1, 2, 3] and town.view_for().outcome.roles == town.roles, "Voting out the last mafia wins immediately and reveals roles")
	var wins: Array = town.session_wins.duplicate()
	check(town.restart() and town.phase == "night" and town.round_number == 2 and town.alive.count(true) == 4 and town.history.size() == 1 and town.session_wins == wins and town.investigations.is_empty(), "Replay redeals roles, restores players and retains completed history and wins")
	var parity = fixture(["mafia", "detective", "doctor", "civilian"])
	night(parity, {0: 3})
	parity.begin_vote()
	for seat in 3:
		parity.vote(seat, 1 if seat != 1 else 2)
	parity.advance_ejection(Rules.EJECTION_DURATION)
	check(parity.phase == "finished" and parity.outcome.mafia_wins and parity.outcome.winners == [0], "Mafia wins at living parity after a town elimination")
	await _test_host()
	_test_suspicions_and_ejection()
	print("Mafia: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _test_host() -> void:
	var host = Host.instantiate()
	root.add_child(host)
	host.settings_store = preload("res://tests/game_settings_fixture.gd").new()
	host.initialize_session(GameSessionContext.new("mafia", roster(4), {}, true))
	host.points_awarded.connect(func(id: String, amount: int) -> void: awards.append([id, amount]))
	host.result_reported.connect(func(id: String, won: bool) -> void: reports.append([id, won]))
	host.controller_state_updated.connect(func(state: Dictionary) -> void: public_state = state)
	host.controller_private_state_updated.connect(func(id: String, state: Dictionary) -> void: private_states[id] = state)
	host.start_game()
	check(public_state.phase == "setup" and not public_state.has("secret") and private_states.size() == 4, "Host lifecycle publishes distinct public and private setup views")
	host._replay()
	host.rules.roles = ["mafia", "detective", "doctor", "civilian"]
	host._publish()
	var revision: int = host.rules.revision
	for message in [{"action": "night_action", "target": 3}, {"action": "night_action", "revision": revision - 1, "target": 3}, {"action": "night_action", "revision": revision, "target": true}, {"action": "night_action", "revision": revision, "target": "3"}, {"action": "night_action", "revision": revision, "target": 1.5}, {"action": "night_action", "revision": revision, "target": -2}, {"action": "night_action", "revision": revision, "target": 99}, {"action": "night_action", "revision": revision, "target": INF}, {"action": "replay", "revision": revision}, {"action": "options", "revision": revision, "boxer": true}]:
		host.handle_controller_message("p0", message)
	host.handle_controller_message("intruder", {"action": "night_action", "revision": revision, "target": 3})
	check(host.rules.revision == revision and host.rules.night_actions.is_empty(), "Malformed, stale, unknown-sender and host-only controller actions cannot mutate the game")
	for seat in 3:
		_send(host, seat, "night_action", {"target": default_target(host.rules, seat)})
	_send(host, 3, "suspect", {"target": -1})
	check(host.rules.phase == "vote" and public_state.daytime and not host.phase_dialog.overlay.visible and host.ballot_scroll.visible, "Dawn opens voting inline in the middle column without a popup")
	_send(host, 3, "begin_vote")
	check(host.rules.phase == "vote" and host.rules.votes.is_empty(), "Legacy Cast Vote cannot reset voting or submit a ballot")
	check(host.ballot_scroll.is_ancestor_of(host.ballot_label), "Ballots use the central scrolling panel")
	host.sky.set_daytime(false, false)
	host.sky.set_daytime(true, true)
	await create_timer(0.3).timeout
	var sky_transition: Tween = host.sky.transition
	check(host.sky.cycle > 1.0 and host.sky.cycle < 2.0, "Dawn rotates the setting moon and rising sun through an intermediate position")
	host.sky.set_daytime(true, true)
	check(host.sky.transition == sky_transition, "Duplicate phase snapshots preserve the active sky rotation")
	host.sky.set_daytime(true, true, true)
	check(host.sky.cycle == 0.0 and host.sky.orbit_position(0).y > 0 and host.sky.orbit_position(1).y > host.sky.size.y, "Reduced motion restores the sun immediately and parks the moon below the horizon")
	for seat in 4:
		_send(host, seat, "vote", {"target": 1 if seat == 0 else 0, "profile_id": "injected", "score": 1000})
	check(host.rules.phase == "ejection" and host.ejection_stage.visible and reports.is_empty() and awards.is_empty(), "A default host ejection is visible and delays results and scoring")
	host.rules.advance_ejection(Rules.EJECTION_DURATION)
	host._record_result()
	host._publish()
	check(reports.size() == 4 and awards.size() == 3 and awards.all(func(award: Array) -> bool: return award[1] == 1 and award[0].begins_with("profile")), "Scoring uses admitted profiles exactly once and ignores controller scores")
	host._record_result()
	_send(host, 1, "vote", {"target": 0})
	check(reports.size() == 4 and awards.size() == 3, "Duplicate completion and inputs cannot repeat awards")
	check(host.replay.visible and host.phase_dialog.overlay.visible and not host.reveal_label.get_parsed_text().is_empty(), "The shared results dialog reveals roles and one replay action")
	check(host.living_team.get_child_count() == 4 and host.living_team.get_child(0).get_meta("eliminated") and host.living_team.get_child(0).get_child(0).texture.resource_path.ends_with("tombstone.svg"), "The host retains an eliminated seat as a shared tombstone")
	check(host.living_team.get_child(0).get_child(1).get_parsed_text() == "Player <0>" and host.roster_rows[0].player.get_parsed_text() == "Player <0>", "Formatted eliminated names preserve literal player text")
	check(not host.reveal_label.get_parsed_text().contains(" · +1 point") and host.reveal_label.get_parsed_text().contains("Detective +1 point"), "Results put points directly after roles")
	host._replay()
	check(host.rules.round_number == 2 and host.rules.history.size() == 1 and not host.phase_dialog.overlay.visible and host.rules.roles.size() == 4, "Host-only replay preserves standings and clears the result view")
	var before_apply: int = host.rules.round_number
	host._set_option("ejection", false)
	check(host.rules.options.ejection and not host.staged_options.ejection and not host.apply_button.disabled, "Live settings remain staged until Apply")
	host._apply_options()
	check(not host.rules.options.ejection and host.rules.round_number == before_apply + 1 and host.rules.history.size() == 1 and reports.size() == 4 and awards.size() == 3 and host.apply_button.disabled, "Apply restarts immediately without scoring the abandoned game or clearing completed totals")
	host.player_disconnected("p2")
	check(host.rules.paused(), "Host disconnect callback pauses the game")
	var own_role: String = private_states.p2.secret.role
	host.player_joined(roster(4)[2])
	check(not host.rules.paused() and private_states.p2.secret.role == own_role, "Launcher join callback restores the same role")
	for button in host.find_children("*", "Button", true, false):
		check(button.tooltip_text.is_empty(), "Host controls have no hover popups")
	host.shutdown_game()
	check(not host.active and not host.phase_dialog.overlay.visible, "Shutdown stops media and dismisses shared overlays")
	host.queue_free()
	await process_frame


func _test_suspicions_and_ejection() -> void:
	var rules = fixture()
	check(rules.suspect(5, 0) and not rules.suspect(5, 1), "Living civilians submit one suspicion per night")
	check(not rules.suspect(2, 0) and not rules.suspect(6, 6) and not rules.suspect(6, 99), "Living special roles, self and invalid suspicions are rejected")
	check(rules.view_for().suspicions.is_empty() and not rules.view_for().has("suspect_choice") and rules.view_for(0).suspect_choice == -1, "Pending civilian choices stay out of public and other players' snapshots")
	for actor in rules.night_actors():
		rules.night_action(actor, 5 if actor in [0, 1] else default_target(rules, actor))
	check(rules.phase == "night", "Night waits for civilians to make a suspect-or-no-one choice")
	rules.suspect(6, -1)
	check(rules.phase == "vote" and rules.view_for().suspicions == [{"target": 0}] and not rules.alive[5], "Dawn reveals only anonymous targets, including a victim's living suspicion")
	check(not rules.view_for(6).has("suspicions") and rules.events[0] == "Day 1. Suspected players: Player <0>.", "Private packets and history contain no suspicion authors or will markers")
	check(not rules.begin_vote(5) and rules.suspect(5, 1) and not rules.suspect(5, 0), "Eliminated players get one last will and cannot open voting")
	check(rules.view_for().suspicions[0].target == 0 and rules.view_for(5).last_will_used, "A will remains private until the following dawn")
	rules.begin_vote(6)
	for seat in rules.players.size():
		if rules.alive[seat]: rules.vote(seat, -1)
	check(rules.view_for().suspicions == [{"target": 0}] and not rules.view_for().daytime, "The published list persists during the next night")
	for actor in rules.night_actors(): rules.night_action(actor, default_target(rules, actor))
	rules.suspect(6, 0)
	check(rules.suspicions.any(func(entry: Dictionary) -> bool: return entry.voter == 5 and entry.target == 1 and entry.last_will), "Last will appears publicly the next day")
	check(rules.view_for().suspicions == [{"target": 0}, {"target": 1}] and rules.view_for().suspicions.all(func(entry: Dictionary) -> bool: return entry.keys() == ["target"]), "Public last-will targets do not reveal an author or last-will status")
	check(not rules.suspect(5, 0), "The last-will limit survives phase changes")
	var previous_round: int = rules.round_number
	check(rules.apply_options({"godfather": true, "boxer": true, "ejection": true}) and rules.phase == "night" and rules.round_number == previous_round + 1 and rules.last_wills.is_empty() and rules.history.is_empty(), "Apply abandons live play, redeals and resets wills without scoring")
	check(not rules.apply_options({"godfather": true, "boxer": true, "ejection": true}) and not rules.apply_options({"godfather": true}), "Unchanged and incomplete settings do not restart play")
	var animated = fixture(["mafia", "detective", "doctor", "civilian"])
	check(animated.options.ejection, "Ejection alignment reveals default on")
	animated.options.ejection = true
	night(animated, {})
	animated.begin_vote(3)
	for seat in 4: animated.vote(seat, 1 if seat == 0 else 0)
	check(animated.phase == "ejection" and animated.ejection.mafia and animated.history.is_empty() and not animated.vote(1, 2), "Enabled ejection reveals convicted alignment and locks input before results")
	animated.set_disconnected(2)
	check(not animated.advance_ejection(3) and animated.ejection.elapsed == 0, "Living disconnect pauses the ejection timeline")
	animated.reconnect(2)
	check(not animated.advance_ejection(2.6) and animated.phase == "ejection" and is_equal_approx(animated.ejection.duration, 6.5), "The slower reveal keeps gameplay locked past the former 2.6-second cutoff")
	check(animated.advance_ejection(Rules.EJECTION_DURATION) and animated.phase == "finished" and animated.history.size() == 1 and not animated.advance_ejection(3), "Ejection finishes once and awards one completed round")
	var innocent = fixture()
	innocent.options.ejection = true
	night(innocent, {})
	innocent.begin_vote()
	for seat in 7: innocent.vote(seat, 6 if seat != 6 else 5)
	check(innocent.phase == "ejection" and not innocent.ejection.mafia, "Optional animation identifies an innocent conviction")
	innocent.advance_ejection(Rules.EJECTION_DURATION)
	check(innocent.phase == "night" and innocent.day == 2, "An innocent ejection resumes the next night")
	check(innocent.suspect(6, -1) and not innocent.suspect(6, 0), "A dead player may explicitly choose no one once")
	var private_ejection = fixture()
	private_ejection.options.ejection = false
	night(private_ejection, {})
	for seat in 7: private_ejection.vote(seat, 6 if seat != 6 else 5)
	check(private_ejection.phase == "ejection" and not private_ejection.view_for().ejection.has("mafia") and not private_ejection.ejection.reveal, "Disabling alignment reveal keeps the ejection animation without leaking a role")
