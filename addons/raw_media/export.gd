@tool
extends EditorExportPlugin

# Include filters alone retain imported resources, not their source bytes.
const MEDIA_EXTENSIONS := ["png", "jpg", "jpeg", "webp", "bmp", "svg", "ogv", "mp4", "webm", "mov", "m4v", "mkv", "avi", "wav", "ogg", "mp3", "m4a", "aac", "flac", "wma"]


func _get_name() -> String:
	return "StarGamesRawMedia"


func _export_file(path: String, _type: String, _features: PackedStringArray) -> void:
	var relative := path.trim_prefix("res://")
	if relative.get_slice("/", 0) in ["asset", "Games", "ui", "web"] and path.get_extension().to_lower() in MEDIA_EXTENSIONS:
		add_file(path, FileAccess.get_file_as_bytes(path), false)
