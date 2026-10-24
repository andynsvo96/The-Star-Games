extends SceneTree

class FakeBrowsers extends "res://scripts/debug_browsers.gd":
	var environment := {}
	var installed := PackedStringArray()
	var calls: Array[Dictionary] = []
	var failed_path := ""
	var registry := {}
	var scans := 0

	func detect() -> Array:
		scans += 1
		return super.detect()

	func _read_registry(registry_root: String) -> String:
		return str(registry.get(registry_root, ""))

	func _environment(variable: String) -> String:
		return str(environment.get(variable, ""))

	func _file_exists(path: String) -> bool:
		return path in installed

	func _directory_exists(path: String) -> bool:
		return path in installed

	func _create_process(path: String, arguments: PackedStringArray) -> int:
		calls.append({"path": path, "arguments": arguments})
		return -1 if path == failed_path else 123


var failures := 0
var checks := 0
var four_browsers := PackedStringArray(["firefox", "chrome", "edge", "brave"])


func _init() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)


func windows_browsers() -> FakeBrowsers:
	var browsers := FakeBrowsers.new()
	browsers.platform_name = "Windows"
	browsers.environment = {"PROGRAMFILES": "C:/Program Files", "PROGRAMFILES(X86)": "C:/Program Files (x86)", "LOCALAPPDATA": "C:/Users/Tester/AppData/Local"}
	browsers.installed = PackedStringArray([
		"C:/Program Files/Mozilla Firefox/firefox.exe",
		"C:/Users/Tester/AppData/Local/Google/Chrome/Application/chrome.exe",
		"C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe",
		"C:/Users/Tester/AppData/Local/BraveSoftware/Brave-Browser/Application/brave.exe",
	])
	return browsers


func _run() -> void:
	var url := "http://192.168.1.23:8088/"
	var browsers := windows_browsers()
	var found := browsers.detect()
	check(found.size() == 4 and browsers.calls.is_empty(), "Detection lists installed browsers without opening any")
	var result := browsers.open_controllers(url, four_browsers)
	check(result.opened == PackedStringArray(["Firefox", "Chrome", "Microsoft Edge", "Brave"]) and result.missing.is_empty() and result.failed.is_empty(), "All four Windows browsers open, including per-user installations")
	for index in browsers.calls.size():
		check_launch(browsers.calls[index], browsers.BROWSERS[index].name, url)
	browsers.installed.remove_at(0)
	browsers.failed_path = browsers.installed[0]
	browsers.calls.clear()
	result = browsers.open_controllers(url, four_browsers)
	check(result.missing == PackedStringArray(["Firefox"]), "Missing browser is reported")
	check(result.failed == PackedStringArray(["Chrome"]), "Failed launch is reported")
	check(result.opened == PackedStringArray(["Microsoft Edge", "Brave"]) and browsers.calls.size() == 3, "Other browsers still open after a missing or failed browser")
	browsers = windows_browsers()
	browsers.installed.remove_at(3)
	result = browsers.open_controllers(url, four_browsers)
	check(result.missing == PackedStringArray(["Brave"]) and result.opened.size() == 3, "Missing Brave is reported while other browsers still open")
	browsers = windows_browsers()
	browsers.failed_path = browsers.installed[3]
	result = browsers.open_controllers(url, four_browsers)
	check(result.failed == PackedStringArray(["Brave"]) and result.opened.size() == 3, "Failed Brave launch is reported while other browsers still open")
	browsers = FakeBrowsers.new()
	browsers.platform_name = "Windows"
	browsers.environment = {"PATH": '"D:/Custom Browsers";C:/Other'}
	browsers.installed = PackedStringArray(["D:/Custom Browsers/firefox.exe", "D:/Custom Browsers/brave.exe"])
	result = browsers.open_controllers(url, four_browsers)
	check(result.opened == PackedStringArray(["Firefox", "Brave"]), "Custom Windows installations are found on PATH")
	browsers = FakeBrowsers.new()
	browsers.platform_name = "macOS"
	browsers.environment = {"HOME": "/Users/tester"}
	browsers.installed = PackedStringArray([
		"/Applications/Firefox.app", "/Applications/Firefox.app/Contents/MacOS/firefox",
		"/Users/tester/Applications/Google Chrome.app", "/Users/tester/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
		"/Applications/Microsoft Edge.app", "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge",
		"/Users/tester/Applications/Brave Browser.app", "/Users/tester/Applications/Brave Browser.app/Contents/MacOS/Brave Browser",
	])
	result = browsers.open_controllers(url, four_browsers)
	check(result.opened == PackedStringArray(["Firefox", "Chrome", "Microsoft Edge", "Brave"]), "macOS supports system and user Applications folders")
	for index in browsers.calls.size():
		var call: Dictionary = browsers.calls[index]
		check(call.path.contains(".app/Contents/MacOS/"), "macOS launches the browser executable so flags reach an existing process")
		check_launch(call, browsers.BROWSERS[index].name, url)
	browsers = FakeBrowsers.new()
	browsers.platform_name = "Linux"
	browsers.environment = {"PATH": "/usr/local/bin:/usr/bin"}
	browsers.installed = PackedStringArray(["/usr/bin/firefox", "/usr/bin/google-chrome-stable", "/usr/bin/microsoft-edge-stable", "/usr/bin/brave-browser-stable"])
	result = browsers.open_controllers(url, four_browsers)
	check(result.opened == PackedStringArray(["Firefox", "Chrome", "Microsoft Edge", "Brave"]), "Linux browsers are discovered on PATH")
	for index in browsers.calls.size():
		check_launch(browsers.calls[index], browsers.BROWSERS[index].name, url)
	browsers.installed = PackedStringArray(["/usr/bin/brave-browser"])
	result = browsers.open_controllers(url, four_browsers)
	check(result.opened == PackedStringArray(["Brave"]), "Linux discovers the brave-browser command on PATH")
	browsers.platform_name = "Android"
	browsers.calls.clear()
	result = browsers.open_controllers(url, four_browsers)
	check(not browsers.is_supported() and browsers.calls.is_empty(), "Android does not attempt desktop process launches")
	browsers = windows_browsers()
	result = browsers.open_controllers(url, PackedStringArray(["brave", "firefox", "brave"]))
	check(result.opened == PackedStringArray(["Brave", "Firefox"]) and browsers.calls.size() == 2, "Only chosen browsers open, once per browser")
	browsers.calls.clear()
	result = browsers.open_controllers(url, PackedStringArray())
	check(browsers.calls.is_empty(), "Empty selection never opens browsers")
	browsers = FakeBrowsers.new(); browsers.platform_name = "Windows"
	browsers.environment = {"PATH": "D:/Browsers"}
	browsers.installed = PackedStringArray(["D:/Browsers/chrome.exe"])
	check(browsers.detect().size() == 1, "Aliases on PATH do not produce duplicate controllers sharing an identity")
	browsers = FakeBrowsers.new(); browsers.platform_name = "Windows"
	browsers.installed = PackedStringArray(["D:/Custom Browser/browser.exe", "D:/Firefox/firefox.exe"])
	browsers.registry = {"HKCU\\SOFTWARE\\Clients\\StartMenuInternet": "HKEY_CURRENT_USER\\SOFTWARE\\Clients\\StartMenuInternet\\Custom\n    (Default)    REG_SZ    Custom Browser\nHKEY_CURRENT_USER\\SOFTWARE\\Clients\\StartMenuInternet\\Custom\\shell\\open\\command\n    (Default)    REG_SZ    \"D:\\Custom Browser\\browser.exe\" --url \"%1\"\nHKEY_CURRENT_USER\\SOFTWARE\\Clients\\StartMenuInternet\\Firefox\\shell\\open\\command\n    (Default)    REG_SZ    \"D:\\Firefox\\firefox.exe\" -osint -url \"%1\""}
	found = browsers.detect()
	check(found.size() == 2 and found[0].name == "Custom Browser" and found[1].id == "firefox", "Windows registration discovers custom browsers and custom Firefox locations")
	result = browsers.open_controllers(url, PackedStringArray([found[0].id, "firefox"]))
	check(result.opened == PackedStringArray(["Custom Browser", "Firefox"]) and browsers.calls[0].arguments.size() == 1, "Unknown registered browsers receive the connection URL without shell or unsupported flags")
	browsers = windows_browsers()
	browsers.registry = {"HKLM\\SOFTWARE\\Clients\\StartMenuInternet": "HKEY_LOCAL_MACHINE\\SOFTWARE\\Clients\\StartMenuInternet\\Firefox\\shell\\open\\command\n    (Default)    REG_SZ    \"C:\\Program Files\\Mozilla Firefox\\firefox.exe\" -url \"%1\""}
	check(browsers.detect().size() == 4, "Registry and standard-path detection deduplicate the same browser")
	browsers.installed.append("C:/Program Files/Internet Explorer/iexplore.exe")
	browsers.registry["HKCU\\SOFTWARE\\Clients\\StartMenuInternet"] = "HKEY_CURRENT_USER\\SOFTWARE\\Clients\\StartMenuInternet\\IEXPLORE.EXE\\shell\\open\\command\n    (Default)    REG_SZ    \"C:\\Program Files\\Internet Explorer\\iexplore.exe\" %1"
	check(browsers.detect().size() == 4, "Legacy Internet Explorer redirects are not offered as independent controllers")
	browsers = FakeBrowsers.new(); browsers.platform_name = "macOS"
	browsers.installed = PackedStringArray(["/Applications/Safari.app", "/Applications/Safari.app/Contents/MacOS/Safari"])
	result = browsers.open_controllers(url, PackedStringArray(["safari"]))
	check(result.opened == PackedStringArray(["Safari"]) and browsers.calls[0].path == "/usr/bin/open" and browsers.calls[0].arguments[1] == "/Applications/Safari.app", "Safari uses the macOS URL-opening mechanism")

	var app = load("res://Main.tscn").instantiate()
	app.profile_store = ProfileStore.new("res://.test_data/debug_browsers.json")
	app.debug_browsers = windows_browsers()
	root.add_child(app)
	await process_frame
	app.profile_store.data.settings.reduced_motion = true
	app._show_settings("title")
	await process_frame
	var button := debug_button(app)
	check(button != null and not button.disabled and button.tooltip_text.is_empty(), "One Debug entry remains available without a live LAN server")
	check(find_button(app, "Autoplay debug") == null, "Settings no longer contains the separate Autoplay debug entry")
	button.pressed.emit(); await process_frame
	var setup: GameDebugPanel = app.screen_root.get_child(0)
	check(app.current_state == "debug_setup" and setup.test_button.text == "Test", "Debug contains autoplay setup and a Test button")
	setup.test_button.pressed.emit(); await process_frame
	var panel: DebugBrowserPanel = app.debug_browser_panel
	check(app.current_state == "debug_browsers" and panel.browser_choices.size() == 4 and app.debug_browsers.calls.is_empty(), "Test scans browsers and waits for a selection")
	panel.browser_choices.firefox.button_pressed = true
	check(panel.open_button.disabled and panel.notice.text.contains("Enter the lobby"), "Stopped server explains how to enable controller launches")
	app._open_debug_controllers(PackedStringArray(["firefox"]))
	check(app.debug_browsers.calls.is_empty(), "Stopped server never launches a stale URL")
	panel.exit_requested.emit(); await process_frame
	check(app.current_state == "debug_setup", "Test Back returns to the combined Debug menu")
	app.screen_root.get_child(0).exit_requested.emit(); await process_frame
	app._return_from_settings()
	app._enter_lobby()
	check(app.lan_server.running, "Test controller server starts")
	app._show_settings("lobby")
	for frame in 4:
		await process_frame
	button = debug_button(app)
	check(not button.disabled, "Debug is enabled for the live lobby")
	check(button.get_global_rect().position.x > app.size.x * 0.75 and button.get_global_rect().position.y < 120, "Debug is in the top-right settings header")
	button.pressed.emit(); await process_frame
	setup = app.screen_root.get_child(0)
	for frame in 4: await process_frame
	check(setup.test_button.get_global_rect().end.x >= app.size.x - 30 and setup.test_button.get_global_rect().position.y < 100, "Test stays at the top right of Debug")
	if DisplayServer.get_name() != "headless": await capture(app, "debug")
	setup.test_button.pressed.emit(); await process_frame
	panel = app.debug_browser_panel
	check(panel.selected_browsers() == PackedStringArray(["firefox"]), "Browser selection survives return navigation")
	panel.browser_choices.brave.button_pressed = true
	check(panel.player_count.text == "2 test players selected" and not panel.open_button.disabled, "Selected browsers determine the test player count")
	if DisplayServer.get_name() != "headless": await capture(app, "browsers")
	panel.open_button.pressed.emit()
	check(app.debug_browsers.calls.size() == 2, "Open launches only the two selected browsers")
	for call in app.debug_browsers.calls:
		check(call.arguments[-1] == app.lan_server.controller_url() + "debug.html?width=390&height=844", "Debug uses the active LAN address and actual server port for the phone preview")
	check(panel.notice.text.contains("Opened: Firefox, Brave"), "Launch feedback names the selected browsers")
	var scans: int = app.debug_browsers.scans
	app.debug_browsers.installed.remove_at(3)
	panel.scan_button.pressed.emit()
	check(app.debug_browsers.scans == scans + 1 and panel.browser_choices.size() == 3 and panel.selected_browsers() == PackedStringArray(["firefox"]), "Rescan removes missing browsers and retains available selections")
	app.debug_browsers.failed_path = app.debug_browsers.installed[0]
	panel.open_button.pressed.emit()
	check(panel.notice.text.contains("Could not open: Firefox"), "A failed selected browser launch remains visible")
	app.debug_browsers.installed.clear()
	panel.scan_button.pressed.emit()
	check(panel.browser_choices.is_empty() and panel.open_button.disabled and panel.player_count.text.begins_with("0"), "No detected browsers leaves launch disabled with a zero player count")
	var many_browsers: Array = []; var many_ids := PackedStringArray()
	for index in 17:
		many_browsers.append({"id": str(index), "name": "Test Browser %02d" % (index + 1)})
		many_ids.append(str(index))
	panel.set_browsers(many_browsers, many_ids)
	check(panel.selected_browsers().size() == 16 and panel.browser_choices["16"].disabled, "Browser selection respects the sixteen-player limit")
	panel.browser_choices["0"].button_pressed = false
	check(not panel.browser_choices["16"].disabled, "Deselecting a browser frees a player slot")
	panel.exit_requested.emit(); await process_frame
	app.screen_root.get_child(0).exit_requested.emit(); await process_frame
	app._return_from_settings()
	check(app.current_state == "lobby" and app.lan_server.running, "Returning from Debug settings preserves the lobby")
	app._play_from_lobby()
	app._show_settings("game_menu")
	await process_frame
	debug_button(app).pressed.emit(); await process_frame
	app.screen_root.get_child(0).test_button.pressed.emit(); await process_frame
	check(not app.lan_server.lobby_open and app.debug_browser_panel.notice.text.contains("Return to the lobby"), "Test preserves admission lock and explains how to admit new players")
	app.debug_browser_panel.exit_requested.emit(); await process_frame
	app.screen_root.get_child(0).exit_requested.emit(); await process_frame
	app._return_from_settings()
	check(app.current_state == "game_menu" and not app.lan_server.lobby_open, "Return navigation preserves game selection")
	app.debug_browsers.platform_name = "Android"
	app._show_settings("game_menu")
	await process_frame
	debug_button(app).pressed.emit(); await process_frame
	app.screen_root.get_child(0).test_button.pressed.emit(); await process_frame
	check(app.debug_browser_panel.open_button.disabled and app.debug_browser_panel.notice.text.contains("desktop hosts"), "Unsupported host explains browser availability while keeping Debug accessible")
	app._leave_lobby()
	app.queue_free()
	await process_frame
	print("Debug browsers: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func check_launch(call: Dictionary, browser_name: String, url: String) -> void:
	var arguments: PackedStringArray = call.arguments
	check(arguments[-1] == url + "debug.html?width=390&height=844", "%s receives the same complete phone-preview URL as one argument" % browser_name)
	check("--new-window" in arguments and not "--new-tab" in arguments, "%s explicitly opens a new window" % browser_name)
	if browser_name == "Firefox":
		check(arguments.slice(0, 4) == PackedStringArray(["--width", "422", "--height", "984"]), "Firefox requests phone dimensions with room for browser chrome")
		check(arguments[arguments.find("--new-window") + 1] == arguments[-1], "Firefox receives the URL as the new-window parameter")
	else:
		check("--window-size=422,984" in arguments, "%s requests phone dimensions with room for browser chrome" % browser_name)
	check(not arguments.has("--incognito") and not arguments.has("--private-window") and not "--no-remote" in arguments, "%s preserves the normal profile and reconnect identity" % browser_name)


func debug_button(app: Control) -> Button:
	return find_button(app, "Debug")


func find_button(app: Control, caption: String) -> Button:
	for button in app.screen_root.find_children("*", "Button", true, false):
		if button.text == caption:
			return button
	return null


func capture(app: Control, label: String) -> void:
	var folder := "res://.test_data/debug-browsers/"
	DirAccess.make_dir_recursive_absolute(folder)
	root.min_size = Vector2i.ONE
	for dimensions in [Vector2i(1280, 720), Vector2i(390, 844), Vector2i(844, 390), Vector2i(640, 360)]:
		root.content_scale_size = dimensions; root.size = dimensions
		for frame in 12: await process_frame
		var action: Button = app.debug_browser_panel.open_button if label == "browsers" else app.screen_root.get_child(0).test_button
		check(root.get_visible_rect().encloses(action.get_global_rect()), "%s action remains reachable at %s" % [label, dimensions])
		var header_action: Button = app.debug_browser_panel.scan_button if label == "browsers" else action
		check(not header_action.get_global_rect().intersects(app.menu_music.trigger.get_global_rect()), "%s header action stays clear of music at %s" % [label, dimensions])
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder + "%s-%dx%d.png" % [label, dimensions.x, dimensions.y])
	root.content_scale_size = Vector2i(1280, 720); root.size = Vector2i(1280, 720)
	for frame in 6: await process_frame
