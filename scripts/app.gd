extends Control

const COLOR_SPACE := Color("101114")
const COLOR_PANEL := Color("1c1d21f5")
const COLOR_PANEL_LIGHT := Color("292a30")
const COLOR_ACCENT := Color("409cff")
const COLOR_ACCENT_2 := Color("a7a4ff")
const COLOR_TEXT := Color("f5f5f7")
const COLOR_MUTED := Color("a1a1aa")
const COLOR_DANGER := Color("ff6961")
const GAME_ICON_CARD_WIDTH := 128.0
const GAME_ICON_MAX_COLUMNS := 8

var profile_store := ProfileStore.new()
var game_catalog := GameCatalog.new()
var lan_server := LanServer.new()
var public_address := preload("res://scripts/public_address.gd").new()
var debug_browsers := preload("res://scripts/debug_browsers.gd").new()
var debug_lab: CanvasLayer
var screen_root: Control
var title_background: Control
var menu_music: Control
var game_music: Control
var settings_caller := "title"
var game_settings_store := GameSettingsStore.new()
var current_state := "title"
var title_intro: Tween
var title_intro_played := false
var title_transition: Tween
var screen_transition: Tween
var entering_lobby := false
var active_game: BaseGame
var active_game_id := ""
var active_collection_id := ""
var collection_roster: Array = []

var lobby_roster: GridContainer
var active_game_is_party := false
var avatar_states: Dictionary = {}
var lobby_avatars: Dictionary = {}
var lobby_player_count: Label
var public_connection_link: LinkButton
var lobby_game_list: GridContainer
var game_view := "list"
var game_view_toggle: Button
var show_all_games := false
var game_filter_toggle: Button
var game_menu_scroll: ScrollContainer
var lobby_diagnostics: Label
var profile_option: OptionButton
var profile_name_edit: LineEdit
var game_id_edit: LineEdit
var game_points_spin: SpinBox
var settings_notice: Label
var debug_notice: Label
var pending_confirmation: Callable
var asset_editor: Control


func _ready() -> void:
	_build_theme()
	_build_background()
	screen_root = Control.new()
	screen_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen_root)
	add_child(lan_server)
	add_child(public_address)
	public_address.changed.connect(_update_public_connection_link)
	lan_server.stopped.connect(public_address.clear)
	lan_server.configure(profile_store, game_catalog)
	lan_server.roster_changed.connect(_on_roster_changed)
	lan_server.server_error.connect(_show_error)
	lan_server.controller_message.connect(_on_controller_message)
	lan_server.player_joined.connect(_on_player_joined)
	lan_server.player_disconnected.connect(_on_player_disconnected)
	profile_store.load_data()
	game_view = str(profile_store.get_settings().get("game_view", "list"))
	if game_view not in ["list", "icons"]:
		game_view = "list"
	_apply_runtime_settings()
	game_catalog.scan()
	var scan_timer := Timer.new()
	scan_timer.wait_time = 5.0
	scan_timer.autostart = true
	scan_timer.timeout.connect(_scan_games)
	add_child(scan_timer)
	title_background = preload("res://scripts/title_background.gd").new()
	title_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(title_background)
	title_background.resized.connect(_center_title_background)
	move_child(title_background, screen_root.get_index())
	menu_music = preload("res://scripts/menu_music.gd").new()
	menu_music.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(menu_music)
	menu_music.volume_changed.connect(func(value: float) -> void: _save_setting("music_volume", value))
	menu_music.set_volume(float(profile_store.get_settings()["music_volume"]))
	menu_music.reduced_motion = bool(profile_store.get_settings().get("reduced_motion", false))
	game_music = preload("res://scripts/menu_music.gd").new()
	game_music.song_dir = "res://asset/music"
	game_music.cache_dir = "user://game_music"
	game_music.active = false
	game_music.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(game_music)
	game_music.volume_changed.connect(func(value: float) -> void: _save_setting("music_volume", value))
	_apply_runtime_settings()
	_show_title()
	debug_lab = preload("res://scripts/debug_lab.gd").new()
	add_child(debug_lab)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F8:
		_toggle_debug_lab()
		get_viewport().set_input_as_handled()


func _toggle_debug_lab() -> void:
	if not is_instance_valid(debug_lab): return
	if debug_lab.opened:
		debug_lab.close()
	else:
		debug_lab.open_for(active_game if is_instance_valid(active_game) else screen_root)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if current_state == "asset_editor" and is_instance_valid(asset_editor):
			asset_editor.request_quit()
		else:
			_quit_application()


func _build_theme() -> void:
	var app_theme := Theme.new()
	app_theme.default_font_size = 16
	var system_font := SystemFont.new()
	system_font.font_names = PackedStringArray(["SF Pro Display", "Segoe UI", "Helvetica Neue", "Arial"])
	app_theme.default_font = system_font
	app_theme.set_color("font_color", "Label", COLOR_TEXT)
	app_theme.set_color("font_color", "Button", COLOR_TEXT)
	app_theme.set_color("font_hover_color", "Button", Color.WHITE)
	app_theme.set_color("font_pressed_color", "Button", Color.WHITE)
	app_theme.set_color("font_color", "LinkButton", COLOR_ACCENT)
	app_theme.set_color("font_hover_color", "LinkButton", Color.WHITE)
	app_theme.set_color("font_pressed_color", "LinkButton", COLOR_ACCENT_2)
	app_theme.set_color("font_color", "LineEdit", COLOR_TEXT)
	app_theme.set_color("font_placeholder_color", "LineEdit", COLOR_MUTED)
	app_theme.set_color("font_color", "CheckBox", COLOR_TEXT)
	app_theme.set_color("font_color", "OptionButton", COLOR_TEXT)
	app_theme.set_color("font_color", "SpinBox", COLOR_TEXT)
	app_theme.set_constant("separation", "VBoxContainer", 14)
	app_theme.set_constant("separation", "HBoxContainer", 14)
	app_theme.set_stylebox("normal", "Button", _style(COLOR_PANEL_LIGHT, 12, 1, Color("ffffff10")))
	app_theme.set_stylebox("hover", "Button", _style(Color("363840"), 12, 1, Color("ffffff28")))
	app_theme.set_stylebox("pressed", "Button", _style(Color("222329"), 12))
	app_theme.set_stylebox("focus", "Button", _style(Color.TRANSPARENT, 14, 2, COLOR_ACCENT))
	app_theme.set_stylebox("focus", "LinkButton", app_theme.get_stylebox("focus", "Button"))
	app_theme.set_stylebox("normal", "LineEdit", _style(Color("141518"), 10, 1, Color("3a3b43")))
	app_theme.set_stylebox("focus", "LineEdit", _style(Color("141518"), 10, 2, COLOR_ACCENT))
	app_theme.set_stylebox("panel", "PanelContainer", _style(COLOR_PANEL, 24, 1, Color("ffffff12")))
	app_theme.set_stylebox("disabled", "Button", _style(Color("24252a"), 12))
	app_theme.set_color("font_disabled_color", "Button", Color("73747e"))
	for state in ["normal", "hover", "pressed", "focus"]:
		app_theme.set_stylebox(state, "OptionButton", app_theme.get_stylebox(state, "Button"))
	var divider := StyleBoxLine.new()
	divider.color = Color("ffffff12")
	divider.thickness = 1
	app_theme.set_stylebox("separator", "HSeparator", divider)
	theme = app_theme


func _build_background() -> void:
	var background := ColorRect.new()
	background.color = COLOR_SPACE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)


func _show_title() -> void:
	current_state = "title"
	_replace_screen()
	var center := CenterContainer.new()
	screen_root.add_child(center)
	center.anchor_left = 0.5
	center.anchor_right = 0.5
	center.anchor_top = 0.75
	center.anchor_bottom = 0.75
	center.offset_left = -110
	center.offset_right = 110
	center.offset_top = -28
	center.offset_bottom = 28
	var play := _button("PLAY", _enter_lobby)
	play.custom_minimum_size = Vector2(220, 56)
	play.add_theme_font_size_override("font_size", 22)
	play.add_theme_color_override("font_shadow_color", Color("10111499"))
	play.add_theme_constant_override("shadow_offset_y", 2)
	play.add_theme_stylebox_override("normal", _style(Color("10111426"), 8, 1, Color("ffffff55")))
	play.add_theme_stylebox_override("hover", _style(Color("10111455"), 8, 1, Color("ffffffaa")))
	play.add_theme_stylebox_override("pressed", _style(Color("10111477"), 8, 1, Color("ffffffcc")))
	play.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, 8, 1, Color("ffffff77")))
	center.add_child(play)
	play.grab_focus()
	_animate_title(center)


func _animate_title(play_layer: Control) -> void:
	if title_intro_played:
		return
	title_intro_played = true
	if profile_store.get_settings().get("reduced_motion", false):
		return
	# The artwork and PLAY reveal independently, without moving their layout.
	_center_title_background()
	title_background.scale = Vector2.ONE * 1.06
	title_background.modulate.a = 0.0
	play_layer.modulate.a = 0.2
	title_intro = create_tween().set_parallel(true)
	title_intro.tween_property(title_background, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	title_intro.tween_property(title_background, "scale", Vector2.ONE, 1.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	title_intro.tween_property(play_layer, "modulate:a", 1.0, 0.45).set_delay(0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	title_intro.chain().tween_callback(func() -> void: title_intro = null)


func _center_title_background() -> void:
	title_background.pivot_offset = title_background.size * 0.5


func _cancel_title_intro() -> void:
	if title_intro != null:
		title_intro.kill()
		title_intro = null


func _enter_lobby() -> void:
	if entering_lobby or current_state != "title":
		return
	if not lan_server.start_server():
		return
	_cancel_title_intro()
	if profile_store.get_settings().get("reduced_motion", false):
		_show_lobby()
		return
	entering_lobby = true
	for button in screen_root.find_children("*", "Button", true, false):
		button.disabled = true
		button.release_focus()
	title_transition = create_tween().set_parallel(true)
	title_transition.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	title_transition.tween_property(screen_root, "modulate:a", 0.0, 0.28)
	title_transition.tween_property(screen_root, "position:y", -18.0, 0.28)
	title_transition.tween_property(title_background, "modulate:a", 0.0, 0.28)
	title_transition.chain().tween_callback(func() -> void:
		title_transition = null
		_show_lobby()
	)


func _show_lobby() -> void:
	lan_server.set_lobby_open(true)
	current_state = "lobby"
	_replace_screen()
	var outer := _screen_margin(32)
	screen_root.add_child(outer)
	var layout := HBoxContainer.new()
	layout.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	outer.add_child(layout)
	var main_panel := PanelContainer.new()
	main_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(main_panel)
	var main_margin := _panel_margin(12)
	main_panel.add_child(main_margin)
	var main_column := VBoxContainer.new()
	main_column.add_theme_constant_override("separation", 12)
	main_margin.add_child(main_column)
	var header := HBoxContainer.new()
	main_column.add_child(header)
	var back := _button("‹  Back", _leave_lobby)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(back)
	var heading_box := VBoxContainer.new()
	heading_box.add_theme_constant_override("separation", 4)
	heading_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading_box)
	heading_box.add_child(_label("The Star Games Lobby", 30, COLOR_TEXT))
	heading_box.add_child(_label("Play solo or up to max of 16 players", 15, COLOR_MUTED))
	var settings_button := _button("Settings", func() -> void: _show_settings("lobby"))
	settings_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(settings_button)
	lobby_player_count = _label("0 of 16 players", 15, COLOR_MUTED)
	main_column.add_child(lobby_player_count)
	lobby_roster = GridContainer.new()
	lobby_roster.columns = 4
	lobby_roster.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lobby_roster.add_theme_constant_override("h_separation", 10)
	lobby_roster.add_theme_constant_override("v_separation", 10)
	main_column.add_child(lobby_roster)
	var play := _primary_button("Choose a game  →", _play_from_lobby)
	main_column.add_child(play)

	var sidebar := PanelContainer.new()
	sidebar.custom_minimum_size = Vector2(320, 0)
	layout.add_child(sidebar)
	var side_margin := _panel_margin(12)
	sidebar.add_child(side_margin)
	var side_column := VBoxContainer.new()
	side_margin.add_child(side_column)
	side_column.add_child(_label("Join the party", 24, COLOR_TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var qr := TextureRect.new()
	qr.custom_minimum_size = Vector2(196, 196)
	qr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	qr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	qr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	qr.texture = QrCode.texture_for_text(lan_server.controller_url())
	side_column.add_child(qr)
	side_column.add_child(_connection_link("Local", lan_server.controller_url(), "ControllerUrl"))
	public_connection_link = _connection_link("Public", "", "PublicControllerUrl")
	side_column.add_child(public_connection_link)
	_update_public_connection_link()
	# Headless checks exercise lookup explicitly against an offline fixture.
	if DisplayServer.get_name() != "headless":
		public_address.refresh()
	side_column.add_child(_label("Scan with your phone on the same Wi-Fi.", 13, COLOR_MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	_build_solo_controls(side_column)
	_on_roster_changed(lan_server.get_players())
	_animate_screen(layout)


func _connection_link(caption: String, url: String, node_name: String) -> LinkButton:
	var link := LinkButton.new()
	link.name = node_name
	link.text = "%s: %s" % [caption, url.trim_prefix("http://").trim_suffix("/")]
	link.set_meta("controller_url", url)
	link.focus_mode = Control.FOCUS_ALL
	link.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	link.custom_minimum_size.y = 36
	link.underline = LinkButton.UNDERLINE_MODE_ALWAYS
	var notice := CenterContainer.new()
	notice.name = "CopyNotice"
	notice.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	notice.offset_top = -48
	notice.offset_bottom = -4
	notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice.hide()
	link.add_child(notice)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice.add_child(panel)
	panel.add_child(_label("Copied to clipboard", 14, COLOR_TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.one_shot = true
	timer.timeout.connect(notice.hide)
	notice.add_child(timer)
	link.pressed.connect(func() -> void:
		var copy_url := str(link.get_meta("controller_url", ""))
		if copy_url.is_empty():
			public_address.refresh(true)
			return
		DisplayServer.clipboard_set(copy_url)
		notice.show()
		timer.start()
	)
	return link


func _update_public_connection_link() -> void:
	if current_state != "lobby" or not is_instance_valid(public_connection_link):
		return
	var url: String = public_address.controller_url(lan_server.http_port)
	public_connection_link.set_meta("controller_url", url)
	public_connection_link.disabled = public_address.loading
	if not url.is_empty():
		public_connection_link.text = "Public: %s" % url.trim_prefix("http://").trim_suffix("/")
	elif public_address.loading:
		public_connection_link.text = "Public: Checking…"
	else:
		public_connection_link.text = "Public: Unavailable — Retry"


func _build_solo_controls(parent: VBoxContainer) -> void:
	parent.add_child(HSeparator.new())
	parent.add_child(_label("Playing solo?", 17, COLOR_TEXT))
	var hint := _label("Play as the host. Solo games do not affect points or win/loss stats.", 14, COLOR_MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(hint)


func _host_solo_profile() -> Dictionary:
	return {"id": "local-host", "display_name": profile_store.get_settings()["host_name"], "color": LanServer.PLAYER_COLORS[4]}


func _play_from_lobby() -> void:
	lan_server.set_lobby_open(false)
	_show_game_menu()


func _show_game_menu() -> void:
	current_state = "game_menu"
	_replace_screen()
	var outer := _screen_margin(32)
	screen_root.add_child(outer)
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	outer.add_child(panel)
	var margin := _panel_margin(16)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)
	var header := HFlowContainer.new()
	header.add_theme_constant_override("h_separation", get_theme_constant("separation", "HBoxContainer"))
	header.add_theme_constant_override("v_separation", get_theme_constant("separation", "VBoxContainer"))
	column.add_child(header)
	header.add_child(_button("‹  Your party", _show_lobby))
	var heading := _label("Choose a game", 34)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	game_view_toggle = _button("View: " + game_view.capitalize(), func() -> void: _set_game_view("icons" if game_view == "list" else "list"))
	game_view_toggle.toggle_mode = true
	game_view_toggle.button_pressed = game_view == "icons"
	header.add_child(game_view_toggle)
	game_filter_toggle = _button("Hide Locked" if show_all_games else "Show All", func() -> void: _set_show_all_games(not show_all_games))
	game_filter_toggle.toggle_mode = true
	game_filter_toggle.button_pressed = show_all_games
	header.add_child(game_filter_toggle)
	header.add_child(_button("Settings", func() -> void: _show_settings("game_menu")))
	lobby_diagnostics = _label("", 14, COLOR_MUTED)
	lobby_diagnostics.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(lobby_diagnostics)
	var scroll := ScrollContainer.new()
	game_menu_scroll = scroll
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.resized.connect(_update_game_menu_height)
	column.minimum_size_changed.connect(_update_game_menu_height.call_deferred)
	_update_game_menu_height.call_deferred()
	column.add_child(scroll)
	lobby_game_list = GridContainer.new()
	lobby_game_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(lobby_game_list)
	scroll.resized.connect(_update_game_columns)
	_scan_games()
	_animate_screen(panel)


func _update_game_menu_height() -> void:
	if current_state != "game_menu" or not is_instance_valid(game_menu_scroll):
		return
	var column := game_menu_scroll.get_parent() as VBoxContainer
	var panel := column.get_parent().get_parent() as PanelContainer
	var outer := panel.get_parent() as MarginContainer
	var chrome_height := panel.get_combined_minimum_size().y - game_menu_scroll.get_combined_minimum_size().y
	var available_height := screen_root.size.y - outer.get_theme_constant("margin_top") - outer.get_theme_constant("margin_bottom") - chrome_height
	game_menu_scroll.custom_minimum_size.y = clampf(available_height, 0, 560)


func _set_game_view(view: String) -> void:
	if view not in ["list", "icons"]:
		return
	game_view = view
	_save_setting("game_view", view)
	if is_instance_valid(game_view_toggle):
		game_view_toggle.set_pressed_no_signal(view == "icons")
		game_view_toggle.text = "View: " + view.capitalize()
	_rebuild_game_list()


func _set_show_all_games(value: bool) -> void:
	show_all_games = value
	if is_instance_valid(game_filter_toggle):
		game_filter_toggle.set_pressed_no_signal(value)
		game_filter_toggle.text = "Hide Locked" if value else "Show All"
	_rebuild_game_list()


func _update_game_columns() -> void:
	if not is_instance_valid(lobby_game_list) or not is_instance_valid(game_menu_scroll):
		return
	for separation in ["h_separation", "v_separation"]:
		if game_view == "icons":
			lobby_game_list.add_theme_constant_override(separation, 12)
		else:
			lobby_game_list.remove_theme_constant_override(separation)
	var gap := lobby_game_list.get_theme_constant("h_separation")
	var available_width := game_menu_scroll.size.x - game_menu_scroll.get_v_scroll_bar().get_combined_minimum_size().x
	var columns := clampi(int((available_width + gap) / (GAME_ICON_CARD_WIDTH + gap)), 1, GAME_ICON_MAX_COLUMNS)
	var visible_count := lobby_game_list.get_child_count()
	lobby_game_list.columns = mini(visible_count, columns) if game_view == "icons" and visible_count > 0 else 1


func _scan_games() -> void:
	var previous := JSON.stringify([game_catalog.games, game_catalog.diagnostics])
	game_catalog.scan()
	if previous != JSON.stringify([game_catalog.games, game_catalog.diagnostics]) or (is_instance_valid(lobby_game_list) and lobby_game_list.get_child_count() == 0):
		_rebuild_game_list()


func _rebuild_game_list() -> void:
	if current_state != "game_menu" or not is_instance_valid(lobby_game_list):
		return
	_free_children(lobby_game_list)
	var visible_games := game_catalog.menu_games().filter(func(game: Dictionary) -> bool: return show_all_games or _can_launch(game))
	if visible_games.is_empty():
		var empty := PanelContainer.new()
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty.custom_minimum_size = Vector2(0, 340)
		lobby_game_list.add_child(empty)
		var center := CenterContainer.new()
		empty.add_child(center)
		var copy := VBoxContainer.new()
		copy.alignment = BoxContainer.ALIGNMENT_CENTER
		center.add_child(copy)
		copy.add_child(_label("✦", 54, COLOR_ACCENT_2, HORIZONTAL_ALIGNMENT_CENTER))
		copy.add_child(_label("Great games start here" if game_catalog.games.is_empty() else "No games for this party size", 25, COLOR_TEXT, HORIZONTAL_ALIGNMENT_CENTER))
		var hint := _label("Your collection will appear here when games are added." if game_catalog.games.is_empty() else "Choose Show All to see every game, or return to Your party to change the player count.", 15, COLOR_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		copy.add_child(hint)
	else:
		for game in visible_games:
			lobby_game_list.add_child(_game_card(game, game_view == "icons"))
	_update_game_columns()
	if not game_catalog.diagnostics.is_empty():
		var lines: Array[String] = []
		for issue in game_catalog.diagnostics:
			lines.append("%s: %s" % [issue["folder"], issue["message"]])
		lobby_diagnostics.text = "Scan skipped %d item(s):\n%s" % [lines.size(), "\n".join(lines)]
	else:
		lobby_diagnostics.text = "%d games in your collection" % game_catalog.menu_games().size()
		lobby_diagnostics.add_theme_color_override("font_color", COLOR_MUTED)

	lobby_diagnostics.visible = not game_catalog.diagnostics.is_empty() or not game_catalog.games.is_empty()


func _game_card(game: Dictionary, icons := false) -> Control:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin := _panel_margin(4 if icons else 8)
	card.add_child(margin)
	var row: BoxContainer = VBoxContainer.new() if icons else HBoxContainer.new()
	if icons:
		row.add_theme_constant_override("separation", 8)
	margin.add_child(row)
	var image := TextureRect.new()
	image.custom_minimum_size = Vector2(0, 80) if icons else Vector2(184, 116)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture = RuntimeAssets.texture(game["thumbnail_path"])
	row.add_child(image)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if icons:
		text.add_theme_constant_override("separation", 4)
		text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var title := _label(str(game["title"]), 16 if icons else 24, COLOR_TEXT, HORIZONTAL_ALIGNMENT_CENTER if icons else HORIZONTAL_ALIGNMENT_LEFT)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(title)
	var details := "%d–%d players" % [game["min_players"], game["max_players"]]
	if not icons:
		details += "  •  %s" % " / ".join(game["modes"])
	var player_limits := _label(details, 13 if icons else 14, COLOR_ACCENT, HORIZONTAL_ALIGNMENT_CENTER if icons else HORIZONTAL_ALIGNMENT_LEFT)
	player_limits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(player_limits)
	if not icons:
		var description := _label(str(game["description"]), 15, COLOR_MUTED)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_child(description)
	var launch := _primary_button("Play", func() -> void: _launch_game(game))
	if icons:
		launch.custom_minimum_size = Vector2(88, 40)
		launch.add_theme_font_size_override("font_size", 14)
	launch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	launch.disabled = not _can_launch(game)
	row.add_child(launch)
	return card


func _can_launch(game: Dictionary) -> bool:
	var count := lan_server.get_admitted_players().size() if game.has("game_choices") and not lan_server.lobby_open else lan_server.get_players().size()
	return _can_launch_for_count(game, count)


func _can_launch_for_count(game: Dictionary, party_count: int) -> bool:
	if game.has("game_choices"):
		return game.game_choices.any(func(id: String) -> bool:
			var child := game_catalog.find_game(id)
			return not child.is_empty() and _can_launch_for_count(child, party_count))
	return (game["modes"].has("multiplayer") and party_count >= int(game["min_players"]) and party_count <= int(game["max_players"])) or (party_count == 0 and game["modes"].has("singleplayer"))


func _launch_game(game: Dictionary, collection_id := "", party_roster: Array = []) -> void:
	var roster := party_roster.duplicate(true)
	if roster.is_empty(): roster = lan_server.get_admitted_players() if game.has("game_choices") and not lan_server.lobby_open else lan_server.get_players()
	if not _can_launch_for_count(game, roster.size()):
		return
	var packed := load(game["host_scene_path"]) as PackedScene
	if packed == null:
		_show_error("The host scene could not be loaded.")
		return
	if is_instance_valid(active_game):
		active_game.shutdown_game()
		ThemePacks.unpin(active_game_id)
		active_game.queue_free()
	# Pin before instantiation: module member initializers and _ready load art.
	var skins := ThemePacks.new(str(game.id), str(game.folder).get_base_dir())
	var skin_settings := game_settings_store.load_settings(str(game.id), {"theme": "default"})
	skins.pin(str(skin_settings.theme))
	var instance := packed.instantiate()
	if not instance is BaseGame:
		instance.queue_free()
		ThemePacks.unpin(str(game.id))
		_show_error("The game host scene root must extend BaseGame.")
		return
	var selected_profile := _host_solo_profile()
	instance.settings_store = game_settings_store
	var count := roster.size()
	var is_party: bool = game["modes"].has("multiplayer") and count >= int(game["min_players"]) and count <= int(game["max_players"])
	active_game_is_party = is_party
	var context := GameSessionContext.new(game["id"], roster if is_party else [], selected_profile, is_party)
	context.reduced_motion = bool(profile_store.get_settings().get("reduced_motion", false))
	for id in game.get("game_choices", []):
		var choice := game_catalog.find_game(id).duplicate(true)
		choice["can_launch"] = _can_launch_for_count(choice, count)
		context.game_choices.append(choice)
	current_state = "game"
	_replace_screen()
	active_game = instance
	active_game_id = game["id"]
	active_collection_id = collection_id
	collection_roster = context.players.duplicate(true) if game.has("game_choices") or not collection_id.is_empty() else []
	active_game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_root.add_child(active_game)
	active_game.points_awarded.connect(_on_points_awarded)
	active_game.result_reported.connect(_on_result_reported)
	active_game.return_to_lobby_requested.connect(_return_from_game)
	active_game.game_selected.connect(_on_collection_choice)
	active_game.controller_state_updated.connect(lan_server.broadcast_game_message)
	active_game.controller_private_state_updated.connect(lan_server.send_game_message_to_player)
	active_game.controller_media_updated.connect(func(resources: Dictionary) -> void: lan_server.set_game_media(str(game.id), resources))
	lan_server.set_active_game(active_game_id if is_party else "")
	active_game.initialize_session(context)
	var connected_ids := lan_server.get_players().map(func(player: Dictionary) -> String: return str(player.id))
	for player in context.players:
		if not connected_ids.has(str(player.id)): active_game.player_disconnected(str(player.id))
	active_game.start_game()


func _on_collection_choice(id: String) -> void:
	var collection := game_catalog.find_game(active_game_id)
	if not collection.get("game_choices", []).has(id): return
	var child := game_catalog.find_game(id)
	if child.is_empty() or not _can_launch_for_count(child, collection_roster.size()): return
	var connected_ids := lan_server.get_players().map(func(player: Dictionary) -> String: return str(player.id))
	if connected_ids.size() != collection_roster.size() or not collection_roster.all(func(player: Dictionary) -> bool: return connected_ids.has(str(player.id))): return
	_launch_game(child, collection.id, collection_roster)


func _return_from_game() -> void:
	var collection := game_catalog.find_game(active_collection_id)
	var roster := collection_roster.duplicate(true)
	if active_game != null and is_instance_valid(active_game):
		active_game.shutdown_game()
		ThemePacks.unpin(active_game_id)
		active_game.queue_free()
	active_game = null
	active_game_id = ""
	active_collection_id = ""
	collection_roster = []
	active_game_is_party = false
	if not collection.is_empty() and _can_launch_for_count(collection, roster.size()): _launch_game(collection, "", roster)
	else:
		lan_server.set_active_game("")
		_show_game_menu()


func _show_settings(caller: String) -> void:
	settings_caller = caller
	current_state = "settings"
	_replace_screen()
	var outer := _screen_margin(32)
	screen_root.add_child(outer)
	var panel := PanelContainer.new()
	outer.add_child(panel)
	var margin := _panel_margin(30)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	header.add_child(_button("← RETURN", _return_from_settings))
	var heading := _label("HOST SETTINGS", 34, COLOR_TEXT)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(heading)
	var debug_button := _button("Debug", _open_debug_controllers)
	debug_button.custom_minimum_size.x = 120
	debug_button.disabled = not debug_browsers.is_supported() or not lan_server.running
	var editor_button := _button("Asset Editor", _show_asset_editor)
	editor_button.disabled = OS.get_name() not in ["Windows", "macOS", "Linux"]
	header.add_child(editor_button)
	header.add_child(debug_button)
	debug_notice = _label("", 14, COLOR_MUTED)
	debug_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	debug_notice.visible = debug_button.disabled
	debug_notice.text = "Debug browser launch is available on desktop hosts." if not debug_browsers.is_supported() else "Enter the lobby to start the controller server before using Debug."
	column.add_child(debug_notice)
	# The inspector also works without a running server. F8 opens it in games.
	var lab_button := _button("Debug Lab · F8", _toggle_debug_lab)
	lab_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	column.add_child(lab_button)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var settings_column := VBoxContainer.new()
	settings_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(settings_column)
	var current := profile_store.get_settings()
	settings_column.add_child(_section_title("AUDIO & DISPLAY"))
	settings_column.add_child(_slider_setting("Master volume", float(current["master_volume"]), func(value: float) -> void: _save_setting("master_volume", value)))
	settings_column.add_child(_slider_setting("Music volume", float(current["music_volume"]), func(value: float) -> void: _save_setting("music_volume", value)))
	settings_column.add_child(_slider_setting("Effects volume", float(current["effects_volume"]), func(value: float) -> void: _save_setting("effects_volume", value)))
	var fullscreen := CheckBox.new()
	fullscreen.text = "Fullscreen"
	fullscreen.button_pressed = bool(current["fullscreen"])
	fullscreen.toggled.connect(func(value: bool) -> void: _save_setting("fullscreen", value))
	settings_column.add_child(fullscreen)
	var reduced := CheckBox.new()
	reduced.text = "Reduced motion"
	reduced.button_pressed = bool(current["reduced_motion"])
	reduced.toggled.connect(func(value: bool) -> void: _save_setting("reduced_motion", value))
	settings_column.add_child(reduced)
	var host_row := HBoxContainer.new()
	settings_column.add_child(host_row)
	var host_label := _label("Host display name", 17, COLOR_TEXT)
	host_label.custom_minimum_size.x = 200
	host_row.add_child(host_label)
	var host_name := LineEdit.new()
	host_name.text = str(current["host_name"])
	host_name.max_length = 32
	host_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host_name.text_submitted.connect(func(value: String) -> void: _save_setting("host_name", value.strip_edges()))
	host_name.focus_exited.connect(func() -> void: _save_setting("host_name", host_name.text.strip_edges()))
	host_row.add_child(host_name)

	settings_column.add_child(_section_title("PROFILE & SCORE ADMINISTRATION"))
	profile_option = OptionButton.new()
	profile_option.item_selected.connect(_load_selected_profile_editor)
	settings_column.add_child(profile_option)
	profile_name_edit = LineEdit.new()
	profile_name_edit.placeholder_text = "Profile name"
	profile_name_edit.max_length = 24
	settings_column.add_child(profile_name_edit)
	settings_column.add_child(_button("SAVE PROFILE NAME", _rename_selected_profile))
	var score_row := HBoxContainer.new()
	settings_column.add_child(score_row)
	game_id_edit = LineEdit.new()
	game_id_edit.placeholder_text = "Game ID"
	game_id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	score_row.add_child(game_id_edit)
	game_points_spin = SpinBox.new()
	game_points_spin.min_value = -999999
	game_points_spin.max_value = 999999999
	game_points_spin.step = 1
	game_points_spin.custom_minimum_size.x = 180
	score_row.add_child(game_points_spin)
	score_row.add_child(_button("SET POINTS", _set_selected_game_points))
	var reset_row := HBoxContainer.new()
	settings_column.add_child(reset_row)
	reset_row.add_child(_button("RESET THIS GAME", func() -> void: _confirm("Reset this game’s points for the selected profile?", _reset_selected_game)))
	reset_row.add_child(_button("RESET THIS PROFILE", func() -> void: _confirm("Reset every score for the selected profile?", _reset_selected_profile), COLOR_DANGER))
	reset_row.add_child(_button("RESET ALL SCORES", func() -> void: _confirm("Reset every score for every profile? This cannot be undone.", _reset_all_profiles), COLOR_DANGER))
	settings_notice = _label("", 14, COLOR_MUTED)
	settings_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	settings_column.add_child(settings_notice)
	_refresh_profile_editor()
	_animate_screen(panel)


func _show_asset_editor() -> void:
	current_state = "asset_editor"
	_replace_screen()
	title_background.release_assets()
	asset_editor = preload("res://scripts/asset_editor.gd").new()
	asset_editor.game_settings_store = game_settings_store
	asset_editor.reduced_motion = bool(profile_store.get_settings().get("reduced_motion", false))
	screen_root.add_child(asset_editor)
	asset_editor.exit_requested.connect(func() -> void: _show_settings(settings_caller))
	asset_editor.quit_requested.connect(_quit_application)
	asset_editor.asset_saved.connect(_on_asset_saved)
	_animate_screen(asset_editor)


func _on_asset_saved(path: String) -> void:
	if path.begins_with("asset/splash_background/"):
		title_background.reload_assets()
	elif path.begins_with("asset/lobby_songs/"):
		menu_music.reload_assets()
	elif path.begins_with("asset/music/"):
		game_music.reload_assets()


func _return_from_settings() -> void:
	if settings_caller == "game_menu":
		_show_game_menu()
	elif settings_caller == "lobby":
		_show_lobby()
	else:
		_show_title()


func _open_debug_controllers() -> void:
	if not debug_browsers.is_supported() or not lan_server.running:
		return
	var result: Dictionary = debug_browsers.open_controllers(lan_server.controller_url())
	var messages := PackedStringArray()
	if not result.opened.is_empty():
		messages.append("Opened: %s." % ", ".join(result.opened))
	else:
		messages.append("No browsers opened.")
	if not result.missing.is_empty():
		messages.append("Not installed or not found: %s." % ", ".join(result.missing))
	if not result.failed.is_empty():
		messages.append("Could not open: %s." % ", ".join(result.failed))
	if not lan_server.lobby_open:
		messages.append("Return to the lobby to let new test players join.")
	debug_notice.text = " ".join(messages)
	debug_notice.visible = true
	debug_notice.add_theme_color_override("font_color", COLOR_ACCENT if result.missing.is_empty() and result.failed.is_empty() else COLOR_DANGER)


func _leave_lobby() -> void:
	lan_server.stop_server()
	_show_title()


func _quit_application() -> void:
	if is_instance_valid(active_game): active_game.shutdown_game()
	profile_store.save_data()
	lan_server.stop_server()
	get_tree().quit()


func _refresh_profile_editor() -> void:
	if profile_option == null or not is_instance_valid(profile_option):
		return
	profile_option.clear()
	for profile in profile_store.get_profiles():
		var index := profile_option.item_count
		profile_option.add_item("%s  —  %d lifetime points" % [profile["display_name"], profile_store.lifetime_points(profile)])
		profile_option.set_item_metadata(index, profile["id"])
	_load_selected_profile_editor(0)


func _load_selected_profile_editor(_index: int) -> void:
	var profile := _selected_admin_profile()
	profile_name_edit.editable = not profile.is_empty()
	profile_name_edit.text = str(profile.get("display_name", ""))
	if not game_id_edit.text.is_empty():
		game_points_spin.value = int(profile.get("game_points", {}).get(game_id_edit.text, 0))


func _selected_admin_profile() -> Dictionary:
	if profile_option == null or profile_option.selected < 0 or profile_option.item_count == 0:
		return {}
	return profile_store.get_profile(str(profile_option.get_item_metadata(profile_option.selected)))


func _rename_selected_profile() -> void:
	var profile := _selected_admin_profile()
	if profile.is_empty():
		_settings_message("Create a profile in the lobby first.", true)
		return
	var result := profile_store.rename_profile(profile["id"], profile_name_edit.text)
	_settings_message("Profile name saved." if result["ok"] else result["error"], not result["ok"])
	_refresh_profile_editor()


func _set_selected_game_points() -> void:
	var profile := _selected_admin_profile()
	if profile.is_empty():
		_settings_message("Select a profile first.", true)
		return
	var game_id := game_id_edit.text.strip_edges()
	if profile_store.set_game_points(profile["id"], game_id, int(game_points_spin.value)):
		_settings_message("Points saved for %s." % game_id)
		_refresh_profile_editor()
	else:
		_settings_message(profile_store.last_error, true)


func _reset_selected_game() -> void:
	var profile := _selected_admin_profile()
	var game_id := game_id_edit.text.strip_edges()
	if game_id.is_empty():
		_settings_message("Enter a game ID first.", true)
		return
	if not profile.is_empty() and profile_store.reset_game_points(profile["id"], game_id):
		_settings_message("Selected game score reset.")
		_refresh_profile_editor()


func _reset_selected_profile() -> void:
	var profile := _selected_admin_profile()
	if not profile.is_empty() and profile_store.reset_profile_points(profile["id"]):
		_settings_message("Selected profile scores reset.")
		_refresh_profile_editor()


func _reset_all_profiles() -> void:
	profile_store.reset_all_points()
	_settings_message("All profile scores reset.")
	_refresh_profile_editor()


func _save_setting(key: String, value: Variant) -> void:
	profile_store.update_settings({key: value})
	_apply_runtime_settings()


func _apply_runtime_settings() -> void:
	var settings := profile_store.get_settings()
	if menu_music != null:
		menu_music.reduced_motion = bool(settings.get("reduced_motion", false))
		menu_music.set_volume(float(settings["music_volume"]))
	_set_bus_volume("Master", float(settings["master_volume"]))
	if game_music != null:
		game_music.reduced_motion = bool(settings.get("reduced_motion", false))
		game_music.set_volume(float(settings["music_volume"]))
	_set_bus_volume("Music", float(settings["music_volume"]))
	_set_bus_volume("Effects", float(settings["effects_volume"]))
	if OS.get_name() in ["Windows", "macOS", "Linux"]:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED)


func _set_bus_volume(bus_name: String, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.001)))
		AudioServer.set_bus_mute(index, linear <= 0.001)


func _on_roster_changed(players: Array) -> void:
	if current_state == "game_menu":
		_rebuild_game_list()
	if current_state != "lobby" or not is_instance_valid(lobby_roster):
		return
	# Keep animated visuals alive when roster cards are rebuilt.
	for existing in lobby_avatars.values():
		if is_instance_valid(existing) and existing.get_parent() != null:
			existing.get_parent().remove_child(existing)
	var next_avatars: Dictionary = {}
	var next_states: Dictionary = {}
	_free_children(lobby_roster)
	lobby_player_count.text = "%d of 16 players" % players.size()
	for index in 16:
		var occupied := index < players.size()
		var player: Dictionary = players[index] if occupied else {}
		var color := Color(str(player.get("color", "#3a3b43")))
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", _style(Color("27282e") if occupied else Color("202126"), 16, 1, Color("ffffff18") if occupied else Color("ffffff06")))
		lobby_roster.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		card.add_child(row)
		# Containers reset the scale of direct children during layout. Animate an
		# inner visual instead, so roster updates cannot erase the animation.
		var avatar_slot := Control.new()
		avatar_slot.custom_minimum_size = Vector2(40, 56)
		avatar_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
		row.add_child(avatar_slot)
		var id := str(player.get("id", ""))
		var previous_avatar: Variant = lobby_avatars.get(id) if occupied else null
		var avatar: TextureRect = previous_avatar if is_instance_valid(previous_avatar) else null
		if not is_instance_valid(avatar):
			avatar = TextureRect.new()
			avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		avatar_slot.add_child(avatar)
		avatar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if occupied:
			var previous: Dictionary = avatar_states.get(id, {})
			if previous.get("color", "") != player.get("color", "") or previous.get("pose", -1) != player.get("pose", 0) or avatar.texture == null:
				var old_color := avatar.modulate if not previous.is_empty() else color
				avatar.texture = RuntimeAssets.texture("res://web/avatar-%d.svg" % int(player.get("pose", 0)))
				_animate_avatar(avatar, old_color, color)
			next_avatars[id] = avatar
			next_states[id] = player.duplicate(true)
		else:
			avatar.texture = RuntimeAssets.texture("res://web/avatar.svg")
			avatar.modulate = Color("72747e44")
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		column.add_theme_constant_override("separation", 3)
		row.add_child(column)
		var name_label := _label(str(player.get("display_name", "")), 16, COLOR_TEXT if occupied else COLOR_MUTED)
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		column.add_child(name_label)
		if occupied:
			var profile := profile_store.get_profile(str(player["id"]))
			var wins := int(profile.get("wins", 0))
			var losses := int(profile.get("losses", 0))
			var ratio := "%.2f" % (float(wins) / losses) if losses > 0 else ("∞" if wins > 0 else "—")
			column.add_child(_label("%d wins / %d losses" % [wins, losses], 12, COLOR_MUTED))
			column.add_child(_label("W/L ratio  %s" % ratio, 12, COLOR_MUTED))
			_ignore_player_card_children(row)
			card.gui_input.connect(func(event: InputEvent) -> void:
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
					_show_player_menu(str(player["id"]))
			)

	for id in lobby_avatars:
		if not next_avatars.has(id) and is_instance_valid(lobby_avatars[id]):
			lobby_avatars[id].queue_free()
	lobby_avatars = next_avatars
	avatar_states = next_states


func _animate_avatar(avatar: TextureRect, old_color: Color, target: Color) -> void:
	var previous_tween: Tween = avatar.get_meta("avatar_tween") if avatar.has_meta("avatar_tween") else null
	if previous_tween != null:
		previous_tween.kill()
	avatar.modulate = target
	avatar.scale = Vector2.ONE
	avatar.rotation = 0.0
	if profile_store.get_settings().get("reduced_motion", false):
		return
	if not avatar.resized.is_connected(_center_avatar_pivot.bind(avatar)):
		avatar.resized.connect(_center_avatar_pivot.bind(avatar))
	_center_avatar_pivot(avatar)
	avatar.modulate = old_color
	avatar.scale = Vector2(0.7, 0.7)
	avatar.rotation = deg_to_rad(-12.0)
	var tween := avatar.create_tween().set_parallel(true)
	avatar.set_meta("avatar_tween", tween)
	tween.tween_property(avatar, "modulate", target, 0.35)
	tween.tween_property(avatar, "scale", Vector2(1.18, 1.18), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(avatar, "rotation", deg_to_rad(6.0), 0.22)
	tween.chain().tween_property(avatar, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(avatar, "rotation", 0.0, 0.28)


func _center_avatar_pivot(avatar: TextureRect) -> void:
	avatar.pivot_offset = avatar.size * 0.5


func _ignore_player_card_children(node: Control) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		if child is Control:
			_ignore_player_card_children(child)


func _show_player_menu(player_id: String) -> void:
	if not lan_server.active_players.has(player_id):
		return
	var menu := PopupMenu.new()
	menu.add_item("Change avatar color", 0)
	menu.add_item("Personal scores / stats", 1)
	menu.add_separator()
	menu.add_item("Kick player", 2)
	menu.id_pressed.connect(func(id: int) -> void:
		match id:
			0: _show_player_colors(player_id)
			1: _show_player_stats(player_id)
			2: lan_server.kick_player(player_id)
	)
	menu.popup_hide.connect(menu.queue_free)
	add_child(menu)
	menu.position = Vector2i(get_viewport().get_mouse_position())
	menu.popup()


func _show_player_colors(player_id: String) -> void:
	if not lan_server.active_players.has(player_id):
		return
	var menu := PopupMenu.new()
	for index in LanServer.PLAYER_COLORS.size():
		var color: String = LanServer.PLAYER_COLORS[index]
		var swatch := Image.create(20, 20, false, Image.FORMAT_RGBA8)
		swatch.fill(Color(color))
		var selected: bool = lan_server.active_players[player_id]["color"] == color
		menu.add_icon_item(ImageTexture.create_from_image(swatch), LanServer.COLOR_NAMES[index] + (" (current)" if selected else ""), index)
		menu.set_item_disabled(index, not lan_server.color_available(color, player_id))
	menu.id_pressed.connect(func(index: int) -> void:
		if not lan_server.change_player_color(player_id, LanServer.PLAYER_COLORS[index]):
			_show_error("That color is no longer available.")
	)
	menu.popup_hide.connect(menu.queue_free)
	add_child(menu)
	menu.position = Vector2i(get_viewport().get_mouse_position())
	menu.popup()


func _show_player_stats(player_id: String) -> void:
	var profile := profile_store.get_profile(player_id)
	if profile.is_empty():
		return
	var dialog := AcceptDialog.new()
	dialog.title = "%s ? Scores / stats" % profile["display_name"]
	var lines: Array[String] = ["Lifetime points: %d" % profile_store.lifetime_points(profile), "Games with recorded scores: %d" % profile["game_points"].size(), "", "PERSONAL SCORES"]
	var game_ids: Array = profile["game_points"].keys()
	game_ids.sort()
	for game_id in game_ids:
		lines.append("%s: %d points" % [game_id, profile["game_points"][game_id]])
	if game_ids.is_empty():
		lines.append("No scores recorded yet.")
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(440, 260)
	var label := _label("\n".join(lines), 18)
	scroll.add_child(label)
	dialog.add_child(scroll)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(500, 350))


func _on_player_joined(player: Dictionary) -> void:
	if active_game != null:
		active_game.player_joined(player)


func _on_player_disconnected(player_id: String) -> void:
	if active_game != null:
		active_game.player_disconnected(player_id)


func _on_controller_message(player_id: String, message: Dictionary) -> void:
	if active_game != null:
		active_game.handle_controller_message(player_id, message)


func _on_result_reported(profile_id: String, won: bool) -> void:
	if active_game_is_party and not active_game_id.is_empty():
		profile_store.record_result(profile_id, won)


func _on_points_awarded(profile_id: String, amount: int) -> void:
	if active_game_is_party and not active_game_id.is_empty():
		profile_store.add_game_points(profile_id, active_game_id, amount)


func _replace_screen() -> void:
	if is_instance_valid(debug_lab): debug_lab.close()
	_cancel_title_intro()
	public_connection_link = null
	if screen_transition != null:
		screen_transition.kill()
		screen_transition = null
	if title_transition != null:
		title_transition.kill()
		title_transition = null
	entering_lobby = false
	screen_root.modulate = Color.WHITE
	screen_root.position = Vector2.ZERO
	if menu_music != null:
		menu_music.set_active(current_state in ["title", "lobby", "game_menu", "settings"])
	if game_music != null:
		game_music.set_active(current_state == "game")
	if title_background != null:
		title_background.modulate = Color.WHITE
		title_background.scale = Vector2.ONE
		title_background.set_active(current_state == "title")
	for child in screen_root.get_children():
		screen_root.remove_child(child)
		child.queue_free()


func _animate_screen(node: Control) -> void:
	if profile_store.get_settings().get("reduced_motion", false):
		return
	node.modulate.a = 0.0
	# Containers own their children's positions and finish layout asynchronously.
	# Move the independent screen layer so entry motion never overwrites centering.
	screen_root.position.y = 14.0
	screen_transition = create_tween().set_parallel(true)
	screen_transition.tween_property(node, "modulate:a", 1.0, 0.25)
	screen_transition.tween_property(screen_root, "position:y", 0.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _show_error(message: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "The Star Games"
	dialog.dialog_text = message
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(520, 220))


func _confirm(message: String, action: Callable) -> void:
	pending_confirmation = action
	var dialog := ConfirmationDialog.new()
	dialog.title = "Confirm score reset"
	dialog.dialog_text = message
	dialog.confirmed.connect(func() -> void:
		if pending_confirmation.is_valid():
			pending_confirmation.call()
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(560, 230))


func _settings_message(message: String, is_error := false) -> void:
	if settings_notice != null and is_instance_valid(settings_notice):
		settings_notice.text = message
		settings_notice.add_theme_color_override("font_color", COLOR_DANGER if is_error else COLOR_ACCENT)


func _screen_margin(amount: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, amount)
	return margin


func _panel_margin(amount: int) -> MarginContainer:
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, amount)
	return margin


func _label(text_value: String, font_size: int, color := COLOR_TEXT, alignment := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var result := Label.new()
	result.text = text_value
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	result.horizontal_alignment = alignment
	return result


func _button(text_value: String, callback: Callable, accent := Color.TRANSPARENT) -> Button:
	var result := Button.new()
	result.text = text_value
	result.custom_minimum_size = Vector2(110, 46)
	if accent != Color.TRANSPARENT:
		result.add_theme_color_override("font_color", accent)
	result.pressed.connect(callback)
	return result


func _primary_button(text_value: String, callback: Callable) -> Button:
	var result := _button(text_value, callback)
	result.add_theme_stylebox_override("normal", _style(Color("007aff"), 12))
	result.add_theme_stylebox_override("hover", _style(Color("2991ff"), 12))
	result.add_theme_stylebox_override("pressed", _style(Color("0062cc"), 12))
	result.add_theme_color_override("font_color", Color.WHITE)
	return result


func _menu_button(text_value: String, callback: Callable, accent := Color.TRANSPARENT) -> Button:
	var result := _button(text_value, callback, accent)
	result.custom_minimum_size = Vector2(360, 58)
	result.add_theme_font_size_override("font_size", 21)
	return result


func _section_title(text_value: String) -> Label:
	var result := _label(text_value, 20, COLOR_ACCENT)
	result.add_theme_constant_override("outline_size", 2)
	return result


func _slider_setting(text_value: String, current: float, callback: Callable) -> Control:
	var row := HBoxContainer.new()
	var setting_label := _label(text_value, 17, COLOR_TEXT)
	setting_label.custom_minimum_size.x = 200
	row.add_child(setting_label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = current
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(callback)
	row.add_child(slider)
	return row


func _style(color: Color, radius: int, border_width := 0, border_color := Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_width_top = border_width
	style.border_width_bottom = border_width
	style.border_color = border_color
	style.border_blend = true
	style.corner_detail = 16
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style


func _free_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
