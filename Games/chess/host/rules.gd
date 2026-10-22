extends RefCounted

enum Difficulty { EASY, MEDIUM, HARD }
const PAWN := 1
const KNIGHT := 2
const BISHOP := 3
const ROOK := 4
const QUEEN := 5
const KING := 6
const VALUES := [0, 100, 320, 335, 500, 900, 20000]
const NAMES := ["", "pawn", "knight", "bishop", "rook", "queen", "king"]
const PROMOTIONS := [QUEEN, ROOK, BISHOP, KNIGHT]
const DIAGONALS := [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]
const STRAIGHTS := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
const HORSES := [Vector2i(-2, -1), Vector2i(-1, -2), Vector2i(1, -2), Vector2i(2, -1), Vector2i(-2, 1), Vector2i(-1, 2), Vector2i(1, 2), Vector2i(2, 1)]

var position := starting_position()
var revision := 0
var round_number := 1
# Wins belong to participants; white_seat alternates their colors on replay.
var white_seat := 0
var session_wins := [0, 0]
var draws := 0
var history: Array[Dictionary] = []
var outcome := 0
var result_reason := ""
var last_move: Dictionary = {}
var moves: Array[String] = []
var positions: Dictionary = {}
var clock_seconds := 0.0
var remaining := [0.0, 0.0]
var clock_started := false


func _init() -> void:
	positions[position_key(position)] = 1


static func owner(piece: int) -> int:
	return 0 if piece == 0 else (1 if piece > 0 else 2)


static func sign_for(side: int) -> int:
	return 1 if side == 1 else -1


static func square(cell: int) -> String:
	return "%s%d" % [String.chr(97 + cell % 8), 8 - cell / 8]


static func starting_position() -> Dictionary:
	var board: Array = []
	board.resize(64)
	board.fill(0)
	var back := [ROOK, KNIGHT, BISHOP, QUEEN, KING, BISHOP, KNIGHT, ROOK]
	for file in 8:
		board[file] = -back[file]
		board[file + 8] = -PAWN
		board[file + 48] = PAWN
		board[file + 56] = back[file]
	return {"board": board, "turn": 1, "castling": 15, "en_passant": -1, "halfmove": 0}


static func _inside(row: int, file: int) -> bool:
	return row >= 0 and row < 8 and file >= 0 and file < 8


static func attacked(board: Array, cell: int, by: int) -> bool:
	var row := cell / 8
	var file := cell % 8
	var sign := sign_for(by)
	var pawn_row := row + (1 if by == 1 else -1)
	for offset in [-1, 1]:
		if _inside(pawn_row, file + offset) and board[pawn_row * 8 + file + offset] == sign * PAWN:
			return true
	for offset: Vector2i in HORSES:
		var r := row + offset.y
		var f := file + offset.x
		if _inside(r, f) and board[r * 8 + f] == sign * KNIGHT:
			return true
	for offset: Vector2i in DIAGONALS + STRAIGHTS:
		var r := row + offset.y
		var f := file + offset.x
		var distance := 1
		while _inside(r, f):
			var piece: int = board[r * 8 + f]
			if piece != 0:
				if owner(piece) == by:
					var kind := absi(piece)
					if kind == QUEEN or (kind == KING and distance == 1) or (kind == BISHOP and offset.x != 0 and offset.y != 0) or (kind == ROOK and (offset.x == 0 or offset.y == 0)):
						return true
				break
			r += offset.y
			f += offset.x
			distance += 1
	return false


static func in_check(state: Dictionary, side: int) -> bool:
	var cell: int = state.board.find(sign_for(side) * KING)
	return cell < 0 or attacked(state.board, cell, 3 - side)


static func _add_move(list: Array[Dictionary], board: Array, from_cell: int, to_cell: int, capture := -1) -> void:
	var step := {"from": from_cell, "to": to_cell, "promotion": 0, "capture": capture if capture >= 0 else (to_cell if board[to_cell] != 0 else -1)}
	if absi(board[from_cell]) == PAWN and (to_cell < 8 or to_cell >= 56):
		for kind in PROMOTIONS:
			var promoted := step.duplicate()
			promoted.promotion = kind
			list.append(promoted)
	else:
		list.append(step)


static func _pseudo(state: Dictionary) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	var board: Array = state.board
	var side: int = state.turn
	var sign := sign_for(side)
	for cell in 64:
		if owner(board[cell]) != side:
			continue
		var kind := absi(board[cell])
		var row := cell / 8
		var file := cell % 8
		if kind == PAWN:
			var direction := -1 if side == 1 else 1
			var next := row + direction
			if _inside(next, file) and board[next * 8 + file] == 0:
				_add_move(list, board, cell, next * 8 + file)
				if row == (6 if side == 1 else 1) and board[(row + direction * 2) * 8 + file] == 0:
					_add_move(list, board, cell, (row + direction * 2) * 8 + file)
			for offset in [-1, 1]:
				if not _inside(next, file + offset):
					continue
				var target: int = next * 8 + file + offset
				if owner(board[target]) == 3 - side and absi(board[target]) != KING:
					_add_move(list, board, cell, target)
				elif target == state.en_passant and board[target] == 0 and board[row * 8 + file + offset] == -sign * PAWN:
					_add_move(list, board, cell, target, row * 8 + file + offset)
			continue
		var directions: Array = HORSES if kind == KNIGHT else (DIAGONALS if kind == BISHOP else (STRAIGHTS if kind == ROOK else DIAGONALS + STRAIGHTS))
		for offset: Vector2i in directions:
			var r := row + offset.y
			var f := file + offset.x
			while _inside(r, f):
				var target := r * 8 + f
				if owner(board[target]) == side or absi(board[target]) == KING:
					break
				_add_move(list, board, cell, target)
				if board[target] != 0 or kind == KING or kind == KNIGHT:
					break
				r += offset.y
				f += offset.x
		if kind == KING and cell == (60 if side == 1 else 4) and not in_check(state, side):
			for kingside in [true, false]:
				var bit := (1 if kingside else 2) * (1 if side == 1 else 4)
				var rook_cell := cell + (3 if kingside else -4)
				var direction := 1 if kingside else -1
				if state.castling & bit == 0 or board[rook_cell] != sign * ROOK:
					continue
				var clear := true
				for between in range(cell + direction, rook_cell, direction):
					if board[between] != 0:
						clear = false
				# Evaluate transit with the king's starting square vacated.
				var transit := board.duplicate()
				transit[cell] = 0
				if not clear or attacked(transit, cell + direction, 3 - side) or attacked(transit, cell + direction * 2, 3 - side):
					continue
				var step := {"from": cell, "to": cell + direction * 2, "promotion": 0, "capture": -1, "rook_from": rook_cell, "rook_to": cell + direction}
				list.append(step)
	return list


static func apply(state: Dictionary, step: Dictionary) -> Dictionary:
	var next := state.duplicate()
	var board: Array = state.board.duplicate()
	var piece: int = board[step.from]
	board[step.from] = 0
	if step.capture >= 0:
		board[step.capture] = 0
	board[step.to] = sign_for(owner(piece)) * step.promotion if step.promotion else piece
	if step.has("rook_from"):
		board[step.rook_to] = board[step.rook_from]
		board[step.rook_from] = 0
	var rights: int = state.castling
	if absi(piece) == KING:
		rights &= ~(3 if piece > 0 else 12)
	for corner in [0, 7, 56, 63]:
		if step.from == corner or step.to == corner:
			rights &= ~({0: 8, 7: 4, 56: 2, 63: 1}[corner])
	next.board = board
	next.turn = 3 - state.turn
	next.castling = rights
	next.en_passant = (step.from + step.to) / 2 if absi(piece) == PAWN and absi(step.to - step.from) == 16 else -1
	next.halfmove = 0 if absi(piece) == PAWN or step.capture >= 0 else state.halfmove + 1
	return next


static func legal_moves_for(state: Dictionary) -> Array[Dictionary]:
	var legal: Array[Dictionary] = []
	for step in _pseudo(state):
		if not in_check(apply(state, step), state.turn):
			legal.append(step)
	return legal


func legal_moves() -> Array[Dictionary]:
	if outcome:
		var empty: Array[Dictionary] = []
		return empty
	return legal_moves_for(position)


static func position_key(state: Dictionary) -> String:
	# An en-passant target changes repetition identity only if capture is legal.
	var ep: int = state.en_passant
	if ep >= 0 and not legal_moves_for(state).any(func(step: Dictionary) -> bool: return step.capture >= 0 and step.capture != step.to):
		ep = -1
	return str(state.board) + ":%d:%d:%d" % [state.turn, state.castling, ep]


static func dead_position(board: Array) -> bool:
	var minor := 0
	var bishops := 0
	var colors: Dictionary = {}
	for cell in 64:
		var kind := absi(board[cell])
		if kind in [PAWN, ROOK, QUEEN]:
			return false
		if kind == KNIGHT or kind == BISHOP:
			minor += 1
		if kind == BISHOP:
			bishops += 1
			colors[(cell / 8 + cell % 8) % 2] = true
	return minor <= 1 or (minor == bishops and colors.size() == 1)


static func can_mate(board: Array, side: int) -> bool:
	var knights := 0
	var bishops := 0
	var bishop_colors: Dictionary = {}
	var opponent_helpers := false
	for cell in 64:
		var piece: int = board[cell]
		var kind := absi(piece)
		if owner(piece) == side:
			if kind in [PAWN, ROOK, QUEEN]:
				return true
			knights += 1 if kind == KNIGHT else 0
			bishops += 1 if kind == BISHOP else 0
		elif kind != KING and kind != 0:
			opponent_helpers = true
		if kind == BISHOP:
			bishop_colors[(cell / 8 + cell % 8) % 2] = true
	if knights >= 2 or (knights > 0 and bishops > 0):
		return true
	if knights == 1:
		return opponent_helpers
	if bishops > 0:
		if bishop_colors.size() > 1:
			return true
		for piece: int in board:
			if owner(piece) == 3 - side and absi(piece) not in [KING, BISHOP]:
				return true
	return false


func seat_for(side: int) -> int:
	return white_seat if side == 1 else 1 - white_seat


func move(from_cell: int, to_cell: int, side: int, promotion := 0) -> bool:
	if outcome or side != position.turn:
		return false
	for step in legal_moves():
		if step.from != from_cell or step.to != to_cell or step.promotion != promotion:
			continue
		var piece: int = position.board[from_cell]
		var notation: String = "O-O" if step.has("rook_from") and to_cell > from_cell else ("O-O-O" if step.has("rook_from") else ("" if absi(piece) == PAWN else ["", "", "N", "B", "R", "Q", "K"][absi(piece)]) + square(from_cell) + ("x" if step.capture >= 0 else "-") + square(to_cell))
		position = apply(position, step)
		last_move = step.duplicate()
		if promotion:
			notation += "=" + ["", "", "N", "B", "R", "Q", "K"][promotion]
		revision += 1
		clock_started = true
		var key := position_key(position)
		positions[key] = positions.get(key, 0) + 1
		var replies := legal_moves_for(position)
		if replies.is_empty():
			if in_check(position, position.turn):
				notation += "#"
				finish(side, "Checkmate")
			else:
				finish(3, "Stalemate")
		elif dead_position(position.board):
			finish(3, "Insufficient mating material")
		elif positions[key] >= 5:
			finish(3, "Fivefold repetition")
		elif position.halfmove >= 150:
			finish(3, "75-move rule")
		elif in_check(position, position.turn):
			notation += "+"
		moves.append(notation)
		return true
	return false


func finish(winner: int, reason: String) -> bool:
	if outcome or winner not in [1, 2, 3]:
		return false
	outcome = winner
	result_reason = reason
	if winner == 3:
		draws += 1
	else:
		session_wins[seat_for(winner)] += 1
	history.append({"round": round_number, "winner": -1 if winner == 3 else seat_for(winner), "reason": reason})
	return true


func claim_reason() -> String:
	if positions.get(position_key(position), 0) >= 3:
		return "Threefold repetition"
	if position.halfmove >= 100:
		return "50-move rule"
	return ""


func resign(side: int) -> bool:
	if outcome or side not in [1, 2]:
		return false
	revision += 1
	return finish(3 - side, "Resignation") if can_mate(position.board, 3 - side) else finish(3, "Resignation; opponent cannot checkmate")


func claimable_moves() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if outcome:
		return result
	for step in legal_moves():
		var next := apply(position, step)
		if next.halfmove >= 100 or positions.get(position_key(next), 0) >= 2:
			result.append(step)
	return result


func claim_draw(step: Dictionary = {}) -> bool:
	if outcome:
		return false
	var reason := claim_reason()
	if reason.is_empty() and not step.is_empty():
		for legal in claimable_moves():
			if legal.from == step.get("from") and legal.to == step.get("to") and legal.promotion == step.get("promotion", 0):
				var next := apply(position, legal)
				reason = "50-move rule" if next.halfmove >= 100 else "Threefold repetition"
				break
	if reason.is_empty():
		return false
	revision += 1
	return finish(3, reason)


func configure_clock(seconds: float) -> bool:
	if not is_finite(seconds) or seconds < 0 or seconds > 86400 or (outcome == 0 and not moves.is_empty()):
		return false
	clock_seconds = seconds
	remaining = [seconds, seconds]
	clock_started = false
	revision += 1
	return true


func advance_clock(elapsed: float) -> bool:
	if clock_seconds <= 0 or not clock_started or outcome or elapsed <= 0 or not is_finite(elapsed):
		return false
	var side: int = position.turn
	remaining[side - 1] = maxf(0.0, remaining[side - 1] - elapsed)
	if remaining[side - 1] > 0:
		return false
	revision += 1
	return finish(3 - side, "Time expired") if can_mate(position.board, 3 - side) else finish(3, "Time expired; opponent cannot checkmate")


func play_again() -> bool:
	if not outcome:
		return false
	white_seat = 1 - white_seat
	round_number += 1
	revision += 1
	position = starting_position()
	positions = {position_key(position): 1}
	outcome = 0
	result_reason = ""
	last_move = {}
	moves.clear()
	remaining = [clock_seconds, clock_seconds]
	clock_started = false
	return true


static func _evaluate(state: Dictionary) -> int:
	var score := 0
	for cell in 64:
		var piece: int = state.board[cell]
		if piece == 0:
			continue
		var kind := absi(piece)
		var row := cell / 8
		var file := cell % 8
		var center := 7 - absi(file * 2 - 7) / 2 - absi(row * 2 - 7) / 2
		var bonus := center * (8 if kind in [KNIGHT, BISHOP] else 2)
		if kind == PAWN:
			bonus += (6 - row if piece > 0 else row - 1) * 12
		if kind == KING:
			bonus = -center * 4
		score += (VALUES[kind] + bonus) * (1 if piece > 0 else -1)
	return score * sign_for(state.turn)


static func _ordered(state: Dictionary, list: Array[Dictionary]) -> Array[Dictionary]:
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_value: int = (VALUES[absi(state.board[a.capture])] * 10 - VALUES[absi(state.board[a.from])] if a.capture >= 0 else 0) + VALUES[a.promotion]
		var b_value: int = (VALUES[absi(state.board[b.capture])] * 10 - VALUES[absi(state.board[b.from])] if b.capture >= 0 else 0) + VALUES[b.promotion]
		return a_value > b_value
	)
	return list


static func _search(state: Dictionary, depth: int, alpha: int, beta: int, budget: Dictionary, ply: int, quiet := 2) -> int:
	budget.nodes += 1
	if budget.nodes > budget.limit or Time.get_ticks_msec() >= budget.deadline:
		budget.expired = true
		return _evaluate(state)
	var legal := legal_moves_for(state)
	var check := in_check(state, state.turn)
	if legal.is_empty():
		return -100000 + ply if check else 0
	if state.halfmove >= 150 or dead_position(state.board):
		return 0
	if depth <= 0:
		var stand := _evaluate(state)
		if quiet <= 0:
			return stand
		if not check:
			if stand >= beta:
				return stand
			alpha = maxi(alpha, stand)
			legal = legal.filter(func(step: Dictionary) -> bool: return step.capture >= 0 or step.promotion != 0)
			if legal.is_empty():
				return stand
	for step in _ordered(state, legal):
		var value := -_search(apply(state, step), depth - 1, -beta, -alpha, budget, ply + 1, quiet - 1 if depth <= 0 else quiet)
		if budget.expired:
			return alpha
		alpha = maxi(alpha, value)
		if alpha >= beta:
			break
	return alpha


# Called on a worker with an isolated position. No nodes, profiles or UI are touched.
static func computer_move(state: Dictionary, difficulty: int) -> Dictionary:
	var legal := legal_moves_for(state)
	if legal.is_empty():
		return {}
	if difficulty == Difficulty.EASY and randf() < 0.75:
		return legal.pick_random()
	legal.shuffle()
	legal = _ordered(state, legal)
	var best: Dictionary = legal[0]
	var budget := {"nodes": 0, "limit": 30000, "deadline": Time.get_ticks_msec() + (1100 if difficulty == Difficulty.HARD else 400), "expired": false}
	for depth in range(1, (3 if difficulty == Difficulty.HARD else (2 if difficulty == Difficulty.MEDIUM else 1)) + 1):
		var score := -1000000
		var choice: Dictionary = best
		for step in legal:
			var value := -_search(apply(state, step), depth - 1, -1000000, -score, budget, 1)
			if budget.expired:
				break
			if value > score:
				score = value
				choice = step
		if budget.expired:
			break
		best = choice
	return best
