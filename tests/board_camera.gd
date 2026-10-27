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
	var host_root := Control.new(); host_root.size = Vector2(800,600); root.add_child(host_root)
	var screen := GameScreen.new(); host_root.add_child(screen); screen.configure("Example map")
	var fit_anchor := Control.new(); screen.content.add_child(fit_anchor); fit_anchor.custom_minimum_size = Vector2(280,280)
	var canvas := Control.new(); screen.mount_board_canvas(canvas,fit_anchor)
	await process_frame; await process_frame
	check(canvas.get_parent() == host_root and canvas.size.is_equal_approx(host_root.size),"Shared map canvas spans its host while the anchor stays in the layout")
	check(screen.board_canvas_fit_rect(canvas).size.is_equal_approx(fit_anchor.size),"Shared camera fit follows its actual anchor")
	var overlays: Array[Control] = [fit_anchor]
	check(screen.board_canvas_input_regions(overlays).any(func(rect: Rect2) -> bool: return rect.has_point(fit_anchor.get_global_rect().get_center())),"Explicit UI rectangles remain protected from map gestures")
	host_root.queue_free(); await process_frame
	var row := GamePlayerRow.new(); root.add_child(row)
	row.set_player({"display_name":"Player [literal] <name>","color":"#000000"},[{"label":"Public cards","value":5}],true)
	check(row.name_label.text == "Player [literal] <name>" and row.accessibility_name.contains("Public cards: 5"),"Public rows preserve literal names and accessible counter meanings")
	row.compact = true; row._layout(); check(row.custom_minimum_size.y >= 44 and row.custom_minimum_size.x < 110,"Compact rows preserve touch targets without widening a phone")
	row.queue_free(); await process_frame
	print("Board camera: %d checks, %d failures" % [checks,failures]); quit(0 if failures == 0 else 1)
