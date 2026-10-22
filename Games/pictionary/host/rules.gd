extends RefCounted

const DEFAULTS := {"seconds": 60, "laps": 1, "category": "mixed", "difficulty": "mixed", "hints": "length", "turn_points": 100, "rank_weights": "linear"}
const CATEGORIES := ["mixed", "animals", "food", "objects", "places", "actions"]
const DIFFICULTIES := ["mixed", "easy", "medium", "hard"]
const HINTS := ["none", "length", "letters"]
const RANK_WEIGHTS := ["linear", "steep"]
const INKS := ["#263442", "#286ac2", "#d83e43", "#409348", "#efbd23", "#88512d", "#893fcc", "#fff7e8"]
const WIDTHS := [4, 9, 18]
const ERASER_WIDTHS := [18, 36, 60]
const BUBBLE_SECONDS := 4.0
const MAX_POINTS := 16000
const MAX_STROKES := 512
const MAX_CHUNK := 32

var players: Array = []
var options: Dictionary = DEFAULTS.duplicate()
var words: Array = []
var pool: Array = []
var categories: Array = CATEGORIES.duplicate()
var phase := "idle"
var revision := 0
var match_number := 0
var turn_id := 0
var turn_index := 0
var starter := 0
var drawer := -1
var remaining := 0.0
var elapsed := 0.0
var clock := 0.0
var missing: Array = []
var scores: Array = []
var session_wins: Array = []
var history: Array = []
var guessed: Array = []
var offers: Array = []
var chosen: Dictionary = {}
var used_words: Array = []
var feed: Array = []
var turn_scores: Array = []
var outcome: Dictionary = {}
var strokes: Array = []
var drawing_epoch := 0
var drawing_version := 0
var point_count := 0
var active_stroke := ""
var stroke_ids: Dictionary = {}
var guess_times: Dictionary = {}
var turn_guesses: Array = []
var match_guesses: Array = []
var ink_tokens := 60.0
var rng := RandomNumberGenerator.new()


static func integer(value: Variant, minimum := 0, maximum := 2147483647) -> int:
	if not (value is int or value is float) or not is_finite(float(value)) or float(value) != floorf(float(value)) or float(value) < minimum or float(value) > maximum:
		return -1
	return int(value)


static func validate_options(value: Dictionary, category_ids: Array = CATEGORIES) -> Dictionary:
	var result := DEFAULTS.duplicate()
	for key in ["seconds", "laps"]:
		var number := integer(value.get(key), 30 if key == "seconds" else 1, 180 if key == "seconds" else 3)
		if number >= 0:
			result[key] = number
	var turn_points := integer(value.get("turn_points"), 15, 10000)
	if turn_points >= 0:
		result.turn_points = turn_points
	if value.get("rank_weights") in RANK_WEIGHTS:
		result.rank_weights = value.rank_weights
	for key in ["category", "difficulty", "hints"]:
		var allowed: Array = category_ids if key == "category" else DIFFICULTIES if key == "difficulty" else HINTS
		if value.get(key) is String and value[key] in allowed:
			result[key] = value[key]
	return result


func setup(roster: Array, bank: Array, preferences: Dictionary = {}, category_ids: Array = CATEGORIES) -> bool:
	if roster.size() < 3 or roster.size() > 16:
		return false
	players.clear()
	var identities: Array = []
	for player in roster:
		if not player is Dictionary or not player.get("id") is String or str(player.id).is_empty() or identities.has(player.id):
			return false
		identities.append(player.id)
		players.append({"id": player.id, "display_name": str(player.get("display_name", "Player")), "color": str(player.get("color", "#286ac2")), "pose": player.get("pose", 0)})
	words.clear()
	categories = category_ids.duplicate()
	for word in bank:
		if word is Dictionary and word.get("word") is String and not str(word.word).strip_edges().is_empty() and word.get("category") in categories and word.get("difficulty") in DIFFICULTIES and word.get("aliases", []) is Array:
			words.append(word.duplicate(true))
	options = validate_options(preferences, categories)
	_refresh_pool()
	if pool.is_empty() or words.size() < 3:
		return false
	rng.randomize()
	session_wins.resize(players.size())
	session_wins.fill(0)
	history.clear()
	missing.clear()
	starter = 0
	match_number = 0
	new_match()
	return true


func _refresh_pool() -> void:
	pool = words.filter(func(word: Dictionary) -> bool: return (options.category == "mixed" or word.category == options.category) and (options.difficulty == "mixed" or word.difficulty == options.difficulty))


func apply_options(preferences: Dictionary) -> bool:
	if not missing.is_empty():
		return false
	var previous := options.duplicate()
	options = validate_options(preferences, categories)
	_refresh_pool()
	if pool.is_empty() or options == previous:
		options = previous
		_refresh_pool()
		return false
	new_match()
	return true


func new_match() -> void:
	match_number += 1
	scores.resize(players.size())
	scores.fill(0)
	match_guesses.clear()
	for seat in players.size():
		match_guesses.append({})
	turn_index = 0
	used_words.clear()
	outcome.clear()
	_start_turn()


func replace_word_bank(bank: Array, category_ids: Array) -> void:
	words = bank.duplicate(true)
	categories = category_ids.duplicate()
	options = validate_options(options, categories)
	_refresh_pool()
	if pool.is_empty():
		options.category = "mixed"
		options.difficulty = "mixed"
		_refresh_pool()
	new_match()


func replay() -> bool:
	if phase != "finished" or not missing.is_empty():
		return false
	starter = (starter + 1) % players.size()
	new_match()
	return true


func _start_turn() -> void:
	turn_id += 1
	revision += 1
	drawer = (starter + turn_index) % players.size()
	phase = "choosing"
	remaining = 10.0
	elapsed = 0.0
	guessed.clear()
	chosen.clear()
	feed.clear()
	guess_times.clear()
	turn_guesses.clear()
	for seat in players.size():
		turn_guesses.append({})
	turn_scores = scores.duplicate()
	_reset_ink()
	ink_tokens = 60.0
	var available: Array = pool.filter(func(word: Dictionary) -> bool: return not used_words.has(word.word))
	if available.size() < mini(3, pool.size()):
		used_words.clear()
		available = pool.duplicate()
	offers.clear()
	for choice in mini(3, available.size()):
		var index := rng.randi_range(0, available.size() - 1)
		offers.append(available.pop_at(index))


func choose(seat: int, choice: Variant) -> bool:
	var index := integer(choice, 0, offers.size() - 1)
	if phase != "choosing" or seat != drawer or index < 0 or not missing.is_empty():
		return false
	chosen = offers[index].duplicate(true)
	used_words.append(chosen.word)
	offers.clear()
	phase = "drawing"
	remaining = float(options.seconds)
	elapsed = 0.0
	revision += 1
	return true


func tick(delta: float) -> bool:
	if phase in ["idle", "finished"] or not missing.is_empty() or not is_finite(delta) or delta <= 0.0:
		return false
	clock += delta
	ink_tokens = minf(60.0, ink_tokens + delta * 60.0)
	elapsed += delta
	remaining = maxf(0, remaining - delta)
	if remaining > 0:
		return false
	match phase:
		"choosing": return choose(drawer, 0)
		"drawing": _end_turn()
		"reveal": return next_turn()
	return true


static func normalize(value: String) -> String:
	var filter := RegEx.new()
	filter.compile("[^\\p{L}\\p{N}]")
	return filter.sub(value.strip_edges().to_lower(), "", true)


# Largest remainders preserve the exact pool; even the final correct guesser
# gets at least one point. Incorrect/missing guesses never enter this list.
static func weighted_points(count: int, total := 100, weighting := "linear") -> Array:
	if count < 1 or count > 15 or total < count or weighting not in RANK_WEIGHTS:
		return []
	var weights: Array = []
	var weight_sum := 0
	for index in count:
		var weight := count - index
		if weighting == "steep":
			weight *= weight
		weights.append(weight)
		weight_sum += weight
	var points: Array = []
	var remainders: Array = []
	var allocated := 0
	for index in count:
		var numerator: int = total * weights[index]
		var amount := int(numerator / weight_sum)
		points.append(amount)
		allocated += amount
		remainders.append({"index": index, "remainder": numerator % weight_sum})
	remainders.sort_custom(func(first: Dictionary, second: Dictionary) -> bool: return first.remainder > second.remainder if first.remainder != second.remainder else first.index < second.index)
	for index in total - allocated:
		points[remainders[index].index] += 1
	for index in count:
		if points[index] == 0:
			var donor := 0
			for candidate in count:
				if points[candidate] > points[donor]:
					donor = candidate
			points[donor] -= 1
			points[index] = 1
	# Integer ties favor the earlier accepted guess.
	points.sort()
	points.reverse()
	return points


# Adjacent swaps, missing/extra letters and substitutions are near misses only.
# Exact normalized answers and curated aliases are the only scoring matches.
static func spelling_distance(first: String, second: String) -> int:
	var previous: Array = []
	var before: Array = []
	for column in range(second.length() + 1):
		previous.append(column)
	for row in range(1, first.length() + 1):
		var current: Array = [row]
		for column in range(1, second.length() + 1):
			var cost := 0 if first[row - 1] == second[column - 1] else 1
			var distance := mini(mini(int(previous[column]) + 1, int(current[column - 1]) + 1), int(previous[column - 1]) + cost)
			if row > 1 and column > 1 and first[row - 1] == second[column - 2] and first[row - 2] == second[column - 1]:
				distance = mini(distance, int(before[column - 2]) + 1)
			current.append(distance)
		before = previous
		previous = current
	return int(previous[-1])


static func guess_quality(value: String, answers: Array) -> String:
	var normalized := normalize(value)
	var close := false
	for answer in answers:
		if not answer is String:
			continue
		var target := normalize(answer)
		if target == normalized:
			return "correct"
		var tolerance := 2 if target.length() >= 8 else 1 if target.length() >= 3 else 0
		if tolerance > 0 and absi(target.length() - normalized.length()) <= tolerance and spelling_distance(normalized, target) <= tolerance:
			close = true
	return "close" if close else "wrong"


func guess(seat: int, value: Variant) -> bool:
	if phase != "drawing" or seat < 0 or seat >= players.size() or seat == drawer or guessed.has(seat) or not missing.is_empty() or not value is String:
		return false
	var text: String = value.strip_edges()
	if text.is_empty() or text.length() > 60 or text.contains("\n") or text.contains("\r") or clock - float(guess_times.get(seat, -10.0)) < 0.75:
		return false
	var guess_value := normalize(text)
	if guess_value.is_empty():
		return false
	guess_times[seat] = clock
	var answers: Array = [chosen.word] + chosen.get("aliases", [])
	var quality := guess_quality(text, answers)
	var correct := quality == "correct"
	var rank := guessed.size() + 1 if correct else 0
	if correct:
		guessed.append(seat)
	var entry := {"seat": seat, "correct": correct, "quality": quality, "text": text, "seconds": minf(elapsed, float(options.seconds)), "rank": rank, "points": 0, "turn": turn_index + 1, "word": chosen.word}
	turn_guesses[seat] = entry.duplicate(true)
	feed.append(entry)
	if feed.size() > 6:
		feed.pop_front()
	if guessed.size() == players.size() - 1:
		_end_turn()
	return true


func _end_turn() -> void:
	var distribution := weighted_points(guessed.size(), int(options.turn_points), options.rank_weights)
	for index in guessed.size():
		var seat: int = guessed[index]
		scores[seat] += distribution[index]
		turn_guesses[seat].points = distribution[index]
	for seat in players.size():
		if seat == drawer:
			continue
		if turn_guesses[seat].is_empty():
			turn_guesses[seat] = {"seat": seat, "correct": false, "quality": "wrong", "text": "", "seconds": float(options.seconds), "rank": 0, "points": 0, "turn": turn_index + 1, "word": chosen.word}
		elif not turn_guesses[seat].correct:
			turn_guesses[seat].seconds = float(options.seconds)
		match_guesses[seat] = turn_guesses[seat].duplicate(true)
	phase = "reveal"
	remaining = 6.0
	elapsed = 0.0
	revision += 1
	_close_stroke()
	var awards: Array = []
	for seat in players.size():
		awards.append(scores[seat] - turn_scores[seat])
	history.append({"match": match_number, "turn": turn_index + 1, "drawer": drawer, "word": chosen.word, "guessed": guessed.duplicate(), "awards": awards, "guesses": turn_guesses.filter(func(entry: Dictionary) -> bool: return not entry.is_empty()).duplicate(true)})
	if history.size() > 96:
		history.pop_front()


func next_turn() -> bool:
	if phase != "reveal" or not missing.is_empty():
		return false
	turn_index += 1
	if turn_index >= players.size() * int(options.laps):
		_finish()
	else:
		_start_turn()
	return true


func _finish() -> void:
	phase = "finished"
	remaining = 0.0
	revision += 1
	var best: int = scores.max()
	var winners: Array = []
	if best > 0:
		for seat in players.size():
			if scores[seat] == best:
				winners.append(seat)
				session_wins[seat] += 1
	outcome = {"winners": winners, "draw": winners.is_empty(), "scores": scores.duplicate()}


func set_disconnected(seat: int) -> bool:
	if seat < 0 or seat >= players.size() or missing.has(seat):
		return false
	missing.append(seat)
	revision += 1
	_close_stroke()
	return true


func reconnect(seat: int) -> bool:
	if not missing.has(seat):
		return false
	missing.erase(seat)
	revision += 1
	return true


func _close_stroke() -> void:
	if not active_stroke.is_empty() and not strokes.is_empty():
		strokes[-1].end = true
	active_stroke = ""


func _reset_ink() -> void:
	strokes.clear()
	stroke_ids.clear()
	point_count = 0
	active_stroke = ""
	drawing_epoch += 1
	drawing_version += 1


# Turn revisions reject stale input; ink epochs/sequences preserve streaming
# while simultaneous correct guesses change scores without breaking a stroke.
func ink(seat: int, message: Dictionary) -> Dictionary:
	if phase != "drawing" or seat != drawer or not missing.is_empty() or ink_tokens < 1.0:
		return {}
	if integer(message.get("epoch")) != drawing_epoch or integer(message.get("turn_id")) != turn_id:
		return {}
	var id: Variant = message.get("stroke_id")
	var sequence := integer(message.get("sequence"), 0, MAX_POINTS)
	var color := integer(message.get("color"), 0, INKS.size() - 1)
	var width := integer(message.get("width"), 0, WIDTHS.size() - 1)
	var points: Variant = message.get("points")
	if not id is String or id.is_empty() or id.length() > 48 or sequence < 0 or color < 0 or width < 0 or not message.get("end") is bool or not points is Array or points.size() > MAX_CHUNK or point_count + points.size() > MAX_POINTS:
		return {}
	if points.is_empty() and not message.end:
		return {}
	var checked: Array = []
	for point in points:
		if not point is Array or point.size() != 2:
			return {}
		var x := integer(point[0], 0, 1000)
		var y := integer(point[1], 0, 700)
		if x < 0 or y < 0:
			return {}
		checked.append([x, y])
	var stroke: Dictionary
	if sequence == 0:
		if stroke_ids.has(id) or not active_stroke.is_empty() or strokes.size() >= MAX_STROKES or checked.is_empty():
			return {}
		stroke = {"id": id, "sequence": -1, "color": color, "width": width, "points": [], "end": false}
		strokes.append(stroke)
		stroke_ids[id] = true
		active_stroke = id
	else:
		if active_stroke != id or strokes.is_empty():
			return {}
		stroke = strokes[-1]
		if sequence != int(stroke.sequence) + 1 or color != stroke.color or width != stroke.width:
			return {}
	stroke.sequence = sequence
	stroke.points.append_array(checked)
	stroke.end = message.end
	point_count += checked.size()
	drawing_version += 1
	ink_tokens -= 1.0
	if message.end:
		active_stroke = ""
	return {"kind": "ink", "turn_id": turn_id, "revision": revision, "epoch": drawing_epoch, "version": drawing_version, "stroke_id": id, "sequence": sequence, "color": color, "width": width, "points": checked, "end": message.end}


func edit_ink(seat: int, clear: bool) -> bool:
	if phase != "drawing" or seat != drawer or not missing.is_empty():
		return false
	_close_stroke()
	if clear:
		_reset_ink()
	elif not strokes.is_empty():
		var removed: Dictionary = strokes.pop_back()
		point_count -= removed.points.size()
		drawing_epoch += 1
		drawing_version += 1
	else:
		return false
	return true


func hint() -> String:
	if chosen.is_empty() or phase == "choosing":
		return ""
	if phase in ["reveal", "finished"]:
		return str(chosen.word).to_upper()
	if options.hints == "none":
		return ""
	var text := str(chosen.word).to_upper()
	var reveal := 0
	if options.hints == "letters":
		reveal = 2 if elapsed >= float(options.seconds) * 0.7 else 1 if elapsed >= float(options.seconds) * 0.4 else 0
	var result := PackedStringArray()
	for index in text.length():
		result.append("  " if text[index] == " " else text[index] if index < reveal else "_")
	return " ".join(result)


func _public_guess(entry: Dictionary) -> Dictionary:
	var result := entry.duplicate(true)
	if phase != "finished":
		result.erase("word")
		if result.correct:
			result.text = ""
	return result


func guess_results() -> Array:
	if phase != "finished":
		return []
	var results: Array = []
	for seat in players.size():
		results.append(match_guesses[seat].duplicate(true))
	results.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		if first.correct != second.correct:
			return first.correct
		if first.seconds != second.seconds:
			return first.seconds < second.seconds
		return first.seat < second.seat)
	return results


func score_order() -> Array:
	var order: Array = range(players.size())
	order.sort_custom(func(first: int, second: int) -> bool: return scores[first] > scores[second] if scores[first] != scores[second] else first < second)
	return order


func guess_bubbles() -> Array:
	var bubbles: Array = []
	if phase != "drawing":
		return bubbles
	for seat in players.size():
		var entry: Dictionary = turn_guesses[seat]
		if entry.is_empty() or entry.correct:
			continue
		var seconds := BUBBLE_SECONDS - (clock - float(guess_times.get(seat, -BUBBLE_SECONDS)))
		if seconds > 0.0:
			bubbles.append({"seat": seat, "text": entry.text, "quality": entry.quality, "remaining": seconds})
	return bubbles


func view_for(seat: int, include_drawing := true) -> Dictionary:
	var state := {"kind": "state", "viewer": seat, "players": players.duplicate(true), "phase": phase, "revision": revision, "match": match_number, "turn_id": turn_id, "turn": mini(turn_index + 1, players.size() * int(options.laps)), "total_turns": players.size() * int(options.laps), "drawer": drawer, "remaining": remaining, "paused": not missing.is_empty(), "missing": missing.duplicate(), "options": options.duplicate(), "scores": scores.duplicate(), "score_order": score_order(), "session_wins": session_wins.duplicate(), "guessed": guessed.duplicate(), "feed": [], "guess_results": guess_results(), "hint": hint(), "epoch": drawing_epoch, "drawing_version": drawing_version, "drawing_limit": point_count >= MAX_POINTS or strokes.size() >= MAX_STROKES, "outcome": outcome.duplicate(true)}
	if phase == "drawing" and seat >= 0 and seat < turn_guesses.size() and not turn_guesses[seat].is_empty():
		state["last_guess"] = _public_guess(turn_guesses[seat])
	if include_drawing:
		state["strokes"] = strokes.duplicate(true)
	if seat == -1:
		state["guess_bubbles"] = guess_bubbles()
		state["history"] = history.duplicate(true) if phase == "finished" else []
	if seat == drawer and phase == "choosing":
		state["choices"] = offers.map(func(word: Dictionary) -> String: return word.word)
	if seat == drawer and phase == "drawing":
		state["secret"] = chosen.word
	if phase in ["reveal", "finished"] and not chosen.is_empty():
		state["word"] = chosen.word
	return state
