extends SceneTree

const Rules = preload("res://Games/pictionary/host/rules.gd")
const Host = preload("res://Games/pictionary/host/main.tscn")
const WordBank = preload("res://Games/pictionary/host/word_bank.gd")
var checks := 0
var failures := 0
var awards: Dictionary = {}
var reports: Array = []
var public_state: Dictionary = {}
var private_states: Dictionary = {}
var bank: Array = []
var sound_events: Array = []


func _init() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)


func roster(count := 3) -> Array:
	var players: Array = []
	for seat in count:
		players.append({"id": "p%d" % seat, "display_name": ["Jane", "Alex", "Riley"][seat] if seat < 3 else "Artist %d" % seat, "profile_id": "profile%d" % seat, "reconnect_token": "token%d" % seat, "color": "#286ac2"})
	return players


func begin(count := 3):
	var game = Rules.new()
	check(game.setup(roster(count), bank), "Valid roster starts a match")
	return game


func chunk(game, id := "stroke", sequence := 0, points: Array = [[200, 150], [500, 300]], ended := true) -> Dictionary:
	return {"action": "ink", "revision": game.revision, "turn_id": game.turn_id, "epoch": game.drawing_epoch, "stroke_id": id, "sequence": sequence, "points": points, "color": 0, "width": 1, "end": ended}


func send(host, seat: int, action: String, values: Dictionary = {}) -> void:
	var message := {"action": action, "revision": host.rules.revision, "turn_id": host.rules.turn_id}
	message.merge(values, true)
	host.handle_controller_message("p%d" % seat, message)


func _run() -> void:
	bank = JSON.parse_string(FileAccess.get_file_as_string("res://Games/pictionary/words.json")).words
	check(bank.size() == 120, "Original offline bank contains 120 words")
	for category in Rules.CATEGORIES:
		for difficulty in Rules.DIFFICULTIES:
			var preferences := {"category": category, "difficulty": difficulty}
			var game = Rules.new()
			check(game.setup(roster(), bank, preferences) and game.offers.size() == 3, "Every category/difficulty offers three distinct words")
	var invalid = Rules.new()
	check(not invalid.setup(roster(2), bank) and not invalid.setup(roster(17), bank), "No solo or two-player fallback; maximum is sixteen")
	var duplicate := roster()
	duplicate[1].id = duplicate[0].id
	check(not invalid.setup(duplicate, bank), "Duplicate identities cannot occupy two seats")
	check(Rules.integer(true) == -1 and Rules.integer(1.2) == -1 and Rules.integer(INF) == -1, "Malformed integer values are rejected")
	check(Rules.validate_options({"seconds": true, "laps": -1, "category": "invalid", "difficulty": {}, "hints": []}) == Rules.DEFAULTS, "Invalid saved preferences recover typed defaults")
	for count in range(3, 17):
		var game = begin(count)
		check(game.phase == "choosing" and game.remaining == 10 and game.offers.size() == 3, "Drawer begins with a timed private choice")
		for seat in count:
			var view: Dictionary = game.view_for(seat)
			check(view.has("choices") == (seat == game.drawer) and not view.has("secret"), "Only the drawer receives word choices")
			check(not JSON.stringify(view).contains("token") and not JSON.stringify(view).contains("profile"), "Private snapshots strip profile and reconnect secrets")
		check(not game.view_for(-1).has("choices") and not game.choose(1, 0) and not game.choose(0, true) and game.choose(0, 0), "Only the drawer can choose an offered integer index")
		var word: String = game.chosen.word
		for seat in count:
			check(game.view_for(seat).has("secret") == (seat == 0), "Chosen word remains private during drawing")
		check(not game.view_for(-1).has("secret") and not game.view_for(-1).has("word") and game.view_for(-1).history.is_empty(), "Host and public state do not leak the current word")
		var revision: int = game.revision
		check(not game.guess(0, word) and not game.guess(-1, word) and not game.guess(1, {}) and not game.guess(1, "x".repeat(61)), "Drawer, outsiders and invalid guesses cannot score")
		for seat in range(1, count):
			check(game.guess(seat, word.to_upper()) and game.turn_guesses[seat].rank == seat, "Correct guesses receive host-accepted ranks")
			check(not game.guess(seat, word), "Correct guessers cannot score twice")
			if seat < count - 1:
				check(game.phase == "drawing" and game.revision == revision, "Other correct guesses leave the drawing turn and stroke revision active")
				check(game.view_for(-1).feed.is_empty() and game.view_for(-1).guess_results.is_empty() and game.scores.all(func(score: int) -> bool: return score == 0), "Live state hides last guesses and defers the fixed pool until turn completion")
		check(game.scores[0] == 0 and game.scores.slice(1) == Rules.weighted_points(count - 1), "Only correct guessers share the hundred-point turn pool")
		check(game.phase == "reveal" and game.remaining == 6 and game.view_for(-1).word == word and game.history.size() == 1, "All correct guesses reveal the word and record the completed turn")
		check(game.view_for(-1).guess_results.is_empty() and game.view_for(-1).feed.is_empty() and game.view_for(-1).history.is_empty() and not game.view_for(1).has("last_guess"), "Turn reveal keeps last guesses private until the whole match concludes")
	var stream = begin()
	stream.choose(0, 0)
	check(stream.ink(1, chunk(stream)).is_empty(), "Guessers cannot inject drawing")
	var bad := chunk(stream)
	bad.points = [[-1, 0]]
	check(stream.ink(0, bad).is_empty() and stream.point_count == 0, "Out-of-range ink is rejected before mutation")
	bad.points = [[0, true]]
	check(stream.ink(0, bad).is_empty(), "Boolean coordinates cannot be coerced into points")
	bad.points = [[0, 0, 1]]
	check(stream.ink(0, bad).is_empty(), "Malformed coordinate arrays are rejected")
	bad.points = []
	bad.end = false
	check(stream.ink(0, bad).is_empty(), "Empty non-final chunks are rejected")
	var first: Dictionary = stream.ink(0, chunk(stream, "a", 0, [[10, 20], [20, 30]], false))
	check(first.kind == "ink" and stream.point_count == 2 and stream.active_stroke == "a", "A validated stroke streams a small public delta")
	check(stream.ink(0, chunk(stream, "a", 0)).is_empty() and stream.ink(0, chunk(stream, "a", 2)).is_empty(), "Duplicate and out-of-order chunks are discarded")
	var before: int = stream.revision
	stream.guess(1, stream.chosen.word)
	check(stream.revision == before and not stream.ink(0, chunk(stream, "a", 1, [[35, 42]], true)).is_empty(), "A simultaneous correct guess does not break the drawer's stroke")
	check(stream.view_for(2).strokes[0].points.size() == 3 and stream.view_for(2).strokes[0].end, "Refresh has the complete settled stroke")
	var epoch: int = stream.drawing_epoch
	check(stream.edit_ink(0, false) and stream.strokes.is_empty() and stream.point_count == 0 and stream.drawing_epoch > epoch, "Undo removes one complete stroke and invalidates stale ink")
	check(stream.ink(0, first).is_empty(), "Ink from before undo cannot return later")
	stream.ink(0, chunk(stream, "b"))
	check(stream.edit_ink(0, true) and stream.strokes.is_empty() and not stream.edit_ink(1, true), "Only the drawer can clear the current canvas")
	stream.point_count = Rules.MAX_POINTS
	check(stream.ink(0, chunk(stream, "overflow")).is_empty(), "Drawing budget bounds memory and traffic")
	var paused = begin()
	paused.choose(0, 0)
	paused.ink(0, chunk(paused, "held", 0, [[20, 40]], false))
	paused.tick(5)
	var remaining: float = paused.remaining
	var secret: String = paused.chosen.word
	check(paused.set_disconnected(0) and paused.strokes[0].end and paused.active_stroke.is_empty(), "Disconnect finalizes an open stroke and keeps the seat")
	paused.tick(100)
	check(paused.remaining == remaining and not paused.guess(1, secret) and paused.ink(0, chunk(paused)).is_empty(), "Disconnect freezes time, guesses and drawing")
	check(paused.reconnect(0) and paused.view_for(0).secret == secret and paused.remaining == remaining and paused.strokes.size() == 1, "Reconnect restores the same private word, canvas and timer")
	var timer = begin()
	var default_word: String = timer.offers[0].word
	timer.tick(10)
	check(timer.phase == "drawing" and timer.chosen.word == default_word and timer.remaining == 60, "Choice timeout selects the first offer without deadlocking")
	timer.tick(60)
	check(timer.phase == "reveal" and timer.guessed.is_empty() and timer.scores == [0, 0, 0], "Drawing timeout reveals the word without points")
	timer.tick(6)
	check(timer.phase == "choosing" and timer.drawer == 1, "Reveal deadline rotates to the next drawer")
	var aliases = begin()
	aliases.choose(0, 0)
	aliases.chosen = {"word": "sailboat", "aliases": ["sail boat", "sailing boat"]}
	check(aliases.guess(1, "  Sailing BOAT! "), "Listed aliases are accepted ignoring case, spaces and punctuation")
	check(aliases.guess(2, "sail") and aliases.scores[2] == 0 and not aliases.guess(2, "sailboat"), "Partial words do not score and rapid repeated guesses are rejected")
	aliases.tick(0.76)
	check(aliases.guess(2, "sailboat"), "Another guess is available after its cooldown")
	check(Rules.guess_quality("bok", ["book"]) == "close" and Rules.guess_quality("boook", ["book"]) == "close" and Rules.guess_quality("sailbaot", ["sailboat"]) == "close", "Missing, extra and transposed letters are orange near misses")
	check(Rules.guess_quality("moon", ["book"]) == "wrong" and Rules.guess_quality("sail", ["sailboat"]) == "wrong" and Rules.guess_quality("Sailing BOAT!", ["sailboat", "sailing boat"]) == "correct", "Unrelated guesses are red; exact aliases remain green")
	var bubbles = begin(4)
	bubbles.choose(0, 0)
	bubbles.chosen = {"word": "book", "aliases": []}
	bubbles.guess(1, "<b>moon</b>")
	var speech: Array = bubbles.view_for(-1).guess_bubbles
	check(speech.size() == 1 and speech[0].seat == 1 and speech[0].text == "<b>moon</b>" and speech[0].quality == "wrong" and not speech[0].has("word") and bubbles.view_for(-1).feed.is_empty(), "Incorrect guesses publish only a literal, answer-free scoreboard bubble")
	bubbles.tick(2)
	bubbles.set_disconnected(2)
	bubbles.tick(30)
	check(bubbles.guess_bubbles()[0].remaining == 2, "Disconnects freeze the bubble lifetime")
	bubbles.reconnect(2)
	bubbles.tick(2)
	check(bubbles.guess_bubbles().is_empty(), "A wrong-guess bubble expires after four active seconds")
	bubbles.guess(2, "bok")
	check(bubbles.guess_bubbles()[0].quality == "close", "Near-misses also create a non-scoring bubble")
	bubbles.tick(0.8)
	bubbles.guess(2, "book")
	check(bubbles.guess_bubbles().is_empty() and bubbles.guessed == [2] and bubbles.view_for(-1).guess_results.is_empty(), "Correct guesses remove their bubble and retain a public success indication without the answer")
	bubbles.guess(1, "moon")
	bubbles.tick(60)
	check(bubbles.guess_bubbles().is_empty(), "Turn completion clears temporary bubbles")
	check(Rules.weighted_points(4) == [40, 30, 20, 10] and Rules.weighted_points(4, 10) == [4, 3, 2, 1], "Linear rank weights share the exact pool without a zero last place")
	check(Rules.weighted_points(0).is_empty() and Rules.weighted_points(16).is_empty() and Rules.weighted_points(4, 3).is_empty(), "Invalid or empty distributions cannot create points")
	for weighting in Rules.RANK_WEIGHTS:
		for count in range(1, 16):
			for total in [15, 100, 137, 10000]:
				var distribution := Rules.weighted_points(count, total, weighting)
				check(distribution.reduce(func(sum: int, amount: int) -> int: return sum + amount, 0) == total and distribution.all(func(amount: int) -> bool: return amount > 0), "Weighted shares conserve the pool and reward every correct guesser")
				var sorted := distribution.duplicate()
				sorted.sort()
				sorted.reverse()
				check(distribution == sorted, "Weighted shares descend by accepted rank")
	check(Rules.validate_options({"turn_points": 137, "rank_weights": "steep"}).turn_points == 137 and Rules.validate_options({"turn_points": true, "rank_weights": "unknown"}) == Rules.DEFAULTS, "Pool and weight settings validate typed values")
	var feedback_game = begin(4)
	feedback_game.choose(0, 0)
	feedback_game.chosen = {"word": "sailboat", "aliases": ["sail boat"]}
	feedback_game.tick(4.25)
	feedback_game.guess(2, "sailbaot")
	check(feedback_game.scores == [0, 0, 0, 0] and feedback_game.view_for(2).last_guess.quality == "close", "Orange guesses earn no points and retain private feedback")
	feedback_game.tick(1.0)
	feedback_game.guess(3, "moon")
	check(feedback_game.scores == [0, 0, 0, 0] and feedback_game.view_for(3).last_guess.quality == "wrong", "Red guesses earn no points")
	feedback_game.set_disconnected(1)
	feedback_game.tick(30)
	feedback_game.reconnect(1)
	feedback_game.guess(1, "Sail Boat")
	check(feedback_game.scores[1] == 0 and feedback_game.turn_guesses[1].seconds == 5.25 and feedback_game.turn_guesses[1].rank == 1, "Correct time excludes pauses and orange guesses do not consume a rank")
	feedback_game.tick(2.5)
	feedback_game.guess(2, "sailboat")
	check(feedback_game.scores[2] == 0 and feedback_game.turn_guesses[2].seconds == 7.75 and feedback_game.turn_guesses[2].rank == 2, "Second correct guess retains its host time before distributing the pool")
	feedback_game.tick(60)
	check(feedback_game.view_for(-1).guess_results.is_empty() and feedback_game.scores == [0, 67, 33, 0], "Two successful guessers split exactly 100 points; misses stay hidden and score zero")
	check(feedback_game.turn_guesses[1].seconds == 5.25 and feedback_game.turn_guesses[2].seconds == 7.75 and feedback_game.turn_guesses[3].seconds == 60.0, "Successful times freeze at their correct guess; incorrect guesses receive the full turn duration")
	feedback_game.next_turn()
	check(feedback_game.turn_guesses.all(func(entry: Dictionary) -> bool: return entry.is_empty()) and feedback_game.match_guesses[3].text == "moon", "New turns clear live feedback and retain completed-turn last guesses")
	while feedback_game.phase != "finished":
		if feedback_game.phase == "choosing": feedback_game.choose(feedback_game.drawer, 0)
		if feedback_game.phase == "drawing": feedback_game.tick(180)
		if feedback_game.phase == "reveal": feedback_game.next_turn()
	check(feedback_game.view_for(-1).guess_results.size() == 4 and feedback_game.view_for(-1).guess_results.all(func(entry: Dictionary) -> bool: return entry.text.is_empty() and entry.seconds == 60.0 and entry.points == 0 and not entry.word.is_empty()), "Final results include no guesses from every player's most recent guessing turn, with full durations and answer context")
	feedback_game.replay()
	check(feedback_game.match_guesses.all(func(entry: Dictionary) -> bool: return entry.is_empty()), "Replay clears old guesses from the new match")
	var durations = begin(4)
	for turn in 2:
		durations.choose(durations.drawer, 0)
		durations.tick(60)
		durations.next_turn()
	durations.choose(2, 0)
	durations.tick(0.6)
	durations.guess(3, durations.chosen.word)
	durations.tick(60)
	durations.next_turn()
	durations.choose(3, 0)
	durations.chosen = {"word": "book", "aliases": []}
	for attempt in 4:
		durations.tick(5)
		durations.guess(1, "moon")
	durations.tick(10)
	durations.guess(1, "book")
	durations.guess(2, "bok")
	durations.tick(30)
	check(durations.phase == "reveal" and durations.turn_guesses[1].seconds == 30 and durations.turn_guesses[2].seconds == 60 and durations.turn_guesses[0].seconds == 60, "Five attempts do not reset elapsed time; incorrect and absent guesses both use the full sixty seconds")
	check(durations.scores == [0, 100, 0, 100] and durations.view_for(1).guess_results.is_empty(), "A sole correct guess gets the pool and results stay hidden during the final reveal")
	durations.next_turn()
	var final_guesses: Array = durations.view_for(-1).guess_results
	check(final_guesses.map(func(entry: Dictionary) -> int: return entry.seat) == [3, 1, 0, 2] and final_guesses[0].seconds == 0.6 and final_guesses[1].text == "book" and final_guesses[2].text.is_empty() and final_guesses[3].text == "bok", "Finished last guesses put correct guesses first, fastest to slowest, with deterministic timeout ties")
	check(durations.score_order() == [1, 3, 0, 2] and durations.view_for(-1).score_order == [1, 3, 0, 2], "Scoreboard orders highest cumulative points first with stable ties")
	var hints = begin()
	hints.options.hints = "letters"
	hints.choose(0, 0)
	hints.chosen.word = "sailboat"
	check(hints.hint() == "_ _ _ _ _ _ _ _", "Hints initially show only length")
	hints.tick(24)
	check(hints.hint() == "S _ _ _ _ _ _ _", "Optional first letter appears at forty percent")
	hints.tick(18)
	check(hints.hint() == "S A _ _ _ _ _ _", "Optional second letter appears at seventy percent")
	var match_game = begin()
	for turn in 3:
		check(match_game.drawer == turn, "Every player draws once in roster order")
		match_game.choose(turn, 0)
		match_game.tick(60)
		match_game.next_turn()
	check(match_game.phase == "finished" and match_game.outcome.draw and match_game.session_wins == [0, 0, 0], "An all-zero completed match is a draw")
	check(match_game.replay() and match_game.drawer == 1 and match_game.match_number == 2 and match_game.history.size() == 3, "Replay rotates the first drawer and preserves completed history")
	var ties = begin()
	for turn in 3:
		ties.choose(ties.drawer, 0)
		for offset in range(1, 3):
			ties.guess((ties.drawer + offset) % 3, ties.chosen.word)
		ties.next_turn()
	check(ties.outcome.winners == [0, 1, 2] and ties.scores == [100, 100, 100] and ties.session_wins == [1, 1, 1], "Tied weighted scores share one match win")
	check(ties.replay() and ties.scores == [0, 0, 0] and ties.session_wins == [1, 1, 1], "Replay resets match points and retains session wins")
	check(ties.apply_options({"seconds": 90, "laps": 2, "category": "food", "difficulty": "easy", "hints": "none"}) and ties.options.seconds == 90 and ties.session_wins == [1, 1, 1], "Settings restart without inventing a result and retain completed wins")
	var host = Host.instantiate()
	root.add_child(host)
	host.settings_store = preload("res://tests/game_settings_fixture.gd").new()
	host.initialize_session(GameSessionContext.new("pictionary", roster(), {}, true))
	host.points_awarded.connect(func(id: String, amount: int) -> void: awards[id] = int(awards.get(id, 0)) + amount)
	host.result_reported.connect(func(id: String, won: bool) -> void: reports.append([id, won]))
	host.controller_state_updated.connect(func(value: Dictionary) -> void: if value.get("kind") == "state": public_state = value)
	host.controller_state_updated.connect(func(value: Dictionary) -> void: if value.get("kind") == "sound": sound_events.append(value))
	host.controller_private_state_updated.connect(func(id: String, value: Dictionary) -> void: private_states[id] = value)
	host.start_game()
	check(public_state.viewer == -1 and not public_state.has("choices") and private_states.p0.choices.size() == 3, "Launcher signals route public and private views separately")
	send(host, 1, "choose", {"choice": 0})
	check(host.rules.phase == "choosing", "Host rejects another player's private choice")
	send(host, 0, "choose", {"choice": 0})
	var stale := chunk(host.rules)
	stale.revision -= 1
	host.handle_controller_message("p0", stale)
	check(host.rules.strokes.is_empty(), "Stale turn revision cannot alter the canvas")
	host.handle_controller_message("unknown", chunk(host.rules))
	check(host.rules.strokes.is_empty(), "Unknown identities cannot draw")
	host.handle_controller_message("p0", chunk(host.rules))
	check(host.rules.strokes.size() == 1 and awards.is_empty() and reports.is_empty(), "Drawing cannot create scores or profile awards")
	var sounds_before := sound_events.size()
	host.effect_sounds.turn.stop()
	send(host, 1, "guess", {"guess": "<img src=x>"})
	var speech_row: Dictionary = host.score_rows.filter(func(row: Dictionary) -> bool: return row.get("seat") == 1)[0]
	check(sound_events.size() == sounds_before and host.effect_sounds.wrong.playing and speech_row.bubble.panel.visible and speech_row.bubble.label.text == "<img src=x>" and not host.guess_notice.text.contains("<img"), "Wrong guesses play one host-only cue and keep literal scoreboard feedback")
	var first_wrong: float = host.wrong_sound_at
	send(host, 1, "guess", {"guess": "another guess"})
	check(sound_events.size() == sounds_before and host.wrong_sound_at == first_wrong, "Rejected rapid guesses cannot restart the wrong-guess sound")
	send(host, 2, "guess", {"guess": "another wrong guess"})
	check(host.rules.turn_guesses[2].text == "another wrong guess" and host.wrong_sound_at == first_wrong and sound_events.size() == sounds_before, "Simultaneous accepted wrong guesses do not stack, restart or broadcast the cue")
	host.effect_sounds.wrong.stop()
	host._sound("wrong")
	check(host.wrong_sound_at == first_wrong and not host.effect_sounds.wrong.playing, "The quiet gap remains enforced after playback ends")
	host.rules.tick(0.41)
	host._sound("wrong")
	check(host.effect_sounds.wrong.playing and host.wrong_sound_at > first_wrong, "A later wrong guess can play after the cooldown")
	host._sound("correct")
	check(not host.effect_sounds.wrong.playing and sound_events[-1].sound == "correct", "Correct feedback takes priority over the wrong-guess cue")
	var last_wrong: float = host.wrong_sound_at
	host.rules.tick(0.41)
	host._sound("wrong")
	check(not host.effect_sounds.wrong.playing and host.wrong_sound_at == last_wrong, "Wrong feedback is skipped while another game cue is playing")
	sounds_before = sound_events.size()
	host.rules.tick(0.8)
	host.rules.remaining = 10
	host._update_countdown()
	host._update_countdown()
	check(sound_events.size() == sounds_before + 1 and sound_events[-1].sound == "countdown", "Urgent clocks play one tick per new second, never per render")
	host.player_disconnected("p2")
	host._update_countdown()
	check(sound_events.size() == sounds_before + 1 and not host.effect_sounds.countdown.playing and not speech_row.bubble.panel.visible, "Disconnect pauses countdown audio and hides scoreboard bubbles")
	host.player_reconnected(roster()[2])
	host._update_countdown()
	check(sound_events.size() == sounds_before + 1 and speech_row.bubble.panel.visible, "Reconnect restores an unexpired bubble without replaying the current clock tick")
	host.rules.remaining = 9
	host._update_countdown()
	check(sound_events.size() == sounds_before + 2 and sound_events[-1].second == 9, "The following urgent second produces one fresh countdown event")
	check(GameMotion.countdown_alpha(9.75, false) != GameMotion.countdown_alpha(9.25, false) and GameMotion.countdown_alpha(9.75, true) == 1 and GameMotion.countdown_alpha(9.25, true) == 1, "Countdown alternates brightness every half-second and stays static with reduced motion")
	host.rules.remaining = 60
	for turn in 3:
		if host.rules.phase == "choosing":
			send(host, host.rules.drawer, "choose", {"choice": 0})
		for offset in range(1, 3):
			send(host, (host.rules.drawer + offset) % 3, "guess", {"guess": host.rules.chosen.word})
			check(host.guess_notice.text.contains("guessed it!"), "Turn table retains correct-guess indications without successful answer text")
		host._next_turn()
	check(host.rules.phase == "finished" and awards == {"profile0": 100, "profile1": 100, "profile2": 100} and reports.size() == 3, "Completed human matches award weighted points through BaseGame")
	host._record_result()
	check(reports.size() == 3 and awards.profile0 == 100, "Repeated sync/record cannot award the completed match twice")
	send(host, 0, "replay")
	check(host.rules.phase == "finished", "Phones cannot bypass host-only replay")
	host._replay()
	check(host.rules.phase == "choosing" and host.rules.drawer == 1 and host.rules.session_wins == [1, 1, 1], "Host replay preserves session history and rotates starters")
	host.settings_seconds.value = 90
	host.settings_points.value = 137
	host.weights_choice.select(Rules.RANK_WEIGHTS.find("steep"))
	host._apply_settings()
	check(host.rules.options.seconds == 90 and host.rules.options.turn_points == 137 and host.rules.options.rank_weights == "steep" and reports.size() == 3, "Applying saved timer/pool/weights abandons the current match without results")
	check(host.find_children("*", "Button", true, false).all(func(button: Button) -> bool: return not button.text.begins_with("HISTORY") and not button.text.begins_with("HELP")), "Host omits Help and History")
	host._toggle_settings()
	check(host.settings_dialog.overlay.visible, "Settings opens as a shared full-screen popup")
	host._close_settings()
	check(not host.settings_dialog.overlay.visible, "Settings popup closes without changing gameplay")
	var old_categories: Array = host.word_categories.duplicate(true)
	host.new_category_input.text = "Custom <Art>"
	host._add_category()
	var custom_id: String = host.staged_categories[-1].id
	check(host.word_categories == old_categories and not host.save_words_button.disabled, "Adding a category is staged until Save")
	host.new_word_input.text = "café"
	host._add_word()
	host.new_word_input.text = "3D printer"
	host._add_word()
	check(host.staged_categories[-1].words.size() == 2 and Rules.normalize("Café!") == "café" and Rules.normalize("3D printer") == "3dprinter", "Edited word banks support letters and numbers without punctuation")
	host.new_word_input.text = " café "
	host._add_word()
	check(host.staged_categories[-1].words.size() == 2, "Equivalent duplicate words cannot be added")
	host.category_name_input.text = "Custom Studio"
	host._rename_category()
	check(host.staged_categories[-1].name == "Custom Studio" and host.staged_categories[-1].id == custom_id, "Renaming preserves stable category IDs")
	host.settings_seconds.value = 120
	host._save_words()
	check(host.rules.options.seconds == 90 and host.settings_seconds.value == 120 and not host.apply_button.disabled, "Word Save preserves independently staged timer changes")
	check(host.word_categories[-1].name == "Custom Studio" and host.rules.categories.has(custom_id) and reports.size() == 3 and host.save_words_button.disabled, "Saving commits the edited bank and restarts without invented results")
	host.category_choice.select(host.category_ids.find(custom_id))
	host.difficulty_choice.select(Rules.DIFFICULTIES.find("easy"))
	host._apply_settings()
	check(host.rules.options.category == custom_id and host.rules.offers.size() == 2 and host.rules.options.seconds == 120, "Custom categories offer their one or two available words")
	check(host.rules.choose(host.rules.drawer, 1), "A smaller edited pool still validates its offered indexes")
	var erased_category: Dictionary = host.staged_categories.pop_back()
	host._refresh_word_editor()
	host._save_words()
	check(not host.rules.categories.has(custom_id) and host.rules.options.category == "mixed", "Removing an active category adapts selection safely on Save")
	check(not WordBank.validate([{"id": "x", "name": "X", "words": []}]).size(), "An empty bank cannot replace a playable bank")
	check(WordBank.validate([{"id": "../x", "name": "X", "words": erased_category.words}]).is_empty(), "Malformed custom category IDs are rejected")
	var restored = Host.instantiate()
	root.add_child(restored)
	restored.settings_store = host.settings_store
	restored.initialize_session(GameSessionContext.new("pictionary", roster(), {}, true))
	check(restored.rules.options.seconds == 120 and restored.rules.options.turn_points == 137 and restored.rules.options.rank_weights == "steep" and restored.settings_points.value == 137 and restored.rules.scores == [0, 0, 0] and restored.word_categories == host.word_categories, "Relaunch restores timer/pool/weights and the saved bank, but starts fresh gameplay")
	var disk := GameSettingsStore.new("res://.test_data/pictionary-settings/%d" % OS.get_process_id())
	check(disk.save_settings("pictionary", {"word_categories": host.word_categories, "seconds": 120}), "The real settings store writes edited categories transactionally")
	var disk_saved := disk.load_settings("pictionary", {"word_categories": [], "seconds": 60})
	check(WordBank.validate(disk_saved.word_categories) == host.word_categories and disk_saved.seconds == 120, "Edited categories and settings survive an actual disk reload")
	restored.shutdown_game()
	restored.queue_free()
	host.shutdown_game()
	check(not host.active, "Shutdown cancels clocks and sounds")
	host.queue_free()
	await process_frame
	# Let the audio mixer release stopped playback before exiting the fixture.
	await create_timer(0.3).timeout
	print("Pictionary: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
