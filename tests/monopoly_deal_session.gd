extends SceneTree
var checks := 0
var failures := 0
var points: Array = []
var results: Array = []

func _init() -> void: call_deferred("_run")
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + text)

func _run() -> void:
	var host = load("res://Games/monopoly-deal/host/main.tscn").instantiate(); root.add_child(host)
	host.settings_store = preload("res://tests/game_settings_fixture.gd").new()
	var players := [{"id":"a","display_name":"Alex","color":"#2463eb"},{"id":"b","display_name":"Nina","color":"#e53935"}]
	var context := GameSessionContext.new("monopoly-deal",players,{},true); context.reduced_motion = true
	host.initialize_session(context); host.start_game(); host.points_awarded.connect(func(id: String,amount: int) -> void: points.append([id,amount])); host.result_reported.connect(func(id: String,won: bool) -> void: results.append([id,won]))
	for seat in 2: host.rules.hands[seat].clear(); host.rules.properties[seat].clear()
	var keys := ["mediterranean-avenue","baltic-avenue","park-place","boardwalk","electric-company","water-works"]
	var ids: Array = keys.map(func(key: String) -> int: return int(host.rules.cards.filter(func(card: Dictionary) -> bool: return card.key == key)[0].id))
	host.rules._put_property(0,ids[0],"brown"); host.rules._put_property(0,ids[1],"brown",0); host.rules._put_property(0,ids[2],"dark-blue"); host.rules._put_property(0,ids[3],"dark-blue",1); host.rules._put_property(0,ids[4],"utility"); host.rules.hands[0] = [ids[5]]; host.rules.revision += 1
	var input := {"action":"property","card":ids[5],"color":"utility","group":2,"revision":host.rules.revision}
	check(host._action(0,input) and host.wins == [1,0] and points == [["a",1]] and results.size() == 2,"A completed human game awards one saved point and one result per player")
	check(not host._action(0,input) and points.size() == 1 and results.size() == 2,"Duplicate winner input cannot score again")
	host._replay(); check(host.rules.starter == 1 and host.wins == [1,0] and host.rules.winner < 0 and host.rules.hands[0].size() == 5,"Replay rotates starter, redeals and preserves wins")
	host.pending_theme = "missing-pack"; host.pending_difficulty = 2; host._refresh_options(); host._apply_options()
	check(host.skin.id == "default" and host.rules.winner < 0 and points.size() == 1,"Invalid saved theme falls back safely and an abandoned game scores nothing")
	host.player_disconnected("b"); var revision: int = host.rules.revision
	check(not host._action(0,{"action":"end","revision":revision}) and host.rules.revision == revision,"Disconnected seats stay fixed and freeze input")
	host.player_reconnected(players[1]); check(host.missing.is_empty(),"Reconnect restores the admitted seat")
	host.shutdown_game(); host.queue_free(); await process_frame
	host = load("res://Games/monopoly-deal/host/main.tscn").instantiate(); root.add_child(host); host.settings_store = preload("res://tests/game_settings_fixture.gd").new()
	context = GameSessionContext.new("monopoly-deal",[],{"id":"host","display_name":"Host","color":"#08a750"}); context.reduced_motion = true; host.initialize_session(context); host.start_game()
	check(host.host_plays and host.seats.size() == 3 and host.seats[1].ai and host._snapshot(0).hand.size() == (7 if host.rules.turn == 0 else 5),"Solo uses a random starter, the host's private hand and two AI opponents by default")
	host.pending_count = 4; host.pending_difficulty = 2; host._refresh_options(); host._apply_options()
	check(host.seats.size() == 5 and host.difficulty == 2 and host.rules.hands.size() == 5,"Solo settings support four computer opponents and restart safely")
	check(host.load_game_settings({"computers":2}).computers == 4,"Applied preferences persist through the shared settings store")
	host.ai_timer.stop(); host.rules.start(5)
	var money: Dictionary = host.rules.cards.filter(func(card: Dictionary) -> bool: return card.kind == "money")[0]
	var go: Dictionary = host.rules.cards.filter(func(card: Dictionary) -> bool: return card.kind == "pass-go")[0]
	host.rules.hands[0] = [int(money.id), int(go.id)]; host._publish(); host.ai_timer.stop()
	host._select_card(money)
	check(host.reader.visible and host.table.selected_card == int(money.id) and not host.rules.banks[0].has(int(money.id)), "Native tap immediately enlarges without playing")
	check(host.table.action_row.get_children().all(func(button: Button) -> bool: return button == host.table.end_button or button == host.replay or button.text in ["Public Table", "Help"]), "Main table contains navigation, Help, End Turn and its reserved replay control")
	var stale_bank: Button = host.reader.actions.get_children().filter(func(button: Button) -> bool: return button.text == "BANK")[0]
	host.rules.revision += 1; host._publish(); host.ai_timer.stop(); stale_bank.pressed.emit()
	check(not host.rules.banks[0].has(int(money.id)), "A stale table action cannot submit against a newer revision")
	var bank_button: Button = host.reader.actions.get_children().filter(func(button: Button) -> bool: return button.text == "BANK")[0]
	bank_button.pressed.emit()
	check(host.rules.banks[0].has(int(money.id)) and not host.reader.visible, "Reader Bank submits the selected money and closes")
	host._select_card(go)
	var stale_play: Button = host.reader.actions.get_children().filter(func(button: Button) -> bool: return button.text == "Draw 2 cards")[0]
	host.rules.revision += 1; host._publish(); host.ai_timer.stop(); stale_play.pressed.emit()
	check(not host.rules.discard.has(int(go.id)) and host.focused_card == int(go.id), "Stale table Play is ignored and preserves current selection")
	host._select_card(go); host._open_selected()
	check(host.reader.visible and host.reader.actions.get_child(2).text == "Draw 2 cards", "Pass Go focus offers Bank and Draw")
	host.reader.actions.get_child(2).pressed.emit()
	check(host.rules.discard.has(int(go.id)) and not host.reader.visible, "Reader Draw plays Pass Go")
	host.rules.start(5); host.rules.hands[0] = [int(go.id)]; host.rules.turn = 1; host._publish(); host.ai_timer.stop(); host._select_card(go); host._open_selected(); host._open_selected()
	check(host.reader.visible and host.reader.actions.get_child_count() == 1, "Off-turn hand cards can be read with Back only")
	host.reader.close(); var opponent: int = host.rules.hands[1].filter(func(id: int) -> bool: return not host.rules.hands[0].has(id))[0]
	host._select_card(host.rules.cards[opponent])
	check(not host.reader.visible, "Host cannot focus an opponent's hidden card")
	host._help(); check(host.reader.visible and host.reader.pages.size() == 2 and host.reader.page == 0, "Help opens a full-screen front/back reference card")
	host.reader.flip.pressed.emit(); check(host.reader.page == 1 and host.reader.flip.text.is_empty() and host.reader.flip.accessibility_name == "Flip to front", "Help flips to Essential Rules with an accessible icon")
	host.reader.close()
	check(not host.find_children("*","Button",true,false).any(func(button: Button) -> bool: return button.text.contains("Bank mode")), "Bank mode has been removed")
	check(host.history_button.text == "HISTORY", "Native game retains the host's explicit History control")
	host.rules.start(5); host.rules.hands[0] = [int(money.id)]; host._publish(); host.ai_timer.stop(); host._select_card(money)
	var solo_bank: Button = host.reader.actions.get_children().filter(func(button: Button) -> bool: return button.text == "BANK")[0]
	host.host_plays = false; host._publish(); host.ai_timer.stop()
	check(host.focused_card == -1 and host.table.action_row.get_children().filter(func(button: Button) -> bool: return button != host.table.end_button and button != host.replay).all(func(button: Button) -> bool: return button.text == "Public Table"), "Public hosts clear private selection and expose public browsing only")
	solo_bank.pressed.emit()
	check(not host.rules.banks[0].has(int(money.id)), "An obsolete solo toolbar cannot play a phone player's cards")
	host.shutdown_game(); host.queue_free(); await process_frame; RuntimeAssets.refresh(); await create_timer(0.15).timeout
	print("Monopoly Deal session: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
