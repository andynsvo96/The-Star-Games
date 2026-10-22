extends GameCatalog

var fixture_count := 12


func _init(count := 12) -> void:
	super._init("res://tests/fixtures/Games")
	fixture_count = count


func scan() -> Array:
	super.scan()
	if games.is_empty():
		return games
	var fixture: Dictionary = games[0]
	for index in range(1, fixture_count):
		var game := fixture.duplicate(true)
		game.id = "layout-%d" % index
		game.title = "Fixture %02d" % index
		games.append(game)
	return games
