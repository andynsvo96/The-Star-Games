class_name GameRentSummary
extends HFlowContainer

# Public presentation only. Modules supply the authoritative base and bonus.
class Building extends Control:
	var kind := "house"
	func _draw() -> void:
		GameLook.draw_table_building(self, Rect2(Vector2.ZERO, size), kind)

func set_rent(caption: String, base: int, bonus: int, buildings: Array) -> void:
	for child in get_children(): remove_child(child); child.queue_free()
	add_theme_constant_override("h_separation", 6); add_theme_constant_override("v_separation", 4)
	var label := Label.new(); label.text = "%s rent $%d" % [caption, base]; label.add_theme_font_size_override("font_size", 16); add_child(label)
	if bonus > 0:
		var extra := Label.new(); extra.text = "+ $%d" % bonus; extra.add_theme_color_override("font_color", Color("8fefae")); extra.add_theme_font_size_override("font_size", 16); add_child(extra)
	for kind in buildings:
		var icon := Building.new(); icon.kind = str(kind); icon.custom_minimum_size = Vector2(24, 24); icon.accessibility_name = str(kind).capitalize(); add_child(icon)
	accessibility_name = "%s rent $%d%s" % [caption, base, " plus $%d in upgrades" % bonus if bonus > 0 else ""]
