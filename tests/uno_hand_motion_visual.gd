extends SceneTree

const Host = preload("res://Games/uno/host/main.tscn")
var failures := 0
var output := "res://.test_data/uno-hand-motion/"


func _init() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)


func capture(name: String) -> void:
	for frame in 6: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output + name + ".png")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	for dimensions in [Vector2i(1280,720),Vector2i(390,844),Vector2i(844,390)]:
		root.min_size = Vector2i.ONE
		root.content_scale_size = dimensions
		root.size = dimensions
		var host := Host.instantiate()
		root.add_child(host)
		var context := GameSessionContext.new("uno",[],{"id":"host","display_name":"Host","color":"#2463eb"},false)
		context.reduced_motion = true
		host.settings_store = preload("res://tests/game_settings_fixture.gd").new()
		host.initialize_session(context)
		host.start_game()
		for timer in [host.ai_timer,host.auto_timer,host.catch_timer,host.jump_timer]: timer.process_mode = Node.PROCESS_MODE_DISABLED
		host.rules.allow_seven_zero = true
		host.rules.phase = "play"
		host.rules.turn = 0
		host.rules.direction = 1
		host.rules.color = "red"
		host.rules.pending_draw = 0
		host.rules.drawn = -1
		host.rules.hands = [[0,3,5,7,9,11,13,15,19],[27,29,31],[53,55,57,59,61,63],[79,81,83,85]]
		host.rules.discard = [17]
		host.rules.revision += 1
		host._publish()
		await capture("%dx%d-before" % [dimensions.x,dimensions.y])
		var before_drag: int = host.rules.revision
		var point: Vector2 = host.table.hand_rect.get_center()
		host.table._begin_pointer(point)
		host.table._drag_pointer(point - Vector2(host.table.hand_spacing * 1.3, 0))
		check(is_equal_approx(host.table.hand_position, 1.3), "Native fan follows fractional drag distance instead of jumping three cards")
		await capture("%dx%d-drag" % [dimensions.x,dimensions.y])
		host.table._end_pointer(point - Vector2(host.table.hand_spacing * 1.3, 0))
		check(host.table.hand_start == 1 and host.rules.revision == before_drag, "Native drag snaps to a card boundary and never plays on release")
		host.table._shift_hand(-1); await capture("%dx%d-drag-reset" % [dimensions.x,dimensions.y])
		host.session.reduced_motion = false
		host._local_action({"action":"play","card":0})
		host.motion_timer.paused = true
		host.table.set_process(false)
		host.table.flight_age = .84
		host.table.queue_redraw()
		await capture("%dx%d-zero" % [dimensions.x,dimensions.y])
		var fans: Array = host.table.flights.filter(func(flight: Dictionary) -> bool: return flight.kind == "hand")
		check(fans.size() == 4 and fans.all(func(flight: Dictionary) -> bool: return is_equal_approx(flight.start,.48)), "All four native hand fans share the Zero start")
		check(host.table._visible_count(0) == 8 and host.table._transferring(0), "Outgoing eight-card fan keeps its stacks and delays the incoming hand")
		var prior: Array = host.table.flights.duplicate(true)
		host._publish()
		check(host.table.flights == prior, "Duplicate native snapshots preserve transfer timing")
		host.table.flight_age = 1.21
		host.table.queue_redraw()
		await capture("%dx%d-settled" % [dimensions.x,dimensions.y])
		check(not host.table._transferring(0) and host.table._visible_count(0) == 4, "Incoming hand appears together after the last fan settles")
		host.session.reduced_motion = true
		host._publish()
		check(host.table.flights.is_empty(), "Changing reduced motion cancels native fan movement")
		host.shutdown_game()
		host.queue_free()
		await process_frame
	await create_timer(.15).timeout
	print("UNO hand motion visual: %d failures" % failures)
	quit(1 if failures else 0)
