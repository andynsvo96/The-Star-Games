class_name RuntimeAssets
extends RefCounted

# Both host presentation and the LAN server resolve the same saved media.
const INDEX := "asset/replacements.json"
const AUDIO_EXTENSIONS := ["wav", "ogg", "mp3"]
const CONVERT_AUDIO_EXTENSIONS := ["mp4", "m4a", "aac", "mov", "mkv", "webm", "flac", "wma"]
static var root_override := ""
static var redirects: Dictionary = {}
static var loaded := false
static var textures: Dictionary = {}


static func root_folder() -> String:
	if not root_override.is_empty():
		return root_override
	var project := ProjectSettings.globalize_path("res://")
	if FileAccess.file_exists(project.path_join("project.godot")):
		return project.trim_suffix("/")
	var executable_folder := OS.get_executable_path().get_base_dir()
	if OS.get_name() == "macOS" and executable_folder.get_file() == "MacOS" and executable_folder.get_base_dir().get_file() == "Contents":
		return executable_folder.get_base_dir().get_base_dir().get_base_dir()
	return executable_folder


static func safe_media_path(path: String) -> bool:
	if path.is_empty() or path.is_absolute_path() or path.contains("\\") or path.contains(":"):
		return false
	var parts := path.split("/")
	if parts[0] not in ["asset", "Games", "ui", "web"]:
		return false
	for part in parts:
		if part in ["", ".", ".."] or part.begins_with("."):
			return false
	return path.get_extension().to_lower() in BackgroundMedia.IMAGE_EXTENSIONS + BackgroundMedia.VIDEO_EXTENSIONS + AUDIO_EXTENSIONS + CONVERT_AUDIO_EXTENSIONS


static func refresh() -> void:
	loaded = false
	redirects.clear()
	textures.clear()


static func replacements() -> Dictionary:
	if not loaded:
		loaded = true
		var path := root_folder().path_join(INDEX)
		if not FileAccess.file_exists(path):
			path = "res://" + INDEX
		if FileAccess.file_exists(path):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary:
				for key in parsed:
					if key is String and parsed[key] is String and safe_media_path(key) and safe_media_path(parsed[key]):
						redirects[key] = parsed[key]
	return redirects.duplicate()


static func source(path: String) -> String:
	var relative := ""
	if path.begins_with("res://"):
		relative = path.trim_prefix("res://")
	elif path.begins_with(root_folder() + "/"):
		relative = path.trim_prefix(root_folder() + "/")
	else:
		return path
	if not safe_media_path(relative):
		return path
	var themed := ThemePacks.resolve(relative)
	var mapped: String = replacements().get(themed, themed)
	var external := root_folder().path_join(mapped)
	if FileAccess.file_exists(external):
		return external
	if FileAccess.file_exists("res://" + mapped):
		return "res://" + mapped
	return path


static func background_override(stem: String) -> String:
	if not stem.begins_with("res://"):
		return ""
	for extension in BackgroundMedia.IMAGE_EXTENSIONS + BackgroundMedia.VIDEO_EXTENSIONS:
		var original: String = stem.trim_prefix("res://") + "." + extension
		if ThemePacks.resolve(original) != original:
			return source("res://" + original)
	for key: String in replacements():
		if ("res://" + key.get_basename()) == stem:
			return source("res://" + key)
	return ""


static func texture(path: String) -> Texture2D:
	var resolved := source(path)
	# Keep the existing import settings (notably SVG scale) for unedited art.
	if resolved == ProjectSettings.globalize_path(path) and not replacements().has(path.trim_prefix("res://")):
		resolved = path
	if textures.has(resolved):
		return textures[resolved]
	var result: Texture2D
	if resolved.begins_with("res://") and not replacements().has(path.trim_prefix("res://")) and ResourceLoader.exists(resolved, "Texture2D"):
		result = load(resolved) as Texture2D
	else:
		var picture: Image
		if resolved.get_extension().to_lower() == "svg":
			picture = Image.new()
			var options := ConfigFile.new()
			var scale := 1.0
			if options.load(path + ".import") == OK:
				scale = float(options.get_value("params", "svg/scale", 1.0))
			if picture.load_svg_from_string(FileAccess.get_file_as_string(resolved), scale) != OK:
				picture = null
		else:
			picture = Image.load_from_file(resolved)
		if picture != null and not picture.is_empty():
			result = ImageTexture.create_from_image(picture)
	if result != null:
		textures[resolved] = result
	return result


static func scalable_texture(path: String, display_size := Vector2.ZERO) -> Texture2D:
	# SVG UI art retains its source and follows the canvas DPI instead of stretching
	# an imported thumbnail. Ordinary bitmap replacements keep their own resolution.
	var resolved := source(path)
	if resolved.get_extension().to_lower() != "svg": return texture(path)
	var key := "svg:" + resolved + ":1"
	var base: DPITexture = textures.get(key)
	if base == null:
		base = DPITexture.create_from_string(FileAccess.get_file_as_string(resolved))
		base.fix_alpha_border = true
		base.set_meta("svg_path", path); base.set_meta("svg_scale", 1)
		textures[key] = base
	var natural := base.get_size()
	if natural.x <= 0 or natural.y <= 0: return texture(path)
	var scale := clampi(ceili(maxf(display_size.x / natural.x, display_size.y / natural.y)), 1, 8)
	if scale == 1: return base
	key = "svg:" + resolved + ":%d" % scale
	var result: DPITexture = textures.get(key)
	if result == null:
		result = DPITexture.create_from_string(base.get_source(), scale)
		result.fix_alpha_border = true; result.set_size_override(Vector2i(natural))
		result.set_meta("svg_path", path); result.set_meta("svg_scale", scale)
		textures[key] = result
	result.set_meta("svg_used", Time.get_ticks_usec())
	# Keep zoomed reader variants bounded; currently displayed textures retain their
	# own references. Base card faces remain cached so a busy table never thrashes.
	var zoomed: Array = textures.keys().filter(func(candidate: String) -> bool: return candidate.begins_with("svg:") and int(textures[candidate].get_meta("svg_scale", 1)) > 1)
	if zoomed.size() > 6:
		zoomed.sort_custom(func(a: String, b: String) -> bool: return int(textures[a].get_meta("svg_used", 0)) < int(textures[b].get_meta("svg_used", 0)))
		for index in zoomed.size() - 6: textures.erase(zoomed[index])
	return result


static func audio(path: String) -> AudioStream:
	var resolved := source(path)
	match resolved.get_extension().to_lower():
		"wav": return AudioStreamWAV.load_from_file(resolved)
		"ogg": return AudioStreamOggVorbis.load_from_file(resolved)
		"mp3": return AudioStreamMP3.load_from_file(resolved)
	return null


static func copy_file(source_path: String, target: String) -> bool:
	# FileAccess reads bundled raw media as well as ordinary desktop files.
	var reader := FileAccess.open(source_path, FileAccess.READ)
	if reader == null:
		return false
	var writer := FileAccess.open(target, FileAccess.WRITE)
	if writer == null:
		return false
	var length := reader.get_length()
	while reader.get_position() < length:
		var chunk := reader.get_buffer(mini(65536, length - reader.get_position()))
		if chunk.is_empty():
			return false
		writer.store_buffer(chunk)
		if writer.get_error() != OK:
			return false
	writer.flush()
	var success := writer.get_error() == OK and writer.get_length() == length
	writer.close()
	reader.close()
	return success


static func materialize(path: String) -> String:
	# External converters cannot read virtual PCK paths. Cache a source copy.
	var physical := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(physical):
		return physical
	var signature := FileAccess.get_sha256(path)
	if signature.is_empty():
		return ""
	var folder := "user://media_sources"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var cached := folder.path_join(signature + "." + path.get_extension())
	if not FileAccess.file_exists(cached) and not copy_file(path, cached):
		return ""
	return ProjectSettings.globalize_path(cached)
