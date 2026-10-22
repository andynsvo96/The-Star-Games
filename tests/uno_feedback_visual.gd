extends SceneTree

const Host = preload("res://Games/uno/host/main.tscn")
var failures := 0
var checks := 0
var output := "res://.test_data/uno-feedback/"


func _init() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)


func capture(name: String) -> void:
	for frame in 6: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output + name + ".png")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	for spectator in [false,true]:
		for dimensions in [Vector2i(1280,720),Vector2i(390,844),Vector2i(844,390)]:
			root.min_size = Vector2i(1,1)
			root.content_scale_size = dimensions
			root.size = dimensions
			var players: Array = []
			if spectator:
				for seat in 6: players.append({"id":"phone-%d" % seat,"display_name":"Player %d" % seat,"color":"#2463eb"})
			var host := Host.instantiate()
			root.add_child(host)
			var context := GameSessionContext.new("uno",players,{"id":"host","display_name":"Host","color":"#e53935"},spectator)
			context.reduced_motion = true
			host.settings_store = preload("res://tests/game_settings_fixture.gd").new()
			host.initialize_session(context)
			host.start_game()
			for timer in [host.ai_timer,host.catch_timer,host.jump_timer,host.auto_timer]: timer.process_mode = Node.PROCESS_MODE_DISABLED
			host.rules.turn = 0
			host.rules.phase = "play"
			host.rules.pending_draw = 0
			host.rules.drawn = -1
			host.rules.color = "red"
			host.rules.discard = [0]
			host.rules.hands[0] = [9,79]
			for seat in range(1,host.seats.size()): host.rules.hands[seat] = [seat + 10,seat + 30,seat + 60]
			host.rules.deck = range(108).filter(func(id: int) -> bool: return not host.rules.discard.has(id) and not host.rules.hands.any(func(hand: Array) -> bool: return hand.has(id)))
			host.rules.revision += 1
			host._publish()
			await capture("%s-%dx%d-before" % ["table" if spectator else "owner",dimensions.x,dimensions.y])
			var board: Rect2 = host.table.get_global_rect()
			check(host.actions.draw.visible == not spectator, "DRAW is visible only on the solo host's controls")
			host.session.reduced_motion = false
			host._action(0,{"action":"uno","revision":host.rules.revision})
			await capture("%s-%dx%d-pop" % ["table" if spectator else "owner",dimensions.x,dimensions.y])
			host._action(0,{"action":"play","card":9,"revision":host.rules.revision})
			await create_timer(.95).timeout
			await capture("%s-%dx%d-hover" % ["table" if spectator else "owner",dimensions.x,dimensions.y])
			check(host.actions.draw.visible == not spectator and host.actions.draw.disabled and host.table.get_global_rect().is_equal_approx(board), "Changing turns greys out DRAW without shifting the board")
			var logos: Array = host.table.effects.filter(func(effect: Dictionary) -> bool: return effect.kind == "uno" and effect.seat == 0)
			check(logos.size() == 1 and host._snapshot(-1).uno_players[0] and not host.sounds.has("uno"), "A silent persistent UNO logo follows the caller's last card")
			if not logos.is_empty():
				var scale: float = host.table.size.x / 1000.0
				var first: Rect2 = host.table._uno_logo_rect(logos[0],scale)
				await create_timer(.35).timeout
				var second: Rect2 = host.table._uno_logo_rect(logos[0],scale)
				check(not first.is_equal_approx(second), "The settled host UNO gently breathes")
				check(Rect2(Vector2.ZERO,host.table.size).encloses(second), "The hovering logo fits inside the table in both orientations")
				if not spectator: check(second.end.y <= host.table.hand_hits[0].rect.position.y + 1, "Own UNO stays above the last private card")
				host.session.reduced_motion = true
				host._publish()
				first = host.table._uno_logo_rect(logos[0],scale)
				await create_timer(.3).timeout
				check(first.is_equal_approx(host.table._uno_logo_rect(logos[0],scale)), "Reduced motion keeps the UNO marker static")
				await capture("%s-%dx%d-reduced" % ["table" if spectator else "owner",dimensions.x,dimensions.y])
				host.table.state.clear()
				host._publish()
				check(host.table.effects.any(func(effect: Dictionary) -> bool: return effect.kind == "uno" and effect.age >= .75), "A fresh view restores the hovering marker without replaying its pop")
			host.rules._take(0,1)
			host.rules.revision += 1
			host._publish()
			check(not host.table.effects.any(func(effect: Dictionary) -> bool: return effect.kind == "uno"), "Drawing another card clears the host UNO marker")
			host.shutdown_game()
			host.queue_free()
			await process_frame
	await create_timer(.15).timeout
	print("UNO feedback visual: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
