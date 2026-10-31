extends SceneTree

var failures := 0
var checks := 0

func _init() -> void: call_deferred("_run")

func check(value: bool, caption: String) -> void:
	checks += 1
	if not value: failures += 1; printerr("FAIL: " + caption)

func fetch(server: LanServer, path: String, extra := "") -> String:
	var socket := StreamPeerTCP.new(); socket.connect_to_host("127.0.0.1", server.http_port)
	for frame in 120:
		socket.poll()
		if socket.get_status() == StreamPeerTCP.STATUS_CONNECTED: break
		await process_frame
	socket.put_data(("GET %s HTTP/1.1\r\nHost: localhost\r\n%sConnection: close\r\n\r\n" % [path, extra]).to_utf8_buffer())
	var bytes := PackedByteArray()
	for frame in 240:
		socket.poll()
		if socket.get_status() == StreamPeerTCP.STATUS_NONE: break
		if socket.get_available_bytes() > 0: bytes.append_array(socket.get_data(socket.get_available_bytes())[1])
		await process_frame
	socket.disconnect_from_host()
	return bytes.get_string_from_utf8()

func _run() -> void:
	check(ProjectSettings.get_setting("display/window/stretch/aspect") == "keep", "Hosts preserve their 16:9 content aspect")
	var server := LanServer.new(); root.add_child(server)
	var catalog := GameCatalog.new("res://tests/fixtures/Games"); catalog.scan()
	server.configure(ProfileStore.new("res://.test_data/controller-viewport/profiles.json"), catalog)
	check(server.start_server(), "Real controller HTTP server starts")
	var shell := await fetch(server, "/game/valid-game/")
	check(shell.contains("phone-frame.js") and shell.contains("<iframe"), "Game routes deliver the shared phone frame")
	check((await fetch(server, "/")).contains("<iframe"), "Joining uses the same phone frame")
	check(not (await fetch(server, "/game/valid-game/?sg-phone=1")).contains("phone-frame.js"), "The child frame receives the original module document")
	check(not (await fetch(server, "/game/valid-game/", "Sec-Fetch-Dest: iframe\r\n")).contains("phone-frame.js"), "Navigation within a frame never nests another shell")
	for path in ["/phone-frame.js", "/phone-frame.css", "/ui/playful/table-property.svg"]:
		check((await fetch(server, path)).begins_with("HTTP/1.1 200"), "Shared controller asset is served over actual HTTP: " + path)
	server.stop_server(); server.queue_free()
	var preview := GameActionPreview.new(); root.add_child(preview)
	var options := [{"label":"First", "summary":"First choice", "players":[{"display_name":"Player [one]", "bank_total":4}], "items":[]}, {"label":"Second", "summary":"Second choice", "players":[{"display_name":"Player two", "bank_total":2}], "items":[]}]
	preview.set_options(options, -1, "players")
	check(preview.selected == -1 and preview.player_buttons.all(func(button: Button) -> bool: return not button.button_pressed), "Target previews can require explicit player selection")
	preview.player_buttons[1].pressed.emit()
	check(preview.selected == 1 and preview.player_buttons[1].button_pressed, "An explicit player choice selects exactly that target")
	preview.queue_free()
	var section := GameSection.new(); section.caption = "Public collection"; root.add_child(section); section.set_identity({"display_name":"Literal name", "color":"#2463eb", "pose":1})
	check(section.identity_icon != null and section.header.columns == 3, "Public section headers support shared identity artwork")
	var rent := GameRentSummary.new(); section.content.add_child(rent); rent.set_rent("Brown", 2, 7, ["house", "hotel"])
	check(rent.get_child_count() == 4 and rent.accessibility_name.contains("plus $7"), "Rent summaries distinguish base rent and both building bonuses")
	section.queue_free()
	print("Controller viewport: %d checks, %d failures" % [checks, failures]); quit(1 if failures else 0)
