extends BaseGame

var screen := GameScreen.new()
var choices := GridContainer.new()
var entrance: Tween
var missing: Dictionary = {}


func _ready() -> void:
	add_child(screen); screen.configure("MONOPOLY")
	screen.use_playful_style("res://Games/monopoly/art/terrace", "royal")
	screen.add_title_art(RuntimeAssets.texture("res://Games/monopoly/art/title.svg"), 138, true)
	screen.exit_requested.connect(return_to_lobby)
	screen.status.hide(); screen.scores.hide()
	choices.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	choices.add_theme_constant_override("h_separation", 28)
	choices.add_theme_constant_override("v_separation", 24)
	screen.content.add_child(choices)
	screen.resized.connect(_queue_fit)
	screen.content_scroll.resized.connect(_queue_fit)


func initialize_session(context: GameSessionContext) -> void:
	super.initialize_session(context)
	screen.background_media.reduced_motion = context.reduced_motion
	for option in context.game_choices:
		var button := GameChoiceCard.new()
		button.caption = "CLASSIC" if option.id == "monopoly-classic" else "DEAL"
		button.accent = Color("940a0a") if option.id == "monopoly-classic" else Color("053d86")
		button.reduced_motion = context.reduced_motion
		button.disabled = not option.can_launch
		button.set_meta("allowed", bool(option.can_launch))
		if option.id == "monopoly-classic": button.illustration = RuntimeAssets.texture("res://Games/monopoly/art/classic-option.png")
		else:
			var deck: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Games/monopoly-deal/cards.json"))
			for name in ["boardwalk", "park-place", "pass-go", "money-10"]:
				button.card_faces.append(GameCard.artwork("res://Games/monopoly-deal/art/%s.svg" % name))
				var data: Dictionary = deck.cards.filter(func(card: Dictionary) -> bool: return card.key == name)[0].duplicate(true)
				data.layout = "deal"; data.currency = "USD"; button.card_data.append(data)
		button.pressed.connect(func() -> void: game_selected.emit(option.id))
		choices.add_child(button)
	_fit.call_deferred()


func start_game() -> void:
	if session.reduced_motion: return
	modulate.a = 0
	entrance = create_tween(); entrance.tween_property(self, "modulate:a", 1.0, .65)


func _queue_fit() -> void:
	# The scroll viewport settles after its owning margin container resizes.
	_fit.call_deferred()


func _fit() -> void:
	var available := screen.available_size()
	choices.columns = 1 if available.x < 650 and available.y > available.x else 2
	var area := screen.content_scroll.size
	if area.y <= 0: area = available - Vector2(48, 128)
	var header_height := 0.0
	for child in screen.content.get_children():
		if child is Control and child.visible and child != choices: header_height += child.get_combined_minimum_size().y + screen.content.get_theme_constant("separation")
	var width := minf(620, (minf(area.x, available.x - 48) - 24 - (28 if choices.columns == 2 else 0)) / choices.columns)
	var height := maxf(100, minf(width * .76, (area.y - header_height - 16 - (24 if choices.columns == 1 else 0)) / (2 if choices.columns == 1 else 1)))
	width = minf(width, height / .76)
	for child in choices.get_children(): child.custom_minimum_size = Vector2(width, height)


func player_disconnected(id: String) -> void:
	for player in session.players:
		if str(player.id) == id: missing[id] = str(player.display_name)
	_refresh_connections()


func player_joined(player: Dictionary) -> void:
	missing.erase(str(player.get("id", ""))); _refresh_connections()


func player_reconnected(player: Dictionary) -> void:
	player_joined(player)


func _refresh_connections() -> void:
	for button in choices.get_children(): button.disabled = not button.get_meta("allowed", false) or not missing.is_empty()
	screen.status.visible = not missing.is_empty()
	if not missing.is_empty(): screen.status.text = "Waiting for " + ", ".join(missing.values())
	_fit.call_deferred()


func shutdown_game() -> void:
	if entrance != null and entrance.is_valid(): entrance.kill()
	screen.background_media.set_active(false)
