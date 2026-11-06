class_name BaseGame
extends Control

signal points_awarded(profile_id: String, amount: int)
signal result_reported(profile_id: String, won: bool)
signal return_to_lobby_requested
signal controller_state_updated(payload: Dictionary)
signal controller_private_state_updated(player_id: String, payload: Dictionary)
signal controller_media_updated(resources: Dictionary)
signal game_selected(game_id: String)

var session: GameSessionContext
var settings_store := GameSettingsStore.new()
var _controller_media: Dictionary = {}
var _debug_settings: Dictionary = {}


func initialize_session(context: GameSessionContext) -> void:
	session = context


func load_game_settings(defaults: Dictionary) -> Dictionary:
	if session != null and session.debug_mode:
		return GameSettingsStore._with_defaults(defaults, _debug_settings)
	return settings_store.load_settings(session.game_id, defaults)


# Save accepted changes immediately so even quitting during play retains them.
func save_game_settings(values: Dictionary) -> bool:
	if session != null and session.debug_mode:
		_debug_settings.merge(values.duplicate(true), true)
		return true
	if settings_store.save_settings(session.game_id, values):
		return true
	push_warning(settings_store.last_error)
	return false


func start_game() -> void:
	pass


# Mount an existing shared choice control in host Settings. The launcher owns
# eligibility, persistence, teardown, theme pinning and controller navigation.
func configure_game_mode_choice(choice: OptionButton) -> void:
	choice.clear()
	choice.accessibility_name = "Game mode"
	choice.fit_to_longest_item = false
	choice.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	choice.get_parent().visible = not session.game_choices.is_empty()
	for option in session.game_choices:
		choice.add_item(str(option.title))
		var index := choice.item_count - 1
		choice.set_item_metadata(index, option.id)
		choice.set_item_disabled(index, not bool(option.get("can_launch", false)))
		if option.id == session.game_id: choice.select(index)
	var current := choice.selected
	choice.item_selected.connect(func(index: int) -> void:
		choice.select(current)
		if choice.disabled or index < 0 or index >= choice.item_count or choice.is_item_disabled(index): return
		var id := str(choice.get_item_metadata(index))
		if id != session.game_id: game_selected.emit(id)
	)


# The launcher delivers snapshots through its existing LAN server.
func broadcast_state(payload: Dictionary) -> void:
	controller_state_updated.emit(_with_skin(payload))


# Hidden-information games send each admitted player only their own view.
func send_state(player_id: String, payload: Dictionary) -> void:
	controller_private_state_updated.emit(player_id, _with_skin(payload))


func _with_skin(payload: Dictionary) -> Dictionary:
	if session == null or payload.has("theme"): return payload
	var skin := ThemePacks.snapshot(session.game_id)
	if skin.is_empty(): return payload
	var view := payload.duplicate()
	view["theme"] = skin
	return view


# Expose only the files currently permitted by the game. URLs are unguessable
# capabilities, not filenames; replacing this set revokes earlier URLs. Send a
# capability only in the public/private snapshot authorized to receive it.
func set_controller_media(paths: Array) -> Dictionary:
	var next: Dictionary = {}
	var urls: Dictionary = {}
	for path in paths.slice(0, 64):
		if not path is String or next.has(path): continue
		var token: String = _controller_media.get(path, Crypto.new().generate_random_bytes(24).hex_encode())
		next[path] = token
		urls[path] = "/session-media/" + token
	if next != _controller_media:
		_controller_media = next
		var resources: Dictionary = {}
		for path in next: resources[next[path]] = path
		controller_media_updated.emit(resources)
	return urls


func shutdown_game() -> void:
	pass


func player_joined(_player: Dictionary) -> void:
	pass


func player_disconnected(_player_id: String) -> void:
	pass


func player_reconnected(_player: Dictionary) -> void:
	pass


func handle_controller_message(_player_id: String, _message: Dictionary) -> void:
	pass


func award_points(profile_id: String, amount: int) -> void:
	if session != null and session.debug_mode: return
	points_awarded.emit(profile_id, amount)


# Report once per player per completed game; omit draws and abandoned games.
func report_result(profile_id: String, won: bool) -> void:
	if session != null and session.debug_mode: return
	result_reported.emit(profile_id, won)


func return_to_lobby() -> void:
	return_to_lobby_requested.emit()
