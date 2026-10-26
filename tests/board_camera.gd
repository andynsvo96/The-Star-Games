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
	var row := GamePlayerRow.new(); root.add_child(row)
	row.set_player({"display_name":"Player [literal] <name>","color":"#000000"},[{"label":"Public cards","value":5}],true)
	check(row.name_label.text == "Player [literal] <name>" and row.accessibility_name.contains("Public cards: 5"),"Public rows preserve literal names and accessible counter meanings")
	row.compact = true; row._layout(); check(row.custom_minimum_size.y >= 44 and row.custom_minimum_size.x < 110,"Compact rows preserve touch targets without widening a phone")
	row.queue_free(); await process_frame
	print("Board camera: %d checks, %d failures" % [checks,failures]); quit(0 if failures == 0 else 1)
