extends SceneTree

var checks := 0
var failures := 0
var cues: Array[String] = []
var players := [{"id": "a", "display_name": "Alex", "color": "#2463eb"}, {"id": "b", "display_name": "Sam", "color": "#08a750"}]


func _init() -> void: call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + message)


func _host(reduced: bool):
	var host = load("res://Games/monopoly-deal/host/main.tscn").instantiate(); root.add_child(host)
	host.settings_store = preload("res://tests/game_settings_fixture.gd").new()
	var context := GameSessionContext.new("monopoly-deal", players, {}, true); context.reduced_motion = reduced
	host.card_sound_played.connect(func(cue: String) -> void: cues.append(cue))
	host.initialize_session(context); cues.clear(); host.start_game()
	return host


func _id(host, key: String, index := 0) -> int:
	return int(host.rules.cards.filter(func(card: Dictionary) -> bool: return card.key == key)[index].id)


func _state(host, first: Array, second: Array, stock: Array = [], used: Array = []) -> void:
	host.motion_timer.stop(); host.animating = false; host.rules.start(2)
	host.rules.hands = [first.duplicate(), second.duplicate()]; host.rules.deck = stock.duplicate(); host.rules.discard = used.duplicate()
	host._publish(); cues.clear()


func _first(host, action: String, seat := 0) -> bool:
	for choice in host.rules.legal_actions(seat):
		if choice.payload.action != action: continue
		var command: Dictionary = choice.payload.duplicate(true); command.revision = host.rules.revision
		return host._action(seat, command)
	return false


func _run() -> void:
	var host = _host(false)
	check(host.sounds.size() == 7 and host.sounds.values().all(func(sound: AudioStreamPlayer) -> bool: return sound.bus == "Effects" and sound.stream != null and sound.stream.get_length() > 0), "Every bundled cue decodes offline and uses the shared Effects volume")
	check(["deal", "play", "bank", "action"].all(func(cue: String) -> bool: return host.sounds[cue].stream is AudioStreamOggVorbis and not host.sounds[cue].stream.loop), "Card cues use non-looping recorded foley rather than the old tones")
	check(host.sounds.win.stream is AudioStreamWAV, "The victory cue remains separate from the card shuffle")
	check(cues == ["deal"] and host.queued_sounds.size() == 12, "Opening shuffle is immediate; twelve private pickups wait for their flights")
	await create_timer(0.1).timeout
	check(cues == ["deal"], "Drawing audio waits until the opening shuffle finishes")
	host.settings_button.button_pressed = true
	var pending: Array = host.queued_sounds.duplicate(true); var count := cues.size()
	await create_timer(0.7).timeout
	check(cues.size() == count and host.queued_sounds == pending and host.sounds.values().all(func(sound: AudioStreamPlayer) -> bool: return not sound.playing), "Settings stops playback and freezes upcoming sounds")
	host.handle_controller_message("a", {"action": "sync"})
	check(cues.size() == count, "Sync cannot replay an already-heard shuffle")
	host.settings_button.button_pressed = false; host.player_disconnected("b")
	await create_timer(0.1).timeout
	check(cues.size() == count and host.queued_sounds == pending, "Disconnects keep the same pending card sounds frozen")
	host.player_reconnected(players[1])
	await create_timer(host.motion_timer.time_left + 0.15).timeout
	check(not host.animating and host.queued_sounds.is_empty() and cues.count("action") > 0 and cues.count("deal") == 1, "Reconnect resumes the remaining deal without restarting its shuffle")
	count = cues.size(); host.handle_controller_message("a", {"action": "sync"}); await process_frame
	check(cues.size() == count, "A completed movement stays silent on refresh")
	var money := _id(host, "money-10"); var one := _id(host, "money-1"); var two := _id(host, "money-2"); var three := _id(host, "money-3")
	_state(host, [money], [one], [two, three])
	check(_first(host, "bank") and cues.is_empty() and host.queued_sounds.size() == 1, "Banking schedules a placement instead of playing a generic input beep")
	count = host.queued_sounds.size()
	check(not host._action(0, {"action": "bank", "card": money, "revision": host.rules.revision}) and host.queued_sounds.size() == count, "Input rejected during movement adds no audio")
	await create_timer(host.motion_timer.time_left + 0.1).timeout
	check(cues == ["bank"] and host.rules.banks[0].has(money) and not cues.has("cash"), "Self-banking places the card without an incoming-payment cash register")
	var go := _id(host, "pass-go")
	_state(host, [go], [one], [two, three])
	check(_first(host, "go") and host.queued_sounds.size() == 3, "Pass Go schedules its discard and both drawn cards")
	await create_timer(host.motion_timer.time_left + 0.1).timeout
	check(cues.count("play") == 1 and cues.count("action") == 2, "Pass Go plays one placement and two pickup sounds")
	host.rules.start(2); host._start_deal(); cues.clear(); host.shutdown_game()
	check(host.queued_sounds.is_empty() and host.sounds.values().all(func(sound: AudioStreamPlayer) -> bool: return not sound.playing and sound.stream == null), "Leaving cancels queued audio and releases every stream")
	await create_timer(0.15).timeout
	check(cues.is_empty(), "No delayed card sounds escape into the lobby")
	host.queue_free(); await process_frame

	host = _host(true)
	check(not host.animating and host.queued_sounds.is_empty() and cues.count("deal") == 1 and cues.count("action") == 1, "Reduced motion keeps compact immediate deal audio without a delayed queue or input lock")
	money = _id(host, "money-10"); one = _id(host, "money-1"); two = _id(host, "money-2"); three = _id(host, "money-3"); go = _id(host, "pass-go")
	var debt := _id(host, "debt-collector")
	var refusal := _id(host, "just-say-no")
	_state(host, [debt], [one, refusal]); host.rules.banks[1].append(money); host._publish()
	check(_first(host, "debt") and cues == ["play"], "Playing an action produces the card-placement sound")
	count = cues.size()
	check(_first(host, "accept", 1) and host.rules.phase == "pay" and cues.size() == count, "A response with no card movement stays silent")
	cues.clear()
	check(host._action(1, {"action": "pay", "cards": [money], "revision": host.rules.revision}) and cues.count("action") == 1 and cues.count("bank") == 1 and cues.count("cash") == 1, "Receiving another player's bank payment plays one cash-register cue")
	count = cues.size(); host.handle_controller_message("a", {"action":"sync"})
	check(cues.size() == count, "Refresh never replays an incoming-payment cue")
	_state(host, [debt], [refusal]); host.rules.banks[1].append(money); host._publish(); _first(host, "debt")
	cues.clear(); check(_first(host, "no", 1) and cues.count("stop") == 1, "An accepted STOP / Just Say No plays the game-show buzzer")
	count = cues.size(); host.handle_controller_message("b", {"action":"sync"}); check(cues.size() == count, "Reconnecting to a completed STOP never repeats its buzzer")
	var property := _id(host, "boardwalk"); var sly := _id(host, "sly-deal")
	_state(host, [sly], [one]); host.rules._put_property(1, property, "dark-blue", -1); host._publish()
	check(_first(host, "sly-deal"), "A legal theft starts normally with sound enabled")
	check(host.rules.phase == "play" and not _first(host, "accept", 1) and cues.count("action") == 1 and cues.count("play") == 1, "An automatic property transfer plays slide and placement sounds without an acknowledgement")
	var wild := _id(host, "wild-light-blue-brown")
	_state(host, [], [one]); host.rules._put_property(0, wild, "brown", -1); host._publish()
	check(_first(host, "move") and host.rules.plays == 0 and cues.count("action") == 1 and cues.count("play") == 1, "Free wild-property rearrangement receives card feedback without consuming a play")
	var excess: Array = range(9)
	_state(host, excess, [money])
	check(_first(host, "end") and host.rules.phase == "discard" and cues.is_empty(), "Requesting a discard choice makes no card sound")
	check(_first(host, "discard") and cues == ["play"], "An actual selected discard produces one placement")
	_state(host, [one], [money], [], [two, three])
	check(_first(host, "end") and host.rules.deck.is_empty() and host.rules.discard.is_empty() and cues.count("deal") == 1 and cues.count("action") == 1, "Recycling all remaining discards still produces shuffle and draw audio")
	check(host._snapshot(-1).motion.flights.all(func(flight: Dictionary) -> bool: return flight.from.zone == "deck" and flight.card == {"back": true}), "Recycled pickups retain their deck origin and private faces stay hidden")
	_state(host, [go], [one])
	check(_first(host, "go") and host.rules.hands[0] == [go] and cues.count("deal") == 1 and cues.count("action") == 1 and cues.count("play") == 1, "An exhausted-stock Pass Go is heard even when the played card is immediately drawn back")
	_state(host, [one], [money])
	check(_first(host, "end") and cues.is_empty(), "An empty stock and discard pile never produce phantom draw sounds")

	var fixture := "res://.test_data/monopoly-audio-theme-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(fixture); RuntimeAssets.root_override = ProjectSettings.globalize_path(fixture); RuntimeAssets.refresh()
	var created: Dictionary = host.skins.duplicate_pack("default", "Audio test")
	var pack: Dictionary = created.pack
	check(host.skins.stage_media(pack, "sound-action", "res://Games/monopoly-deal/audio/win.wav").ok and host.skins.save_pack(pack).ok, "Existing named audio slots accept a custom replacement")
	host.skins.pin(pack.id); host._load_sounds()
	check(host.sounds.action.stream is AudioStreamWAV and host.sounds.play.stream is AudioStreamOggVorbis, "A saved sound-action replacement survives the new default OGG paths while omitted slots inherit foley")
	host.skins.pin("default"); host._load_sounds()
	check(host.sounds.action.stream is AudioStreamOggVorbis and host.queued_sounds.is_empty(), "Changing themes reloads audio and removes the previous game's pending cues")
	host.shutdown_game(); host.queue_free(); await process_frame; await process_frame
	RuntimeAssets.root_override = ""; RuntimeAssets.refresh()
	print("Monopoly Deal audio: %d checks, %d failures" % [checks, failures]); quit(1 if failures else 0)
