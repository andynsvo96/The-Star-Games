extends SceneTree

var host: Node
var checks := 0
var failures := 0

func _init() -> void: call_deferred("_run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + label)

func reset() -> void:
	host.rules.start(4)
	for seat in 4:
		host.rules.hands[seat].clear(); host.rules.banks[seat].clear(); host.rules.properties[seat].clear(); host.rules.loose[seat].clear()
	host.rules.deck = range(host.rules.cards.size()); host.rules.discard.clear(); host.animating = false; host.motion_timer.stop(); host.ai_timer.stop()
	host._publish(); host.ai_timer.stop()

func take(key: String, seat := 0) -> int:
	var id: int = host.rules.deck.filter(func(value: int) -> bool: return host.rules.cards[value].key == key)[0]
	host.rules.deck.erase(id); host.rules.hands[seat].append(id); return id

func prop(key: String, color: String, seat := 0) -> int:
	var id := take(key, seat); host.rules.hands[seat].erase(id); host.rules._receive_property(seat, id, color); return id

func act(seat: int, input: Dictionary) -> bool:
	input.revision = host.rules.revision; var accepted: bool = host._action(seat, input); host.ai_timer.stop(); return accepted

func check_applicability() -> void:
	reset()
	var debt := take("debt-collector"); var birthday := take("birthday"); var rent := take("rent-light-blue-brown"); var any_rent := take("rent-any"); var double := take("double-rent")
	prop("mediterranean-avenue", "brown")
	var offered: Array = host.rules.legal_actions(0)
	check(not offered.any(func(choice: Dictionary) -> bool: return choice.payload.action in ["debt", "birthday", "rent"]), "Collection cards are inapplicable when no opponent has payable assets")
	check(host.rules.rent_cards_for_double(0, double).is_empty(), "A double cannot offer a Rent card that nobody can pay")
	check(not act(0, {"action":"debt", "card":debt, "target":1}) and host.rules.plays == 0 and host.rules.hands[0].has(debt), "The host rejects a forged empty-target charge without spending its card")
	host._publish(); host._select_card(host.rules.cards[debt])
	var play: Button = host.reader.actions.get_children().filter(func(button: Button) -> bool: return button.text == "Play card")[0]
	check(play.disabled and host.reader.actions.get_children().any(func(button: Button) -> bool: return button.text == "Bank $3" and not button.disabled), "The native reader disables an inapplicable action while retaining Bank")
	host.reader.close(); prop("wild-any", "orange", 1)
	check(not host.rules.legal_actions(0).any(func(choice: Dictionary) -> bool: return choice.payload.action == "debt"), "An unpayable zero-value wild does not enable a collection")
	prop("boardwalk", "dark-blue", 1)
	offered = host.rules.legal_actions(0)
	check(offered.filter(func(choice: Dictionary) -> bool: return choice.payload.action == "debt").size() == 1 and offered.any(func(choice: Dictionary) -> bool: return choice.payload.action == "debt" and choice.payload.target == 1), "A property-only opponent can pay and is the only eligible debt target")
	check(offered.any(func(choice: Dictionary) -> bool: return choice.payload.action == "birthday") and not host.rules.rent_cards_for_double(0, double).is_empty(), "Birthday, Rent and Double the Rent become applicable when someone has assets")
	var partial := take("money-1", 2); host.rules.hands[2].erase(partial); host.rules.banks[2].append(partial)
	check(host.rules.legal_actions(0).any(func(choice: Dictionary) -> bool: return choice.payload.action == "debt" and choice.payload.target == 2), "A partial payment remains valid without requiring the full $5 upfront")
	check(host.rules.legal_actions(0).filter(func(choice: Dictionary) -> bool: return choice.payload.action == "rent" and choice.payload.card == any_rent).all(func(choice: Dictionary) -> bool: return choice.payload.target in [1, 2]), "Targeted Rent omits opponents with nothing payable")
	check(act(0, {"action":"debt", "card":debt, "target":2}) and host.rules.phase == "pay", "A payable opponent receives the actual debt decision")
	var payment: Dictionary = host.rules.payment_command(2, [partial])
	check(act(2, payment) and host.rules.banks[0].has(partial), "Paying every available asset still settles a partially covered debt")

func _run() -> void:
	host = load("res://Games/monopoly-deal/host/main.tscn").instantiate(); root.add_child(host)
	host.settings_store = preload("res://tests/game_settings_fixture.gd").new()
	var players: Array = []
	for index in 4: players.append({"id":"qa-%d" % index, "display_name":"Host" if index == 0 else "Player %d" % index, "color":"#2463eb"})
	var context := GameSessionContext.new("monopoly-deal", players, {}, true); context.reduced_motion = true
	host.initialize_session(context); host.start_game(); host.host_plays = true; reset()
	var banknote := take("money-2"); host._publish(); host._select_card(host.rules.cards[banknote])
	check(host.reader.heading.text.is_empty() and host.reader.actions.get_children().map(func(button: Button) -> String: return button.text) == ["Back", "BANK"], "Focused money shows one BANK action and no redundant amount heading")
	host.reader.actions.get_child(1).pressed.emit()
	check(host.rules.banks[0].has(banknote) and host.rules.plays == 1 and not host.reader.visible, "The single BANK action deposits the money once through normal validation")
	host._inspect_card(host.rules.cards[banknote])
	check(host.reader.heading.text.is_empty(), "Public money inspection also omits the redundant value heading")
	host.reader.close(); reset()
	check_applicability(); reset()
	var any_wild := take("wild-any")
	prop("boardwalk", "dark-blue"); prop("park-place", "dark-blue"); prop("pacific-avenue", "green")
	var wild_choices: Array = host.rules.tap_choices(0, any_wild)
	check(wild_choices[0].payload.color == "green" and wild_choices[-1].payload.color == "dark-blue", "Any-color wilds prioritize the most expensive unfinished color before completed colors")
	var green_id: int = host.rules.properties[0].filter(func(group: Dictionary) -> bool: return group.color == "green")[0].id
	check(wild_choices[0].payload.group == green_id, "A wild still joins its fullest offered incomplete group")
	host._publish(); host._select_card(host.rules.cards[any_wild])
	check(host.reader.preview.visible and host.reader.preview.options.size() == 10 and host.reader.preview.options[0].groups[0].items[0].card.kind == "property" and host.reader.preview.options[0].groups[0].items[0].texture != null, "The any-color wild opens an actual card-face chooser in the shared reader")
	check(host.rules.plays == 0 and host.rules.hands[0].has(any_wild), "Opening or selecting the illustrated color chooser spends no play")
	host.reader.preview._select_group(host.reader.preview.card_groups[0]); host._choose_card_play()
	check(host.rules.group_for(0, green_id).cards.has(any_wild) and host.rules.plays == 1 and not host.reader.visible, "Explicit Add property submits only the selected offered color/group")
	host.reader.close(); reset()
	prop("reading-railroad", "railroad"); prop("pennsylvania-railroad", "railroad"); prop("b-and-o-railroad", "railroad")
	prop("mediterranean-avenue", "brown"); prop("baltic-avenue", "brown")
	prop("electric-company", "utility"); prop("water-works", "utility")
	prop("short-line", "railroad")
	prop("boardwalk", "dark-blue")
	var groups: Array = host.rules.view_for(0).table[0].groups
	check(groups[0].color == "railroad" and groups[1].color == "brown" and groups[2].color == "utility" and not groups[-1].complete, "Completed sets sort first, and a completed 4/4 sorts ahead of 2/2")
	# Separate fixture avoids a three-set victory while selecting actions.
	reset(); prop("mediterranean-avenue", "brown"); prop("baltic-avenue", "brown"); prop("oriental-avenue", "light-blue"); prop("boardwalk", "dark-blue", 1)
	var rent := take("rent-light-blue-brown"); var double := take("double-rent"); var money := take("money-10")
	var options: Array = host.rules.tap_choices(0, rent)
	check(host.rules.preview_for(0, options[0].payload).amount == 2 and host.rules.preview_for(0, options[-1].payload).amount == 1, "Rent candidates descend by the authoritative amount")
	host._publish(); host._select_card(host.rules.cards[rent])
	check(host.reader.preview.selected == 0 and host.reader.preview.options[0].groups[0].label == "Rent $2", "Rent opens with the highest charge selected and a rent-only caption")
	check(host.reader.preview.options.all(func(item: Dictionary) -> bool: return item.groups[0].label.begins_with("Rent $") and not item.groups[0].label.contains("brown")), "Every rent tile omits color names")
	host._select_card(host.rules.cards[double])
	check(host.reader.preview.options.size() == 1 and host.reader.preview.options[0].rent_card == rent and host.reader.preview.options[0].groups[0].items[0].card.id == rent, "Double the Rent directly displays its applicable held Rent card")
	host.reader.preview._select_group(host.reader.preview.card_groups[0])
	check(host.focused_card == rent and host.table.armed_doubles == [double] and host.reader.preview.options[0].groups[0].label == "Rent $4" and host.rules.hands[0].has(double), "Choosing Rent previews its doubled amount without spending either card")
	host.reader.close()
	var wild := prop("wild-pink-orange", "orange")
	context.reduced_motion = false; host._publish(); host._select_card(host.rules.public_card(wild, 0))
	check(host.reader.rotation_side == 1 and is_equal_approx(host.reader.card.rotation, PI) and (host.reader.rotation_tween == null or not host.reader.rotation_tween.is_running()), "Opening an already-rotated wild restores its side without animation")
	host._rotate_card()
	check(host.reader.rotation_tween != null and host.reader.rotation_tween.is_running(), "Explicitly rotating that wild still animates")
	host.reader.close(); host._select_card(host.rules.public_card(wild, 0))
	check(is_equal_approx(host.reader.card.rotation, PI) and not host.reader.rotation_tween.is_running(), "Reopening restores the authoritative orientation immediately after a canceled rotation")
	host.reader.close(); context.reduced_motion = true
	var forced := take("forced-deal"); prop("new-york-avenue", "orange", 1); prop("park-place", "dark-blue", 2)
	host._publish(); host._select_card(host.rules.cards[forced])
	var headings: Array = []
	for child in host.reader.preview.body.get_children():
		if child is Label: headings.append(child.text)
	check(headings == ["Your cards to give", "Opponents' cards to take"], "Forced Deal has separate own-card and opponent-card categories")
	check(host.reader.preview.card_grids.all(func(entry: Dictionary) -> bool: return entry.grid.left_aligned), "Action choices use left-aligned shared grids")
	host.reader.close(); host._publish()
	for frame in 5: await process_frame
	var public_groups: Array = host.table.state.table[0].groups
	var brown: Dictionary = public_groups.filter(func(group: Dictionary) -> bool: return group.color == "brown")[0]
	var live: Dictionary = host.table.face_schedule(brown, brown.cards[0])
	check(live.rows[1].active and live.rows[1].value == "$2" and not live.rows[0].active, "The host card emphasizes only its current count and authoritative rent")
	var improved: Dictionary = brown.duplicate(true); improved.rent += 7
	check(host.table.face_schedule(improved, improved.cards[0]).rows[1].value == "$9", "The active printed row includes House and Hotel rent instead of a separate caption")
	var orange: Dictionary = public_groups.filter(func(group: Dictionary) -> bool: return group.color == "orange")[0]
	var wild_face: Dictionary = host.rules.public_card(wild, 0)
	check(wild_face.face_side == 1 and host.table.face_schedule(orange, wild_face).compact and not host.table.face_schedule(orange, wild_face).dim_regions.is_empty(), "A rotated wild gets upright active rows and a dimmed opposing schedule")
	check(not wild_face.has("face_schedule") and host.table.inspector_data(0, orange).items.all(func(item: Dictionary) -> bool: return item.get("placeholder", false) or not item.card.has("face_schedule")), "Live table emphasis never alters the card data or enlarged inspector art")
	var group_rect: Rect2 = host.table.group_bounds["0:%d" % brown.id]
	host.table._activate(group_rect.get_center()); await process_frame
	check(host.inspection.overlay.visible and host.inspected_seat == 0 and host.inspected_group == -1 and host.inspection.body.find_children("*", "GameTableInspector", true, false).is_empty(), "A placed property opens the owner's complete public cards")
	host.inspection.overlay.hide(); await process_frame
	check(host.table.selected_group_seat == -1 and host.table.selected_group_id == -1, "Dismissing inspection clears its temporary cyan outline")
	var seat_one: Rect2 = host.table.seat_bounds[1]; var seat_empty: Rect2 = host.table.seat_bounds[3]
	check(is_equal_approx(seat_one.size.y, seat_empty.size.y), "An empty player's panel has the same height as a player with properties")
	check(not host.table.history_bounds.has_area() and host.table.activity_log.get_parent() == host.history_dialog.body, "Activity is available through History instead of occupying pile space")
	check(not host.table.history_bounds.intersects(host.table.hand_bounds), "Activity cannot bleed into the private hand")
	var positions: Array = host.table.group_bounds.values()
	check(positions.all(func(bounds: Rect2) -> bool: return bounds.position.x >= 0), "Compact property rows stay in the public field")
	check(act(0, {"action":"bank", "card":money}), "A real bank action is accepted")
	var history: Array = host._snapshot(-1).activity_entries
	check(history.size() == 1 and history[0].text.contains("banked $10") and history[0].text.begins_with("Host"), "The public activity log identifies the actual player and accepted action")
	host._publish(); await process_frame
	check(host.table.activity_log.signature == JSON.stringify(history), "Duplicate publications preserve the same activity entries")
	host.rules._check_win(); host.rules.winner = 0; host._publish(); await process_frame
	check(host._snapshot(-1).activity_entries == history and not JSON.stringify(history).contains("wins"), "Winner presentation never adds a game conclusion to activity")
	host.rules.start(4); check(host.rules.activity.is_empty(), "A new deal clears its previous activity")
	reset()
	var birthday := take("birthday"); var cash := take("money-10", 1); host.rules.hands[1].erase(cash); host.rules.banks[1].append(cash)
	check(act(0, {"action":"birthday", "card":birthday}), "A public multi-player action enters activity after acceptance")
	var view: Dictionary = host._snapshot(1); var payment: Dictionary = view.payment.command.duplicate(true); payment.cards = [cash]
	check(act(1, payment), "An overpayment completes the recipient's own decision")
	var entries: Array = host._snapshot(-1).activity_entries
	check(entries[0].text == "Player 1 paid $10 to Host" and entries[1].text.contains("Birthday") and entries[0].id > entries[1].id, "Activity is newest-first and records the actual transferred amount")
	var events_before: int = host.rules.activity.size(); payment.revision = view.revision
	check(not host._action(1, payment) and host.rules.activity.size() == events_before, "Rejected duplicate input cannot add false activity")
	reset(); var go := take("pass-go"); check(act(0, {"action":"go", "card":go}), "An accepted private draw records public activity")
	check(host.rules.activity[0].amount == 2 and not host.rules.activity[0].has("cards") and host.rules.view_for(-1).hand.is_empty(), "Draw history exposes its count without private drawn card identities")
	context.reduced_motion = false; host._publish(); await process_frame
	check(act(0, {"action":"end"}), "Ending a turn adds live public activity")
	await process_frame; await process_frame
	var latest: Label = host.table.activity_log.entries.get_child(0)
	check(latest.modulate.a < 1 and not host.table.activity_log.animations.is_empty(), "A new live activity entry fades in")
	host.settings_button.button_pressed = true; await process_frame
	var frozen := latest.modulate.a; await create_timer(0.05).timeout
	check(is_equal_approx(latest.modulate.a, frozen), "Host Settings freezes the activity entry animation")
	context.reduced_motion = true; host._publish(); await process_frame
	check(latest.modulate.a == 1, "Reduced motion presents the activity immediately")
	host.settings_button.button_pressed = false
	host.shutdown_game(); host.queue_free(); await create_timer(0.15).timeout
	print("Monopoly Deal refinements: %d checks, %d failures" % [checks, failures]); quit(1 if failures else 0)
