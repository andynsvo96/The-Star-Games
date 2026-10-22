class_name GameThemePreview
extends Control

# Shared visual sample for cosmetic packs; it never starts a game or pins a pack.
var manager: ThemePacks
var pack: Dictionary = {}
var phone := false
var reduced_motion := false
var background: Control
var presentation := "card-table"


func configure(store: ThemePacks, draft: Dictionary, portrait := false, reduced := false, style := "card-table") -> void:
	manager = store; pack = draft.duplicate(true); phone = portrait; reduced_motion = reduced
	presentation = style


func _sheet(active := false) -> StyleBoxFlat:
	return GameLook.modern_table_sheet(active) if presentation == "modern-table" else GameLook.card_table_sheet(active)


func _ink() -> Color:
	return Color("edf8ff") if presentation == "modern-table" else Color("293a30")


func _ready() -> void:
	custom_minimum_size = Vector2(260,410 if phone else 340)
	resized.connect(queue_redraw)
	if manager == null: return
	for slot in manager.slots:
		if slot.kind == "background":
			background = preload("res://scripts/game_background.gd").new(); background.source_stem = _source(slot).get_basename(); background.reduced_motion = reduced_motion; background.show_behind_parent = true; add_child(background); background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); break


func _source(slot: Dictionary) -> String:
	var relative: String = pack.assets.get(slot.id, slot.path)
	var external := RuntimeAssets.root_folder().path_join(relative)
	return external if FileAccess.file_exists(external) else "res://" + relative


func _face(slot: Dictionary, bounds: Rect2) -> void:
	var data: Dictionary = slot.preview.duplicate(true)
	data.display_name = manager.display_name(slot.id, slot.label, pack)
	GameCard.paint(self,bounds,data,GameCard.artwork(_source(slot)),Color(data.get("color","#17594d")))


func _draw() -> void:
	if manager == null: return
	var faces: Array = manager.slots.filter(func(slot: Dictionary) -> bool: return slot.has("preview"))
	if faces.is_empty(): return
	if phone:
		var width := minf(300,size.x - 16); var left := (size.x-width)/2
		draw_style_box(_sheet(),Rect2(left,8,width,35))
		draw_string(ThemeDB.fallback_font,Vector2(left+12,31),"Your portfolio · Draft" if manager.preview_kind == "portfolio" else "Your turn · 3 plays left",HORIZONTAL_ALIGNMENT_LEFT,width-24,15,_ink())
		draw_style_box(_sheet(),Rect2(left,52,width,130))
		for index in 3: _face(faces[index],Rect2(left+12+index*(width-86)/2,63,70,105))
		_face(faces[mini(40,faces.size()-1)],Rect2(size.x/2-25,193,50,75))
		for index in 3: _face(faces[mini(39+index,faces.size()-1)],Rect2(left+14+index*(width-89)/2,280,75,112))
	else:
		var width := (size.x-32)/2; var gap := 90.0; var height := (size.y-36-gap)/2
		for seat in 4:
			var origin := Vector2(8+(seat%2)*(width+16),8+(seat/2)*(height+16+gap))
			draw_style_box(_sheet(seat==0),Rect2(origin,Vector2(width,height)))
			var caption := ("Player %d · Sample properties" if manager.preview_kind == "portfolio" else "Player %d · Bank $4 · 1/3 sets") % (seat+1)
			draw_string(ThemeDB.fallback_font,origin+Vector2(10,23),caption,HORIZONTAL_ALIGNMENT_LEFT,width-20,12,_ink())
			var card_h := minf(104,height-42); var card_w := card_h*.68
			for index in 3: _face(faces[(seat*3+index)%faces.size()],Rect2(origin+Vector2(10+index*(card_w+5),33),Vector2(card_w,card_h)))
		_face(faces[mini(40,faces.size()-1)],Rect2(size.x/2+8,height+24,50,75))
		for slot in manager.slots:
			if slot.id == "back": GameCard.paint(self,Rect2(size.x/2-62,height+24,50,75),{"back":true},RuntimeAssets.texture(_source(slot)),Color("173c45")); break


func _exit_tree() -> void:
	if is_instance_valid(background): background.set_active(false)
