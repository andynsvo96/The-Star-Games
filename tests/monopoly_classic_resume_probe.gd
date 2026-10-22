extends SceneTree

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1: quit(1); return
	var host = load("res://Games/monopoly-classic/host/main.tscn").instantiate()
	host.settings_store = preload("res://tests/game_settings_fixture.gd").new(); host.saved_game.path = args[0]; root.add_child(host)
	var players := [{"id": "alice", "display_name": "Alice", "color": "#e53935", "pose": 0}, {"id": "bob", "display_name": "Bob", "color": "#2463eb", "pose": 1}]
	var context := GameSessionContext.new("monopoly-classic", players, {"id": "host", "display_name": "Host", "color": "#08a750", "pose": 2}, true); context.reduced_motion = true
	host.initialize_session(context); host.start_game(); host.set_process(false)
	var waiting: bool = host.awaiting_resume
	host.resume_game()
	var records: Array = []
	host.result_reported.connect(func(id: String, won: bool) -> void: records.append([id, won]))
	var result := {"resumed": waiting and not host.awaiting_resume, "phase": host.rules.s.get("phase", ""), "practice": host.practice, "round_id": host.round_id, "turn": host.turn_remaining, "response": host.response_remaining}
	host.rules.finish("time"); host._record_results(); result.records = records.size()
	var file := FileAccess.open(args[0] + ".probe.json", FileAccess.WRITE); file.store_string(JSON.stringify(result)); file.close()
	host.shutdown_game(); host.queue_free(); await process_frame
	quit()
