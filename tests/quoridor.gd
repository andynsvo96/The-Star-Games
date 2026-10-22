extends SceneTree

const Rules = preload("res://Games/quoridor/host/rules.gd")
const Host = preload("res://Games/quoridor/host/main.tscn")
const LOCAL := {"id": "local-host", "display_name": "Host", "color": "#25b3ab"}
const PHONE := {"id": "phone", "display_name": "Phone [literal]", "color": "#e8794b"}
const SECOND := {"id": "second", "display_name": "Second", "color": "#2463eb"}
const THIRD := {"id": "third", "display_name": "Third", "color": "#8f62cc"}
const FOURTH := {"id": "fourth", "display_name": "Fourth", "color": "#e3b831"}
var checks := 0
var failures := 0
var awards := 0
var reports := 0
var snapshot: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)


func _host(players: Array, reduced := true) -> Node:
	var host := Host.instantiate()
	root.add_child(host)
	var context := GameSessionContext.new("quoridor", players, LOCAL, not players.is_empty())
	context.reduced_motion = reduced
	host.settings_store = preload("res://tests/game_settings_fixture.gd").new()
	host.initialize_session(context)
	host.controller_state_updated.connect(func(state: Dictionary) -> void: snapshot = state)
	host.points_awarded.connect(func(_id: String, amount: int) -> void: awards += amount)
	host.result_reported.connect(func(_id: String, _won: bool) -> void: reports += 1)
	for sound in host.sounds.values():
		sound.volume_db = -80
	host.start_game()
	return host


func _send(host: Node, id: String, input: Dictionary, revision: Variant = null) -> void:
	var message := input.duplicate()
	message.revision = host.rules.revision if revision == null else revision
	host.handle_controller_message(id, message)


func _run() -> void:
	seed(47)
	var rules := Rules.new()
	check(rules.pawns == [76, 4] and rules.remaining == [10, 10] and rules.turn == 1, "Two centered pawns and ten walls each")
	check(rules.legal_moves().size() == 3 and rules.legal_moves().has(67), "Three orthogonal opening moves")
	check(rules.legal_walls().size() == 128, "All 128 opening wall placements are legal")
	check(not rules.move(67, 2) and not rules.move(66, 1) and not rules.move(81, 1), "Wrong player, diagonal and out-of-bounds moves rejected")
	check(not rules.play_again() and rules.revision == 0, "Active games cannot be abandoned through replay")
	check(rules.move(67, 1) and rules.turn == 2 and rules.revision == 1, "A pawn move consumes exactly one turn")
	check(rules.place_wall(6, 4, "h", 2) and rules.remaining == [10, 9] and rules.turn == 1, "A two-cell wall uses the correct stock and changes turn")
	check(not rules.legal_moves().has(58), "Horizontal walls block both covered edges")
	var blocked := Rules.graph_for([{"row": 3, "col": 3, "orientation": "v"}])
	check(blocked[30 * 4 + 1] == -1 and blocked[39 * 4 + 1] == -1 and blocked[31 * 4 + 3] == -1, "Vertical walls block both rows in both directions")
	check(blocked[29 * 4 + 1] == 30 and blocked[48 * 4 + 1] == 49, "A wall does not extend beyond its two edges")
	var walls := [{"row": 3, "col": 3, "orientation": "h"}]
	for candidate in [[3, 3, "h"], [3, 2, "h"], [3, 4, "h"], [3, 3, "v"], [-1, 3, "h"], [8, 3, "h"], [3, 8, "v"], [3, 3, "bad"]]:
		check(not Rules.wall_fits(walls, candidate[0], candidate[1], candidate[2]), "Overlap, crossing, bounds and unknown orientations rejected")
	check(Rules.wall_fits(walls, 3, 5, "h") and Rules.wall_fits(walls, 4, 3, "v"), "End-to-end walls and non-crossing corners remain legal")
	# Enclosing a corner pawn, or completing a barrier across the whole board,
	# must fail even if walls do not geometrically overlap.
	var corner := Rules.new()
	corner.pawns = [0, 76]
	corner.walls = [{"row": 0, "col": 0, "orientation": "h"}]
	check(not corner.place_wall(0, 0, "v", 1), "Crossing a wall is rejected without consuming stock")
	corner.pawns = [9, 4]
	corner.walls = [{"row": 0, "col": 0, "orientation": "h"}, {"row": 1, "col": 0, "orientation": "h"}]
	check(not Rules.wall_legal(Rules.graph_for(corner.walls), corner.pawns, corner.walls, 0, 0, "v"), "Geometric crossings remain invalid in path checks")
	var sealed := [{"row": 0, "col": 0, "orientation": "h"}, {"row": 0, "col": 2, "orientation": "h"}, {"row": 0, "col": 4, "orientation": "h"}, {"row": 0, "col": 6, "orientation": "h"}, {"row": 0, "col": 7, "orientation": "v"}, {"row": 2, "col": 7, "orientation": "v"}]
	check(Rules.distance(Rules.graph_for(sealed), 76, 1) >= 0 and Rules.wall_fits(sealed, 3, 7, "h") and not Rules.wall_legal(Rules.graph_for(sealed), [76, 13], sealed, 3, 7, "h"), "Last escape cannot be sealed despite a non-overlapping wall")
	var mirrored: Array = sealed.map(func(wall: Dictionary) -> Dictionary: return {"row": 7 - wall.row, "col": wall.col, "orientation": wall.orientation})
	check(Rules.distance(Rules.graph_for(mirrored), 4, 2) >= 0 and not Rules.wall_legal(Rules.graph_for(mirrored), [67, 4], mirrored, 4, 7, "h"), "Path preservation protects both goal directions")
	var graph := Rules.graph_for([])
	check(Rules.distance(graph, 76, 1) == 8 and Rules.distance(graph, 4, 2) == 8, "Empty-board distances reach the opposite edge")
	check(Rules.pawn_moves(graph, [40, 31], 1).has(22) and not Rules.pawn_moves(graph, [40, 31], 1).has(30), "Straight jumps take priority over diagonal side jumps")
	var jump_wall := Rules.graph_for([{"row": 2, "col": 3, "orientation": "h"}])
	var moves := Rules.pawn_moves(jump_wall, [40, 31], 1)
	check(moves.has(30) and moves.has(32) and not moves.has(22) and not moves.has(31), "Blocked straight jump permits both side squares, never the occupied square")
	check(Rules.pawn_moves(graph, [13, 4], 1).has(3) and Rules.pawn_moves(graph, [13, 4], 1).has(5), "The board edge behind a pawn permits diagonal jumps")
	var separated := Rules.graph_for([{"row": 3, "col": 3, "orientation": "h"}])
	check(not Rules.pawn_moves(separated, [40, 31], 1).has(22), "Cannot jump through a wall between the pawns")
	for side in [1, 2]:
		var victory := Rules.new()
		victory.turn = side
		victory.pawns = [9, 71]
		check(victory.move(0 if side == 1 else 80, side) and victory.outcome == side, "Every goal-edge square awards an immediate win")
		check(victory.session_wins[side - 1] == 1 and victory.history.size() == 1 and victory.legal_moves().is_empty() and victory.legal_walls().is_empty(), "Completed races stop input and count once")
		check(not victory.move(10, side) and not victory.place_wall(1, 1, "h", side), "No input after a win")
		check(victory.play_again() and victory.starter == 2 and victory.turn == 2 and victory.pawns == [76, 4] and victory.remaining == [10, 10] and victory.session_wins[side - 1] == 1 and victory.history.size() == 1, "Replay alternates starters and preserves participant wins/history")
	var stock := Rules.new()
	stock.remaining[0] = 0
	check(stock.legal_walls().is_empty() and not stock.place_wall(1, 1, "h", 1) and stock.move(67, 1), "Exhausted walls still permit pawn movement")
	for level in 3:
		var ai := Rules.new()
		var before := ai.position()
		var began := Time.get_ticks_msec()
		var input := Rules.computer_move(before, level)
		print("Quoridor AI %d: %d ms" % [level, Time.get_ticks_msec() - began])
		check(ai.position() == before and (ai.move(input.get("to", -1), 1) if input.action == "move" else ai.place_wall(input.row, input.col, input.orientation, 1)), "AI returns a legal action without mutating its input")
		ai = Rules.new()
		ai.pawns = [13, 4]
		input = Rules.computer_move(ai.position(), level)
		check(input.action == "move" and input.to in [3, 5], "Every AI level takes an available winning side jump")
	for level in 3:
		var race := Rules.new()
		for ply in 300:
			if race.outcome:
				break
			var input := Rules.computer_move(race.position(), level)
			check(race.move(input.get("to", -1), race.turn) if input.action == "move" else race.place_wall(input.row, input.col, input.orientation, race.turn), "AI self-play actions remain legal")
		print("AI race %d: outcome=%d turns=%d pawns=%s stock=%s" % [level, race.outcome, race.revision, race.pawns, race.remaining])
		check(race.outcome in [1, 2] and race.history.size() == 1, "Every AI difficulty completes a full race")
	# Random legal play checks graph symmetry, conservation, paths, and reachability.
	for game in 6:
		var random_game := Rules.new()
		for ply in 100:
			if random_game.outcome:
				break
			var legal_moves: Array = random_game.legal_moves()
			var legal_walls: Array = random_game.legal_walls()
			check(not legal_moves.is_empty(), "Active positions always permit movement")
			if not legal_walls.is_empty() and randf() < .28:
				var wall: Dictionary = legal_walls.pick_random()
				check(random_game.place_wall(wall.row, wall.col, wall.orientation, random_game.turn), "Generated legal walls are accepted")
			else:
				check(random_game.move(legal_moves.pick_random(), random_game.turn), "Generated pawn moves are accepted")
			graph = Rules.graph_for(random_game.walls)
			check(random_game.remaining[0] + random_game.remaining[1] + random_game.walls.size() == 20 and random_game.pawns[0] != random_game.pawns[1], "Wall stock is conserved and pawns never overlap")
			check(Rules.distance(graph, random_game.pawns[0], 1) >= 0 and Rules.distance(graph, random_game.pawns[1], 2) >= 0, "Both goal routes survive every accepted wall")
	var solo = _host([])
	check(solo.host_plays and solo.sounds.size() == 3 and solo.sounds.wall.bus == "Effects", "Solo host and offline shared Effects audio initialize")
	solo._host_cell(67)
	for frame in 600:
		await process_frame
		if solo.rules.turn == 1:
			break
	check(solo.rules.revision == 2 and solo.rules.turn == 1, "Solo worker replies and returns control")
	solo._host_cell(solo.rules.legal_moves()[0])
	var old_revision: int = solo.rules.revision
	solo._select_difficulty(2)
	check(solo.rules.revision == old_revision and not solo.apply_button.disabled, "Difficulty stays staged until Apply")
	solo._apply_settings()
	await create_timer(.6).timeout
	check(solo.rules.pawns == [76, 4] and solo.rules.revision > old_revision and solo.rules.history.is_empty(), "Difficulty reset cancels stale AI and advances revision")
	solo.shutdown_game()
	solo.queue_free()
	await process_frame
	var one = _host([PHONE])
	old_revision = one.rules.revision
	one._select_host(true)
	one._apply_settings()
	_send(one, PHONE.id, {"action": "move", "to": 67}, old_revision)
	_send(one, LOCAL.id, {"action": "move", "to": 67})
	_send(one, PHONE.id, {"action": "move", "to": 67})
	check(one.rules.pawns == [76, 4], "Stale revision, host impersonation, and wrong phone seat rejected")
	one._host_cell(67)
	check(one.host_plays and not one.player_choice.disabled, "Host settings remain available during play")
	one.player_disconnected(PHONE.id)
	_send(one, PHONE.id, {"action": "move", "to": 13})
	check(snapshot.paused and one.rules.pawns[1] == 4, "Disconnect pauses play with original seats")
	one.player_joined(PHONE)
	check(not snapshot.paused and snapshot.pawns[0] == 67 and snapshot.players[1].id == PHONE.id, "Reconnect restores the authoritative board and identity")
	_send(one, PHONE.id, {"action": "move", "to": 13})
	check(one.rules.pawns[1] == 13 and awards == 0 and reports == 0, "Host-versus-phone uses session scores only")
	one.shutdown_game()
	one.queue_free()
	await process_frame
	var two = _host([PHONE, SECOND])
	for bad in [-1, 81, 1.5, true, "67", {}, null, INF, NAN]:
		_send(two, PHONE.id, {"action": "move", "to": bad})
		_send(two, PHONE.id, {"action": "wall", "row": bad, "col": 0, "orientation": "h"})
	for bad in [-1, 0.5, true, "0", {}, INF, NAN]:
		_send(two, PHONE.id, {"action": "move", "to": 67}, bad)
	for bad in [null, false, "x", 1, {}]:
		_send(two, PHONE.id, {"action": "wall", "row": 0, "col": 0, "orientation": bad})
	_send(two, "intruder", {"action": "move", "to": 67})
	check(two.rules.revision == 0 and two.rules.walls.is_empty(), "Malformed and unauthorized inputs preserve state")
	_send(two, PHONE.id, {"action": "wall", "row": 4, "col": 4, "orientation": "h"})
	_send(two, SECOND.id, {"action": "wall", "row": 4, "col": 4, "orientation": "v"})
	check(two.rules.revision == 1 and two.rules.remaining == [9, 10], "Controller wall validation rejects crossing without consuming a turn")
	two.rules.pawns = [9, 71]
	two.rules.turn = 1
	two.rules.revision += 1
	two._publish()
	_send(two, PHONE.id, {"action": "move", "to": 0})
	_send(two, PHONE.id, {"action": "sync"})
	check(awards == 1 and reports == 2 and two.rules.history.size() == 1, "Exactly one saved point and one result per two-phone player")
	check(snapshot.players[0].display_name == PHONE.display_name and not str(snapshot).contains("profile_id"), "Snapshots retain literal names and omit profile authority")
	_send(two, SECOND.id, {"action": "play_again"})
	check(two.rules.turn == 2 and two.rules.session_wins == [1, 0] and two.rules.history.size() == 1, "An admitted player replays while preserving totals")
	two.shutdown_game()
	two.queue_free()
	await process_frame
	var animated = _host([PHONE, SECOND], false)
	_send(animated, PHONE.id, {"action": "move", "to": 67})
	_send(animated, SECOND.id, {"action": "move", "to": 13})
	check(animated.rules.revision == 1 and snapshot.animating, "Host rejects taps during pawn movement")
	while animated._busy():
		await process_frame
	await process_frame
	check(not snapshot.animating and animated.rules.revision == 1, "Movement settles without queuing the rejected tap")
	_send(animated, SECOND.id, {"action": "move", "to": 13})
	check(animated.rules.revision == 2, "Input resumes after motion settles")
	animated.shutdown_game()
	animated.queue_free()
	await process_frame
	var local_motion = _host([PHONE], false)
	local_motion._select_host(true)
	local_motion._apply_settings()
	local_motion._host_cell(67)
	while local_motion._busy() or local_motion.board.busy:
		await process_frame
	_send(local_motion, PHONE.id, {"action": "move", "to": 13})
	while local_motion._busy() or local_motion.board.busy:
		await process_frame
	await process_frame
	check(not local_motion.move_button.disabled and local_motion.board.cells[58].disabled == false, "Native host input returns after both movement clocks settle")
	local_motion.shutdown_game()
	local_motion.queue_free()
	await process_frame
	await _four_players()
	var catalog := GameCatalog.new()
	catalog.scan()
	var found: Array = catalog.games.filter(func(game: Dictionary) -> bool: return game.id == "quoridor")
	check(found.size() == 1 and found[0].min_players == 1 and found[0].max_players == 4 and found[0].background == "art/courtyard", "Validated catalog discovers Quoridor once with up to four phones")
	print("Quoridor: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _four_players() -> void:
	var rules := Rules.new(4)
	check(rules.pawns == [76, 36, 4, 44] and rules.remaining == [5, 5, 5, 5], "Four centered pawns run clockwise with five walls each")
	check(rules.legal_walls().size() == 128, "Four players retain all opening wall placements")
	for side in range(1, 5):
		check(rules.turn == side and rules.move([67, 37, 13, 43][side - 1], side), "All four players move in clockwise order")
	check(rules.turn == 1, "Fourth turn wraps back to the first player")
	var graph := Rules.graph_for([])
	for side in range(1, 5):
		check(Rules.distance(graph, [76, 36, 4, 44][side - 1], side, 4) == 8, "Every seat targets its own opposite edge")
	var moves := Rules.pawn_moves(graph, [40, 31, 22, 32], 1)
	check(moves.has(30) and not moves.has(22) and not moves.has(13) and not moves.has(31) and not moves.has(32), "A pawn behind an opponent allows only unoccupied side jumps, never two-pawn jumps")
	check(Rules.pawn_moves(graph, [40, 31, 22, 30], 1).has(32), "Either free side can be used around a blocked pawn")
	check(Rules.pawn_moves(graph, [40, 31, 39, 41], 1).has(22), "A single adjacent pawn can still be jumped in four-player play")
	var sealed := [{"row": 0, "col": 0, "orientation": "h"}, {"row": 0, "col": 2, "orientation": "h"}, {"row": 0, "col": 4, "orientation": "h"}, {"row": 0, "col": 6, "orientation": "h"}, {"row": 0, "col": 7, "orientation": "v"}, {"row": 2, "col": 7, "orientation": "v"}]
	# Mirror the existing sealed pocket to trap seat 3 on its route south.
	var mirrored: Array = sealed.map(func(wall: Dictionary) -> Dictionary: return {"row": 7 - wall.row, "col": wall.col, "orientation": wall.orientation})
	var positions := [67, 36, 67, 44]
	positions[0] = 9
	check(Rules.wall_fits(mirrored, 4, 7, "h") and not Rules.wall_legal(Rules.graph_for(mirrored), positions, mirrored, 4, 7, "h"), "A legal-shaped wall cannot remove the third player's route")
	# Rotate that pocket clockwise to trap seat 4 on its route west.
	var rotated: Array = mirrored.map(func(wall: Dictionary) -> Dictionary: return {"row": wall.col, "col": 7 - wall.row, "orientation": "v" if wall.orientation == "h" else "h"})
	check(Rules.wall_fits(rotated, 7, 3, "v") and not Rules.wall_legal(Rules.graph_for(rotated), [76, 36, 4, 37], rotated, 7, 3, "v"), "Wall path checks protect the fourth player's west goal")
	for side in range(1, 5):
		var victory := Rules.new(4)
		victory.turn = side
		victory.pawns = [9, 43, 71, 37]
		var destination: int = [0, 44, 80, 36][side - 1]
		check(victory.move(destination, side) and victory.outcome == side and victory.session_wins[side - 1] == 1, "All four goal directions finish with one win")
		for round_index in 4:
			if round_index > 0:
				victory.outcome = side
			check(victory.play_again() and victory.turn == (round_index + 1) % 4 + 1 and victory.remaining == [5, 5, 5, 5], "Four-player replay rotates the starter and restores five walls")
		check(victory.session_wins[side - 1] == 1 and victory.history.size() == 1, "Replay preserves four-player wins and history")
	for level in 3:
		for side in range(1, 5):
			var ai := Rules.new(4)
			ai.turn = side
			var before := ai.position()
			var input := Rules.computer_move(before, level)
			check(ai.position() == before and (ai.move(input.get("to", -1), side) if input.action == "move" else ai.place_wall(input.row, input.col, input.orientation, side)), "Each AI level produces legal actions from every seat")
			ai = Rules.new(4)
			ai.turn = side
			ai.pawns = [9, 43, 71, 37]
			input = Rules.computer_move(ai.position(), level)
			check(input.action == "move" and Rules.at_goal(input.to, side, 4), "Every AI seat takes its immediate goal")
	for level in 3:
		var race := Rules.new(4)
		for ply in 400:
			if race.outcome:
				break
			var input := Rules.computer_move(race.position(), level)
			check(race.move(input.get("to", -1), race.turn) if input.action == "move" else race.place_wall(input.row, input.col, input.orientation, race.turn), "Four-seat AI self-play always uses legal actions")
			var route := Rules.graph_for(race.walls)
			for index in 4:
				check(Rules.distance(route, race.pawns[index], index + 1, 4) >= 0, "Every AI wall preserves all four routes")
			check(race.remaining.reduce(func(total: int, stock: int) -> int: return total + stock, 0) + race.walls.size() == 20 and race.pawns.size() == 4 and not race.pawns.any(func(cell: int) -> bool: return race.pawns.count(cell) > 1), "Four-seat play conserves twenty walls and keeps all pawns distinct")
		print("Four-seat AI race %d: outcome=%d turns=%d" % [level, race.outcome, race.revision])
		check(race.outcome in [1, 2, 3, 4] and race.history.size() == 1, "Every AI difficulty completes a four-player race")
	var three = _host([PHONE, SECOND, THIRD])
	check(three.seats.size() == 4 and three.computer_count == 1 and three.seats[3].computer, "Three phones default to four seats with one computer")
	for index in 3:
		_send(three, [PHONE.id, SECOND.id, THIRD.id][index], {"action": "move", "to": [67, 37, 13][index]})
	for frame in 1200:
		await process_frame
		if three.rules.turn == 1:
			break
	check(three.rules.revision == 4 and three.rules.turn == 1 and three.rules.pawns.size() == 4, "The fourth-seat AI acts and returns control to the first phone")
	three._select_players(0)
	check(three.rules.pawns.size() == 4 and not three.apply_button.disabled, "Changing player count remains staged")
	var old_revision: int = three.rules.revision
	three._apply_settings()
	check(three.rules.pawns.size() == 2 and three.seats.size() == 2 and three.rules.revision > old_revision and three.rules.remaining == [10, 10], "Apply switches to two seats and rejects stale state")
	_send(three, THIRD.id, {"action": "move", "to": 67})
	check(three.rules.revision == old_revision + 1, "Unseated phones are spectators and cannot move")
	three.player_disconnected(THIRD.id)
	check(three.missing.is_empty(), "Spectator disconnects do not pause active seats")
	three.player_joined(THIRD)
	three.shutdown_game()
	three.queue_free()
	await process_frame
	var solo = _host([])
	solo._select_players(1)
	solo._apply_settings()
	check(solo.host_plays and solo.computer_count == 3 and solo.seats.map(func(player: Dictionary) -> String: return player.id).size() == 4, "Solo can use three distinct AI opponents")
	check(solo.seats[1].id != solo.seats[2].id and solo.seats[2].id != solo.seats[3].id, "Computers have distinct stable identities")
	solo._host_cell(67)
	old_revision = solo.rules.revision
	solo._select_difficulty(0)
	solo._apply_settings()
	await create_timer(.8).timeout
	check(solo.rules.revision == old_revision + 1 and solo.rules.pawns == [76, 36, 4, 44] and solo.rules.turn == 1, "Applying settings invalidates pending multi-seat computer work")
	solo._host_cell(67)
	for frame in 1800:
		await process_frame
		if solo.rules.turn == 1:
			break
	check(solo.rules.revision == old_revision + 5 and solo.rules.turn == 1, "Three consecutive computer turns complete without a queue or deadlock")
	solo.shutdown_game()
	solo.queue_free()
	await process_frame
	var four = _host([PHONE, SECOND, THIRD, FOURTH])
	check(four.seats.size() == 4 and four.computer_count == 0 and four.rules.session_wins == [0, 0, 0, 0], "Four phones default to a human table")
	four._select_computers(2)
	four._select_difficulty(0)
	four._apply_settings()
	check(four.computer_count == 2 and four.seats[0].id == PHONE.id and four.seats[1].id == SECOND.id and four.seats[2].computer, "Host chooses the human/AI split without mutating the launcher roster")
	var before_awards := awards
	var before_reports := reports
	four.rules.pawns = [9, 36, 4, 44]
	four.rules.revision += 1
	four._publish()
	_send(four, PHONE.id, {"action": "move", "to": 0})
	check(awards == before_awards and reports == before_reports, "Mixed human/AI races keep session scores only")
	four._select_computers(0)
	four._apply_settings()
	check(four.rules.history.is_empty() and four.rules.session_wins == [0, 0, 0, 0], "Applying a new lineup clears session history and wins")
	old_revision = four.rules.revision
	four.player_disconnected(THIRD.id)
	_send(four, PHONE.id, {"action": "move", "to": 67})
	check(snapshot.paused and four.rules.revision == old_revision and four.apply_button.disabled, "Any seated human disconnect pauses input and settings")
	four.player_joined(THIRD)
	check(not snapshot.paused and snapshot.players[2].id == THIRD.id and snapshot.remaining == [5, 5, 5, 5], "Third player reconnect restores seat and stock")
	for index in 4:
		_send(four, [PHONE.id, SECOND.id, THIRD.id, FOURTH.id][index], {"action": "move", "to": [67, 37, 13, 43][index]})
	check(four.rules.turn == 1 and four.rules.pawns == [67, 37, 13, 43], "Every phone authorizes its own four-player move")
	four.rules.pawns = [67, 37, 13, 37 + 9]
	four.rules.turn = 4
	four.rules.revision += 1
	four._publish()
	_send(four, FOURTH.id, {"action": "move", "to": 45})
	_send(four, FOURTH.id, {"action": "sync"})
	check(four.rules.outcome == 4 and awards == before_awards + 1 and reports == before_reports + 4, "A four-phone winner records one saved point and four results exactly once")
	_send(four, THIRD.id, {"action": "play_again"})
	check(four.rules.turn == 2 and four.rules.session_wins == [0, 0, 0, 1] and four.rules.remaining == [5, 5, 5, 5], "Four-player controller replay preserves wins and rotates the starter")
	four.shutdown_game()
	four.queue_free()
	await process_frame
	var animated = _host([PHONE, SECOND, THIRD, FOURTH], false)
	for index in 4:
		_send(animated, [PHONE.id, SECOND.id, THIRD.id, FOURTH.id][index], {"action": "move", "to": [67, 37, 13, 43][index]})
		if index < 3:
			while animated._busy():
				await process_frame
	check(animated.board.busy and animated.rules.revision == 4 and snapshot.animating, "The fourth native pawn animates and locks the next turn")
	_send(animated, PHONE.id, {"action": "move", "to": 58})
	check(animated.rules.revision == 4, "Four-player motion discards the next player's tap")
	while animated._busy():
		await process_frame
	_send(animated, PHONE.id, {"action": "move", "to": 58})
	check(animated.rules.revision == 5, "Four-player input resumes after both host movement clocks settle")
	animated.shutdown_game()
	animated.queue_free()
	await process_frame
