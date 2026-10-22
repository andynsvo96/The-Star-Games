extends SceneTree


func _init() -> void:
	var texture := QrCode.texture_for_text("http://192.168.1.20:8080/")
	if texture == null:
		printerr("QR generation failed")
		quit(1)
		return
	var output := "user://qr_test.png"
	var error := texture.get_image().save_png(output)
	print(ProjectSettings.globalize_path(output))
	quit(0 if error == OK else 1)
