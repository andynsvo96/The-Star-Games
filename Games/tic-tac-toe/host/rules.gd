extends RefCounted

const LINES := [[0, 1, 2], [3, 4, 5], [6, 7, 8], [0, 3, 6], [1, 4, 7], [2, 5, 8], [0, 4, 8], [2, 4, 6]]
enum Difficulty { EASY, MEDIUM, HARD }
var board: Array = [0, 0, 0, 0, 0, 0, 0, 0, 0]
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


static func result(cells: Array) -> int:
	for line in LINES:
		if cells[line[0]] != 0 and cells[line[0]] == cells[line[1]] and cells[line[1]] == cells[line[2]]:
			return cells[line[0]]
	return 0 if cells.has(0) else 3


func move(cell: int, mark: int) -> bool:
	if champion != 0 or outcome != 0 or mark != turn or cell < 0 or cell >= 9 or board[cell] != 0:
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


static func computer_move(cells: Array, mark: int, difficulty: int) -> int:
	if result(cells) != 0:
		return -1
	var random_chance := 0.0
	if difficulty == Difficulty.EASY:
		random_chance = 0.75
	elif difficulty == Difficulty.MEDIUM:
		random_chance = 0.25
	if random_chance > 0.0 and randf() < random_chance:
		var legal: Array[int] = []
		for cell in 9:
			if cells[cell] == 0:
				legal.append(cell)
		return legal.pick_random()
	return best_move(cells, mark)


static func best_move(cells: Array, mark: int) -> int:
	if result(cells) != 0:
		return -1
	var best := -100
	var choices: Array[int] = []
	for cell in 9:
		if cells[cell] != 0:
			continue
		cells[cell] = mark
		var score := -_value(cells, 3 - mark)
		cells[cell] = 0
		if score > best:
			best = score
			choices.clear()
		if score == best:
			choices.append(cell)
	# Vary equally strong moves while preserving perfect play.
	return -1 if choices.is_empty() else choices.pick_random()


static func _value(cells: Array, mark: int) -> int:
	var winner := result(cells)
	if winner != 0:
		return 0 if winner == 3 else (1 if winner == mark else -1)
	var best := -2
	for cell in 9:
		if cells[cell] == 0:
			cells[cell] = mark
			best = maxi(best, -_value(cells, 3 - mark))
			cells[cell] = 0
	return best
