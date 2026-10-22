extends Node

# Launcher-owned work survives game exit; a long encode never blocks navigation.
signal prepared(source: String, success: bool)
var pending: Array[Dictionary] = []
var known: Dictionary = {}
var current: Dictionary = {}
var worker: Thread


func prepare(source: String, target: String, media_kind := "video") -> bool:
	if OS.get_name() not in ["Windows", "macOS", "Linux"]:
		return false
	if known.has(target):
		if known[target] != "ready" or FileAccess.file_exists(target):
			return known[target] != "failed"
		known.erase(target)
	known[target] = "pending"
	pending.append({"source": source, "target": target, "kind": media_kind})
	return true


func prepare_audio(source: String, target: String) -> bool:
	return prepare(source, target, "audio")


func _process(_delta: float) -> void:
	if worker != null and not worker.is_alive():
		var result: int = worker.wait_to_finish()
		worker = null
		var success := result == 0 and DirAccess.rename_absolute(str(current.temporary), str(current.target)) == OK
		known[current.target] = "ready" if success else "failed"
		if not success:
			push_warning("Could not prepare video background: %s. Install FFmpeg or supply an .ogv file." % current.source)
		prepared.emit(current.source, success)
		current = {}
	if worker == null and not pending.is_empty():
		current = pending.pop_front()
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(str(current.target).get_base_dir()))
		current.temporary = str(current.target) + ".tmp." + str(current.target).get_extension()
		var args := PackedStringArray(["-hide_banner", "-loglevel", "error", "-y", "-i", ProjectSettings.globalize_path(current.source)])
		if current.kind == "audio":
			args.append_array(PackedStringArray(["-vn", "-c:a", "libvorbis", "-q:a", "5"]))
		else:
			args.append_array(PackedStringArray(["-map", "0:v:0", "-an", "-c:v", "libtheora", "-q:v", "7", "-pix_fmt", "yuv420p"]))
		args.append(ProjectSettings.globalize_path(str(current.temporary)))
		var original_source := str(current.source)
		worker = Thread.new()
		worker.start(func() -> int:
			var actual := RuntimeAssets.materialize(original_source)
			if actual.is_empty():
				return ERR_FILE_NOT_FOUND
			args[5] = actual
			return OS.execute("ffmpeg", args, [], false, false)
		)


func _exit_tree() -> void:
	if worker != null:
		worker.wait_to_finish()
