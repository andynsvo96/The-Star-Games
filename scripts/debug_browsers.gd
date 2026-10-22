extends RefCounted

const BROWSERS := [
	{"name": "Firefox", "windows_path": "Mozilla Firefox/firefox.exe", "macos_app": "Firefox.app", "macos_executable": "firefox", "commands": ["firefox"]},
	{"name": "Chrome", "windows_path": "Google/Chrome/Application/chrome.exe", "macos_app": "Google Chrome.app", "macos_executable": "Google Chrome", "commands": ["google-chrome", "google-chrome-stable"]},
	{"name": "Microsoft Edge", "windows_path": "Microsoft/Edge/Application/msedge.exe", "macos_app": "Microsoft Edge.app", "macos_executable": "Microsoft Edge", "commands": ["microsoft-edge", "microsoft-edge-stable"]},
	{"name": "Brave", "windows_path": "BraveSoftware/Brave-Browser/Application/brave.exe", "macos_app": "Brave Browser.app", "macos_executable": "Brave Browser", "commands": ["brave-browser", "brave-browser-stable"]},
]
# iPhone 13/14 portrait dimensions in CSS pixels, rather than physical pixels.
const PHONE_VIEWPORT := Vector2i(390, 844)
const WINDOW_PADDING := Vector2i(32, 140)

var platform_name := OS.get_name()


func is_supported() -> bool:
	return platform_name in ["Windows", "macOS", "Linux"]


func open_controllers(url: String) -> Dictionary:
	var result := {"opened": PackedStringArray(), "missing": PackedStringArray(), "failed": PackedStringArray()}
	if not is_supported():
		return result
	var preview_url := url + "debug.html?width=%d&height=%d" % [PHONE_VIEWPORT.x, PHONE_VIEWPORT.y]
	var window_size := PHONE_VIEWPORT + WINDOW_PADDING
	for browser in BROWSERS:
		var path := _find_browser(browser)
		if path.is_empty():
			result.missing.append(browser.name)
			continue
		# Launch directly so an already-running browser also receives new-window.
		# The preview keeps an exact viewport if window sizing is ignored/clamped.
		var arguments := PackedStringArray(["--new-window", "--window-size=%d,%d" % [window_size.x, window_size.y], preview_url])
		if browser.name == "Firefox":
			arguments = PackedStringArray(["--width", str(window_size.x), "--height", str(window_size.y), "--new-window", preview_url])
		if _create_process(path, arguments) == -1:
			result.failed.append(browser.name)
		else:
			result.opened.append(browser.name)
	return result


func _find_browser(browser: Dictionary) -> String:
	if platform_name == "Windows":
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


func _environment(variable: String) -> String:
	return OS.get_environment(variable)


func _file_exists(path: String) -> bool:
	return FileAccess.file_exists(path)


func _directory_exists(path: String) -> bool:
	return DirAccess.dir_exists_absolute(path)


func _create_process(path: String, arguments: PackedStringArray) -> int:
	return OS.create_process(path, arguments, false)
