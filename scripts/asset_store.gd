class_name AssetStore
extends RefCounted

const MAX_BYTES := 512 * 1024 * 1024
var entries: Array[Dictionary] = []
var background_stems: Array[String] = []
var definitions_root := "res://Games"


func scan() -> Array[Dictionary]:
	entries.clear()
	background_stems.clear()
	var paths: Dictionary = {}
	for base in ["asset", "Games", "ui", "web"]:
		_collect("res://" + base, base, paths)
		if RuntimeAssets.root_folder().simplify_path() != ProjectSettings.globalize_path("res://").trim_suffix("/").simplify_path():
			_collect(RuntimeAssets.root_folder().path_join(base), base, paths)
	for relative: String in paths:
		if relative.ends_with("/game.json"):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(paths[relative])))
			if parsed is Dictionary and parsed.get("background", "") is String:
				var stem := relative.get_base_dir().path_join(str(parsed.get("background", "")))
				if RuntimeAssets.safe_media_path(stem + ".png"):
					background_stems.append(stem)
	var skin_slots: Dictionary = {}
	var skin_backgrounds: Dictionary = {}
	for id in DirAccess.get_directories_at(definitions_root):
		if FileAccess.file_exists(definitions_root.path_join(id).path_join("theme-slots.json")) and not id.begins_with("_"):
			for slot in ThemePacks.new(id, definitions_root).slots:
				var skin := {"game_id": id, "slot_id": slot.id, "protected": true}
				# A shared source can belong to multiple variants; retain its owner.
				if not skin_slots.has(slot.path) or str(slot.path).begins_with("Games/%s/" % id):
					skin_slots[slot.path] = skin
				if slot.kind == "background":
					if not skin_backgrounds.has(str(slot.path).get_basename()) or str(slot.path).begins_with("Games/%s/" % id):
						skin_backgrounds[str(slot.path).get_basename()] = skin
					if not background_stems.has(str(slot.path).get_basename()):
						background_stems.append(str(slot.path).get_basename())
	var sorted := paths.keys()
	sorted.sort()
	for relative: String in sorted:
		if not RuntimeAssets.safe_media_path(relative) or relative.get_file().contains(".replacement."):
			continue
		var background := relative.get_basename() in background_stems
		var source := RuntimeAssets.source("res://" + relative)
		var music := relative.begins_with("asset/lobby_songs/") or relative.begins_with("asset/music/")
		var entry := {"path": relative, "background": background or relative.begins_with("asset/splash_background/"), "source": source, "kind": "audio" if music else kind(source), "skin": "Default"}
		entry.merge(skin_slots.get(relative, skin_backgrounds.get(relative.get_basename(), {})), true)
		# Content-addressed skin media is visible too, but must remain immutable.
		var parts := relative.split("/")
		if parts.size() > 5 and parts[0] == "Games" and parts[2] == "themes":
			entry.merge({"game_id": parts[1], "skin": parts[3].capitalize(), "protected": true}, true)
		entries.append(entry)
	return entries


func _collect(directory: String, relative: String, paths: Dictionary) -> void:
	if not DirAccess.dir_exists_absolute(directory):
		return
	var names := Array(DirAccess.get_files_at(directory))
	if directory.begins_with("res://"):
		for name in ResourceLoader.list_directory(directory):
			if not name.ends_with("/") and not names.has(name):
				names.append(name)
	for name: String in names:
		if name == "game.json" or RuntimeAssets.safe_media_path(relative.path_join(name)):
			paths[relative.path_join(name)] = directory.path_join(name)
	for name in DirAccess.get_directories_at(directory):
		if not name.begins_with(".") and name != "_Template" and not _is_link(directory.path_join(name)):
			_collect(directory.path_join(name), relative.path_join(name), paths)


static func kind(path: String) -> String:
	var extension := path.get_extension().to_lower()
	if extension in BackgroundMedia.IMAGE_EXTENSIONS:
		return "image"
	if extension in BackgroundMedia.VIDEO_EXTENSIONS:
		return "video"
	if extension in RuntimeAssets.AUDIO_EXTENSIONS + RuntimeAssets.CONVERT_AUDIO_EXTENSIONS:
		return "audio"
	return ""


func stage(entry: Dictionary, selected: String) -> Dictionary:
	var relative := str(entry.get("path", ""))
	if not RuntimeAssets.safe_media_path(relative) or not entries.any(func(item: Dictionary) -> bool: return item.path == relative):
		return _error("Select an asset from the list first.")
	if entries.any(func(item: Dictionary) -> bool: return item.path == relative and item.get("protected", false)):
		return _error("This skin's source is protected. Duplicate the skin in Themes to replace its artwork or sound.")
	var media_kind := kind(selected)
	if media_kind.is_empty():
		return _error("Unsupported type. Choose PNG, JPG, WebP, BMP, SVG, OGV, MP4, WebM, MOV, M4V, MKV, AVI, WAV, OGG, or MP3.")
	var current := RuntimeAssets.source("res://" + relative)
	var current_kind: String = entry.get("kind", kind(current))
	if current_kind == "audio" and selected.get_extension().to_lower() not in RuntimeAssets.AUDIO_EXTENSIONS:
		return _error("Choose WAV, OGG Vorbis, or MP3 for an audio replacement. Other existing music sources can still be previewed.")
	if media_kind != current_kind and not (entry.background and media_kind in ["image", "video"]):
		return _error("This asset needs %s media. Only backgrounds can switch between images and videos." % current_kind)
	var file := FileAccess.open(selected, FileAccess.READ)
	if file == null or file.get_length() == 0 or file.get_length() > MAX_BYTES:
		return _error("The file is unreadable, empty, or larger than 512 MB.")
	file.close()
	var folder := "user://asset_editor/staged"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var staged := folder.path_join("%s.%s" % [Time.get_ticks_usec(), selected.get_extension().to_lower()])
	if not _copy(selected, staged):
		return _error("Could not prepare a preview copy. Your asset is unchanged.")
	var checked := inspect(staged)
	if not checked.ok:
		DirAccess.remove_absolute(staged)
		return checked
	checked.merge({"entry": entry.duplicate(), "staged": staged, "name": selected.get_file(), "hash": FileAccess.get_sha256(staged), "original_hash": FileAccess.get_sha256(current)}, true)
	return checked


static func inspect(path: String) -> Dictionary:
	var media_kind := kind(path)
	if media_kind == "image":
		if path.get_extension().to_lower() == "png":
			var file := FileAccess.open(path, FileAccess.READ)
			if file == null or file.get_buffer(8) != PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10]):
				return _error("This file is not a valid PNG image.")
		if path.get_extension().to_lower() == "svg":
			var svg := FileAccess.get_file_as_string(path).to_lower()
			var namespaces := RegEx.new()
			namespaces.compile('xmlns(?::[a-z]+)?\\s*=\\s*["\'][^"\']*["\']')
			var content := namespaces.sub(svg, "", true)
			if content.contains("<script") or content.contains("<foreignobject") or content.contains("http:") or content.contains("https:") or content.contains("file:") or content.contains("<!entity") or content.contains("@import"):
				return _error("SVG replacements must contain offline artwork only.")
			var references := RegEx.new()
			references.compile('(?:href|src)\\s*=\\s*["\']([^"\']+)')
			for match_item in references.search_all(svg):
				var reference := match_item.get_string(1)
				if not reference.begins_with("#") and not reference.begins_with("data:image/"):
					return _error("SVG replacements cannot link to external files or websites.")
		var image := Image.load_from_file(path)
		if image == null or image.is_empty():
			return _error("This file could not be decoded as an image.")
		return {"ok": true, "kind": media_kind, "details": "%d × %d pixels" % [image.get_width(), image.get_height()]}
	if media_kind == "audio":
		var stream := RuntimeAssets.audio(path)
		if stream == null or stream.get_length() <= 0:
			return _error("This file could not be decoded as audio.")
		return {"ok": true, "kind": media_kind, "details": "%.1f seconds" % stream.get_length()}
	if media_kind == "video":
		var output: Array = []
		# Decode a frame: a container extension alone does not prove support.
		var result := OS.execute("ffmpeg", PackedStringArray(["-hide_banner", "-i", ProjectSettings.globalize_path(path), "-map", "0:v:0", "-frames:v", "1", "-an", "-f", "null", "-"]), output, true, false)
		if result != 0:
			return _error("This file has no decodable video, or FFmpeg is unavailable on PATH.")
		var dimensions := RegEx.new()
		dimensions.compile("Video:[^\\n]*?\\b([0-9]{2,5})x([0-9]{2,5})\\b")
		var size_match := dimensions.search("".join(output))
		return {"ok": true, "kind": media_kind, "details": "%s × %s video · silent preview" % [size_match.get_string(1), size_match.get_string(2)] if size_match != null else "Video · silent preview"}
	return _error("Unsupported media type.")


static func prepare_audio_preview(path: String) -> Dictionary:
	var signature := FileAccess.get_sha256(path)
	if signature.is_empty():
		return _error("This audio source is unreadable.")
	var folder := "user://asset_editor/audio_previews"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var cached := folder.path_join(signature + ".ogg")
	if not FileAccess.file_exists(cached):
		var preparer := (Engine.get_main_loop() as SceneTree).root.get_node("BackgroundPreparer")
		if not preparer.prepare_audio(path, cached):
			return _error("This music preview requires FFmpeg on PATH and a readable audio track.")
	return {"ok": true, "preview": cached}


func save(pending: Dictionary) -> Dictionary:
	if OS.get_name() not in ["Windows", "macOS", "Linux"]:
		return _error("Asset replacement is available on desktop hosts.")
	var relative := str(pending.get("entry", {}).get("path", ""))
	if entries.any(func(item: Dictionary) -> bool: return item.path == relative and item.get("protected", false)):
		return _error("Use Themes to edit this protected skin asset.")
	var staged := str(pending.get("staged", ""))
	if not RuntimeAssets.safe_media_path(relative) or not staged.begins_with("user://asset_editor/staged/") or FileAccess.get_sha256(staged) != pending.get("hash", ""):
		return _error("The prepared replacement is missing or changed. Choose the file again.")
	var current := RuntimeAssets.source("res://" + relative)
	if FileAccess.get_sha256(current) != pending.original_hash:
		return _error("The original asset changed since preview. Discard and choose the replacement again.")
	var root_path := RuntimeAssets.root_folder()
	var extension := staged.get_extension()
	var target_relative := relative if extension == relative.get_extension().to_lower() else relative.get_basename() + ".replacement." + extension
	var target := root_path.path_join(target_relative)
	if not _safe_destination(target_relative) or not _safe_destination(RuntimeAssets.INDEX):
		return _error("The destination contains a linked folder. Choose an asset inside the Star Games root.")
	var backup_dir := root_path.path_join("Backups").path_join("%s-%s" % [Time.get_datetime_string_from_system().replace(":", "-"), Time.get_ticks_usec()])
	if _is_link(root_path.path_join("Backups")) or DirAccess.make_dir_recursive_absolute(backup_dir) != OK:
		return _error("Could not create Backups in the Star Games root. Check folder permissions.")
	var ignore := FileAccess.open(root_path.path_join("Backups/.gdignore"), FileAccess.WRITE)
	if ignore == null:
		return _error("Could not prepare the backup folder.")
	ignore.close()
	var snapshot_relative := relative.get_basename() + "." + current.get_extension()
	var snapshot := backup_dir.path_join(snapshot_relative)
	DirAccess.make_dir_recursive_absolute(snapshot.get_base_dir())
	if not _copy(current, snapshot):
		return _error("Backup failed. The original asset has not been changed.")
	var record := {"asset": relative, "snapshot": snapshot_relative, "sha256": FileAccess.get_sha256(snapshot)}
	if not _write_json(backup_dir.path_join("restore.json"), record):
		return _error("Could not record the backup. The original asset has not been changed.")
	DirAccess.make_dir_recursive_absolute(target.get_base_dir())
	var target_existed := FileAccess.file_exists(target)
	var rollback := backup_dir.path_join("destination.bak")
	if target_existed and not _copy(target, rollback):
		return _error("Could not back up the destination. The original asset has not been changed.")
	if not _copy(staged, target + ".tmp"):
		return _error("Could not write the replacement. The original asset is safe in Backups.")
	if target_existed and DirAccess.remove_absolute(target) != OK:
		DirAccess.remove_absolute(target + ".tmp")
		return _error("The asset is in use or read-only. Close other applications and try again.")
	if DirAccess.rename_absolute(target + ".tmp", target) != OK:
		if target_existed:
			_copy(rollback, target)
		return _error("Could not install the replacement. The previous file was restored.")
	var mapping := RuntimeAssets.replacements()
	mapping[relative] = target_relative
	if not _write_json(root_path.path_join(RuntimeAssets.INDEX), mapping):
		DirAccess.remove_absolute(target)
		if target_existed:
			_copy(rollback, target)
		return _error("Could not save the asset index. The previous file was restored.")
	RuntimeAssets.refresh()
	return {"ok": true, "backup": backup_dir, "path": relative, "source": target}


func previous(relative: String) -> String:
	if not RuntimeAssets.safe_media_path(relative):
		return ""
	var directory := RuntimeAssets.root_folder().path_join("Backups")
	if not DirAccess.dir_exists_absolute(directory):
		return ""
	var folders := DirAccess.get_directories_at(directory)
	folders.sort()
	folders.reverse()
	for folder in folders:
		var record_path := directory.path_join(folder).path_join("restore.json")
		if not FileAccess.file_exists(record_path):
			continue
		var record: Variant = JSON.parse_string(FileAccess.get_file_as_string(record_path))
		if record is Dictionary and record.get("asset", "") == relative and RuntimeAssets.safe_media_path(str(record.get("snapshot", ""))):
			var snapshot := directory.path_join(folder).path_join(str(record.snapshot))
			if FileAccess.file_exists(snapshot) and FileAccess.get_sha256(snapshot) == record.get("sha256", ""):
				return snapshot
	return ""


func _safe_destination(relative: String) -> bool:
	var path := RuntimeAssets.root_folder()
	for segment in relative.split("/"):
		path = path.path_join(segment)
		if _is_link(path):
			return false
	return true


static func _is_link(path: String) -> bool:
	var directory := DirAccess.open(path.get_base_dir())
	return directory != null and directory.is_link(path.get_file())


static func _copy(source: String, target: String) -> bool:
	return RuntimeAssets.copy_file(source, target)


static func _write_json(path: String, value: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(value, "\t") + "\n")
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return false
	var existed := FileAccess.file_exists(path)
	if existed and DirAccess.rename_absolute(path, path + ".rollback") != OK:
		return false
	if DirAccess.rename_absolute(path + ".tmp", path) != OK:
		if existed:
			DirAccess.rename_absolute(path + ".rollback", path)
		return false
	if existed:
		DirAccess.remove_absolute(path + ".rollback")
	return true


static func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
