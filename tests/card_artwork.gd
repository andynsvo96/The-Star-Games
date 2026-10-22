extends SceneTree
var checks := 0
var failures := 0

func _init() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + message)

func _run() -> void:
	var path := "res://Games/monopoly-deal/art/pass-go.svg"
	var base := GameCard.artwork(path)
	check(base is DPITexture and base.get_size() == Vector2(240,360), "Card artwork retains SVG source at its logical size")
	var sharp := RuntimeAssets.scalable_texture(path, Vector2(700,1050)) as DPITexture
	check(sharp != null and sharp.base_scale == 3 and sharp.get_size() == base.get_size(), "Reader artwork rasterizes at a higher scale without changing layout")
	check(RuntimeAssets.scalable_texture(path, Vector2(700,1050)) == sharp, "Repeated frames reuse the same scalable texture")
	check(RuntimeAssets.texture(path).get_size() == Vector2(240,360), "Existing texture callers keep their original import behavior")
	var inventory: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Games/monopoly-deal/cards.json"))
	var seen: Array = []
	for card in inventory.cards:
		if seen.has(card.key): continue
		seen.append(card.key)
		var art := GameCard.artwork("res://Games/monopoly-deal/art/%s.svg" % card.key)
		check(art is DPITexture and art.get_size() == Vector2(240,360), "Every default face remains scalable: " + str(card.key))
	for index in 10: RuntimeAssets.scalable_texture("res://Games/monopoly-deal/art/%s.svg" % seen[index], Vector2(700,1050))
	check(RuntimeAssets.textures.keys().filter(func(key: String) -> bool: return key.begins_with("svg:") and int(RuntimeAssets.textures[key].get_meta("svg_scale", 1)) > 1).size() <= 6, "Zoomed card textures have a bounded cache")
	var folder := "res://.test_data/card-artwork/"; DirAccess.make_dir_recursive_absolute(folder + "asset")
	var image := Image.create(40,60,false,Image.FORMAT_RGBA8); image.fill(Color.PURPLE); image.save_png(folder + "asset/custom.png")
	RuntimeAssets.root_override = ProjectSettings.globalize_path(folder).trim_suffix("/"); RuntimeAssets.refresh(); RuntimeAssets.loaded = true
	RuntimeAssets.redirects = {"Games/monopoly-deal/art/pass-go.svg": "asset/custom.png"}
	var raster := GameCard.artwork(path)
	check(not raster is DPITexture and raster.get_size() == Vector2(40,60), "Bitmap theme replacements keep their original pixels")
	var file := FileAccess.open(folder + "asset/custom.svg", FileAccess.WRITE)
	file.store_string('<svg xmlns="http://www.w3.org/2000/svg" width="300" height="450"><rect width="300" height="450" fill="#893dec"/></svg>'); file.close()
	RuntimeAssets.refresh(); RuntimeAssets.loaded = true; RuntimeAssets.redirects = {"Games/monopoly-deal/art/pass-go.svg": "asset/custom.svg"}
	var themed := RuntimeAssets.scalable_texture(path, Vector2(600,900)) as DPITexture
	check(themed != null and themed.base_scale == 2 and themed.get_source().contains("#893dec"), "Replacement SVGs use the same sharp rendering path")
	RuntimeAssets.root_override = ""; RuntimeAssets.refresh()
	print("Card artwork: %d checks, %d failures" % [checks, failures]); quit(1 if failures else 0)
