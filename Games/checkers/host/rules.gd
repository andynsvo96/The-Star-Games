extends RefCounted

# American / English checkers. Red begins at the bottom and moves up.
# Piece values: empty, red man, black man, red king, black king.
enum Difficulty { EASY, MEDIUM, HARD }
const DRAW_TURNS := 80
const SEARCH_NODES := 12000
var board: Array = []
var turn := 1
var starter := 1
var forced_from := -1
var force_jump := true
var revision := 0
var outcome := 0
var champion := 0
var wins: Array = [0, 0]
var round_number := 1
var match_number := 1
var session_wins: Array = [0, 0]
var match_wins: Array = [0, 0]
var draws := 0
var history: Array = []
var quiet_turns := 0
var positions: Dictionary = {}
var last_move: Dictionary = {}
var draw_reason := ""
var result_reason := ""
var clock_seconds := 0.0
var remaining := [0.0, 0.0]
var clock_started := false


func _init() -> void:
	_reset_board()


static func owner(piece: int) -> int:
	return 0 if piece == 0 else (piece - 1) % 2 + 1


static func playable(cell: int) -> bool:
	return cell >= 0 and cell < 64 and (int(cell / 8) + cell % 8) % 2 == 1


static func _steps(cells: Array, cell: int, captures_only: bool) -> Array:
	var moves: Array = []
	var piece: int = cells[cell]
	var mark := owner(piece)
	var directions: Array = [-1, 1] if piece >= 3 else [-1 if mark == 1 else 1]
	var row := int(cell / 8)
	var column := cell % 8
	for dy in directions:
		for dx in [-1, 1]:
			var y: int = row + dy
			var x: int = column + dx
			if y < 0 or y >= 8 or x < 0 or x >= 8:
				continue
			var neighbor: int = y * 8 + x
			if cells[neighbor] == 0 and not captures_only:
				moves.append({"from": cell, "to": neighbor, "capture": -1})
			elif owner(cells[neighbor]) == 3 - mark:
				y += dy
				x += dx
				if y >= 0 and y < 8 and x >= 0 and x < 8 and cells[y * 8 + x] == 0:
					moves.append({"from": cell, "to": y * 8 + x, "capture": neighbor})
	return moves


static func available_moves(cells: Array, mark: int, forced := -1, require_jump := true) -> Array:
	if forced >= 0:
		return _steps(cells, forced, true) if playable(forced) and owner(cells[forced]) == mark else []
	var moves: Array = []
	var captures: Array = []
	for cell in 64:
		if playable(cell) and owner(cells[cell]) == mark:
			for step in _steps(cells, cell, false):
				if step.capture >= 0:
					captures.append(step)
				else:
					moves.append(step)
	return captures if require_jump and not captures.is_empty() else captures + moves


func legal_moves() -> Array:
	return [] if outcome != 0 or champion != 0 else available_moves(board, turn, forced_from, force_jump)


func set_force_jump(enabled: bool) -> bool:
	# A started capture chain always finishes with the same piece.
	if forced_from >= 0 or force_jump == enabled:
		return false
	force_jump = enabled
	revision += 1
	positions = {position_key(board, turn): 1}
	return true


static func _promotes(piece: int, destination: int) -> bool:
	return (piece == 1 and destination < 8) or (piece == 2 and destination >= 56)


func move(from_cell: int, to_cell: int, mark: int) -> bool:
	if mark != turn or not playable(from_cell) or not playable(to_cell):
		return false
	var chosen: Dictionary = {}
	for step in legal_moves():
		if step.from == from_cell and step.to == to_cell:
			chosen = step
			break
	if chosen.is_empty():
		return false
	clock_started = clock_seconds > 0
	var piece: int = board[from_cell]
	var promoted := _promotes(piece, to_cell)
	board[from_cell] = 0
	board[to_cell] = piece + 2 if promoted else piece
	if chosen.capture >= 0:
		board[chosen.capture] = 0
	last_move = {"from": from_cell, "to": to_cell, "capture": chosen.capture, "promoted": promoted}
	revision += 1
	# Advancing any man or removing a piece resets the forty-moves-per-side draw.
	if piece < 3 or chosen.capture >= 0:
		quiet_turns = 0
	if chosen.capture >= 0 and not promoted and not _steps(board, to_cell, true).is_empty():
		forced_from = to_cell
		return true
	forced_from = -1
	if piece >= 3 and chosen.capture < 0:
		quiet_turns += 1
	turn = 3 - turn
	if available_moves(board, turn, -1, force_jump).is_empty():
		_finish(mark)
	else:
		var key := position_key(board, turn)
		positions[key] = int(positions.get(key, 0)) + 1
		if positions[key] >= 3:
			draw_reason = "The same position occurred three times."
			_finish(3)
		elif quiet_turns >= DRAW_TURNS:
			draw_reason = "Forty moves per player without a capture or advancing a man."
			_finish(3)
	return true


func _finish(result: int) -> void:
	if outcome != 0:
		return
	outcome = result
	if result == 3:
		draws += 1
	else:
		wins[result - 1] += 1
		session_wins[result - 1] += 1
		champion = result
		match_wins[result - 1] += 1
	history.append({"match": match_number, "round": round_number, "outcome": result, "champion": champion, "reason": result_reason})


func configure_clock(seconds: float) -> bool:
	if not is_finite(seconds) or seconds < 0 or seconds > 86400 or (outcome == 0 and not last_move.is_empty()):
		return false
	clock_seconds = seconds
	remaining = [seconds, seconds]
	clock_started = false
	revision += 1
	return true


func advance_clock(elapsed: float) -> bool:
	if clock_seconds <= 0 or not clock_started or outcome != 0 or elapsed <= 0 or not is_finite(elapsed):
		return false
	remaining[turn - 1] = maxf(0.0, remaining[turn - 1] - elapsed)
	if remaining[turn - 1] > 0:
		return false
	result_reason = "Time expired"
	revision += 1
	_finish(3 - turn)
	return true


func _reset_board() -> void:
	board.resize(64)
	board.fill(0)
	for cell in 64:
		if playable(cell):
			if cell < 24:
				board[cell] = 2
			elif cell >= 40:
				board[cell] = 1
	turn = starter
	forced_from = -1
	outcome = 0
	quiet_turns = 0
	last_move = {}
	draw_reason = ""
	result_reason = ""
	remaining = [clock_seconds, clock_seconds]
	clock_started = false
	positions = {position_key(board, turn): 1}


func next_round() -> bool:
	return play_again()


func play_again() -> bool:
	if outcome == 0:
		return false
	champion = 0
	wins = [0, 0]
	starter = 3 - starter
	round_number += 1
	match_number += 1
	revision += 1
	_reset_board()
	return true


static func position_key(cells: Array, mark: int) -> String:
	return str(cells) + ":" + str(mark)


static func counts(cells: Array, mark: int) -> Dictionary:
	return {"pieces": cells.count(mark) + cells.count(mark + 2), "men": cells.count(mark), "kings": cells.count(mark + 2)}


# Search complete turns so a multiple jump consumes only one search level.
static func _capture_paths(cells: Array, cell: int, path: Array, result: Array) -> void:
	var steps := _steps(cells, cell, true)
	if steps.is_empty():
		result.append({"board": cells, "path": path})
		return
	for step in steps:
		var next := cells.duplicate()
		var piece: int = next[cell]
		next[cell] = 0
		next[step.capture] = 0
		var promoted := _promotes(piece, step.to)
		next[step.to] = piece + 2 if promoted else piece
		var trail := path.duplicate()
		trail.append(step)
		if promoted:
			result.append({"board": next, "path": trail})
		else:
			_capture_paths(next, step.to, trail, result)


static func _turns(cells: Array, mark: int, forced := -1, require_jump := true) -> Array:
	var result: Array = []
	var sources: Dictionary = {}
	for step in available_moves(cells, mark, forced, require_jump):
		if step.capture >= 0:
			sources[step.from] = true
		else:
			var next := cells.duplicate()
			var piece: int = next[step.from]
			next[step.from] = 0
			next[step.to] = piece + 2 if _promotes(piece, step.to) else piece
			result.append({"board": next, "path": [step]})
	for source in sources:
		_capture_paths(cells, source, [], result)
	return result


static func computer_move(cells: Array, mark: int, difficulty: int, forced := -1, require_jump := true) -> Dictionary:
	var options := _turns(cells, mark, forced, require_jump)
	if options.is_empty():
		return {}
	if difficulty == Difficulty.EASY:
		return options.pick_random().path[0].duplicate()
	var depth := 5 if difficulty == Difficulty.HARD else 3
	var best := -1000000
	var choices: Array = []
	# A shared node budget keeps the host responsive on mobile hardware.
	var budget := [SEARCH_NODES]
	for option in options:
		var score := -_search(option.board, 3 - mark, depth - 1, -1000000, 1000000, budget, require_jump)
		if score > best:
			best = score
			choices.clear()
		if score == best:
			choices.append(option.path[0])
	return choices.pick_random().duplicate()


static func _search(cells: Array, mark: int, depth: int, alpha: int, beta: int, budget: Array, require_jump: bool) -> int:
	budget[0] -= 1
	var moves := available_moves(cells, mark, -1, require_jump)
	if moves.is_empty():
		return -100000 - depth
	if depth == 0 or budget[0] <= 0:
		return _evaluate(cells, mark)
	var best := -1000000
	for option in _turns(cells, mark, -1, require_jump):
		var score := -_search(option.board, 3 - mark, depth - 1, -beta, -alpha, budget, require_jump)
		best = maxi(best, score)
		alpha = maxi(alpha, score)
		if alpha >= beta:
			break
	return best


static func _evaluate(cells: Array, mark: int) -> int:
	var value := 0
	for cell in 64:
		var piece: int = cells[cell]
		if piece == 0:
			continue
		var side := owner(piece)
		var row := int(cell / 8)
		var progress := 7 - row if side == 1 else row
		var points := 175 if piece >= 3 else 100 + progress * 5
		if cell % 8 >= 2 and cell % 8 <= 5 and row >= 2 and row <= 5:
			points += 8
		value += points if side == mark else -points
	return value
