extends RefCounted

# Public presentation metadata only. Prices, ownership and levels come from rules.
static func decorate(source: Dictionary, labels: Dictionary = {}) -> Dictionary:
	var card := source.duplicate(true)
	card.display_name = str(labels.get(card.key, card.name))
	if card.get("kind", "") != "property" or int(card.get("owner", -1)) < 0: return card
	var level := int(card.get("buildings", 0))
	var active := int(card.get("rent_level", level)) if int(card.owner) >= 0 and not card.get("mortgaged", false) else -1
	var rows: Array = []
	var labels_rows := ["RENT", "With 1 House", "With 2 Houses", "With 3 Houses", "With 4 Houses", "With HOTEL"]
	var area := [25, 122, 190, 147]
	if card.group == "railroad":
		labels_rows = ["One railroad", "Two railroads", "Three railroads", "Four railroads"]; area = [25, 122, 190, 122]
	if card.group == "utility":
		area = [25, 148, 190, 78]
		for index in 2: rows.append({"label":"One utility" if index == 0 else "Both utilities", "value":"4 × dice" if index == 0 else "10 × dice", "active":index == active})
	else:
		for index in card.rents.size():
			rows.append({"label":labels_rows[index], "value":"$%d" % (int(card.rent) if index == active else int(card.rents[index])), "active":index == active})
	card.deed_state = {"area":area, "rows":rows, "accent":card.color, "badge":"HOTEL" if level == 5 else "1 HOUSE" if level == 1 else "%d HOUSES" % level if level > 0 else "", "icon":"hotel" if level == 5 else "house"}
	return card
