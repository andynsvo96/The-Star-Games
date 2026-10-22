extends SceneTree

# Build compact catalog images from the preserved, unmodified imagegen originals.
const GAME_IDS := [
	"battleship", "checkers", "chess", "four-in-a-row", "mafia", "monopoly",
	"pictionary", "poker", "quoridor", "spyfall", "tic-tac-toe", "uno",
]


func _init() -> void:
	var total_bytes := 0
	for id: String in GAME_IDS:
		var source := "res://asset/game-icons/originals/%s.png" % id
		var image := Image.load_from_file(source)
		if image == null or image.is_empty() or image.get_width() != image.get_height():
			push_error("Missing or non-square game icon: " + source)
			quit(1)
			return
		image.resize(512, 512, Image.INTERPOLATE_LANCZOS)
		image.convert(Image.FORMAT_RGB8)
		var target := "res://Games/%s/thumbnail.webp" % id
		if image.save_webp(target, true, 0.92) != OK:
			push_error("Could not save game icon: " + target)
			quit(1)
			return
		var bytes := FileAccess.get_file_as_bytes(target).size()
		total_bytes += bytes
		print("%s: %d bytes" % [id, bytes])
	print("Built %d game icons (%d bytes total)" % [GAME_IDS.size(), total_bytes])
	quit(0)
