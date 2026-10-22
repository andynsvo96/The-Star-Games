extends SceneTree

class SocketErrorLogger extends Logger:
	var errors := 0
	var mutex := Mutex.new()

	func _log_error(_function: String, _file: String, _line: int, code: String, _rationale: String, _editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if code.contains("ready_state != STATE_OPEN") or code.contains("outbound_buffer_size") or code.contains("Missing or invalid header") or _rationale.contains("Missing or invalid header"):
			mutex.lock()
			errors += 1
			mutex.unlock()

	func has_errors() -> bool:
		mutex.lock()
		var result := errors > 0
		mutex.unlock()
		return result


var server: LanServer
var store: ProfileStore
var socket := WebSocketPeer.new()
var socket_errors := SocketErrorLogger.new()
var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	OS.add_logger(socket_errors)
	var path := "user://the_star_games_network_test.json"
	_cleanup(path)
	store = ProfileStore.new(path)
	if not store.load_data():
		return _finish(false, "Profile store did not initialize")
	server = LanServer.new()
	root.add_child(server)
	server.configure(store, GameCatalog.new())
	if not server.start_server():
		return _finish(false, "LAN server did not start")
	# Ordinary HTTP probes during solo play must never reach the WS parser.
	server.set_lobby_open(false); server.set_process(false)
	var probe := StreamPeerTCP.new(); probe.connect_to_host("127.0.0.1", server.websocket_port)
	for frame in 60:
		probe.poll()
		if probe.get_status() == StreamPeerTCP.STATUS_CONNECTED: break
		await process_frame
	if probe.get_status() != StreamPeerTCP.STATUS_CONNECTED: return _finish(false, "Solo probe could not connect")
	probe.put_data("GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n".to_utf8_buffer())
	server._process(0)
	if not server.websocket_clients.is_empty(): return _finish(false, "Solo HTTP probe reached WebSocket handshaking")
	probe.disconnect_from_host(); server.set_lobby_open(true); server.set_process(true)

	var http := HTTPClient.new()
	if http.connect_to_host("127.0.0.1", server.http_port) != OK:
		return _finish(false, "HTTP client could not begin connecting")
	if not await _wait_for_http_status(http, HTTPClient.STATUS_CONNECTED):
		return _finish(false, "HTTP client did not connect")
	http.request(HTTPClient.METHOD_GET, "/", PackedStringArray())
	if not await _wait_for_http_status(http, HTTPClient.STATUS_BODY):
		return _finish(false, "HTTP server did not return a response body")
	var body := PackedByteArray()
	while http.get_status() == HTTPClient.STATUS_BODY:
		http.poll()
		body.append_array(http.read_response_body_chunk())
		await process_frame
	if http.get_response_code() != 200 or not body.get_string_from_utf8().contains("THE STAR"):
		return _finish(false, "HTTP controller page response was invalid")
	var artwork := HTTPRequest.new()
	root.add_child(artwork)
	if artwork.request("http://127.0.0.1:%d/debug.html?width=390&height=844" % server.http_port) != OK:
		return _finish(false, "Debug phone preview request failed")
	var preview_response: Array = await artwork.request_completed
	if preview_response[1] != 200 or not preview_response[3].get_string_from_utf8().contains("Phone controller preview"):
		return _finish(false, "Debug phone preview was not served offline")
	for asset in ["score-wood", "iron-chain", "scroll-closed", "assembly-avatar", "assembly-avatar-detail", "clipboard-board"]:
		if artwork.request("http://127.0.0.1:%d/ui/playful/%s.svg" % [server.http_port, asset]) != OK:
			return _finish(false, "Shared game artwork request failed")
		var response: Array = await artwork.request_completed
		if response[1] != 200 or not response[3].get_string_from_utf8().contains("<svg"):
			return _finish(false, "Shared %s artwork was not served offline" % asset)
	if artwork.request("http://127.0.0.1:%d/ui/playful/paper-fill.png" % server.http_port) != OK:
		return _finish(false, "Shared paper texture request failed")
	var paper_response: Array = await artwork.request_completed
	if paper_response[1] != 200 or paper_response[3].size() < 1000:
		return _finish(false, "Shared paper texture was not served offline")
	artwork.queue_free()

	socket.inbound_buffer_size = 8 * 1024 * 1024
	if socket.connect_to_url("ws://127.0.0.1:%d/" % server.websocket_port) != OK:
		return _finish(false, "WebSocket client could not begin connecting")
	if not await _wait_for_socket(WebSocketPeer.STATE_OPEN):
		return _finish(false, "WebSocket client did not connect")
	var hello := await _next_message()
	if hello.get("type", "") != "hello":
		return _finish(false, "WebSocket did not send hello")
	socket.send_text(JSON.stringify({"type": "join", "name": "Network Tester", "reconnect_token": ""}))
	var joined := await _message_of_type("joined")
	if joined.is_empty() or joined.get("player", {}).get("display_name", "") != "Network Tester":
		return _finish(false, "Browser player could not join")
	if server.get_players().size() != 1:
		return _finish(false, "Joined player did not enter authoritative roster")
	socket.send_text(JSON.stringify({"type": "color", "color": "#e53935"}))
	await _message_of_type("roster")
	for _frame in 10:
		await process_frame
	if server.get_players()[0].get("color") != "#e53935":
		return _finish(false, "Color did not update authoritative roster")
	server.set_lobby_open(false)
	var token: String = joined["reconnect_token"]
	var player_id: String = joined["player"]["id"]
	server.set_active_game("valid-game")
	var publish_state := func(_player: Dictionary) -> void:
		server.send_game_message_to_player(player_id, {"action": "state", "test": "reconnected"})
	server.player_joined.connect(publish_state)
	# A closed socket can remain beside a live replacement until the next poll.
	var stale_client := {"socket": WebSocketPeer.new(), "player_id": player_id, "opened": true}
	server.websocket_clients.append(stale_client)
	server.send_game_message_to_player(player_id, {"action": "state", "test": "stale_socket"})
	server.websocket_clients.erase(stale_client)
	var private_state := await _message_of_type("game")
	if private_state.get("payload", {}).get("test") != "stale_socket":
		return _finish(false, "Closed socket prevented state delivery to the live controller")
	# Exercise backpressure without polling the receiving controller between sends.
	var large := "x".repeat(180000)
	var live: Dictionary = server.websocket_clients.filter(func(client: Dictionary) -> bool: return client.get("player_id") == player_id)[0]
	for index in 30: server.send_to_player(player_id, {"type": "large_state", "sequence": index, "data": large})
	if live.get("outbox", []).is_empty(): return _finish(false, "Backpressure fixture did not fill the outbound buffer")
	for index in 30:
		var delivered := await _message_of_type("large_state")
		if delivered.get("sequence", -1) != index or delivered.get("data", "") != large: return _finish(false, "Queued oversized messages were dropped or reordered")
	socket.close()
	for _frame in 20:
		socket.poll()
		await process_frame
	socket = WebSocketPeer.new()
	socket.connect_to_url("ws://127.0.0.1:%d/" % server.websocket_port)
	await _wait_for_socket(WebSocketPeer.STATE_OPEN)
	await _message_of_type("hello")
	socket.send_text(JSON.stringify({"type": "join", "name": "Late Player"}))
	var rejected := await _message_of_type("error")
	if rejected.get("code") != "lobby_locked":
		return _finish(false, "Late join was not rejected")
	socket.send_text(JSON.stringify({"type": "join", "name": "Network Tester", "reconnect_token": token}))
	var rejoined := await _message_of_type("joined")
	if rejoined.get("player", {}).get("color") != "#e53935":
		return _finish(false, "Locked party reconnect lost player color")
	await _message_of_type("game")
	# Joining from another tab closes the old socket before player_joined publishes.
	var previous_socket := socket
	socket = WebSocketPeer.new()
	if socket.connect_to_url("ws://127.0.0.1:%d/" % server.websocket_port) != OK or not await _wait_for_socket(WebSocketPeer.STATE_OPEN):
		return _finish(false, "Replacement controller did not connect")
	await _message_of_type("hello")
	socket.send_text(JSON.stringify({"type": "join", "name": "Network Tester", "reconnect_token": token}))
	var replacement := await _message_of_type("joined")
	if replacement.get("player", {}).get("id") != player_id:
		return _finish(false, "Tab handover did not preserve the player identity")
	private_state = await _message_of_type("game")
	if private_state.get("payload", {}).get("test") != "reconnected":
		return _finish(false, "Closing socket prevented state delivery during tab handover")
	for _frame in 60:
		previous_socket.poll()
		await process_frame
		if previous_socket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
			break
	if previous_socket.get_close_code() != 4001 or server.get_players().size() != 1:
		return _finish(false, "Old tab closure removed the replacement controller")
	socket.send_text(JSON.stringify({"type": "color", "color": "#228b22"}))
	for _frame in 10:
		await process_frame
	if server.get_players()[0].get("color") != "#e53935":
		return _finish(false, "Color changed after party lock")
	server.set_lobby_open(true)
	server.kick_player(player_id)
	for _frame in 60:
		socket.poll()
		await process_frame
		if socket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
			break
	if socket.get_close_code() != 4003 or not server.get_players().is_empty():
		return _finish(false, "Kick did not close controller and remove player")
	if not server.color_available("#e53935"):
		return _finish(false, "Kick did not release color")
	_cleanup(path)
	_finish(true, "PASS: HTTP, WebSocket, private sends, reconnects, and roster smoke test")


func _wait_for_http_status(http: HTTPClient, wanted: int) -> bool:
	for _frame in 300:
		http.poll()
		if http.get_status() == wanted:
			return true
		if http.get_status() in [HTTPClient.STATUS_CANT_CONNECT, HTTPClient.STATUS_CANT_RESOLVE, HTTPClient.STATUS_CONNECTION_ERROR]:
			return false
		await process_frame
	return false


func _wait_for_socket(wanted: int) -> bool:
	for _frame in 300:
		socket.poll()
		if socket.get_ready_state() == wanted:
			return true
		if socket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
			return false
		await process_frame
	return false


func _next_message() -> Dictionary:
	for _frame in 300:
		socket.poll()
		if socket.get_available_packet_count() > 0:
			var parsed: Variant = JSON.parse_string(socket.get_packet().get_string_from_utf8())
			return parsed if parsed is Dictionary else {}
		await process_frame
	return {}


func _message_of_type(type_name: String) -> Dictionary:
	for _attempt in 4:
		var message := await _next_message()
		if message.get("type", "") == type_name:
			return message
	return {}


func _finish(success: bool, message: String) -> void:
	if success and socket_errors.has_errors():
		success = false
		message = "Private sends attempted to use a closed or closing WebSocket"
	OS.remove_logger(socket_errors)
	print(message) if success else printerr("FAIL: %s" % message)
	if server != null:
		server.stop_server()
	quit(0 if success else 1)


func _cleanup(path: String) -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		var target := path + suffix
		if FileAccess.file_exists(target):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(target))
