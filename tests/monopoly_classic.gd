extends SceneTree

const Rules = preload("res://Games/monopoly-classic/host/rules.gd")
const Computer = preload("res://Games/monopoly-classic/host/ai.gd")
const Store = preload("res://Games/monopoly-classic/host/session_store.gd")
var failures := 0
var checks := 0
var instances: Array = []


func _init() -> void:
	call_deferred("_run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + label)


func game(count := 2):
	var result = Rules.new(); result.start(count, 0, 47017); return result


func act(rules, seat: int, action: String, extra: Dictionary = {}) -> bool:
	var input := extra.duplicate(true); input.action = action; input.revision = int(rules.s.revision)
	return rules.apply(seat, input)


func building_market():
	var result = game()
	for pair in [[1, 0, 3], [3, 0, 4], [6, 0, 4], [8, 0, 4], [9, 0, 4], [11, 1, 3], [13, 1, 3], [14, 1, 3], [16, 1, 1], [18, 1, 1], [19, 1, 1]]:
		result.s.owners[pair[0]] = pair[1]; result.s.levels[pair[0]] = pair[2]
	return result


func _run() -> void:
	var r = game()
	check(r.definition.board.size() == 40 and r.properties.size() == 28, "US board contains 40 spaces and 28 independently defined deeds")
	check(r.properties[1].name == "Mediterranean Avenue" and r.properties[39].name == "Boardwalk" and r.properties[35].name == "Short Line", "Canonical US street and railroad names")
	check(not JSON.stringify(r.definition).contains("Mayfair") and not JSON.stringify(r.definition).contains("Old Kent"), "No UK board names")
	check(r.s.cash == [1500, 1500] and r.buildings_available() == {"houses": 32, "hotels": 12}, "Starting cash and finite building bank")
	check(not r.start(1) and not r.start(7), "Rules enforce 2–6 total seats")
	r = game(); r.s.owners[1] = 0; r.s.owners[3] = 0
	check(r.rent(1, 7) == 4, "Unimproved color monopoly doubles base rent")
	check(act(r, 0, "build", {"property": 1}) and r.rent(1, 7) == 10, "Build house and collect printed house rent")
	check(not act(r, 0, "build", {"property": 1}), "Building is even across the color set")
	check(not act(r, 0, "mortgage", {"property": 3}), "No mortgage while any street in set is developed")
	check(act(r, 0, "sell", {"property": 1}) and r.s.cash[0] == 1475, "Selling returns half building price")
	check(act(r, 0, "mortgage", {"property": 1}) and r.rent(1, 7) == 0 and r.rent(3, 7) == 8, "Mortgage suppresses only that deed's rent")
	check(r.wealth(0) == 1595, "Wealth includes cash and property value less mortgage principal")
	check(act(r, 0, "unmortgage", {"property": 1}) and r.s.cash[0] == 1472, "Mortgage repayment includes 10 percent interest")
	r = game(); r.s.owners[5] = 0; r.s.owners[15] = 0; r.s.owners[25] = 0; r.s.owners[35] = 0
	check(r.rent(5, 7) == 200 and r.rent(5, 7, 2) == 400, "Railroad schedules and Chance doubled railroad rent")
	r.s.owners[12] = 0
	check(r.rent(12, 7) == 28 and r.rent(12, 7, 1, true) == 70, "Utility normal and Chance multiplier")
	r.s.owners[28] = 0; check(r.rent(12, 7) == 70, "Owning both utilities uses ten times dice")
	r = game(); r.s.positions[0] = 39; r._roll_values(0, 1, 2)
	check(r.s.positions[0] == 2 and r.s.cash[0] >= 1700, "Crossing GO awards $200 before landing effects")
	r = game(); r.s.doubles = 2; r._roll_values(0, 4, 4)
	check(r.s.positions[0] == 10 and r.s.jailed[0] == 0 and not r.s.extra_roll, "Third consecutive doubles goes directly to Jail")
	r = game(); r.s.positions[0] = 10; r.s.jailed[0] = 2; r.s.phase = "jail"; r._roll_values(0, 2, 3)
	check(r.s.jailed[0] == -1 and r.s.positions[0] == 15 and r.s.cash[0] == 1450, "Third failed jail attempt pays and uses that roll")
	r = game(); r.s.positions[0] = 10; r.s.jailed[0] = 0; r.s.phase = "jail"; r._roll_values(0, 3, 3)
	check(r.s.jailed[0] == -1 and not r.s.extra_roll, "Doubles release from jail without a bonus roll")
	r = game(); r.s.positions[0] = 36; r.s.phase = "manage"; r.s.decks.chance.erase(8); r.s.decks.chance.push_front(8); r.s.decks.community.erase(1); r.s.decks.community.push_front(1); r._draw_card("chance", 0); r._drain()
	check(r.s.positions[0] == 33 and r.s.cash[0] == 1700, "Back-three Chance resolves Community Chest without GO income")
	r = game(); r.s.positions[0] = 1; r.s.phase = "buy"; r.s.buy_id = 1
	check(act(r, 0, "auction") and act(r, 0, "bid", {"amount": 25}) and act(r, 1, "pass_bid"), "Declined purchase opens an auction including the lander")
	check(r.s.owners[1] == 0 and r.s.cash[0] == 1475, "Highest bidder pays the actual winning bid")
	r = game(); r.s.phase = "buy"; r.s.buy_id = 1; act(r, 0, "auction"); act(r, 0, "pass_bid"); act(r, 1, "pass_bid")
	check(r.s.owners[1] == -1 and r.s.phase == "manage", "Unbid property remains at the bank")
	r = building_market()
	check(r.buildings_available().houses == 1 and act(r, 0, "build", {"property": 1}) and r.s.phase == "building_interest" and r.actor() == 1, "Last house asks other eligible builders before selling")
	check(Rules.new().import_state(JSON.parse_string(JSON.stringify(r.export_state()))), "Building requests restore from a save")
	check(not act(r, 1, "claim_building", {"property": 39}), "Cannot request the last house on an unowned street")
	check(act(r, 1, "claim_building", {"property": 11}) and r.s.phase == "auction" and r.s.auction.kind == "building", "Competing last-house requests create an auction")
	check(Rules.new().import_state(JSON.parse_string(JSON.stringify(r.export_state()))), "Building auction restores its eligible placements")
	check(act(r, 0, "bid", {"amount": 40, "property": 1}) and act(r, 1, "bid", {"amount": 60, "property": 11}) and act(r, 0, "pass_bid"), "Builders bid for their own selected street")
	check(r.s.levels[11] == 4 and r.s.levels[1] == 3 and r.s.cash[1] == 1440 and r.buildings_available().houses == 0, "Highest bidder receives exactly the final physical house")
	check(act(r, 0, "build", {"property": 6}) and r.s.levels[6] == 5 and r.buildings_available().houses == 4, "Hotel conversion returns four houses to the bank")
	r = building_market(); act(r, 0, "build", {"property": 1}); act(r, 1, "decline_building")
	check(r.s.levels[1] == 4 and r.s.cash[0] == 1450 and r.s.phase == "roll", "Uncontested last building sells at its printed price")
	r = game()
	for pair in [[1,0,4],[3,0,4],[6,1,4],[8,1,4],[9,1,4],[11,0,5],[13,0,5],[14,0,5],[16,1,5],[18,1,5],[19,1,5],[21,0,5],[23,0,5],[24,0,5],[26,1,5],[27,1,5],[29,1,4]]:
		r.s.owners[pair[0]] = pair[1]; r.s.levels[pair[0]] = pair[2]
	check(r.buildings_available() == {"houses": 8, "hotels": 1} and act(r, 0, "build", {"property": 1}) and r.s.building_sale.kind == "hotel", "The last hotel uses the same finite-stock request process")
	check(act(r, 1, "claim_building", {"property": 6}) and act(r, 0, "bid", {"amount": 100, "property": 1}) and act(r, 1, "pass_bid"), "Competing hotel buyers resolve by a binding auction")
	check(r.s.levels[1] == 5 and r.buildings_available() == {"houses": 12, "hotels": 0} and Rules.new().import_state(JSON.parse_string(JSON.stringify(r.export_state()))), "Final hotel returns four houses and preserves stock through resume")
	check(ThemePacks.new("monopoly-classic").presentation == "modern-table" and ThemePacks.new("monopoly-deal").presentation == "modern-table", "Classic preview opts into the shared modern palette while preserving Deal")
	check(ThemePacks.new("monopoly-classic").preview_kind == "portfolio" and ThemePacks.new("monopoly-deal").preview_kind == "cards", "Classic's skin preview uses portfolio captions and preserves Deal's existing preview")
	r = game(); r.s.owners[1] = 0; r.s.owners[5] = 1
	var offer := {"to": 1, "give_cash": 50, "take_cash": 0, "give_properties": [1], "take_properties": [5], "give_jail": [], "take_jail": []}
	check(act(r, 0, "offer_trade", offer) and act(r, 1, "accept_trade"), "Explicit bilateral property and cash trade")
	check(r.s.owners[1] == 1 and r.s.owners[5] == 0 and r.s.cash == [1450, 1550] and r.s.phase == "roll", "Trade transfers assets and restores the interrupted phase")
	r = game(); r.s.owners[1] = 0; r.s.mortgaged[1] = true
	var mortgage_offer := {"to": 1, "give_cash": 0, "take_cash": 0, "give_properties": [1], "take_properties": [], "give_jail": [], "take_jail": []}
	act(r, 0, "offer_trade", mortgage_offer); act(r, 1, "accept_trade")
	check(r.s.phase == "transfer" and r.actor() == 1, "Mortgage recipient must choose interest or repayment")
	act(r, 1, "keep_mortgage")
	check(r.s.cash[1] == 1497 and r.s.mortgaged[1] and r.s.phase == "roll", "Incoming mortgage interest is charged and original phase restored")
	r = game(); var before := JSON.stringify(r.export_state())
	check(not r.apply(1, {"action": "roll", "revision": r.s.revision}) and JSON.stringify(r.export_state()) == before, "Off-turn controller cannot roll")
	check(not r.apply(0, {"action": "roll", "revision": r.s.revision, "dice": [6, 6]}) and JSON.stringify(r.export_state()) == before, "Controller cannot supply dice")
	check(not r.apply(0, {"action": "roll", "revision": 0}) and not r.apply(0, {"action": "roll", "revision": true}), "Stale and boolean revisions rejected")
	r = game(); r.s.cash[0] = 5; r.s.phase = "manage"; r.s.owners[1] = 0; r._prepend([{"kind": "charge", "seat": 0, "target": 1, "amount": 1000, "reason": "Rent"}]); r._drain()
	check(r.s.phase == "debt" and act(r, 0, "bankrupt"), "Insolvent debt permits bankruptcy")
	check(r.s.bankrupt[0] and r.s.owners[1] == 1 and r.s.winner == 1, "Creditor receives assets and final survivor wins")
	r = game(); r.s.owners[39] = 1; r.s.levels[39] = 3; r.s.cash[1] = 1000
	r.finish("time")
	check(r.s.winner == 1 and r.s.result_wealth[1] == 2000, "Timed winner includes property and full building purchase value")
	r = game(); r.finish("time")
	check(r.s.winner in [0, 1] and not r.s.tie_rolls.is_empty(), "Tied wealth and cash produces exactly one dice tiebreak winner")
	r = game(); var restored = Rules.new(); var exported: Dictionary = JSON.parse_string(JSON.stringify(r.export_state()))
	check(restored.import_state(exported) and int(restored.s.cash[0]) == 1500 and int(restored.s.cash[1]) == 1500, "Saved numeric state survives JSON round trip")
	check(restored.rng.randi() == r.rng.randi(), "Saved random state preserves the next host-owned random result")
	exported.owners[1] = 8; check(not Rules.new().import_state(exported), "Invalid saved ownership is rejected")
	check(not JSON.stringify(r.view_for(0)).contains("rng_state") and not r.view_for(0).has("decks"), "Controller view omits deck order and random state")
	exported = game().export_state(); exported.phase = "debt"; exported.debt = {}
	check(not Rules.new().import_state(exported), "Malformed pending debt cannot enter a resumed game")
	exported = game().export_state(); exported.phase = "auction"; exported.auction = {}
	check(not Rules.new().import_state(exported), "Malformed saved auction is rejected")
	var random := RandomNumberGenerator.new(); random.seed = 37017
	for count in [2, 3, 6]:
		r = game(count)
		for step in 2200:
			if r.s.phase == "finished": break
			var seat: int = r.actor(); var input: Dictionary = Computer.choose(r.view_for(seat), 1, random); input.revision = int(r.s.revision)
			if not r.apply(seat, input): check(false, "Computer must submit a legal offered decision"); break
			if step % 100 == 0 and not Rules.new().import_state(JSON.parse_string(JSON.stringify(r.export_state()))): check(false, "Simulation phase must round-trip through a save"); break
		check(r.s.cash.all(func(value: Variant) -> bool: return int(value) >= 0) and r.buildings_available().houses >= 0 and r.buildings_available().hotels >= 0, "%d-player simulation conserves money bounds and physical building stock" % count)
		if r.s.phase != "finished": r.finish("time")
		check(r.s.winner >= 0, "%d-player game reaches one winner" % count)
	await _session_checks()
	print("Monopoly Classic: %d checks, %d failures" % [checks, failures])
	for host in instances:
		host.shutdown_game(); host.queue_free()
	await process_frame
	quit(1 if failures else 0)


func make_host(solo := false):
	var host = load("res://Games/monopoly-classic/host/main.tscn").instantiate()
	host.settings_store = preload("res://tests/game_settings_fixture.gd").new()
	host.saved_game.path = "res://.test_data/classic-tests/%d-%d.json" % [OS.get_process_id(), host.get_instance_id()]
	root.add_child(host); instances.append(host)
	var players := [] if solo else [{"id": "alice", "display_name": "Alice", "color": "#e53935", "pose": 0}, {"id": "bob", "display_name": "Bob", "color": "#2463eb", "pose": 1}]
	var context := GameSessionContext.new("monopoly-classic", players, {"id": "host", "display_name": "Host", "color": "#08a750", "pose": 2}, not solo)
	context.reduced_motion = true
	host.initialize_session(context); host.start_game(); host.set_process(false)
	host.rules.s.turn = 0; host.rules.s.phase = "roll"; host._sync_clocks(); host._publish()
	return host


func _session_checks() -> void:
	var host = make_host()
	await process_frame
	check(host.options.turn_timer and host.options.turn_seconds == 60 and not host.options.game_timer and host.options.game_seconds == 3600, "Requested timer defaults")
	check(host.seats.size() == 2 and not host.practice, "Multiplayer defaults to no computers")
	var earlier: Dictionary = host.saved_game.load_game()
	var legacy: Dictionary = earlier.duplicate(true); legacy.options.continue_disconnected = false
	check(host.saved_game.valid(legacy) and not host._normalize_options(legacy.options).has("continue_disconnected"), "Older saves remain readable and cannot override automatic timer-based continuation")
	host.player_disconnected("alice")
	check(not host._paused(), "An enabled turn timer always permits continuation after disconnect")
	host.options.turn_timer = false
	check(host._paused(), "A disabled turn timer always waits for reconnection")
	host.options.turn_timer = true
	check(not host._paused(), "Continue with an active turn timer permits countdown")
	host._step(60.1)
	check(host.practice, "Timed-out disconnected player permanently marks practice")
	host.player_reconnected({"id": "alice"})
	check(host.practice, "Reconnection never clears practice")
	var save: Dictionary = host.saved_game.load_game()
	check(not save.is_empty() and save.practice, "Autosave preserves the sticky AI flag")
	host.saved_game.save_game(earlier)
	check(host.saved_game.load_game().practice, "Restoring an older checkpoint cannot erase that game's AI history")
	var broken := FileAccess.open(host.saved_game.path, FileAccess.WRITE); broken.store_string("broken"); broken.close()
	check(host.saved_game.load_game().practice, "Backup recovery preserves the external sticky practice marker")
	host._save()
	var results: Array = []; var points: Array = []
	host.result_reported.connect(func(id: String, won: bool) -> void: results.append([id, won]))
	host.points_awarded.connect(func(id: String, amount: int) -> void: points.append([id, amount]))
	host.rules.finish("time"); host._record_results()
	check(results.is_empty() and points.is_empty(), "Any timeout AI forbids every saved win, loss and point")
	host = make_host(); results = []; points = []
	host.result_reported.connect(func(id: String, won: bool) -> void: results.append([id, won]))
	host.points_awarded.connect(func(id: String, amount: int) -> void: points.append([id, amount]))
	host.rules.s.owners[39] = 1; host.rules.finish("time"); host._record_results(); host._record_results()
	check(results.size() == 2 and results.has(["bob", true]) and results.has(["alice", false]) and points == [["bob", 1]], "All-human result records one winner and every other player loses, exactly once")
	broken = FileAccess.open(host.saved_game.path, FileAccess.WRITE); broken.store_string("broken"); broken.close()
	check(host.saved_game.load_game().is_empty(), "A completed-game marker prevents replaying an unfinished backup for duplicate records")
	var old_revision := int(host.rules.s.revision)
	host._new_round(true)
	check(int(host.rules.s.revision) > old_revision and not host.rules.apply(0, {"action": "roll", "revision": old_revision}), "Replay advances revision and rejects commands from the previous game")
	host = make_host(); host.ui.settings_toggle.button_pressed = true
	var remaining: float = host.turn_remaining; host._step(80)
	check(host.turn_remaining == remaining and not host.practice, "Host Settings pauses the turn timer and cannot cause practice autoplay")
	host.ui.settings_toggle.button_pressed = false
	host.options.game_timer = true; host.game_remaining = .1; host.rules.s.owners[39] = 1; host._step(.2)
	check(host.rules.s.phase == "finished" and host.rules.s.winner == 1 and not host.practice, "Whole-game deadline selects wealth without introducing AI")
	await _resume_check()
	host = make_host(true)
	check(host.practice and host.seats.size() == 2, "Solo defaults to one practice computer")
	for number in range(1, 6):
		host.options.solo_ai = number; host._new_round(false)
		check(host.seats.size() == number + 1, "Solo supports %d AI opponents" % number)
	var catalog := GameCatalog.new(); catalog.scan()
	check(catalog.find_game("monopoly-deal").max_players == 5 and catalog.find_game("monopoly-classic").max_players == 6, "Separate preserved Deal and Classic player limits")
	check(catalog.menu_games().filter(func(item: Dictionary) -> bool: return str(item.id).begins_with("monopoly")).size() == 1 and not catalog.find_game("monopoly-deal").is_empty(), "One Monopoly menu entry retains both child controller routes")


func _resume_check() -> void:
	var host = make_host()
	host.rules.s.owners[1] = 0; host.rules.s.owners[5] = 1
	host._act(0, {"action": "offer_trade", "to": 1, "give_cash": 50, "take_cash": 0, "give_properties": [1], "take_properties": [5], "give_jail": [], "take_jail": []})
	host.turn_remaining = 17.25; host.response_remaining = 11.5; host.practice = true; host.saved_game.mark_practice(host.round_id); host._save()
	var arguments := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/monopoly_classic_resume_probe.gd", "--", host.saved_game.path])
	var output: Array = []
	OS.execute(OS.get_executable_path(), arguments, output, true)
	var result_path: String = host.saved_game.path + ".probe.json"
	check(FileAccess.file_exists(result_path), "Fresh process writes its resume verification")
	if FileAccess.file_exists(result_path):
		var result: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(result_path))
		check(result.resumed and result.phase == "trade" and result.practice and result.round_id == host.round_id, "Fresh process resumes exact pending trade, identities and AI history")
		check(is_equal_approx(float(result.turn), 17.25) and is_equal_approx(float(result.response), 11.5), "Fresh process restores both turn and response time")
		check(int(result.records) == 0, "Resumed practice game cannot emit profile results")
	await process_frame
