extends SceneTree

const BOARDS := ["tic-tac-toe", "four-in-a-row", "checkers", "chess", "battleship"]
const HOST := {"id": "host", "display_name": "Host", "color": "#e53935"}
var checks := 0
var failures := 0
var directory := ""


func _init() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)


func _players(count: int) -> Array:
	var players: Array = []
	for index in count:
		players.append({"id": "phone-%d" % index, "profile_id": "phone-%d" % index, "display_name": "Player %d" % index, "color": "#2463eb", "connected": true})
	return players


func _host(id: String, count := 0, custom_directory := "") -> BaseGame:
	var folder := "_Template" if id == "template" else id
	var host := load("res://Games/%s/host/main.tscn" % folder).instantiate() as BaseGame
	host.settings_store = GameSettingsStore.new(directory if custom_directory.is_empty() else custom_directory)
	if id == "spyfall":
		host.settings = preload("res://Games/spyfall/host/settings.gd").new(directory.path_join("spyfall.json"))
	root.add_child(host)
	var context := GameSessionContext.new(id, _players(count), HOST, count > 0)
	context.reduced_motion = true
	host.initialize_session(context)
	host.start_game()
	await process_frame
	return host


func _close(host: BaseGame) -> void:
	host.shutdown_game()
	host.queue_free()
	await process_frame


func _test_store() -> void:
	var store := GameSettingsStore.new(directory.path_join("store"))
	var defaults := {"difficulty": 1, "enabled": true, "minutes": 10.0, "options": {"rule": false}}
	check(store.load_settings("first", defaults) == defaults, "Missing preferences use defaults")
	check(store.save_settings("first", {"difficulty": 2, "options": {"rule": true}}), "Initial preferences save")
	check(store.save_settings("first", {"minutes": 3.25}), "Partial changes save")
	var loaded := GameSettingsStore.new(store.directory).load_settings("first", defaults)
	check(loaded.difficulty == 2 and loaded.options.rule and loaded.minutes == 3.25 and loaded.enabled, "New store restores values and keeps unrelated preferences")
	loaded.options.rule = false
	check(store.load_settings("first", defaults).options.rule, "Returned dictionaries cannot mutate saved preferences")
	check(store.load_settings("second", defaults) == defaults, "Games have independent preferences")
	check(not store.save_settings("../outside", defaults), "Unsafe IDs cannot escape the settings directory")
	check(store.save_settings("invalid", {"difficulty": 1.5, "enabled": "false", "minutes": "3", "options": {"rule": 1}}), "Malformed-type fixture writes")
	check(store.load_settings("invalid", defaults) == defaults, "Malformed values use typed defaults recursively")
	var file := FileAccess.open(store.directory.path_join("first.json"), FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	loaded = store.load_settings("first", defaults)
	check(loaded.difficulty == 2 and loaded.options.rule and loaded.minutes == 10.0, "Corrupt primary recovers the last committed backup")
	file = FileAccess.open(store.directory.path_join("invalid.json"), FileAccess.WRITE)
	file.store_string("{\"schema_version\":999,\"settings\":{\"difficulty\":2}}")
	file.close()
	check(store.load_settings("invalid", defaults) == defaults, "Unknown schemas safely use defaults")
	var blocked := GameSettingsStore.new(store.directory.path_join("invalid.json/child"))
	check(not blocked.save_settings("first", defaults) and not blocked.last_error.is_empty(), "Failed writes return an explicit error")


func _write_hosts() -> void:
	for id in BOARDS:
		var host = await _host(id)
		host._select_difficulty(2)
		if id in ["checkers", "chess"]:
			host.clock_input.value = 3.2
			host._select_clock(true)
			host._select_clock(false)
			host.clock_input.value = 4.7
			check(not host.clock_toggle.button_pressed and is_equal_approx(host.clock_minutes, 4.7), "%s remembers minutes while the timer is off" % id)
			host._select_clock(true)
		if id == "checkers": host._select_force_jump(false)
		if id == "chess": host._select_guidance(false)
		check(FileAccess.file_exists(directory.path_join(id + ".json")), "%s saves immediately before shutdown" % id)
		await _close(host)
		host = await _host(id, 1)
		host._select_mode(1)
		check(host.host_plays and host.seats[0].id == "host", "%s accepts and saves the one-phone opponent" % id)
		await _close(host)
	var uno = await _host("uno")
	uno._set_gamemode(2)
	uno._set_difficulty(2)
	uno._set_rule("allow_stacking", false)
	uno._set_rule("force_play", true)
	check(not FileAccess.file_exists(directory.path_join("uno.json")), "Staged UNO edits are not saved")
	uno._apply_options()
	uno._set_gamemode(1)
	await _close(uno)
	uno = await _host("uno", 0, directory.path_join("classic"))
	uno._set_addon("reverse", true)
	uno._set_addon("love_island", true)
	uno._set_rule("allow_jump_ins", true)
	uno._apply_options()
	await _close(uno)
	var quoridor = await _host("quoridor", 4)
	quoridor._select_host(true)
	quoridor._select_computers(2)
	quoridor._select_difficulty(0)
	check(not FileAccess.file_exists(directory.path_join("quoridor.json")), "Staged Quoridor edits are not saved")
	quoridor._apply_settings()
	check(quoridor.player_count == 4 and quoridor.computer_count == 2, "Quoridor applies the chosen lineup")
	quoridor._select_players(0)
	await _close(quoridor)
	var mafia = await _host("mafia", 7)
	mafia._set_option("godfather", true)
	mafia._set_option("boxer", true)
	mafia._set_option("ejection", false)
	check(not FileAccess.file_exists(directory.path_join("mafia.json")), "Staged Mafia edits are not saved")
	mafia._apply_options()
	await _close(mafia)
	mafia = await _host("mafia", 4)
	check(not mafia.rules.options.godfather and not mafia.rules.options.boxer, "Unavailable Mafia roles stay disabled in a smaller party")
	mafia._set_option("ejection", true)
	mafia._apply_options()
	await _close(mafia)
	var spyfall = await _host("spyfall", 4)
	spyfall.timer_input.value = 3.2
	spyfall.vote_timer_input.value = 0.5
	spyfall.anonymous_toggle.button_pressed = true
	spyfall._apply_settings()
	spyfall.staged_locations = ["Library", "Garden", "Station"]
	spyfall._settings_changed()
	spyfall._save_locations()
	await _close(spyfall)
	var template = await _host("template")
	template.example_choice.item_selected.emit(1)
	template.example_toggle.button_pressed = true
	template.example_length.value = 2.5
	await _close(template)


func _read_hosts() -> void:
	for id in BOARDS:
		var host = await _host(id, 1)
		check(host.difficulty == 2 and host.difficulty_choice.selected == 2, "%s restores solo difficulty and its selector after process exit" % id)
		check(host.host_plays and host.seats[0].id == "host" and host.seats[1].id == "phone-0" and host.mode_choice.selected == 1, "%s restores host-versus-phone seats" % id)
		if id in ["checkers", "chess"]:
			check(is_equal_approx(host.rules.clock_seconds, 282.0) and is_equal_approx(host.clock_minutes, 4.7) and is_equal_approx(host.clock_input.value, 4.7) and host.clock_toggle.button_pressed, "%s restores decimal clock settings and controls" % id)
			check(is_equal_approx(host.rules.remaining[0], 282.0) and host.rules.remaining[0] == host.rules.remaining[1] and not host.rules.clock_started, "%s starts fresh clocks rather than resuming old time" % id)
		if id == "checkers": check(not host.rules.force_jump and not host.force_jump_toggle.button_pressed, "Checkers restores Force Jump")
		if id == "chess": check(not host.guidance and not host.guidance_toggle.button_pressed, "Chess restores guidance")
		host._select_difficulty(0)
		check(host.difficulty == 2, "%s rejects solo difficulty changes in a phone session" % id)
		await _close(host)
		host = await _host(id, 2)
		check(not host.host_plays and host.seats[0].id == "phone-0" and host.seats[1].id == "phone-1", "%s keeps two-phone seats despite the saved opponent choice" % id)
		await _close(host)
		host = await _host(id)
		check(host.host_plays and host.seats[0].id == "host" and host.seats[1].id == "computer" and host.difficulty == 2, "%s keeps solo play available and saved preferences unchanged" % id)
		await _close(host)
	var uno = await _host("uno")
	check(uno.rules.gamemode == "no_mercy" and uno.pending_gamemode == "no_mercy" and uno.difficulty == 2, "UNO restores applied mode/difficulty, discarding later uncommitted edits")
	check(not uno.rules.allow_stacking and uno.rules.force_play and uno.rules.draw_until_play and uno.rules.allow_mercy and not uno._options_changed(), "UNO restores mode rules without resetting them to defaults")
	await _close(uno)
	uno = await _host("uno", 0, directory.path_join("classic"))
	check(uno.rules.enabled_addons.reverse and uno.rules.enabled_addons.love_island and uno.rules.allow_jump_ins and not uno._options_changed(), "UNO restores Classic add-on packs and rules")
	await _close(uno)
	var quoridor = await _host("quoridor")
	check(quoridor.player_count == 4 and quoridor.computer_count == 3 and quoridor.host_plays and quoridor.difficulty == 0 and quoridor.seats.size() == 4, "Quoridor adapts a saved lineup to a solo host")
	await _close(quoridor)
	quoridor = await _host("quoridor", 4)
	check(quoridor.player_count == 4 and quoridor.computer_count == 2 and quoridor.host_plays and quoridor.difficulty == 0 and not quoridor._settings_changed(), "Quoridor restores the preferred lineup when phones return")
	await _close(quoridor)
	var mafia = await _host("mafia", 7)
	check(mafia.rules.options.godfather and mafia.rules.options.boxer and mafia.rules.options.ejection and mafia.staged_options == mafia.rules.options, "Mafia restores saved roles after smaller-party settings changes")
	await _close(mafia)
	var spyfall = await _host("spyfall", 4)
	check(is_equal_approx(spyfall.settings.minutes, 3.2) and spyfall.settings.vote_minutes == 0.5 and spyfall.rules.anonymous_voting and spyfall.rules.locations == ["Library", "Garden", "Station"], "Spyfall retains its existing saved timers, anonymity and location pool")
	await _close(spyfall)
	var template = await _host("template")
	check(template.example_choice.selected == 1 and template.example_toggle.button_pressed and template.example_length.value == 2.5, "Template demonstrates persistence for every shared control type")
	await _close(template)
	# Out-of-range settings must not cause invalid selectors or game rules.
	var store := GameSettingsStore.new(directory.path_join("bounds"))
	store.save_settings("chess", {"difficulty": 99, "clock_enabled": true, "clock_minutes": -2.0})
	var chess = await _host("chess", 0, store.directory)
	check(chess.difficulty == 1 and chess.clock_minutes == 10.0 and chess.rules.clock_seconds == 600.0, "Out-of-range saved values use safe game defaults")
	await _close(chess)


func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() == 2 and arguments[0] == "--read":
		directory = arguments[1]
		await _read_hosts()
	else:
		directory = "res://.test_data/game-settings/%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
		_test_store()
		await _write_hosts()
		var output: Array = []
		var result := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/game_settings.gd", "--", "--read", directory], output, true)
		for line in output: print(line)
		check(result == 0 and not str(output).contains("FAIL:") and str(output).contains("0 failures"), "A separate Godot process restores every game's preferences")
	print("Game settings: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
