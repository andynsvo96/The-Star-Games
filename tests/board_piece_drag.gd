extends SceneTree

var checks := 0
var failures := 0
var revision := 0
var enabled := true
var drops := 0
var clicks := 0
var drag: GamePieceDrag


func _init() -> void:
	call_deferred("_run")


func check(ok: bool, caption: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + caption)


func mouse(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point; event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed
	root.push_input(event, true)


func motion(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point; event.global_position = point
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(event, true)


func _run() -> void:
	var surface := Control.new(); root.add_child(surface); surface.size = Vector2(300,150)
	var buttons: Array[Button] = []
	for cell in 2:
		var button := Button.new(); surface.add_child(button)
		button.position = Vector2(20 + 140 * cell,20); button.size = Vector2(64,64)
		button.text = "A" if cell == 0 else ""
		button.pressed.connect(func() -> void: if not drag.blocks_click(): clicks += 1)
		buttons.append(button)
	drag = GamePieceDrag.new(); root.add_child(drag)
	drag.configure(surface, {"hit_test":func(point: Vector2) -> int: return 0 if buttons[0].get_global_rect().has_point(point) else 1 if buttons[1].get_global_rect().has_point(point) else -1, "can_start":func(cell: int) -> bool: return enabled and cell == 0, "revision":func() -> int: return revision, "make_preview":func(_cell: int) -> Control: var picture := Label.new(); picture.text = "A"; picture.size = Vector2(32,32); return picture, "drop":func(from: int, to: int) -> void: if from == 0 and to == 1: drops += 1; revision += 1})
	for frame in 4: await process_frame
	var from := buttons[0].get_global_rect().get_center()
	var to := buttons[1].get_global_rect().get_center()
	mouse(from,true); mouse(from,false)
	for frame in 2: await process_frame
	check(clicks == 1 and drops == 0, "A normal click retains the existing Button action")
	mouse(from,true); motion(to)
	check(drag.dragging and is_instance_valid(drag.preview) and surface.is_ancestor_of(drag.preview), "A deliberate drag lifts an inner preview below modal layers")
	mouse(to,false)
	for frame in 2: await process_frame
	check(drops == 1 and clicks == 1 and not drag.dragging, "Dropping submits one move without a second click")
	mouse(from,true); motion(Vector2(400,200)); mouse(Vector2(400,200),false)
	for frame in 2: await process_frame
	check(drops == 1 and not drag.dragging, "An outside drop cancels without submitting")
	mouse(from,true); motion(to); revision += 1
	await process_frame; mouse(to,false)
	check(drops == 1 and not drag.dragging, "A changed authoritative revision cancels a held piece")
	mouse(from,true); motion(to); enabled = false
	await process_frame; mouse(to,false)
	check(drops == 1 and not drag.dragging, "Pause or lost eligibility cancels a held piece")
	enabled = true
	drag.begin(from); drag.move_pointer(to); surface.size.x += 1
	await process_frame
	check(not drag.dragging, "Board reflow cancels a held piece")
	for frame in 2: await process_frame
	var touch := InputEventScreenTouch.new(); touch.index = 0; touch.position = from; touch.pressed = true
	root.push_input(touch,true)
	var finger := InputEventScreenDrag.new(); finger.index = 0; finger.position = to
	root.push_input(finger,true)
	check(drag.dragging, "Touch movement lifts a preview")
	touch = InputEventScreenTouch.new(); touch.index = 0; touch.position = to
	root.push_input(touch,true)
	check(drops == 2 and not drag.dragging, "Touch release submits one drop")
	drag.begin(from,0); drag.move_pointer(to)
	touch = InputEventScreenTouch.new(); touch.index = 0; touch.position = to; touch.canceled = true
	root.push_input(touch,true)
	check(drops == 2 and not drag.dragging, "A canceled touch cannot submit a drop")
	drag.queue_free(); surface.queue_free(); await process_frame
	print("Board piece drag: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
