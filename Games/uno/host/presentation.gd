extends RefCounted

static var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Games/uno/art/rules/catalog.json"))


static func player_choice(view: Dictionary) -> Dictionary:
	if int(view.get("viewer", -1)) < 0: return {}
	if view.get("phase", "") == "swap" and view.get("swap_seat", -1) == view.viewer:
		return {"targets":view.get("swap_targets", []), "prompt":"Choose a player to swap hands with.", "action":"swap", "multiple":false, "amounts":{}}
	var offered: Dictionary = view.get("addon_choice", {})
	if view.get("phase", "") != "addon_choice" or offered.get("owner", -1) != view.viewer or offered.get("targets", []).is_empty(): return {}
	var multiple: bool = offered.kind == "instigator"
	return {"targets":offered.targets, "prompt":"Tap players to set 0–4 cards each." if multiple else str(offered.prompt), "compact_prompt":"Tap players: 0–4 cards." if multiple else str(offered.prompt), "action":"addon_choose", "multiple":multiple, "amounts":offered.get("amounts", {})}


static func rule_items(view: Dictionary) -> Array:
	var mode: String = view.get("gamemode", "classic")
	var definitions: Array = [catalog.modes.get(mode, catalog.modes.classic) + ["Game Mode"]]
	for key: String in catalog.options:
		if view.get("options", {}).get(key, false) and (key != "allow_mercy" or mode == "no_mercy"):
			definitions.append(catalog.options[key] + ["House Rules"])
	for addon: String in view.get("active_addons", []):
		definitions.append([addon, catalog.addons.get(addon, "Extra action cards"), catalog.addon_icons.get(addon, "addon"), "Add-Ons"])
	var items: Array = definitions.map(func(item: Array) -> Dictionary:
		return {"title":item[0], "detail":item[1], "icon":"res://Games/uno/art/rules/%s.svg" % item[2], "section":item[3]}
	)
	for effect: Dictionary in relationships(view): items.append({"title":effect.title, "detail":effect.detail, "icon":effect.icon, "section":"Active Effects"})
	return items


static func relationships(view: Dictionary) -> Array:
	var result: Array = []
	var players: Array = view.get("players", [])
	for pair in [["Coupled", view.get("couple", [-1,-1]), "addon-love-island"], ["Basket", view.get("basket", [-1,-1]), "addon-love-island"]]:
		if pair[1][0] >= 0 and pair[1][1] >= 0 and pair[1].max() < players.size():
			result.append({"title":pair[0], "detail":"%s → %s" % [players[pair[1][0]].display_name, players[pair[1][1]].display_name], "seats":pair[1], "icon":"res://Games/uno/art/rules/%s.svg" % pair[2]})
	for owner in view.get("enemies", {}):
		var target: int = int(view.enemies[owner])
		if int(owner) >= 0 and int(owner) < players.size() and target >= 0 and target < players.size():
			result.append({"title":"Nemesis", "detail":"%s → %s" % [players[int(owner)].display_name, players[target].display_name], "seats":[int(owner), target], "icon":"res://Games/uno/art/rules/addon-frenemies.svg"})
	return result


static func hand_choice(view: Dictionary) -> Array:
	var offered: Dictionary = view.get("addon_choice", {})
	if view.get("phase", "") == "addon_choice" and offered.get("owner", -1) == view.get("viewer", -2) and offered.get("kind", "") in ["give", "double", "combo_keep"]:
		return offered.get("cards", []).map(func(card: Dictionary) -> int: return card.id)
	return []


static func context_actions(view: Dictionary) -> Dictionary:
	if int(view.get("viewer", -1)) < 0 or view.get("phase", "") == "finished": return {}
	var actions: Array = []
	if not str(view.get("addon_accept", "")).is_empty(): actions.append({"id":"accept", "label":view.addon_accept})
	if view.get("addon_decline", false): actions.append({"id":"decline", "label":"LET PARTNER DRAW"})
	if view.get("can_combo", false): actions.append({"id":"combo", "label":"U-N-O COMBO"})
	if view.get("can_end_enemy", false): actions.append({"id":"end_enemy", "label":"END NEMESIS"})
	var offered: Dictionary = view.get("addon_choice", {})
	var prompt: String = ""
	if not hand_choice(view).is_empty(): prompt = str(offered.prompt) + " Tap a card in your hand."
	elif offered.get("kind", "") == "chat_take": prompt = "Tap %s's badge to view the exchange cards." % view.players[offered.target].display_name
	elif offered.get("kind", "") == "text": prompt = "Tap the discard card to choose a rule."
	elif offered.get("kind", "") == "combo_color" or view.get("phase", "") in ["opening_color", "drawn_color", "flip_color", "roulette_color"]: prompt = "Tap the discard card to choose a color."
	elif not view.get("revealed_cards", {}).is_empty(): prompt = "Tap a highlighted player badge to view Color Challenge results."
	return {"prompt":prompt, "actions":actions}
