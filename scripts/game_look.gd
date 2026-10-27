class_name GameLook
extends RefCounted

# Opt-in shared toy-box presentation. Game rules never depend on this theme.
const INK := Color("243653")
const CREAM := Color("fff4cf")
const RED := Color("ff4262")
const BLUE := Color("00b9ef")
const SCROLL_INK := Color("56351f")
const WOOD_INSET := Color("3c271b")
const WOOD_EDGE := Color("c38e50")
const DISABLED_FILL := Color("bfc3ca")
const DISABLED_EDGE := Color("838b98")
const DISABLED_INK := Color("59616f")
const NOTE_INK := Color("57441e")
static var _disabled_icons: Dictionary = {}


# Keep identity hues recognizable while making names readable on themed panels.
static func text_contrast(foreground: Color, background: Color) -> float:
	var front := foreground.srgb_to_linear().get_luminance()
	var back := background.srgb_to_linear().get_luminance()
	return (maxf(front, back) + 0.05) / (minf(front, back) + 0.05)


static func readable_text_color(identity: Color, background: Color, minimum := 4.5) -> Color:
	if text_contrast(identity, background) >= minimum:
		return identity
	var endpoint := Color.WHITE if text_contrast(Color.WHITE, background) >= text_contrast(Color.BLACK, background) else Color.BLACK
	var low := 0.0
	var high := 1.0
	for step in 20:
		var amount := (low + high) / 2.0
		if text_contrast(identity.lerp(endpoint, amount), background) >= minimum:
			high = amount
		else:
			low = amount
	return identity.lerp(endpoint, high)


static func sticky_note() -> StyleBoxTexture:
	var style := surface("sticky-note")
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, 28)
		style.set_content_margin(side, 18)
	return style


# Turn/choice feedback for canvas playfields; reduced motion uses a fixed pulse.
static func draw_turn_glow(canvas: CanvasItem, bounds: Rect2, accent: Color, pulse: float) -> void:
	for spread in [16.0, 11.0, 6.0]:
		var glow := accent.lerp(Color("ffe46a"),0.75)
		glow.a = 0.32 + pulse * 0.35
		var ring := box(Color.TRANSPARENT, glow, 18 + int(spread), 6)
		ring.shadow_size = 0
		canvas.draw_style_box(ring, bounds.grow(spread))
	var rim := box(Color(1.0, 0.8, 0.2, 0.12 + pulse * 0.10), Color(1.0, 0.96, 0.7, 1), 18, 4)
	rim.shadow_size = 0
	canvas.draw_style_box(rim, bounds.grow(3))

static func surface(kind: String) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = RuntimeAssets.texture("res://ui/playful/%s.svg" % kind)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, 28)
		style.set_content_margin(side, 14)
	return style


# Flat paper/clipboard surfaces for social games; geometry stays shared.
static func paper_sheet(clipboard := false, compact := false) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = RuntimeAssets.texture("res://ui/playful/clipboard-board.svg" if clipboard else "res://ui/playful/paper-fill.png")
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_BOTTOM, SIDE_TOP]:
		style.set_texture_margin(side, 30 if clipboard else 16)
		style.set_content_margin(side, 16 if clipboard else 18)
	if compact and not clipboard:
		for side in [SIDE_TOP, SIDE_BOTTOM]:
			style.set_content_margin(side, 8)
	if clipboard:
		style.set_content_margin(SIDE_TOP, 30)
	return style


# A thin shared paper surface leaves nearly the whole control for live artwork.
static func drawing_sheet() -> StyleBoxFlat:
	return box(Color("fff7e8"), WOOD_EDGE, 4, 3)


# Rounded card-table panels share one surface across host tables and previews.
static func card_table_sheet(active := false) -> StyleBoxFlat:
	var style := box(Color("fff7e5"), Color("f3c45b") if active else Color("c8b58c"), 12, 3 if active else 1)
	style.shadow_size = 5; style.shadow_offset = Vector2(0, 3); style.shadow_color = Color(0, 0, 0, .22)
	return style


static func card_table_frame() -> StyleBoxFlat:
	var style := box(Color.TRANSPARENT, Color("67462e"), 0, 16)
	style.draw_center = false; style.shadow_size = 0
	return style


static func guess_color(quality: String) -> Color:
	match quality:
		"correct": return Color("18773b")
		"close": return Color("9a5700")
		"wrong": return Color("b02535")
	return INK


static func artwork_sheet(texture: Texture2D, inset := 32.0) -> StyleBoxTexture:
	# Source originals remain editable. Resample only the displayed nine-slice
	# texture, so large generated artwork keeps a modest logical frame width.
	var image := texture.get_image()
	image.resize(256, 192, Image.INTERPOLATE_LANCZOS)
	var style := StyleBoxTexture.new()
	style.texture = ImageTexture.create_from_image(image)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_texture_margin(side, 28)
		style.set_content_margin(side, inset)
	return style


static func paper_theme(source: Theme) -> Theme:
	var result: Theme = source.duplicate()
	var ink := INK if source.get_constant("studio", "GamePalette") == 1 else Color("071c1e") if source.get_constant("dossier", "GamePalette") == 1 else Color("291e17")
	result.set_color("font_color", "Label", ink)
	result.set_color("default_color", "RichTextLabel", ink)
	return result


static func scroll_sheet() -> StyleBoxTexture:
	var style := surface("score-scroll")
	for side in [SIDE_TOP, SIDE_BOTTOM]:
		style.set_texture_margin(side, 38)
		style.set_content_margin(side, 54)
	for side in [SIDE_LEFT, SIDE_RIGHT]:
		style.set_texture_margin(side, 38)
		style.set_content_margin(side, 54)
	return style


static func scroll_toggle(button: Button, expanded: bool) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		if expanded:
			var clear := StyleBoxEmpty.new()
			clear.set_content_margin_all(10)
			button.add_theme_stylebox_override(state, clear)
		else:
			var roll := surface("scroll-closed")
			for side in [SIDE_LEFT, SIDE_RIGHT]:
				roll.set_texture_margin(side, 38)
				roll.set_content_margin(side, 30)
			for side in [SIDE_TOP, SIDE_BOTTOM]:
				roll.set_texture_margin(side, 20)
				roll.set_content_margin(side, 14)
			roll.modulate_color = Color(1.04, 1.04, 1.04) if state == "hover" else Color.WHITE
			button.add_theme_stylebox_override(state, roll)
		button.add_theme_color_override("font_" + ("color" if state == "normal" else state + "_color"), SCROLL_INK)
	button.add_theme_stylebox_override("focus", box(Color.TRANSPARENT, BLUE, 8, 2))
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

static func speech_bubble(_quality := "wrong") -> StyleBoxFlat:
	var style := box(Color.WHITE, Color("9ccff0"), 10, 1)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	style.shadow_size = 1
	style.shadow_offset = Vector2(0, 1)
	return style


static func box(fill: Color, edge: Color, radius := 18, border := 3) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(border)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.shadow_color = Color("49312055")
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 4)
	return style

static func make_theme(presentation := "") -> Theme:
	var result := Theme.new()
	var covert := presentation == "covert"
	var story := presentation in ["noir", "dossier"]
	var naval := presentation in ["naval", "covert", "noir", "dossier", "modern-table"]
	var ink := Color("e8f5ff") if naval else INK
	var edge := Color("6087ab") if naval else Color("bd782d")
	result.set_constant("naval", "GamePalette", int(naval))
	result.set_constant("covert", "GamePalette", int(covert))
	result.set_constant("story", "GamePalette", int(story))
	result.set_constant("noir", "GamePalette", int(presentation == "noir"))
	result.set_constant("dossier", "GamePalette", int(presentation == "dossier"))
	result.set_color("ink", "GamePalette", ink)
	result.set_color("panel", "GamePalette", Color("172c47f2") if naval else Color("fff4cff2"))
	result.set_color("panel_edge", "GamePalette", Color("557b9e") if naval else Color("c58d49"))
	result.set_color("status", "GamePalette", Color("203c5b") if naval else CREAM)
	result.set_color("status_edge", "GamePalette", edge if naval else Color("cf9749"))
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Arial Rounded MT Bold", "Trebuchet MS", "Arial"])
	font.font_weight = 700
	result.default_font = font
	result.default_font_size = 16
	result.set_color("font_color", "Label", ink)
	result.set_color("default_color", "RichTextLabel", ink)
	result.set_constant("separation", "VBoxContainer", 8)
	result.set_constant("separation", "HBoxContainer", 12)
	for type in ["Button", "OptionButton"]:
		for state in ["normal", "hover", "pressed", "disabled"]:
			var fill := Color("ffe8a3") if state != "hover" else Color("fff8dd")
			if naval:
				fill = Color({"normal": "284969", "hover": "365f83", "pressed": "1c3552", "disabled": "20344b"}[state])
			var style := box(fill, edge, 10 if naval else 16, 2)
			if naval:
				style.shadow_color = Color("08172c88")
				style.shadow_offset = Vector2(0, 2)
				style.shadow_size = 2
			result.set_stylebox(state, type, style)
			result.set_color("font_" + ("color" if state == "normal" else state + "_color"), type, Color("8ca5bd") if naval and state == "disabled" else ink)
		result.set_stylebox("focus", type, box(Color.TRANSPARENT, Color("8de8ff") if naval else Color("006dba"), 10 if naval else 16, 3))
	result.set_stylebox("panel", "PopupMenu", box(Color("203c5b") if naval else CREAM, edge))
	if naval:
		result.set_stylebox("hover", "PopupMenu", box(Color("365f83"), edge, 6, 0))
	result.set_color("font_color", "PopupMenu", ink)
	result.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	if naval:
		result.set_type_variation("GamePrimaryButton", "Button")
		for state in ["normal", "hover", "pressed", "disabled"]:
			var fill := Color({"normal": "176078", "hover": "247d94", "pressed": "10485e", "disabled": "20344b"}[state])
			var style := box(fill, Color("76cddd"), 10, 2)
			style.shadow_color = Color("08172c88")
			style.shadow_offset = Vector2(0, 2)
			style.shadow_size = 2
			result.set_stylebox(state, "GamePrimaryButton", style)
	if covert:
		result.set_color("ink", "GamePalette", Color("dcecf5"))
		result.set_color("panel", "GamePalette", Color("101f30f7"))
		result.set_color("panel_edge", "GamePalette", Color("3b7183"))
		result.set_color("status", "GamePalette", Color("142b3c"))
		result.set_color("status_edge", "GamePalette", Color("44d7c6"))
		result.set_color("font_color", "Label", Color("dcecf5"))
		result.set_color("default_color", "RichTextLabel", Color("dcecf5"))
		for type in ["Button", "OptionButton", "GamePrimaryButton"]:
			for state in ["normal", "hover", "pressed", "disabled"]:
				var primary: bool = type == "GamePrimaryButton"
				var fill := Color({"normal": "15565a", "hover": "20777a", "pressed": "103e45", "disabled": "192b38"}[state]) if primary else Color({"normal": "1d3548", "hover": "2c4d63", "pressed": "132635", "disabled": "192b38"}[state])
				var style := box(fill, Color("44d7c6") if primary else Color("527e91"), 10, 2)
				style.shadow_color = Color("040c1888")
				style.shadow_offset = Vector2(0, 2)
				style.shadow_size = 2
				result.set_stylebox(state, type, style)
				result.set_color("font_" + ("color" if state == "normal" else state + "_color"), type, Color("8499a8") if state == "disabled" else Color("dcecf5"))
		for state in ["normal", "focus", "read_only"]:
			result.set_stylebox(state, "LineEdit", box(Color("0b1928"), Color("44d7c6") if state == "focus" else Color("527e91"), 8, 2))
		result.set_color("font_color", "LineEdit", Color("dcecf5"))
		result.set_color("font_placeholder_color", "LineEdit", Color("8499a8"))
	if story:
		result.set_color("ink", "GamePalette", Color("291e17"))
		result.set_color("panel", "GamePalette", Color("f3dfb8"))
		result.set_color("panel_edge", "GamePalette", Color("b18a5d"))
		result.set_color("status", "GamePalette", Color("f3dfb8"))
		result.set_color("status_edge", "GamePalette", Color("b18a5d"))
		result.set_color("font_color", "Label", Color("ffefd2"))
		result.set_color("default_color", "RichTextLabel", Color("ffefd2"))
		if presentation == "noir":
			font.font_names = PackedStringArray(["Georgia", "Times New Roman", "serif"])
		else:
			font.font_names = PackedStringArray(["Arial Narrow", "Bahnschrift", "Helvetica Neue", "Arial"])
			font.font_weight = 600
			var digits := SystemFont.new()
			digits.font_names = PackedStringArray(["Arial Black", "Arial", "sans-serif"])
			digits.font_weight = 900
			result.set_type_variation("GameTimerLabel", "Label")
			result.set_font("font", "GameTimerLabel", digits)
			result.set_color("font_color", "GameTimerLabel", Color("071c1e"))
			result.set_color("ink", "GamePalette", Color("071c1e"))
			var divider := StyleBoxLine.new()
			divider.color = Color("88735455")
			divider.vertical = true
			divider.thickness = 1
			result.set_stylebox("separator", "VSeparator", divider)
			var horizontal_divider: StyleBoxLine = divider.duplicate()
			horizontal_divider.vertical = false
			result.set_stylebox("separator", "HSeparator", horizontal_divider)
		for type in ["Button", "OptionButton", "GamePrimaryButton"]:
			for state in ["normal", "hover", "pressed", "disabled"]:
				var fill := Color("211918") if presentation == "noir" else Color("123b3c")
				if state == "hover": fill = fill.lightened(0.12)
				if state == "pressed": fill = fill.darkened(0.15)
				if state == "disabled": fill = DISABLED_FILL
				var style := box(fill, DISABLED_EDGE if state == "disabled" else Color("ad8054") if presentation == "noir" else Color("8ab9b1"), 5, 2)
				style.shadow_color = Color("100b0980")
				style.shadow_size = 3
				result.set_stylebox(state, type, style)
				result.set_color("font_" + ("color" if state == "normal" else state + "_color"), type, DISABLED_INK if state == "disabled" else Color("ffefd2"))
			result.set_stylebox("focus", type, box(Color.TRANSPARENT, Color("f3c65e"), 5, 3))
		for state in ["normal", "focus", "read_only"]:
			result.set_stylebox(state, "LineEdit", box(Color("fff1d9"), Color("997a55"), 4, 1))
		result.set_color("font_color", "LineEdit", Color("291e17"))
		result.set_color("font_placeholder_color", "LineEdit", Color("78644f"))
	if presentation in ["royal", "arcade", "admiral"]:
		_apply_classic_palette(result, presentation)
	if presentation == "garden":
		_apply_classic_palette(result, "royal")
		_apply_garden_palette(result)
	if presentation == "card-table":
		_apply_classic_palette(result, "royal")
		_apply_garden_palette(result)
		result.set_constant("card_table", "GamePalette", 1)
		result.set_color("status", "GamePalette", Color("f4d48b"))
	if presentation == "studio":
		_apply_classic_palette(result, "royal")
		_apply_studio_palette(result)
	if presentation in ["modern-table", "party-table"]:
		_apply_modern_table_palette(result)
	if presentation == "casino":
		_apply_classic_palette(result, "royal")
		_apply_casino_palette(result)
	return result


# Dark brass/ivory table chrome is shared by host, settings and future card games.
static func _apply_casino_palette(result: Theme) -> void:
	result.set_constant("casino", "GamePalette", 1)
	var body_font := SystemFont.new(); body_font.font_names = PackedStringArray(["Segoe UI", "Arial", "sans-serif"]); body_font.font_weight = 500; result.default_font = body_font; result.default_font_size = 16
	var title_font := SystemFont.new(); title_font.font_names = PackedStringArray(["Georgia", "Times New Roman", "serif"]); title_font.font_weight = 800; result.set_font("title", "GamePalette", title_font)
	for key in ["ink", "text", "title"]: result.set_color(key, "GamePalette", Color("fff0cf"))
	result.set_color("panel", "GamePalette", Color("151510f5"))
	result.set_color("panel_edge", "GamePalette", Color("b68c46"))
	result.set_color("status", "GamePalette", Color("151510f5"))
	result.set_color("status_edge", "GamePalette", Color("b68c46"))
	result.set_color("muted", "GamePalette", Color("d4bb93"))
	result.set_color("gold", "GamePalette", Color("ffda79"))
	result.set_color("success", "GamePalette", Color("8ee5ad"))
	result.set_color("loss", "GamePalette", Color("ff7d86"))
	result.set_color("font_color", "Label", Color("fff0cf"))
	result.set_color("default_color", "RichTextLabel", Color("fff0cf"))
	result.set_stylebox("panel", "PanelContainer", casino_frame())
	for type in ["Button", "OptionButton", "GamePrimaryButton"]:
		for state in ["normal", "hover", "pressed", "disabled"]:
			var style := casino_button("raise" if type == "GamePrimaryButton" else "neutral", state)
			result.set_stylebox(state, type, style)
			result.set_color("font_" + ("color" if state == "normal" else state + "_color"), type, Color("a1a49a") if state == "disabled" else Color("fff1ce"))
		result.set_stylebox("focus", type, box(Color.TRANSPARENT, Color("ffe99c"), 9, 3))
		result.set_color("font_outline_color", type, Color("080b0dcc")); result.set_constant("outline_size", type, 1)
	for state in ["normal", "focus", "read_only"]: result.set_stylebox(state, "LineEdit", box(Color("171813"), Color("b68c46"), 7, 1))
	result.set_color("font_color", "LineEdit", Color("fff1ce"))
	result.set_stylebox("panel", "PopupMenu", casino_sheet())
	result.set_color("font_color", "PopupMenu", Color("fff1ce"))
	for kind in ["slider", "grabber_area", "grabber_area_highlight"]:
		var track := StyleBoxTexture.new(); track.texture = RuntimeAssets.texture("res://ui/playful/casino-slider-%s.svg" % ("track" if kind == "slider" else "fill"))
		for side in [SIDE_LEFT, SIDE_RIGHT]: track.set_texture_margin(side, 7); track.set_content_margin(side, 0)
		for side in [SIDE_TOP, SIDE_BOTTOM]: track.set_texture_margin(side, 4); track.set_content_margin(side, 5)
		result.set_stylebox(kind, "HSlider", track)
	for kind in ["grabber", "grabber_highlight", "grabber_disabled"]:
		result.set_icon(kind, "HSlider", RuntimeAssets.texture("res://ui/playful/casino-slider-knob%s.svg" % ("-disabled" if kind == "grabber_disabled" else "")))


static func casino_sheet(active := false, compact := false) -> StyleBoxFlat:
	var style := box(Color("151510f5"), Color("ffdc7b") if active else Color("b68c46"), 12, 2)
	style.set_content_margin_all(6 if compact else 14); style.shadow_size = 6; style.shadow_color = Color("00000088")
	return style


# Engraved brass frame and illuminated controls keep all text and hit areas live.
static func casino_frame(active := false, compact := false) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = RuntimeAssets.texture("res://ui/playful/casino-frame%s.svg" % ("-active" if active else ""))
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, 18 if compact else 24)
		style.set_content_margin(side, 6 if compact else 14)
	return style


# Rounded player plaques are separate from the engraved screen/pot frames.
static func casino_player_sheet(active := false) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = RuntimeAssets.texture("res://ui/playful/casino-player%s.svg" % ("-active" if active else ""))
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, 16); style.set_content_margin(side, 6)
	return style


static func casino_button(kind := "neutral", state := "normal") -> StyleBox:
	if state == "disabled":
		var disabled := box(Color("32362f"), Color("6e7163"), 9, 1)
		disabled.set_content_margin_all(10); disabled.shadow_size = 0; return disabled
	var style := StyleBoxTexture.new()
	style.texture = RuntimeAssets.texture("res://ui/playful/casino-button-%s.svg" % (kind if kind in ["fold", "call", "raise"] else "neutral"))
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, 18); style.set_content_margin(side, 10); style.set_expand_margin(side, 4)
	style.modulate_color = Color(1.14, 1.10, 1.02) if state == "hover" else Color(.77, .77, .77) if state == "pressed" else Color.WHITE
	return style


static func casino_action(button: Button, kind := "") -> void:
	for state in ["normal", "hover", "pressed", "disabled"]: button.add_theme_stylebox_override(state, casino_button(kind, state))


# Board-game palettes share controls and geometry; modules only select a style.
static func _apply_modern_table_palette(result: Theme) -> void:
	result.set_constant("modern_table", "GamePalette", 1)
	result.set_constant("royal", "GamePalette", 0)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Segoe UI", "Arial", "sans-serif"])
	font.font_weight = 600
	result.default_font = font
	result.default_font_size = 16
	for key in ["ink", "text", "title"]: result.set_color(key, "GamePalette", Color("eef8ff"))
	result.set_color("panel", "GamePalette", Color("05263df5"))
	result.set_color("panel_edge", "GamePalette", Color("258db6"))
	result.set_color("status", "GamePalette", Color("123b48"))
	result.set_color("status_edge", "GamePalette", Color("aeaa58"))
	result.set_color("muted", "GamePalette", Color("b6d6e8"))
	result.set_color("success", "GamePalette", Color("91e9b5"))
	result.set_color("loss", "GamePalette", Color("ff7d86"))
	result.set_color("gold", "GamePalette", Color("ffd447"))
	result.set_color("selection", "GamePalette", Color("64d5ff"))
	result.set_color("selection_fill", "GamePalette", Color("0d51665c"))
	result.set_color("font_color", "Label", Color("eef8ff"))
	result.set_color("default_color", "RichTextLabel", Color("d4eaf6"))
	for type in ["Button", "OptionButton", "GamePrimaryButton"]:
		for state in ["normal", "hover", "pressed", "disabled"]:
			var fill := Color("087be7") if type == "GamePrimaryButton" else Color("12425c")
			if state == "hover": fill = fill.lightened(.12)
			if state == "pressed": fill = fill.darkened(.15)
			if state == "disabled": fill = Color("344a5c")
			var style := box(fill, Color("3e9dc3") if state != "disabled" else Color("536b7d"), 11, 1)
			style.set_content_margin_all(10)
			style.shadow_color = Color("00142688"); style.shadow_size = 3; style.shadow_offset = Vector2(0, 3)
			result.set_stylebox(state, type, style)
			result.set_color("font_" + ("color" if state == "normal" else state + "_color"), type, Color("9cb3c3") if state == "disabled" else Color("f4faff"))
		result.set_stylebox("focus", type, box(Color.TRANSPARENT, Color("ffe58a"), 11, 3))
		result.set_font_size("font_size", type, 16)


static func modern_table_sheet(active := false) -> StyleBoxFlat:
	var style := box(Color("05263df5"), Color("ffd447") if active else Color("258db6"), 15, 2 if active else 1)
	style.shadow_color = Color("ffd44766") if active else Color("00101c66")
	style.shadow_size = 10 if active else 4
	return style


# Optional asset-game plaques keep identity, cash and collections on one surface.
static func asset_player_sheet(identity: Color, active := false, compact := false) -> StyleBoxFlat:
	var style := modern_table_sheet()
	style.bg_color = Color("061d30").lerp(identity, .08)
	style.border_color = identity.lightened(.35 if active else .16)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(6 if compact else 8)
	style.shadow_color = Color(identity, .42 if active else .16)
	style.shadow_size = 12 if active else 5
	style.shadow_offset = Vector2(0, 2)
	return style


static func money_text(amount: int) -> String:
	var digits := str(absi(amount))
	for index in range(digits.length() - 3, 0, -3): digits = digits.insert(index, ",")
	return ("−" if amount < 0 else "") + "$" + digits


# Raised blue/slate/red actions for asset tables; dimensions and focus stay shared.
static func asset_action(button: Button, kind := "secondary") -> void:
	table_action(button, "play" if kind == "primary" else "bank")
	var fill := Color("067cbd") if kind == "primary" else Color("a32536") if kind == "end" else Color("163e58")
	for state in ["normal", "hover", "pressed", "disabled"]:
		var tint := fill.lightened(.14) if state == "hover" else fill.darkened(.16) if state == "pressed" else fill
		if state == "disabled": tint = Color("344a5c")
		var style := box(tint, tint.lightened(.48), 12, 2)
		style.set_content_margin_all(10)
		style.shadow_color = Color("35cfff66") if kind == "primary" and state != "disabled" else Color("00081988")
		style.shadow_size = 8 if kind == "primary" and state != "disabled" else 3
		style.shadow_offset = Vector2(0, 3)
		button.add_theme_stylebox_override(state, style)
	button.add_theme_stylebox_override("focus", box(Color.TRANSPARENT, Color("ffe58a"), 12, 3))
	button.add_theme_font_override("font", party_font(button.get_theme_default_font()))
	button.add_theme_constant_override("icon_max_width", 24)
	button.add_theme_constant_override("h_separation", 8)
	button.expand_icon = true
	if not button.has_meta("asset_action_fitted"):
		button.set_meta("asset_action_fitted", true)
		button.resized.connect(func() -> void: center_button_contents(button))
	center_button_contents(button)


static func rules_sheet() -> StyleBoxFlat:
	var style := box(Color("152139f2"), Color("368eb9"), 20, 1)
	style.set_content_margin_all(12)
	style.content_margin_top = 5
	style.shadow_color = Color("00081988")
	style.shadow_size = 8
	return style


# Party tables reuse the modern palette, avatars and semantic card counters.
static func party_player_sheet(identity: Color, active := false) -> StyleBoxFlat:
	var style := modern_table_sheet(active)
	style.bg_color = party_identity_fill(identity)
	style.border_color = Color("ffe47b") if active else identity.lightened(.18)
	style.set_border_width_all(2 if active else 1)
	style.set_corner_radius_all(24)
	style.shadow_size = 12 if active else 5
	style.shadow_color = Color("ffd44777") if active else Color("00081966")
	style.shadow_offset = Vector2(0, 3)
	return style


static func party_identity_fill(identity: Color) -> Color:
	var fill := identity
	for step in 40:
		if text_contrast(Color.WHITE, fill) >= 5.6: break
		fill = fill.darkened(.045)
	return fill


static var _party_fonts: Dictionary = {}
static func party_font(base: Font) -> Font:
	var key := base.get_instance_id()
	if not _party_fonts.has(key):
		var bold := FontVariation.new()
		bold.base_font = base
		bold.variation_embolden = .65
		_party_fonts[key] = bold
	return _party_fonts[key]


static func draw_party_player(canvas: CanvasItem, bounds: Rect2, identity: Color, active := false) -> void:
	canvas.draw_style_box(party_player_sheet(identity, active), bounds)
	canvas.draw_style_box(party_sheen(), bounds.grow(-2))


static func party_sheen() -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = RuntimeAssets.texture("res://ui/playful/party-sheen.svg")
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, 20)
		style.set_content_margin(side, 0)
	return style


static func party_feedback_sheet() -> StyleBoxFlat:
	var style := rules_sheet()
	style.bg_color = Color("13213af5")
	style.border_color = Color("608fce")
	style.set_content_margin_all(10)
	style.shadow_size = 8
	return style


# The visible cue is smaller than the end stack's 44px input target.
static func draw_party_hand_hint(canvas: Control, target: Rect2, direction: int, amount: int, disabled := false) -> void:
	var bounds := Rect2(Vector2(target.get_center().x - 22, target.get_center().y - 15), Vector2(44, 30))
	var surface := box(Color("14253cf2"), Color("7195b3"), 12, 1)
	surface.shadow_color = Color("00081966"); surface.shadow_size = 3
	canvas.draw_style_box(surface, bounds)
	var tint := Color("9bb0c2") if disabled else Color("eef8ff")
	var arrow := bounds.position + Vector2(10 if direction < 0 else 34, 15)
	canvas.draw_polyline(PackedVector2Array([arrow + Vector2(direction * -3, -4), arrow + Vector2(direction * 1, 0), arrow + Vector2(direction * -3, 4)]), tint, 2, true)
	var label := str(amount)
	var font := party_font(canvas.get_theme_default_font())
	var font_size := 12 if amount < 100 else 10
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	canvas.draw_string(font, bounds.position + Vector2((44 - width) / 2.0 + (-4 if direction > 0 else 4), 19), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, tint)


# Cosmetic depth preserves the supplied card face and its input rectangle.
static func draw_party_card(canvas: CanvasItem, artwork: Texture2D, bounds: Rect2, tint := Color.WHITE, depth := 0.0, tabletop := false) -> void:
	if artwork == null or bounds.size.x <= 0 or bounds.size.y <= 0: return
	var shadow := box(Color("00081b30"), Color.TRANSPARENT, maxf(3, bounds.size.x * .06), 0)
	shadow.set_content_margin_all(0)
	shadow.shadow_color = Color("00051480")
	shadow.shadow_size = clampi(int(bounds.size.x * .07), 2, 12)
	shadow.shadow_offset = Vector2(1, maxf(3, bounds.size.x * .055))
	canvas.draw_style_box(shadow, bounds.grow(-2))
	if depth > 0:
		for layer in range(int(depth), 0, -1):
			var edge := box(Color("ede5d7") if layer % 2 == 0 else Color("a5a3a1"), Color("706a66"), maxf(3, bounds.size.x * .06), 1)
			edge.shadow_size = 0
			canvas.draw_style_box(edge, Rect2(bounds.position + Vector2(-layer * .15, layer), bounds.size))
	if tabletop:
		var inset := bounds.size.x * .035
		var corners := PackedVector2Array([bounds.position + Vector2(inset, 0), bounds.position + Vector2(bounds.size.x - inset, 0), bounds.end, bounds.position + Vector2(0, bounds.size.y)])
		canvas.draw_polygon(corners, PackedColorArray([tint]), PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]), artwork)
	else: canvas.draw_texture_rect(artwork, bounds, false, tint)


static func party_action(button: Button, kind := "play") -> void:
	table_action(button, "special" if kind == "sort" else "play")
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_constant_override("h_separation", 6)
	button.add_theme_font_override("font", party_font(button.get_theme_default_font()))
	var fill := Color("ed202e") if kind == "call" else Color("8339d0") if kind == "sort" else Color("0869db")
	for state in ["normal", "hover", "pressed", "disabled"]:
		var tint := fill.lightened(.14) if state == "hover" else fill.darkened(.18) if state == "pressed" else fill
		if state == "disabled": tint = Color("344a5c")
		var surface := box(tint, Color("ffe47b") if kind == "call" else tint.lightened(.45), 24, 2)
		surface.set_content_margin_all(10)
		surface.shadow_size = 12 if kind == "call" and state != "disabled" else 5
		surface.shadow_color = Color("ffd44788") if kind == "call" else Color("00142688")
		if state == "disabled":
			surface.border_color = Color("536b7d")
			surface.shadow_size = 0
		button.add_theme_stylebox_override(state, surface)
	button.add_theme_stylebox_override("focus", box(Color.TRANSPARENT, Color("fff0a1"), 20, 3))


# Keep an icon and label together as one centered group as the button resizes.
static func center_button_contents(button: Button) -> void:
	if button.icon == null or button.text.is_empty(): return
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var surface := button.get_theme_stylebox("normal")
	var icon_width := float(button.icon.get_width())
	if button.expand_icon:
		icon_width = maxf(0, button.size.y - surface.get_minimum_size().y) * button.icon.get_width() / button.icon.get_height()
	var maximum := button.get_theme_constant("icon_max_width")
	if maximum > 0: icon_width = minf(icon_width, maximum)
	var text_width := button.get_theme_font("font").get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size("font_size")).x
	var inset := maxf(6, (button.size.x - icon_width - button.get_theme_constant("h_separation") - text_width) / 2)
	for state in ["normal", "hover", "pressed", "disabled"]:
		button.get_theme_stylebox(state).content_margin_left = inset
		button.get_theme_stylebox(state).content_margin_right = inset


static func draw_table_building(canvas: Control, bounds: Rect2, kind: String) -> void:
	if kind == "house":
		canvas.draw_texture_rect(RuntimeAssets.texture("res://ui/playful/table-house.svg"), bounds, false)
	else:
		canvas.draw_style_box(box(Color("e95c69"), Color("ffd0d3"), 2, 1), bounds.grow(-2))
		for row in 2:
			for column in 3:
				canvas.draw_rect(Rect2(bounds.position + Vector2(4 + column * 4, 4 + row * 5), Vector2(2, 3)), Color("fff4d9"))
		canvas.draw_rect(Rect2(bounds.position + Vector2(8, 13), Vector2(3, 4)), Color("fff4d9"))


static func draw_table_winner(canvas: Control, bounds: Rect2, elapsed: float, reduced: bool) -> void:
	var font := canvas.get_theme_default_font(); var font_size := clampi(int(bounds.size.y * 0.8), 9, 20)
	while font_size > 8 and font.get_string_size("WINNER", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > bounds.size.x: font_size -= 1
	var width := font.get_string_size("WINNER", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var x := bounds.position.x; var shine := fposmod(elapsed * 0.45, 1.5) - 0.25
	for character in "WINNER":
		var highlight := 0.0 if reduced else pow(maxf(0, 1.0 - absf((x - bounds.position.x) / maxf(1, width) - shine) * 4), 2)
		var point := Vector2(x, bounds.position.y + font_size)
		canvas.draw_string_outline(font, point, character, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 2, Color("75501b"))
		canvas.draw_string(font, point, character, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("ffd54d").lerp(Color("fffad1"), highlight))
		x += font.get_string_size(character, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


static func table_owed_color() -> Color:
	return Color("ff777c")


static func table_action(button: Button, kind := "play") -> void:
	button.custom_minimum_size.y = 44
	button.add_theme_font_size_override("font_size", 16)
	var fill := Color("ffc52d") if kind == "end" else Color("4c6385") if kind == "bank" else Color("8e3ddb") if kind == "special" else Color("087be7")
	for state in ["normal", "hover", "pressed", "disabled"]:
		var tint := fill.lightened(.1) if state == "hover" else fill.darkened(.12) if state == "pressed" else fill
		if state == "disabled": tint = Color("344a5c")
		var style := box(tint, tint.lightened(.3), 10, 1)
		style.shadow_color = tint.darkened(.6); style.shadow_size = 2; style.shadow_offset = Vector2(0, 3)
		button.add_theme_stylebox_override(state, style)
		button.add_theme_color_override("font_" + ("color" if state == "normal" else state + "_color"), Color("9bb0c0") if state == "disabled" else Color("352800") if kind == "end" else Color.WHITE)


static func draw_table_avatar(canvas: CanvasItem, bounds: Rect2, identity: Color, pose := 0, contrast_background := false, winner := false) -> void:
	canvas.draw_circle(bounds.get_center(), bounds.size.x / 2, party_identity_fill(identity) if contrast_background else identity.darkened(.2))
	canvas.draw_arc(bounds.get_center(), bounds.size.x / 2, 0, TAU, 32, identity.lightened(.4), 2, true)
	var texture := RuntimeAssets.texture("res://web/avatar-%d.svg" % clampi(pose, 0, 5))
	if texture != null:
		draw_texture_contained(canvas,texture,Rect2(bounds.position + bounds.size * .1, bounds.size * .8))
	if winner:
		var crown_size := bounds.size.x * .6
		canvas.draw_texture_rect(RuntimeAssets.texture("res://ui/playful/table-crown.svg"), Rect2(bounds.position + Vector2(bounds.size.x * .05, -bounds.size.y * .16), Vector2(crown_size, crown_size * .8)), false)


static func draw_texture_contained(canvas: CanvasItem, texture: Texture2D, bounds: Rect2, tint := Color.WHITE) -> void:
	if texture == null: return
	var natural := texture.get_size()
	if natural.x <= 0 or natural.y <= 0: return
	var dimensions := natural*minf(bounds.size.x/natural.x,bounds.size.y/natural.y)
	canvas.draw_texture_rect(texture,Rect2(bounds.get_center()-dimensions/2,dimensions),false,tint)

static func draw_table_text(canvas: Control, text: String, point: Vector2, width: float, font_size: int, color: Color, centered := false) -> void:
	var font := canvas.get_theme_default_font()
	var fitted := text
	while fitted.length() > 1 and font.get_string_size(fitted, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
		fitted = fitted.substr(0, fitted.length() - 2) + "…"
	canvas.draw_string(font, point, fitted, HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT, width, font_size, color)


# A static wash keeps public eliminated seats in place without fading the roster.
static func draw_table_eliminated(canvas: CanvasItem, bounds: Rect2) -> void:
	var shade := box(Color(0, 0, 0, .45), Color.TRANSPARENT, 16, 0)
	shade.shadow_size = 0
	canvas.draw_style_box(shade, bounds)


# Shared cash/card/house counters use the same offline SVGs as browser tables.
static func draw_table_stats(canvas: Control, point: Vector2, width: float, stats: Array, font_size := 11, prominent := false) -> void:
	var font := party_font(canvas.get_theme_default_font()) if prominent else canvas.get_theme_default_font()
	var required := 0.0
	for stat in stats: required += (font_size * .9 + 7 if prominent else 22) + font.get_string_size(str(stat.value), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var scale := minf(1, width / maxf(1, required))
	var fitted_size := maxi(8, int(font_size * scale))
	var icon_size := (font_size * .9 if prominent else 15.0) * scale
	var x := point.x
	for stat in stats:
		var texture := RuntimeAssets.texture("res://ui/playful/table-%s.svg" % stat.icon)
		if texture != null: canvas.draw_texture_rect(texture, Rect2(Vector2(x, point.y - icon_size + 2), Vector2.ONE * icon_size), false)
		x += icon_size + 3 * scale
		var value := str(stat.value)
		canvas.draw_string(font, Vector2(x, point.y), value, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted_size, Color.WHITE if prominent else canvas.get_theme_color("muted", "GamePalette"))
		x += font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted_size).x + 4 * scale


static func _apply_classic_palette(result: Theme, presentation: String) -> void:
	var royal := presentation == "royal"
	var admiral := presentation == "admiral"
	var ink := Color("392718") if royal else Color("152b3e")
	var cream := Color("f4e5c6")
	var edge := Color("b18b4e")
	var dark := Color("302218") if royal else Color("102e3e")
	result.set_constant("naval", "GamePalette", 1)
	result.set_constant("classic", "GamePalette", 1)
	result.set_constant("royal", "GamePalette", int(royal))
	result.set_color("ink", "GamePalette", Color("f4ead5") if admiral else ink)
	result.set_color("panel", "GamePalette", dark if admiral else cream)
	result.set_color("panel_edge", "GamePalette", edge)
	result.set_color("status", "GamePalette", dark if admiral else cream)
	result.set_color("status_edge", "GamePalette", edge)
	result.set_color("font_color", "Label", Color("f4ead5") if admiral else ink)
	result.set_color("default_color", "RichTextLabel", Color("f4ead5") if admiral else ink)
	if royal:
		var font := SystemFont.new()
		font.font_names = PackedStringArray(["Georgia", "Times New Roman", "serif"])
		font.font_weight = 700
		result.default_font = font
	result.set_type_variation("GamePrimaryButton", "Button")
	for type in ["Button", "OptionButton", "GamePrimaryButton"]:
		for state in ["normal", "hover", "pressed", "disabled"]:
			var primary: bool = type == "GamePrimaryButton"
			var fill := Color("154b52") if primary else dark if royal or admiral else cream
			if state == "hover": fill = fill.lightened(0.1)
			if state == "pressed": fill = fill.darkened(0.12)
			var disabled: bool = state == "disabled"
			var style := box(DISABLED_FILL if disabled else fill, DISABLED_EDGE if disabled else Color("62bfc5") if primary else edge, 7, 2)
			style.shadow_color = Color("150f0966")
			style.shadow_size = 2
			style.shadow_offset = Vector2(0, 2)
			result.set_stylebox(state, type, style)
			result.set_color("font_" + ("color" if state == "normal" else state + "_color"), type, DISABLED_INK if disabled else Color("f4ead5") if primary or royal or admiral else ink)
		result.set_stylebox("focus", type, box(Color.TRANSPARENT, Color("f3ce79"), 7, 3))
	for state in ["normal", "focus", "read_only"]:
		result.set_stylebox(state, "LineEdit", box(dark if admiral else cream, edge, 6, 1))
	result.set_color("font_color", "LineEdit", Color("f4ead5") if admiral else ink)
	result.set_stylebox("panel", "PopupMenu", box(dark if admiral else cream, edge, 7, 2))
	result.set_color("font_color", "PopupMenu", Color("f4ead5") if admiral else ink)
	result.set_stylebox("hover", "PopupMenu", box(Color("715333") if royal else Color("37616c"), edge, 4, 0))
	result.set_color("font_hover_color", "PopupMenu", Color("fff4dc"))


static func _apply_studio_palette(result: Theme) -> void:
	result.set_constant("studio", "GamePalette", 1)
	var ink := Color("243653")
	result.set_color("ink", "GamePalette", ink)
	result.set_color("font_color", "Label", ink)
	result.set_color("default_color", "RichTextLabel", ink)
	for type in ["Button", "OptionButton"]:
		result.set_color("font_focus_color", type, ink)
		for state in ["normal", "hover", "pressed"]:
			var fill := Color("fff1d8").lightened(0.04) if state == "hover" else Color("ebd5af") if state == "pressed" else Color("f8e6c4")
			var style := box(fill, Color("a77c49"), 9, 2)
			style.shadow_color = Color("4b2e1966")
			style.shadow_size = 2
			style.shadow_offset = Vector2(0, 3)
			result.set_stylebox(state, type, style)
			result.set_color("font_" + ("color" if state == "normal" else state + "_color"), type, ink)
	result.set_color("font_color", "LineEdit", ink)
	result.set_color("font_placeholder_color", "LineEdit", Color("756149"))


static func _apply_garden_palette(result: Theme) -> void:
	result.set_constant("garden", "GamePalette", 1)
	result.set_color("status", "GamePalette", Color("754525"))
	var divider := StyleBoxLine.new()
	divider.color = Color("b68c55")
	divider.thickness = 1
	divider.set_content_margin(SIDE_TOP, 4)
	divider.set_content_margin(SIDE_BOTTOM, 4)
	result.set_stylebox("separator", "HSeparator", divider)
	for type in ["Button", "OptionButton", "GamePrimaryButton"]:
		for state in ["normal", "hover", "pressed", "disabled"]:
			var style: StyleBox = box(DISABLED_FILL, DISABLED_EDGE, 12, 2) if state == "disabled" else carved_surface(type == "GamePrimaryButton")
			if style is StyleBoxTexture:
				style.modulate_color = Color(1.12, 1.12, 1.12) if state == "hover" else Color(.88, .88, .88) if state == "pressed" else Color.WHITE
			result.set_stylebox(state, type, style)
		result.set_constant("h_separation", type, 8)
		result.set_constant("icon_max_width", type, 28)
		result.set_color("icon_disabled_color", type, Color("777c84"))


static func carved_surface(primary := false) -> StyleBoxTexture:
	var style := surface("button-carved-primary" if primary else "button-carved")
	for side in [SIDE_LEFT, SIDE_RIGHT]:
		style.set_texture_margin(side, 20)
		style.set_content_margin(side, 14)
	for side in [SIDE_TOP, SIDE_BOTTOM]:
		style.set_texture_margin(side, 20)
		style.set_content_margin(side, 12)
	return style


# Shared icons and dimensions for illustrated board decisions. Disabled actions
# retain the theme's opaque grey surface instead of tinting the wood artwork.
static func illustrated_control(button: Button, icon: Texture2D, primary := false, compact := false, roomy := false) -> void:
	button.icon = icon
	button.expand_icon = true
	action(button, primary)
	fit_illustrated_control(button, compact, roomy)
	button.set_meta("game_control_icon", icon)
	button.set_meta("game_disabled_icon", _grey_icon(icon))
	set_illustrated_control_disabled(button, button.disabled)


static func fit_illustrated_control(button: Button, compact := false, roomy := false) -> void:
	button.set_meta("game_roomy_control", roomy)
	button.add_theme_constant_override("icon_max_width", (18 if compact else 24) if roomy else (22 if compact else 32))
	button.add_theme_constant_override("h_separation", 6 if compact else 8)
	button.add_theme_font_size_override("font_size", (12 if compact else 14) if roomy else (13 if compact else 16))
	var minimum_width := button.get_theme_font("font").get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 56 if compact else 144.0
	button.custom_minimum_size = Vector2(minimum_width + (16 if roomy else 0), (60 if compact else 76) if roomy else (52 if compact else 68))


static func set_illustrated_control_disabled(button: Button, disabled: bool) -> void:
	button.disabled = disabled
	if button.has_meta("game_control_icon"):
		button.icon = button.get_meta("game_disabled_icon" if disabled else "game_control_icon")


static func _grey_icon(icon: Texture2D) -> Texture2D:
	if icon == null:
		return null
	var key := icon.get_instance_id()
	if not _disabled_icons.has(key):
		var grey := icon.get_image().duplicate() as Image
		if grey.is_compressed():
			grey.decompress()
		grey.convert(Image.FORMAT_RGBA8)
		for y in grey.get_height():
			for x in grey.get_width():
				var pixel := grey.get_pixel(x, y)
				var value := pixel.r * 0.2126 + pixel.g * 0.7152 + pixel.b * 0.0722
				grey.set_pixel(x, y, Color(value, value, value, pixel.a))
		_disabled_icons[key] = ImageTexture.create_from_image(grey)
	return _disabled_icons[key]


# Semantic result surfaces can be used by any game, independently of its palette.
static func result_colors(tone: String) -> Dictionary:
	if tone == "danger":
		return {"fill": Color("250e1bf7"), "edge": Color("df4e69"), "ink": Color("ffe6eb"), "accent": RED, "shade": Color("12050cf5")}
	return {"fill": Color("092936f7"), "edge": Color("44d7c6"), "ink": Color("defbf7"), "accent": Color("6cf4de"), "shade": Color("031722f5")}

static func action(button: Button, primary := true) -> void:
	if button.get_theme_constant("naval", "GamePalette") == 1:
		button.theme_type_variation = "GamePrimaryButton" if primary else "Button"
		button.custom_minimum_size.y = 44
		return
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style: StyleBox = box(DISABLED_FILL, DISABLED_EDGE, 16, 2) if state == "disabled" else surface("green" if primary else "gold")
		if style is StyleBoxTexture: style.modulate_color = Color("ffffff") if state != "hover" else Color(1.1, 1.1, 1.1)
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_disabled_color", DISABLED_INK)
	button.add_theme_font_size_override("font_size", 23)
	button.custom_minimum_size.y = 52


# Fit ordinary themed controls into small artwork panels; retain their palette.
# Call with false to restore their original size when the panel wraps on phones.
static func confirm_control(button: Button) -> void:
	# Semantic confirmation keeps the current theme surface and disabled palette.
	for key in ["font_color","font_hover_color","font_pressed_color"]: button.add_theme_color_override(key,Color("97e891"))
	button.add_theme_font_size_override("font_size",28); button.custom_minimum_size = Vector2(56,44)

static func compact_control(button: BaseButton, enabled := true) -> void:
	if not button.has_meta("game_regular_control"):
		var styles: Dictionary = {}
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			styles[state] = button.get_theme_stylebox(state)
		button.set_meta("game_regular_control", {"styles": styles, "font_size": button.get_theme_font_size("font_size"), "minimum": button.custom_minimum_size})
	if button.get_meta("game_compact_control", false) == enabled:
		return
	button.set_meta("game_compact_control", enabled)
	var regular: Dictionary = button.get_meta("game_regular_control")
	for state in regular.styles:
		var style: StyleBox = regular.styles[state].duplicate() if enabled else regular.styles[state]
		if enabled:
			if style is StyleBoxTexture:
				if style.texture.resource_path.get_file().begins_with("button-carved"):
					for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
						style.set_texture_margin(side, 20); style.set_content_margin(side, 8 if side in [SIDE_LEFT, SIDE_RIGHT] else 4)
					button.add_theme_stylebox_override(state, style)
					continue
				# Large action artwork cannot shrink its rounded caps to 28 pixels.
				var primary: bool = style.texture.resource_path.get_file().get_basename() == "green"
				style = box(Color("88df29") if primary else Color("ffd149"), Color("287a18") if primary else Color("b96917"), 10, 2)
				if state == "hover":
					style.bg_color = style.bg_color.lightened(0.12)
				style.shadow_size = 2
				style.shadow_offset = Vector2(0, 2)
			style.content_margin_left = 8
			style.content_margin_right = 8
			style.content_margin_top = 4
			style.content_margin_bottom = 4
		button.add_theme_stylebox_override(state, style)
	button.add_theme_font_size_override("font_size", 12 if enabled else regular.font_size)
	button.custom_minimum_size = Vector2(0, 28) if enabled else regular.minimum


# Optional semantic rule colors, retaining shared control geometry and focus.
# Call after compact_control and when restoring a toggle without its signal.
static func toggle_state(button: Button, enabled: bool) -> void:
	var fill := Color("b6e89a") if enabled else Color("ffb6b9")
	var edge := Color("247a28") if enabled else Color("a52b39")
	var ink := Color("153c19") if enabled else Color("681520")
	for state in ["normal", "hover", "pressed", "disabled"]:
		var current := button.get_theme_stylebox(state)
		var style: StyleBoxFlat = current.duplicate() if current is StyleBoxFlat else box(fill, edge, 10, 2)
		style.bg_color = fill.lightened(.10) if state == "hover" else fill.darkened(.06) if state == "pressed" else fill
		style.border_color = edge
		button.add_theme_stylebox_override(state, style)
		button.add_theme_color_override("font_" + ("color" if state == "normal" else state + "_color"), ink)


# Reserve every label state and keep grouped controls equal as toggles change.
# Call after compact_control/action have applied the final shared styles.
static func equal_control_sizes(buttons: Array[Button]) -> void:
	var minimum := Vector2.ZERO
	for button in buttons:
		var bounds := button.get_combined_minimum_size()
		var font := button.get_theme_font("font")
		var font_size := button.get_theme_font_size("font_size")
		var current_width := font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		for label in button.get_meta("game_control_labels", [button.text]):
			var label_width := font.get_string_size(str(label), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			minimum = minimum.max(Vector2(bounds.x + ceilf(maxf(0, label_width - current_width)), bounds.y))
	for button in buttons:
		button.custom_minimum_size = minimum


static func tile(button: Button) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := surface("tile")
		style.modulate_color = Color(1.05, 1.05, 1.05) if state == "hover" else Color.WHITE
		button.add_theme_stylebox_override(state, style)
	button.add_theme_stylebox_override("focus", box(Color.TRANSPARENT, Color("006dba"), 17, 4))
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_constant_override("icon_max_width", 100)
	for state in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_color_override("icon_" + ("normal_color" if state == "normal" else state + "_color"), Color.WHITE)


static func highlight_tile(button: Button, winning: bool) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, surface("gold" if winning else "tile"))
