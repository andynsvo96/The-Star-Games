extends SceneTree

var checks := 0
var failures := 0
var taps: Array[Vector2] = []

func _init() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: "+message)

func touch(camera: GameBoardCamera, index: int, point: Vector2, pressed: bool, canceled := false) -> void:
	var event := InputEventScreenTouch.new(); event.index = index; event.pressed = pressed; event.canceled = canceled
	camera.handle_input(event,point)

func drag(camera: GameBoardCamera, index: int, point: Vector2) -> void:
	var event := InputEventScreenDrag.new(); event.index = index; camera.handle_input(event,point)

func _run() -> void:
	var camera := GameBoardCamera.new(); camera.viewport_size = Vector2(400,300); camera.tapped.connect(func(point: Vector2) -> void: taps.append(point))
	var anchor := Vector2(120,90); var logical := anchor
	camera.zoom_at(2,anchor); check(camera.project(logical).is_equal_approx(anchor),"Zoom keeps the point under the pointer")
	camera.zoom_at(100,anchor); check(camera.zoom == 4,"Magnification is bounded")
	camera.reset(); touch(camera,0,anchor,true); touch(camera,0,anchor,false); check(taps.size() == 1,"A simple tap remains available for preview")
	touch(camera,0,anchor,true); drag(camera,0,anchor+Vector2(40,20)); touch(camera,0,anchor+Vector2(40,20),false)
	check(taps.size() == 1 and camera.pan.length()>20,"Drag moves the map without issuing a tap")
	camera.reset(); touch(camera,0,Vector2(100,100),true); touch(camera,1,Vector2(200,100),true); drag(camera,1,Vector2(300,100))
	touch(camera,1,Vector2(300,100),false); touch(camera,0,Vector2(100,100),false)
	check(camera.zoom > 1 and taps.size() == 1,"Pinch zoom and both releases never issue a tap")
	touch(camera,0,anchor,true); touch(camera,0,anchor,false,true); check(taps.size() == 1,"Canceled touch cannot select a target")
	touch(camera,0,anchor,true); camera.cancel(); touch(camera,0,anchor,false); check(taps.size() == 1,"Lost focus or modal navigation clears held gestures")
	camera.reset(); touch(camera,0,Vector2(-10,-10),true); drag(camera,0,anchor); check(camera.pan == Vector2.ZERO,"Gestures starting outside the map are ignored")
	camera.set_frame(Vector2(800,600),Rect2(240,160,320,280)); camera.zoom_at(2,Vector2(300,240))
	check(camera.project(Vector2(300,240)).is_equal_approx(Vector2(300,240)),"A full-screen camera zooms around the pointer with a separate fitted area")
	camera.pan = Vector2(9000,9000); camera.set_frame(Vector2(400,700),Rect2(60,180,280,280))
	var content := Rect2(camera.focus_center()+camera.pan-camera.fit_rect.size*camera.zoom/2,camera.fit_rect.size*camera.zoom)
	check(content.intersects(Rect2(Vector2.ZERO,camera.viewport_size)),"Resizing a panned map keeps some island reachable")
	camera.reset(); camera.set_frame(Vector2(1920,1080),Rect2(500,100,920,880))
	camera.set_frame(Vector2(480,850),Rect2(500,100,920,880))
	camera.set_frame(Vector2(480,850),Rect2(40,240,400,400))
	check(camera.pan == Vector2.ZERO and camera.focus_center() == Vector2(240,440),"Transient old container bounds cannot push an unpanned island off-center after resize")
	var host_root := Control.new(); host_root.size = Vector2(800,600); root.add_child(host_root)
	var screen := GameScreen.new(); host_root.add_child(screen); screen.configure("Example map")
	var fit_anchor := Control.new(); screen.content.add_child(fit_anchor); fit_anchor.custom_minimum_size = Vector2(280,280)
	var canvas := Control.new(); screen.mount_board_canvas(canvas,fit_anchor)
	await process_frame; await process_frame
	check(canvas.get_parent() == host_root and canvas.size.is_equal_approx(host_root.size),"Shared map canvas spans its host while the anchor stays in the layout")
	check(screen.board_canvas_fit_rect(canvas).size.is_equal_approx(fit_anchor.size),"Shared camera fit follows its actual anchor")
	var overlays: Array[Control] = [fit_anchor]
	check(screen.board_canvas_input_regions(overlays).any(func(rect: Rect2) -> bool: return rect.has_point(fit_anchor.get_global_rect().get_center())),"Explicit UI rectangles remain protected from map gestures")
	var inspector := screen.add_phase_dialog(true,false,true)
	screen.set_phase_dialog_header(inspector,"Player <literal>",{"value":3,"label":"Session wins"})
	check(inspector.heading.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT and inspector.header_value.text == "3" and inspector.header_metric.visible,"Inspector headers separate literal names and an independent public metric")
	screen.set_phase_dialog_header(inspector,"Ordinary dialog")
	check(not inspector.header_metric.visible and inspector.heading.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER,"Ordinary dialogs retain their centered heading")
	host_root.queue_free(); await process_frame
	var row := GamePlayerRow.new(); root.add_child(row)
	row.set_player({"display_name":"Player [literal] <name>","color":"#000000"},[{"label":"Public cards","value":5}],true)
	check(row.name_label.text == "Player [literal] <name>" and row.accessibility_name.contains("Public cards: 5"),"Public rows preserve literal names and accessible counter meanings")
	row.compact = true; row._layout(); check(row.custom_minimum_size.y >= 44 and row.custom_minimum_size.x < 110,"Compact rows preserve touch targets without widening a phone")
	var metrics: Array = []
	for index in 6: metrics.append({"label":"Public stat %d" % index,"caption":"Stat %d" % index,"value":index})
	row.detailed = true; row.show_labels = true; row.set_player({"display_name":"Player <literal>","color":"#ffffff"},metrics,true); row.size = row.custom_minimum_size; row._layout()
	check(row.values.all(func(label: Label) -> bool: return label.visible) and row.captions.all(func(label: Label) -> bool: return label.visible),"Detailed compact rows retain all six labelled public counters")
	for label in row.values+row.captions: check(Rect2(Vector2.ZERO,row.size).encloses(label.get_rect()),"Detailed stat text stays inside its player card")
	var grid := GameStatGrid.new(); root.add_child(grid); grid.set_metrics(metrics); grid.size.x = 430; grid._fit(); await process_frame
	check(grid.columns == 3 and grid.values.size() == 6,"Public inspectors use a compact three-column icon grid")
	var held := grid.values[0]; metrics[0].value = 9; grid.set_metrics(metrics)
	check(grid.values[0] == held and held.text == "9","Stat refresh preserves existing labels and updates the authoritative value")
	row.grid_counters = true; row.detailed = false; row.compact = true; metrics[0].value = 120
	row.set_player({"display_name":"Very long literal <player> name","color":"#000000"},metrics,true,{"value":10,"label":"Victory points"}); row.size = row.custom_minimum_size; row._layout()
	check(row.headline_value.text == "10" and row.name_label.get_rect().end.x < row.headline_value.position.x-14,"Headline point counters never bleed into a long name")
	for label: Label in row.values: check(Rect2(Vector2.ZERO,row.size).encloses(label.get_rect()),"Compact icon counts stay inside the roster card, including three-digit amounts")
	var strip := GameTurnStrip.new(); strip.tracked = true; root.add_child(strip); strip.size = Vector2(400,52)
	strip.set_players([{"display_name":"A <literal>","color":"#000000"},{"display_name":"B","color":"#ffffff"}],0); strip.set_actions(["Built a house","Rolled 6"])
	for unused in 4: await process_frame
	for label: Label in strip.get_children():
		var caption: Label = label.get_child(0)
		check(caption.visible and absf(caption.get_global_rect().get_center().x-label.get_global_rect().get_center().x)<1 and strip.get_global_rect().encloses(caption.get_global_rect()),"Turn actions remain inside the header and centered on their own identity")
	strip.queue_free()
	for paper in [false,true]:
		var log := GameActivityLog.new(); log.paper = paper; log.theme = GameLook.paper_theme(GameLook.make_theme("royal")); root.add_child(log); log.set_entries([{"id":1,"text":"Player <literal> rolled 8."}],true)
		var color: Color = log.entries.get_child(0).get_theme_color("font_color"); var background: StyleBoxFlat = log.get_theme_stylebox("panel")
		check(GameLook.text_contrast(color,background.bg_color) >= 4.5,"History ink remains readable when inheriting an opposite-color theme")
		log.queue_free()
	grid.queue_free()
	var compact_log := GameActivityLog.new(); compact_log.maximum_entries = 5; compact_log.separators = true; compact_log.expandable = true; root.add_child(compact_log)
	var log_items: Array = []
	for index in 8: log_items.append({"id":index,"text":"Literal <player> %d" % index})
	compact_log.set_entries(log_items,true)
	check(compact_log.entries.get_child_count() == 9 and compact_log.entries.get_child(1) is HSeparator,"Compact history limits entries and separates each pair")
	compact_log.set_entries([{"id":9,"text":"Literal <player> with an icon","parts":[{"text":"Literal <player> "},{"texture":RuntimeAssets.texture("res://ui/playful/stat-route.svg")}]}],true)
	check(compact_log.entries.get_child(0) is RichTextLabel and compact_log.entries.get_child(0).accessibility_name == "Literal <player> with an icon","Icon history retains literal accessible meaning")
	compact_log.set_entries([{"id":10,"text":"Literal [color=red]<name> acted","parts":[{"text":"Literal [color=red]<name>","color":Color("58d6ff")},{"text":" acted"}]}],true)
	var colored: RichTextLabel = compact_log.entries.get_child(0)
	check(colored.get_parsed_text() == "Literal [color=red]<name> acted" and not colored.bbcode_enabled,"Colored activity parts keep names literal without interpreting markup")
	var cost := GameCostRow.new(); root.add_child(cost); cost.set_items([{"texture":RuntimeAssets.texture("res://ui/playful/table-cards.svg"),"label":"Wood","available":false}])
	var sectioned_log := GameActivityLog.new(); sectioned_log.sectioned = true; sectioned_log.expandable = true; root.add_child(sectioned_log); sectioned_log.size = Vector2(280,220); sectioned_log.heading.text = "Recent Activity"; sectioned_log.set_entries(log_items,true)
	var expands: Array = []; sectioned_log.expand_requested.connect(func() -> void: expands.append(true)); sectioned_log.show_all.pressed.emit()
	for unused in 3: await process_frame
	check(expands.size() == 1 and sectioned_log.show_all.size.y >= 44 and sectioned_log.body_font != null,"Sectioned activity supplies compact type and an accessible Show All action")
	check(sectioned_log.heading.get_global_rect().end.x <= sectioned_log.show_all.get_global_rect().position.x,"Section heading and Show All reserve separate space")
	sectioned_log.queue_free()
	check(cost.get_child(0).material is ShaderMaterial and cost.get_child(0).accessibility_name == "Wood missing","Missing materials desaturate and remain accessible")
	cost.set_items([{"texture":RuntimeAssets.texture("res://ui/playful/table-cards.svg"),"label":"Wood","owned":2,"required":3,"available":false}])
	check(cost.get_child(0).accessibility_name == "Wood: have 2, need 3" and cost.find_children("*","Label",true,false).any(func(label: Label) -> bool: return label.text == "Need 1 more"),"Counted materials preserve exact owned, required and missing quantities")
	cost.highlight_counts = true; cost.dark = true; cost.set_items([{"texture":RuntimeAssets.texture("res://ui/playful/table-cards.svg"),"label":"Ready","owned":2,"required":2,"available":true},{"texture":RuntimeAssets.texture("res://ui/playful/table-cards.svg"),"label":"Missing","owned":1,"required":3,"available":false}])
	var count_labels: Array = cost.find_children("*","Label",true,false).filter(func(label: Label) -> bool: return label.text.contains(" / "))
	check(count_labels[0].get_theme_color("font_color") == Color("91ffc8") and count_labels[1].get_theme_color("font_color") == Color("ff98ac"),"Opt-in material counts distinguish ready and missing quantities")
	var held_flight := {"delay":0.0,"duration":1.5,"hold":.25}
	check(GameCardMotion.progress(held_flight,.2) == 0 and GameCardMotion.progress(held_flight,1.5) == 1,"Optional card hold stays at its source and still finishes at the authoritative deadline")
	check(is_equal_approx(GameCardMotion.travel(Rect2(0,0,10,10),Rect2(100,0,10,10),.5,"smooth").position.x,50),"Smooth card travel remains halfway across at its midpoint")
	row.set_player({"display_name":"Long name","color":"#000000"},metrics,true,{"value":"5 +2","label":"Points plus cards"}); row._layout()
	check(row.name_label.get_rect().end.x < row.headline_value.position.x-14,"Headline bonus suffix reserves its full width")
	row.dark = true; row.set_player({"display_name":"Dark identity","color":"#000000"},metrics,true)
	check(GameLook.text_contrast(row.name_label.get_theme_color("font_color"),Color("061d30")) >= 4.5 and row.values[0].get_theme_color("font_color") == GameLook.CREAM,"Dark player rows keep black identities and counters readable")
	var dark_grid := GameStatGrid.new(); dark_grid.dark = true; root.add_child(dark_grid); dark_grid.set_metrics(metrics)
	var dark_surface: StyleBoxFlat = dark_grid.get_child(0).get_theme_stylebox("panel")
	check(GameLook.text_contrast(dark_grid.values[0].get_theme_color("font_color"),dark_surface.bg_color) >= 4.5,"Dark inspector metrics retain accessible contrast")
	dark_grid.queue_free()
	cost.queue_free(); compact_log.queue_free()
	row.queue_free(); await process_frame
	print("Board camera: %d checks, %d failures" % [checks,failures]); quit(0 if failures == 0 else 1)
