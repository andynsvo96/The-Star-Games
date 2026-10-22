extends RefCounted

# Authoritative indexes run top-left (0) to bottom-right (80).
# Two seats face north/south. Four seats run clockwise: south, west, north, east.
# Walls are anchored at the top-left of a 2x2 block; h blocks north/south.
enum Difficulty { EASY, MEDIUM, HARD }
const SIZE := 9
const DIRECTIONS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
var pawns: Array = [76, 4]
var walls: Array = []
var remaining: Array = [10, 10]
var turn := 1
var starter := 1
var outcome := 0
var revision := 0
var round_number := 1
var session_wins: Array = [0, 0]
var history: Array = []
var last_action: Dictionary = {}


func _init(player_count := 2) -> void:
	assert(player_count in [2, 4])
	pawns = [76, 4] if player_count == 2 else [76, 36, 4, 44]
	remaining = [10, 10] if player_count == 2 else [5, 5, 5, 5]
	session_wins = [0, 0] if player_count == 2 else [0, 0, 0, 0]


static func at_goal(cell: int, side: int, player_count := 2) -> bool:
	if player_count == 2:
		return int(cell / 9) == (0 if side == 1 else 8)
	match side:
		1: return int(cell / 9) == 0
		2: return cell % 9 == 8
		3: return int(cell / 9) == 8
		4: return cell % 9 == 0
	return false


static func next_side(side: int, player_count: int) -> int:
	return side % player_count + 1


static func graph_for(placed: Array) -> PackedInt32Array:
	var graph := PackedInt32Array()
	graph.resize(81 * 4)
	graph.fill(-1)
	for cell in 81:
		var point := Vector2i(cell % 9, int(cell / 9))
		for direction in 4:
			var next: Vector2i = point + DIRECTIONS[direction]
			if next.x >= 0 and next.x < 9 and next.y >= 0 and next.y < 9:
				graph[cell * 4 + direction] = next.y * 9 + next.x
	for wall in placed:
		_block_wall(graph, wall)
	return graph


static func _block_wall(graph: PackedInt32Array, wall: Dictionary) -> void:
	var cell: int = wall.row * 9 + wall.col
	for offset in 2:
		if wall.orientation == "h":
			graph[(cell + offset) * 4 + 2] = -1
			graph[(cell + offset + 9) * 4] = -1
		else:
			graph[(cell + offset * 9) * 4 + 1] = -1
			graph[(cell + offset * 9 + 1) * 4 + 3] = -1


static func distance(graph: PackedInt32Array, start: int, side: int, player_count := 2) -> int:
	# Reachability ignores pawn occupancy: an opponent cannot permanently seal a path.
	var distances := PackedInt32Array()
	distances.resize(81)
	distances.fill(-1)
	distances[start] = 0
	var queue := PackedInt32Array([start])
	var index := 0
	while index < queue.size():
		var cell := queue[index]
		index += 1
		if at_goal(cell, side, player_count):
			return distances[cell]
		for direction in 4:
			var neighbor := graph[cell * 4 + direction]
			if neighbor >= 0 and distances[neighbor] < 0:
				distances[neighbor] = distances[cell] + 1
				queue.append(neighbor)
	return -1


static func pawn_moves(graph: PackedInt32Array, positions: Array, side: int) -> Array:
	var result: Array = []
	var cell: int = positions[side - 1]
	for direction in 4:
		var next := graph[cell * 4 + direction]
		if next < 0:
			continue
		if not positions.has(next):
			if not result.has(next):
				result.append(next)
			continue
		var behind := graph[next * 4 + direction]
		if behind >= 0 and not positions.has(behind):
			if not result.has(behind):
				result.append(behind)
		else:
			# A wall, edge or another pawn permits side jumps, never a chain jump.
			for sideways in [(direction + 1) % 4, (direction + 3) % 4]:
				var diagonal := graph[next * 4 + sideways]
				if diagonal >= 0 and not positions.has(diagonal) and not result.has(diagonal):
					result.append(diagonal)
	return result


static func wall_fits(placed: Array, row: int, col: int, orientation: String) -> bool:
	if row < 0 or row >= 8 or col < 0 or col >= 8 or orientation not in ["h", "v"]:
		return false
	for wall in placed:
		if wall.orientation != orientation:
			if wall.row == row and wall.col == col:
				return false
		elif orientation == "h":
			if wall.row == row and absi(wall.col - col) <= 1:
				return false
		elif wall.col == col and absi(wall.row - row) <= 1:
			return false
	return true


static func wall_legal(graph: PackedInt32Array, positions: Array, placed: Array, row: int, col: int, orientation: String) -> bool:
	if not wall_fits(placed, row, col, orientation):
		return false
	var candidate := graph.duplicate()
	_block_wall(candidate, {"row": row, "col": col, "orientation": orientation})
	for index in positions.size():
		if distance(candidate, positions[index], index + 1, positions.size()) < 0:
			return false
	return true


func legal_moves() -> Array:
	return [] if outcome else pawn_moves(graph_for(walls), pawns, turn)


func legal_walls() -> Array:
	var result: Array = []
	if outcome or remaining[turn - 1] <= 0:
		return result
	var graph := graph_for(walls)
	for row in 8:
		for col in 8:
			for orientation in ["h", "v"]:
				if wall_legal(graph, pawns, walls, row, col, orientation):
					result.append({"row": row, "col": col, "orientation": orientation})
	return result


func move(destination: int, side: int) -> bool:
	if side != turn or outcome or not legal_moves().has(destination):
		return false
	last_action = {"action": "move", "side": side, "from": pawns[side - 1], "to": destination}
	pawns[side - 1] = destination
	revision += 1
	if at_goal(destination, side, pawns.size()):
		outcome = side
		session_wins[side - 1] += 1
		history.append({"round": round_number, "outcome": side})
	else:
		turn = next_side(turn, pawns.size())
	return true


func place_wall(row: int, col: int, orientation: String, side: int) -> bool:
	if side != turn or outcome or remaining[side - 1] <= 0 or not wall_legal(graph_for(walls), pawns, walls, row, col, orientation):
		return false
	var wall := {"row": row, "col": col, "orientation": orientation, "side": side}
	walls.append(wall)
	remaining[side - 1] -= 1
	last_action = wall.duplicate()
	last_action.action = "wall"
	revision += 1
	turn = next_side(turn, pawns.size())
	return true


func play_again() -> bool:
	if not outcome:
		return false
	var player_count := pawns.size()
	pawns = [76, 4] if player_count == 2 else [76, 36, 4, 44]
	walls = []
	remaining = [10, 10] if player_count == 2 else [5, 5, 5, 5]
	starter = next_side(starter, player_count)
	turn = starter
	outcome = 0
	round_number += 1
	revision += 1
	last_action = {}
	return true


func position() -> Dictionary:
	return {"pawns": pawns.duplicate(), "walls": walls.duplicate(true), "remaining": remaining.duplicate(), "turn": turn}


static func _evaluate(graph: PackedInt32Array, positions: Array, stock: Array, side: int, to_play: int) -> int:
	var distances: Array = []
	for player in range(1, positions.size() + 1):
		if at_goal(positions[player - 1], player, positions.size()):
			return 100000 if player == side else -100000
		var best := 1000
		for next in pawn_moves(graph, positions, player):
			best = mini(best, 1 + distance(graph, next, player, positions.size()))
		distances.append(best)
	var nearest := 1000
	var largest_stock := 0
	for index in positions.size():
		if index == side - 1:
			continue
		nearest = mini(nearest, distances[index])
		largest_stock = maxi(largest_stock, stock[index])
	var score: int = (nearest - distances[side - 1]) * 100 + (stock[side - 1] - largest_stock) * 9
	if to_play != side and distances[to_play - 1] == 1:
		score -= 50000
	return score


static func _ranked(position_state: Dictionary, side: int) -> Array:
	var graph := graph_for(position_state.walls)
	var candidates: Array = []
	for destination in pawn_moves(graph, position_state.pawns, side):
		var positions: Array = position_state.pawns.duplicate()
		positions[side - 1] = destination
		candidates.append({"input": {"action": "move", "to": destination}, "score": _evaluate(graph, positions, position_state.remaining, side, next_side(side, positions.size()))})
	if position_state.remaining[side - 1] > 0:
		for row in 8:
			for col in 8:
				for orientation in ["h", "v"]:
					if not wall_fits(position_state.walls, row, col, orientation):
						continue
					var candidate := graph.duplicate()
					_block_wall(candidate, {"row": row, "col": col, "orientation": orientation})
					var reachable := true
					for index in position_state.pawns.size():
						if distance(candidate, position_state.pawns[index], index + 1, position_state.pawns.size()) < 0:
							reachable = false
							break
					if not reachable:
						continue
					var stock: Array = position_state.remaining.duplicate()
					stock[side - 1] -= 1
					candidates.append({"input": {"action": "wall", "row": row, "col": col, "orientation": orientation}, "score": _evaluate(candidate, position_state.pawns, stock, side, next_side(side, position_state.pawns.size()))})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.score > b.score)
	return candidates


static func _after(position_state: Dictionary, input: Dictionary, side: int) -> Dictionary:
	var next := position_state.duplicate(true)
	if input.action == "move":
		next.pawns[side - 1] = input.to
	else:
		next.walls.append({"row": input.row, "col": input.col, "orientation": input.orientation})
		next.remaining[side - 1] -= 1
	next.turn = next_side(side, next.pawns.size())
	return next


static func computer_move(position_state: Dictionary, level: int) -> Dictionary:
	# Search copies only, on the host's worker. Hard compares the best six actions
	# with the next opponent's best legal reply; no unbeatable claim is made.
	var side: int = position_state.turn
	var candidates := _ranked(position_state, side)
	if candidates.is_empty():
		return {}
	if candidates[0].score >= 100000:
		return candidates[0].input.duplicate()
	var random := RandomNumberGenerator.new()
	random.randomize()
	if level == Difficulty.EASY:
		var relaxed: Array = candidates.filter(func(candidate: Dictionary) -> bool: return candidate.input.action == "move")
		if random.randf() < 0.15:
			relaxed = candidates
		elif random.randf() < 0.7:
			# Usually make progress; random-only walking can wander indefinitely.
			var graph := graph_for(position_state.walls)
			var shortest := 1000
			for candidate in relaxed:
				shortest = mini(shortest, distance(graph, candidate.input.to, side, position_state.pawns.size()))
			relaxed = relaxed.filter(func(candidate: Dictionary) -> bool: return distance(graph, candidate.input.to, side, position_state.pawns.size()) == shortest)
		return relaxed[random.randi_range(0, relaxed.size() - 1)].input.duplicate()
	var best := -1000000000
	var choices: Array = []
	for candidate in candidates.slice(0, 6 if level == Difficulty.HARD else candidates.size()):
		var score: int = candidate.score
		if level == Difficulty.HARD:
			var after := _after(position_state, candidate.input, side)
			var replies := _ranked(after, after.turn)
			if not replies.is_empty():
				# The next opponent chooses for itself; evaluate its reply for this AI.
				var reply := _after(after, replies[0].input, after.turn)
				score = _evaluate(graph_for(reply.walls), reply.pawns, reply.remaining, side, reply.turn) * 1000 + candidate.score
		if score > best:
			best = score
			choices.clear()
		if score == best:
			choices.append(candidate.input)
	return choices[random.randi_range(0, choices.size() - 1)].duplicate()
