extends RefCounted
const Rules = preload("res://Games/pictionary/host/rules.gd")

const MAX_CATEGORIES := 24
const MAX_WORDS := 2000


static func from_words(words: Array) -> Array:
	var result: Array = []
	for id in ["animals", "food", "objects", "places", "actions"]:
		var entries: Array = []
		for word in words:
			if word.get("category") == id:
				entries.append({"word": word.word, "difficulty": word.difficulty, "aliases": word.get("aliases", []).duplicate()})
		result.append({"id": id, "name": id.capitalize(), "words": entries})
	return result


static func valid_name(value: Variant, limit := 40) -> bool:
	return value is String and not value.strip_edges().is_empty() and value.length() <= limit and not value.contains("\n") and not value.contains("\r")


static func validate(value: Variant) -> Array:
	if not value is Array or value.is_empty() or value.size() > MAX_CATEGORIES:
		return []
	var result: Array = []
	var ids: Array = ["mixed"]
	var names: Array = []
	var total := 0
	var id_pattern := RegEx.new()
	id_pattern.compile("^[a-z0-9][a-z0-9-]{0,47}$")
	for category in value:
		if not category is Dictionary or not category.get("id") is String or ids.has(category.id) or id_pattern.search(category.id) == null or not valid_name(category.get("name")) or not category.get("words") is Array:
			return []
		var name: String = category.name.strip_edges()
		if names.has(name.to_lower()):
			return []
		ids.append(category.id)
		names.append(name.to_lower())
		var words: Array = []
		var used: Array = []
		for word in category.words:
			if not word is Dictionary or not valid_name(word.get("word")) or Rules.normalize(word.word).is_empty() or not word.get("difficulty") in ["easy", "medium", "hard"] or not word.get("aliases", []) is Array:
				return []
			var text: String = word.word.strip_edges()
			if used.has(text.to_lower()):
				return []
			used.append(text.to_lower())
			var aliases: Array = word.get("aliases", [])
			if aliases.size() > 12 or aliases.any(func(alias: Variant) -> bool: return not valid_name(alias, 60)):
				return []
			words.append({"word": text, "difficulty": word.difficulty, "aliases": aliases.duplicate()})
			total += 1
			if total > MAX_WORDS:
				return []
		result.append({"id": category.id, "name": name, "words": words})
	return result if total >= 3 else []


static func flatten(categories: Array) -> Array:
	var result: Array = []
	for category in categories:
		for word in category.words:
			var entry: Dictionary = word.duplicate(true)
			entry["category"] = category.id
			result.append(entry)
	return result


static func category_ids(categories: Array) -> Array:
	var result: Array = ["mixed"]
	for category in categories:
		result.append(category.id)
	return result
