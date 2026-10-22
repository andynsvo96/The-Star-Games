extends RefCounted

const LINES := [[0, 1, 2, 3], [0, 7, 14, 21], [0, 8, 16, 24], [1, 2, 3, 4], [1, 8, 15, 22], [1, 9, 17, 25], [2, 3, 4, 5], [2, 9, 16, 23], [2, 10, 18, 26], [3, 4, 5, 6], [3, 10, 17, 24], [3, 11, 19, 27], [3, 9, 15, 21], [4, 11, 18, 25], [4, 10, 16, 22], [5, 12, 19, 26], [5, 11, 17, 23], [6, 13, 20, 27], [6, 12, 18, 24], [7, 8, 9, 10], [7, 14, 21, 28], [7, 15, 23, 31], [8, 9, 10, 11], [8, 15, 22, 29], [8, 16, 24, 32], [9, 10, 11, 12], [9, 16, 23, 30], [9, 17, 25, 33], [10, 11, 12, 13], [10, 17, 24, 31], [10, 18, 26, 34], [10, 16, 22, 28], [11, 18, 25, 32], [11, 17, 23, 29], [12, 19, 26, 33], [12, 18, 24, 30], [13, 20, 27, 34], [13, 19, 25, 31], [14, 15, 16, 17], [14, 21, 28, 35], [14, 22, 30, 38], [15, 16, 17, 18], [15, 22, 29, 36], [15, 23, 31, 39], [16, 17, 18, 19], [16, 23, 30, 37], [16, 24, 32, 40], [17, 18, 19, 20], [17, 24, 31, 38], [17, 25, 33, 41], [17, 23, 29, 35], [18, 25, 32, 39], [18, 24, 30, 36], [19, 26, 33, 40], [19, 25, 31, 37], [20, 27, 34, 41], [20, 26, 32, 38], [21, 22, 23, 24], [22, 23, 24, 25], [23, 24, 25, 26], [24, 25, 26, 27], [28, 29, 30, 31], [29, 30, 31, 32], [30, 31, 32, 33], [31, 32, 33, 34], [35, 36, 37, 38], [36, 37, 38, 39], [37, 38, 39, 40], [38, 39, 40, 41]]
enum Difficulty { EASY, MEDIUM, HARD }
var board: Array = []

var wins: Array = [0, 0]
var turn := 1
var starter := 1
var round_number := 1
var outcome := 0
var champion := 0
var revision := 0
var match_number := 1
var session_wins: Array = [0, 0]
var match_wins: Array = [0, 0]
var draws := 0
var history: Array = []


func _init() -> void:
	board.resize(42)
	board.fill(0)


static func result(cells: Array) -> int:
	for line in LINES:
		if cells[line[0]] != 0 and cells[line[0]] == cells[line[1]] and cells[line[1]] == cells[line[2]] and cells[line[2]] == cells[line[3]]:
			return cells[line[0]]
	return 0 if cells.has(0) else 3


func move(column: int, mark: int) -> bool:
	var cell := landing_cell(board, column)
	if champion != 0 or outcome != 0 or mark != turn or cell < 0 or cell >= 42 or board[cell] != 0:
		return false
	board[cell] = mark
	revision += 1
	outcome = result(board)
	if outcome in [1, 2]:
		wins[outcome - 1] += 1
		champion = outcome
	if outcome != 0:
		if outcome == 3:
			draws += 1
		else:
			session_wins[outcome - 1] += 1
		if champion != 0:
			match_wins[champion - 1] += 1
		history.append({"match": match_number, "round": round_number, "outcome": outcome, "champion": champion})
	if outcome == 0:
		turn = 3 - turn
	return true


func next_round() -> bool:
	return play_again()


func play_again() -> bool:
	if outcome == 0:
		return false
	board.fill(0)
	wins = [0, 0]
	outcome = 0
	champion = 0
	starter = 3 - starter
	turn = starter
	round_number += 1
	match_number += 1
	revision += 1
	return true


# Rows are top-to-bottom. Only the host chooses the landing cell.
static func landing_cell(cells: Array, column: int) -> int:
	if column < 0 or column >= 7:
		return -1
	for row in range(5, -1, -1):
		if cells[row * 7 + column] == 0:
			return row * 7 + column
	return -1


static func computer_move(cells: Array, mark: int, difficulty: int) -> int:
	if result(cells) != 0:
		return -1
	var legal: Array[int] = []
	for column in [3, 2, 4, 1, 5, 0, 6]:
		if landing_cell(cells, column) >= 0:
			legal.append(column)
	if difficulty == Difficulty.EASY and randf() < 0.75:
		return legal.pick_random()
	var depth := 5 if difficulty == Difficulty.HARD else 3
	var best := -1000000
	var choices: Array[int] = []
	for column in legal:
		var cell := landing_cell(cells, column)
		cells[cell] = mark
		var score := -_search(cells, 3 - mark, depth - 1, -1000000, 1000000)
		cells[cell] = 0
		if score > best:
			best = score
			choices.clear()
		if score == best:
			choices.append(column)
	return choices.pick_random()


static func _search(cells: Array, mark: int, depth: int, alpha: int, beta: int) -> int:
	var winner := result(cells)
	if winner != 0:
		return 0 if winner == 3 else (100000 + depth if winner == mark else -100000 - depth)
	if depth == 0:
		return _evaluate(cells, mark)
	var best := -1000000
	for column in [3, 2, 4, 1, 5, 0, 6]:
		var cell := landing_cell(cells, column)
		if cell < 0:
			continue
		cells[cell] = mark
		var score := -_search(cells, 3 - mark, depth - 1, -beta, -alpha)
		cells[cell] = 0
		best = maxi(best, score)
		alpha = maxi(alpha, score)
		if alpha >= beta:
			break
	return best


static func _evaluate(cells: Array, mark: int) -> int:
	var score := 0
	var weights := [0, 1, 8, 60, 100000]
	for line in LINES:
		var own := 0
		var other := 0
		for cell in line:
			if cells[cell] == mark:
				own += 1
			elif cells[cell] == 3 - mark:
				other += 1
		if other == 0:
			score += weights[own]
		if own == 0:
			score -= weights[other]
	return score
