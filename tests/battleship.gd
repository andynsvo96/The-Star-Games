extends SceneTree

const Rules = preload("res://Games/battleship/host/rules.gd")
const Host = preload("res://Games/battleship/host/main.tscn")
const LOCAL := {"id": "local-host", "display_name": "Admiral", "color": "#ff9800"}
const PHONE := {"id": "phone", "display_name": "Captain", "color": "#2463eb", "reconnect_token": "private-token"}
const SECOND := {"id": "second", "display_name": "Opponent", "color": "#e53935", "profile_id": "private-profile"}
var checks := 0
var failures := 0
var awards := 0
var reports := 0
var broadcasts := 0
var private_states: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)


func _host(players: Array) -> Node:
	var host := Host.instantiate()
	root.add_child(host)
	var context := GameSessionContext.new("battleship", players, LOCAL, not players.is_empty())
	context.reduced_motion = true
	host.settings_store = preload("res://tests/game_settings_fixture.gd").new()
	host.initialize_session(context)
	host.points_awarded.connect(func(_id: String, amount: int) -> void: awards += amount)
	host.result_reported.connect(func(_id: String, _won: bool) -> void: reports += 1)
	host.controller_state_updated.connect(func(_state: Dictionary) -> void: broadcasts += 1)
	host.controller_private_state_updated.connect(func(id: String, state: Dictionary) -> void: private_states[id] = state)
	for sound in host.sounds.values():
		sound.volume_db = -80
	host.start_game()
	return host


func _send(host: Node, id: String, action: String, extra: Dictionary = {}) -> void:
	var input := {"action": action, "revision": host.rules.revision}
	input.merge(extra, true)
	host.handle_controller_message(id, input)


func _finish_host(host: Node, winner: int) -> void:
	var target_cells: Array = []
	for ship in host.rules.fleets[2 - winner]:
		target_cells.append_array(ship.cells)
	var winner_cells: Array = []
	for ship in host.rules.fleets[winner - 1]:
		winner_cells.append_array(ship.cells)
	var miss_cells := range(100).filter(func(cell: int) -> bool: return not winner_cells.has(cell))
	var hit := 0
	var miss := 0
	while host.rules.outcome == 0 and hit < 18:
		var seat: int = host.rules.turn
		host._fire(seat, target_cells[hit] if seat == winner else miss_cells[miss])
		if seat == winner:
			hit += 1
		else:
			miss += 1


func _run() -> void:
	seed(7317)
	var rules := Rules.new()
	check(Rules.ship_cells(8, 4, false).is_empty() and Rules.ship_cells(90, 2, true).is_empty(), "Ships cannot wrap rows or leave the board")
	check(Rules.ship_cells(96, 4, false) == [96, 97, 98, 99] and Rules.ship_cells(59, 5, true) == [59, 69, 79, 89, 99], "Both orientations reach the final square correctly")
	check(not rules.fire(1, 0) and not rules.lock_fleet(1), "Firing and locking an incomplete fleet are rejected")
	check(not rules.place_ship(0, 0, 0, false) and not rules.place_ship(1, 5, 0, false), "Bad seats and ship IDs are rejected")
	check(not rules.rotate_ship(1, 0) and not rules.rotate_ship(0, 0) and not rules.rotate_ship(1, 100) and rules.revision == 0, "Rotation cannot deploy a ship or accept bad seats and coordinates")
	check(rules.place_ship(1, 0, 0, false), "Carrier deploys")
	var revision := rules.revision
	check(not rules.place_ship(1, 1, 2, false) and rules.revision == revision, "Overlap is rejected without changing revision")
	check(rules.place_ship(1, 0, 10, false) and rules.fleets[0].size() == 1, "Moving an existing ship replaces its placement")
	check(rules.rotate_ship(1, 12) and rules.fleets[0].size() == 1 and rules.fleets[0][0].cell == 10 and rules.fleets[0][0].vertical, "Rotation keeps an existing ship at its original start")
	for sample in 100:
		var fleet := Rules.random_fleet()
		var cells: Array = []
		for ship in fleet:
			cells.append_array(ship.cells)
		check(fleet.size() == 5 and cells.size() == 17 and cells.all(func(cell: int) -> bool: return cells.count(cell) == 1), "Random fleets contain exactly five non-overlapping ships")
	check(rules.auto_place(1) and rules.auto_place(2), "Both captains may auto-deploy")
	check(rules.view_for(1).fleets[0].size() == 5 and rules.view_for(1).fleets[1].is_empty(), "Private view contains its owner and hides the opponent")
	check(rules.view_for(0).fleets == [[], []], "Public view hides both fleets during setup")
	var view: Dictionary = rules.view_for(1)
	view.fleets[0][0].cells.clear()
	check(not rules.fleets[0][0].cells.is_empty(), "Snapshots are deep copies")
	check(rules.lock_fleet(1) and rules.phase == "setup" and not rules.clear_fleet(1), "Readiness locks the fleet while waiting for the opponent")
	check(not rules.rotate_ship(1, rules.fleets[0][0].cell), "Ready fleets cannot rotate while waiting")
	check(rules.lock_fleet(2) and rules.phase == "battle" and rules.turn == 1, "Both fleets ready begins the first battle")
	check(not rules.place_ship(2, 0, 0, false) and not rules.auto_place(2), "Deployed fleets cannot change during battle")
	check(not rules.rotate_ship(2, rules.fleets[1][0].cell), "Ships cannot rotate during battle")
	check(not rules.fire(2, 0) and not rules.fire(1, 100), "Turn and target bounds are enforced")
	var ship: Dictionary = rules.fleets[1][0]
	check(rules.fire(1, ship.cells[0]) and rules.last_shot.result == 2 and rules.turn == 2, "Hits alternate turns")
	var misses := range(100).filter(func(cell: int) -> bool: return not rules.fleets[0].any(func(p: Dictionary) -> bool: return p.cells.has(cell)))
	rules.fire(2, misses[0])
	check(rules.last_shot.result == 1 and rules.turn == 1, "Misses alternate turns and leave a white peg")
	revision = rules.revision
	check(not rules.fire(1, ship.cells[0]) and rules.revision == revision, "A fired square cannot be targeted twice")
	for index in range(1, ship.cells.size()):
		rules.fire(1, ship.cells[index])
		if index < ship.cells.size() - 1:
			rules.fire(2, misses[index])
	check(rules.last_shot.result == 3 and rules.sunk_fleet(2).size() == 1 and rules.view_for(0).fleets[1].size() == 1, "Only a completely sunk ship becomes public")
	check(rules.remaining_lengths(1).size() == 4, "AI receives only publicly known remaining ship lengths")
	for level in 3:
		var simulation := Rules.new()
		simulation.auto_place(1)
		simulation.auto_place(2)
		simulation.lock_fleet(1)
		simulation.lock_fleet(2)
		for step in 200:
			if simulation.outcome != 0:
				break
			var seat: int = simulation.turn
			var known: Array = simulation.shots[seat - 1].duplicate()
			var target := Rules.computer_target(known, simulation.remaining_lengths(seat), level)
			check(target >= 0 and known[target] == 0 and known == simulation.shots[seat - 1], "Computer targets a fresh square without mutating known state")
			check(simulation.fire(seat, target), "Computer plays a legal complete battle")
		check(simulation.outcome in [1, 2] and simulation.session_wins[simulation.outcome - 1] == 1 and simulation.history.size() == 1, "One completed battle is one immediate win")
		check(not simulation.fire(simulation.turn, 99), "No shots are accepted after victory")
		check(simulation.play_again() and simulation.starter == 2 and simulation.round_number == 2 and simulation.fleets == [[], []] and simulation.session_wins.count(1) == 1, "Replay alternates first shots and keeps wins/history")
	var known: Array = []
	known.resize(100)
	known.fill(0)
	known[44] = 2
	for level in [Rules.Difficulty.MEDIUM, Rules.Difficulty.HARD]:
		check(Rules.computer_target(known, [2], level) in [34, 43, 45, 54], "Hunting AI follows an unresolved hit without accessing hidden ships")

	var host := _host([PHONE, SECOND])
	check(host.sounds.size() == 6 and host.sounds.cannon.bus == "Effects", "All six local cues use the shared Effects bus")
	check(not host.host_plays and host.seats.size() == 2 and private_states.size() == 2, "Two-phone sessions send each admitted captain a private view")
	for value in [null, true, "0", -1, 100, 1.5, INF, NAN, {}, []]:
		_send(host, "phone", "place", {"ship": 0, "cell": value, "vertical": false})
		_send(host, "phone", "place", {"ship": value, "cell": 0, "vertical": false})
		_send(host, "phone", "rotate", {"cell": value})
	_send(host, "phone", "place", {"ship": 0, "cell": 0, "vertical": "false"})
	_send(host, "intruder", "auto", {"profile_id": "phone", "score": 99})
	_send(host, "phone", "auto", {"revision": "0"})
	check(host.rules.fleets == [[], []] and awards == 0, "Malformed, spoofed and stale requests cannot deploy or award points")
	_send(host, "phone", "rotate", {"cell": 0})
	check(host.rules.fleets == [[], []] and host.rules.revision == 0, "A controller rotation on empty water cannot place a ship")
	_send(host, "phone", "place", {"ship": 0, "cell": 0, "vertical": false})
	_send(host, "phone", "rotate", {"cell": 2, "ship": 4, "vertical": false})
	check(host.rules.fleets[0].size() == 1 and host.rules.fleets[0][0].ship == 0 and host.rules.fleets[0][0].cell == 0 and host.rules.fleets[0][0].vertical and private_states.second.fleets[0].is_empty(), "Host rotation derives the ship and orientation privately from the held square")
	revision = host.rules.revision
	_send(host, "phone", "rotate", {"cell": 0, "revision": revision - 1})
	check(host.rules.revision == revision, "Stale rotations cannot flip an accepted ship again")
	_send(host, "phone", "clear")
	_send(host, "phone", "auto")
	_send(host, "second", "auto")
	check(private_states.phone.fleets[0].size() == 5 and private_states.phone.fleets[1].is_empty() and private_states.second.fleets[0].is_empty() and private_states.second.fleets[1].size() == 5, "Each network recipient receives only its own unsunk fleet")
	check(host.boards[0].fleet.is_empty() and host.boards[1].fleet.is_empty() and broadcasts == 0, "Two-phone host display and broadcasts contain no secret ships")
	check(not JSON.stringify(private_states).contains("private-token") and not JSON.stringify(private_states).contains("private-profile"), "Snapshots omit identity secrets")
	_send(host, "phone", "ready")
	_send(host, "second", "ready")
	revision = host.rules.revision
	host.player_disconnected("second")
	_send(host, "phone", "fire", {"cell": 0})
	check(host.rules.revision == revision and private_states.phone.paused, "Disconnect pauses authoritative input")
	host.player_reconnected(SECOND)
	check(not private_states.phone.paused and private_states.second.fleets[1].size() == 5, "Reconnect restores the same private fleet and seat")
	_finish_host(host, 1)
	check(host.rules.outcome == 1 and host.rules.session_wins == [1, 0] and awards == 1 and reports == 2, "A two-phone battle awards exactly one point and one result per player")
	host._publish()
	host._publish()
	_send(host, "phone", "sync")
	check(awards == 1 and reports == 2, "Sync and duplicate publications never re-award results")
	check(private_states.second.fleets[0].size() == 5 and host.replay_button.visible, "Victory reveals the completed fleets and one replay control")
	_send(host, "second", "play_again")
	check(host.rules.phase == "setup" and host.rules.starter == 2 and host.rules.session_wins == [1, 0] and host.rules.history.size() == 1 and private_states.phone.fleets == [[], []], "Replay keeps session totals and removes old fleets and effects")
	_send(host, "phone", "auto")
	_send(host, "second", "auto")
	_send(host, "phone", "ready")
	_send(host, "second", "ready")
	_finish_host(host, 2)
	check(awards == 2 and reports == 4 and host.rules.session_wins == [1, 1], "The replayed battle records a fresh, single result")
	host.shutdown_game()
	host.queue_free()
	await process_frame
	var one_phone := _host([PHONE])
	check(not one_phone.host_plays and one_phone.rules.ready == [false, true], "One phone defaults to a privately deployed Hard computer")
	revision = one_phone.rules.revision
	one_phone._select_mode(1)
	check(one_phone.host_plays and one_phone._seat_for("phone") == 2 and one_phone.rules.ready == [false, false], "Host-versus-phone maps the controller to seat two")
	_send(one_phone, "phone", "auto", {"revision": revision})
	check(one_phone.rules.fleets == [[], []], "Changing opponents invalidates old setup requests")
	one_phone._setup_action(1, "auto")
	_send(one_phone, "phone", "auto")
	one_phone._setup_action(1, "ready")
	_send(one_phone, "phone", "ready")
	one_phone._select_mode(0)
	check(one_phone.host_plays, "Opponent selection stays locked after deployment")
	_finish_host(one_phone, 2)
	check(awards == 2 and reports == 4, "Host-versus-phone wins leave saved standings unchanged")
	one_phone.shutdown_game()
	one_phone.queue_free()
	await process_frame
	var solo := _host([])
	check(solo.host_plays and solo.seats[0].display_name == "Admiral", "Solo uses the existing host identity")
	solo._setup_action(1, "auto")
	solo._setup_action(1, "ready")
	solo.seats[1].id = "fixture"
	solo.ai_timer.stop()
	_finish_host(solo, 1)
	check(awards == 2 and reports == 4 and solo.rules.session_wins == [1, 0], "Solo battles keep session wins without awarding saved scores")
	revision = solo.rules.revision
	solo._select_difficulty(2)
	check(solo.rules.phase == "setup" and solo.rules.session_wins == [0, 0] and solo.rules.history.is_empty() and solo.rules.revision > revision, "Solo difficulty resets the session and invalidates stale input")
	solo.shutdown_game()
	solo.queue_free()
	await process_frame
	var catalog := GameCatalog.new()
	var games := catalog.scan().filter(func(game: Dictionary) -> bool: return game.id == "battleship")
	check(games.size() == 1 and games[0].min_players == 1 and games[0].max_players == 2 and games[0].background == "art/command-bridge", "Validated catalog discovers Battleship exactly once with an interchangeable background")
	# Let the mixer release stopped Foley playbacks before headless shutdown.
	await create_timer(0.15).timeout
	print("Battleship: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
