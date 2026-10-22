extends SceneTree

class FakeBrowsers extends "res://scripts/debug_browsers.gd":
	var environment := {}
	var installed := PackedStringArray()
	var calls: Array[Dictionary] = []
	var failed_path := ""

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
	var result := browsers.open_controllers(url)
	check(result.opened == PackedStringArray(["Firefox", "Chrome", "Microsoft Edge", "Brave"]) and result.missing.is_empty() and result.failed.is_empty(), "All four Windows browsers open, including per-user installations")
	for index in browsers.calls.size():
		check_launch(browsers.calls[index], browsers.BROWSERS[index].name, url)
	browsers.installed.remove_at(0)
	browsers.failed_path = browsers.installed[0]
	browsers.calls.clear()
	result = browsers.open_controllers(url)
	check(result.missing == PackedStringArray(["Firefox"]), "Missing browser is reported")
	check(result.failed == PackedStringArray(["Chrome"]), "Failed launch is reported")
	check(result.opened == PackedStringArray(["Microsoft Edge", "Brave"]) and browsers.calls.size() == 3, "Other browsers still open after a missing or failed browser")
	browsers = windows_browsers()
	browsers.installed.remove_at(3)
	result = browsers.open_controllers(url)
	check(result.missing == PackedStringArray(["Brave"]) and result.opened.size() == 3, "Missing Brave is reported while other browsers still open")
	browsers = windows_browsers()
	browsers.failed_path = browsers.installed[3]
	result = browsers.open_controllers(url)
	check(result.failed == PackedStringArray(["Brave"]) and result.opened.size() == 3, "Failed Brave launch is reported while other browsers still open")
	browsers = FakeBrowsers.new()
	browsers.platform_name = "Windows"
	browsers.environment = {"PATH": '"D:/Custom Browsers";C:/Other'}
	browsers.installed = PackedStringArray(["D:/Custom Browsers/firefox.exe", "D:/Custom Browsers/brave.exe"])
	result = browsers.open_controllers(url)
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
	result = browsers.open_controllers(url)
	check(result.opened == PackedStringArray(["Firefox", "Chrome", "Microsoft Edge", "Brave"]), "macOS supports system and user Applications folders")
	for index in browsers.calls.size():
		var call: Dictionary = browsers.calls[index]
		check(call.path.contains(".app/Contents/MacOS/"), "macOS launches the browser executable so flags reach an existing process")
		check_launch(call, browsers.BROWSERS[index].name, url)
	browsers = FakeBrowsers.new()
	browsers.platform_name = "Linux"
	browsers.environment = {"PATH": "/usr/local/bin:/usr/bin"}
	browsers.installed = PackedStringArray(["/usr/bin/firefox", "/usr/bin/google-chrome-stable", "/usr/bin/microsoft-edge-stable", "/usr/bin/brave-browser-stable"])
	result = browsers.open_controllers(url)
	check(result.opened == PackedStringArray(["Firefox", "Chrome", "Microsoft Edge", "Brave"]), "Linux browsers are discovered on PATH")
	for index in browsers.calls.size():
		check_launch(browsers.calls[index], browsers.BROWSERS[index].name, url)
	browsers.installed = PackedStringArray(["/usr/bin/brave-browser"])
	result = browsers.open_controllers(url)
	check(result.opened == PackedStringArray(["Brave"]), "Linux discovers the brave-browser command on PATH")
	browsers.platform_name = "Android"
	browsers.calls.clear()
	result = browsers.open_controllers(url)
	check(not browsers.is_supported() and browsers.calls.is_empty(), "Android does not attempt desktop process launches")

	var app = load("res://Main.tscn").instantiate()
	app.profile_store = ProfileStore.new("res://.test_data/debug_browsers.json")
	app.debug_browsers = windows_browsers()
	root.add_child(app)
	await process_frame
	app.profile_store.data.settings.reduced_motion = true
	app._show_settings("title")
	await process_frame
	var button := debug_button(app)
	check(button != null and button.disabled and button.tooltip_text.is_empty(), "Settings contains Debug without a tooltip, disabled when the server is stopped")
	app._open_debug_controllers()
	check(app.debug_browsers.calls.is_empty(), "Stopped server never launches a stale URL")
	app._return_from_settings()
	app._enter_lobby()
	check(app.lan_server.running, "Test controller server starts")
	app._show_settings("lobby")
	for frame in 4:
		await process_frame
	button = debug_button(app)
	check(not button.disabled, "Debug is enabled for the live lobby")
	check(button.get_global_rect().position.x > app.size.x * 0.75 and button.get_global_rect().position.y < 120, "Debug is in the top-right settings header")
	button.pressed.emit()
	check(app.debug_browsers.calls.size() == 4, "Pressing Debug launches all four browsers")
	for call in app.debug_browsers.calls:
		check(call.arguments[-1] == app.lan_server.controller_url() + "debug.html?width=390&height=844", "Debug uses the active LAN address and actual server port for the phone preview")
	check(app.debug_notice.visible and app.debug_notice.text.contains("Opened: Firefox, Chrome, Microsoft Edge, Brave"), "Launch feedback appears immediately below the header")
	app._return_from_settings()
	check(app.current_state == "lobby" and app.lan_server.running, "Returning from Debug settings preserves the lobby")
	app._play_from_lobby()
	app._show_settings("game_menu")
	await process_frame
	debug_button(app).pressed.emit()
	check(not app.lan_server.lobby_open and app.debug_notice.text.contains("Return to the lobby"), "Debug preserves admission lock and explains how to admit new players")
	app._return_from_settings()
	check(app.current_state == "game_menu" and not app.lan_server.lobby_open, "Return navigation preserves game selection")
	app.debug_browsers.platform_name = "Android"
	app._show_settings("game_menu")
	await process_frame
	check(debug_button(app).disabled and app.debug_notice.text.contains("desktop hosts"), "Unsupported host displays an explanation beside the disabled action")
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
	for button in app.screen_root.find_children("*", "Button", true, false):
		if button.text == "Debug":
			return button
	return null
