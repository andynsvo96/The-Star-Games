class_name GameSkinSelector
extends OptionButton

# Cosmetic changes never restart or revise a game's authoritative state.
# The module reloads its retained media and publishes its usual private views.
signal skin_changed
var host: BaseGame
var manager: ThemePacks


func configure(game: BaseGame, packs: ThemePacks = null) -> void:
	host = game
	manager = packs if packs != null else ThemePacks.new(game.session.game_id)
	accessibility_name = "Skin"
	fit_to_longest_item = false
	text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if ThemePacks.snapshot(manager.game_id).is_empty():
		manager.pin(str(host.load_game_settings({"theme": "default"}).theme))
	_refresh()
	get_popup().about_to_popup.connect(_refresh)
	item_selected.connect(func(index: int) -> void: select_skin(str(get_item_metadata(index))))


func _refresh() -> void:
	clear()
	var current := str(ThemePacks.snapshot(manager.game_id).get("id", "default"))
	for pack in manager.list_packs():
		add_item(str(pack.name))
		set_item_metadata(item_count - 1, pack.id)
		if pack.id == current: select(item_count - 1)
	disabled = item_count == 0


func select_skin(id: String) -> bool:
	var pack := manager.load_pack(id)
	if pack.is_empty():
		_refresh()
		return false
	if ThemePacks.snapshot(manager.game_id).get("revision", "") == pack.revision:
		_refresh()
		return true
	if not host.save_game_settings({"theme": id}):
		_refresh()
		return false
	manager.pin(id)
	_refresh()
	skin_changed.emit()
	return true
