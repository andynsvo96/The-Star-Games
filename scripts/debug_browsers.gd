extends RefCounted

const BROWSERS := [
	{"id": "firefox", "name": "Firefox", "windows_path": "Mozilla Firefox/firefox.exe", "macos_app": "Firefox.app", "macos_executable": "firefox", "commands": ["firefox"]},
	{"id": "chrome", "name": "Chrome", "windows_path": "Google/Chrome/Application/chrome.exe", "macos_app": "Google Chrome.app", "macos_executable": "Google Chrome", "commands": ["google-chrome", "google-chrome-stable"]},
	{"id": "edge", "name": "Microsoft Edge", "windows_path": "Microsoft/Edge/Application/msedge.exe", "macos_app": "Microsoft Edge.app", "macos_executable": "Microsoft Edge", "commands": ["microsoft-edge", "microsoft-edge-stable"]},
	{"id": "brave", "name": "Brave", "windows_path": "BraveSoftware/Brave-Browser/Application/brave.exe", "macos_app": "Brave Browser.app", "macos_executable": "Brave Browser", "commands": ["brave-browser", "brave-browser-stable"]},
	{"id": "vivaldi", "name": "Vivaldi", "windows_path": "Vivaldi/Application/vivaldi.exe", "macos_app": "Vivaldi.app", "macos_executable": "Vivaldi", "commands": ["vivaldi", "vivaldi-stable"]},
	{"id": "opera", "name": "Opera", "windows_path": "Programs/Opera/opera.exe", "macos_app": "Opera.app", "macos_executable": "Opera", "commands": ["opera"]},
	{"id": "chromium", "name": "Chromium", "windows_path": "Chromium/Application/chrome.exe", "macos_app": "Chromium.app", "macos_executable": "Chromium", "commands": ["chromium", "chromium-browser"]},
	{"id": "safari", "name": "Safari", "windows_path": "", "macos_app": "Safari.app", "macos_executable": "Safari", "commands": []},
]
# iPhone 13/14 portrait dimensions in CSS pixels, rather than physical pixels.
const PHONE_VIEWPORT := Vector2i(390, 844)
const WINDOW_PADDING := Vector2i(32, 140)

var platform_name := OS.get_name()


func is_supported() -> bool:
	return platform_name in ["Windows", "macOS", "Linux"]


func detect() -> Array:
	var detected: Array = []
	if not is_supported():
		return detected
	var paths := {}
	for browser: Dictionary in BROWSERS:
		var path := _find_browser(browser)
		if path.is_empty() or paths.has(_path_key(path)): continue
		var entry := browser.duplicate(true)
		entry.path = path
		detected.append(entry)
		paths[_path_key(path)] = true
	# Registered clients also cover custom Windows install locations and browsers
	# outside the common list. Only their executable is used, never a shell command.
	if platform_name == "Windows":
		for browser: Dictionary in _registered_windows_browsers():
			var key := _path_key(str(browser.path))
			if paths.has(key): continue
			var matched := false
			for known: Dictionary in BROWSERS:
				if not str(known.windows_path).is_empty() and str(browser.path).get_file().to_lower() == str(known.windows_path).get_file().to_lower():
					# Chrome and Chromium share a filename; retain the registered
					# client's actual browser family for custom installations.
					if str(browser.path).get_file().to_lower() == "chrome.exe":
						var chromium := str(browser.name).to_lower().contains("chromium") or str(browser.path).to_lower().contains("/chromium/")
						if (known.id == "chromium") != chromium: continue
					if detected.any(func(entry: Dictionary) -> bool: return entry.id == known.id): continue
					var entry := known.duplicate(true); entry.path = browser.path
					detected.append(entry); matched = true; break
			if not matched: detected.append(browser)
			paths[key] = true
	return detected


func open_controllers(url: String, selected: PackedStringArray) -> Dictionary:
	var result := {"opened": PackedStringArray(), "missing": PackedStringArray(), "failed": PackedStringArray()}
	if not is_supported() or selected.is_empty():
		return result
	var preview_url := url.trim_suffix("/") + "/debug.html?width=%d&height=%d" % [PHONE_VIEWPORT.x, PHONE_VIEWPORT.y]
	var window_size := PHONE_VIEWPORT + WINDOW_PADDING
	var available := {}
	for browser: Dictionary in detect(): available[str(browser.id)] = browser
	var handled := {}
	for id: String in selected:
		if handled.has(id) or handled.size() >= LanServer.MAX_PLAYERS: continue
		handled[id] = true
		if not available.has(id):
			var name := id
			for browser: Dictionary in BROWSERS:
				if browser.id == id: name = str(browser.name); break
			result.missing.append(name)
			continue
		var browser: Dictionary = available[id]
		var path: String = browser.path
		# Launch directly so an already-running browser also receives new-window.
		# The preview keeps an exact viewport if window sizing is ignored/clamped.
		var arguments := PackedStringArray(["--new-window", "--window-size=%d,%d" % [window_size.x, window_size.y], preview_url])
		if browser.id == "firefox":
			arguments = PackedStringArray(["--width", str(window_size.x), "--height", str(window_size.y), "--new-window", preview_url])
		elif browser.id == "safari":
			arguments = PackedStringArray(["-a", path.get_base_dir().get_base_dir().get_base_dir(), preview_url])
			path = "/usr/bin/open"
		elif str(browser.id).begins_with("registered-"):
			# Unknown clients receive the URL alone, without Chromium-only flags.
			arguments = PackedStringArray([preview_url])
		if _create_process(path, arguments) == -1:
			result.failed.append(browser.name)
		else:
			result.opened.append(browser.name)
	return result


func _find_browser(browser: Dictionary) -> String:
	if platform_name == "Windows":
		if str(browser.windows_path).is_empty(): return ""
		for variable in ["ProgramW6432", "PROGRAMFILES", "PROGRAMFILES(X86)", "LOCALAPPDATA"]:
			var folder := _environment(variable)
			if not folder.is_empty():
				var path := folder.path_join(browser.windows_path)
				if _file_exists(path):
					return path
	elif platform_name == "macOS":
		for folder in ["/Applications", _environment("HOME").path_join("Applications")]:
			var path: String = folder.path_join(browser.macos_app)
			if _directory_exists(path):
				var executable := path.path_join("Contents/MacOS").path_join(browser.macos_executable)
				if _file_exists(executable):
					return executable
	var separator := ";" if platform_name == "Windows" else ":"
	for entry in _environment("PATH").split(separator, false):
		var folder := entry.strip_edges().trim_prefix('"').trim_suffix('"')
		for command in browser.commands:
			var filename: String = str(browser.windows_path).get_file() if platform_name == "Windows" else command
			var path := folder.path_join(filename)
			if _file_exists(path):
				return path
	return ""


func _path_key(path: String) -> String:
	var normalized := path.replace("\\", "/").simplify_path()
	return normalized.to_lower() if platform_name == "Windows" else normalized


func _registered_windows_browsers() -> Array:
	var clients := {}
	for registry_root in ["HKCU\\SOFTWARE\\Clients\\StartMenuInternet", "HKLM\\SOFTWARE\\Clients\\StartMenuInternet", "HKLM\\SOFTWARE\\WOW6432Node\\Clients\\StartMenuInternet"]:
		var current_key := ""
		for line: String in _read_registry(registry_root).split("\n"):
			var value := line.strip_edges()
			if value.begins_with("HKEY_"):
				current_key = value
				continue
			var marker := current_key.to_lower().find("\\startmenuinternet\\")
			var value_at := value.find("REG_SZ")
			if marker < 0 or value_at < 0: continue
			var relative := current_key.substr(marker + "\\startmenuinternet\\".length())
			var client := relative.get_slice("\\", 0)
			if not clients.has(client): clients[client] = {"name": client, "command": ""}
			value = value.substr(value_at + 6).strip_edges()
			if relative.to_lower().ends_with("\\shell\\open\\command"):
				clients[client].command = value
			elif not relative.contains("\\") and not value.is_empty() and not value.begins_with("@"):
				clients[client].name = value
	var browsers: Array = []
	for client: Dictionary in clients.values():
		var command: String = client.command
		var path := command.get_slice('"', 1) if command.begins_with('"') else command.substr(0, command.to_lower().find(".exe") + 4)
		path = path.replace("\\", "/")
		if path.get_extension().to_lower() != "exe" or not _file_exists(path): continue
		# This legacy registration may redirect to Edge, sharing its identity,
		# and cannot run the offline controller SDK itself.
		if path.get_file().to_lower() == "iexplore.exe": continue
		browsers.append({"id": "registered-" + _path_key(path).sha256_text().substr(0, 16), "name": str(client.name), "path": path})
	return browsers


func _read_registry(registry_root: String) -> String:
	var output: Array = []
	if OS.execute("reg.exe", PackedStringArray(["query", registry_root, "/s"]), output, false, false) != 0:
		return ""
	return "\n".join(output)


func _environment(variable: String) -> String:
	return OS.get_environment(variable)


func _file_exists(path: String) -> bool:
	return FileAccess.file_exists(path)


func _directory_exists(path: String) -> bool:
	return DirAccess.dir_exists_absolute(path)


func _create_process(path: String, arguments: PackedStringArray) -> int:
	return OS.create_process(path, arguments, false)
