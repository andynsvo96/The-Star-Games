class_name LanServer
extends Node

signal started(url: String)
signal stopped
signal server_error(message: String)
signal roster_changed(players: Array)
signal player_joined(player: Dictionary)
signal player_disconnected(player_id: String)
signal controller_message(player_id: String, message: Dictionary)

const MAX_PLAYERS := 16
const AVATAR_POSE_COUNT := 6
const PROTOCOL_VERSION := 1
const HTTP_BASE_PORT := 8080
const WEBSOCKET_BASE_PORT := 8081
const PORT_ATTEMPTS := 10
const WEBSOCKET_OUTBOUND_BYTES := 4 * 1024 * 1024
const WEBSOCKET_PENDING_BYTES := 8 * 1024 * 1024

var profile_store: ProfileStore
var game_catalog: GameCatalog
var http_server := TCPServer.new()
var websocket_server := TCPServer.new()
var http_connections: Array = []
var http_responses: Array = []
var websocket_clients: Array = []
var active_players := {}
var http_port := 0
var websocket_port := 0
var lan_address := "127.0.0.1"
var running := false
var active_game_id := ""
var lobby_open := true
var admitted_players := {}
var session_media: Dictionary = {}
const PLAYER_COLORS := ["#202020", "#ffffff", "#e53935", "#228b22", "#2463eb", "#ffdf00", "#ff8c00", "#8b35c9", "#ff91af", "#8b4513", "#808080", "#00ced1", "#00a080", "#a4de02", "#000080", "#800020"]
const COLOR_NAMES := ["Black", "White", "Red", "Green", "Blue", "Yellow", "Orange", "Purple", "Pink", "Brown", "Gray", "Cyan", "Teal", "Lime", "Navy", "Maroon"]


func configure(store: ProfileStore, catalog: GameCatalog) -> void:
	profile_store = store
	game_catalog = catalog


func start_server() -> bool:
	if running:
		return true
	lan_address = _find_lan_address()
	for offset in PORT_ATTEMPTS:
		var candidate_http := HTTP_BASE_PORT + offset * 2
		var candidate_ws := WEBSOCKET_BASE_PORT + offset * 2
		if http_server.listen(candidate_http, "*") != OK:
			continue
		if websocket_server.listen(candidate_ws, "*") == OK:
			http_port = candidate_http
			websocket_port = candidate_ws
			running = true
			set_process(true)
			started.emit(controller_url())
			return true
		http_server.stop()
	server_error.emit("Could not open local ports 8080-8099. Check firewall settings or close the program using those ports.")
	return false


func stop_server() -> void:
	if not running:
		return
	for client in websocket_clients:
		var socket: WebSocketPeer = client["socket"]
		if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
			socket.close(1001, "Host left the lobby")
	websocket_clients.clear()
	http_connections.clear()
	for response in http_responses:
		response.peer.disconnect_from_host()
	http_responses.clear()
	active_players.clear()
	admitted_players.clear()
	lobby_open = true
	active_game_id = ""
	session_media.clear()
	http_server.stop()
	websocket_server.stop()
	running = false
	set_process(false)
	roster_changed.emit([])
	stopped.emit()


func controller_url() -> String:
	return "http://%s:%d/" % [lan_address, http_port]


func get_players() -> Array:
	var result: Array = []
	for player in active_players.values():
		result.append(player.duplicate(true))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["display_name"].naturalnocasecmp_to(b["display_name"]) < 0)
	return result


# Collection navigation keeps the party locked at the lobby's Play action,
# including admitted identities temporarily offline. Never expose tokens.
func get_admitted_players() -> Array:
	var result: Array = []
	for player in admitted_players.values(): result.append(_public_player(player))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.display_name.naturalnocasecmp_to(b.display_name) < 0)
	return result


func color_available(color: String, player_id := "") -> bool:
	if not PLAYER_COLORS.has(color):
		return false
	for player in active_players.values():
		if player["id"] != player_id and player.get("color") == color:
			return false
	if not lobby_open:
		for player in admitted_players.values():
			if player["id"] != player_id and player.get("color") == color:
				return false
	return true


func _first_available_color() -> String:
	for color in PLAYER_COLORS:
		if color_available(color):
			return color
	return ""


func change_player_color(player_id: String, color: String) -> bool:
	if not lobby_open or not active_players.has(player_id) or not color_available(color, player_id):
		return false
	if active_players[player_id]["color"] == color:
		return true
	active_players[player_id]["pose"] = _random_pose(int(active_players[player_id].get("pose", -1)))
	active_players[player_id]["color"] = color
	_broadcast_roster()
	return true


func _random_pose(previous := -1) -> int:
	if previous < 0:
		return randi_range(0, AVATAR_POSE_COUNT - 1)
	return (previous + randi_range(1, AVATAR_POSE_COUNT - 1)) % AVATAR_POSE_COUNT


func kick_player(player_id: String) -> void:
	if not active_players.has(player_id):
		return
	for client in websocket_clients:
		if client.get("player_id", "") == player_id:
			client["player_id"] = ""
			client["socket"].close(4003, "Removed by the host")
	active_players.erase(player_id)
	admitted_players.erase(player_id)
	_broadcast_roster()
	player_disconnected.emit(player_id)


func set_lobby_open(value: bool) -> void:
	lobby_open = value
	if value:
		admitted_players.clear()
	else:
		admitted_players = active_players.duplicate(true)
	_broadcast({"type": "lobby_state", "lobby_open": lobby_open})


func set_active_game(game_id: String) -> void:
	if active_game_id != game_id: session_media.clear()
	active_game_id = game_id
	_broadcast({"type": "screen", "game_id": active_game_id, "path": "/" if active_game_id.is_empty() else "/game/%s/" % active_game_id})


func set_game_media(game_id: String, resources: Dictionary) -> void:
	if game_id != active_game_id or game_catalog.find_game(game_id).is_empty(): return
	var next: Dictionary = {}
	if resources.size() > 64: return
	for token in resources:
		var source: Variant = resources[token]
		if not token is String or token.length() != 48 or not token.is_valid_hex_number() or not source is String: continue
		if source != source.simplify_path() or source.contains("\\"): continue
		var roots := ["res://Games/%s/" % game_id, "user://%s/content/" % game_id, RuntimeAssets.root_folder().path_join("Games/%s/" % game_id)]
		if not roots.any(func(folder: String) -> bool: return source.begins_with(folder)): continue
		if not source.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp", "bmp", "ogv", "mp4", "webm"]: continue
		if not FileAccess.file_exists(source): continue
		next[token] = source
	session_media = next


func send_to_player(player_id: String, message: Dictionary) -> void:
	for client in websocket_clients:
		if client.get("player_id", "") == player_id:
			_send(client["socket"], message)


func broadcast_game_message(message: Dictionary) -> void:
	_broadcast({"type": "game", "game_id": active_game_id, "payload": message})


func send_game_message_to_player(player_id: String, message: Dictionary) -> void:
	if active_game_id.is_empty() or not active_players.has(player_id) or not admitted_players.has(player_id):
		return
	send_to_player(player_id, {"type": "game", "game_id": active_game_id, "payload": message})


func _ready() -> void:
	set_process(false)


func _process(_delta: float) -> void:
	_poll_http_responses()
	_accept_http_connections()
	_poll_http_connections()
	_accept_websocket_connections()
	_poll_websocket_clients()


func _accept_http_connections() -> void:
	while http_server.is_connection_available():
		http_connections.append({"peer": http_server.take_connection(), "buffer": PackedByteArray(), "frames": 0})


func _poll_http_connections() -> void:
	for index in range(http_connections.size() - 1, -1, -1):
		var connection: Dictionary = http_connections[index]
		var peer: StreamPeerTCP = connection["peer"]
		peer.poll()
		connection["frames"] += 1
		if peer.get_status() == StreamPeerTCP.STATUS_CONNECTED and peer.get_available_bytes() > 0:
			var received := peer.get_partial_data(peer.get_available_bytes())
			if received[0] == OK:
				connection["buffer"].append_array(received[1])
				var request: String = PackedByteArray(connection["buffer"]).get_string_from_utf8()
				if request.contains("\r\n\r\n"):
					_serve_http(peer, request)
					http_connections.remove_at(index)
					continue
		if peer.get_status() in [StreamPeerTCP.STATUS_ERROR, StreamPeerTCP.STATUS_NONE] or connection["frames"] > 300:
			peer.disconnect_from_host()
			http_connections.remove_at(index)


func _serve_http(peer: StreamPeerTCP, request: String) -> void:
	var first_line := request.get_slice("\r\n", 0)
	var parts := first_line.split(" ")
	if parts.size() < 2 or parts[0] != "GET":
		_write_http(peer, 405, "text/plain; charset=utf-8", "Method not allowed".to_utf8_buffer())
		return
	var path := str(parts[1]).get_slice("?", 0)
	if path.begins_with("/session-media/"):
		var token := path.trim_prefix("/session-media/")
		var source: String = session_media.get(token, "")
		var media := FileAccess.open(source, FileAccess.READ) if not source.is_empty() else null
		if media == null:
			_write_http(peer, 404, "text/plain; charset=utf-8", "Not found".to_utf8_buffer())
		else:
			_stream_http_file(peer, media, _mime_type(source), request)
		return
	if path.begins_with("/game/") and path.ends_with("/background.json"):
		var game_id := path.trim_prefix("/game/").trim_suffix("/background.json")
		_write_http(peer, 200, "application/json; charset=utf-8", JSON.stringify(_background_sources(game_id)).to_utf8_buffer())
		return
	var resource_path := ""
	match path:
		"/", "/index.html": resource_path = "res://web/index.html"
		"/debug.html": resource_path = "res://web/debug.html"
		"/avatar-0.svg": resource_path = "res://web/avatar-0.svg"
		"/avatar-1.svg": resource_path = "res://web/avatar-1.svg"
		"/avatar-2.svg": resource_path = "res://web/avatar-2.svg"
		"/avatar-3.svg": resource_path = "res://web/avatar-3.svg"
		"/avatar-4.svg": resource_path = "res://web/avatar-4.svg"
		"/avatar-5.svg": resource_path = "res://web/avatar-5.svg"
		"/avatar.svg": resource_path = "res://web/avatar.svg"
		"/app.js": resource_path = "res://web/app.js"
		"/styles.css": resource_path = "res://web/styles.css"
		"/ui/playful/score-scroll.svg": resource_path = "res://ui/playful/score-scroll.svg"
		"/ui/playful/score-wood.svg": resource_path = "res://ui/playful/score-wood.svg"
		"/ui/playful/score-ledger.svg": resource_path = "res://ui/playful/score-ledger.svg"
		"/ui/playful/score-ornate.svg": resource_path = "res://ui/playful/score-ornate.svg"
		"/ui/playful/button-carved.svg": resource_path = "res://ui/playful/button-carved.svg"
		"/ui/playful/button-carved-primary.svg": resource_path = "res://ui/playful/button-carved-primary.svg"
		"/ui/playful/stat-wins.svg": resource_path = "res://ui/playful/stat-wins.svg"
		"/ui/playful/stat-victory.svg": resource_path = "res://ui/playful/stat-victory.svg"
		"/ui/playful/stat-resources.svg": resource_path = "res://ui/playful/stat-resources.svg"
		"/ui/playful/stat-development.svg": resource_path = "res://ui/playful/stat-development.svg"
		"/ui/playful/stat-route.svg": resource_path = "res://ui/playful/stat-route.svg"
		"/ui/playful/stat-knights.svg": resource_path = "res://ui/playful/stat-knights.svg"
		"/ui/playful/stat-trophy.svg": resource_path = "res://ui/playful/stat-trophy.svg"
		"/ui/playful/control-help.svg": resource_path = "res://ui/playful/control-help.svg"
		"/ui/playful/stat-walls.svg": resource_path = "res://ui/playful/stat-walls.svg"
		"/ui/playful/control-move.svg": resource_path = "res://ui/playful/control-move.svg"
		"/ui/playful/control-wall.svg": resource_path = "res://ui/playful/control-wall.svg"
		"/ui/playful/control-rotate.svg": resource_path = "res://ui/playful/control-rotate.svg"
		"/ui/playful/control-settings.svg": resource_path = "res://ui/playful/control-settings.svg"
		"/ui/playful/control-history.svg": resource_path = "res://ui/playful/control-history.svg"
		"/ui/playful/control-back.svg": resource_path = "res://ui/playful/control-back.svg"
		"/ui/playful/table-cash.svg": resource_path = "res://ui/playful/table-cash.svg"
		"/ui/playful/table-dice.svg": resource_path = "res://ui/playful/table-dice.svg"
		"/ui/playful/table-trade.svg": resource_path = "res://ui/playful/table-trade.svg"
		"/ui/playful/table-flag.svg": resource_path = "res://ui/playful/table-flag.svg"
		"/ui/playful/table-cards.svg": resource_path = "res://ui/playful/table-cards.svg"
		"/ui/playful/table-house.svg": resource_path = "res://ui/playful/table-house.svg"
		"/ui/playful/table-crown-silver.svg": resource_path = "res://ui/playful/table-crown-silver.svg"
		"/ui/playful/table-crown.svg": resource_path = "res://ui/playful/table-crown.svg"
		"/ui/playful/rules-star.svg": resource_path = "res://ui/playful/rules-star.svg"
		"/ui/playful/party-sheen.svg": resource_path = "res://ui/playful/party-sheen.svg"
		"/ui/playful/casino-frame.svg": resource_path = "res://ui/playful/casino-frame.svg"
		"/ui/playful/casino-frame-active.svg": resource_path = "res://ui/playful/casino-frame-active.svg"
		"/ui/playful/casino-player.svg": resource_path = "res://ui/playful/casino-player.svg"
		"/ui/playful/casino-player-active.svg": resource_path = "res://ui/playful/casino-player-active.svg"
		"/ui/playful/casino-button-neutral.svg": resource_path = "res://ui/playful/casino-button-neutral.svg"
		"/ui/playful/casino-button-fold.svg": resource_path = "res://ui/playful/casino-button-fold.svg"
		"/ui/playful/casino-button-call.svg": resource_path = "res://ui/playful/casino-button-call.svg"
		"/ui/playful/casino-button-raise.svg": resource_path = "res://ui/playful/casino-button-raise.svg"
		"/ui/playful/casino-slider-track.svg": resource_path = "res://ui/playful/casino-slider-track.svg"
		"/ui/playful/casino-slider-fill.svg": resource_path = "res://ui/playful/casino-slider-fill.svg"
		"/ui/playful/casino-slider-knob.svg": resource_path = "res://ui/playful/casino-slider-knob.svg"
		"/ui/playful/casino-slider-knob-disabled.svg": resource_path = "res://ui/playful/casino-slider-knob-disabled.svg"
		"/ui/playful/iron-chain.svg": resource_path = "res://ui/playful/iron-chain.svg"
		"/ui/playful/scroll-closed.svg": resource_path = "res://ui/playful/scroll-closed.svg"
		"/ui/playful/sticky-note.svg": resource_path = "res://ui/playful/sticky-note.svg"
		"/ui/playful/tombstone.svg": resource_path = "res://ui/playful/tombstone.svg"
		"/ui/playful/assembly-avatar.svg": resource_path = "res://ui/playful/assembly-avatar.svg"
		"/ui/playful/assembly-avatar-detail.svg": resource_path = "res://ui/playful/assembly-avatar-detail.svg"
		"/ui/playful/paper.svg": resource_path = "res://ui/playful/paper.svg"
		"/ui/playful/paper-fill.png": resource_path = "res://ui/playful/paper-fill.png"
		"/ui/playful/clipboard-board.svg": resource_path = "res://ui/playful/clipboard-board.svg"
		"/ui/playful/clipboard.svg": resource_path = "res://ui/playful/clipboard.svg"
		"/ui/playful/paper-clip.svg": resource_path = "res://ui/playful/paper-clip.svg"
		"/controller-sdk.js": resource_path = "res://web/controller-sdk.js"
		"/game-celebration.js": resource_path = "res://web/game-celebration.js"
		"/card-ui.js": resource_path = "res://web/card-ui.js"
		"/media-view.js": resource_path = "res://web/media-view.js"
		"/manifest.webmanifest": resource_path = "res://web/manifest.webmanifest"
		_:
			resource_path = _resolve_game_web_path(path)
	resource_path = RuntimeAssets.source(resource_path)
	if resource_path.is_empty() or not FileAccess.file_exists(resource_path):
		_write_http(peer, 404, "text/plain; charset=utf-8", "Not found".to_utf8_buffer())
		return
	var file := FileAccess.open(resource_path, FileAccess.READ)
	if file == null:
		_write_http(peer, 404, "text/plain; charset=utf-8", "Not found".to_utf8_buffer())
		return
	_stream_http_file(peer, file, _mime_type(resource_path), request)


func _background_sources(game_id: String) -> Dictionary:
	var result := {"videos": [], "image": ""}
	for game in game_catalog.games:
		if game.id != game_id or not game.has("background"):
			continue
		result = _background_stem_sources(game, str(game.background))
		if game.has("background_variants"):
			result["variants"] = {}
			for variant in game.background_variants:
				result.variants[variant] = _background_stem_sources(game, str(game.background_variants[variant]))
	return result


func _background_stem_sources(game: Dictionary, relative_stem: String) -> Dictionary:
	var result := {"videos": [], "image": ""}
	for source in BackgroundMedia.candidates(str(game.folder).path_join(relative_stem)):
		var relative := relative_stem.get_base_dir().path_join(source.get_file())
		for base in [RuntimeAssets.root_folder().path_join("Games/%s/" % game.id), "res://Games/%s/" % game.id]:
			if source.begins_with(base): relative = source.trim_prefix(base)
		var url := "/game/%s/%s" % [game.id, relative]
		if source.get_extension().to_lower() in BackgroundMedia.VIDEO_EXTENSIONS:
			result.videos.append({"url": url, "type": _mime_type(source)})
		elif result.image.is_empty():
			result.image = url
	return result


func _resolve_game_web_path(path: String) -> String:
	if not path.begins_with("/game/") or path.contains("..") or path.contains("\\"):
		return ""
	var parts := path.trim_prefix("/game/").split("/", false)
	if parts.is_empty():
		return ""
	var game_id := parts[0]
	for game in game_catalog.games:
		if game["id"] == game_id:
			var relative := "/".join(parts.slice(1))
			if relative.is_empty():
				relative = str(game["controller_entry"])
			relative = relative.simplify_path()
			if _game_path_is_private(game, relative):
				return ""
			# External exported backgrounds use the same restricted asset paths.
			if game.has("background"):
				var stems: Array = [game.background]
				stems.append_array(game.get("background_variants", {}).values())
				for stem in stems:
					for candidate in BackgroundMedia.candidates(str(game.folder).path_join(str(stem))):
						if relative == str(stem).get_base_dir().path_join(candidate.get_file()):
							return candidate
			var direct := str(game["folder"]).path_join(relative)
			var external_relative := "Games/%s/%s" % [game_id, relative]
			if RuntimeAssets.safe_media_path(external_relative) and ThemePacks._safe(external_relative):
				var external := RuntimeAssets.root_folder().path_join(external_relative)
				if FileAccess.file_exists(external): return external
			if FileAccess.file_exists(direct):
				return direct
			# The entry is served at /game/<id>/, so sibling URLs need its directory.
			var sibling := str(game["controller_entry"]).get_base_dir().path_join(relative)
			if _game_path_is_private(game, sibling):
				return ""
			return str(game["folder"]).path_join(sibling)
	return ""


func _game_path_is_private(game: Dictionary, relative: String) -> bool:
	# Windows source folders are case insensitive; keep the same boundary on all
	# hosts and on both direct URLs and controller-relative asset aliases.
	var candidate := relative.simplify_path().to_lower()
	for path in game.get("private_paths", []):
		var prefix := str(path).to_lower()
		if candidate == prefix or candidate.begins_with(prefix + "/"):
			return true
	return false


func _write_http(peer: StreamPeerTCP, status: int, content_type: String, body: PackedByteArray) -> void:
	var status_text := "OK" if status == 200 else ("Not Found" if status == 404 else "Method Not Allowed")
	var headers := "HTTP/1.1 %d %s\r\nContent-Type: %s\r\nContent-Length: %d\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\nConnection: close\r\n\r\n" % [status, status_text, content_type, body.size()]
	var response := headers.to_utf8_buffer()
	response.append_array(body)
	http_responses.append({"peer": peer, "buffer": response, "offset": 0, "file": null, "remaining": 0})


# Byte ranges let phone browsers seek/loop videos. Send bounded chunks so large
# backgrounds do not block the host's game loop or load the whole video into RAM.
func _stream_http_file(peer: StreamPeerTCP, file: FileAccess, content_type: String, request: String) -> void:
	var length := file.get_length()
	var start := 0
	var end := length - 1
	var partial := false
	for line in request.split("\r\n"):
		if not line.to_lower().begins_with("range: bytes="):
			continue
		var value := line.substr(line.find("=") + 1).strip_edges()
		var bounds := value.split("-", true)
		if bounds.size() != 2 or value.contains(",") or (not bounds[0].is_empty() and not bounds[0].is_valid_int()) or (not bounds[1].is_empty() and not bounds[1].is_valid_int()) or (bounds[0].is_empty() and bounds[1].is_empty()):
			break
		partial = true
		if bounds[0].is_empty():
			start = maxi(0, length - int(bounds[1]))
		else:
			start = int(bounds[0])
			if not bounds[1].is_empty():
				end = mini(end, int(bounds[1]))
		break
	if partial and (start < 0 or start >= length or end < start):
		var rejected := "HTTP/1.1 416 Range Not Satisfiable\r\nContent-Range: bytes */%d\r\nContent-Length: 0\r\nConnection: close\r\n\r\n" % length
		http_responses.append({"peer": peer, "buffer": rejected.to_utf8_buffer(), "offset": 0, "file": null, "remaining": 0})
		return
	var count := maxi(0, end - start + 1)
	var header := "HTTP/1.1 %s\r\nContent-Type: %s\r\nContent-Length: %d\r\nAccept-Ranges: bytes\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\nConnection: close\r\n" % ["206 Partial Content" if partial else "200 OK", content_type, count]
	if partial:
		header += "Content-Range: bytes %d-%d/%d\r\n" % [start, end, length]
	file.seek(start)
	http_responses.append({"peer": peer, "buffer": (header + "\r\n").to_utf8_buffer(), "offset": 0, "file": file, "remaining": count})


func _poll_http_responses() -> void:
	for index in range(http_responses.size() - 1, -1, -1):
		var response: Dictionary = http_responses[index]
		var peer: StreamPeerTCP = response.peer
		peer.poll()
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			http_responses.remove_at(index)
			continue
		if response.offset >= response.buffer.size():
			if response.remaining <= 0:
				peer.disconnect_from_host()
				http_responses.remove_at(index)
				continue
			response.buffer = response.file.get_buffer(mini(65536, response.remaining))
			response.remaining -= response.buffer.size()
			response.offset = 0
		var sent := peer.put_partial_data(response.buffer.slice(response.offset))
		if sent[0] != OK:
			peer.disconnect_from_host()
			http_responses.remove_at(index)
		else:
			response.offset += sent[1]


func _accept_websocket_connections() -> void:
	while websocket_server.is_connection_available():
		var stream := websocket_server.take_connection()
		# Solo sessions have no admitted controllers. Reject probes before the
		# engine attempts a WebSocket upgrade on an ordinary HTTP request.
		if not lobby_open and admitted_players.is_empty():
			stream.disconnect_from_host()
			continue
		var socket := WebSocketPeer.new()
		# Private card-table choices can exceed the engine's 64 KiB default.
		socket.outbound_buffer_size = WEBSOCKET_OUTBOUND_BYTES
		var error := socket.accept_stream(stream)
		if error == OK:
			websocket_clients.append({"socket": socket, "player_id": "", "opened": false, "outbox": [], "outbox_bytes": 0})


func _poll_websocket_clients() -> void:
	for index in range(websocket_clients.size() - 1, -1, -1):
		var client: Dictionary = websocket_clients[index]
		var socket: WebSocketPeer = client["socket"]
		if not client.opened and not lobby_open and admitted_players.is_empty():
			socket.close(-1); websocket_clients.remove_at(index); continue
		socket.poll()
		if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
			_flush_client(client)
			if not client["opened"]:
				client["opened"] = true
				_send(socket, {"type": "hello", "protocol_version": PROTOCOL_VERSION, "host_name": profile_store.get_settings()["host_name"], "websocket_port": websocket_port, "lobby_open": lobby_open})
			while socket.get_available_packet_count() > 0:
				var text := socket.get_packet().get_string_from_utf8()
				var message: Variant = JSON.parse_string(text)
				if message is Dictionary:
					_handle_message(client, message)
				else:
					_send(socket, {"type": "error", "code": "invalid_json", "message": "Message must be valid JSON."})
		elif socket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
			_disconnect_client(client)
			websocket_clients.remove_at(index)


func _handle_message(client: Dictionary, message: Dictionary) -> void:
	var socket: WebSocketPeer = client["socket"]
	match str(message.get("type", "")):
		"join":
			_join_client(client, str(message.get("name", "")), str(message.get("reconnect_token", "")))
		"color":
			var player_id := str(client.get("player_id", ""))
			var color := str(message.get("color", "")).to_lower()
			if not change_player_color(player_id, color):
				_send(socket, {"type": "error", "code": "color_unavailable", "message": "That color is unavailable. Choose an unused color in the lobby."})
		"ping":
			_send(socket, {"type": "pong", "time": Time.get_unix_time_from_system()})
		"game":
			var player_id := str(client.get("player_id", ""))
			if not player_id.is_empty() and str(message.get("game_id", "")) == active_game_id:
				controller_message.emit(player_id, message.get("payload", {}))
		_:
			_send(socket, {"type": "error", "code": "unknown_message", "message": "Unknown message type."})


func _join_client(client: Dictionary, name: String, reconnect_token: String) -> void:
	var socket: WebSocketPeer = client["socket"]
	if not str(client.get("player_id", "")).is_empty():
		_send(socket, {"type": "error", "code": "already_joined", "message": "This controller has already joined."})
		return
	var reserved: Dictionary = {}
	if not lobby_open:
		for player in admitted_players.values():
			if not reconnect_token.is_empty() and player["reconnect_token"] == reconnect_token and str(player["display_name"]).to_lower() == name.strip_edges().to_lower():
				reserved = player
				break
		if reserved.is_empty():
			_send(socket, {"type": "error", "code": "lobby_locked", "message": "The party has started. Join when the host returns to the lobby."})
			return
	var profile_result := profile_store.create_or_get_profile(name)
	if not profile_result["ok"]:
		_send(socket, {"type": "error", "code": "invalid_name", "message": profile_result["error"]})
		return
	var profile: Dictionary = profile_result["profile"]
	var profile_id: String = profile["id"]
	if active_players.has(profile_id):
		var active: Dictionary = active_players[profile_id]
		if reconnect_token.is_empty() or reconnect_token != active["reconnect_token"]:
			_send(socket, {"type": "error", "code": "name_in_use", "message": "That player is already connected."})
			return
		for existing in websocket_clients:
			if existing.get("player_id", "") == profile_id and existing != client:
				var old_socket: WebSocketPeer = existing["socket"]
				old_socket.close(4001, "Reconnected from another tab")
	if active_players.size() >= MAX_PLAYERS and not active_players.has(profile_id):
		_send(socket, {"type": "error", "code": "lobby_full", "message": "The lobby is full (16 players)."})
		return
	var token := reconnect_token if not reconnect_token.is_empty() else Crypto.new().generate_random_bytes(18).hex_encode()
	var player := {"id": profile_id, "display_name": profile["display_name"], "reconnect_token": token, "lifetime_points": profile_store.lifetime_points(profile)}
	player["color"] = active_players.get(profile_id, reserved).get("color", _first_available_color())
	player["pose"] = active_players.get(profile_id, reserved).get("pose", _random_pose())
	active_players[profile_id] = player
	client["player_id"] = profile_id
	_send(socket, {"type": "joined", "player": _public_player(player), "reconnect_token": token, "game_id": active_game_id, "lobby_open": lobby_open})
	_broadcast_roster()
	player_joined.emit(_public_player(player))


func _disconnect_client(client: Dictionary) -> void:
	var player_id := str(client.get("player_id", ""))
	if player_id.is_empty() or not active_players.has(player_id):
		return
	# Do not remove a freshly reconnected player when the older socket closes.
	for other in websocket_clients:
		if other != client and other.get("player_id", "") == player_id and other["socket"].get_ready_state() == WebSocketPeer.STATE_OPEN:
			return
	active_players.erase(player_id)
	_broadcast_roster()
	player_disconnected.emit(player_id)


func _broadcast_roster() -> void:
	var public_players: Array = []
	for player in get_players():
		public_players.append(_public_player(player))
	_broadcast({"type": "roster", "players": public_players})
	roster_changed.emit(public_players)


func _broadcast(message: Dictionary) -> void:
	for client in websocket_clients:
		var socket: WebSocketPeer = client["socket"]
		if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
			_send(socket, message)


func _send(socket: WebSocketPeer, message: Dictionary) -> void:
	# Disconnect callbacks and tab handovers can publish before stale sockets are removed.
	if socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	var encoded := JSON.stringify(message)
	var bytes := encoded.to_utf8_buffer().size()
	for client in websocket_clients:
		if client.socket != socket: continue
		if bytes + 14 > socket.outbound_buffer_size:
			socket.close(1009, "Game state exceeds transport limit")
			return
		var outbox: Array = client.get("outbox", [])
		if int(client.get("outbox_bytes", 0)) + bytes > WEBSOCKET_PENDING_BYTES:
			socket.close(1013, "Reconnect to restore current game state")
			return
		outbox.append({"text": encoded, "bytes": bytes})
		client.outbox = outbox; client.outbox_bytes = int(client.get("outbox_bytes", 0)) + bytes
		_flush_client(client)
		return


func _flush_client(client: Dictionary) -> void:
	var socket: WebSocketPeer = client.socket
	if socket.get_ready_state() != WebSocketPeer.STATE_OPEN: return
	var outbox: Array = client.get("outbox", [])
	while not outbox.is_empty():
		var packet: Dictionary = outbox[0]
		# Leave room for framing and retry after poll drains the socket. Never
		# discard a snapshot, decision or navigation message on a full buffer.
		if socket.get_current_outbound_buffered_amount() + int(packet.bytes) + 14 > socket.outbound_buffer_size: return
		if socket.send_text(packet.text) != OK: return
		client.outbox_bytes -= int(packet.bytes); outbox.pop_front()


func _public_player(player: Dictionary) -> Dictionary:
	return {"id": player["id"], "display_name": player["display_name"], "lifetime_points": player.get("lifetime_points", 0), "color": player.get("color", PLAYER_COLORS[0]), "pose": player.get("pose", 0)}


func _find_lan_address() -> String:
	var fallback := "127.0.0.1"
	for address in IP.get_local_addresses():
		if address.contains(":") or address.begins_with("127.") or address.begins_with("169.254."):
			continue
		if address.begins_with("192.168.") or address.begins_with("10.") or address.begins_with("172."):
			return address
		fallback = address
	return fallback


func _mime_type(path: String) -> String:
	match path.get_extension().to_lower():
		"html": return "text/html; charset=utf-8"
		"css": return "text/css; charset=utf-8"
		"js": return "application/javascript; charset=utf-8"
		"json", "webmanifest": return "application/json; charset=utf-8"
		"png": return "image/png"
		"svg": return "image/svg+xml"
		"jpg", "jpeg": return "image/jpeg"
		"webp": return "image/webp"
		"bmp": return "image/bmp"
		"ogv": return "video/ogg"
		"mp4", "m4v": return "video/mp4"
		"webm": return "video/webm"
		"mov": return "video/quicktime"
		"mkv": return "video/x-matroska"
		"avi": return "video/x-msvideo"
		"ogg": return "audio/ogg"
		"wav": return "audio/wav"
		"mp3": return "audio/mpeg"
		_: return "application/octet-stream"
