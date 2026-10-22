class_name BaseGame
extends Control

signal points_awarded(profile_id: String, amount: int)
signal result_reported(profile_id: String, won: bool)
signal return_to_lobby_requested
signal controller_state_updated(payload: Dictionary)
signal controller_private_state_updated(player_id: String, payload: Dictionary)
signal game_selected(game_id: String)

var session: GameSessionContext
var settings_store := GameSettingsStore.new()


func initialize_session(context: GameSessionContext) -> void:
	session = context


func load_game_settings(defaults: Dictionary) -> Dictionary:
	return settings_store.load_settings(session.game_id, defaults)


# Save accepted changes immediately so even quitting during play retains them.
func save_game_settings(values: Dictionary) -> bool:
	if settings_store.save_settings(session.game_id, values):
		return true
	push_warning(settings_store.last_error)
	return false


func start_game() -> void:
	pass


# The launcher delivers snapshots through its existing LAN server.
func broadcast_state(payload: Dictionary) -> void:
	controller_state_updated.emit(payload)


# Hidden-information games send each admitted player only their own view.
func send_state(player_id: String, payload: Dictionary) -> void:
	controller_private_state_updated.emit(player_id, payload)


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
	points_awarded.emit(profile_id, amount)


# Report once per player per completed game; omit draws and abandoned games.
func report_result(profile_id: String, won: bool) -> void:
	result_reported.emit(profile_id, won)


func return_to_lobby() -> void:
	return_to_lobby_requested.emit()
