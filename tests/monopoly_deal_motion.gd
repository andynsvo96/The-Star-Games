extends SceneTree
var checks := 0
var failures := 0

func _init() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + message)

func _run() -> void:
	var gesture := GameDragScroll.new()
	gesture.begin(Vector2(100, 20)); gesture.move(Vector2(97, 20)); check(gesture.end(), "A simple tap selects")
	gesture.begin(Vector2(100, 20)); check(gesture.move(Vector2(40, 20)) == 60 and not gesture.end(), "Dragging browses without selecting")
	var host = load("res://Games/monopoly-deal/host/main.tscn").instantiate(); root.add_child(host)
	host.settings_store = preload("res://tests/game_settings_fixture.gd").new()
	var players: Array = []
	for index in 5: players.append({"id":str(index),"display_name":"Player %d" % index,"color":"#2463eb"})
	var context := GameSessionContext.new("monopoly-deal", players, {}, true)
	host.initialize_session(context); host.start_game()
	var public: Dictionary = host._snapshot(-1); var own: Dictionary = host._snapshot(0)
	check(host.animating and public.motion.shuffle > 0 and public.motion.flights.size() == 27, "Five-player starts shuffle then deal 25 plus 2 cards")
	check(public.motion.flights.all(func(f: Dictionary) -> bool: return f.card == {"back":true}), "Public deal flights never reveal private IDs or faces")
	check(own.motion.flights.filter(func(f: Dictionary) -> bool: return f.card.has("id")).size() == 7, "Only the recipient sees their seven dealt faces")
	check(not host._action(0,{"action":"end","revision":host.rules.revision}), "Host rejects input throughout the deal")
	await create_timer(0.12).timeout; host.player_disconnected("1")
	var elapsed: float = host._snapshot(0).motion.elapsed; await create_timer(0.12).timeout
	check(is_equal_approx(elapsed, float(host._snapshot(0).motion.elapsed)), "Disconnect freezes the shared presentation clock")
	host.player_reconnected(players[1]); check(host._snapshot(0).motion.revision == own.motion.revision, "Reconnect resumes the same deal")
	host.settings_button.button_pressed = true; elapsed = host._snapshot(0).motion.elapsed; await create_timer(0.12).timeout
	check(is_equal_approx(elapsed, float(host._snapshot(0).motion.elapsed)) and host.motion_timer.paused, "Settings freezes an in-progress deal and its shared movement clock")
	host.settings_button.button_pressed = false
	await create_timer(host.motion_timer.time_left + 0.1).timeout
	check(not host.animating, "Deal releases input after the last pickup lands")
	var go: Dictionary = host.rules.cards.filter(func(c: Dictionary) -> bool: return c.kind == "pass-go")[0]
	for seat in 5: host.rules.hands[seat].erase(int(go.id))
	host.rules.deck.erase(int(go.id)); host.rules.hands[0].append(int(go.id)); host.rules.turn = 0
	check(host._action(0,{"action":"go","card":go.id,"revision":host.rules.revision}), "Pass Go begins a discard and draw timeline")
	public = host._snapshot(-1)
	check(public.motion.flights[0].to.zone == "discard" and public.motion.flights[0].card.id == go.id, "Played card visibly travels into the discard pile first")
	check(public.motion.flights.filter(func(f: Dictionary) -> bool: return f.to.zone == "hand" and f.card == {"back":true}).size() == 2, "Draw two flights conceal both picked-up cards from others")
	host.shutdown_game(); host.queue_free(); await process_frame
	host = load("res://Games/monopoly-deal/host/main.tscn").instantiate(); root.add_child(host); host.settings_store = preload("res://tests/game_settings_fixture.gd").new()
	context = GameSessionContext.new("monopoly-deal", [], {"id":"solo","display_name":"Host","color":"#2463eb"}); context.reduced_motion = true
	host.initialize_session(context); host.start_game(); host.ai_timer.stop()
	host.rules.turn = 0
	check(not host.animating, "Reduced motion skips shuffle and flights")
	var wild: Dictionary = host.rules.cards.filter(func(c: Dictionary) -> bool: return c.kind == "wild" and c.colors.size() == 2)[0]
	host.rules.hands[0] = [int(wild.id)]; host._publish(); host.ai_timer.stop(); host._select_card(wild); host._open_selected()
	check(host.reader.rotate_row.visible and host.focused_side == 0, "Two-color wild opens with its upright side selected")
	host.reader.rotate_button.pressed.emit()
	check(host.focused_side == 1 and is_equal_approx(host.reader.card.rotation, PI), "Rotate changes the side, with immediate reduced-motion positioning")
	host._choose_card_play()
	check(host.rules.properties[0].size() == 1 and host.rules.properties[0][0].color == wild.colors[1] and not host.reader.visible, "Add property uses the upright side without an extra color prompt")
	check(host.rules.cards.all(func(c: Dictionary) -> bool: return c.currency == "USD" and not c.name.ends_with("M")), "Card metadata consistently uses dollar currency")
	host.shutdown_game(); host.queue_free(); await process_frame; RuntimeAssets.refresh()
	print("Monopoly Deal motion: %d checks, %d failures" % [checks, failures]); quit(1 if failures else 0)
