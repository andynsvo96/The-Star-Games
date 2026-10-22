extends SceneTree

var checks := 0
var failures := 0
const CAPTURE_DIR := "res://.test_data/game-selection/"


func _init() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)


func set_player_count(app: Control, count: int) -> void:
	app.lan_server.active_players.clear()
	for index in count:
		var id := str(index)
		app.lan_server.active_players[id] = {"id": id, "display_name": "Player %02d" % (index + 1), "color": LanServer.PLAYER_COLORS[index % LanServer.PLAYER_COLORS.size()], "pose": index % 6}
	# This fixture replaces the whole lobby lineup, rather than disconnecting it.
	if not app.lan_server.lobby_open: app.lan_server.set_lobby_open(false)
	app.lan_server.roster_changed.emit(app.lan_server.get_players())


func game_titles(app: Control) -> Array[String]:
	var titles: Array[String] = []
	for card in app.lobby_game_list.get_children():
		if not card.find_children("*", "Button", true, false).is_empty():
			titles.append(card.find_children("*", "Label", true, false)[0].text)
	return titles


func capture(name: String) -> void:
	for frame in 4:
		await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(CAPTURE_DIR + name + ".png")


func check_icon_layout(app: Control) -> void:
	# Repeat real catalog cards to verify capacity before sixteen modules exist.
	var collection: Array = app.game_catalog.games.duplicate(true)
	var sixteen_games: Array = []
	for index in 16:
		sixteen_games.append(collection[index % collection.size()].duplicate(true))
		sixteen_games[-1].id = "grid-%d" % index
		sixteen_games[-1].erase("game_choices")
	for child in app.get_children():
		if child is Timer:
			child.stop()
	app._set_show_all_games(true)
	app._set_game_view("icons")
	await capture("collection-icons")
	for reduced_motion in [true, false]:
		app.profile_store.data.settings.reduced_motion = reduced_motion
		for viewport_size in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(720, 1280), Vector2i(390, 844), Vector2i(844, 390)]:
			root.min_size = Vector2i.ONE
			root.content_scale_size = viewport_size
			root.size = viewport_size
			app._show_game_menu()
			app.game_catalog.games = sixteen_games.duplicate(true)
			app._rebuild_game_list()
			await create_timer(0.35).timeout
			await capture("sixteen-%dx%d-%s" % [viewport_size.x, viewport_size.y, "reduced" if reduced_motion else "motion"])
			var screen: Rect2 = app.get_global_rect()
			var panel: Control = app.screen_root.get_child(0).get_child(0)
			var scroll: Rect2 = app.game_menu_scroll.get_global_rect()
			var cards: Array[Node] = app.lobby_game_list.get_children()
			check(panel.get_global_rect().get_center().distance_to(screen.get_center()) < 2, "Selection stays centered at %s (reduced motion: %s)" % [viewport_size, reduced_motion])
			check(screen.grow(1).encloses(panel.get_global_rect()), "Selection panel fits the viewport at %s" % viewport_size)
			check(app.lobby_game_list.size.x <= scroll.size.x, "Icon grid fits without horizontal scrolling at %s" % viewport_size)
			for button in app.game_view_toggle.get_parent().find_children("*", "Button", false, false):
				check(screen.encloses(button.get_global_rect()), "Selection controls stay reachable at %s" % viewport_size)
			if viewport_size.x >= 1280:
				check(app.lobby_game_list.columns == 8 and is_equal_approx(cards[0].position.y, cards[7].position.y) and is_equal_approx(cards[8].position.y, cards[15].position.y), "Sixteen games form two rows of eight at %s" % viewport_size)
				check(cards.all(func(card: Control) -> bool: return scroll.grow(1).encloses(card.get_global_rect())), "All sixteen cards fit on screen at %s (grid: %s, scroll: %s)" % [viewport_size, app.lobby_game_list.size, scroll.size])
				check(not app.game_menu_scroll.get_v_scroll_bar().visible, "Two rows need no vertical scrolling at %s" % viewport_size)
			else:
				check(app.lobby_game_list.columns < 8, "Narrow screens reduce the column count at %s" % viewport_size)
				app.game_menu_scroll.scroll_vertical = 100000
				for frame in 4:
					await process_frame
				var last_play: Button = cards[-1].find_children("*", "Button", true, false)[0]
				check(scroll.grow(1).encloses(last_play.get_global_rect()), "The final game's Play button can be reached at %s" % viewport_size)
			check(not app.screen_root.find_children("*", "Label", true, false).any(func(label: Label) -> bool: return label.text.contains("Your party is ready")), "Selection omits the removed message")
	root.content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
	app.profile_store.data.settings.reduced_motion = true
	app.game_catalog.games = collection
	app._set_show_all_games(false)
	app._set_game_view("list")
	await process_frame


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(CAPTURE_DIR)
	var app = load("res://Main.tscn").instantiate()
	app.profile_store = ProfileStore.new(CAPTURE_DIR + "profiles.json")
	app.game_settings_store = preload("res://tests/game_settings_fixture.gd").new()
	root.add_child(app)
	app.profile_store.data.settings.fullscreen = false
	app.profile_store.data.settings.reduced_motion = true
	app.game_view = "list"
	app._enter_lobby()
	set_player_count(app, 3)
	app._play_from_lobby()
	check(game_titles(app) == ["Monopoly", "Pictionary", "Poker", "Quoridor", "UNO"], "Three players see each collection once plus compatible standalone games")
	var toggle: Button = app.game_filter_toggle
	check(toggle.toggle_mode and not toggle.button_pressed and toggle.text == "Show All", "Selection defaults to hidden locked games")
	check(toggle.get_parent() == app.game_view_toggle.get_parent() and toggle.get_index() == app.game_view_toggle.get_index() + 1, "Filter is immediately beside View")
	toggle.pressed.emit()
	check(toggle == app.game_filter_toggle and toggle.button_pressed and toggle.text == "Hide Locked", "One button toggles to Show All")
	check(game_titles(app).size() == app.game_catalog.menu_games().size(), "Show All reveals the validated menu with children grouped")
	var buttons: Array[Node] = app.lobby_game_list.find_children("*", "Button", true, false)
	check(buttons.filter(func(button: Button) -> bool: return not button.disabled).size() == 5, "Only compatible games remain playable with three players")
	var locked_game: Dictionary = app.game_catalog.games.filter(func(game: Dictionary) -> bool: return game.id == "spyfall")[0]
	app._launch_game(locked_game)
	check(app.current_state == "game_menu" and app.active_game == null, "Show All cannot bypass player limits when launching")
	app._set_game_view("icons")
	await capture("three-players-all-icons")
	app._show_settings("game_menu")
	app._return_from_settings()
	check(app.show_all_games and app.game_filter_toggle.text == "Hide Locked" and app.game_filter_toggle.button_pressed, "Navigation retains the filter state")
	check(app.screen_root.find_children("*", "Button", true, false).filter(func(button: Button) -> bool: return button.text in ["Show All", "Hide Locked"]).size() == 1, "Navigation creates only one filter button")
	app.game_filter_toggle.pressed.emit()
	for frame in 4:
		await process_frame
	check(game_titles(app) == ["Monopoly", "Pictionary", "Poker", "Quoridor", "UNO"] and app.lobby_game_list.columns == 5, "Hide Locked also filters Icons and sizes columns to visible games")
	for count in [4, 6]:
		set_player_count(app, count)
		var expected := ["Mafia", "Monopoly", "Pictionary", "Poker", "Quoridor", "Spyfall", "UNO"] if count == 4 else ["Mafia", "Monopoly", "Pictionary", "Poker", "Spyfall", "UNO"]
		check(game_titles(app) == expected, "%d players show only games within their supported range" % count)
	await capture("six-players-filtered-icons")
	for count in [7, 8]:
		set_player_count(app, count)
		check(game_titles(app) == ["Mafia", "Pictionary", "Poker", "Spyfall"], "%d players hide games above their maximum" % count)
	app._set_game_view("list")
	await capture("eight-players-filtered-list")
	for count in [9, 10]:
		set_player_count(app, count)
		check(game_titles(app) == ["Mafia", "Pictionary", "Poker"], "%d players see Poker at its upper player boundary" % count)
	for count in [11, 16]:
		set_player_count(app, count)
		check(game_titles(app) == ["Mafia", "Pictionary"], "%d players can play games with larger party limits" % count)
	set_player_count(app, 17)
	check(game_titles(app).is_empty(), "Unsupported party sizes show no game cards")
	check(app.lobby_game_list.find_children("*", "Label", true, false).any(func(label: Label) -> bool: return label.text == "No games for this party size"), "An empty filtered collection explains how to recover")
	await capture("seventeen-players-empty")
	var empty: Control = app.lobby_game_list.get_child(0)
	check(absf(empty.get_global_rect().get_center().x - app.get_global_rect().get_center().x) < 2.0, "The empty filtered collection stays horizontally centered")
	app.game_filter_toggle.pressed.emit()
	check(game_titles(app).size() == app.game_catalog.menu_games().size(), "Show All remains available when no games are compatible")
	check(app.lobby_game_list.find_children("*", "Button", true, false).all(func(button: Button) -> bool: return button.disabled), "Every revealed game stays locked above sixteen players")
	app.game_filter_toggle.pressed.emit()
	set_player_count(app, 2)
	check(game_titles(app).size() == 9 and game_titles(app).has("Poker") and not game_titles(app).has("Spyfall"), "Roster reconnection restores games at the two-player boundary")
	set_player_count(app, 0)
	check(game_titles(app).size() == 9 and game_titles(app).has("Poker") and not game_titles(app).has("Spyfall"), "No phones preserves all solo games")
	await check_icon_layout(app)
	set_player_count(app, 9)
	app.game_catalog.games_root = "res://tests/fixtures/Games"
	app._scan_games()
	check(game_titles(app) == ["Valid Game"], "Catalog rescans apply the active player filter to new games")
	check(app.game_filter_toggle.text == "Show All" and not app.game_filter_toggle.button_pressed, "Rescans preserve the toggle state")
	app._leave_lobby()
	app.queue_free()
	await process_frame
	print("Game selection: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
