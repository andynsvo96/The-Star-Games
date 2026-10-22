class_name BackgroundMedia
extends RefCounted

# A video's stem matches its image fallback. Prefer animation when both exist.
const VIDEO_EXTENSIONS := ["ogv", "mp4", "webm", "mov", "m4v", "mkv", "avi"]
const IMAGE_EXTENSIONS := ["png", "jpg", "jpeg", "webp", "bmp", "svg"]


static func candidates(stem: String) -> Array[String]:
	var replacement := RuntimeAssets.background_override(stem)
	if not replacement.is_empty():
		var resolved: Array[String] = [replacement]
		if replacement.get_extension().to_lower() in VIDEO_EXTENSIONS:
			for extension: String in IMAGE_EXTENSIONS:
				var fallback := stem + "." + extension
				var external := RuntimeAssets.root_folder().path_join(fallback.trim_prefix("res://"))
				if FileAccess.file_exists(external):
					resolved.append(external)
				elif FileAccess.file_exists(fallback):
					resolved.append(fallback)
		return resolved
	var stems: Array[String] = [stem]
	if OS.has_feature("standalone") and stem.begins_with("res://"):
		stems.push_front(RuntimeAssets.root_folder().path_join(stem.trim_prefix("res://")))
	for base in stems:
		var found: Array[String] = []
		var directory := base.get_base_dir()
		var filenames := Array(DirAccess.get_files_at(directory)) if DirAccess.dir_exists_absolute(directory) else []
		if directory.begins_with("res://"):
			for filename in ResourceLoader.list_directory(directory):
				if not filenames.has(filename):
					filenames.append(filename)
		for extension in VIDEO_EXTENSIONS + IMAGE_EXTENSIONS:
			for filename: String in filenames:
				if filename.get_basename() == base.get_file() and filename.get_extension().to_lower() == extension:
					found.append(directory.path_join(filename))
		# An external same-name source overrides the bundled set on both screens.
		if not found.is_empty():
			return found
	return []


static func cache_path(source: String) -> String:
	var file := FileAccess.open(source, FileAccess.READ)
	var signature := "%s:%s:%s" % [source, FileAccess.get_modified_time(source), file.get_length() if file != null else 0]
	return "user://video_backgrounds".path_join(signature.sha256_text() + ".ogv")
