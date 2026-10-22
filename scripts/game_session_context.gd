class_name GameSessionContext
extends RefCounted

var game_id := ""
var players: Array = []
var solo_profile: Dictionary = {}
var is_party_game := false
var reduced_motion := false
var game_choices: Array = []


func _init(id := "", connected_players: Array = [], selected_profile: Dictionary = {}, party := false) -> void:
	game_id = id
	players = connected_players.duplicate(true)
	solo_profile = selected_profile.duplicate(true)
	is_party_game = party


func player_color(player_id: String) -> Color:
	for player in players:
		if player.get("id", "") == player_id:
			return Color(str(player.get("color", "#58d6ff")))
	return Color(str(solo_profile.get("color", "#58d6ff")))
