extends SceneTree

class LookupFixture extends LanServer:
	var response_body := "203.0.113.7\n"
	var response_status := 200
	var hold_response := false
	var requests := 0
	var held_peers: Array[StreamPeerTCP] = []

	func start_server() -> bool:
		if http_server.listen(0, "127.0.0.1") != OK:
			return false
		http_port = http_server.get_local_port()
		running = true
		set_process(true)
		return true

	func _serve_http(peer: StreamPeerTCP, _request_text: String) -> void:
		requests += 1
		if hold_response:
			held_peers.append(peer)
		else:
			_write_http(peer, response_status, "text/plain", response_body.to_utf8_buffer())

	func stop_server() -> void:
		for peer in held_peers:
			peer.disconnect_from_host()
		held_peers.clear()
		super.stop_server()


var checks := 0
var failures := 0


func _init() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)


func wait_for_lookup(lookup: Node) -> void:
	var deadline := Time.get_ticks_msec() + 2000
	while lookup.loading and Time.get_ticks_msec() < deadline:
		await create_timer(0.01).timeout
	check(not lookup.loading, "Public lookup settles without blocking the lobby")
	for frame in 4:
		await process_frame


func _run() -> void:
	var folder := "res://.test_data/lobby-addresses/"
	DirAccess.make_dir_recursive_absolute(folder)
	var app = load("res://Main.tscn").instantiate()
	app.profile_store = ProfileStore.new(folder + "profiles.json")
	root.add_child(app)
	var fixture := LookupFixture.new()
	root.add_child(fixture)
	fixture.configure(app.profile_store, app.game_catalog)
	check(fixture.start_server(), "Offline public-IP fixture starts")
	app.public_address.lookup_url = fixture.controller_url()
	app.profile_store.data.settings.reduced_motion = true
	app._enter_lobby()
	var local: LinkButton = app.screen_root.find_child("ControllerUrl", true, false)
	var public_link: LinkButton = app.public_connection_link
	check(local.text == "Local: %s:%d" % [app.lan_server.lan_address, app.lan_server.http_port], "Local row displays the current host address and port")
	check(local.get_meta("controller_url") == app.lan_server.controller_url(), "Local copy uses the complete HTTP URL without its caption")
	app.public_address.refresh()
	check(public_link.text == "Public: Checking…" and public_link.disabled, "Pending public lookup has visible feedback and cannot copy a placeholder")
	await wait_for_lookup(app.public_address)
	var expected := "http://203.0.113.7:%d/" % app.lan_server.http_port
	check(public_link.text == "Public: 203.0.113.7:%d" % app.lan_server.http_port, "Public row displays the detected IPv4 address and actual port")
	check(not public_link.disabled and public_link.get_meta("controller_url") == expected, "Public copy uses the complete detected HTTP URL")
	check(public_link.get_global_rect().position.y >= local.get_global_rect().end.y, "Public address sits beneath Local")
	check(local.tooltip_text.is_empty() and public_link.tooltip_text.is_empty(), "Address controls have no hover popups")
	var request_count := fixture.requests
	app.public_address.refresh()
	check(fixture.requests == request_count and not app.public_address.loading, "Returning to a recently detected address reuses the cache")
	check(app.public_address.controller_url(8092) == "http://203.0.113.7:8092/", "Cached IPv4 still uses the current server port")
	if DisplayServer.get_name() != "headless":
		var previous_clipboard := DisplayServer.clipboard_get()
		local.pressed.emit()
		check(DisplayServer.clipboard_get() == app.lan_server.controller_url(), "Local click copies its complete URL to the system clipboard")
		public_link.pressed.emit()
		check(DisplayServer.clipboard_get() == expected, "Public click copies its complete URL to the system clipboard")
		check(public_link.get_node("CopyNotice").visible, "Public click shows copy confirmation")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder + "copied.png")
		await create_timer(1.1).timeout
		check(not public_link.get_node("CopyNotice").visible, "Copy confirmation disappears after one second")
		DisplayServer.clipboard_set(previous_clipboard)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder + "lobby.png")
	for response in [[503, "203.0.113.7"], [200, "invalid"], [200, "2001:db8::7"]]:
		fixture.response_status = response[0]
		fixture.response_body = response[1]
		app.public_address.refresh(true)
		await wait_for_lookup(app.public_address)
		check(app.public_address.address.is_empty() and public_link.text.contains("Unavailable"), "Bad HTTP/IP response leaves a retryable public row")
		check(public_link.get_meta("controller_url").is_empty() and not public_link.disabled, "Failed lookup cannot copy an invalid or stale address")
		check(app.lan_server.running and local.get_meta("controller_url") == app.lan_server.controller_url(), "Lookup failure preserves local hosting")
	fixture.response_status = 200
	fixture.response_body = "203.0.113.8"
	public_link.pressed.emit()
	check(app.public_address.loading, "Unavailable public row retries when clicked")
	app._show_settings("lobby")
	await wait_for_lookup(app.public_address)
	app._return_from_settings()
	await process_frame
	check(app.public_connection_link.text.contains("203.0.113.8"), "Navigation restores lookup completed while the lobby was hidden")
	fixture.hold_response = true
	app.public_address.request_timeout = 0.15
	app.public_address.refresh(true)
	await wait_for_lookup(app.public_address)
	check(app.public_connection_link.text.contains("Unavailable") and app.lan_server.running, "Timed-out lookup keeps the local lobby usable")
	app.public_address.refresh(true)
	app._leave_lobby()
	await create_timer(0.25).timeout
	check(not app.public_address.loading and app.public_address.address.is_empty(), "Leaving cancels lookup and clears the public address")
	check(app.public_connection_link == null and app.current_state == "title", "Late lookup cannot revive a removed lobby")
	fixture.stop_server()
	fixture.queue_free()
	app.queue_free()
	await process_frame
	print("Lobby addresses: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
