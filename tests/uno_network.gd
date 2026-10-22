extends SceneTree

var app: Control
var checks := 0
var failures := 0


func _init() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)


func packet(socket: WebSocketPeer, type: String, private := false, minimum_revision := -1) -> Dictionary:
	for frame in 600:
		socket.poll()
		while socket.get_available_packet_count() > 0:
			var value: Variant = JSON.parse_string(socket.get_packet().get_string_from_utf8())
			if value is Dictionary and value.get("type") == type and (not private or value.get("payload", {}).get("viewer", -1) >= 0) and value.get("payload", {}).get("revision", -1) >= minimum_revision:
				return value
		await process_frame
	return {}


func join_phone(name: String, token := "") -> Dictionary:
	var socket := WebSocketPeer.new()
	socket.connect_to_url("ws://127.0.0.1:%d/" % app.lan_server.websocket_port)
	await packet(socket, "hello")
	socket.send_text(JSON.stringify({"type": "join", "name": name, "reconnect_token": token}))
	return {"socket": socket, "joined": await packet(socket, "joined")}


func declare_uno(socket: WebSocketPeer, revision: int) -> int:
	socket.send_text(JSON.stringify({"type":"game", "game_id":"uno", "payload":{"action":"uno", "revision":revision}}))
	var declared: Dictionary = (await packet(socket, "game", true, revision + 1)).payload
	check(declared.uno_armed and declared.hand.size() == 2, "Real UNO declaration keeps both cards until a separate play")
	return int(declared.revision)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://.test_data/uno-network")
	app = load("res://Main.tscn").instantiate()
	app.profile_store = ProfileStore.new("res://.test_data/uno-network/profiles.json")
	app.game_settings_store = preload("res://tests/game_settings_fixture.gd").new()
	root.add_child(app)
	app.profile_store.data.settings.reduced_motion = true
	app._enter_lobby()
	var phones: Array = []
	for index in 3:
		phones.append(await join_phone("UNO Player %d" % index))
	check(phones.all(func(phone: Dictionary) -> bool: return not phone.joined.is_empty()), "Three real controller sockets join through the launcher")
	app._play_from_lobby()
	var module: Dictionary = app.game_catalog.games.filter(func(game: Dictionary) -> bool: return game.id == "uno")[0]
	check(app._can_launch(module), "UNO launches from a three-human party")
	app._launch_game(module)
	await process_frame
	check(app.active_game.seats.size() == 4 and app.active_game.seats.filter(func(player: Dictionary) -> bool: return player.ai).size() == 1, "One AI fills the three-human table")
	for phone in phones:
		var view: Dictionary = (await packet(phone.socket, "game", true)).payload
		check(view.players[view.viewer].id == phone.joined.player.id and view.hand.size() in [7, 9] and not JSON.stringify(view).contains("reconnect_token"), "Raw socket payload contains only its recipient's private hand and safe identities")
	var own: Array = app.active_game.rules.hands[app.active_game._seat_for(phones[0].joined.player.id)].duplicate()
	phones[0].socket.close()
	for frame in 180:
		phones[0].socket.poll()
		await process_frame
		if not app.active_game.missing.is_empty(): break
	check(not app.active_game.missing.is_empty() and app.active_game.ai_timer.is_stopped(), "Real disconnect pauses the table and AI")
	var refreshed := await join_phone("UNO Player 0", phones[0].joined.reconnect_token)
	check(refreshed.joined.get("game_id") == "uno" and refreshed.joined.player.id == phones[0].joined.player.id, "Refresh restores the same identity and UNO route")
	var restored: Dictionary = (await packet(refreshed.socket, "game", true)).payload
	check(restored.hand.map(func(card: Dictionary) -> int: return int(card.id)) == own and not restored.paused, "Reconnect restores the exact private hand")
	var game = app.active_game
	game.rules.allow_stacking = true
	game.ai_timer.stop()
	game.catch_timer.stop()
	var wild: int = game.rules.cards.filter(func(card: Dictionary) -> bool: return card.kind == "draw4")[0].id
	var remaining: int = game.rules.cards.filter(func(card: Dictionary) -> bool: return card.color == "blue" and card.kind == "3")[0].id
	game.rules.hands[0] = [wild, remaining]
	for seat in range(1, game.rules.hands.size()):
		game.rules.hands[seat].erase(wild)
		game.rules.hands[seat].erase(remaining)
	var stack_four: int = game.rules.cards.filter(func(card: Dictionary) -> bool: return card.kind == "draw4")[1].id
	for hand in game.rules.hands: hand.erase(stack_four)
	game.rules.hands[1].append(stack_four)
	var keep_plus: int = game.rules.cards.filter(func(card: Dictionary) -> bool: return card.kind == "draw4")[2].id
	for hand in game.rules.hands: hand.erase(keep_plus)
	game.rules.hands[2].append(keep_plus)
	game.rules.deck = range(108).filter(func(id: int) -> bool: return not game.rules.discard.has(id) and not game.rules.hands.any(func(hand: Array) -> bool: return hand.has(id)))
	game.rules.turn = 0
	game.rules.direction = 1
	game.rules.phase = "play"
	game.rules.drawn = -1
	game.rules.pending_draw = 0
	game.rules.revision += 1
	game._publish()
	var input_revision: int = game.rules.revision
	var target_count: int = game.rules.hands[1].size()
	input_revision = await declare_uno(refreshed.socket, input_revision)
	refreshed.socket.send_text(JSON.stringify({"type":"game", "game_id":"uno", "payload":{"action":"play", "card":wild, "color":"green", "revision":input_revision}}))
	var played: Dictionary = (await packet(refreshed.socket, "game", true, input_revision + 1)).payload
	var received: Dictionary = (await packet(phones[1].socket, "game", true, input_revision + 1)).payload
	check(played.hand.size() == 1 and played.catch_target == -1, "A real controller declares before playing without a confirmation step")
	check(played.uno_players[0] and received.uno_players[0], "The last-card UNO marker is authoritative and visible to every real controller")
	check(received.hand.size() == target_count and received.phase == "play" and received.turn == 1 and received.pending_draw == 4, "The next real controller receives the pending Draw Four total")
	check(received.motion.flights.size() == 1 and not received.has("challenge_result"), "Pending penalties do not reveal secret drawn cards")
	check(played.top.selected_color == "green" and received.top.selected_color == "green" and received.motion.flights[0].card.selected_color == "green", "Every controller receives the chosen Wild face color")
	check(played.latest_play == received.latest_play and played.latest_play.card.id == wild and played.latest_play.seat == 0 and played.latest_play.color == "green", "Recent-play feedback is the same accepted public card and chosen color for every real controller")
	check(played.latest_play.keys().all(func(key: String) -> bool: return key in ["number", "seat", "card", "color", "note"]) and not played.latest_play.has("hand"), "Recent-play feedback has no hidden hand or deck fields")
	phones[1].socket.send_text(JSON.stringify({"type":"game", "game_id":"uno", "payload":{"action":"play", "card":stack_four, "color":"blue", "revision":received.revision}}))
	var stacked: Dictionary = (await packet(phones[2].socket, "game", true, int(received.revision) + 1)).payload
	check(stacked.pending_draw == 8 and stacked.turn == 2 and stacked.color == "blue", "A second real controller stacks Draw Four to +8")
	var stacked_hand: Array = stacked.hand.map(func(card: Dictionary) -> int: return int(card.id))
	phones[2].socket.close()
	for frame in 180:
		phones[2].socket.poll()
		await process_frame
		if not game.missing.is_empty(): break
	var recipient := await join_phone("UNO Player 2", phones[2].joined.reconnect_token)
	var stack_restored: Dictionary = (await packet(recipient.socket, "game", true)).payload
	check(stack_restored.pending_draw == 8 and stack_restored.turn == 2 and stack_restored.hand.map(func(card: Dictionary) -> int: return int(card.id)) == stacked_hand and not stack_restored.paused, "Reconnect restores the same private hand and pending +8")
	recipient.socket.send_text(JSON.stringify({"type":"game", "game_id":"uno", "payload":{"action":"draw", "amount":1, "revision":stack_restored.revision}}))
	var taken: Dictionary = (await packet(recipient.socket, "game", true, int(stack_restored.revision) + 1)).payload
	check(taken.hand.size() == stacked_hand.size() + 8 and taken.pending_draw == 0 and taken.turn == 3, "Host delivers all eight cards despite a controller-supplied amount and skips that controller")
	check(taken.motion.flights[0].count == 8 and taken.motion.flights[0].card.is_empty(), "Penalty movement is count-only over real sockets")
	# Restore a deterministic board for real-socket hand swapping and jump-ins.
	game.ai_timer.stop()
	var red_seven: int = game.rules.cards.filter(func(card: Dictionary) -> bool: return card.color == "red" and card.kind == "7")[0].id
	game.rules.allow_seven_zero = true
	game.rules.allow_jump_ins = true
	game.rules.hands = [[red_seven, remaining], [27, 57], [15, 81], [61, 38]]
	game.rules.discard = [17]
	game.rules.deck = range(108).filter(func(id: int) -> bool: return not game.rules.discard.has(id) and not game.rules.hands.any(func(hand: Array) -> bool: return hand.has(id)))
	game.rules.turn = 0
	game.rules.color = "red"
	game.rules.phase = "play"
	game.rules.drawn = -1
	game.rules.pending_draw = 0
	game.rules.revision += 1
	game._publish()
	input_revision = game.rules.revision
	input_revision = await declare_uno(refreshed.socket, input_revision)
	refreshed.socket.send_text(JSON.stringify({"type":"game", "game_id":"uno", "payload":{"action":"play", "card":red_seven, "revision":input_revision}}))
	var choose_swap: Dictionary = (await packet(refreshed.socket, "game", true, input_revision + 1)).payload
	var observer: Dictionary = (await packet(recipient.socket, "game", true, input_revision + 1)).payload
	check(choose_swap.phase == "swap" and choose_swap.swap_targets.map(func(seat: float) -> int: return int(seat)) == [1, 2, 3] and observer.swap_targets.is_empty(), "Only the real Seven player receives swap choices")
	var original_other: Array = game.rules.hands[2].duplicate()
	refreshed.socket.close()
	for frame in 180:
		refreshed.socket.poll()
		await process_frame
		if not game.missing.is_empty(): break
	refreshed = await join_phone("UNO Player 0", refreshed.joined.reconnect_token)
	var swap_restored: Dictionary = (await packet(refreshed.socket, "game", true)).payload
	check(swap_restored.phase == "swap" and swap_restored.swap_targets.map(func(seat: float) -> int: return int(seat)) == [1, 2, 3] and not swap_restored.paused, "Real reconnect restores the pending swap prompt")
	refreshed.socket.send_text(JSON.stringify({"type":"game", "game_id":"uno", "payload":{"action":"swap", "target":2, "revision":swap_restored.revision}}))
	var swapped: Dictionary = (await packet(refreshed.socket, "game", true, int(swap_restored.revision) + 1)).payload
	var swapped_other: Dictionary = (await packet(recipient.socket, "game", true, int(swap_restored.revision) + 1)).payload
	check(swapped.hand.map(func(card: Dictionary) -> int: return int(card.id)) == original_other and swapped_other.hand.map(func(card: Dictionary) -> int: return int(card.id)) == [remaining] and swapped.turn == 1, "Real swap delivers each exchanged hand only to its new owner")
	check(swapped.motion.flights.all(func(flight: Dictionary) -> bool: return flight.kind == "hand" and flight.card.is_empty()), "Swap movement contains no private faces over real sockets")
	game.rules.hands = [[9, remaining], [27, 57], [10, 81], [61, 38]]
	game.rules.discard = [17]
	game.rules.deck = range(108).filter(func(id: int) -> bool: return not game.rules.discard.has(id) and not game.rules.hands.any(func(hand: Array) -> bool: return hand.has(id)))
	game.rules.turn = 0
	game.rules.color = "red"
	game.rules.revision += 1
	game._publish()
	input_revision = game.rules.revision
	input_revision = await declare_uno(refreshed.socket, input_revision)
	refreshed.socket.send_text(JSON.stringify({"type":"game", "game_id":"uno", "payload":{"action":"play", "card":9, "revision":input_revision}}))
	var jump_view: Dictionary = (await packet(recipient.socket, "game", true, input_revision + 1)).payload
	check(jump_view.turn == 1 and jump_view.jump_cards.map(func(id: float) -> int: return int(id)) == [10] and jump_view.legal_cards.map(func(id: float) -> int: return int(id)) == [10], "An out-of-turn real controller receives its exact-card jump-in opportunity")
	input_revision = await declare_uno(recipient.socket, int(jump_view.revision))
	recipient.socket.send_text(JSON.stringify({"type":"game", "game_id":"uno", "payload":{"action":"play", "card":10, "revision":input_revision}}))
	var jumped: Dictionary = (await packet(recipient.socket, "game", true, input_revision + 1)).payload
	check(jumped.turn == 3 and jumped.top.id == 10 and jumped.hand.size() == 1, "Real jump-in changes turn order after declaring UNO separately")
	game.ai_timer.stop()
	game.rules.hands = [[remaining], [9, 27], [13, 57], [15, 61]]
	game.rules.discard = [17]
	game.rules.deck = range(108).filter(func(id: int) -> bool: return not game.rules.discard.has(id) and not game.rules.hands.any(func(hand: Array) -> bool: return hand.has(id)))
	for id in [3, 85, 79]: game.rules.deck.erase(id)
	game.rules.deck.append_array([3, 85, 79])
	game.rules.turn = 0
	game.rules.color = "red"
	game.rules.drawn = -1
	game.rules.draw_until_play = true
	game.rules.force_play = false
	game.rules.revision += 1
	game._publish()
	var sequence_revision: int = game.rules.revision
	var drawn_sequence: Dictionary = (await packet(refreshed.socket, "game", true, sequence_revision + 3)).payload
	check(drawn_sequence.hand.size() == 4 and drawn_sequence.drawn == 3 and drawn_sequence.turn == 0 and drawn_sequence.legal_cards.size() == 1, "Real controller receives automatic draws up to the first playable card without sending Draw")
	var draw_observer: Dictionary = (await packet(recipient.socket, "game", true, sequence_revision + 3)).payload
	check(draw_observer.drawn == -1 and draw_observer.hand.size() == 2 and draw_observer.motion.flights[0].card.is_empty(), "Automatic draw sequences preserve other controllers' private hands and reveal only count-based movement")
	game.rules.force_play = true # Fixture for a forced draw; options are tested below.
	game._publish()
	var force_revision: int = game.rules.revision
	refreshed.socket.send_text(JSON.stringify({"type":"game", "game_id":"uno", "payload":{"action":"pass", "revision":force_revision}}))
	for frame in 3: await process_frame
	check(game.rules.revision == force_revision and game.rules.drawn == 3, "A real controller cannot keep the drawn card after Force Play is enabled")
	var forced_played: Dictionary = (await packet(refreshed.socket, "game", true, force_revision + 1)).payload
	check(forced_played.top.id == 3 and forced_played.hand.size() == 3 and forced_played.drawn == -1, "Host automatically plays the focused card over real controller sockets")
	game.rules.hands = [[remaining], [9, 27], [13, 57], [15, 61]]
	game.rules.discard = [17]
	game.rules.deck = range(108).filter(func(id: int) -> bool: return not game.rules.discard.has(id) and not game.rules.hands.any(func(hand: Array) -> bool: return hand.has(id)))
	game.rules.deck.erase(100)
	game.rules.deck.append(100)
	game.rules.turn = 0
	game.rules.color = "red"
	game.rules.phase = "play"
	game.rules.drawn = -1
	game.rules.revision += 1
	game._publish()
	var forced_wild: Dictionary = (await packet(refreshed.socket, "game", true, game.rules.revision + 1)).payload
	check(forced_wild.phase == "drawn_color" and forced_wild.drawn == 100 and forced_wild.hand.size() == 2, "Automatically drawn Wild waits for a color choice with Force Play")
	refreshed.socket.close()
	for frame in 180:
		refreshed.socket.poll()
		await process_frame
		if not game.missing.is_empty(): break
	refreshed = await join_phone("UNO Player 0", refreshed.joined.reconnect_token)
	var forced_restored: Dictionary = (await packet(refreshed.socket, "game", true)).payload
	check(forced_restored.phase == "drawn_color" and forced_restored.drawn == 100 and not forced_restored.paused, "Reconnect restores the forced Wild choice and the exact drawn card")
	refreshed.socket.send_text(JSON.stringify({"type":"game", "game_id":"uno", "payload":{"action":"uno", "revision":forced_restored.revision}}))
	var armed_wild: Dictionary = (await packet(refreshed.socket, "game", true, int(forced_restored.revision) + 1)).payload
	refreshed.socket.send_text(JSON.stringify({"type":"game", "game_id":"uno", "payload":{"action":"color", "color":"blue", "revision":armed_wild.revision}}))
	var color_played: Dictionary = (await packet(refreshed.socket, "game", true, int(armed_wild.revision) + 1)).payload
	check(color_played.top.id == 100 and color_played.top.selected_color == "blue" and color_played.hand.size() == 1 and color_played.catch_target == -1, "Forced Wild color selection plays immediately and respects the real player's UNO declaration")
	check(color_played.uno_players[0], "A forced Wild retains its declared last-card marker")
	# Missing UNO is penalized by the host, without a catch message from anyone.
	game.rules.hands = [[9,remaining], [10,27], [13,57], [15,61]]
	game.rules.discard = [17]
	game.rules.deck = range(108).filter(func(id: int) -> bool: return not game.rules.discard.has(id) and not game.rules.hands.any(func(hand: Array) -> bool: return hand.has(id)))
	game.rules.turn = 0
	game.rules.color = "red"
	game.rules.phase = "play"
	game.rules.drawn = -1
	game.rules.force_play = false
	game.rules.draw_until_play = false
	game.rules.armed.fill(false)
	game.rules.revision += 1
	game._publish()
	input_revision = game.rules.revision
	refreshed.socket.send_text(JSON.stringify({"type":"game", "game_id":"uno", "payload":{"action":"play", "card":9, "revision":input_revision}}))
	var missed: Dictionary = (await packet(refreshed.socket,"game",true,input_revision + 1)).payload
	check(missed.hand.size() == 3 and missed.turn == 1 and missed.catch_target == -1, "A real play without a prior UNO automatically draws two cards and advances the turn")
	check(missed.motion.flights.size() == 2 and missed.motion.flights[1].count == 2 and missed.motion.flights[1].card.is_empty(), "Real missed-UNO snapshots keep penalty card faces private")
	refreshed.socket.send_text(JSON.stringify({"type":"game", "game_id":"uno", "payload":{"action":"uno", "revision":missed.revision}}))
	for frame in 3: await process_frame
	check(game.rules.revision == int(missed.revision) and game.rules.hands[0].size() == 3, "A late real UNO message cannot remove the automatic penalty")
	game.pending_options = game.rules.view_for(-1).options.duplicate()
	var old_hand: Array = game.rules.hands[0].duplicate()
	var old_round: int = game.rules.round_number
	game._set_difficulty(2)
	game._set_rule("force_play",true)
	game._publish()
	check(game.rules.hands[0] == old_hand and game._snapshot(0).difficulty == 1 and not game._snapshot(0).options.force_play, "Host option edits leave real controllers on the current hand and active settings")
	game._apply_options()
	var applied: Dictionary = (await packet(refreshed.socket,"game",true,int(missed.revision) + 1)).payload
	check(applied.round == old_round + 1 and applied.difficulty == 2 and applied.options.force_play and applied.players[0].id == refreshed.joined.player.id, "Apply sends a fresh hand and new options over the existing controller connection")
	# Classic add-on choices use the same authenticated socket and private snapshots.
	game._set_addon("love_island", true)
	game._apply_options()
	game.auto_timer.process_mode = Node.PROCESS_MODE_DISABLED
	game.ai_timer.process_mode = Node.PROCESS_MODE_DISABLED
	game.rules.addons.reset()
	var chat: int = game.rules.cards.filter(func(card: Dictionary) -> bool: return card.kind == "chat")[0].id
	game.rules.hands = [[chat,remaining,9],[10,27,58],[13,57],[15,61]]
	game.rules.discard = [17]
	game.rules.deck = range(game.rules.cards.size()).filter(func(id: int) -> bool: return not game.rules.discard.has(id) and not game.rules.hands.any(func(hand: Array) -> bool: return hand.has(id)))
	game.rules.turn = 0
	game.rules.phase = "play"
	game.rules.drawn = -1
	game.rules.pending_draw = 0
	game.rules.force_play = false
	game.rules.armed.fill(false)
	game.rules.revision += 1
	game._publish()
	input_revision = game.rules.revision
	refreshed.socket.send_text(JSON.stringify({"type":"game", "game_id":"uno", "payload":{"action":"play", "card":chat,"color":"red", "revision":input_revision}}))
	var chat_choice: Dictionary = (await packet(refreshed.socket,"game",true,input_revision + 1)).payload
	check(chat_choice.addon_choice.kind == "chat" and chat_choice.enabled_addons.love_island, "Add-on card creates a private target choice over real sockets")
	check(chat_choice.player_choice.action == "addon_choose" and chat_choice.player_choice.targets == chat_choice.addon_choice.targets and game._snapshot(-1).player_choice.is_empty() and game._snapshot(1).player_choice.is_empty(), "Badge target metadata is authoritative and private to the chooser")
	refreshed.socket.close()
	for frame in 180:
		refreshed.socket.poll()
		await process_frame
		if not game.missing.is_empty(): break
	refreshed = await join_phone("UNO Player 0", refreshed.joined.reconnect_token)
	var restored_target: Dictionary = (await packet(refreshed.socket,"game",true)).payload
	check(restored_target.player_choice == chat_choice.player_choice and not restored_target.paused, "Reconnection restores the exact pending player-badge choice")
	chat_choice = restored_target
	phones[1].socket.send_text(JSON.stringify({"type":"game", "game_id":"uno", "payload":{"action":"addon_choose", "target":2,"revision":chat_choice.revision}}))
	for frame in 4: await process_frame
	check(game.rules.revision == int(chat_choice.revision), "An opponent cannot submit the chooser's add-on decision")
	refreshed.socket.send_text(JSON.stringify({"type":"game", "game_id":"uno", "payload":{"action":"addon_choose", "target":1,"revision":chat_choice.revision}}))
	var peek: Dictionary = (await packet(refreshed.socket,"game",true,int(chat_choice.revision) + 1)).payload
	var hidden_peek: Dictionary = (await packet(recipient.socket,"game",true,int(chat_choice.revision) + 1)).payload
	check(peek.addon_choice.kind == "chat_take" and peek.addon_choice.cards.size() == game.rules.hands[1].size() and hidden_peek.addon_choice.is_empty() and game._snapshot(-1).addon_choice.is_empty(), "Chat discloses the selected hand only to the authorized chooser")
	check(peek.player_choice.is_empty() and hidden_peek.player_choice.is_empty(), "Choosing a player clears targeting before a private card decision")
	refreshed.socket.close()
	for frame in 180:
		refreshed.socket.poll()
		await process_frame
		if not game.missing.is_empty(): break
	refreshed = await join_phone("UNO Player 0", refreshed.joined.reconnect_token)
	var peek_restored: Dictionary = (await packet(refreshed.socket,"game",true)).payload
	check(peek_restored.addon_choice == peek.addon_choice and not peek_restored.paused, "Refresh restores the exact private Chat choice")
	refreshed.socket.send_text(JSON.stringify({"type":"game", "game_id":"uno", "payload":{"action":"addon_choose", "value":"skip","revision":peek_restored.revision}}))
	var chat_done: Dictionary = (await packet(refreshed.socket,"game",true,int(peek_restored.revision) + 1)).payload
	check(chat_done.addon_choice.is_empty() and chat_done.phase == "play", "The reconnected chooser can finish the add-on decision")
	var request := HTTPRequest.new()
	root.add_child(request)
	for stem: String in preload("res://Games/uno/host/presentation.gd").catalog.addon_icons.values():
		request.request("http://127.0.0.1:%d/game/uno/art/rules/%s.svg" % [app.lan_server.http_port, stem])
		var response: Array = await request.request_completed
		check(response[1] == 200 and response[3].size() > 0, "Distinct add-on icons use the real offline LAN route: " + stem)
	for asset in ["background.json", "controller.js", "style.css", "art/cards/wild-back.svg", "art/cards/green-draw4-chosen.svg", "art/cards/red-wild-chosen.svg", "art/cards/addon-wild-chat.svg", "art/cards/addon-green-block-chosen.svg", "art/cards/addon-speed-yellow-1.svg", "art/uno-logo.webp", "art/sunset-lounge.png", "art/rules/catalog.json", "art/rules/classic.svg", "art/rules/stacking.svg", "art/rules/seven-zero.svg", "art/rules/jump-in.svg", "art/rules/draw-until-play.svg", "art/rules/force-play.svg", "art/rules/mercy.svg", "art/rules/flip.svg", "art/rules/no-mercy.svg", "art/rules/addon.svg"]:
		request.request("http://127.0.0.1:%d/game/uno/%s" % [app.lan_server.http_port, asset])
		var response: Array = await request.request_completed
		check(response[1] == 200, "UNO assets are served entirely offline: " + asset)
		if asset == "background.json": check(JSON.parse_string(response[3].get_string_from_utf8()).image.ends_with("/art/sunset-lounge.png"), "LAN background metadata resolves the new extensionless stem")
	for asset in ["table-cards.svg", "table-crown.svg", "rules-star.svg", "party-sheen.svg"]:
		request.request("http://127.0.0.1:%d/ui/playful/%s" % [app.lan_server.http_port, asset])
		var response: Array = await request.request_completed
		check(response[1] == 200 and response[3].size() > 0, "Shared party artwork is served by the real LAN route: " + asset)
	request.queue_free()
	app.active_game.return_to_lobby()
	await process_frame
	check(app.current_state == "game_menu" and app.active_game == null and app.lan_server.running and not app.lan_server.lobby_open, "Back to Games cancels UNO and preserves the existing LAN session")
	check((await packet(refreshed.socket, "screen")).get("game_id", "missing") == "", "SDK receives standard return navigation")
	refreshed.socket.close()
	recipient.socket.close()
	for phone in phones: phone.socket.close()
	app.lan_server.stop_server()
	app.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	print("UNO network: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
