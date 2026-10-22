@tool
extends EditorPlugin

var exporter := preload("res://addons/raw_media/export.gd").new()


func _enter_tree() -> void:
	add_export_plugin(exporter)


func _exit_tree() -> void:
	remove_export_plugin(exporter)
