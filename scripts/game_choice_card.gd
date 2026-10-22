class_name GameChoiceCard
extends Button

# Shared illustrated collection choice. Motion never moves a container-owned
# position, and unavailable choices retain a visible, static state.
var illustration: Texture2D
var card_faces: Array[Texture2D] = []
var card_data: Array[Dictionary] = []
var caption := ""
var accent := Color("8e0809")
var reduced_motion := false
var caption_on_top := false
var overlay_cards := false
var board_data: Array[Dictionary] = []
var _elapsed := 0.0


func _ready() -> void:
	text = caption
	add_theme_color_override("font_color", Color.TRANSPARENT)
	add_theme_color_override("font_hover_color", Color.TRANSPARENT)
	add_theme_color_override("font_pressed_color", Color.TRANSPARENT)
	add_theme_color_override("font_focus_color", Color.TRANSPARENT)
	add_theme_color_override("font_disabled_color", Color.TRANSPARENT)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	mouse_entered.connect(queue_redraw); mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw); focus_exited.connect(queue_redraw)
	resized.connect(queue_redraw)


func _process(delta: float) -> void:
	if not reduced_motion and not disabled and (is_hovered() or has_focus()):
		_elapsed += delta
		queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var active := not disabled and (is_hovered() or has_focus())
	var pulse := 1.0 if reduced_motion else .66 + .34 * sin(_elapsed * TAU / 2.3)
	if active:
		for radius in range(18, 0, -2):
			var glow := GameLook.box(Color(1, .72, .18, .018 * pulse), Color.TRANSPARENT, 25 + radius, 0)
			draw_style_box(glow, rect.grow(radius))
	var border := GameLook.box(Color("20170f"), Color("ffd77b") if active else Color("c9943f"), 24, 4)
	border.shadow_color = Color(0, 0, 0, .45); border.shadow_size = 9; border.shadow_offset = Vector2(0, 6)
	draw_style_box(border, rect)
	var picture := Rect2(Vector2(9, 9), Vector2(size.x - 18, size.y * .73 - 9))
	if caption_on_top: picture.position.y = size.y * .27; picture.size.y = size.y * .73 - 9
	if illustration != null:
		# TextureRect's cover geometry, clipped inside the framed inset.
		var source := Vector2(illustration.get_width(), illustration.get_height())
		var scale_factor := maxf(picture.size.x / source.x, picture.size.y / source.y)
		var crop := picture.size / scale_factor
		draw_texture_rect_region(illustration, picture, Rect2((source - crop) / 2, crop))
	else:
		draw_style_box(GameLook.box(Color("075d46"), Color.TRANSPARENT, 15, 0), picture)
	for index in board_data.size():
		var face_size := Vector2(picture.size.x * .10, picture.size.x * .15)
		var point := Vector2(picture.get_center().x + (index - (board_data.size() - 1) / 2.0) * face_size.x * 1.1, picture.get_center().y - picture.size.y * .20)
		GameCard.paint(self, Rect2(point - face_size / 2, face_size), board_data[index], null, Color.WHITE)
	if illustration == null or overlay_cards:
		for index in card_faces.size():
			var face_size := Vector2(picture.size.x * (.15 if overlay_cards else .29), picture.size.y * (.42 if overlay_cards else .84))
			var point := Vector2(picture.get_center().x + (index - (card_faces.size() - 1) / 2.0) * face_size.x * (.9 if overlay_cards else .62), picture.get_center().y + (picture.size.y * .12 if overlay_cards else 0))
			draw_set_transform(point, (index - (card_faces.size() - 1) / 2.0) * .18)
			if index < card_data.size():
				GameCard.paint(self, Rect2(-face_size / 2, face_size), card_data[index], card_faces[index], Color("244695"), false)
			else: draw_texture_rect(card_faces[index], Rect2(-face_size / 2, face_size), false)
		draw_set_transform(Vector2.ZERO)
	var plaque := Rect2(Vector2(7, size.y * .72), Vector2(size.x - 14, size.y * .28 - 7))
	if caption_on_top: plaque.position.y = 7
	draw_style_box(GameLook.box(accent.darkened(.4) if disabled else accent, Color("f8cf77"), 19, 2), plaque)
	var font := get_theme_font("title", "GamePalette") if get_theme_constant("casino", "GamePalette") == 1 else get_theme_font("font")
	var font_size := clampi(int(size.x / 8.5), 22, 64)
	while font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > plaque.size.x - 28 and font_size > 15: font_size -= 1
	var width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var point := Vector2(plaque.get_center().x - width / 2, plaque.get_center().y + font_size * .34)
	draw_string(font, point + Vector2(1, 3), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("4a2405"))
	draw_string(font, point, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("fff1c7") if not disabled else Color("b3a993"))
