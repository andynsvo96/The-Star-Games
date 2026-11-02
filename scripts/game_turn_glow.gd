class_name GameTurnGlow
extends Control

var target: Control
var active := false
var reduced_motion := false
var accent := Color("ffd84c")
var age := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if not active or not is_instance_valid(target) or not target.is_visible_in_tree():
		return
	if not reduced_motion:
		age += delta
	queue_redraw()


func _draw() -> void:
	if not active or not is_instance_valid(target) or not target.is_visible_in_tree():
		return
	var bounds := get_global_transform().affine_inverse() * target.get_global_rect()
	var pulse := 0.5 if reduced_motion else (sin(age * TAU / 2.2) + 1.0) / 2.0
	GameLook.draw_turn_glow(self, bounds.grow(-5), accent, pulse)
