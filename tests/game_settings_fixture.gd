extends GameSettingsStore

# Each fixture has a fresh directory without touching the host's preferences.
func _init() -> void:
	directory = "res://.test_data/game-settings-fixtures/%d-%d/%d" % [OS.get_process_id(), Time.get_ticks_usec(), get_instance_id()]
